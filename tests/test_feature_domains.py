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
    assert domains.markers.needs_update() is False

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
    assert domains.markers.release_grid(grid) is True

    inactive_grid = lua.table_from({"_better_inventory_myfavorites_active": False})
    assert domains.markers.invalidate_grid(inactive_grid) is False

    lua.execute(
        """
        marker_refreshes = 0
        marker_last_grid = nil
        function synchronize_marker_grid(item_grid, widgets)
            marker_refreshes = marker_refreshes + 1
            marker_last_grid = item_grid
            assert(next(widgets) ~= nil)
        end
        """
    )
    tracked_widget = lua.table_from({"name": "tracked"})
    tracked_widgets = lua.table()
    tracked_widgets[tracked_widget] = True
    tracked_grid = lua.table_from(
        {
            "_better_inventory_myfavorites_active": True,
            "_better_inventory_myfavorites_widgets": tracked_widgets,
        }
    )
    assert domains.markers.track_grid(tracked_grid) is True
    assert domains.markers.needs_update() is True
    assert domains.markers.invalidate_grid(tracked_grid) is True
    assert domains.markers.update(0, lua.globals().synchronize_marker_grid) == 1
    assert lua.globals().marker_refreshes == 1
    assert domains.markers.update(0.5, lua.globals().synchronize_marker_grid) == 0

    # Generation polling replaces a hook on every ViewElementGrid update.
    tracked_grid._grid_generation = 2
    assert domains.markers.update(0.5, lua.globals().synchronize_marker_grid) == 1
    assert lua.globals().marker_refreshes == 2

    # Hidden grids keep one dirty token but perform no item-card traversal.
    tracked_grid._visible = False
    assert domains.markers.invalidate_grid(tracked_grid) is True
    assert domains.markers.update(0, lua.globals().synchronize_marker_grid) == 0
    assert tracked_grid._better_inventory_myfavorites_dirty is True
    tracked_grid._visible = True
    assert domains.markers.update(0, lua.globals().synchronize_marker_grid) == 1
    assert tracked_grid._better_inventory_myfavorites_dirty is False

    tracked_count, dirty_count = domains.markers.count()
    assert tracked_count == 1
    assert dirty_count == 0
    assert domains.markers.release_grid(tracked_grid) is True
    assert tracked_grid._better_inventory_myfavorites_widgets is None
    assert tracked_grid._better_inventory_myfavorites_active is None
    assert domains.markers.count() == (0, 0)
    assert domains.markers.needs_update() is False

    for _ in range(250):
        cycled_grid = lua.table_from(
            {
                "_better_inventory_myfavorites_active": True,
                "_better_inventory_myfavorites_widgets": lua.table_from(
                    {lua.table_from({"name": "widget"}): True}
                ),
            }
        )
        assert domains.markers.track_grid(cycled_grid) is True
        assert domains.markers.invalidate_grid(cycled_grid) is True
        assert domains.markers.release_grid(cycled_grid) is True
    assert domains.markers.count() == (0, 0)

    release_grids = []
    for _ in range(3):
        release_grid = lua.table_from(
            {"_better_inventory_myfavorites_active": True}
        )
        release_grids.append(release_grid)
        domains.markers.track_grid(release_grid)
        domains.markers.invalidate_grid(release_grid)
    assert domains.markers.release_all() == 3
    assert domains.markers.count() == (0, 0)
    assert domains.markers.needs_update() is False

    # Hundreds of unrelated UI grids never enter BetterInventory's registry.
    unrelated_grids = [lua.table_from({"_visible": True}) for _ in range(500)]
    assert domains.markers.update(1, lua.globals().synchronize_marker_grid) == 0
    assert lua.globals().marker_refreshes == 3

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

    # God Stat Checker can grow CreditsVendorView's live detail panel through
    # Darktide's fixed Acquire slot. Anchor the action row immediately below
    # the final panel rectangle, without requiring Quick Level Mastery.
    vendor_view = lua.execute(
        """
        local view = {
            _widgets_by_name = {
                purchase_button = {offset = {0, 0, 0}},
            },
            _ui_scenegraph = {
                purchase_button = {
                    position = {857, -90, 1},
                    size = {374, 76, 0},
                },
            },
            _world_position = {
                purchase_button = {857, 914, 1},
            },
        }

        view._weapon_stats = {
            _pivot_offset = {780, 80, 3},
            _world_position = {780, 80, 3},
            _ui_scenegraph = {
                grid_background = {size = {530, 920, 0}},
            },
            scenegraph_world_position = function(self, id)
                self.position_queries = (self.position_queries or 0) + 1
                return self._world_position
            end,
            _scenegraph_size = function(self, id)
                self.size_queries = (self.size_queries or 0) + 1
                local size = self._ui_scenegraph[id].size
                return size[1], size[2]
            end,
            _force_update_scenegraph = function(self)
                self.force_update_calls = (self.force_update_calls or 0) + 1
            end,
        }
        view._scenegraph_world_position = function(self, id)
            self.position_queries = (self.position_queries or 0) + 1
            return self._world_position[id]
        end
        view._set_scenegraph_position = function(self, id, x, y, z)
            local node = self._ui_scenegraph[id]
            local world = self._world_position[id]
            world[1] = world[1] + x - node.position[1]
            world[2] = world[2] + y - node.position[2]
            node.position[1], node.position[2], node.position[3] = x, y, z
            self.position_writes = (self.position_writes or 0) + 1
        end

        return view
        """
    )
    action_alignment = domains.quick_level_alignment
    assert action_alignment.update(vendor_view, None, True) is True
    assert vendor_view._ui_scenegraph.purchase_button.position[1] == 857
    assert vendor_view._ui_scenegraph.purchase_button.position[2] == 4
    assert vendor_view._world_position.purchase_button[2] == 1008
    assert vendor_view.position_writes == 1

    # Stable frames only compare scalar geometry and do not query or rewrite
    # the scenegraph. A live height change wakes reconciliation immediately.
    assert action_alignment.update(vendor_view, None, True) is False
    assert vendor_view._weapon_stats.force_update_calls == 1
    vendor_view._weapon_stats._ui_scenegraph.grid_background.size[2] = 880
    assert action_alignment.update(vendor_view, None, True) is True
    assert vendor_view._ui_scenegraph.purchase_button.position[2] == -36
    assert vendor_view._world_position.purchase_button[2] == 968
    assert vendor_view.position_writes == 2

    # Removing GSC restores the captured native coordinate. Short panels stay
    # native, and releasing a live view restores only BI's owned Y write.
    assert action_alignment.update(vendor_view, None, False) is True
    assert vendor_view._ui_scenegraph.purchase_button.position[2] == -90
    vendor_view._weapon_stats._ui_scenegraph.grid_background.size[2] = 700
    assert action_alignment.update(vendor_view, None, True) is True
    assert vendor_view._ui_scenegraph.purchase_button.position[2] == -90
    assert vendor_view.position_writes == 3
    vendor_view._weapon_stats._ui_scenegraph.grid_background.size[2] = 920
    assert action_alignment.update(vendor_view, None, True) is True
    assert vendor_view._ui_scenegraph.purchase_button.position[2] == 4
    assert action_alignment.release(vendor_view) is True
    assert vendor_view._ui_scenegraph.purchase_button.position[2] == -90
    assert vendor_view._better_inventory_quick_level_alignment_probe is None

    print("BetterInventory feature-domain boundary tests passed.")


if __name__ == "__main__":
    main()
