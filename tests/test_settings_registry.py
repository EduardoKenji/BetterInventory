from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime
from localization_support import load_localization


PROJECT_ROOT = Path(__file__).resolve().parents[1]
REGISTRY_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_settings.lua"
)
DATA_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_data.lua"
)
LOCALIZATION_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_localization.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    registry = lua.execute(
        REGISTRY_PATH.read_text(encoding="utf-8"), name=str(REGISTRY_PATH)
    )

    settings = lua.table_from(
        [
            lua.table_from(
                {
                    "setting_id": "root",
                    "sub_widgets": lua.table_from(
                        [
                            lua.table_from({"setting_id": "child"}),
                            lua.table_from(
                                {"setting_id": "automatic_curio_character_slot_1"}
                            ),
                        ]
                    ),
                }
            )
        ]
    )
    ok, count, duplicates = registry.register(settings)

    assert ok is True
    assert count == 3
    assert len(duplicates) == 0
    assert registry.has("child") is True
    assert registry.metadata("child").setting_id == "child"
    assert registry.metadata("child").owner == "general"
    assert registry.metadata("child").visibility == "always"
    assert registry.metadata("child").test_id == "settings:child"
    assert registry.is_visible("child") is True
    assert registry.should_refresh_dependencies("child") is False
    assert registry.should_refresh_dependencies("automatic_curio_character_slot_1") is True

    duplicate_settings = lua.table_from(
        [
            lua.table_from({"setting_id": "duplicate"}),
            lua.table_from({"setting_id": "duplicate"}),
        ]
    )
    ok, count, duplicates = registry.register(duplicate_settings)

    assert ok is False
    assert count == 1
    assert duplicates[1] == "duplicate"

    lua.execute(
        "function get_mod() return {localize = function(_, id) return id end} end; "
        "function require(_) return {max_num_characters = 10} end"
    )
    data = lua.execute(DATA_PATH.read_text(encoding="utf-8"), name=str(DATA_PATH))
    localization = load_localization(lua, LOCALIZATION_PATH)
    ok, count, duplicates = registry.register(data.options.widgets)

    assert ok is True
    assert count >= 200
    assert len(duplicates) == 0
    assert registry.has("automatic_curio_character_slot_10") is True
    assert registry.metadata("automatic_curio_character_slot_10").owner == "curio_acquisition"
    assert registry.metadata("automatic_curio_character_slot_10").default_value is False
    assert registry.is_visible("enable_grid_layout", lua.table_from({"dependencies_enabled": False})) is False
    assert registry.is_visible("enable_grid_layout", lua.table_from({"dependencies_enabled": True})) is True
    manifest = registry.metadata_manifest()
    assert len(manifest) == count
    assert manifest[1].setting_id == "additional_views_group"
    audit = registry.audit(localization)
    assert audit.active_count == count
    assert len(audit.duplicate_ids) == 0
    assert len(audit.metadata_issues) == 0
    assert len(audit.missing_localization) == 0
    assert len(audit.orphan_metadata) == 0
    assert len(audit.unregistered_active_settings) == 0

    incomplete_settings = lua.table_from(
        [lua.table_from({"setting_id": "missing_metadata"})]
    )
    registry.register(incomplete_settings)
    incomplete_audit = registry.audit(lua.table_from({}))
    assert incomplete_audit.unregistered_active_settings[1] == "missing_metadata:title_id=missing_metadata"
    assert incomplete_audit.unregistered_active_settings[2] == "missing_metadata:type"

    print("BetterInventory settings registry tests passed.")


if __name__ == "__main__":
    main()
