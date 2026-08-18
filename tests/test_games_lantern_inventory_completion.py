from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CONTROLLER_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "core" / "controller.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('package.preload["scripts/foundation/utilities/promise"] = function() return {} end')
    controller_module = __import__("auto_crafter_test_support").load_controller(lua)

    def to_lua(value):
        if isinstance(value, dict):
            return lua.table_from({key: to_lua(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([to_lua(item) for item in value])
        return value

    settings_values = {
        "auto_crafter_allocate_mastery_points": True,
        "auto_crafter_change_blessings": True,
        "auto_crafter_change_perks": True,
        "auto_crafter_consecrate_transcendent": True,
        "auto_crafter_include_favorite_inventory_bases": True,
        "auto_crafter_craft_duplicate_completed_queued_weapons": False,
        "auto_crafter_level_mastery_20": True,
        "auto_crafter_reuse_inventory_base": True,
        "auto_crafter_upgrade_expertise_500": True,
    }
    settings = to_lua({"values": settings_values})
    settings["get"] = lua.eval("function(self, key) return self.values[key] end")
    context = to_lua({})
    context["current_character_id"] = lua.eval("function() return 'character-1' end")
    context["is_runtime_valid"] = lua.eval("function() return true end")
    controller = controller_module.new(to_lua({"context": context, "settings": settings}))

    def item(gear_id, master_id, favorite=False, equipped=False):
        return {
            "available": True,
            "equipped": equipped,
            "expertise_level": 500,
            "favorite_known": True,
            "favorited": favorite,
            "gear_id": gear_id,
            "master_id": master_id,
            "parent_pattern": "pattern-1",
            "potential_base_stats": {"damage": 60},
            "rarity": 5,
            "perks": [{"id": "perk-a", "rarity": 4}, {"id": "perk-b", "rarity": 4}],
            "traits": [{"id": "blessing-a", "rarity": 4}, {"id": "blessing-b", "rarity": 4}],
        }

    def job(slot="melee", master_id="mark-exact"):
        return {
            "kind": "games_lantern_job",
            "slot": slot,
            "job_id": "queue:1" if slot == "melee" else "queue:2",
            "queue_id": "queue",
            "master_id": master_id,
            "parent_pattern": "pattern-1",
            "offer": {"master_id": master_id, "parent_pattern": "pattern-1"},
            "dump_stat": "damage",
            "dump_target": 60,
            "perks": [{"id": "perk-a", "rarity": 4}, {"id": "perk-b", "rarity": 4}],
            "blessings": [{"id": "blessing-a", "rarity": 4}, {"id": "blessing-b", "rarity": 4}],
            "catalog": {
                "available": True,
                "mastery": {"mastery_level": 20, "claimed_level": 19},
                "blessings": [
                    {"id": "blessing-a", "tiers": [{"tier": 4, "status": "seen"}]},
                    {"id": "blessing-b", "tiers": [{"tier": 4, "status": "seen"}]},
                ],
            },
        }

    def set_inventory(items):
        controller["_snapshot"] = to_lua({
            "character_id": "character-1",
            "gear": {"available": True, "items": items},
        })

    # Finished-item detection is read-only. Favorite, equipped, and mark state
    # do not hide a family-equivalent result; tie-break remains stable.
    set_inventory([
        item("gear-z", "mark-exact", favorite=True),
        item("gear-a", "mark-exact", favorite=False, equipped=True),
        item("gear-wrong-mark", "mark-sibling"),
    ])
    melee = to_lua(job("melee"))
    completed = controller._completed_imported_job_result(controller, melee)
    assert completed["gear_id"] == "gear-a"
    assert completed["kind"] == "games_lantern_completed_inventory_result"

    set_inventory([item("gear-only-sibling", "mark-sibling")])
    assert controller._completed_imported_job_result(controller, melee)["gear_id"] == "gear-only-sibling"

    # Perk/blessing order is not item identity. Missing any final invariant,
    # mastery claim, or allocated blessing tier prevents a skip.
    reordered = item("gear-reordered", "mark-exact")
    reordered["perks"].reverse()
    reordered["traits"].reverse()
    set_inventory([reordered])
    assert controller._completed_imported_job_result(controller, melee)["gear_id"] == "gear-reordered"

    for field, bad_value in (("rarity", 4), ("expertise_level", 499)):
        incomplete = item("gear-incomplete", "mark-exact")
        incomplete[field] = bad_value
        set_inventory([incomplete])
        assert controller._completed_imported_job_result(controller, melee) is None

    wrong_perk = item("gear-wrong-perk", "mark-exact")
    wrong_perk["perks"][0] = {"id": "other", "rarity": 4}
    set_inventory([wrong_perk])
    assert controller._completed_imported_job_result(controller, melee) is None

    unclaimed = job("melee")
    unclaimed["catalog"]["mastery"]["claimed_level"] = 18
    set_inventory([item("gear-unclaimed", "mark-exact")])
    assert controller._completed_imported_job_result(controller, to_lua(unclaimed)) is None

    unallocated = job("melee")
    unallocated["catalog"]["blessings"][0]["tiers"][0]["status"] = "unseen"
    set_inventory([item("gear-unallocated", "mark-exact")])
    assert controller._completed_imported_job_result(controller, to_lua(unallocated)) is None

    # Both queue positions use the same family-level resume selector. An
    # incomplete sibling mark is resumable and takes priority over a completed
    # item. Favorite option gates mutable bases, not read-only completion.
    for slot in ("melee", "ranged"):
        current_job = to_lua(job(slot))
        resumable = item(f"gear-{slot}-resume", "mark-sibling", favorite=True)
        resumable["expertise_level"] = 400
        completed_exact = item(f"gear-{slot}-complete", "mark-exact")
        set_inventory([completed_exact, resumable])
        controller["_imported_job"] = current_job
        controller["_search"] = to_lua({
            "dump_stat": "damage",
            "favorite_result": False,
            "target_dump": 60,
            "target_offer": current_job["offer"],
        })
        selected = controller._find_inventory_base(controller)
        assert selected["gear_id"] == f"gear-{slot}-resume"
        decision = controller._imported_job_inventory_decision(controller, current_job)
        assert decision == "resume"

        settings["values"]["auto_crafter_include_favorite_inventory_bases"] = False
        assert controller._find_inventory_base(controller) is None
        settings["values"]["auto_crafter_include_favorite_inventory_bases"] = True

        set_inventory([completed_exact])
        decision, skipped = controller._imported_job_inventory_decision(controller, current_job)
        assert decision == "skip" and skipped["gear_id"] == f"gear-{slot}-complete"
        settings["values"]["auto_crafter_craft_duplicate_completed_queued_weapons"] = True
        assert controller._imported_job_inventory_decision(controller, current_job) == "new"
        assert controller._find_inventory_base(controller) is None
        settings["values"]["auto_crafter_craft_duplicate_completed_queued_weapons"] = False

    # Exact imported five-stat profiles participate in the same completed-item
    # skip and family-equivalent resume rules. A single mismatched projected
    # value prevents an incorrect skip, independent of mark or favorite state.
    exact_profile = [
        {"name": "charge_speed", "value": 70},
        {"name": "ammo", "value": 80},
        {"name": "power", "value": 80},
        {"name": "heat", "value": 70},
        {"name": "damage", "value": 80},
    ]
    profile_job = job("ranged")
    profile_job["custom_stats_enabled"] = True
    profile_job["custom_stat_targets"] = exact_profile
    profile_job["custom_stat_total"] = 380
    profile_item = item("gear-profile", "mark-sibling", favorite=True)
    profile_item["potential_base_stats"] = {target["name"]: target["value"] for target in exact_profile}
    set_inventory([profile_item])
    profile_job_lua = to_lua(profile_job)
    assert controller._completed_imported_job_result(controller, profile_job_lua)["gear_id"] == "gear-profile"

    profile_item["potential_base_stats"]["heat"] = 71
    set_inventory([profile_item])
    assert controller._completed_imported_job_result(controller, profile_job_lua) is None
    profile_item["potential_base_stats"]["heat"] = 70
    profile_item["expertise_level"] = 400
    controller["_imported_job"] = profile_job_lua
    controller["_search"] = to_lua({
        "custom_stat_targets": exact_profile,
        "dump_stat": "charge_speed",
        "favorite_result": False,
        "target_dump": 70,
        "target_offer": profile_job_lua["offer"],
    })
    set_inventory([profile_item])
    assert controller._find_inventory_base(controller)["gear_id"] == "gear-profile"

    # A fresh boundary snapshot revalidates completed prefix before next job.
    # Removal, family drift, or trait drift blocks queue continuation. Mark
    # changes inside the same mastery family remain valid.
    exact = item("gear-prefix", "mark-exact")
    set_inventory([exact])
    controller["_queue_operation_owner"] = True
    controller["_queue_run_policy"] = to_lua({
        "values": {
            "auto_crafter_change_blessings": True,
            "auto_crafter_change_perks": True,
            "auto_crafter_consecrate_transcendent": True,
            "auto_crafter_upgrade_expertise_500": True,
        }
    })
    prefix_result = to_lua({"character_id": "character-1", "gear_id": "gear-prefix"})
    assert controller._verify_imported_result(controller, prefix_result, melee, 1) is True

    exact["master_id"] = "mark-sibling"
    set_inventory([exact])
    assert controller._verify_imported_result(controller, prefix_result, melee, 1) is True

    exact["parent_pattern"] = "other-pattern"
    set_inventory([exact])
    verified, reason = controller._verify_imported_result(controller, prefix_result, melee, 1)
    assert verified is False and "weapon family" in reason

    set_inventory([])
    verified, reason = controller._verify_imported_result(controller, prefix_result, melee, 1)
    assert verified is False and "missing" in reason

    # Closest fallback carries immutable distance proof across queue boundaries.
    # Matching proof passes; altered or forged distance fails final reconciliation.
    fallback_item = item("gear-prefix-fallback", "mark-exact")
    fallback_item["potential_base_stats"]["damage"] = 58
    set_inventory([fallback_item])
    fallback_result = to_lua({
        "character_id": "character-1",
        "fallback_accepted": True,
        "fallback_target_distance": 2,
        "gear_id": "gear-prefix-fallback",
    })
    assert controller._verify_imported_result(controller, fallback_result, melee, 1) is True
    fallback_result["fallback_target_distance"] = 1
    verified, reason = controller._verify_imported_result(controller, fallback_result, melee, 1)
    assert verified is False and "dump stat" in reason

    # Terminal Phase 4 performs same authoritative postcondition check. Any
    # malformed/drifted result becomes visible operation_failed, never success.
    final_controller = controller_module.new(to_lua({"context": context, "settings": settings}))
    final_item = to_lua(item("gear-final", "mark-exact", favorite=True))
    final_controller["_snapshot"] = to_lua({"character_id": "character-1", "gear": {"items": [final_item]}})
    final_controller["_search"] = to_lua({"running": True})
    final_controller["_phase4"] = to_lua({
        "allocate_mastery": False,
        "consecrate": True,
        "dump_stat": "damage",
        "expertise": True,
        "favorite_result": True,
        "gear_id": "gear-final",
        "mastery_id": "pattern-1",
        "running": True,
        "target_dump": 60,
        "target_master_id": "mark-exact",
        "targets": {
            "perks": [{"id": "perk-a", "rarity": 4}, {"id": "perk-b", "rarity": 4}],
            "traits": [{"id": "blessing-a", "rarity": 4}, {"id": "blessing-b", "rarity": 4}],
        },
        "verify_completion": True,
    })
    assert final_controller._phase4_complete(final_controller, final_item, final_controller["_snapshot"]) is True

    final_item["master_id"] = "mark-sibling"
    final_controller["_phase4"]["running"] = True
    final_controller["_search"]["running"] = True
    assert final_controller._phase4_complete(final_controller, final_item, final_controller["_snapshot"]) is True

    final_item["parent_pattern"] = "other-pattern"
    final_controller["_phase4"]["running"] = True
    final_controller["_search"]["running"] = True
    assert final_controller._phase4_complete(final_controller, final_item, final_controller["_snapshot"]) is False
    assert final_controller.snapshot(final_controller)["last_error"] == "final weapon changed weapon family"

    fallback_controller = controller_module.new(to_lua({"context": context, "settings": settings}))
    final_fallback = to_lua(item("gear-final-fallback", "mark-exact", favorite=True))
    final_fallback["potential_base_stats"]["damage"] = 58
    fallback_controller["_snapshot"] = to_lua({"character_id": "character-1", "gear": {"items": [final_fallback]}})
    fallback_controller["_search"] = to_lua({"running": True})
    fallback_controller["_phase4"] = to_lua({
        "allocate_mastery": False,
        "consecrate": True,
        "dump_stat": "damage",
        "expertise": True,
        "fallback_accepted": True,
        "fallback_target_distance": 2,
        "favorite_result": True,
        "gear_id": "gear-final-fallback",
        "mastery_id": "pattern-1",
        "running": True,
        "target_dump": 60,
        "targets": {
            "perks": [{"id": "perk-a", "rarity": 4}, {"id": "perk-b", "rarity": 4}],
            "traits": [{"id": "blessing-a", "rarity": 4}, {"id": "blessing-b", "rarity": 4}],
        },
        "verify_completion": True,
    })
    assert fallback_controller._phase4_complete(fallback_controller, final_fallback, fallback_controller["_snapshot"]) is True

    final_fallback["potential_base_stats"]["damage"] = 57
    fallback_controller["_phase4"]["running"] = True
    fallback_controller["_search"]["running"] = True
    assert fallback_controller._phase4_complete(fallback_controller, final_fallback, fallback_controller["_snapshot"]) is False
    assert fallback_controller.snapshot(fallback_controller)["last_error"] == "final weapon changed dump stat"


if __name__ == "__main__":
    main()
