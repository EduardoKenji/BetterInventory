from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CONTROLLER_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "core" / "controller.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('package.preload["scripts/foundation/utilities/promise"] = function() return {} end')
    controller_module = lua.execute(CONTROLLER_PATH.read_text(encoding="utf-8"), name=str(CONTROLLER_PATH))

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

    # Finished-item detection is read-only. Favorite and equipped state do not
    # hide an exact result; exact mark remains mandatory and tie-break is stable.
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
    assert controller._completed_imported_job_result(controller, melee) is None

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

    # Both queue positions use same strict resume selector. Correct exact-mark
    # partial base wins; sibling mark never resumes. Favorite option only gates
    # mutable in-progress bases, not read-only completed detection above.
    for slot in ("melee", "ranged"):
        current_job = to_lua(job(slot))
        resumable = item(f"gear-{slot}-resume", "mark-exact", favorite=True)
        resumable["expertise_level"] = 400
        sibling = item(f"gear-{slot}-sibling", "mark-sibling")
        set_inventory([sibling, resumable])
        controller["_imported_job"] = current_job
        controller["_search"] = to_lua({
            "dump_stat": "damage",
            "favorite_result": False,
            "target_dump": 60,
            "target_offer": current_job["offer"],
        })
        selected = controller._find_inventory_base(controller)
        assert selected["gear_id"] == f"gear-{slot}-resume"

        settings["values"]["auto_crafter_include_favorite_inventory_bases"] = False
        assert controller._find_inventory_base(controller) is None
        settings["values"]["auto_crafter_include_favorite_inventory_bases"] = True


if __name__ == "__main__":
    main()
