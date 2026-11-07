local OptionDependencies = {}
local AUTOMATIC_CURIO_SETTING_IDS = {
	"automatic_curio_scan_operative_selection", "automatic_curio_once_per_store_rotation",
	"automatic_curio_rescan_on_store_refresh", "automatic_curio_favorite_purchased_curios",
	"automatic_curio_consecrate_transcendent",
	"automatic_curio_min_item_level", "automatic_curio_owned_target_per_stat",
	"automatic_curio_min_health", "automatic_curio_min_toughness", "automatic_curio_min_stamina",
	"automatic_curio_diagnostic_logging", "automatic_curio_disable_no_eligible_notification",
	"automatic_curio_target_mode", "automatic_curio_buy_health", "automatic_curio_buy_toughness",
	"automatic_curio_buy_stamina", "automatic_curio_buy_wounds",
}

-- Builds the Mod Options dependency greying and colour-preset machinery for one
-- Runtime.install() pass. State (bound option entries) is per instance.
function OptionDependencies.create(context)
	local mod = context.mod
	local Layout = context.Layout
	local FavoriteIntegration = context.FavoriteIntegration
	-- A fresh owner per install retires bindings from an earlier runtime load.
	local option_dependency_owner = {}

	mod._better_inventory_option_dependency_owner = option_dependency_owner

	local COLOR_PRESETS = {
		custom_tier_red = {
			210,
			30,
			40,
		},
		red = {
			235,
			85,
			85,
		},
		light_blue = {
			105,
			200,
			235,
		},
		sky_blue = {
			144,
			213,
			255,
		},
		purple = {
			190,
			105,
			230,
		},
		pink = {
			255,
			94,
			132,
		},
		orange = {
			235,
			155,
			60,
		},
		yellow = {
			235,
			205,
			80,
		},
		gold = {
			250,
			189,
			73,
		},
		green = {
			105,
			210,
			120,
		},
		light_green = {
			190,
			210,
			180,
		},
		terminal_green = {
			113,
			126,
			103,
		},
		white = {
			255,
			255,
			255,
		},
		neutral = {
			220,
			230,
			210,
		},
	}
	local COLOR_TARGETS = {
		{
			prefix = "custom_tier_color",
			default_preset = "custom_tier_red",
		},
		{
			prefix = "new_item_highlight_color",
			default_preset = "green",
			mode_default_color = function()
				local mode = mod:get("new_item_highlight_mode")

				return (mode == "animated_dashes" or mode == "pulsing_dashes" or mode == "solid_border") and COLOR_PRESETS.gold or COLOR_PRESETS.white
			end,
		},
		{
			prefix = "equipped_highlight_color",
			default_preset = "gold",
			mode_default_color = function()
				local mode = mod:get("highlight_equipped_items")

				return (mode == "animated_dashes" or mode == "pulsing_dashes" or mode == "solid_border") and COLOR_PRESETS.gold or COLOR_PRESETS.white
			end,
		},
		{
			prefix = "weapon_perk_text_color",
			default_preset = "light_green",
		},
		{
			prefix = "weapon_blessing_text_color",
			default_preset = "light_blue",
		},
		{
			prefix = "weapon_modifier_lowest_color",
			default_preset = "pink",
		},
		{
			prefix = "character_overview_dump_stat_color",
			default_preset = "pink",
		},
	}

	for prefix, preset in pairs({
		curio_secondary_text_color="neutral",curio_health_color="red",curio_toughness_color="light_blue",
		curio_wound_color="purple",curio_stamina_color="yellow",curio_enemy_resistance_color="pink",
		curio_corruption_resistance_color="purple",curio_ability_regeneration_color="green",
		curio_mission_rewards_color="custom",curio_revive_speed_color="neutral",
	}) do
		COLOR_TARGETS[#COLOR_TARGETS + 1] = { prefix = prefix, default_preset = preset }
	end

	local color_target_by_setting_id = {}
	local equipped_highlight_color_target
	local new_item_highlight_color_target
	local option_dependency_entries = {}
	local CHARACTER_OVERVIEW_DUMP_STAT_STYLE_SETTING_IDS = {
		character_overview_dump_stat_horizontal_offset = true,
		character_overview_dump_stat_font_scale_percent = true,
		character_overview_dump_stat_color_preset = true,
		character_overview_dump_stat_color_r = true,
		character_overview_dump_stat_color_g = true,
		character_overview_dump_stat_color_b = true,
	}
	local HIGHLIGHT_MODE_SETTING_IDS = {
		highlight_equipped_items = true,
		new_item_highlight_mode = true,
	}

	for i = 1, #COLOR_TARGETS do
		local target = COLOR_TARGETS[i]

		if target.prefix == "equipped_highlight_color" then
			equipped_highlight_color_target = target
		elseif target.prefix == "new_item_highlight_color" then
			new_item_highlight_color_target = target
		end

		target.preset_id = target.prefix .. "_preset"
		target.channel_ids = {
			target.prefix .. "_r",
			target.prefix .. "_g",
			target.prefix .. "_b",
		}
		color_target_by_setting_id[target.preset_id] = {
			target = target,
			is_preset = true,
		}

		for channel = 1, 3 do
			color_target_by_setting_id[target.channel_ids[channel]] = {
				target = target,
				is_preset = false,
			}
		end
	end

	local function apply_color_preset(target)
		local preset_id = mod:get(target.preset_id) or target.default_preset
		local color = preset_id == "mode_default" and target.mode_default_color and target.mode_default_color() or COLOR_PRESETS[preset_id]

		if not color then
			return
		end

		for channel = 1, 3 do
			mod:set(target.channel_ids[channel], color[channel], false)
		end
	end

	local function set_option_enabled(entry, on, reason)
		if not entry then
			return
		end

		entry.disabled = not on

		if on then
			entry.disabled_by = nil
			return
		end

		local list = type(entry.disabled_by) == "table" and entry.disabled_by or {}

		for key in pairs(list) do list[key] = nil end

		list[1] = reason
		entry.disabled_by = list
	end

	local function character_overview_dump_stat_style_state()
		local weapon_enabled = (mod:get("enable_character_overview_melee_mirror") ~= false or mod:get("enable_character_overview_ranged_mirror") ~= false)
			and mod:get("enable_quick_look_card_single_column_integration") ~= false
		local enabled = weapon_enabled and mod:get("character_overview_show_only_dump_stat") ~= false
		local reason = weapon_enabled and mod:localize("option_requires_character_overview_dump_stat_only") or mod:localize("option_requires_character_overview_weapon_mirror")

		return enabled, reason
	end

	local function bind_live_option_dependency(setting_id, entry)
		if not CHARACTER_OVERVIEW_DUMP_STAT_STYLE_SETTING_IDS[setting_id] or mod._better_inventory_option_dependency_owner ~= option_dependency_owner then
			return
		end

		local state = entry._better_inventory_live_dependency_state

		if type(state) == "table" then
			state.owner = option_dependency_owner
			state.refresh = character_overview_dump_stat_style_state

			return
		elseif entry._better_inventory_live_dependency_getter then
			return
		end

		local original_get_function = entry.get_function

		if type(original_get_function) ~= "function" then
			return
		end

		state = {
			owner = option_dependency_owner,
			original = original_get_function,
			refresh = character_overview_dump_stat_style_state,
		}
		entry._better_inventory_live_dependency_state = state
		entry.get_function = function(...)
			local active_state = entry._better_inventory_live_dependency_state
			local enabled, reason = active_state.refresh()

			entry.disabled = not enabled
			entry.disabled_by = enabled and nil or {
				reason,
			}

			return active_state.original(...)
		end
	end

	local function refresh_highlight_option_dependencies(entries)
		if type(entries) ~= "table" then
			return
		end

		local equipped_mode = mod:get("highlight_equipped_items")
		local equipped_enabled = equipped_mode ~= "off" and equipped_mode ~= false
		local equipped_glow_enabled = equipped_mode == "soft_glow" or equipped_mode == true
		local equipped_dashes_enabled = equipped_mode == "animated_dashes" or equipped_mode == "pulsing_dashes"
		local equipped_solid_enabled = equipped_mode == "solid_border"
		local equipped_reason = mod:localize("option_requires_equipped_highlight")

		set_option_enabled(entries.equipped_highlight_color_preset, equipped_enabled, equipped_reason)
		set_option_enabled(entries.equipped_highlight_color_r, equipped_enabled, equipped_reason)
		set_option_enabled(entries.equipped_highlight_color_g, equipped_enabled, equipped_reason)
		set_option_enabled(entries.equipped_highlight_color_b, equipped_enabled, equipped_reason)
		set_option_enabled(entries.equipped_highlight_glow_intensity, equipped_glow_enabled, mod:localize("option_requires_equipped_highlight_soft_glow"))
		set_option_enabled(entries.equipped_highlight_animated_border_width, equipped_dashes_enabled, mod:localize("option_requires_equipped_highlight_animated_dashes"))
		set_option_enabled(entries.equipped_highlight_solid_border_width, equipped_solid_enabled, mod:localize("option_requires_equipped_highlight_solid_border"))

		local new_item_mode = mod:get("new_item_highlight_mode")
		local new_item_enhanced = new_item_mode ~= "native"
		local new_item_glow_enabled = new_item_mode == "soft_glow"
		local new_item_dashes_enabled = new_item_mode == "animated_dashes" or new_item_mode == "pulsing_dashes"
		local new_item_solid_enabled = new_item_mode == "solid_border"
		local new_item_reason = mod:localize("option_requires_new_item_enhanced_highlight")

		set_option_enabled(entries.new_item_highlight_color_preset, new_item_enhanced, new_item_reason)
		set_option_enabled(entries.new_item_highlight_color_r, new_item_enhanced, new_item_reason)
		set_option_enabled(entries.new_item_highlight_color_g, new_item_enhanced, new_item_reason)
		set_option_enabled(entries.new_item_highlight_color_b, new_item_enhanced, new_item_reason)
		set_option_enabled(entries.new_item_highlight_glow_intensity, new_item_glow_enabled, mod:localize("option_requires_new_item_soft_glow"))
		set_option_enabled(entries.new_item_highlight_animated_border_width, new_item_dashes_enabled, mod:localize("option_requires_new_item_animated_dashes"))
		set_option_enabled(entries.new_item_highlight_solid_border_width, new_item_solid_enabled, mod:localize("option_requires_new_item_solid_border"))
	end

	local function bind_highlight_mode_dependency_refresh(setting_id, entry, entries)
		if not HIGHLIGHT_MODE_SETTING_IDS[setting_id] or type(entry.on_activated) ~= "function" then
			return
		end

		local original_on_activated = entry._better_inventory_original_on_activated or entry.on_activated

		entry._better_inventory_original_on_activated = original_on_activated
		entry.on_activated = function(...)
			local result = original_on_activated(...)

			-- DMF saves the dropdown value synchronously in the original callback.
			-- Refresh this exact generated options tree once after the save so an
			-- older live view is not coupled to a later cached tree.
			refresh_highlight_option_dependencies(entries)

			return result
		end
	end

	local function refresh_option_dependencies()
		local grid_enabled = mod:get("enable_grid_layout") ~= false
		local single_column_enabled = not grid_enabled
		local automatic_height = mod:get("automatic_card_height") ~= false
		local native_reason = mod:localize("option_requires_grid_layout")
		local single_column_reason = mod:localize("option_requires_single_column_mode")

		for _, setting_id in ipairs({
			"melee_columns",
			"ranged_columns",
			"curio_columns",
			"expand_inventory_window",
			"grid_spacing",
			"automatic_card_height",
			"enable_hadron_entreat_grid",
			"enable_armoury_requisition_grid",
			"enable_melk_limited_grid",
			"enable_melk_multi_operative_grid",
			"enable_global_store_grid",
		}) do
			set_option_enabled(option_dependency_entries[setting_id], grid_enabled, native_reason)
		end

		set_option_enabled(option_dependency_entries.enable_hadron_single_column_mirror, single_column_enabled, single_column_reason)
		set_option_enabled(option_dependency_entries.enable_armoury_single_column_mirror, single_column_enabled, single_column_reason)

		local card_height_enabled = grid_enabled and not automatic_height
		local card_height_reason = grid_enabled and mod:localize("option_disabled_by_automatic_height") or native_reason

		set_option_enabled(option_dependency_entries.card_height, card_height_enabled, card_height_reason)

		local window_expansion_enabled = grid_enabled and mod:get("expand_inventory_window") ~= false
		local curio_expansion_enabled = window_expansion_enabled and mod:get("expand_curio_inventory_window") ~= false
		local expansion_reason = grid_enabled and mod:localize("option_requires_window_expansion") or native_reason
		local weapon_columns = math.max(Layout.columns(mod, 5, "melee"), Layout.columns(mod, 5, "ranged"))
		local weapon_width_threshold = mod:get("weapon_extra_width_column_threshold") == "five_only" and 5 or 4
		local weapon_extra_width_enabled = window_expansion_enabled and weapon_columns >= weapon_width_threshold
		local weapon_extra_width_reason = not window_expansion_enabled and expansion_reason or mod:localize("option_requires_weapon_extra_width_threshold")
		local curio_target_reason = not window_expansion_enabled and expansion_reason or not curio_expansion_enabled and mod:localize("option_requires_curio_expansion") or nil
		local armoury_grid_enabled = grid_enabled and mod:get("enable_armoury_requisition_grid") ~= false
		local global_store_grid_enabled = grid_enabled and mod:get("enable_global_store_grid") ~= false
		local global_store_integration_enabled = mod:get("enable_global_store_integration") ~= false
		local global_store_native_enabled = global_store_integration_enabled and not grid_enabled
		local armoury_expansion_enabled = armoury_grid_enabled and mod:get("expand_armoury_requisition_window") ~= false
		local armoury_reason = grid_enabled and mod:localize("option_requires_armoury_grid") or native_reason
		local armoury_target_reason = armoury_grid_enabled and mod:localize("option_requires_armoury_expansion") or armoury_reason
		local weapon_perks_enabled = mod:get("show_weapon_perks") ~= false
		local weapon_perk_ranks_enabled = weapon_perks_enabled and mod:get("show_weapon_perk_rank_symbols") ~= false
		local weapon_blessing_mode = mod:get("weapon_blessing_display_mode") or "ranked_text"
		local weapon_blessing_icons_enabled = weapon_blessing_mode == "icons"
		local weapon_blessing_ranked_text_enabled = weapon_blessing_mode == "ranked_text"
		local weapon_blessing_text_enabled = weapon_blessing_mode == "text" or weapon_blessing_ranked_text_enabled
		local weapon_blessings_enabled = weapon_blessing_mode ~= "off"
		local single_column_blessing_icons_enabled = single_column_enabled and weapon_blessing_text_enabled and mod:get("single_column_blessing_icons_on_right") ~= false
		local blessing_icon_controls_enabled = weapon_blessing_icons_enabled or single_column_blessing_icons_enabled
		local blessing_icon_controls_reason = single_column_enabled and weapon_blessing_text_enabled and mod:localize("option_requires_single_column_blessing_icons") or mod:localize("option_requires_weapon_blessings")
		local weapon_rank_symbols_enabled = weapon_perk_ranks_enabled or weapon_blessing_ranked_text_enabled
		local weapon_perk_blessing_sections_enabled = weapon_perks_enabled and weapon_blessings_enabled
		local detailed_curio_profile = (mod:get("curio_display_profile") or "detailed") == "detailed"
		local weapon_rarity_rating_enabled = mod:get("weapon_rarity_rating_mode") ~= "off" or mod:get("character_overview_weapon_rarity_rating_mode") ~= "off"
		local curio_rarity_rating_enabled = mod:get("curio_rarity_rating_mode") ~= "off" or mod:get("character_overview_curio_rarity_rating_mode") ~= "off"
		local wkc_zero_kills_enabled = mod:get("weapon_kill_counter_show_zero_kills") ~= false
		local quick_discard_enabled = mod:get("enable_experimental_quick_discard") == true
		local quick_discard_reason = mod:localize("option_requires_experimental_quick_discard")
		local automatic_curio_enabled = mod:get("enable_automatic_curio_acquisition") == true
		local automatic_curio_reason = mod:localize("option_requires_automatic_curio_acquisition")
		local automatic_curio_character_mode = mod:get("automatic_curio_target_mode") ~= "classes"
		local automatic_curio_classes_enabled = automatic_curio_enabled and not automatic_curio_character_mode
		local automatic_curio_characters_enabled = automatic_curio_enabled and automatic_curio_character_mode
		local automatic_curio_classes_reason = automatic_curio_enabled and mod:localize("option_requires_automatic_curio_classes_mode") or automatic_curio_reason
		local automatic_curio_characters_reason = automatic_curio_enabled and mod:localize("option_requires_automatic_curio_characters_mode") or automatic_curio_reason
		local lantern_installed = get_mod("Lantern of the Omnissiah") ~= nil
		local lantern_reason = mod:localize("option_requires_lantern_of_the_omnissiah")
		local myfavorites_available = FavoriteIntegration and type(FavoriteIntegration.is_myfavorites_available) == "function" and FavoriteIntegration.is_myfavorites_available()
		local myfavorites_reason = mod:localize("option_requires_myfavorites")
		local quick_look_card_grid_enabled = grid_enabled and mod:get("enable_quick_look_card_grid_integration") ~= false
		local quick_look_card_grid_reason = grid_enabled and mod:localize("option_requires_quick_look_card_grid_integration") or native_reason
		local quick_look_card_single_column_enabled = single_column_enabled and mod:get("enable_quick_look_card_single_column_integration") ~= false
		local quick_look_card_single_column_reason = single_column_enabled and mod:localize("option_requires_quick_look_card_single_column_integration") or single_column_reason
		local weapon_modifier_lowest_color_enabled = quick_look_card_grid_enabled or quick_look_card_single_column_enabled
		local weapon_modifier_lowest_color_reason = grid_enabled and quick_look_card_grid_reason or quick_look_card_single_column_reason
		local quick_look_card_above_power = quick_look_card_grid_enabled and mod:get("quick_look_card_grid_stat_position") ~= "name_left" and mod:get("quick_look_card_grid_stat_position") ~= "name_right"
		local quick_look_card_bottom_padding_reason = quick_look_card_grid_enabled and mod:localize("option_requires_quick_look_card_above_power") or quick_look_card_grid_reason
		set_option_enabled(option_dependency_entries.expand_curio_inventory_window, window_expansion_enabled, expansion_reason)
		set_option_enabled(option_dependency_entries.weapon_extra_width_column_threshold, window_expansion_enabled, expansion_reason)
		set_option_enabled(option_dependency_entries.five_column_weapon_extra_width, weapon_extra_width_enabled, weapon_extra_width_reason)
		set_option_enabled(option_dependency_entries.curio_target_card_width, curio_expansion_enabled, curio_target_reason)
		set_option_enabled(option_dependency_entries.expand_armoury_requisition_window, armoury_grid_enabled, armoury_reason)
		set_option_enabled(option_dependency_entries.enable_armoury_requisition_sorting_panel, armoury_grid_enabled, armoury_reason)
		set_option_enabled(option_dependency_entries.brighten_armoury_item_levels, armoury_grid_enabled, armoury_reason)
		set_option_enabled(option_dependency_entries.three_column_weapon_name_font_size, armoury_grid_enabled, armoury_reason)
		set_option_enabled(option_dependency_entries.armoury_requisition_target_card_width, armoury_expansion_enabled, armoury_target_reason)
		set_option_enabled(option_dependency_entries.enable_melk_limited_grid, grid_enabled, native_reason)
		local global_store_integration_reason = grid_enabled and mod:localize("option_requires_global_store_integration") or native_reason
		local global_store_reason = global_store_integration_enabled and grid_enabled and mod:localize("option_requires_global_store_grid") or global_store_integration_reason
		set_option_enabled(option_dependency_entries.enable_global_store_integration, true)
		set_option_enabled(option_dependency_entries.enable_global_store_grid, global_store_integration_enabled and grid_enabled, global_store_integration_reason)
		set_option_enabled(option_dependency_entries.enable_melk_multi_operative_grid, global_store_integration_enabled and grid_enabled, global_store_integration_reason)
		set_option_enabled(option_dependency_entries.enable_global_store_sorting_panel, global_store_integration_enabled and global_store_grid_enabled, global_store_reason)
		local global_store_layout_enabled = global_store_integration_enabled and (global_store_grid_enabled or global_store_native_enabled)
		set_option_enabled(option_dependency_entries.global_store_character_photo_size_percent, global_store_layout_enabled, global_store_reason)
		set_option_enabled(option_dependency_entries.global_store_price_row_padding, global_store_layout_enabled, global_store_reason)
		set_option_enabled(option_dependency_entries.global_store_character_info_gap, global_store_layout_enabled, global_store_reason)
		set_option_enabled(option_dependency_entries.global_store_character_class_icon_size, global_store_layout_enabled, global_store_reason)
		set_option_enabled(option_dependency_entries.global_store_character_name_font_size, global_store_layout_enabled, global_store_reason)
		set_option_enabled(option_dependency_entries.global_store_compact_character_names, global_store_layout_enabled, global_store_reason)
		set_option_enabled(option_dependency_entries.global_store_single_column_modifier_horizontal_position, global_store_native_enabled, global_store_integration_reason)
		set_option_enabled(option_dependency_entries.global_store_single_column_modifier_vertical_position, global_store_native_enabled, global_store_integration_reason)
		local character_overview_curio_enabled = mod:get("enable_character_overview_curio_details") ~= false
		local character_overview_melee_enabled = mod:get("enable_character_overview_melee_mirror") ~= false
		local character_overview_ranged_enabled = mod:get("enable_character_overview_ranged_mirror") ~= false
		local character_overview_weapon_enabled = (character_overview_melee_enabled or character_overview_ranged_enabled) and mod:get("enable_quick_look_card_single_column_integration") ~= false
		local character_overview_dump_stat_enabled, character_overview_dump_stat_reason = character_overview_dump_stat_style_state()
		set_option_enabled(option_dependency_entries.character_overview_weapon_rarity_rating_mode, character_overview_melee_enabled or character_overview_ranged_enabled, mod:localize("option_requires_character_overview_weapon_mirror"))
		set_option_enabled(option_dependency_entries.character_overview_curio_rarity_rating_mode, character_overview_curio_enabled, mod:localize("option_requires_character_overview_curio_details"))
		set_option_enabled(option_dependency_entries.character_overview_show_melee_rarity_strip, character_overview_melee_enabled, mod:localize("option_requires_character_overview_melee_mirror"))
		set_option_enabled(option_dependency_entries.character_overview_show_ranged_rarity_strip, character_overview_ranged_enabled, mod:localize("option_requires_character_overview_ranged_mirror"))
		set_option_enabled(option_dependency_entries.character_overview_blessing_name_mode, character_overview_weapon_enabled and weapon_blessing_text_enabled, not character_overview_weapon_enabled and mod:localize("option_requires_character_overview_weapon_mirror") or mod:localize("option_requires_weapon_blessing_text"))
		set_option_enabled(option_dependency_entries.character_overview_show_only_dump_stat, character_overview_weapon_enabled, mod:localize("option_requires_character_overview_weapon_mirror"))
		set_option_enabled(option_dependency_entries.character_overview_dump_stat_horizontal_offset, character_overview_dump_stat_enabled, character_overview_dump_stat_reason)
		set_option_enabled(option_dependency_entries.character_overview_dump_stat_font_scale_percent, character_overview_dump_stat_enabled, character_overview_dump_stat_reason)
		set_option_enabled(option_dependency_entries.character_overview_dump_stat_color_preset, character_overview_dump_stat_enabled, character_overview_dump_stat_reason)
		set_option_enabled(option_dependency_entries.character_overview_dump_stat_color_r, character_overview_dump_stat_enabled, character_overview_dump_stat_reason)
		set_option_enabled(option_dependency_entries.character_overview_dump_stat_color_g, character_overview_dump_stat_enabled, character_overview_dump_stat_reason)
		set_option_enabled(option_dependency_entries.character_overview_dump_stat_color_b, character_overview_dump_stat_enabled, character_overview_dump_stat_reason)
		set_option_enabled(option_dependency_entries.character_overview_show_curio_rarity_strip, character_overview_curio_enabled, mod:localize("option_requires_character_overview_curio_details"))
		set_option_enabled(option_dependency_entries.character_overview_curio_name_mode, character_overview_curio_enabled, mod:localize("option_requires_character_overview_curio_details"))
		set_option_enabled(option_dependency_entries.character_overview_curio_font_size_percent, character_overview_curio_enabled, mod:localize("option_requires_character_overview_curio_details"))
		set_option_enabled(option_dependency_entries.character_overview_use_native_curio_overlay, character_overview_curio_enabled, mod:localize("option_requires_character_overview_curio_details"))
		set_option_enabled(option_dependency_entries.weapon_perk_compression, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
		set_option_enabled(option_dependency_entries.show_weapon_perk_rank_symbols, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
		set_option_enabled(option_dependency_entries.weapon_perk_rank_icon_size, weapon_rank_symbols_enabled, mod:localize("option_requires_rank_symbols"))
		set_option_enabled(option_dependency_entries.remove_weapon_perk_plus_signs, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
		set_option_enabled(option_dependency_entries.weapon_perk_text_color_preset, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
		set_option_enabled(option_dependency_entries.weapon_perk_text_color_r, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
		set_option_enabled(option_dependency_entries.weapon_perk_text_color_g, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
		set_option_enabled(option_dependency_entries.weapon_perk_text_color_b, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
		set_option_enabled(option_dependency_entries.weapon_perk_text_opacity, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
		set_option_enabled(option_dependency_entries.weapon_perk_vertical_spacing, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
		refresh_highlight_option_dependencies(option_dependency_entries)
		set_option_enabled(option_dependency_entries.blessing_text_item_level_separation, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
		set_option_enabled(option_dependency_entries.auto_fit_long_blessing_names, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
		set_option_enabled(option_dependency_entries.truncate_long_blessing_names, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
		set_option_enabled(option_dependency_entries.weapon_blessing_text_color_preset, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
		set_option_enabled(option_dependency_entries.weapon_blessing_text_color_r, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
		set_option_enabled(option_dependency_entries.weapon_blessing_text_color_g, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
		set_option_enabled(option_dependency_entries.weapon_blessing_text_color_b, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
		set_option_enabled(option_dependency_entries.weapon_blessing_text_opacity, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
		set_option_enabled(option_dependency_entries.weapon_blessing_text_vertical_spacing, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
		set_option_enabled(option_dependency_entries.weapon_blessing_text_bottom_padding, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
		set_option_enabled(option_dependency_entries.blessing_icon_size, blessing_icon_controls_enabled, blessing_icon_controls_reason)
		set_option_enabled(option_dependency_entries.blessing_icon_spacing, blessing_icon_controls_enabled, blessing_icon_controls_reason)
		set_option_enabled(option_dependency_entries.weapon_perk_blessing_spacing, weapon_perk_blessing_sections_enabled, mod:localize("option_requires_perk_and_blessing_sections"))
		set_option_enabled(option_dependency_entries.curio_secondary_stat_font_size, detailed_curio_profile, mod:localize("option_requires_detailed_curio_profile"))
		set_option_enabled(option_dependency_entries.curio_primary_secondary_spacing, detailed_curio_profile, mod:localize("option_requires_detailed_curio_profile"))
		set_option_enabled(option_dependency_entries.weapon_rarity_rating_use_card_background_color, weapon_rarity_rating_enabled, mod:localize("option_requires_weapon_rarity_rating"))
		set_option_enabled(option_dependency_entries.weapon_rarity_rating_opacity, weapon_rarity_rating_enabled, mod:localize("option_requires_weapon_rarity_rating"))
		set_option_enabled(option_dependency_entries.curio_rarity_rating_use_card_background_color, curio_rarity_rating_enabled, mod:localize("option_requires_curio_rarity_rating"))
		set_option_enabled(option_dependency_entries.curio_rarity_rating_opacity, curio_rarity_rating_enabled, mod:localize("option_requires_curio_rarity_rating"))
		set_option_enabled(option_dependency_entries.weapon_kill_counter_show_zero_kills_in_stores, wkc_zero_kills_enabled, mod:localize("option_requires_weapon_kill_counter_zero_kills"))
		set_option_enabled(option_dependency_entries.single_column_layout_group, single_column_enabled, single_column_reason)
		set_option_enabled(option_dependency_entries.single_column_weapon_name_font_size, single_column_enabled, single_column_reason)
		set_option_enabled(option_dependency_entries.single_column_blessing_icons_on_right, single_column_enabled and weapon_blessing_text_enabled, not single_column_enabled and single_column_reason or mod:localize("option_requires_weapon_blessing_text"))
		set_option_enabled(option_dependency_entries.quick_look_card_single_column_font_size, quick_look_card_single_column_enabled, quick_look_card_single_column_reason)
		set_option_enabled(option_dependency_entries.quick_look_card_single_column_label_value_gap, quick_look_card_single_column_enabled, quick_look_card_single_column_reason)
		set_option_enabled(option_dependency_entries.quick_look_card_single_column_horizontal_position, quick_look_card_single_column_enabled, quick_look_card_single_column_reason)
		set_option_enabled(option_dependency_entries.quick_look_card_single_column_vertical_position, quick_look_card_single_column_enabled, quick_look_card_single_column_reason)
		set_option_enabled(option_dependency_entries.quick_look_card_grid_stat_position, quick_look_card_grid_enabled, quick_look_card_grid_reason)
		set_option_enabled(option_dependency_entries.quick_look_card_grid_font_size, quick_look_card_grid_enabled, quick_look_card_grid_reason)
		set_option_enabled(option_dependency_entries.quick_look_card_grid_bottom_padding, quick_look_card_above_power, quick_look_card_bottom_padding_reason)
		set_option_enabled(option_dependency_entries.weapon_modifier_lowest_color_preset, weapon_modifier_lowest_color_enabled, weapon_modifier_lowest_color_reason)
		set_option_enabled(option_dependency_entries.weapon_modifier_lowest_color_r, weapon_modifier_lowest_color_enabled, weapon_modifier_lowest_color_reason)
		set_option_enabled(option_dependency_entries.weapon_modifier_lowest_color_g, weapon_modifier_lowest_color_enabled, weapon_modifier_lowest_color_reason)
		set_option_enabled(option_dependency_entries.weapon_modifier_lowest_color_b, weapon_modifier_lowest_color_enabled, weapon_modifier_lowest_color_reason)
		set_option_enabled(option_dependency_entries.weapon_modifier_lowest_color_opacity, weapon_modifier_lowest_color_enabled, weapon_modifier_lowest_color_reason)
		set_option_enabled(option_dependency_entries.name_it_force_curio_name_in_detailed_mode, detailed_curio_profile, mod:localize("option_requires_detailed_curio_profile"))
		set_option_enabled(option_dependency_entries.curio_content_name_it_curio_name, detailed_curio_profile, mod:localize("option_requires_detailed_curio_profile"))
		local custom_item_colors_enabled = mod:get("enable_custom_item_name_and_colors") ~= false
		local custom_item_colors_reason = mod:localize("option_requires_custom_item_name_and_colors")

		set_option_enabled(option_dependency_entries.enable_custom_item_name_and_colors, true)
		set_option_enabled(option_dependency_entries.custom_item_name_keybind, custom_item_colors_enabled, custom_item_colors_reason)
		set_option_enabled(option_dependency_entries.custom_item_name_color_keybind, custom_item_colors_enabled, custom_item_colors_reason)
		set_option_enabled(option_dependency_entries.custom_item_background_color_keybind, custom_item_colors_enabled, custom_item_colors_reason)
		set_option_enabled(option_dependency_entries.custom_item_skip_confirmation_prompts, custom_item_colors_enabled, custom_item_colors_reason)
		set_option_enabled(option_dependency_entries.custom_item_preserve_card_shading, custom_item_colors_enabled, custom_item_colors_reason)
		set_option_enabled(option_dependency_entries.custom_item_override_weapon_information_color, custom_item_colors_enabled, custom_item_colors_reason)
		set_option_enabled(option_dependency_entries.custom_item_override_weapon_rarity_keyword_color, custom_item_colors_enabled, custom_item_colors_reason)
		set_option_enabled(option_dependency_entries.custom_item_override_weapon_information_name_color, custom_item_colors_enabled, custom_item_colors_reason)

		local auto_crafter_mastery_enabled = mod:get("auto_crafter_level_mastery_20") ~= false
		local auto_crafter_perks_enabled = auto_crafter_mastery_enabled and mod:get("auto_crafter_change_perks") ~= false
		local auto_crafter_allocate_enabled = auto_crafter_mastery_enabled and mod:get("auto_crafter_allocate_mastery_points") ~= false
		local auto_crafter_blessings_enabled = auto_crafter_allocate_enabled and mod:get("auto_crafter_change_blessings") ~= false
		local mastery_reason = mod:localize("option_requires_auto_crafter_mastery_20")

		set_option_enabled(option_dependency_entries.auto_crafter_defer_bad_weapon_processing, auto_crafter_mastery_enabled, mastery_reason)
		local reuse_inventory_base = mod:get("auto_crafter_reuse_inventory_base") ~= false
		set_option_enabled(option_dependency_entries.auto_crafter_include_favorite_inventory_bases, reuse_inventory_base, mod:localize("option_requires_auto_crafter_inventory_reuse"))
		set_option_enabled(option_dependency_entries.auto_crafter_allocate_mastery_points, auto_crafter_mastery_enabled, mastery_reason)
		set_option_enabled(option_dependency_entries.auto_crafter_change_perks, auto_crafter_mastery_enabled, mastery_reason)
		set_option_enabled(option_dependency_entries.auto_crafter_change_blessings, auto_crafter_mastery_enabled, mastery_reason)
		set_option_enabled(option_dependency_entries.auto_crafter_perk_1_target, auto_crafter_perks_enabled, auto_crafter_mastery_enabled and mod:localize("option_requires_auto_crafter_change_perks") or mastery_reason)
		set_option_enabled(option_dependency_entries.auto_crafter_perk_2_target, auto_crafter_perks_enabled, auto_crafter_mastery_enabled and mod:localize("option_requires_auto_crafter_change_perks") or mastery_reason)
		set_option_enabled(option_dependency_entries.auto_crafter_show_perk_grid, auto_crafter_perks_enabled, auto_crafter_mastery_enabled and mod:localize("option_requires_auto_crafter_change_perks") or mastery_reason)
		set_option_enabled(option_dependency_entries.auto_crafter_blessing_1_target, auto_crafter_blessings_enabled, auto_crafter_mastery_enabled and mod:localize("option_requires_auto_crafter_blessing_workflow") or mastery_reason)
		set_option_enabled(option_dependency_entries.auto_crafter_blessing_2_target, auto_crafter_blessings_enabled, auto_crafter_mastery_enabled and mod:localize("option_requires_auto_crafter_blessing_workflow") or mastery_reason)
		set_option_enabled(option_dependency_entries.auto_crafter_show_blessing_grid, auto_crafter_blessings_enabled, auto_crafter_mastery_enabled and mod:localize("option_requires_auto_crafter_blessing_workflow") or mastery_reason)
		set_option_enabled(option_dependency_entries.auto_crafter_myfavorites_color, myfavorites_available and mod:get("auto_crafter_favorite_result") ~= false, myfavorites_available and mod:localize("option_requires_auto_crafter_myfavorites_color") or myfavorites_reason)

		for _, setting_id in ipairs({
			"inventory_options_controller_focus_keybind",
			"curio_information_width_percent",
			"curio_preview_height_percent",
			"inventory_options_panel_width",
			"inventory_options_panel_max_height",
			"inventory_options_panel_row_spacing",
			"inventory_options_panel_padding_top",
			"inventory_options_panel_padding_bottom",
			"inventory_options_panel_padding_left",
			"inventory_options_panel_padding_right",
		}) do
			set_option_enabled(option_dependency_entries[setting_id], true)
		end

		set_option_enabled(option_dependency_entries.enable_lantern_inventory_section, lantern_installed, lantern_reason)
		set_option_enabled(option_dependency_entries.keep_lantern_curio_panel_separate, lantern_installed and mod:get("enable_lantern_inventory_section") ~= false, lantern_reason)

		for _, setting_id in ipairs({
			"quick_discard_mode",
			"quick_discard_rarity",
			"quick_discard_max_item_level",
			"quick_discard_protect_above_equipped_level",
			"quick_discard_include_melee",
			"quick_discard_include_ranged",
			"quick_discard_include_curios",
			"quick_discard_protect_perfect_weapons",
			"quick_discard_protect_health_roll_curios",
			"quick_discard_protect_toughness_roll_curios",
			"quick_discard_protect_high_level_curios",
			"quick_discard_keep_health_curios",
			"quick_discard_keep_toughness_curios",
			"quick_discard_keep_wound_curios",
			"quick_discard_keep_stamina_curios",
			"quick_discard_show_type_breakdown",
			"quick_discard_show_summary_notification",
		}) do
			set_option_enabled(option_dependency_entries[setting_id], quick_discard_enabled, quick_discard_reason)
		end

		local automatic_discard_enabled = quick_discard_enabled and mod:get("quick_discard_mode") == "automatic"
		local automatic_discard_reason = quick_discard_enabled and mod:localize("option_requires_automatic_discard_mode") or quick_discard_reason

		set_option_enabled(option_dependency_entries.quick_discard_skip_automatic_confirmation, automatic_discard_enabled, automatic_discard_reason)
		set_option_enabled(option_dependency_entries.quick_discard_disable_no_eligible_notification, automatic_discard_enabled, automatic_discard_reason)

		local curio_protection_enabled = quick_discard_enabled and mod:get("quick_discard_protect_high_level_curios") ~= false
		local health_roll_protection_enabled = quick_discard_enabled and mod:get("quick_discard_protect_health_roll_curios") == true
		local toughness_roll_protection_enabled = quick_discard_enabled and mod:get("quick_discard_protect_toughness_roll_curios") == true

		set_option_enabled(option_dependency_entries.quick_discard_curio_protection_level, curio_protection_enabled, quick_discard_enabled and mod:localize("option_requires_curio_discard_protection") or quick_discard_reason)
		set_option_enabled(option_dependency_entries.quick_discard_curio_health_roll, health_roll_protection_enabled, quick_discard_enabled and mod:localize("option_requires_curio_health_roll_protection") or quick_discard_reason)
		set_option_enabled(option_dependency_entries.quick_discard_curio_toughness_roll, toughness_roll_protection_enabled, quick_discard_enabled and mod:localize("option_requires_curio_toughness_roll_protection") or quick_discard_reason)

		for _, setting_id in ipairs(AUTOMATIC_CURIO_SETTING_IDS) do
			set_option_enabled(option_dependency_entries[setting_id], automatic_curio_enabled, automatic_curio_reason)
		end

		set_option_enabled(option_dependency_entries.automatic_curio_classes_group, automatic_curio_classes_enabled, automatic_curio_classes_reason)
		set_option_enabled(option_dependency_entries.automatic_curio_characters_group, automatic_curio_characters_enabled, automatic_curio_characters_reason)

		for _, setting_id in ipairs({
			"automatic_curio_class_veteran",
			"automatic_curio_class_zealot",
			"automatic_curio_class_psyker",
			"automatic_curio_class_ogryn",
			"automatic_curio_class_adamant",
			"automatic_curio_class_broker",
			"automatic_curio_class_cryptic",
		}) do
			set_option_enabled(option_dependency_entries[setting_id], automatic_curio_classes_enabled, automatic_curio_classes_reason)
		end

		for _, entry in ipairs(option_dependency_entries.automatic_curio_character_entries or {}) do
			local slot_available = entry._better_inventory_curio_character_available == true
			local slot_reason = slot_available and automatic_curio_characters_reason or mod:localize("automatic_curio_character_slot_empty_reason")

			set_option_enabled(entry, automatic_curio_characters_enabled and slot_available, slot_reason)
		end

		local automatic_health_enabled = automatic_curio_enabled and mod:get("automatic_curio_buy_health") ~= false
		local automatic_toughness_enabled = automatic_curio_enabled and mod:get("automatic_curio_buy_toughness") ~= false
		local automatic_stamina_enabled = automatic_curio_enabled and mod:get("automatic_curio_buy_stamina") == true

		set_option_enabled(option_dependency_entries.automatic_curio_min_health, automatic_health_enabled, automatic_curio_enabled and mod:localize("option_requires_automatic_curio_health") or automatic_curio_reason)
		set_option_enabled(option_dependency_entries.automatic_curio_min_toughness, automatic_toughness_enabled, automatic_curio_enabled and mod:localize("option_requires_automatic_curio_toughness") or automatic_curio_reason)
		set_option_enabled(option_dependency_entries.automatic_curio_min_stamina, automatic_stamina_enabled, automatic_curio_enabled and mod:localize("option_requires_automatic_curio_stamina") or automatic_curio_reason)
	end

	local function bind_option_dependencies(options_templates)
		local settings = options_templates and options_templates.settings

		if type(settings) ~= "table" then
			return
		end

		local category_name = mod:get_readable_name()

		-- Presentation only; never run duplicate-ID validation here.

		local setting_by_title = {}
		local tracked_setting_ids = {}
		local curio_buyer_subsection_titles = {
			[mod:localize("automatic_curio_types_group")] = true,
			[mod:localize("automatic_curio_classes_group")] = true,
			[mod:localize("automatic_curio_characters_group")] = true,
		}
		local class_group_title = mod:localize("automatic_curio_classes_group")
		local character_group_title = mod:localize("automatic_curio_characters_group")
		local class_group_entry
		local character_group_entry

		local tracked_ids = {
			"melee_columns",
			"ranged_columns",
			"curio_columns",
			"three_column_weapon_name_font_size",
			"expand_inventory_window",
			"weapon_extra_width_column_threshold",
			"five_column_weapon_extra_width",
			"grid_spacing",
			"automatic_card_height",
			"card_height",
			"weapon_rarity_rating_mode",
			"curio_rarity_rating_mode",
			"weapon_rarity_rating_use_card_background_color",
			"weapon_rarity_rating_opacity",
			"curio_rarity_rating_use_card_background_color",
			"curio_rarity_rating_opacity",
			"weapon_kill_counter_show_zero_kills_in_stores",
			"expand_curio_inventory_window",
			"curio_target_card_width",
			"enable_hadron_entreat_grid",
			"enable_hadron_single_column_mirror",
			"enable_armoury_requisition_grid",
			"enable_melk_limited_grid",
			"enable_melk_multi_operative_grid",
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
			"character_overview_blessing_name_mode",
			"character_overview_weapon_rarity_rating_mode",
			"character_overview_curio_rarity_rating_mode",
			"character_overview_show_only_dump_stat",
			"character_overview_dump_stat_horizontal_offset",
			"character_overview_dump_stat_font_scale_percent",
			"character_overview_dump_stat_color_preset",
			"character_overview_dump_stat_color_r",
			"character_overview_dump_stat_color_g",
			"character_overview_dump_stat_color_b",
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
			"highlight_equipped_items",
			"equipped_highlight_color_preset",
			"equipped_highlight_color_r",
			"equipped_highlight_color_g",
			"equipped_highlight_color_b",
			"equipped_highlight_glow_intensity",
			"equipped_highlight_animated_border_width",
			"equipped_highlight_solid_border_width",
			"new_item_highlight_mode",
			"new_item_highlight_color_preset",
			"new_item_highlight_color_r",
			"new_item_highlight_color_g",
			"new_item_highlight_color_b",
			"new_item_highlight_glow_intensity",
			"new_item_highlight_animated_border_width",
			"new_item_highlight_solid_border_width",
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
			"custom_item_name_keybind",
			"custom_item_name_color_keybind",
			"custom_item_background_color_keybind",
			"custom_item_skip_confirmation_prompts",
			"custom_item_preserve_card_shading",
			"custom_item_override_weapon_information_color",
			"custom_item_override_weapon_rarity_keyword_color",
			"custom_item_override_weapon_information_name_color",
			"inventory_options_controller_focus_keybind",
			"curio_information_width_percent",
			"curio_preview_height_percent",
			"enable_lantern_inventory_section",
			"keep_lantern_curio_panel_separate",
			"inventory_options_panel_width",
			"inventory_options_panel_max_height",
			"inventory_options_panel_row_spacing",
			"inventory_options_panel_padding_top",
			"inventory_options_panel_padding_bottom",
			"inventory_options_panel_padding_left",
			"inventory_options_panel_padding_right",
			"quick_discard_mode",
			"quick_discard_skip_automatic_confirmation",
			"quick_discard_rarity",
			"quick_discard_max_item_level",
			"quick_discard_protect_above_equipped_level",
			"quick_discard_include_melee",
			"quick_discard_include_ranged",
			"quick_discard_include_curios",
			"quick_discard_protect_perfect_weapons",
			"quick_discard_protect_health_roll_curios",
			"quick_discard_curio_health_roll",
			"quick_discard_protect_toughness_roll_curios",
			"quick_discard_curio_toughness_roll",
			"quick_discard_protect_high_level_curios",
			"quick_discard_curio_protection_level",
			"quick_discard_keep_health_curios",
			"quick_discard_keep_toughness_curios",
			"quick_discard_keep_wound_curios",
			"quick_discard_keep_stamina_curios",
			"quick_discard_show_type_breakdown",
			"quick_discard_show_summary_notification",
			"quick_discard_disable_no_eligible_notification",
			"automatic_curio_class_veteran",
			"automatic_curio_class_zealot",
			"automatic_curio_class_psyker",
			"automatic_curio_class_ogryn",
			"automatic_curio_class_adamant",
			"automatic_curio_class_broker",
			"automatic_curio_class_cryptic",
			"auto_crafter_myfavorites_color",
		}

		for _, setting_id in ipairs(AUTOMATIC_CURIO_SETTING_IDS) do
			tracked_ids[#tracked_ids + 1] = setting_id
		end

		for _, setting_id in ipairs(tracked_ids) do
			tracked_setting_ids[setting_id] = true
			local title = mod:localize(setting_id)
			local existing = setting_by_title[title]

			if existing == nil then
				setting_by_title[title] = setting_id
			elseif type(existing) == "table" then
				existing[#existing + 1] = setting_id
			else
				setting_by_title[title] = {
					existing,
					setting_id,
				}
			end
		end

		option_dependency_entries = {
			automatic_curio_character_entries = {},
		}

		for i = 1, #settings do
			local entry = settings[i]

			if type(entry) == "table" and entry.category == category_name and entry.widget_type == "group_header" and curio_buyer_subsection_titles[entry.display_name] then
				entry.indentation_level = 2

				if entry.display_name == class_group_title then
					class_group_entry = entry
				elseif entry.display_name == character_group_title then
					character_group_entry = entry
				end
			end

			local setting_id

			if type(entry) == "table" and entry.category == category_name then
				setting_id = tracked_setting_ids[entry.setting_id] and entry.setting_id or setting_by_title[entry.display_name]
			end

			if type(setting_id) == "table" then
				-- Bind duplicate localized labels in schema order.
				setting_id = table.remove(setting_id, 1)
			end

			if setting_id then
				option_dependency_entries[setting_id] = entry
				bind_live_option_dependency(setting_id, entry)
				bind_highlight_mode_dependency_refresh(setting_id, entry, option_dependency_entries)
			elseif type(entry) == "table" and entry._better_inventory_curio_character_slot_index then
				option_dependency_entries.automatic_curio_character_entries[#option_dependency_entries.automatic_curio_character_entries + 1] = entry
			end
		end

		option_dependency_entries.automatic_curio_classes_group = class_group_entry
		option_dependency_entries.automatic_curio_characters_group = character_group_entry

		local myfavorites_color_entry = option_dependency_entries.auto_crafter_myfavorites_color

		if type(myfavorites_color_entry) == "table" and type(myfavorites_color_entry.options) == "table" and FavoriteIntegration and type(FavoriteIntegration.color_preview) == "function" then
			for index, option in ipairs(myfavorites_color_entry.options) do
				if type(option) == "table" then
					option.display_name = FavoriteIntegration.color_preview(mod, tonumber(option.value) or index)
				end
			end
		end

		refresh_option_dependencies()
	end

	return {
		COLOR_TARGETS = COLOR_TARGETS,
		color_target_by_setting_id = color_target_by_setting_id,
		equipped_highlight_color_target = equipped_highlight_color_target,
		new_item_highlight_color_target = new_item_highlight_color_target,
		apply_color_preset = apply_color_preset,
		refresh_option_dependencies = refresh_option_dependencies,
		bind_option_dependencies = bind_option_dependencies,
	}
end

return OptionDependencies
