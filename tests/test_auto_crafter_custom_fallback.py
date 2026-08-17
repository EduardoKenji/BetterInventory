from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CONTROLLER_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "core" / "controller.lua"
PANEL_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "darktide" / "panel.lua"
LOCALIZATION_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_localization_features.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    controller_module = __import__("auto_crafter_test_support").load_controller(lua)
    controller = controller_module.new(lua.table_from({}))

    target_values = [80, 75, 75, 80, 70]
    targets = lua.table_from([
        lua.table_from({"name": f"stat_{index}", "value": value})
        for index, value in enumerate(target_values, start=1)
    ])
    controller["_search"] = lua.table_from({
        "custom_stat_targets": targets,
        "dump_stat": "stat_1",
        "target_dump": 80,
    })

    def candidate(gear_id: str, values: list[int], damage: int = 0):
        return lua.table_from({
            "gear_id": gear_id,
            "damage": damage,
            "potential_base_stats": lua.table_from({
                f"stat_{index}": value for index, value in enumerate(values, start=1)
            }),
        })

    distance_four = candidate("distance-4", [80, 73, 77, 80, 70], 1)
    distance_ten = candidate("distance-10", [80, 70, 80, 80, 70], 999)
    assert controller._candidate_is_better(controller, distance_four, distance_ten) is True
    assert distance_four["target_distance"] == 4
    assert distance_ten["target_distance"] == 10

    # A malformed/missing stat profile cannot displace a complete candidate.
    incomplete = candidate("incomplete", [80, 73, 77, 80, 70])
    incomplete["potential_base_stats"]["stat_5"] = None
    assert controller._candidate_is_better(controller, incomplete, None) is False
    assert controller._candidate_is_better(controller, incomplete, distance_four) is False
    assert incomplete["target_distance"] == float("inf")

    # Equal custom distance keeps the earlier roll, regardless of legacy Damage
    # tie-break values, making network response timing deterministic.
    equal_distance = candidate("equal-distance", [78, 75, 77, 80, 70], 9999)
    assert controller._candidate_is_better(controller, equal_distance, distance_four) is False
    assert equal_distance["target_distance"] == 4

    # The original single-dump policy retains its legacy Damage tie-break.
    controller["_search"] = lua.table_from({"dump_stat": "stat_1", "target_dump": 60})
    lower_damage = candidate("lower-damage", [58, 80, 80, 80, 80], 10)
    higher_damage = candidate("higher-damage", [62, 80, 80, 80, 80], 20)
    assert controller._candidate_is_better(controller, higher_damage, lower_damage) is True

    # A selected mark and a random Brunt sibling may expose different internal
    # IDs for the same Darktide stat. Only an exact, unique display identity may
    # bridge them; absent and ambiguous identities remain unusable.
    controller["_search"] = lua.table_from({
        "dump_stat": "shovel_m3_defence_stat",
        "dump_stat_identity": lua.table_from({
            "display_name_key": "loc_stats_display_defense_stat",
            "name": "shovel_m3_defence_stat",
        }),
        "target_dump": 60,
    })
    sibling = lua.table_from({
        "gear_id": "shovel-mk-1-roll",
        "base_stat_labels": lua.table_from({"shovel_m1_defence_stat": "loc_stats_display_defense_stat"}),
        "potential_base_stats": lua.table_from({"shovel_m1_defence_stat": 60}),
    })
    assert controller._candidate_is_better(controller, sibling, None) is True
    assert sibling.target_distance == 0

    absent = lua.table_from({
        "gear_id": "missing-defence",
        "base_stat_labels": lua.table_from({"shovel_m1_mobility_stat": "loc_stats_display_mobility_stat"}),
        "potential_base_stats": lua.table_from({"shovel_m1_mobility_stat": 60}),
    })
    assert controller._candidate_is_better(controller, absent, None) is False
    assert absent.target_distance == float("inf")

    ambiguous = lua.table_from({
        "gear_id": "ambiguous-defence",
        "base_stat_labels": lua.table_from({
            "shovel_m1_defence_a": "loc_stats_display_defense_stat",
            "shovel_m1_defence_b": "loc_stats_display_defense_stat",
        }),
        "potential_base_stats": lua.table_from({
            "shovel_m1_defence_a": 60,
            "shovel_m1_defence_b": 60,
        }),
    })
    assert controller._candidate_is_better(controller, ambiguous, None) is False
    assert ambiguous.target_distance == float("inf")

    requested_label = "Use closest fallback candidate weapon if exact stat match weapon is not found"
    assert requested_label in PANEL_PATH.read_text(encoding="utf-8")
    assert requested_label in LOCALIZATION_PATH.read_text(encoding="utf-8")


if __name__ == "__main__":
    main()
