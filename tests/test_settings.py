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
			melee_columns = 3,
			ranged_columns = 3,
			curio_columns = 3,
			three_column_weapon_name_font_size = 14,
            enable_grid_layout = true,
			enable_quick_look_card_single_column_integration = true,
			enable_quick_look_card_grid_integration = true,
			quick_look_card_single_column_font_size = 14,
			quick_look_card_single_column_label_value_gap = 1,
			quick_look_card_single_column_horizontal_position = 79,
			quick_look_card_single_column_vertical_position = 93,
			quick_look_card_grid_stat_position = "above_power",
			weapon_modifier_lowest_color_preset = "pink",
			weapon_modifier_lowest_color_r = 255,
			weapon_modifier_lowest_color_g = 94,
			weapon_modifier_lowest_color_b = 132,
			weapon_modifier_lowest_color_opacity = 80,
			name_it_force_curio_name_in_detailed_mode = true,
			curio_content_name_it_curio_name = false,
			enable_custom_item_name_and_colors = true,
			inventory_options_controller_focus_keybind = "navigate_secondary_right_pressed",
			custom_item_name_keybind = "lobby_open_inventory",
			custom_item_name_color_keybind = "hotkey_menu_special_1",
			custom_item_background_color_keybind = "navigate_secondary_left_pressed",
			custom_item_skip_confirmation_prompts = true,
			custom_item_preserve_card_shading = true,
			custom_item_override_weapon_information_color = true,
			custom_item_override_weapon_rarity_keyword_color = true,
			custom_item_override_weapon_information_name_color = true,
			enable_hadron_entreat_grid = true,
			enable_hadron_single_column_mirror = true,
			enable_armoury_requisition_grid = true,
			enable_armoury_single_column_mirror = true,
			enable_armoury_requisition_sorting_panel = true,
			brighten_armoury_item_levels = true,
			enable_global_store_integration = true,
			enable_global_store_grid = true,
			enable_global_store_sorting_panel = true,
			global_store_character_photo_size_percent = 110,
			global_store_price_row_padding = 10,
			global_store_character_info_gap = 5,
			global_store_character_class_icon_size = 16,
			global_store_character_name_font_size = 16,
			global_store_compact_character_names = true,
			global_store_single_column_modifier_horizontal_position = 55,
			global_store_single_column_modifier_vertical_position = 100,
			expand_armoury_requisition_window = true,
			armoury_requisition_target_card_width = 230,
			debug_expand_armoury_requisition_window_30_percent = false,
			debug_armoury_requisition_window_increase_percent = 30,
			debug_adjust_inventory_window_width = false,
			debug_inventory_window_width_adjustment_percent = 30,
			debug_adjust_global_store_window_width = false,
			debug_global_store_window_width_adjustment_percent = 30,
			show_inventory_options_widget = true,
			automatic_card_height = true,
			show_weapon_perks = false,
			show_weapon_blessings = true,
			weapon_blessing_display_mode = "icons",
			blessing_text_item_level_separation = "four_plus",
			auto_fit_long_blessing_names = true,
			truncate_long_blessing_names = false,
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
			quick_discard_mode = "manual",
			quick_discard_disable_no_eligible_notification = false,
			enable_automatic_curio_acquisition = false,
			automatic_curio_disable_no_eligible_notification = false,
			myfavorites_show_favorite_letter = false,
        }

		test_layout = {
            is_enabled_for_view = function() return false end,
            columns = function(_, _, slot_kind)
                local setting_id = slot_kind == "melee" and "melee_columns" or slot_kind == "ranged" and "ranged_columns" or slot_kind == "curio" and "curio_columns" or "melee_columns"
                return settings[setting_id] or 3
            end,
            expanded_view_definitions = function(_, definitions) return definitions, 0 end,
			expanded_armoury_view_definitions = function(_, definitions)
				definitions.armoury_expanded = true
				return definitions, 114
			end,
			expanded_global_store_view_definitions = function(_, definitions)
				definitions.global_store_expanded = true
				return definitions, 114
			end,
            configure_item_blueprint = function() end,
			configure_grid = function() end,
		}
		inventory_sort_syncs = 0
		quick_discard_syncs = 0
		curio_acquisition_syncs = 0
		lantern_recommendations_are_active = false
		profile_discovery_requests = 0
		last_profile_discovery_force = nil
		test_features = {
			add_inventory_sort_toggle_definition = function(_, _, definitions) return definitions end,
			configure_inventory_sort_options = function() end,
			setup_inventory_options_panel = function() end,
			bind_inventory_sort_toggle = function() end,
			resort_inventory = function() end,
			update_inventory_sort_toggle = function() end,
			update_morningstar_auto_discard = function() end,
			sync_inventory_sort_setting = function() inventory_sort_syncs = inventory_sort_syncs + 1 end,
			sync_quick_discard_settings = function() quick_discard_syncs = quick_discard_syncs + 1 end,
			sync_curio_acquisition_settings = function() curio_acquisition_syncs = curio_acquisition_syncs + 1 end,
			morningstar_auto_discard_is_busy = function() return false end,
			unregister_inventory_view = function() end,
			lantern_recommendations_active = function() return lantern_recommendations_are_active end,
		}
		test_curio_acquisition = {
			begin_morningstar_pass = function() end,
			cancel = function() end,
			on_setting_changed = function() end,
			refresh_character_options = function() end,
			request_profile_discovery = function(force)
				profile_discovery_requests = profile_discovery_requests + 1
				last_profile_discovery_force = force
			end,
			update = function() end,
		}
		test_item_customization = {
			on_enabled = function() end,
			on_all_mods_loaded = function() end,
			on_setting_changed = function() end,
			update_runtime = function() end,
			import_name_it_names = function() end,
		}

        test_mod = {}
        test_dmf = {
            create_mod_options_settings = function() end,
        }
		test_inventory_view = {
			_create_entry_widget_from_config = function() end,
		}
		test_view_element_grid = {
			_create_entry_widget_from_config = function() end,
			_update_grid_widgets = function() end,
		}
		test_visible_equipment = {
			is_enabled = function() return visible_equipment_enabled end,
		}
		visible_equipment_available = true
		visible_equipment_enabled = true
		overview_equipped_item_calls = 0
		overview_layout_switches = 0
		captured_options_hook = nil
		captured_item_grid_init_hook = nil
		captured_armoury_on_enter_hook = nil
		captured_character_overview_widget_hook = nil
		captured_character_overview_update_hook = nil
		captured_grid_widget_hook = nil
		captured_grid_update_hook = nil
		captured_module_errors = 0
		fail_feature_load = false

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
				if fail_feature_load then
					return false
				end

				return test_features
			elseif string.find(path, "BetterInventory_curio_acquisition", 1, true) then
				return test_curio_acquisition
			elseif string.find(path, "BetterInventory_item_customization", 1, true) then
				return test_item_customization
			end

			return test_layout
		end

		function test_mod:error()
			captured_module_errors = captured_module_errors + 1
		end

        function test_mod:hook(target, method, callback)
			if method == "init" then
				captured_item_grid_init_hook = callback
			elseif method == "on_enter" then
				captured_armoury_on_enter_hook = callback
			elseif target == test_inventory_view and method == "_create_entry_widget_from_config" then
				captured_character_overview_widget_hook = callback
			elseif target == test_view_element_grid and method == "_create_entry_widget_from_config" then
				captured_grid_widget_hook = callback
			elseif target == test_view_element_grid and method == "_update_grid_widgets" then
				captured_grid_update_hook = callback
			end
        end

        function test_mod:hook_safe(target, method, callback)
            if target == test_dmf and method == "create_mod_options_settings" then
                captured_options_hook = callback
			elseif target == test_inventory_view and method == "update" then
				captured_character_overview_update_hook = callback
            end
        end

        function get_mod(name)
            if name == "BetterInventory" then
                return test_mod
            end

            if name == "DMF" then
                return test_dmf
            end

			if name == "visible_equipment" then
				return visible_equipment_available and test_visible_equipment or nil
			end

        end

        function require(path)
			if path == "scripts/ui/views/inventory_view/inventory_view" then
				return test_inventory_view
			elseif path == "scripts/ui/view_elements/view_element_grid/view_element_grid" then
				return test_view_element_grid
			end

            return {}
        end
        """
    )
    lua.execute(MAIN_PATH.read_text(encoding="utf-8"))
    globals_ = lua.globals()
    mod = globals_.test_mod
    settings = globals_.settings

    visible_equipment_config = lua.table_from(
        {
            "widget_type": "gear_placement_slot",
            "item_type": "WEAPON_MELEE",
            "slot": lua.table_from({"name": "slot_primary"}),
        }
    )
    overview_view = lua.execute(
        """
        return {
            __class_name = "InventoryView",
            equipped_item_in_slot = function()
                overview_equipped_item_calls = overview_equipped_item_calls + 1
            end,
            _switch_active_layout = function()
                overview_layout_switches = overview_layout_switches + 1
            end,
        }
        """
    )
    original_widget_factory = lua.eval(
        "function(view, config) return config.widget_type end"
    )
    assert (
        globals_.captured_character_overview_widget_hook(
            original_widget_factory,
            overview_view,
            visible_equipment_config,
            "test",
            "pressed",
            "right_pressed",
            "slot_primary",
        )
        == "gear_placement_slot"
    )
    assert globals_.overview_equipped_item_calls == 0
    native_weapon_config = lua.table_from(
        {
            "widget_type": "weapon_item_slot",
            "item_type": "WEAPON_MELEE",
            "slot": lua.table_from({"name": "slot_primary"}),
        }
    )
    assert (
        globals_.captured_character_overview_widget_hook(
            original_widget_factory,
            overview_view,
            native_weapon_config,
            "test",
            "pressed",
            "right_pressed",
            "slot_primary",
        )
        == "weapon_item_slot"
    )
    assert globals_.overview_equipped_item_calls == 1

    globals_.visible_equipment_enabled = False
    globals_.captured_character_overview_widget_hook(
        original_widget_factory,
        overview_view,
        visible_equipment_config,
        "test",
        "pressed",
        "right_pressed",
        "slot_primary",
    )
    assert globals_.overview_equipped_item_calls == 2
    globals_.visible_equipment_enabled = True

    globals_.visible_equipment_available = False
    globals_.captured_character_overview_widget_hook(
        original_widget_factory,
        overview_view,
        visible_equipment_config,
        "test",
        "pressed",
        "right_pressed",
        "slot_primary",
    )
    assert globals_.overview_equipped_item_calls == 3
    globals_.visible_equipment_available = True

    overview_equipped_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(
                {
                    "myfav_hotspot": lua.table_from(
                        {
                            "horizontal_alignment": "right",
                            "vertical_alignment": "top",
                            "offset": lua.table_from({1: -8, 2: 7, 3: 17}),
                        }
                    ),
                    "equipped_icon": lua.table_from(
                        {"offset": lua.table_from({1: -2, 2: 2, 3: 16})}
                    )
                },
            ),
            "passes": lua.table_from(
                [
                    lua.table_from(
                        {
                            "style_id": "equipped_icon",
                            "visibility_function": lua.eval("function() return true end"),
                        }
                    )
                ]
            ),
        }
    )
    overview_widget_factory = lua.eval(
        "function(view, config) return config.test_widget, config.test_widget end"
    )
    runtime_overview_config = lua.table_from(
        {
            "widget_type": "weapon_item_slot",
            "item_type": "WEAPON_MELEE",
            "slot": lua.table_from({"name": "slot_primary"}),
            "test_widget": overview_equipped_widget,
        }
    )
    globals_.captured_character_overview_widget_hook(
        overview_widget_factory,
        overview_view,
        runtime_overview_config,
        "test",
        "pressed",
        "right_pressed",
        "slot_primary",
    )
    assert overview_equipped_widget.style.equipped_icon.offset[2] == 2
    assert overview_equipped_widget.content.better_inventory_equipped_icon_original_y == 2
    assert overview_equipped_widget.content.better_inventory_myfavorites_hotspot_style.offset[2] == 7
    assert overview_equipped_widget.content.better_inventory_myfavorites_hotspot_style.offset[1] == overview_equipped_widget.style.myfav_hotspot.offset[1]
    assert overview_equipped_widget.content.better_inventory_equipped_icon_visibility_function is not None
    overview_view._loadout_widgets = lua.table_from([overview_equipped_widget])
    overview_view._active_category_tab_context = lua.table_from({"is_grid_layout": False})
    globals_.lantern_recommendations_are_active = True
    globals_.captured_character_overview_update_hook(overview_view)
    assert overview_equipped_widget.style.equipped_icon.offset[2] == 34
    globals_.lantern_recommendations_are_active = False
    globals_.captured_character_overview_update_hook(overview_view)
    assert overview_equipped_widget.style.equipped_icon.offset[2] == 2
    settings.character_overview_use_native_curio_overlay = True
    mod.on_setting_changed("character_overview_use_native_curio_overlay")
    globals_.captured_character_overview_update_hook(overview_view)
    assert globals_.overview_layout_switches == 1
    globals_.captured_character_overview_update_hook(overview_view)
    assert globals_.overview_layout_switches == 1
    settings.character_overview_show_curio_rarity_strip = False
    mod.on_setting_changed("character_overview_show_curio_rarity_strip")
    globals_.captured_character_overview_update_hook(overview_view)
    assert globals_.overview_layout_switches == 2

    runtime_hotspot_style = lua.table_from(
        {
            "horizontal_alignment": "right",
            "vertical_alignment": "top",
            "offset": lua.table_from({1: -8, 2: 7, 3: 17}),
        }
    )
    grid_widget = lua.table_from(
        {
            "name": "item_widget",
            "content": lua.table_from({"favorite": False, "equipped": False}),
            "style": lua.table_from(
                {
                    "myfav_hotspot": runtime_hotspot_style,
                    "favorite_icon": lua.table_from(
                        {"offset": lua.table_from({1: -8, 2: 7, 3: 16})}
                    ),
                    "equipped_icon": lua.table_from({}),
                }
            ),
            "passes": lua.table_from(
                {
                    1: lua.table_from(
                        {
                            "style_id": "equipped_icon",
                            "visibility_function": lua.eval(
                                "function(content) return content.inactive_loadout_equipped == true end"
                            ),
                        }
                    )
                }
            ),
        }
    )
    grid_alignment_widget = lua.table_from({"name": "alignment"})
    grid_widget_factory = lua.eval(
        "function(item_grid, config) return config.widget, config.alignment_widget end"
    )
    returned_widget, returned_alignment = globals_.captured_grid_widget_hook(
        grid_widget_factory,
        lua.table_from({}),
        lua.table_from(
            {"widget": grid_widget, "alignment_widget": grid_alignment_widget}
        ),
        "test",
        "pressed",
        "right_pressed",
        "double_pressed",
    )
    assert returned_widget.name == "item_widget"
    assert returned_alignment.name == "alignment"
    bound_hotspot_style = (
        grid_widget.content.better_inventory_myfavorites_hotspot_style
    )
    assert tuple(bound_hotspot_style.offset[index] for index in range(1, 4)) == (
        -8,
        7,
        17,
    )

    grid_update_calls = lua.table_from({"count": 0})
    original_grid_update = lua.eval(
        "function(item_grid, state) state.count = state.count + 1 return 'updated', nil, 'tail' end"
    )
    item_grid = lua.table_from(
        {"_grid_widgets": lua.table_from({1: grid_widget})}
    )

    # MyFavorites only / native equipped state: favorite state never controls
    # placement, including transitions while the favorite icon is hidden.
    update_result, update_nil, update_tail = globals_.captured_grid_update_hook(
        original_grid_update, item_grid, grid_update_calls
    )
    assert (update_result, update_nil, update_tail) == ("updated", None, "tail")
    assert grid_update_calls.count == 1
    assert runtime_hotspot_style.offset[2] == 7
    assert grid_widget.style.favorite_icon.offset[2] == 7
    grid_widget.content.favorite = True
    globals_.captured_grid_update_hook(original_grid_update, item_grid, grid_update_calls)
    assert runtime_hotspot_style.offset[2] == 7
    grid_widget.content.favorite = False
    grid_widget.content.equipped = True
    globals_.captured_grid_update_hook(original_grid_update, item_grid, grid_update_calls)
    assert runtime_hotspot_style.offset[2] == 33
    assert grid_widget.style.favorite_icon.offset[2] == 33
    grid_widget.content.equipped = False
    globals_.captured_grid_update_hook(original_grid_update, item_grid, grid_update_calls)
    assert runtime_hotspot_style.offset[2] == 7

    # Equipped Icon+ inactive-loadout state follows its live visibility pass.
    grid_widget.content.inactive_loadout_equipped = True
    globals_.captured_grid_update_hook(original_grid_update, item_grid, grid_update_calls)
    assert runtime_hotspot_style.offset[2] == 33
    grid_widget.content.inactive_loadout_equipped = False
    globals_.captured_grid_update_hook(original_grid_update, item_grid, grid_update_calls)
    assert runtime_hotspot_style.offset[2] == 7

    # A third-party equipped pass failure is isolated and falls back to the
    # ordinary unequipped position instead of breaking grid updates.
    grid_widget.content.better_inventory_equipped_icon_visibility_function = lua.eval(
        "function() error('simulated Equipped Icon+ failure') end"
    )
    globals_.captured_grid_update_hook(original_grid_update, item_grid, grid_update_calls)
    assert runtime_hotspot_style.offset[2] == 7

    # Bottom-left marker mode is intentionally static and must not be pulled
    # into the top-right Equipped Icon+ placement rules.
    runtime_hotspot_style.horizontal_alignment = "left"
    runtime_hotspot_style.vertical_alignment = "bottom"
    runtime_hotspot_style.offset[2] = -5
    grid_widget.content.equipped = True
    globals_.captured_grid_update_hook(original_grid_update, item_grid, grid_update_calls)
    assert runtime_hotspot_style.offset[2] == -5

    # Equipped Icon+ without MyFavorites has no MyFavorites hotspot and is a
    # complete no-op.
    no_myfavorites_widget = lua.table_from(
        {
            "content": lua.table_from({"equipped": True}),
            "style": lua.table_from(
                {
                    "equipped_icon": lua.table_from({}),
                    "favorite_icon": lua.table_from(
                        {"offset": lua.table_from({1: -8, 2: 7, 3: 16})}
                    ),
                }
            ),
        }
    )
    item_grid._grid_widgets[1] = no_myfavorites_widget
    globals_.captured_grid_update_hook(original_grid_update, item_grid, grid_update_calls)
    assert no_myfavorites_widget.style.favorite_icon.offset[2] == 7

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
    credits_view._widgets_by_name = lua.table_from(
        {
            "purchase_button": lua.table_from(
                {"offset": lua.table_from([0, 0, 0])}
            ),
            "quick_sacrifice_button": lua.table_from(
                {"offset": lua.table_from([250, 0, 0])}
            )
        }
    )
    credits_view._ui_scenegraph = lua.table_from(
        {
            "purchase_button": lua.table_from(
                {
                    "position": lua.table_from([790, -90, 1]),
                    "size": lua.table_from([374 / 1.5, 76, 0]),
                }
            )
        }
    )
    credits_view._weapon_stats = lua.table_from(
        {
            "_world_x": 894,
            "scenegraph_world_position": lua.eval(
                "function(element, id) return {element._world_x, 0, 0} end"
            ),
            "_scenegraph_size": lua.eval(
                "function(element, id) return 646, 920 end"
            ),
        }
    )
    credits_view._world_x = lua.table_from(
        {"purchase_button": 790}
    )
    credits_view._scenegraph_world_position = lua.eval(
        "function(view, id) return {view._world_x[id], 0, 0} end"
    )
    credits_view._set_scenegraph_position = lua.eval(
        "function(view, id, x, y, z) "
        "local delta = x - view._ui_scenegraph[id].position[1] "
        "view._ui_scenegraph[id].position[1] = x "
        "view._ui_scenegraph[id].position[2] = y "
        "view._ui_scenegraph[id].position[3] = z "
        "view._world_x[id] = view._world_x[id] + delta end"
    )

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
    assert abs(
        credits_view._ui_scenegraph.purchase_button.position[1] - 967.3333333333
    ) < 0.0001

    # Re-entering must not apply the same compatibility offset twice.
    globals_.captured_armoury_on_enter_hook(
        lua.eval("function() return 'entered again' end"), credits_view
    )
    assert abs(
        credits_view._ui_scenegraph.purchase_button.position[1] - 967.3333333333
    ) < 0.0001

    # CreditsVendorView is also reused by GlobalStore. Its custom cards use the
    # same expanded grid geometry, while their portrait footer is handled by
    # the GlobalStore blueprint hook.
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
    assert custom_credits_view._better_inventory_armoury_grid_expansion == 114
    assert custom_credits_view.received_definitions.global_store_expanded is True
    globals_.captured_armoury_on_enter_hook(
        lua.eval("function() return 'custom_entered' end"), custom_credits_view
    )
    assert custom_credits_view._item_grid.updated is True

    mod.on_enabled()
    assert globals_.profile_discovery_requests == 1
    assert globals_.last_profile_discovery_force is True
    assert settings.curio_stat_compression == "heavy"
    assert settings.blessing_icon_size == 36
    assert settings.weapon_perk_rank_icon_size == 17
    assert settings.weapon_blessing_display_mode == "icons"
    assert settings.curio_content_name_it_curio_name is True

    settings._grid_columns_v1_migrated = False
    settings.columns = 2
    settings.melee_columns = 3
    settings.ranged_columns = 3
    settings.curio_columns = 3
    mod.on_enabled()
    assert (settings.melee_columns, settings.ranged_columns, settings.curio_columns) == (2, 2, 2)

    settings._grid_columns_v1_migrated = False
    settings.melee_columns = 3
    settings.ranged_columns = 3
    settings.curio_columns = 4
    mod.on_enabled()
    assert (settings.melee_columns, settings.ranged_columns, settings.curio_columns) == (3, 3, 4)
    settings._grid_columns_v1_migrated = True
    settings.columns = None
    settings.melee_columns = 3
    settings.ranged_columns = 3
    settings.curio_columns = 3

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

    settings.weapon_modifier_lowest_color_preset = "pink"
    mod.on_setting_changed("weapon_modifier_lowest_color_preset")
    assert (
        settings.weapon_modifier_lowest_color_r,
        settings.weapon_modifier_lowest_color_g,
        settings.weapon_modifier_lowest_color_b,
    ) == (255, 94, 132)

    settings.weapon_modifier_lowest_color_g = 33
    mod.on_setting_changed("weapon_modifier_lowest_color_g")
    assert settings.weapon_modifier_lowest_color_preset == "custom"
    settings.weapon_modifier_lowest_color_preset = "pink"
    mod.on_setting_changed("weapon_modifier_lowest_color_preset")

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
		"melee_columns",
		"ranged_columns",
		"curio_columns",
		"three_column_weapon_name_font_size",
        "expand_inventory_window",
		"weapon_extra_width_column_threshold",
		"five_column_weapon_extra_width",
        "expand_curio_inventory_window",
        "curio_target_card_width",
        "grid_spacing",
        "automatic_card_height",
        "card_height",
        "enable_hadron_entreat_grid",
		"enable_hadron_single_column_mirror",
		"enable_armoury_requisition_grid",
		"enable_armoury_single_column_mirror",
		"enable_armoury_requisition_sorting_panel",
		"brighten_armoury_item_levels",
		"expand_armoury_requisition_window",
		"armoury_requisition_target_card_width",
		"enable_global_store_integration",
		"enable_global_store_grid",
		"enable_global_store_sorting_panel",
		"global_store_character_photo_size_percent",
		"global_store_price_row_padding",
		"global_store_character_info_gap",
		"global_store_character_class_icon_size",
		"global_store_character_name_font_size",
		"global_store_compact_character_names",
		"global_store_single_column_modifier_horizontal_position",
		"global_store_single_column_modifier_vertical_position",
		"character_overview_show_melee_rarity_strip",
		"character_overview_show_ranged_rarity_strip",
		"character_overview_show_curio_rarity_strip",
		"character_overview_use_native_curio_overlay",
		"character_overview_curio_name_mode",
		"character_overview_curio_font_size_percent",
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
		"auto_fit_long_blessing_names",
		"truncate_long_blessing_names",
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
		"single_column_layout_group",
		"single_column_weapon_name_font_size",
		"single_column_blessing_icons_on_right",
		"quick_look_card_single_column_font_size",
		"quick_look_card_single_column_label_value_gap",
		"quick_look_card_single_column_horizontal_position",
		"quick_look_card_single_column_vertical_position",
		"quick_look_card_grid_stat_position",
		"quick_look_card_grid_font_size",
		"quick_look_card_grid_bottom_padding",
		"weapon_modifier_lowest_color_preset",
		"weapon_modifier_lowest_color_r",
		"weapon_modifier_lowest_color_g",
		"weapon_modifier_lowest_color_b",
		"weapon_modifier_lowest_color_opacity",
		"name_it_force_curio_name_in_detailed_mode",
		"curio_content_name_it_curio_name",
		"enable_custom_item_name_and_colors",
		"inventory_options_controller_focus_keybind",
		"custom_item_name_keybind",
		"custom_item_name_color_keybind",
		"custom_item_background_color_keybind",
		"custom_item_skip_confirmation_prompts",
		"custom_item_preserve_card_shading",
		"custom_item_override_weapon_information_color",
		"custom_item_override_weapon_rarity_keyword_color",
		"custom_item_override_weapon_information_name_color",
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
        "quick_discard_disable_no_eligible_notification",
        "automatic_curio_scan_operative_selection",
        "automatic_curio_once_per_store_rotation",
        "automatic_curio_rescan_on_store_refresh",
        "automatic_curio_min_item_level",
		"automatic_curio_min_health",
		"automatic_curio_min_toughness",
		"automatic_curio_diagnostic_logging",
		"automatic_curio_disable_no_eligible_notification",
		"automatic_curio_target_mode",
		"automatic_curio_buy_health",
		"automatic_curio_buy_toughness",
		"automatic_curio_buy_stamina",
		"automatic_curio_buy_wounds",
		"automatic_curio_class_veteran",
		"automatic_curio_class_zealot",
		"automatic_curio_class_psyker",
		"automatic_curio_class_ogryn",
		"automatic_curio_class_adamant",
		"automatic_curio_class_broker",
		"automatic_curio_class_cryptic",
		"automatic_curio_types_group",
		"automatic_curio_classes_group",
		"automatic_curio_characters_group",
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
    active_character_entry = lua.table_from(
        {
            "category": "Better Inventory",
            "display_name": "Dudualdo(Ogryn)",
            "_better_inventory_curio_character_slot_index": 1,
            "_better_inventory_curio_character_available": True,
        }
    )
    empty_character_entry = lua.table_from(
        {
            "category": "Better Inventory",
            "display_name": "Character 2",
            "_better_inventory_curio_character_slot_index": 2,
            "_better_inventory_curio_character_available": False,
        }
    )
    entries.extend([active_character_entry, empty_character_entry])
    for option_id, entry in zip(option_ids, entries):
        if option_id in {
			"single_column_layout_group",
            "automatic_curio_types_group",
            "automatic_curio_classes_group",
            "automatic_curio_characters_group",
        }:
            entry.widget_type = "group_header"
    options_templates = lua.table_from(
        {"settings": lua.table_from(entries)}
    )

    globals_.captured_options_hook(globals_.test_dmf, options_templates)
    entries_by_id = dict(zip(option_ids, entries))
    name_it_curio_name_entries = [
        entries_by_id["name_it_force_curio_name_in_detailed_mode"],
        entries_by_id["curio_content_name_it_curio_name"],
    ]

    assert entries_by_id["melee_columns"].disabled is False
    assert entries_by_id["ranged_columns"].disabled is False
    assert entries_by_id["curio_columns"].disabled is False
    assert entries_by_id["three_column_weapon_name_font_size"].disabled is False
    assert entries_by_id["automatic_card_height"].disabled is False
    assert entries_by_id["card_height"].disabled is True
    assert entries_by_id["enable_hadron_entreat_grid"].disabled is False
    assert entries_by_id["enable_hadron_single_column_mirror"].disabled is True
    assert entries_by_id["enable_armoury_requisition_grid"].disabled is False
    assert entries_by_id["enable_armoury_single_column_mirror"].disabled is True
    assert entries_by_id["enable_armoury_requisition_sorting_panel"].disabled is False
    assert entries_by_id["brighten_armoury_item_levels"].disabled is False
    assert entries_by_id["expand_armoury_requisition_window"].disabled is False
    assert entries_by_id["armoury_requisition_target_card_width"].disabled is False
    assert entries_by_id["enable_global_store_integration"].disabled is False
    assert entries_by_id["enable_global_store_grid"].disabled is False
    assert entries_by_id["enable_global_store_sorting_panel"].disabled is False
    assert entries_by_id["global_store_character_photo_size_percent"].disabled is False
    assert entries_by_id["global_store_price_row_padding"].disabled is False
    assert entries_by_id["global_store_character_info_gap"].disabled is False
    assert entries_by_id["global_store_character_class_icon_size"].disabled is False
    assert entries_by_id["global_store_character_name_font_size"].disabled is False
    assert entries_by_id["global_store_compact_character_names"].disabled is False
    assert entries_by_id["global_store_single_column_modifier_horizontal_position"].disabled is True
    assert entries_by_id["global_store_single_column_modifier_vertical_position"].disabled is True
    assert entries_by_id["character_overview_curio_name_mode"].disabled is False
    assert entries_by_id["character_overview_curio_font_size_percent"].disabled is False
    assert entries_by_id["character_overview_show_melee_rarity_strip"].disabled is False
    assert entries_by_id["character_overview_show_ranged_rarity_strip"].disabled is False
    assert entries_by_id["character_overview_show_curio_rarity_strip"].disabled is False
    assert entries_by_id["character_overview_use_native_curio_overlay"].disabled is False
    settings.enable_character_overview_curio_details = False
    mod.on_setting_changed("enable_character_overview_curio_details")
    assert entries_by_id["character_overview_curio_name_mode"].disabled is True
    assert entries_by_id["character_overview_curio_font_size_percent"].disabled is True
    assert entries_by_id["character_overview_show_curio_rarity_strip"].disabled is True
    assert entries_by_id["character_overview_use_native_curio_overlay"].disabled is True
    settings.enable_character_overview_curio_details = True
    mod.on_setting_changed("enable_character_overview_curio_details")
    assert entries_by_id["character_overview_curio_name_mode"].disabled is False
    assert entries_by_id["character_overview_curio_font_size_percent"].disabled is False
    assert entries_by_id["character_overview_show_curio_rarity_strip"].disabled is False
    assert entries_by_id["character_overview_use_native_curio_overlay"].disabled is False
    assert entries_by_id["expand_curio_inventory_window"].disabled is False
    assert entries_by_id["weapon_extra_width_column_threshold"].disabled is False
    assert entries_by_id["five_column_weapon_extra_width"].disabled is True
    assert entries_by_id["curio_target_card_width"].disabled is False
    assert len(name_it_curio_name_entries) == 2
    assert all(entry.disabled is True for entry in name_it_curio_name_entries)
    settings.curio_display_profile = "detailed"
    mod.on_setting_changed("curio_display_profile")
    assert all(entry.disabled is False for entry in name_it_curio_name_entries)
    settings.name_it_force_curio_name_in_detailed_mode = False
    mod.on_setting_changed("name_it_force_curio_name_in_detailed_mode")
    assert settings.curio_content_name_it_curio_name is False
    settings.curio_content_name_it_curio_name = True
    mod.on_setting_changed("curio_content_name_it_curio_name")
    assert settings.name_it_force_curio_name_in_detailed_mode is True
    settings.curio_display_profile = "primary"
    mod.on_setting_changed("curio_display_profile")
    assert all(entry.disabled is True for entry in name_it_curio_name_entries)
    settings.curio_display_profile = "detailed"
    mod.on_setting_changed("curio_display_profile")
    assert all(entry.disabled is False for entry in name_it_curio_name_entries)
    settings.curio_display_profile = "primary"
    mod.on_setting_changed("curio_display_profile")
    assert entries_by_id["enable_custom_item_name_and_colors"].disabled is False
    assert entries_by_id["custom_item_name_keybind"].disabled is False
    assert entries_by_id["custom_item_name_color_keybind"].disabled is False
    assert entries_by_id["custom_item_background_color_keybind"].disabled is False
    assert entries_by_id["custom_item_skip_confirmation_prompts"].disabled is False
    assert entries_by_id["custom_item_preserve_card_shading"].disabled is False
    assert entries_by_id["custom_item_override_weapon_information_color"].disabled is False
    assert entries_by_id["custom_item_override_weapon_rarity_keyword_color"].disabled is False
    assert entries_by_id["custom_item_override_weapon_information_name_color"].disabled is False
    settings.enable_custom_item_name_and_colors = False
    mod.on_setting_changed("enable_custom_item_name_and_colors")
    assert entries_by_id["custom_item_name_keybind"].disabled is True
    assert entries_by_id["custom_item_name_color_keybind"].disabled is True
    assert entries_by_id["custom_item_background_color_keybind"].disabled is True
    assert entries_by_id["custom_item_skip_confirmation_prompts"].disabled is True
    assert entries_by_id["custom_item_preserve_card_shading"].disabled is True
    assert entries_by_id["custom_item_override_weapon_information_color"].disabled is True
    assert entries_by_id["custom_item_override_weapon_rarity_keyword_color"].disabled is True
    assert entries_by_id["custom_item_override_weapon_information_name_color"].disabled is True
    settings.enable_custom_item_name_and_colors = True
    mod.on_setting_changed("enable_custom_item_name_and_colors")
    assert entries_by_id["custom_item_name_keybind"].disabled is False
    assert entries_by_id["custom_item_name_color_keybind"].disabled is False
    assert entries_by_id["custom_item_background_color_keybind"].disabled is False
    assert entries_by_id["custom_item_skip_confirmation_prompts"].disabled is False
    assert entries_by_id["custom_item_preserve_card_shading"].disabled is False
    assert entries_by_id["custom_item_override_weapon_information_color"].disabled is False
    assert entries_by_id["custom_item_override_weapon_rarity_keyword_color"].disabled is False
    assert entries_by_id["custom_item_override_weapon_information_name_color"].disabled is False
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
    assert entries_by_id["auto_fit_long_blessing_names"].disabled is True
    assert entries_by_id["truncate_long_blessing_names"].disabled is True
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
    assert entries_by_id["single_column_layout_group"].disabled is True
    assert entries_by_id["single_column_weapon_name_font_size"].disabled is True
    assert entries_by_id["single_column_blessing_icons_on_right"].disabled is True
    assert entries_by_id["quick_look_card_single_column_font_size"].disabled is True
    assert entries_by_id["quick_look_card_single_column_label_value_gap"].disabled is True
    assert entries_by_id["quick_look_card_single_column_horizontal_position"].disabled is True
    assert entries_by_id["quick_look_card_single_column_vertical_position"].disabled is True
    assert entries_by_id["quick_look_card_grid_stat_position"].disabled is False
    assert entries_by_id["quick_look_card_grid_font_size"].disabled is False
    assert entries_by_id["quick_look_card_grid_bottom_padding"].disabled is False
    assert entries_by_id["weapon_modifier_lowest_color_preset"].disabled is False
    assert entries_by_id["weapon_modifier_lowest_color_r"].disabled is False
    assert entries_by_id["weapon_modifier_lowest_color_g"].disabled is False
    assert entries_by_id["weapon_modifier_lowest_color_b"].disabled is False
    assert entries_by_id["weapon_modifier_lowest_color_opacity"].disabled is False
    assert entries_by_id["quick_discard_rarity"].disabled is True
    assert entries_by_id["quick_discard_protect_above_equipped_level"].disabled is True
    assert entries_by_id["quick_discard_curio_protection_level"].disabled is True
    assert entries_by_id["quick_discard_keep_health_curios"].disabled is True
    assert entries_by_id["quick_discard_keep_toughness_curios"].disabled is True
    assert entries_by_id["quick_discard_show_type_breakdown"].disabled is True
    assert entries_by_id["quick_discard_show_summary_notification"].disabled is True
    assert entries_by_id["quick_discard_disable_no_eligible_notification"].disabled is True
    assert entries_by_id["automatic_curio_scan_operative_selection"].disabled is True
    assert entries_by_id["automatic_curio_once_per_store_rotation"].disabled is True
    assert entries_by_id["automatic_curio_rescan_on_store_refresh"].disabled is True
    assert entries_by_id["automatic_curio_min_item_level"].disabled is True
    assert entries_by_id["automatic_curio_min_health"].disabled is True
    assert entries_by_id["automatic_curio_min_toughness"].disabled is True
    assert entries_by_id["automatic_curio_diagnostic_logging"].disabled is True
    assert entries_by_id["automatic_curio_disable_no_eligible_notification"].disabled is True
    assert entries_by_id["automatic_curio_target_mode"].disabled is True
    assert entries_by_id["automatic_curio_buy_health"].disabled is True
    assert entries_by_id["automatic_curio_class_cryptic"].disabled is True
    assert entries_by_id["automatic_curio_types_group"].indentation_level == 2
    assert entries_by_id["automatic_curio_classes_group"].indentation_level == 2
    assert entries_by_id["automatic_curio_characters_group"].indentation_level == 2
    # Alf's DMF Extensions pairs definitions and rendered widgets by numeric
    # index. Keep every row in the schema and grey inactive controls instead
    # of filtering them through validation functions.
    assert entries_by_id["automatic_curio_classes_group"].validation_function is None
    assert entries_by_id["automatic_curio_characters_group"].validation_function is None
    assert entries_by_id["automatic_curio_classes_group"].disabled is True
    assert entries_by_id["automatic_curio_characters_group"].disabled is True
    assert active_character_entry.disabled is True
    assert empty_character_entry.disabled is True
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
    assert entries_by_id["quick_discard_curio_protection_level"].validation_function is None
    assert entries_by_id["quick_discard_keep_health_curios"].disabled is False
    assert entries_by_id["quick_discard_keep_toughness_curios"].disabled is False
    assert entries_by_id["quick_discard_keep_wound_curios"].disabled is False
    assert entries_by_id["quick_discard_keep_stamina_curios"].disabled is False
    assert entries_by_id["quick_discard_show_type_breakdown"].disabled is False
    assert entries_by_id["quick_discard_show_summary_notification"].disabled is False
    assert entries_by_id["quick_discard_disable_no_eligible_notification"].disabled is True
    settings.quick_discard_mode = "automatic"
    mod.on_setting_changed("quick_discard_mode")
    assert entries_by_id["quick_discard_disable_no_eligible_notification"].disabled is False
    settings.quick_discard_mode = "manual"
    mod.on_setting_changed("quick_discard_mode")
    settings.quick_discard_protect_high_level_curios = False
    mod.on_setting_changed("quick_discard_protect_high_level_curios")
    assert entries_by_id["quick_discard_curio_protection_level"].disabled is True
    assert entries_by_id["quick_discard_curio_protection_level"].validation_function is None
    assert entries_by_id["quick_discard_keep_health_curios"].disabled is False
    assert entries_by_id["quick_discard_keep_toughness_curios"].disabled is False
    assert entries_by_id["quick_discard_keep_wound_curios"].disabled is False
    assert entries_by_id["quick_discard_keep_stamina_curios"].disabled is False
    assert globals_.quick_discard_syncs > 0
    settings.quick_discard_protect_high_level_curios = True
    settings.enable_experimental_quick_discard = False
    mod.on_setting_changed("enable_experimental_quick_discard")

    settings.enable_automatic_curio_acquisition = True
    mod.on_setting_changed("enable_automatic_curio_acquisition")
    assert entries_by_id["automatic_curio_scan_operative_selection"].disabled is False
    assert entries_by_id["automatic_curio_once_per_store_rotation"].disabled is False
    assert entries_by_id["automatic_curio_rescan_on_store_refresh"].disabled is False
    assert entries_by_id["automatic_curio_min_item_level"].disabled is False
    assert entries_by_id["automatic_curio_min_health"].disabled is False
    assert entries_by_id["automatic_curio_min_toughness"].disabled is False
    assert entries_by_id["automatic_curio_diagnostic_logging"].disabled is False
    assert entries_by_id["automatic_curio_disable_no_eligible_notification"].disabled is False
    assert entries_by_id["automatic_curio_target_mode"].disabled is False
    assert entries_by_id["automatic_curio_buy_health"].disabled is False
    assert entries_by_id["automatic_curio_buy_toughness"].disabled is False
    assert entries_by_id["automatic_curio_buy_stamina"].disabled is False
    assert entries_by_id["automatic_curio_buy_wounds"].disabled is False
    assert entries_by_id["automatic_curio_class_veteran"].disabled is False
    assert entries_by_id["automatic_curio_class_cryptic"].disabled is False
    assert entries_by_id["automatic_curio_classes_group"].disabled is False
    assert entries_by_id["automatic_curio_characters_group"].disabled is True
    settings.automatic_curio_target_mode = "characters"
    mod.on_setting_changed("automatic_curio_target_mode")
    assert entries_by_id["automatic_curio_classes_group"].disabled is True
    assert entries_by_id["automatic_curio_characters_group"].disabled is False
    assert entries_by_id["automatic_curio_class_veteran"].disabled is True
    assert entries_by_id["automatic_curio_class_cryptic"].disabled is True
    assert active_character_entry.disabled is False
    assert empty_character_entry.disabled is True
    assert (
        empty_character_entry.disabled_by[1]
        == "automatic_curio_character_slot_empty_reason"
    )
    settings.automatic_curio_target_mode = "classes"
    mod.on_setting_changed("automatic_curio_target_mode")
    assert entries_by_id["automatic_curio_classes_group"].disabled is False
    assert entries_by_id["automatic_curio_characters_group"].disabled is True
    assert entries_by_id["automatic_curio_class_veteran"].disabled is False
    settings.automatic_curio_buy_health = False
    mod.on_setting_changed("automatic_curio_buy_health")
    assert entries_by_id["automatic_curio_min_health"].disabled is True
    assert entries_by_id["automatic_curio_min_toughness"].disabled is False
    settings.automatic_curio_buy_health = True
    mod.on_setting_changed("automatic_curio_buy_health")
    assert entries_by_id["automatic_curio_min_health"].disabled is False
    assert globals_.curio_acquisition_syncs > 0
    settings.enable_automatic_curio_acquisition = False
    mod.on_setting_changed("enable_automatic_curio_acquisition")
    assert entries_by_id["automatic_curio_min_item_level"].disabled is True

    settings.melee_columns = 4
    mod.on_setting_changed("melee_columns")
    assert entries_by_id["five_column_weapon_extra_width"].disabled is False
    settings.weapon_extra_width_column_threshold = "five_only"
    mod.on_setting_changed("weapon_extra_width_column_threshold")
    assert entries_by_id["five_column_weapon_extra_width"].disabled is True
    settings.melee_columns = 5
    mod.on_setting_changed("melee_columns")
    assert entries_by_id["five_column_weapon_extra_width"].disabled is False
    settings.weapon_extra_width_column_threshold = "four_plus"
    mod.on_setting_changed("weapon_extra_width_column_threshold")
    settings.melee_columns = 3
    mod.on_setting_changed("melee_columns")
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
    assert entries_by_id["auto_fit_long_blessing_names"].disabled is False
    assert entries_by_id["truncate_long_blessing_names"].disabled is False
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
    assert entries_by_id["auto_fit_long_blessing_names"].disabled is True
    assert entries_by_id["truncate_long_blessing_names"].disabled is True
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
    assert entries_by_id["enable_armoury_requisition_sorting_panel"].disabled is True
    assert entries_by_id["brighten_armoury_item_levels"].disabled is True
    assert entries_by_id["expand_armoury_requisition_window"].disabled is True
    assert entries_by_id["armoury_requisition_target_card_width"].disabled is True
    settings.enable_armoury_requisition_grid = True
    mod.on_setting_changed("enable_armoury_requisition_grid")
    assert entries_by_id["enable_armoury_requisition_sorting_panel"].disabled is False
    assert entries_by_id["brighten_armoury_item_levels"].disabled is False
    assert entries_by_id["expand_armoury_requisition_window"].disabled is False
    assert entries_by_id["armoury_requisition_target_card_width"].disabled is False

    settings.enable_global_store_integration = False
    mod.on_setting_changed("enable_global_store_integration")
    assert entries_by_id["enable_global_store_grid"].disabled is True
    assert entries_by_id["enable_global_store_sorting_panel"].disabled is True
    assert entries_by_id["global_store_character_photo_size_percent"].disabled is True
    assert entries_by_id["global_store_price_row_padding"].disabled is True
    assert entries_by_id["global_store_character_info_gap"].disabled is True
    assert entries_by_id["global_store_character_class_icon_size"].disabled is True
    assert entries_by_id["global_store_character_name_font_size"].disabled is True
    assert entries_by_id["global_store_compact_character_names"].disabled is True
    assert entries_by_id["global_store_single_column_modifier_horizontal_position"].disabled is True
    assert entries_by_id["global_store_single_column_modifier_vertical_position"].disabled is True
    settings.enable_global_store_integration = True
    mod.on_setting_changed("enable_global_store_integration")
    assert entries_by_id["enable_global_store_grid"].disabled is False
    assert entries_by_id["enable_global_store_sorting_panel"].disabled is False
    assert entries_by_id["global_store_character_photo_size_percent"].disabled is False
    assert entries_by_id["global_store_price_row_padding"].disabled is False
    assert entries_by_id["global_store_character_info_gap"].disabled is False
    assert entries_by_id["global_store_character_class_icon_size"].disabled is False
    assert entries_by_id["global_store_character_name_font_size"].disabled is False
    assert entries_by_id["global_store_compact_character_names"].disabled is False
    assert entries_by_id["global_store_single_column_modifier_horizontal_position"].disabled is True
    assert entries_by_id["global_store_single_column_modifier_vertical_position"].disabled is True

    settings.enable_global_store_grid = False
    mod.on_setting_changed("enable_global_store_grid")
    assert entries_by_id["enable_global_store_sorting_panel"].disabled is True
    assert entries_by_id["global_store_character_photo_size_percent"].disabled is True
    assert entries_by_id["global_store_price_row_padding"].disabled is True
    assert entries_by_id["global_store_character_info_gap"].disabled is True
    assert entries_by_id["global_store_character_class_icon_size"].disabled is True
    assert entries_by_id["global_store_character_name_font_size"].disabled is True
    assert entries_by_id["global_store_compact_character_names"].disabled is True
    assert entries_by_id["global_store_single_column_modifier_horizontal_position"].disabled is True
    assert entries_by_id["global_store_single_column_modifier_vertical_position"].disabled is True
    settings.enable_global_store_grid = True
    mod.on_setting_changed("enable_global_store_grid")
    assert entries_by_id["enable_global_store_sorting_panel"].disabled is False
    assert entries_by_id["global_store_character_photo_size_percent"].disabled is False
    assert entries_by_id["global_store_price_row_padding"].disabled is False
    assert entries_by_id["global_store_character_info_gap"].disabled is False
    assert entries_by_id["global_store_character_class_icon_size"].disabled is False
    assert entries_by_id["global_store_character_name_font_size"].disabled is False
    assert entries_by_id["global_store_compact_character_names"].disabled is False

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

    settings.enable_quick_look_card_grid_integration = False
    mod.on_setting_changed("enable_quick_look_card_grid_integration")
    assert entries_by_id["quick_look_card_grid_stat_position"].disabled is True
    assert entries_by_id["quick_look_card_grid_font_size"].disabled is True
    assert entries_by_id["quick_look_card_grid_bottom_padding"].disabled is True
    assert entries_by_id["weapon_modifier_lowest_color_preset"].disabled is True
    assert entries_by_id["weapon_modifier_lowest_color_r"].disabled is True
    assert entries_by_id["weapon_modifier_lowest_color_g"].disabled is True
    assert entries_by_id["weapon_modifier_lowest_color_b"].disabled is True
    assert entries_by_id["weapon_modifier_lowest_color_opacity"].disabled is True
    settings.enable_quick_look_card_grid_integration = True
    mod.on_setting_changed("enable_quick_look_card_grid_integration")
    assert entries_by_id["quick_look_card_grid_stat_position"].disabled is False
    assert entries_by_id["quick_look_card_grid_font_size"].disabled is False
    assert entries_by_id["quick_look_card_grid_bottom_padding"].disabled is False
    assert entries_by_id["weapon_modifier_lowest_color_preset"].disabled is False
    assert entries_by_id["weapon_modifier_lowest_color_r"].disabled is False
    assert entries_by_id["weapon_modifier_lowest_color_g"].disabled is False
    assert entries_by_id["weapon_modifier_lowest_color_b"].disabled is False
    assert entries_by_id["weapon_modifier_lowest_color_opacity"].disabled is False

    settings.quick_look_card_grid_stat_position = "name_right"
    mod.on_setting_changed("quick_look_card_grid_stat_position")
    assert entries_by_id["quick_look_card_grid_bottom_padding"].disabled is True
    settings.quick_look_card_grid_stat_position = "above_power"
    mod.on_setting_changed("quick_look_card_grid_stat_position")
    assert entries_by_id["quick_look_card_grid_bottom_padding"].disabled is False

    settings.enable_grid_layout = False
    mod.on_setting_changed("enable_grid_layout")

    for option_id in option_ids:
        if option_id in {
			"single_column_layout_group",
			"single_column_weapon_name_font_size",
			"quick_look_card_single_column_font_size",
			"quick_look_card_single_column_label_value_gap",
			"quick_look_card_single_column_horizontal_position",
			"quick_look_card_single_column_vertical_position",
			"weapon_modifier_lowest_color_preset",
			"weapon_modifier_lowest_color_r",
			"weapon_modifier_lowest_color_g",
			"weapon_modifier_lowest_color_b",
			"weapon_modifier_lowest_color_opacity",
            "blessing_icon_size",
            "blessing_icon_spacing",
            "automatic_curio_types_group",
            "automatic_curio_classes_group",
			"automatic_curio_characters_group",
			"enable_hadron_single_column_mirror",
			"enable_armoury_single_column_mirror",
			"enable_global_store_integration",
			"global_store_character_photo_size_percent",
			"global_store_price_row_padding",
			"global_store_character_info_gap",
			"global_store_character_class_icon_size",
			"global_store_character_name_font_size",
			"global_store_compact_character_names",
			"global_store_single_column_modifier_horizontal_position",
			"global_store_single_column_modifier_vertical_position",
			"name_it_force_curio_name_in_detailed_mode",
			"enable_custom_item_name_and_colors",
			"custom_item_name_keybind",
			"custom_item_name_color_keybind",
			"custom_item_background_color_keybind",
			"custom_item_skip_confirmation_prompts",
			"custom_item_preserve_card_shading",
			"custom_item_override_weapon_information_color",
			"custom_item_override_weapon_rarity_keyword_color",
			"custom_item_override_weapon_information_name_color",
			"character_overview_show_melee_rarity_strip",
			"character_overview_show_ranged_rarity_strip",
			"character_overview_show_curio_rarity_strip",
			"character_overview_use_native_curio_overlay",
			"character_overview_curio_name_mode",
			"character_overview_curio_font_size_percent",
        }:
            continue

        assert entries_by_id[option_id].disabled is True, option_id

    assert entries_by_id["blessing_icon_size"].disabled is False
    assert entries_by_id["blessing_icon_spacing"].disabled is False
    assert entries_by_id["single_column_layout_group"].disabled is False
    assert entries_by_id["enable_hadron_single_column_mirror"].disabled is False
    assert entries_by_id["enable_armoury_single_column_mirror"].disabled is False
    assert entries_by_id["single_column_weapon_name_font_size"].disabled is False
    assert entries_by_id["single_column_blessing_icons_on_right"].disabled is True
    assert entries_by_id["quick_look_card_single_column_font_size"].disabled is False
    assert entries_by_id["quick_look_card_single_column_label_value_gap"].disabled is False
    assert entries_by_id["quick_look_card_single_column_horizontal_position"].disabled is False
    assert entries_by_id["quick_look_card_single_column_vertical_position"].disabled is False
    assert entries_by_id["global_store_character_photo_size_percent"].disabled is False
    assert entries_by_id["global_store_price_row_padding"].disabled is False
    assert entries_by_id["global_store_character_info_gap"].disabled is False
    assert entries_by_id["global_store_character_class_icon_size"].disabled is False
    assert entries_by_id["global_store_character_name_font_size"].disabled is False
    assert entries_by_id["global_store_compact_character_names"].disabled is False
    assert entries_by_id["global_store_single_column_modifier_horizontal_position"].disabled is False
    assert entries_by_id["global_store_single_column_modifier_vertical_position"].disabled is False
    assert entries_by_id["weapon_modifier_lowest_color_preset"].disabled is False
    assert entries_by_id["weapon_modifier_lowest_color_r"].disabled is False
    assert entries_by_id["weapon_modifier_lowest_color_g"].disabled is False
    assert entries_by_id["weapon_modifier_lowest_color_b"].disabled is False
    assert entries_by_id["weapon_modifier_lowest_color_opacity"].disabled is False

    settings.weapon_blessing_display_mode = "ranked_text"
    mod.on_setting_changed("weapon_blessing_display_mode")
    assert entries_by_id["single_column_blessing_icons_on_right"].disabled is False
    assert entries_by_id["blessing_icon_size"].disabled is False
    assert entries_by_id["blessing_icon_spacing"].disabled is False
    settings.weapon_blessing_display_mode = "text"
    mod.on_setting_changed("weapon_blessing_display_mode")
    assert entries_by_id["single_column_blessing_icons_on_right"].disabled is False
    assert entries_by_id["blessing_icon_size"].disabled is False
    assert entries_by_id["blessing_icon_spacing"].disabled is False
    settings.single_column_blessing_icons_on_right = False
    mod.on_setting_changed("single_column_blessing_icons_on_right")
    assert entries_by_id["blessing_icon_size"].disabled is True
    assert entries_by_id["blessing_icon_spacing"].disabled is True
    settings.single_column_blessing_icons_on_right = True
    mod.on_setting_changed("single_column_blessing_icons_on_right")
    assert entries_by_id["blessing_icon_size"].disabled is False
    assert entries_by_id["blessing_icon_spacing"].disabled is False
    settings.weapon_blessing_display_mode = "ranked_text"
    mod.on_setting_changed("weapon_blessing_display_mode")
    settings.enable_quick_look_card_single_column_integration = False
    mod.on_setting_changed("enable_quick_look_card_single_column_integration")
    assert entries_by_id["quick_look_card_single_column_font_size"].disabled is True
    assert entries_by_id["quick_look_card_single_column_label_value_gap"].disabled is True
    assert entries_by_id["quick_look_card_single_column_horizontal_position"].disabled is True
    assert entries_by_id["quick_look_card_single_column_vertical_position"].disabled is True
    assert entries_by_id["weapon_modifier_lowest_color_preset"].disabled is True
    assert entries_by_id["weapon_modifier_lowest_color_r"].disabled is True
    assert entries_by_id["weapon_modifier_lowest_color_g"].disabled is True
    assert entries_by_id["weapon_modifier_lowest_color_b"].disabled is True
    assert entries_by_id["weapon_modifier_lowest_color_opacity"].disabled is True

    data = lua.execute(DATA_PATH.read_text(encoding="utf-8"))
    localization = lua.execute(LOCALIZATION_PATH.read_text(encoding="utf-8"))
    defaults = {}
    setting_ids = set()

    assert data.version == "1.9.4"
    assert (
        localization["quick_look_card_integration_group"]["en"]
        == "Mod Integration: Quick Look Card"
    )

    for localization_id, localized_values in localization.items():
        simplified_chinese = localized_values["zh-cn"]
        assert isinstance(simplified_chinese, str), localization_id
        assert simplified_chinese.strip(), localization_id
        assert "{" not in simplified_chinese, localization_id
        assert "}" not in simplified_chinese, localization_id

    def inspect_widgets(widgets) -> None:
        for index in range(1, len(widgets) + 1):
            widget = widgets[index]
            setting_id = widget.setting_id

            assert setting_id not in setting_ids, f"Duplicate setting_id: {setting_id}"
            setting_ids.add(setting_id)
            assert localization[setting_id] is not None, setting_id

            if widget.default_value is not None:
                defaults[setting_id] = widget.default_value

            options = widget.options

            if options is not None:
                for option_index in range(1, len(options) + 1):
                    assert localization[options[option_index].text] is not None

            sub_widgets = widget.sub_widgets

            if widget.type == "group":
                assert sub_widgets is not None and len(sub_widgets) > 0, setting_id

            if sub_widgets is not None:
                inspect_widgets(sub_widgets)

    inspect_widgets(data.options.widgets)

    automatic_curio_group = next(
        data.options.widgets[index]
        for index in range(1, len(data.options.widgets) + 1)
        if data.options.widgets[index].setting_id == "automatic_curio_buyer_group"
    )
    automatic_curio_enabled = automatic_curio_group.sub_widgets[1]
    assert automatic_curio_enabled.setting_id == "enable_automatic_curio_acquisition"
    character_group = next(
        automatic_curio_enabled.sub_widgets[index]
        for index in range(1, len(automatic_curio_enabled.sub_widgets) + 1)
        if automatic_curio_enabled.sub_widgets[index].setting_id
        == "automatic_curio_characters_group"
    )
    assert len(character_group.sub_widgets) == 10
    for slot_index in range(1, 11):
        slot = character_group.sub_widgets[slot_index]
        assert slot.setting_id == f"automatic_curio_character_slot_{slot_index}"
        assert slot.type == "checkbox"
        assert slot.default_value is False

    top_level_ids = [
        data.options.widgets[index].setting_id
        for index in range(1, len(data.options.widgets) + 1)
    ]
    assert "debug_group" in top_level_ids
    debug_group = next(
        data.options.widgets[index]
        for index in range(1, len(data.options.widgets) + 1)
        if data.options.widgets[index].setting_id == "debug_group"
    )
    assert [
        debug_group.sub_widgets[index].setting_id
        for index in range(1, len(debug_group.sub_widgets) + 1)
    ] == [
        "debug_expand_armoury_requisition_window_30_percent",
        "debug_armoury_requisition_window_increase_percent",
		"debug_adjust_inventory_window_width",
		"debug_inventory_window_width_adjustment_percent",
		"debug_adjust_global_store_window_width",
		"debug_global_store_window_width_adjustment_percent",
    ]
    additional_views_group = next(
        data.options.widgets[index]
        for index in range(1, len(data.options.widgets) + 1)
        if data.options.widgets[index].setting_id == "additional_views_group"
    )
    additional_view_ids = [
        additional_views_group.sub_widgets[index].setting_id
        for index in range(1, len(additional_views_group.sub_widgets) + 1)
    ]
    assert additional_view_ids == [
        "hadron_additional_views_group",
        "armoury_exchange_views_group",
        "global_store_integration_group",
        "character_overview_group",
    ]
    myfavorites_group = next(
        data.options.widgets[index]
        for index in range(1, len(data.options.widgets) + 1)
        if data.options.widgets[index].setting_id == "myfavorites_integration_group"
    )
    assert [
        myfavorites_group.sub_widgets[index].setting_id
        for index in range(1, len(myfavorites_group.sub_widgets) + 1)
    ] == ["myfavorites_show_favorite_letter"]
    lantern_group = next(
        data.options.widgets[index]
        for index in range(1, len(data.options.widgets) + 1)
        if data.options.widgets[index].setting_id == "lantern_integration_group"
    )
    assert [
        lantern_group.sub_widgets[index].setting_id
        for index in range(1, len(lantern_group.sub_widgets) + 1)
    ] == [
        "enable_lantern_inventory_section",
        "keep_lantern_curio_panel_separate",
    ]
    assert lantern_group.sub_widgets[1].default_value is True
    assert lantern_group.sub_widgets[2].default_value is True
    hadron_view_group = additional_views_group.sub_widgets[1]
    assert [
        hadron_view_group.sub_widgets[index].setting_id
        for index in range(1, len(hadron_view_group.sub_widgets) + 1)
    ] == [
        "enable_hadron_entreat_grid",
        "enable_hadron_single_column_mirror",
    ]
    armoury_view_group = additional_views_group.sub_widgets[2]
    armoury_view_ids = [
        armoury_view_group.sub_widgets[index].setting_id
        for index in range(1, len(armoury_view_group.sub_widgets) + 1)
    ]
    assert armoury_view_ids == [
        "enable_armoury_requisition_grid",
        "enable_armoury_single_column_mirror",
        "enable_armoury_requisition_sorting_panel",
        "brighten_armoury_item_levels",
        "three_column_weapon_name_font_size",
        "expand_armoury_requisition_window",
        "armoury_requisition_target_card_width",
    ]
    global_store_view_group = additional_views_group.sub_widgets[3]
    assert [
        global_store_view_group.sub_widgets[index].setting_id
        for index in range(1, len(global_store_view_group.sub_widgets) + 1)
    ] == [
        "enable_global_store_integration",
        "enable_global_store_grid",
        "enable_global_store_sorting_panel",
        "global_store_character_photo_size_percent",
        "global_store_price_row_padding",
        "global_store_character_info_gap",
        "global_store_character_class_icon_size",
        "global_store_character_name_font_size",
        "global_store_compact_character_names",
        "global_store_single_column_modifier_horizontal_position",
        "global_store_single_column_modifier_vertical_position",
    ]
    character_overview_view_group = additional_views_group.sub_widgets[4]
    assert [
        character_overview_view_group.sub_widgets[index].setting_id
        for index in range(1, len(character_overview_view_group.sub_widgets) + 1)
    ] == [
        "enable_character_overview_melee_mirror",
        "character_overview_show_melee_rarity_strip",
        "enable_character_overview_ranged_mirror",
        "character_overview_show_ranged_rarity_strip",
        "enable_character_overview_curio_details",
        "character_overview_show_curio_rarity_strip",
        "character_overview_use_native_curio_overlay",
        "character_overview_curio_name_mode",
        "character_overview_curio_font_size_percent",
    ]
    additional_views_index = top_level_ids.index("additional_views_group")
    assert top_level_ids[additional_views_index + 1] == "layout_group"
    grid_layout_index = top_level_ids.index("layout_group")
    assert top_level_ids[grid_layout_index - 1] == "additional_views_group"
    assert top_level_ids[grid_layout_index + 1] == "single_column_layout_group"
    customization_index = top_level_ids.index("custom_item_name_and_colors_group")
    assert top_level_ids[customization_index - 1] == "single_column_layout_group"
    assert top_level_ids[customization_index + 1] == "quick_look_card_integration_group"
    enhanced_descriptions_index = top_level_ids.index(
        "enhanced_descriptions_integration_group"
    )
    assert (
        top_level_ids[enhanced_descriptions_index - 1]
        == "quick_look_card_integration_group"
    )
    assert top_level_ids[enhanced_descriptions_index + 1] == "myfavorites_integration_group"
    assert top_level_ids[enhanced_descriptions_index + 2] == "lantern_integration_group"
    assert top_level_ids[enhanced_descriptions_index + 3] == "card_content_group"

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
    assert curio_content_ids.count("curio_content_name_it_curio_name") == 1
    assert curio_content_ids.index("curio_content_name_it_curio_name") == (
        curio_content_ids.index("curio_display_profile") + 1
    )
    enhanced_descriptions_group = next(
        data.options.widgets[index]
        for index in range(1, len(data.options.widgets) + 1)
        if data.options.widgets[index].setting_id
        == "enhanced_descriptions_integration_group"
    )
    enhanced_descriptions_ids = [
        enhanced_descriptions_group.sub_widgets[index].setting_id
        for index in range(1, len(enhanced_descriptions_group.sub_widgets) + 1)
    ]
    assert enhanced_descriptions_ids == ["simplify_curio_primary_stat_text"]
    assert "simplify_curio_primary_stat_text" not in curio_content_ids
    assert curio_content_ids.index("curio_secondary_text_color_group") > curio_content_ids.index("curio_stamina_color_group")

    assert defaults["enable_grid_layout"] is True
    assert defaults["melee_columns"] == 3
    assert defaults["ranged_columns"] == 3
    assert defaults["curio_columns"] == 3
    assert defaults["enable_hadron_single_column_mirror"] is True
    assert defaults["enable_armoury_single_column_mirror"] is True
    assert defaults["enable_character_overview_melee_mirror"] is True
    assert defaults["character_overview_show_melee_rarity_strip"] is True
    assert defaults["enable_character_overview_ranged_mirror"] is True
    assert defaults["character_overview_show_ranged_rarity_strip"] is True
    assert defaults["enable_character_overview_curio_details"] is True
    assert defaults["character_overview_show_curio_rarity_strip"] is True
    assert defaults["character_overview_use_native_curio_overlay"] is False
    assert defaults["myfavorites_show_favorite_letter"] is False
    assert defaults["character_overview_curio_name_mode"] == "two_lines"
    assert defaults["character_overview_curio_font_size_percent"] == 110
    assert defaults["three_column_weapon_name_font_size"] == 14
    assert defaults["enable_global_store_integration"] is True
    assert defaults["enable_global_store_grid"] is True
    assert defaults["enable_global_store_sorting_panel"] is True
    assert defaults["global_store_character_photo_size_percent"] == 110
    assert defaults["global_store_price_row_padding"] == 10
    assert defaults["global_store_character_info_gap"] == 5
    assert defaults["global_store_character_class_icon_size"] == 16
    assert defaults["global_store_character_name_font_size"] == 16
    assert defaults["global_store_compact_character_names"] is True
    assert defaults["global_store_single_column_modifier_horizontal_position"] == 55
    assert defaults["global_store_single_column_modifier_vertical_position"] == 100
    assert defaults["enable_quick_look_card_single_column_integration"] is True
    assert defaults["name_it_force_curio_name_in_detailed_mode"] is True
    assert defaults["enable_custom_item_name_and_colors"] is True
    assert defaults["custom_item_name_keybind"] == "lobby_open_inventory"
    assert defaults["custom_item_name_color_keybind"] == "hotkey_menu_special_1"
    assert defaults["inventory_options_controller_focus_keybind"] == "navigate_secondary_right_pressed"
    assert defaults["custom_item_background_color_keybind"] == "navigate_secondary_left_pressed"
    assert defaults["custom_item_skip_confirmation_prompts"] is True
    assert defaults["custom_item_preserve_card_shading"] is True
    assert defaults["custom_item_override_weapon_information_color"] is True
    assert defaults["custom_item_override_weapon_rarity_keyword_color"] is True
    assert defaults["custom_item_override_weapon_information_name_color"] is True
    assert defaults["quick_look_card_single_column_font_size"] == 14
    assert defaults["quick_look_card_single_column_label_value_gap"] == 1
    assert defaults["quick_look_card_single_column_horizontal_position"] == 79
    assert defaults["quick_look_card_single_column_vertical_position"] == 93
    assert defaults["enable_quick_look_card_grid_integration"] is True
    assert defaults["quick_look_card_grid_stat_position"] == "above_power"
    assert defaults["quick_look_card_grid_font_size"] == 13
    assert defaults["quick_look_card_grid_bottom_padding"] == 26
    assert defaults["weapon_modifier_lowest_color_preset"] == "pink"
    assert defaults["weapon_modifier_lowest_color_r"] == 255
    assert defaults["weapon_modifier_lowest_color_g"] == 94
    assert defaults["weapon_modifier_lowest_color_b"] == 132
    assert defaults["weapon_modifier_lowest_color_opacity"] == 80
    assert defaults["single_column_weapon_name_font_size"] == 20
    assert defaults["single_column_blessing_icons_on_right"] is True
    assert defaults["enable_hadron_entreat_grid"] is True
    assert defaults["enable_armoury_requisition_grid"] is True
    assert defaults["enable_armoury_requisition_sorting_panel"] is True
    assert defaults["brighten_armoury_item_levels"] is True
    assert defaults["expand_armoury_requisition_window"] is True
    assert defaults["armoury_requisition_target_card_width"] == 230
    assert defaults["debug_expand_armoury_requisition_window_30_percent"] is False
    assert defaults["debug_armoury_requisition_window_increase_percent"] == 30
    assert defaults["debug_adjust_inventory_window_width"] is False
    assert defaults["debug_inventory_window_width_adjustment_percent"] == 30
    assert defaults["debug_adjust_global_store_window_width"] is False
    assert defaults["debug_global_store_window_width_adjustment_percent"] == 30
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
    assert defaults["auto_fit_long_blessing_names"] is True
    assert defaults["truncate_long_blessing_names"] is False
    assert "show_weapon_blessings" not in defaults
    assert defaults["show_weapon_perks"] is True
    assert defaults["weapon_perk_compression"] == "heavy"
    assert defaults["show_weapon_perk_rank_symbols"] is True
    assert defaults["weapon_perk_rank_icon_size"] == 17
    assert defaults["remove_weapon_perk_plus_signs"] is False
    assert defaults["curio_display_profile"] == "detailed"
    assert defaults["show_curio_item_level"] is True
    assert defaults["prioritize_equipped_favorites"] is True
    assert defaults["show_inventory_options_widget"] is True
    assert defaults["prioritize_perfect_roll_weapons"] is True
    assert defaults["enable_inventory_options_panel_prototype"] is True
    assert defaults["automatic_curio_target_mode"] == "characters"
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
    assert defaults["quick_discard_disable_no_eligible_notification"] is False
    assert defaults["enable_automatic_curio_acquisition"] is False
    assert defaults["automatic_curio_scan_operative_selection"] is False
    assert defaults["automatic_curio_once_per_store_rotation"] is False
    assert defaults["automatic_curio_rescan_on_store_refresh"] is False
    assert defaults["automatic_curio_min_item_level"] == 410
    assert defaults["automatic_curio_min_health"] == 21
    assert defaults["automatic_curio_min_toughness"] == 17
    assert defaults["automatic_curio_diagnostic_logging"] is False
    assert defaults["automatic_curio_disable_no_eligible_notification"] is False
    assert defaults["automatic_curio_buy_health"] is True
    assert defaults["automatic_curio_buy_toughness"] is True
    assert defaults["automatic_curio_buy_stamina"] is False
    assert defaults["automatic_curio_buy_wounds"] is False
    for class_setting in (
        "automatic_curio_class_veteran",
        "automatic_curio_class_zealot",
        "automatic_curio_class_psyker",
        "automatic_curio_class_ogryn",
        "automatic_curio_class_adamant",
        "automatic_curio_class_broker",
        "automatic_curio_class_cryptic",
    ):
        assert defaults[class_setting] is True
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

    # A failed hot-reload dependency must disable that feature module once. It
    # must never leave a boolean upvalue that raises again on every frame.
    globals_.fail_feature_load = True
    lua.execute(MAIN_PATH.read_text(encoding="utf-8"))
    assert globals_.captured_module_errors == 1
    globals_.test_mod.update(0.016)
    globals_.test_mod.update(0.016)
    assert globals_.captured_module_errors == 1

    print("BetterInventory live setting synchronization tests passed.")


if __name__ == "__main__":
    main()
