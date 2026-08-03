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
			columns = 3,
            enable_grid_layout = true,
			enable_hadron_entreat_grid = true,
			enable_armoury_requisition_grid = true,
			expand_armoury_requisition_window = true,
			armoury_requisition_target_card_width = 230,
			automatic_card_height = true,
			show_weapon_perks = false,
			show_weapon_blessings = true,
			weapon_blessing_display_mode = "icons",
			blessing_text_item_level_separation = "four_plus",
			show_weapon_perk_rank_symbols = false,
			weapon_perk_rank_icon_size = 18,
			blessing_icon_size = 34,
			blessing_icon_spacing = 3,
			weapon_blessing_text_vertical_spacing = 2,
			weapon_blessing_text_bottom_padding = 4,
			weapon_blessing_text_color_preset = "sky_blue",
			weapon_blessing_text_color_r = 144,
			weapon_blessing_text_color_g = 213,
			weapon_blessing_text_color_b = 255,
			weapon_blessing_text_opacity = 100,
			remove_weapon_perk_plus_signs = false,
			weapon_perk_vertical_spacing = 2,
			weapon_perk_blessing_spacing = 5,
			weapon_perk_text_color_preset = "light_green",
			weapon_perk_text_color_r = 190,
			weapon_perk_text_color_g = 210,
			weapon_perk_text_color_b = 180,
			weapon_perk_text_opacity = 100,
			curio_display_profile = "primary",
			show_curio_item_level = true,
			expand_inventory_window = true,
			weapon_extra_width_column_threshold = "four_plus",
			five_column_weapon_extra_width = 80,
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
			curio_secondary_text_color_preset = "neutral",
			curio_secondary_text_color_r = 220,
			curio_secondary_text_color_g = 230,
			curio_secondary_text_color_b = 210,
			enable_experimental_quick_discard = false,
			quick_discard_protect_high_level_curios = true,
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
		inventory_sort_syncs = 0
		quick_discard_syncs = 0
		test_features = {
			add_inventory_sort_toggle_definition = function(_, _, definitions) return definitions end,
			configure_inventory_sort_options = function() end,
			setup_inventory_options_panel = function() end,
			bind_inventory_sort_toggle = function() end,
			resort_inventory = function() end,
			update_inventory_sort_toggle = function() end,
			sync_inventory_sort_setting = function() inventory_sort_syncs = inventory_sort_syncs + 1 end,
			sync_quick_discard_settings = function() quick_discard_syncs = quick_discard_syncs + 1 end,
			unregister_inventory_view = function() end,
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
			if string.find(path, "BetterInventory_features", 1, true) then
				return test_features
			end

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

    # CreditsVendorView is also reused by GlobalStore. Its custom cards add a
    # portrait footer, so BetterInventory must leave that route completely native.
    custom_credits_view = lua.table_from(
        {
            "__class_name": "CreditsVendorView",
            "_optional_store_service": "get_all_characters_store_custom",
            "_item_grid": lua.execute(
                "return {update_dividers = function(self) self.updated = true end}"
            ),
        }
    )
    custom_definitions = lua.table_from({})
    globals_.captured_item_grid_init_hook(
        original_init,
        custom_credits_view,
        custom_definitions,
        lua.table_from({}),
        lua.table_from({}),
    )
    assert custom_credits_view._better_inventory_armoury_grid_expansion is None
    assert custom_credits_view.received_definitions.armoury_expanded is None
    globals_.captured_armoury_on_enter_hook(
        lua.eval("function() return 'custom_entered' end"), custom_credits_view
    )
    assert custom_credits_view._item_grid.updated is None

    mod.on_enabled()
    assert settings.curio_stat_compression == "heavy"
    assert settings.blessing_icon_size == 36
    assert settings.weapon_perk_rank_icon_size == 17
    assert settings.weapon_blessing_display_mode == "icons"

    settings._weapon_blessing_display_mode_v1_migrated = False
    settings.show_weapon_blessings = False
    mod.on_enabled()
    assert settings.weapon_blessing_display_mode == "off"

    settings._weapon_blessing_display_mode_v1_migrated = False
    settings.show_weapon_blessings = None
    settings.weapon_blessing_display_mode = "ranked_text"
    mod.on_enabled()
    assert settings.weapon_blessing_display_mode == "ranked_text"

    settings.show_weapon_blessings = True
    settings.weapon_blessing_display_mode = "icons"

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

    settings.weapon_perk_text_color_preset = "neutral"
    mod.on_setting_changed("weapon_perk_text_color_preset")
    assert (
        settings.weapon_perk_text_color_r,
        settings.weapon_perk_text_color_g,
        settings.weapon_perk_text_color_b,
    ) == (220, 230, 210)

    settings.weapon_perk_text_color_b = 77
    mod.on_setting_changed("weapon_perk_text_color_b")
    assert settings.weapon_perk_text_color_preset == "custom"

    settings.weapon_blessing_text_color_preset = "sky_blue"
    mod.on_setting_changed("weapon_blessing_text_color_preset")
    assert (
        settings.weapon_blessing_text_color_r,
        settings.weapon_blessing_text_color_g,
        settings.weapon_blessing_text_color_b,
    ) == (144, 213, 255)

    settings.weapon_blessing_text_color_r = 42
    mod.on_setting_changed("weapon_blessing_text_color_r")
    assert settings.weapon_blessing_text_color_preset == "custom"

    settings.curio_secondary_text_color_preset = "terminal_green"
    mod.on_setting_changed("curio_secondary_text_color_preset")
    assert (
        settings.curio_secondary_text_color_r,
        settings.curio_secondary_text_color_g,
        settings.curio_secondary_text_color_b,
    ) == (113, 126, 103)

    settings.curio_secondary_text_color_g = 88
    mod.on_setting_changed("curio_secondary_text_color_g")
    assert settings.curio_secondary_text_color_preset == "custom"

    option_ids = (
        "columns",
        "expand_inventory_window",
		"weapon_extra_width_column_threshold",
		"five_column_weapon_extra_width",
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
		"show_weapon_perk_rank_symbols",
		"weapon_perk_rank_icon_size",
		"remove_weapon_perk_plus_signs",
		"weapon_perk_text_color_preset",
		"weapon_perk_text_color_r",
		"weapon_perk_text_color_g",
		"weapon_perk_text_color_b",
		"weapon_perk_text_opacity",
		"weapon_perk_vertical_spacing",
		"blessing_text_item_level_separation",
		"weapon_blessing_text_color_preset",
		"weapon_blessing_text_color_r",
		"weapon_blessing_text_color_g",
		"weapon_blessing_text_color_b",
		"weapon_blessing_text_opacity",
		"weapon_blessing_text_vertical_spacing",
		"weapon_blessing_text_bottom_padding",
		"blessing_icon_size",
		"blessing_icon_spacing",
		"weapon_perk_blessing_spacing",
		"curio_secondary_stat_font_size",
		"curio_primary_secondary_spacing",
		"curio_information_width_percent",
		"curio_preview_height_percent",
		"inventory_options_panel_width",
		"inventory_options_panel_max_height",
		"inventory_options_panel_row_spacing",
		"inventory_options_panel_padding_top",
		"inventory_options_panel_padding_bottom",
		"inventory_options_panel_padding_left",
		"inventory_options_panel_padding_right",
		"quick_discard_rarity",
		"quick_discard_max_item_level",
		"quick_discard_protect_above_equipped_level",
		"quick_discard_include_melee",
		"quick_discard_include_ranged",
		"quick_discard_include_curios",
		"quick_discard_protect_perfect_weapons",
		"quick_discard_protect_high_level_curios",
		"quick_discard_curio_protection_level",
		"quick_discard_keep_health_curios",
		"quick_discard_keep_toughness_curios",
		"quick_discard_keep_wound_curios",
		"quick_discard_keep_stamina_curios",
		"quick_discard_show_type_breakdown",
		"quick_discard_show_summary_notification",
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
    assert entries_by_id["weapon_extra_width_column_threshold"].disabled is False
    assert entries_by_id["five_column_weapon_extra_width"].disabled is True
    assert entries_by_id["curio_target_card_width"].disabled is False
    assert entries_by_id["weapon_perk_compression"].disabled is True
    assert entries_by_id["show_weapon_perk_rank_symbols"].disabled is True
    assert entries_by_id["weapon_perk_rank_icon_size"].disabled is True
    assert entries_by_id["remove_weapon_perk_plus_signs"].disabled is True
    assert entries_by_id["weapon_perk_text_color_preset"].disabled is True
    assert entries_by_id["weapon_perk_text_color_r"].disabled is True
    assert entries_by_id["weapon_perk_text_color_g"].disabled is True
    assert entries_by_id["weapon_perk_text_color_b"].disabled is True
    assert entries_by_id["weapon_perk_text_opacity"].disabled is True
    assert entries_by_id["weapon_perk_vertical_spacing"].disabled is True
    assert entries_by_id["blessing_text_item_level_separation"].disabled is True
    assert entries_by_id["weapon_blessing_text_color_preset"].disabled is True
    assert entries_by_id["weapon_blessing_text_color_r"].disabled is True
    assert entries_by_id["weapon_blessing_text_color_g"].disabled is True
    assert entries_by_id["weapon_blessing_text_color_b"].disabled is True
    assert entries_by_id["weapon_blessing_text_opacity"].disabled is True
    assert entries_by_id["weapon_blessing_text_vertical_spacing"].disabled is True
    assert entries_by_id["weapon_blessing_text_bottom_padding"].disabled is True
    assert entries_by_id["blessing_icon_size"].disabled is False
    assert entries_by_id["blessing_icon_spacing"].disabled is False
    assert entries_by_id["weapon_perk_blessing_spacing"].disabled is True
    assert entries_by_id["curio_secondary_stat_font_size"].disabled is True
    assert entries_by_id["curio_primary_secondary_spacing"].disabled is True
    assert entries_by_id["quick_discard_rarity"].disabled is True
    assert entries_by_id["quick_discard_protect_above_equipped_level"].disabled is True
    assert entries_by_id["quick_discard_curio_protection_level"].disabled is True
    assert entries_by_id["quick_discard_keep_health_curios"].disabled is True
    assert entries_by_id["quick_discard_keep_toughness_curios"].disabled is True
    assert entries_by_id["quick_discard_show_type_breakdown"].disabled is True
    assert entries_by_id["quick_discard_show_summary_notification"].disabled is True
    assert entries_by_id["curio_information_width_percent"].disabled is True
    assert entries_by_id["curio_preview_height_percent"].disabled is True
    assert entries_by_id["inventory_options_panel_width"].disabled is True
    assert entries_by_id["inventory_options_panel_max_height"].disabled is True
    assert entries_by_id["inventory_options_panel_row_spacing"].disabled is True
    assert entries_by_id["inventory_options_panel_padding_top"].disabled is True
    assert entries_by_id["inventory_options_panel_padding_bottom"].disabled is True
    assert entries_by_id["inventory_options_panel_padding_left"].disabled is True
    assert entries_by_id["inventory_options_panel_padding_right"].disabled is True

    settings.enable_inventory_options_panel_prototype = True
    mod.on_setting_changed("enable_inventory_options_panel_prototype")
    assert entries_by_id["curio_information_width_percent"].disabled is False
    assert entries_by_id["curio_preview_height_percent"].disabled is False
    assert entries_by_id["inventory_options_panel_width"].disabled is False
    assert entries_by_id["inventory_options_panel_max_height"].disabled is False
    assert entries_by_id["inventory_options_panel_row_spacing"].disabled is False
    assert entries_by_id["inventory_options_panel_padding_top"].disabled is False
    assert entries_by_id["inventory_options_panel_padding_bottom"].disabled is False
    assert entries_by_id["inventory_options_panel_padding_left"].disabled is False
    assert entries_by_id["inventory_options_panel_padding_right"].disabled is False
    settings.enable_inventory_options_panel_prototype = False
    mod.on_setting_changed("enable_inventory_options_panel_prototype")

    settings.enable_experimental_quick_discard = True
    mod.on_setting_changed("enable_experimental_quick_discard")
    assert entries_by_id["quick_discard_rarity"].disabled is False
    assert entries_by_id["quick_discard_max_item_level"].disabled is False
    assert entries_by_id["quick_discard_protect_above_equipped_level"].disabled is False
    assert entries_by_id["quick_discard_curio_protection_level"].disabled is False
    assert entries_by_id["quick_discard_curio_protection_level"].validation_function() is True
    assert entries_by_id["quick_discard_keep_health_curios"].disabled is False
    assert entries_by_id["quick_discard_keep_toughness_curios"].disabled is False
    assert entries_by_id["quick_discard_keep_wound_curios"].disabled is False
    assert entries_by_id["quick_discard_keep_stamina_curios"].disabled is False
    assert entries_by_id["quick_discard_show_type_breakdown"].disabled is False
    assert entries_by_id["quick_discard_show_summary_notification"].disabled is False
    settings.quick_discard_protect_high_level_curios = False
    mod.on_setting_changed("quick_discard_protect_high_level_curios")
    assert entries_by_id["quick_discard_curio_protection_level"].disabled is True
    assert entries_by_id["quick_discard_curio_protection_level"].validation_function() is False
    assert entries_by_id["quick_discard_keep_health_curios"].disabled is False
    assert entries_by_id["quick_discard_keep_toughness_curios"].disabled is False
    assert entries_by_id["quick_discard_keep_wound_curios"].disabled is False
    assert entries_by_id["quick_discard_keep_stamina_curios"].disabled is False
    assert globals_.quick_discard_syncs > 0
    settings.quick_discard_protect_high_level_curios = True
    settings.enable_experimental_quick_discard = False
    mod.on_setting_changed("enable_experimental_quick_discard")

    settings.columns = 4
    mod.on_setting_changed("columns")
    assert entries_by_id["five_column_weapon_extra_width"].disabled is False
    settings.weapon_extra_width_column_threshold = "five_only"
    mod.on_setting_changed("weapon_extra_width_column_threshold")
    assert entries_by_id["five_column_weapon_extra_width"].disabled is True
    settings.columns = 5
    mod.on_setting_changed("columns")
    assert entries_by_id["five_column_weapon_extra_width"].disabled is False
    settings.weapon_extra_width_column_threshold = "four_plus"
    mod.on_setting_changed("weapon_extra_width_column_threshold")
    settings.columns = 3
    mod.on_setting_changed("columns")
    assert entries_by_id["five_column_weapon_extra_width"].disabled is True

    settings.curio_display_profile = "detailed"
    mod.on_setting_changed("curio_display_profile")
    assert entries_by_id["curio_secondary_stat_font_size"].disabled is False
    assert entries_by_id["curio_primary_secondary_spacing"].disabled is False
    settings.curio_display_profile = "primary"
    mod.on_setting_changed("curio_display_profile")
    assert entries_by_id["curio_secondary_stat_font_size"].disabled is True
    assert entries_by_id["curio_primary_secondary_spacing"].disabled is True

    settings.show_weapon_perks = True
    mod.on_setting_changed("show_weapon_perks")
    assert entries_by_id["weapon_perk_compression"].disabled is False
    assert entries_by_id["show_weapon_perk_rank_symbols"].disabled is False
    assert entries_by_id["weapon_perk_rank_icon_size"].disabled is True
    assert entries_by_id["remove_weapon_perk_plus_signs"].disabled is False
    assert entries_by_id["weapon_perk_text_color_preset"].disabled is False
    assert entries_by_id["weapon_perk_text_color_r"].disabled is False
    assert entries_by_id["weapon_perk_text_color_g"].disabled is False
    assert entries_by_id["weapon_perk_text_color_b"].disabled is False
    assert entries_by_id["weapon_perk_text_opacity"].disabled is False
    assert entries_by_id["weapon_perk_vertical_spacing"].disabled is False
    assert entries_by_id["weapon_perk_blessing_spacing"].disabled is False
    settings.show_weapon_perk_rank_symbols = True
    mod.on_setting_changed("show_weapon_perk_rank_symbols")
    assert entries_by_id["weapon_perk_rank_icon_size"].disabled is False
    settings.show_weapon_perk_rank_symbols = False
    mod.on_setting_changed("show_weapon_perk_rank_symbols")
    assert entries_by_id["weapon_perk_rank_icon_size"].disabled is True
    settings.show_weapon_perks = False
    mod.on_setting_changed("show_weapon_perks")
    assert entries_by_id["weapon_perk_compression"].disabled is True
    assert entries_by_id["show_weapon_perk_rank_symbols"].disabled is True
    assert entries_by_id["weapon_perk_rank_icon_size"].disabled is True
    assert entries_by_id["remove_weapon_perk_plus_signs"].disabled is True
    assert entries_by_id["weapon_perk_text_color_preset"].disabled is True
    assert entries_by_id["weapon_perk_text_color_r"].disabled is True
    assert entries_by_id["weapon_perk_text_color_g"].disabled is True
    assert entries_by_id["weapon_perk_text_color_b"].disabled is True
    assert entries_by_id["weapon_perk_text_opacity"].disabled is True
    assert entries_by_id["weapon_perk_vertical_spacing"].disabled is True
    assert entries_by_id["weapon_perk_blessing_spacing"].disabled is True

    settings.weapon_blessing_display_mode = "text"
    mod.on_setting_changed("weapon_blessing_display_mode")
    assert entries_by_id["blessing_text_item_level_separation"].disabled is False
    assert entries_by_id["weapon_perk_rank_icon_size"].disabled is True
    assert entries_by_id["weapon_blessing_text_color_preset"].disabled is False
    assert entries_by_id["weapon_blessing_text_color_r"].disabled is False
    assert entries_by_id["weapon_blessing_text_color_g"].disabled is False
    assert entries_by_id["weapon_blessing_text_color_b"].disabled is False
    assert entries_by_id["weapon_blessing_text_opacity"].disabled is False
    assert entries_by_id["weapon_blessing_text_vertical_spacing"].disabled is False
    assert entries_by_id["weapon_blessing_text_bottom_padding"].disabled is False
    assert entries_by_id["blessing_icon_size"].disabled is True
    assert entries_by_id["blessing_icon_spacing"].disabled is True
    settings.weapon_blessing_display_mode = "ranked_text"
    mod.on_setting_changed("weapon_blessing_display_mode")
    assert entries_by_id["blessing_text_item_level_separation"].disabled is False
    assert entries_by_id["weapon_perk_rank_icon_size"].disabled is False
    assert entries_by_id["blessing_icon_size"].disabled is True
    assert entries_by_id["blessing_icon_spacing"].disabled is True
    settings.weapon_blessing_display_mode = "off"
    mod.on_setting_changed("weapon_blessing_display_mode")
    assert entries_by_id["blessing_text_item_level_separation"].disabled is True
    assert entries_by_id["weapon_perk_rank_icon_size"].disabled is True
    assert entries_by_id["weapon_blessing_text_color_preset"].disabled is True
    assert entries_by_id["weapon_blessing_text_color_r"].disabled is True
    assert entries_by_id["weapon_blessing_text_color_g"].disabled is True
    assert entries_by_id["weapon_blessing_text_color_b"].disabled is True
    assert entries_by_id["weapon_blessing_text_opacity"].disabled is True
    assert entries_by_id["weapon_blessing_text_vertical_spacing"].disabled is True
    assert entries_by_id["weapon_blessing_text_bottom_padding"].disabled is True
    assert entries_by_id["blessing_icon_size"].disabled is True
    assert entries_by_id["blessing_icon_spacing"].disabled is True
    settings.weapon_blessing_display_mode = "icons"
    mod.on_setting_changed("weapon_blessing_display_mode")
    assert entries_by_id["blessing_text_item_level_separation"].disabled is True
    assert entries_by_id["blessing_icon_size"].disabled is False
    assert entries_by_id["blessing_icon_spacing"].disabled is False

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

    settings.prioritize_equipped_favorites = False
    mod.on_setting_changed("prioritize_equipped_favorites")
    assert globals_.inventory_sort_syncs == 1

    settings.automatic_card_height = False
    mod.on_setting_changed("automatic_card_height")
    assert entries_by_id["card_height"].disabled is False

    settings.enable_grid_layout = False
    mod.on_setting_changed("enable_grid_layout")

    for option_id in option_ids:
        if option_id in {"blessing_icon_size", "blessing_icon_spacing"}:
            continue

        assert entries_by_id[option_id].disabled is True

    assert entries_by_id["blessing_icon_size"].disabled is False
    assert entries_by_id["blessing_icon_spacing"].disabled is False

    data = lua.execute(DATA_PATH.read_text(encoding="utf-8"))
    localization = lua.execute(LOCALIZATION_PATH.read_text(encoding="utf-8"))
    defaults = {}

    assert data.version == "1.1.0"

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

    card_content_group = next(
        data.options.widgets[index]
        for index in range(1, len(data.options.widgets) + 1)
        if data.options.widgets[index].setting_id == "card_content_group"
    )
    card_content_ids = {
        card_content_group.sub_widgets[index].setting_id
        for index in range(1, len(card_content_group.sub_widgets) + 1)
    }
    assert "weapon_perk_text_color_group" not in card_content_ids
    assert {
        "weapon_perk_text_color_preset",
        "weapon_perk_text_color_r",
        "weapon_perk_text_color_g",
		"weapon_perk_text_color_b",
		"weapon_perk_text_opacity",
    }.issubset(card_content_ids)
    assert {
        "weapon_blessing_text_color_preset",
        "weapon_blessing_text_color_r",
        "weapon_blessing_text_color_g",
		"weapon_blessing_text_color_b",
		"weapon_blessing_text_opacity",
    }.issubset(card_content_ids)

    curio_content_group = next(
        data.options.widgets[index]
        for index in range(1, len(data.options.widgets) + 1)
        if data.options.widgets[index].setting_id == "curio_content_group"
    )
    curio_content_ids = [
        curio_content_group.sub_widgets[index].setting_id
        for index in range(1, len(curio_content_group.sub_widgets) + 1)
    ]
    assert curio_content_ids.index("curio_secondary_text_color_group") > curio_content_ids.index("curio_stamina_color_group")

    assert defaults["enable_grid_layout"] is True
    assert defaults["enable_hadron_entreat_grid"] is True
    assert defaults["enable_armoury_requisition_grid"] is True
    assert defaults["expand_armoury_requisition_window"] is True
    assert defaults["armoury_requisition_target_card_width"] == 230
    assert defaults["automatic_card_height"] is True
    assert defaults["expand_curio_inventory_window"] is True
    assert defaults["weapon_extra_width_column_threshold"] == "four_plus"
    assert defaults["five_column_weapon_extra_width"] == 80
    assert defaults["curio_target_card_width"] == 190
    assert defaults["curio_stat_compression"] == "heavy"
    assert defaults["simplify_curio_primary_stat_text"] is True
    assert defaults["remove_curio_stat_plus_signs"] is False
    assert defaults["blessing_icon_spacing"] == 3
    assert defaults["blessing_icon_size"] == 36
    assert defaults["weapon_blessing_text_vertical_spacing"] == 2
    assert defaults["weapon_blessing_text_bottom_padding"] == 4
    assert defaults["show_rarity_tag"] is True
    assert defaults["weapon_blessing_text_color_preset"] == "light_blue"
    assert defaults["weapon_blessing_text_color_r"] == 105
    assert defaults["weapon_blessing_text_color_g"] == 200
    assert defaults["weapon_blessing_text_color_b"] == 235
    assert defaults["weapon_blessing_text_opacity"] == 80
    assert defaults["highlight_equipped_items"] is True
    assert defaults["weapon_blessing_display_mode"] == "ranked_text"
    assert defaults["blessing_text_item_level_separation"] == "four_plus"
    assert "show_weapon_blessings" not in defaults
    assert defaults["show_weapon_perks"] is True
    assert defaults["weapon_perk_compression"] == "heavy"
    assert defaults["show_weapon_perk_rank_symbols"] is True
    assert defaults["weapon_perk_rank_icon_size"] == 17
    assert defaults["remove_weapon_perk_plus_signs"] is False
    assert defaults["curio_display_profile"] == "detailed"
    assert defaults["show_curio_item_level"] is True
    assert defaults["prioritize_equipped_favorites"] is True
    assert defaults["prioritize_perfect_roll_weapons"] is True
    assert defaults["enable_inventory_options_panel_prototype"] is True
    assert defaults["curio_information_width_percent"] == 90
    assert defaults["curio_preview_height_percent"] == 76
    assert defaults["inventory_options_panel_width"] == 445
    assert defaults["inventory_options_panel_max_height"] == 360
    assert defaults["inventory_options_panel_row_spacing"] == 8
    assert defaults["inventory_options_panel_padding_top"] == 10
    assert defaults["inventory_options_panel_padding_bottom"] == 10
    assert defaults["inventory_options_panel_padding_left"] == 12
    assert defaults["inventory_options_panel_padding_right"] == 12
    assert defaults["quick_discard_keep_health_curios"] is True
    assert defaults["quick_discard_keep_toughness_curios"] is True
    assert defaults["quick_discard_keep_wound_curios"] is True
    assert defaults["quick_discard_keep_stamina_curios"] is True
    assert defaults["quick_discard_max_item_level"] == 490
    assert defaults["quick_discard_protect_above_equipped_level"] is True
    assert defaults["quick_discard_show_summary_notification"] is True
    assert defaults["curio_primary_stat_font_size"] == 16
    assert defaults["curio_secondary_stat_font_size"] == 13
    assert defaults["curio_primary_secondary_spacing"] == 5
    assert defaults["show_item_level_icon"] is False
    assert defaults["curio_health_color_preset"] == "red"
    assert defaults["curio_toughness_color_preset"] == "light_blue"
    assert defaults["curio_wound_color_preset"] == "purple"
    assert defaults["curio_stamina_color_preset"] == "yellow"
    assert defaults["weapon_perk_text_color_preset"] == "light_green"
    assert defaults["weapon_perk_text_color_r"] == 190
    assert defaults["weapon_perk_text_color_g"] == 210
    assert defaults["weapon_perk_text_color_b"] == 180
    assert defaults["weapon_perk_text_opacity"] == 80
    assert defaults["weapon_perk_vertical_spacing"] == 2
    assert defaults["weapon_perk_blessing_spacing"] == 5
    assert defaults["curio_secondary_text_color_preset"] == "neutral"
    assert defaults["curio_secondary_text_color_r"] == 220
    assert defaults["curio_secondary_text_color_g"] == 230
    assert defaults["curio_secondary_text_color_b"] == 210

    print("BetterInventory live setting synchronization tests passed.")


if __name__ == "__main__":
    main()
