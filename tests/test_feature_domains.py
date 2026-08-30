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

    # GlobalStore's card binder writes "class-glyph operative-name" into one
    # field. BetterInventory owns separate glyph and name passes, so retained
    # widgets must be normalized after both full presents and search reorders.
    # Repeating the repair is idempotent, while a later GlobalStore rebind of
    # the combined value is detected without allocating replacement cards.
    owner_widget = lua.table_from(
        {
            "content": lua.table_from(
                {"character_info_text": "ICON Point And Click"}
            ),
            "style": lua.table_from(
                {
                    "portrait": lua.table_from({"size": lua.table_from([44, 44])}),
                    "character_info_text": lua.table(),
                    "character_class_icon_text": lua.table(),
                }
            ),
        }
    )
    unrelated_widget = lua.table_from(
        {
            "content": lua.table_from({"character_info_text": "native"}),
            "style": lua.table_from(
                {"portrait": lua.table_from({"size": lua.table_from([55, 55])})}
            ),
        }
    )
    normalize_grid = lua.table_from(
        {
            "_widgets_by_entry_id": lua.table_from(
                {
                    "owner": lua.table_from({"widget": owner_widget}),
                    "native": lua.table_from({"widget": unrelated_widget}),
                }
            )
        }
    )
    global_store = domains.global_store
    assert global_store.normalize_widgets(normalize_grid, 37) == (1, 1)
    assert owner_widget.content.character_class_icon_text == "ICON"
    assert owner_widget.content.character_info_text == "Point And Click"
    assert (
        owner_widget.content.better_inventory_global_store_character_name
        == "Point And Click"
    )
    assert list(owner_widget.style.portrait.size.values()) == [37, 37]
    assert list(unrelated_widget.style.portrait.size.values()) == [55, 55]
    assert global_store.normalize_widgets(normalize_grid, 37) == (0, 0)
    assert owner_widget.content.character_info_text == "Point And Click"
    owner_widget.content.character_info_text = "ICON Point And Click"
    assert global_store.normalize_widgets(normalize_grid, 37) == (1, 0)
    assert owner_widget.content.character_info_text == "Point And Click"

    # GlobalStore retains portrait callbacks unless each outgoing card load is
    # explicitly unloaded before Darktide destroys the grid generation. Stress
    # disjoint 150-card tabs and prove retained resources remain bounded to the
    # current generation while marker reconciliation drops retired widgets.
    lua.execute(
        r'''
        portrait_resources = {}
        portrait_unloads = 0

        function unload_portrait(load_id)
            portrait_resources[load_id] = nil
            portrait_unloads = portrait_unloads + 1
        end

        portrait_manager = {
            unload_profile_portrait = function(_, load_id)
                unload_portrait(load_id)
            end
        }

        function install_portrait_generation(grid, generation, count)
            local widgets = {}
            local widget_map = {}
            local layout = {}

            for index = 1, count do
                local load_id = tostring(generation) .. ":" .. tostring(index)
                local widget = {content = {portrait_load_id = load_id}}
                local entry_id = "entry:" .. tostring(generation) .. ":" .. tostring(index)

                widgets[index] = widget
                widget_map[entry_id] = {widget = widget}
                layout[index] = {entry_id = entry_id}
                -- Model Managers.ui retaining callbacks/widgets until unload.
                portrait_resources[load_id] = widget
            end

            grid._all_grid_widgets = widgets
            grid._widgets_by_entry_id = widget_map
            grid._grid_layout = layout
            grid._better_inventory_myfavorites_active = true
            grid._better_inventory_myfavorites_widgets = setmetatable({}, {__mode = "k"})

            for index = 1, count do
                grid._better_inventory_myfavorites_widgets[widgets[index]] = true
            end
        end

        function resource_count()
            local count = 0
            for _ in pairs(portrait_resources) do count = count + 1 end
            return count
        end

        function marker_count(grid)
            local count = 0
            for _ in pairs(grid._better_inventory_myfavorites_widgets or {}) do count = count + 1 end
            return count
        end
        ''',
    )
    global_grid = lua.table()
    lua.globals().install_portrait_generation(global_grid, 1, 150)
    empty_grid = lua.table_from({"_grid_layout": lua.table()})
    assert global_store.grid_rebuild_required(empty_grid, lua.table()) is True
    assert global_store.grid_rebuild_required(
        global_grid, global_grid._grid_layout
    ) is False
    assert global_store.retire_grid_generation(
        global_grid, global_grid._grid_layout, lua.globals().portrait_manager
    ) == (0, False)

    for generation in range(2, 42):
        incoming = lua.table_from(
            {1: lua.table_from({"entry_id": f"new:{generation}"})}
        )
        released, rebuilding = global_store.retire_grid_generation(
            global_grid, incoming, lua.globals().portrait_manager
        )
        assert rebuilding is True
        assert released == 150
        assert lua.globals().marker_count(global_grid) == 0
        lua.globals().install_portrait_generation(global_grid, generation, 150)
        assert lua.globals().resource_count() == 150

    assert lua.globals().portrait_unloads == 40 * 150
    assert global_store.grid_rebuild_required(global_grid, None) is False
    assert global_store.retire_grid_generation(global_grid, lua.table(), None) == (
        0,
        False,
    )
    missing_unloader_layout = lua.table_from(
        {1: lua.table_from({"entry_id": "unseen"})}
    )
    assert global_store.retire_grid_generation(
        global_grid, missing_unloader_layout, None
    ) == (0, True)

    print("BetterInventory feature-domain boundary tests passed.")


if __name__ == "__main__":
    main()
