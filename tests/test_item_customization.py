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
        test_mod = {}

        function test_mod:get(setting_id)
            local value = settings[setting_id]

            return type(value) == "table" and table.clone(value) or value
        end

        function test_mod:set(setting_id, value)
            settings[setting_id] = type(value) == "table" and table.clone(value) or value
        end

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

    settings.custom_item_name_color_picker_spike = True
    assert (
        customization.on_setting_changed(mod, "custom_item_name_color_picker_spike")
        is True
    )
    assert settings.custom_item_name_color_picker_spike is False
    popup = globals_.captured_popup
    assert popup.type == "grid"
    assert popup.title_text == "custom_item_name_color_picker_title"
    assert len(popup.grid_layout) == 4
    assert len(popup.options) == 3

    slider_blueprint = popup.grid_blueprints.color_slider
    red_element = popup.grid_layout[2]
    red_widget = lua.table_from({"content": lua.table_from({}), "style": lua.table_from({})})
    slider_blueprint.init(None, red_widget, red_element)
    red_widget.content.slider_value = 0.5
    slider_blueprint.update(None, red_widget)
    popup.options[1].callback()
    stored_color = settings.custom_item_name_color_picker_value
    assert stored_color[2] == 128

    settings.custom_item_background_color_picker_spike = True
    customization.on_setting_changed(mod, "custom_item_background_color_picker_spike")
    popup = globals_.captured_popup
    popup.options[2].callback()
    popup.options[1].callback()
    stored_background = settings.custom_item_background_color_picker_value
    assert tuple(stored_background[index] for index in range(1, 5)) == (
        255,
        45,
        55,
        45,
    )

    print("BetterInventory item customization spike tests passed.")


if __name__ == "__main__":
    main()
