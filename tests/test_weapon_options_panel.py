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
            weapon_options_panel_max_height = 360,
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
    assert panel._menu_settings.grid_size[2] == 360
    assert panel._menu_settings.mask_size[2] == 400
    assert panel._better_inventory_weapon_options_overflow is True

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
        assert panel._menu_settings.grid_size[2] == 360
        assert panel._menu_settings.mask_size[2] == 400
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
    mod.settings.weapon_options_panel_max_height = 600
    preserved, handled = panel_module.prepare_layout(
        mod, panel, seven_real, blueprints, view
    )
    assert handled is True
    assert len(preserved) == 7
    assert panel._better_inventory_weapon_options_content_height == 590
    assert panel._menu_settings.grid_size[2] == 590
    assert panel._better_inventory_weapon_options_overflow is False

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
