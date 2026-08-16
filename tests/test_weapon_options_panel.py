from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_weapon_options_panel.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    panel_module = lua.execute(
        MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH)
    )
    same_lua_value = lua.eval("function(left, right) return left == right end")
    mod, panel, view, layout, blueprints = lua.execute(
        r"""
        local settings = {
            debug_weapon_options_button_count = 0,
        }
        local mod = {
            settings = settings,
            get = function(self, setting_id)
                return self.settings[setting_id]
            end,
        }
        local panel = {
            _menu_settings = {
                enable_gamepad_scrolling = false,
                grid_size = {420, 270},
                grid_spacing = {10, 10},
                mask_size = {460, 310},
                top_padding = 30,
            },
            update_grid_height = function(self, grid_height, mask_height)
                self.update_count = (self.update_count or 0) + 1
                self._menu_settings.grid_size[2] = grid_height
                self._menu_settings.mask_size[2] = mask_height
            end,
            _set_scenegraph_position = function(self, scenegraph_id, x, y)
                self.mask_scenegraph_id = scenegraph_id
                self.mask_x = x
                self.mask_y = y
            end,
        }
        local view = {_weapon_options_element = panel}
        local layout = {
            {display_name = "Marks", widget_type = "button"},
            {display_name = "Cosmetics", widget_type = "button"},
            {display_name = "Inspect", widget_type = "button"},
        }
        local blueprints = {button = {size = {420, 60}}}

        return mod, panel, view, layout, blueprints
        """
    )

    unrelated = lua.table_from({"_menu_settings": panel._menu_settings})
    untouched, handled = panel_module.prepare_layout(
        mod, unrelated, layout, blueprints, view
    )
    assert handled is False
    assert same_lua_value(untouched, layout) is True
    assert panel.update_count is None

    native, handled = panel_module.prepare_layout(mod, panel, layout, blueprints, view)
    assert handled is True
    assert len(native) == 3
    assert same_lua_value(native[1], layout[1]) is True
    assert panel._menu_settings.enable_gamepad_scrolling is True
    assert panel._menu_settings.grid_size[2] == 270
    assert panel._menu_settings.mask_size[2] == 310
    assert panel._better_inventory_weapon_options_content_height == 270
    assert panel._better_inventory_weapon_options_viewport_height == 210
    assert panel._better_inventory_weapon_options_overflow is False

    mod.settings.debug_weapon_options_button_count = 5
    five_rows, handled = panel_module.prepare_layout(
        mod, panel, native, blueprints, view
    )
    assert handled is True
    assert len(five_rows) == 5
    assert five_rows[4].display_name == "BetterInventory test button 4"
    assert five_rows[5].display_name == "BetterInventory test button 5"
    assert five_rows[4][panel_module.DEBUG_MARKER] is True
    assert five_rows[4].callback() is None
    assert panel._better_inventory_weapon_options_content_height == 430
    assert panel._better_inventory_weapon_options_viewport_height == 350
    assert panel._menu_settings.grid_size[2] == 430
    assert panel._menu_settings.mask_size[2] == 470
    assert panel._better_inventory_weapon_options_overflow is False

    # Re-presenting a layout already prepared by BetterInventory replaces its
    # filler rows instead of accumulating duplicates.
    repeated, handled = panel_module.prepare_layout(
        mod, panel, five_rows, blueprints, view
    )
    assert handled is True
    assert len(repeated) == 5

    expected_content_heights = {10: 830, 20: 1630}
    for target, expected_height in expected_content_heights.items():
        mod.settings.debug_weapon_options_button_count = target
        prepared, handled = panel_module.prepare_layout(
            mod, panel, repeated, blueprints, view
        )
        assert handled is True
        assert len(prepared) == target
        assert panel._better_inventory_weapon_options_content_height == expected_height
        assert panel._better_inventory_weapon_options_viewport_height == 490
        assert panel._menu_settings.grid_size[2] == 590
        assert panel._menu_settings.mask_size[2] == 551
        assert panel._menu_settings.bottom_chin == 39
        assert panel.mask_scenegraph_id == "grid_mask"
        assert panel.mask_x is None
        assert panel.mask_y == -4.5
        assert panel._better_inventory_weapon_options_overflow is True
        repeated = prepared

    # The dropdown is a minimum total for stress testing. Real actions supplied
    # by other mods are never removed when they already exceed that target.
    seven_real = lua.table_from(
        [
            lua.table_from({"display_name": f"Real {index}", "widget_type": "button"})
            for index in range(1, 8)
        ]
    )
    mod.settings.debug_weapon_options_button_count = 5
    preserved, handled = panel_module.prepare_layout(
        mod, panel, seven_real, blueprints, view
    )
    assert handled is True
    assert len(preserved) == 7
    assert panel._better_inventory_weapon_options_content_height == 590
    assert panel._better_inventory_weapon_options_viewport_height == 490
    assert panel._menu_settings.grid_size[2] == 590
    assert panel._menu_settings.mask_size[2] == 630
    assert panel._menu_settings.bottom_chin is None
    assert panel._better_inventory_weapon_options_overflow is False

    # At overflow, the mask ends exactly where row eight starts. The matching
    # bottom chin makes max scroll align the final row's bottom to that edge.
    ten_row_content_bottom = 30 + 9 * 70 + 60
    active_background_height = 590 - 31
    scroll_area_height = active_background_height - 39 - 30
    maximum_scroll = ten_row_content_bottom - scroll_area_height - 30
    assert 30 + 7 * 70 == 520
    assert ten_row_content_bottom - maximum_scroll == 520

    # A grid that already exists receives the same scrolling contract. This
    # covers another mod re-presenting the action layout after the first draw.
    panel._grid = lua.execute(
        r"""
        return {
            set_enable_gamepad_scrolling = function(self, enabled)
                self.gamepad_scrolling = enabled
            end,
            force_update_list_size = function(self)
                self.force_update_count = (self.force_update_count or 0) + 1
            end,
        }
        """
    )
    mod.settings.debug_weapon_options_button_count = 10
    existing_grid_rows, handled = panel_module.prepare_layout(
        mod, panel, seven_real, blueprints, view
    )
    assert handled is True
    assert len(existing_grid_rows) == 10
    assert panel._grid._bottom_chin == 39
    assert panel._grid.gamepad_scrolling is True
    assert panel._grid.force_update_count == 1

    # Darktide's native resize recenters the mask; the post-resize finalizer
    # must restore BetterInventory's strict overflow boundary.
    panel.mask_y = 15
    assert panel_module.finalize_layout(panel) is True
    assert panel.mask_y == -4.5
    assert panel._grid.force_update_count == 2
    assert panel_module.finalize_layout(unrelated) is False

    malformed_panel = lua.table_from({"_menu_settings": lua.table_from({})})
    malformed_view = lua.table_from({"_weapon_options_element": malformed_panel})
    unchanged, handled = panel_module.prepare_layout(
        mod, malformed_panel, layout, blueprints, malformed_view
    )
    assert handled is False
    assert same_lua_value(unchanged, layout) is True

    print("BetterInventory weapon-options overflow tests passed.")


if __name__ == "__main__":
    main()
