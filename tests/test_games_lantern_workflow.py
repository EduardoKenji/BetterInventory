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
                            {"id": "perk_cara", "display_name": "Damage Carapace Armoured"},
                            {"id": "perk_unyielding", "display_name": "Damage Unyielding"},
                        ],
                    "blessings": [
                            {"id": "blessing_unstable_power", "display_name": "Unstable Power"},
                            {"id": "blessing_riposte", "display_name": "Riposte"},
                        ],
                }
            )
        return to_lua(
            {
                "available": True,
                "perks": [
                        {"id": "perk_cara", "display_name": "Damage Carapace Armoured"},
                        {"id": "perk_unyielding", "display_name": "Damage Unyielding"},
                    ],
                "blessings": [
                        {"id": "blessing_warp_nexus", "display_name": "Warp Nexus"},
                        {"id": "blessing_surge", "display_name": "Surge"},
                    ],
            }
        )

    catalog_callback = lua.eval(
        "function(callback) return function(offer) return callback(offer) end end"
    )(catalog_for_offer)
    context = to_lua(
        {
            "active_archetype": "psyker",
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
    assert resolved["jobs"][2]["dump_stat"] == "charge_speed"
    assert resolved["jobs"][1]["perks"][1]["id"] == "perk_cara"
    assert resolved["jobs"][2]["blessings"][2]["id"] == "blessing_surge"

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


if __name__ == "__main__":
    main()
