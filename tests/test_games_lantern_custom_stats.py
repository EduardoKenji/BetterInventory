from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PLANNER_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "core" / "planner.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)

    def to_lua(value):
        if isinstance(value, dict):
            return lua.table_from({key: to_lua(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([to_lua(item) for item in value])
        return value

    planner = lua.execute(PLANNER_PATH.read_text(encoding="utf-8"), name=str(PLANNER_PATH))
    offer = to_lua({
        "master_id": "plasmagun_p1_m1",
        "price_amount": 9200,
        "price_type": "credits",
        "base_stats": [
            {"name": "damage_stat", "display_name_key": "Damage"},
            {"name": "heat_stat", "display_name_key": "Heat Management"},
            {"name": "ammo_stat", "display_name_key": "Ammo"},
            {"name": "power_stat", "display_name_key": "Stopping Power"},
            {"name": "charge_speed_stat", "display_name_key": "Charge Rate"},
        ],
    })
    snapshot = to_lua({
        "store": {"available": True},
        "wallets": {"currencies": {"credits": {"amount": 1_000_000}}},
    })

    # Imported targets deliberately arrive in website order, which is not the
    # planner's semantic sort order. Values must bind to exact stat identities,
    # never to whichever entry happens to share the same array index.
    imported_targets = [
        {"name": "charge_speed_stat", "display_name_key": "Charge Rate", "value": 70},
        {"name": "ammo_stat", "display_name_key": "Ammo", "value": 80},
        {"name": "power_stat", "display_name_key": "Stopping Power", "value": 80},
        {"name": "heat_stat", "display_name_key": "Heat Management", "value": 70},
        {"name": "damage_stat", "display_name_key": "Damage", "value": 80},
    ]
    plan = planner.build(snapshot, to_lua({
        "target_offer": offer,
        "custom_stats_enabled": True,
        "custom_stat_targets": imported_targets,
    }))
    assert plan.custom_stats_valid is True
    assert plan.custom_stat_total == 380
    assert plan.custom_stat_target_map["charge_speed_stat"] == 70
    assert plan.custom_stat_target_map["heat_stat"] == 70
    assert plan.custom_stat_target_map["damage_stat"] == 80
    assert plan.custom_stat_target_map["ammo_stat"] == 80
    assert plan.custom_stat_target_map["power_stat"] == 80

    malformed = [dict(target) for target in imported_targets]
    malformed[1]["name"] = "charge_speed_stat"
    malformed_plan = planner.build(snapshot, to_lua({
        "target_offer": offer,
        "custom_stats_enabled": True,
        "custom_stat_targets": malformed,
    }))
    assert malformed_plan.custom_stats_valid is False
    assert malformed_plan.preflight.ok is False
    assert "missing or ambiguous" in malformed_plan.preflight.summary


if __name__ == "__main__":
    main()
