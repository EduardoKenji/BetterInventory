from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_item_customization.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r"""
        function table.clone(value)
            if type(value) ~= "table" then
                return value
            end

            local copy = {}

            for key, child in pairs(value) do
                copy[table.clone(key)] = table.clone(child)
            end

            return copy
        end

        Color = {
            white = function(alpha) return { alpha, 255, 255, 255 } end,
            terminal_corner_hover = function(alpha) return { alpha, 90, 100, 80 } end,
        }

        function require(path)
            if string.find(path, "slider_pass_templates", 1, true) then
                return {
                    value_slider = function() return {} end,
                }
            elseif string.find(path, "ui_font_settings", 1, true) then
                return {
                    body = {},
                }
            elseif string.find(path, "popup_handler_settings", 1, true) then
                return {
                    text_max_width = 800,
                }
            end

            return {}
        end

        settings = {}
        name_it_settings = { name_list = {} }
        test_name_it_mod = {}

        function test_name_it_mod:get(setting_id)
            return name_it_settings[setting_id]
        end

        function test_name_it_mod:set(setting_id, value)
            name_it_settings[setting_id] = value
        end

        function test_name_it_mod.get_custom_name_list()
            return name_it_settings.name_list
        end

        function get_mod(name)
            return name == "name_it" and test_name_it_mod or nil
        end

        test_mod = {}

        function test_mod:get(setting_id)
            local value = settings[setting_id]

            return type(value) == "table" and table.clone(value) or value
        end

        function test_mod:set(setting_id, value)
            settings[setting_id] = type(value) == "table" and table.clone(value) or value
        end

        captured_hooks = {}

        function test_mod:add_global_localize_strings(strings)
            global_strings = strings
        end

        function test_mod:hook_require() end

        function test_mod:hook(target, method, callback)
            captured_hooks[method] = callback
        end

        function test_mod:hook_safe() end

        captured_popup = nil
        Managers = {
            event = {
                trigger = function(self, event_name, context)
                    assert(event_name == "event_show_ui_popup")
                    captured_popup = context
                end,
            },
        }
        """
    )
    customization = lua.execute(MODULE_PATH.read_text(encoding="utf-8"))
    globals_ = lua.globals()
    mod = globals_.test_mod
    settings = globals_.settings

    customization.on_enabled(mod)
    assert len(settings.custom_item_name_and_colors) == 0

    changes = lua.table_from(
        {
            "name": "Test",
            "name_color": lua.table_from([255, 10, 20, 30]),
            "background_color": lua.table_from([255, 40, 50, 60]),
        }
    )
    assert customization.update(mod, "gear-1", changes) is True
    record = customization.get(mod, "gear-1")
    assert record.name == "Test"
    assert tuple(record.name_color[index] for index in range(1, 5)) == (
        255,
        10,
        20,
        30,
    )
    assert customization.remove(mod, "gear-1") is True
    assert customization.get(mod, "gear-1") is None

    context = lua.table_from({"gear_id": "gear-1", "name": "Test Item"})
    assert customization.show_color_picker(mod, "name", context, None) is True
    popup = globals_.captured_popup
    assert popup.type == "grid"
    assert popup.title_text_unlocalized == "Change item name color(Test Item)"
    assert len(popup.grid_layout) == 4
    assert len(popup.options) == 3
    assert [popup.options[index].text for index in range(1, 4)] == [
        "Confirm",
        "Reset to default",
        "Cancel",
    ]
    assert all(popup.options[index].no_localization is True for index in range(1, 4))

    slider_blueprint = popup.grid_blueprints.color_slider
    red_element = popup.grid_layout[2]
    red_widget = lua.table_from({"content": lua.table_from({}), "style": lua.table_from({})})
    slider_blueprint.init(None, red_widget, red_element)
    red_widget.content.slider_value = 0.5
    slider_blueprint.update(None, red_widget)
    popup.options[1].callback()
    stored_color = customization.get(mod, "gear-1").name_color
    assert stored_color[2] == 128

    customization.show_color_picker(mod, "background", context, None)
    popup = globals_.captured_popup
    popup.options[1].callback()
    stored_background = customization.get(mod, "gear-1").background_color
    assert tuple(stored_background[index] for index in range(1, 5)) == (
        255,
        45,
        55,
        45,
    )

    popup.options[2].callback()
    assert customization.get(mod, "gear-1").background_color is None

    globals_.name_it_settings.name_list["legacy-gear"] = "Legacy Name"
    assert customization.import_name_it_names(mod) == 1
    assert customization.get(mod, "legacy-gear").name == "Legacy Name"
    assert customization.get(mod, "legacy-gear").name_target == "primary"

    globals_.name_it_settings.replace_pattern_name = True
    globals_.name_it_settings.name_list["legacy-pattern"] = "Legacy Pattern Name"
    assert customization.import_name_it_names(mod) == 1
    assert customization.get(mod, "legacy-pattern").name_target == "sub"

    customization.update(
        mod, "legacy-gear", lua.table_from({"name": "BetterInventory Name"})
    )
    assert globals_.name_it_settings.name_list["legacy-gear"] == "BetterInventory Name"

    customization.remove(mod, "legacy-gear")
    assert globals_.name_it_settings.name_list["legacy-gear"] is None

    settings.custom_item_name_keybind = "hotkey_menu_special_1"
    settings.custom_item_name_color_keybind = "hotkey_menu_special_1"
    settings.custom_item_background_color_keybind = "group_finder_refresh_groups"
    globals_.name_it_settings.keybind_change_name = "hotkey_menu_special_2"
    inventory_view_class = lua.table_from({})
    assert customization.install(mod, inventory_view_class, lua.table_from({})) is True
    view = lua.table_from(
        {
            "_definitions": lua.table_from(
                {
                    "legend_inputs": lua.table_from(
                        [
                            lua.table_from(
                                {
                                    "input_action": "hotkey_menu_special_2",
                                    "on_pressed_callback": "cb_on_change_name_pressed",
                                }
                            )
                        ]
                    )
                }
            )
        }
    )
    globals_.captured_hooks.init(lua.eval("function() end"), view)
    globals_.captured_hooks._setup_input_legend(
        lua.eval(
            "function(view) built_legend = table.clone(view._definitions.legend_inputs) end"
        ),
        view,
    )
    legend = view._definitions.legend_inputs
    built_legend = globals_.built_legend
    assert len(legend) == 3
    assert len(built_legend) == 3
    assert [legend[index].display_name for index in range(1, 4)] == [
        "better_inventory_change_name",
        "better_inventory_name_color",
        "better_inventory_background_color",
    ]
    assert [legend[index].input_action for index in range(1, 4)] == [
        "hotkey_menu_special_2",
        "hotkey_menu_special_1",
        "group_finder_refresh_groups",
    ]
    assert [built_legend[index].input_action for index in range(1, 4)] == [
        "hotkey_menu_special_2",
        "hotkey_menu_special_1",
        "group_finder_refresh_groups",
    ]
    assert all(
        legend[index].on_pressed_callback != "cb_on_change_name_pressed"
        for index in range(1, 4)
    )

    print("BetterInventory item customization tests passed.")


if __name__ == "__main__":
    main()
