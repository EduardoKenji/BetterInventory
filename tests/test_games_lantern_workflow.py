from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
PARSER_PATH = RUNTIME_ROOT / "auto_crafter" / "games_lantern" / "parser.lua"
RESOLVER_PATH = RUNTIME_ROOT / "auto_crafter" / "games_lantern" / "resolver.lua"
FIXTURE_PATH = PROJECT_ROOT / "tests" / "fixtures" / "games_lantern_weapon_cards.html"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)

    def to_lua(value):
        if isinstance(value, dict):
            return lua.table_from({key: to_lua(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([to_lua(item) for item in value])
        return value

    parser = lua.execute(PARSER_PATH.read_text(encoding="utf-8"), name=str(PARSER_PATH))
    resolver = lua.execute(RESOLVER_PATH.read_text(encoding="utf-8"), name=str(RESOLVER_PATH))
    model = parser.parse(FIXTURE_PATH.read_text(encoding="utf-8"))

    melee_offer = to_lua(
        {
            "display_name": "Covenant Mk VI Blaze Force Greatsword",
            "master_id": "covenant_mk_vi_blaze_force_greatsword",
            "parent_pattern": "blaze_force_greatsword_pattern",
            "weapon_category": "melee",
            "base_stats": [
                    {"name": "warp_resist", "display_name_key": "Warp Resistance"},
                    {"name": "cleave_damage", "display_name_key": "Cleave Damage"},
                    {"name": "finesse", "display_name_key": "Finesse"},
                ],
        }
    )
    ranged_offer = to_lua(
        {
            "display_name": "Covenant Mk VI Trauma Force Staff",
            "master_id": "covenant_mk_vi_trauma_force_staff",
            "parent_pattern": "trauma_force_staff_pattern",
            "weapon_category": "ranged",
            "base_stats": [
                    {"name": "charge_speed", "display_name_key": "Charge Rate"},
                    {"name": "warp_resist", "display_name_key": "Warp Resistance"},
                    {"name": "blast_radius", "display_name_key": "Blast Radius"},
                ],
        }
    )

    def catalog_for_offer(offer):
        if offer["weapon_category"] == "melee":
            return to_lua(
                {
                    "available": True,
                    "perks": [
                            {"id": "perk_cara", "display_name": "Damage Carapace Armoured", "tier": 4},
                            {"id": "perk_unyielding", "display_name": "Damage Unyielding", "tier": 4},
                        ],
                    "blessings": [
                            {"id": "blessing_unstable_power", "display_name": "Unstable Power", "tiers": [{"tier": 4, "status": "seen"}]},
                            {"id": "blessing_riposte", "display_name": "Riposte", "tiers": [{"tier": 4, "status": "seen"}]},
                        ],
                }
            )
        return to_lua(
            {
                "available": True,
                "perks": [
                        {"id": "perk_cara", "display_name": "Damage Carapace Armoured", "tier": 4},
                        {"id": "perk_unyielding", "display_name": "Damage Unyielding", "tier": 4},
                    ],
                "blessings": [
                        {"id": "blessing_warp_nexus", "display_name": "Warp Nexus", "tiers": [{"tier": 4, "status": "seen"}]},
                        {"id": "blessing_surge", "display_name": "Surge", "tiers": [{"tier": 4, "status": "seen"}]},
                    ],
            }
        )

    catalog_callback = lua.eval(
        "function(callback) return function(offer) return callback(offer) end end"
    )(catalog_for_offer)
    context = to_lua(
        {
            "active_archetype": "psyker",
            "dump_target": 65,
            "melee_offers": [melee_offer],
            "ranged_offers": [ranged_offer],
            "catalog_for_offer": catalog_callback,
        }
    )
    resolved, reason = resolver.resolve(model, context)
    assert resolved is not None, reason
    assert resolved["resolver_contract_version"] == "games_lantern_resolver_v1"
    assert resolved["jobs"][1]["slot"] == "melee"
    assert resolved["jobs"][2]["slot"] == "ranged"
    assert resolved["jobs"][1]["dump_stat"] == "warp_resist"
    assert resolved["jobs"][1]["dump_target"] == 65
    assert resolved["jobs"][2]["dump_stat"] == "charge_speed"
    assert resolved["jobs"][1]["perks"][1]["id"] == "perk_cara"
    assert resolved["jobs"][1]["perks"][1]["rarity"] == 4
    assert resolved["jobs"][1]["blessings"][1]["rarity"] == 4
    assert resolved["jobs"][2]["blessings"][2]["id"] == "blessing_surge"

    # Public Games Lantern class slugs map to Darktide's internal archetype
    # IDs before enforcing the class safety gate.
    assert resolver.canonical_archetype("skitarii") == "cryptic"
    assert resolver.canonical_archetype("Skitarius") == "cryptic"
    assert resolver.canonical_archetype("arbites") == "adamant"
    assert resolver.canonical_archetype("hive_scum") == "broker"
    skitarius_model = to_lua({"source_archetype": "skitarii", "weapons": model["weapons"]})
    skitarius_context = to_lua({
        "active_archetype": "cryptic",
        "dump_target": 65,
        "melee_offers": [melee_offer],
        "ranged_offers": [ranged_offer],
    })
    assert resolver.resolve_identities(skitarius_model, skitarius_context)[0] is not None

    # Brunt's live offers are family-level and intentionally omit Games
    # Lantern's named mark. Both Skitarius weapons must still resolve without
    # weakening ambiguity handling.
    transonic_offer = to_lua({
        "display_name": "loc_weapon_family_transonic_sword_transonic_knife_p1_m1",
        "master_id": "content/items/weapons/player/melee/transonic_sword_transonic_knife_p1_m1",
        "parent_pattern": "transonic_sword_transonic_knife_p1_m1",
        "base_stats": [
            {"name": "transonic_sword_transonic_knife_p1_m1_cleave_damage_and_targets_stat", "display_name_key": "loc_stats_display_cleave_damage_and_targets_stat"},
            {"name": "damage", "display_name_key": "Damage"},
        ],
    })
    phosphor_offer = to_lua({
        "display_name": "loc_weapon_family_phosphor_pistol_p1_m1",
        "master_id": "content/items/weapons/player/ranged/phosphor_pistol_p1_m1",
        "parent_pattern": "phosphor_pistol_p1_m1",
        "base_stats": [
            {"name": "mobility", "display_name_key": "Mobility"},
            {"name": "damage", "display_name_key": "Damage"},
        ],
    })
    skitarius_live_model = to_lua({
        "source_archetype": "skitarii",
        "weapons": [
            {
                "display_name": "Branx Mk XI Paired Transonic Blades",
                "external_family_slug": "paired-transonic-blades",
                "external_mark_slug": "branx-mk-xi-paired-transonic-blades",
                "stats": [{"label": "Cleave Efficiency", "value": 60}, {"label": "Damage", "value": 80}],
            },
            {
                "display_name": "Branx Mk XI Phosphor Blast Pistol",
                "external_family_slug": "phosphor-blast-pistol",
                "external_mark_slug": "branx-mk-xi-phosphor-blast-pistol",
                "stats": [{"label": "Mobility", "value": 60}, {"label": "Damage", "value": 80}],
            },
        ],
    })
    skitarius_live_context = to_lua({
        "active_archetype": "cryptic",
        "dump_target": 60,
        "localize_offer_label": lua.eval("function(key) local labels = { loc_weapon_family_transonic_sword_transonic_knife_p1_m1 = 'Paired Transonic Blades', loc_weapon_family_phosphor_pistol_p1_m1 = 'Phosphor Blast Pistol' }; return labels[key] end"),
        "melee_offers": [transonic_offer],
        "ranged_offers": [phosphor_offer],
    })
    skitarius_identity, reason = resolver.resolve_identities(skitarius_live_model, skitarius_live_context)
    assert skitarius_identity is not None, reason
    assert skitarius_identity["jobs"][1]["master_id"].endswith("transonic_sword_transonic_knife_p1_m1")
    assert skitarius_identity["jobs"][2]["master_id"].endswith("phosphor_pistol_p1_m1")
    assert skitarius_identity["jobs"][1]["dump_stat"].endswith("cleave_damage_and_targets_stat")

    bad_dump_model = to_lua({
        "source_archetype": "skitarii",
        "weapons": [
            {
                "display_name": "Branx Mk XI Paired Transonic Blades",
                "external_family_slug": "paired-transonic-blades",
                "external_mark_slug": "branx-mk-xi-paired-transonic-blades",
                "stats": [{"label": "Unknown Efficiency", "value": 60}, {"label": "Damage", "value": 80}],
            },
            skitarius_live_model["weapons"][2],
        ],
    })
    assert resolver.resolve_identities(bad_dump_model, skitarius_live_context)[1] == "dump_stat_unavailable"

    # Class mismatch, ambiguous marks, and tied dump stats must reject the
    # entire build rather than install one partially resolved job.
    wrong_class = to_lua(
        {
            "source_archetype": "veteran",
            "weapons": model["weapons"],
        }
    )
    result, reason = resolver.resolve(wrong_class, context)
    assert result is None
    assert reason == "archetype_mismatch"

    missing_class = to_lua({"weapons": model["weapons"]})
    result, reason = resolver.resolve(missing_class, context)
    assert result is None
    assert reason == "archetype_unavailable"

    duplicate_offer = to_lua(
        {
            "active_archetype": "psyker",
            "melee_offers": [melee_offer, melee_offer],
            "ranged_offers": [ranged_offer],
            "catalog_for_offer": catalog_callback,
        }
    )
    result, reason = resolver.resolve(model, duplicate_offer)
    assert result is None
    assert reason in {"ambiguous_melee", "multiple_melee_weapons"}

    tied_model = to_lua(
        {
            "source_archetype": "psyker",
            "weapons": [
                    {
                            "display_name": "Covenant Mk VI Blaze Force Greatsword",
                            "external_family_slug": "blaze-force-greatsword",
                            "external_mark_slug": "covenant-mk-vi",
                            "stats": [
                                    {"label": "Warp Resistance", "value": 0},
                                    {"label": "Cleave Damage", "value": 0},
                                ],
                            "perks": model["weapons"][1]["perks"],
                            "blessings": model["weapons"][1]["blessings"],
                        }
                ],
        }
    )
    result, reason = resolver.resolve(tied_model, context)
    assert result is None
    assert reason in {"dump_stat_tie", "melee_weapon_unavailable"}

    clone = lua.eval("function(value) local result = {}; for key, child in pairs(value) do result[key] = type(child) == 'table' and (function(v) local r = {}; for k, c in pairs(v) do r[k] = type(c) == 'table' and (function(v2) local r2 = {}; for k2, c2 in pairs(v2) do r2[k2] = c2 end; return r2 end)(c) or c end; return r end)(child) or child end; return result end")
    multi_model = to_lua({
        "source_archetype": "psyker",
        "weapons": [clone(model["weapons"][1]), clone(model["weapons"][1]), clone(model["weapons"][2])],
    })
    multi_model["weapons"][1]["card_index"] = 1
    multi_model["weapons"][2]["card_index"] = 2
    multi_model["weapons"][3]["card_index"] = 3
    result, reason, choices = resolver.resolve_identities(multi_model, context)
    assert result is None
    assert reason == "weapon_choice_required"
    assert len(choices["melee"]) == 2
    context["weapon_choices"] = to_lua({"melee": 2})
    selected = resolver.resolve_identities(multi_model, context)[0]
    assert selected["jobs"][1]["external"]["card_index"] == 2


if __name__ == "__main__":
    main()
