from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_feature_domains.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    domains = lua.execute(MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH))

    grid = lua.table_from(
        {
            "_better_inventory_myfavorites_active": True,
            "_better_inventory_myfavorites_generation": 4,
        }
    )
    assert domains.markers.invalidate_grid(grid) is True
    assert grid._better_inventory_myfavorites_dirty is True
    assert grid._better_inventory_myfavorites_generation == 5
    assert domains.markers.needs_refresh(4, 5, False) is True
    assert domains.markers.needs_refresh(5, 5, False) is False

    inactive_grid = lua.table_from({"_better_inventory_myfavorites_active": False})
    assert domains.markers.invalidate_grid(inactive_grid) is False

    parts = lua.table_from({1: "start", 2: 3, 3: "", 4: "name"})
    assert domains.sorting.signature(parts) == "start|3||name"
    options = lua.table_from([lua.table_from({"id": 1}), lua.table_from({"id": 2})])
    assert domains.sorting.selected_index(options, 0) == 1
    assert domains.sorting.selected_index(options, 99) == 2
    assert domains.sorting.selected_index(lua.table_from([]), 1) is None

    assert domains.panels.composite_key(12, "lantern", "sort") == "12:lantern:sort"
    view = lua.table_from({})
    assert domains.panels.invalidate(view) is True
    assert view._better_inventory_composition_dirty is True
    assert view._better_inventory_composition_generation == 1

    print("BetterInventory feature-domain boundary tests passed.")


if __name__ == "__main__":
    main()
