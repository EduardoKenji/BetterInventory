from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MAIN_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory.lua"
DATA_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_data.lua"
LOCALIZATION_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_localization.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r"""
        settings = {
            enable_grid_layout = true,
            automatic_card_height = true,
            curio_health_color_preset = "red",
            curio_health_color_r = 235,
            curio_health_color_g = 85,
            curio_health_color_b = 85,
            curio_toughness_color_preset = "light_blue",
            curio_toughness_color_r = 105,
            curio_toughness_color_g = 200,
            curio_toughness_color_b = 235,
            curio_wound_color_preset = "purple",
            curio_wound_color_r = 190,
            curio_wound_color_g = 105,
            curio_wound_color_b = 230,
        }

        test_layout = {
            is_enabled_for_view = function() return false end,
            expanded_view_definitions = function(_, definitions) return definitions, 0 end,
            configure_item_blueprint = function() end,
            configure_grid = function() end,
        }

        test_mod = {}
        test_dmf = {
            create_mod_options_settings = function() end,
        }
        captured_options_hook = nil

        function test_mod:get(setting_id)
            return settings[setting_id]
        end

        function test_mod:set(setting_id, value, notify)
            settings[setting_id] = value
        end

        function test_mod:localize(localization_id)
            return localization_id
        end

        function test_mod:get_readable_name()
            return "Better Inventory"
        end

        function test_mod:io_dofile(path)
            return test_layout
        end

        function test_mod:hook(target, method, callback)
        end

        function test_mod:hook_safe(target, method, callback)
            if target == test_dmf and method == "create_mod_options_settings" then
                captured_options_hook = callback
            end
        end

        function get_mod(name)
            if name == "BetterInventory" then
                return test_mod
            end

            if name == "DMF" then
                return test_dmf
            end
        end

        function require(path)
            return {}
        end
        """
    )
    lua.execute(MAIN_PATH.read_text(encoding="utf-8"))
    globals_ = lua.globals()
    mod = globals_.test_mod
    settings = globals_.settings

    settings.curio_health_color_preset = "light_blue"
    mod.on_setting_changed("curio_health_color_preset")
    assert (
        settings.curio_health_color_r,
        settings.curio_health_color_g,
        settings.curio_health_color_b,
    ) == (105, 200, 235)

    settings.curio_health_color_r = 17
    mod.on_setting_changed("curio_health_color_r")
    assert settings.curio_health_color_preset == "custom"

    settings.curio_health_color_preset = "custom"
    settings.curio_health_color_g = 44
    mod.on_setting_changed("curio_health_color_preset")
    assert (settings.curio_health_color_r, settings.curio_health_color_g) == (17, 44)

    option_ids = (
        "columns",
        "expand_inventory_window",
        "grid_spacing",
        "automatic_card_height",
        "card_height",
    )
    entries = [
        lua.table_from(
            {
                "category": "Better Inventory",
                "display_name": option_id,
            }
        )
        for option_id in option_ids
    ]
    options_templates = lua.table_from(
        {"settings": lua.table_from(entries)}
    )

    globals_.captured_options_hook(globals_.test_dmf, options_templates)
    entries_by_id = dict(zip(option_ids, entries))

    assert entries_by_id["columns"].disabled is False
    assert entries_by_id["automatic_card_height"].disabled is False
    assert entries_by_id["card_height"].disabled is True

    settings.automatic_card_height = False
    mod.on_setting_changed("automatic_card_height")
    assert entries_by_id["card_height"].disabled is False

    settings.enable_grid_layout = False
    mod.on_setting_changed("enable_grid_layout")

    for option_id in option_ids:
        assert entries_by_id[option_id].disabled is True

    data = lua.execute(DATA_PATH.read_text(encoding="utf-8"))
    localization = lua.execute(LOCALIZATION_PATH.read_text(encoding="utf-8"))
    defaults = {}

    def inspect_widgets(widgets) -> None:
        for index in range(1, len(widgets) + 1):
            widget = widgets[index]
            setting_id = widget.setting_id

            assert localization[setting_id] is not None, setting_id

            if widget.default_value is not None:
                defaults[setting_id] = widget.default_value

            options = widget.options

            if options is not None:
                for option_index in range(1, len(options) + 1):
                    assert localization[options[option_index].text] is not None

            sub_widgets = widget.sub_widgets

            if sub_widgets is not None:
                inspect_widgets(sub_widgets)

    inspect_widgets(data.options.widgets)

    assert defaults["enable_grid_layout"] is True
    assert defaults["automatic_card_height"] is True
    assert defaults["compact_curio_stat_text"] is True
    assert defaults["curio_health_color_preset"] == "red"
    assert defaults["curio_toughness_color_preset"] == "light_blue"
    assert defaults["curio_wound_color_preset"] == "purple"

    print("BetterInventory live setting synchronization tests passed.")


if __name__ == "__main__":
    main()
