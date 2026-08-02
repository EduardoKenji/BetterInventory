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
			enable_hadron_entreat_grid = true,
			enable_armoury_requisition_grid = true,
			expand_armoury_requisition_window = true,
			armoury_requisition_target_card_width = 230,
            automatic_card_height = true,
			show_weapon_perks = false,
			expand_inventory_window = true,
			expand_curio_inventory_window = true,
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
			curio_stamina_color_preset = "yellow",
			curio_stamina_color_r = 235,
			curio_stamina_color_g = 205,
			curio_stamina_color_b = 80,
        }

        test_layout = {
            is_enabled_for_view = function() return false end,
            expanded_view_definitions = function(_, definitions) return definitions, 0 end,
			expanded_armoury_view_definitions = function(_, definitions)
				definitions.armoury_expanded = true
				return definitions, 114
			end,
            configure_item_blueprint = function() end,
            configure_grid = function() end,
        }

        test_mod = {}
        test_dmf = {
            create_mod_options_settings = function() end,
        }
        captured_options_hook = nil
		captured_item_grid_init_hook = nil
		captured_armoury_on_enter_hook = nil

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
			if method == "init" then
				captured_item_grid_init_hook = callback
			elseif method == "on_enter" then
				captured_armoury_on_enter_hook = callback
			end
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

    credits_view = lua.table_from({"__class_name": "CreditsVendorView"})
    credits_definitions = lua.table_from({})
    original_init = lua.eval(
        "function(view, definitions) view.received_definitions = definitions return 'initialized' end"
    )
    init_result = globals_.captured_item_grid_init_hook(
        original_init, credits_view, credits_definitions, lua.table_from({}), lua.table_from({})
    )
    assert init_result == "initialized"
    assert credits_view._better_inventory_armoury_grid_expansion == 114
    assert credits_view.received_definitions.armoury_expanded is True

    armoury_grid = lua.execute(
        """
        return {
            update_dividers = function(self, top_material, top_size, top_offset, bottom_material, bottom_size, bottom_offset)
                self.top_width = top_size[1]
                self.bottom_width = bottom_size[1]
            end,
        }
        """
    )
    credits_view._item_grid = armoury_grid
    entered = globals_.captured_armoury_on_enter_hook(
        lua.eval("function() return 'entered' end"), credits_view
    )
    assert entered == "entered"
    assert armoury_grid.top_width == 766
    assert armoury_grid.bottom_width == 788

    mod.on_enabled()
    assert settings.curio_stat_compression == "heavy"

    settings._curio_heavy_default_v1_migrated = False
    settings.curio_stat_compression = "none"
    mod.on_enabled()
    assert settings.curio_stat_compression == "none"

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

    settings.curio_stamina_color_preset = "green"
    mod.on_setting_changed("curio_stamina_color_preset")
    assert (
        settings.curio_stamina_color_r,
        settings.curio_stamina_color_g,
        settings.curio_stamina_color_b,
    ) == (105, 210, 120)

    option_ids = (
        "columns",
        "expand_inventory_window",
        "expand_curio_inventory_window",
        "curio_target_card_width",
        "grid_spacing",
        "automatic_card_height",
        "card_height",
        "enable_hadron_entreat_grid",
        "enable_armoury_requisition_grid",
		"expand_armoury_requisition_window",
		"armoury_requisition_target_card_width",
		"weapon_perk_compression",
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
    assert entries_by_id["enable_hadron_entreat_grid"].disabled is False
    assert entries_by_id["enable_armoury_requisition_grid"].disabled is False
    assert entries_by_id["expand_armoury_requisition_window"].disabled is False
    assert entries_by_id["armoury_requisition_target_card_width"].disabled is False
    assert entries_by_id["expand_curio_inventory_window"].disabled is False
    assert entries_by_id["curio_target_card_width"].disabled is False
    assert entries_by_id["weapon_perk_compression"].disabled is True

    settings.show_weapon_perks = True
    mod.on_setting_changed("show_weapon_perks")
    assert entries_by_id["weapon_perk_compression"].disabled is False
    settings.show_weapon_perks = False
    mod.on_setting_changed("show_weapon_perks")
    assert entries_by_id["weapon_perk_compression"].disabled is True

    settings.expand_armoury_requisition_window = False
    mod.on_setting_changed("expand_armoury_requisition_window")
    assert entries_by_id["armoury_requisition_target_card_width"].disabled is True
    settings.expand_armoury_requisition_window = True
    mod.on_setting_changed("expand_armoury_requisition_window")
    assert entries_by_id["armoury_requisition_target_card_width"].disabled is False

    settings.enable_armoury_requisition_grid = False
    mod.on_setting_changed("enable_armoury_requisition_grid")
    assert entries_by_id["expand_armoury_requisition_window"].disabled is True
    assert entries_by_id["armoury_requisition_target_card_width"].disabled is True
    settings.enable_armoury_requisition_grid = True
    mod.on_setting_changed("enable_armoury_requisition_grid")
    assert entries_by_id["expand_armoury_requisition_window"].disabled is False
    assert entries_by_id["armoury_requisition_target_card_width"].disabled is False

    settings.expand_curio_inventory_window = False
    mod.on_setting_changed("expand_curio_inventory_window")
    assert entries_by_id["curio_target_card_width"].disabled is True
    settings.expand_curio_inventory_window = True
    mod.on_setting_changed("expand_curio_inventory_window")
    assert entries_by_id["curio_target_card_width"].disabled is False

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
    assert defaults["enable_hadron_entreat_grid"] is True
    assert defaults["enable_armoury_requisition_grid"] is True
    assert defaults["expand_armoury_requisition_window"] is True
    assert defaults["armoury_requisition_target_card_width"] == 230
    assert defaults["automatic_card_height"] is True
    assert defaults["expand_curio_inventory_window"] is True
    assert defaults["curio_target_card_width"] == 190
    assert defaults["curio_stat_compression"] == "heavy"
    assert defaults["simplify_curio_primary_stat_text"] is True
    assert defaults["remove_curio_stat_plus_signs"] is False
    assert defaults["blessing_icon_spacing"] == 3
    assert defaults["show_weapon_perks"] is False
    assert defaults["weapon_perk_compression"] == "compression"
    assert defaults["show_item_level_icon"] is True
    assert defaults["curio_health_color_preset"] == "red"
    assert defaults["curio_toughness_color_preset"] == "light_blue"
    assert defaults["curio_wound_color_preset"] == "purple"
    assert defaults["curio_stamina_color_preset"] == "yellow"

    print("BetterInventory live setting synchronization tests passed.")


if __name__ == "__main__":
    main()
