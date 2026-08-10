local Runtime = {}

local mod
local Layout
local Features
local CurioAcquisition
local ItemCustomization
local EquipmentPersistence
local SettingsRegistry
local Diagnostics
local AutoCrafter
local Capabilities
local CharacterOverviewUI
local CraftingMechanicusModifyView
local CreditsVendorView
local MainMenuView
local InventoryBackgroundView
local ItemGridViewBase
local ItemGridViewBaseDefinitions
local InventoryWeaponsView
local ViewElementGrid
local CreditsGoodsVendorView = require("scripts/ui/views/credits_goods_vendor_view/credits_goods_vendor_view")

local function configure_dependencies(dependencies)
	mod = dependencies.mod
	Layout = dependencies.Layout
	Features = dependencies.Features
	CurioAcquisition = dependencies.CurioAcquisition
	ItemCustomization = dependencies.ItemCustomization
	EquipmentPersistence = dependencies.EquipmentPersistence
	SettingsRegistry = dependencies.SettingsRegistry
	Diagnostics = dependencies.Diagnostics
	AutoCrafter = dependencies.AutoCrafter
	Capabilities = dependencies.Capabilities
	CharacterOverviewUI = dependencies.CharacterOverviewUI
	CraftingMechanicusModifyView = dependencies.CraftingMechanicusModifyView
	CreditsVendorView = dependencies.CreditsVendorView
	MainMenuView = dependencies.MainMenuView
	InventoryBackgroundView = dependencies.InventoryBackgroundView
	ItemGridViewBase = dependencies.ItemGridViewBase
	ItemGridViewBaseDefinitions = dependencies.ItemGridViewBaseDefinitions
	InventoryWeaponsView = dependencies.InventoryWeaponsView
	ViewElementGrid = dependencies.ViewElementGrid
end

Runtime.configure = configure_dependencies

function Runtime.install()
	local unpack_values = table.unpack or unpack
	local INVENTORY_GRID_CONFIGURATION = {
		blueprint_key = "item",
	}
	local HADRON_GRID_CONFIGURATION = {
		blueprint_key = "item",
		maximum_columns = 3,
	}
	local ARMOURY_GRID_CONFIGURATION = {
		blueprint_key = "store_item",
		maximum_columns = 3,
		store_item = true,
	}
	local GLOBAL_STORE_SERVICE = "get_all_characters_store_custom"
	local GLOBAL_STORE_GRID_CONFIGURATION = {
		blueprint_key = "store_item",
		global_store = true,
		maximum_columns = 3,
		store_item = true,
	}
	local GLOBAL_STORE_NATIVE_CONFIGURATION = {
		blueprint_key = "store_item",
		global_store = true,
		native_single_column = true,
		store_item = true,
	}

	local pack_values = CharacterOverviewUI.pack_values
	local shallow_copy = CharacterOverviewUI.shallow_copy
	local is_armoury_requisition_view = CharacterOverviewUI.is_armoury_requisition_view
	local is_global_store_view = CharacterOverviewUI.is_global_store_view
	local is_hadron_view = CharacterOverviewUI.is_hadron_view
	local attach_runtime_marker_styles = CharacterOverviewUI.attach_runtime_marker_styles
	local invalidate_myfavorites_grid = CharacterOverviewUI.invalidate_myfavorites_grid

local function is_armoury_sort_view(view)
	return is_armoury_requisition_view(view) or is_global_store_view(view)
end

local function align_quick_level_mastery_buttons(view)
	if type(Diagnostics.count) == "function" then
		Diagnostics.count("alignment_queries")
	end
	-- Quick Level Mastery adds Sacrifice as an offset child of Darktide's shared
	-- purchase_button node. Center the complete action group on the actual weapon
	-- information panel instead of deriving its position from the store grid:
	-- the grid can have a different width, and another hook can independently
	-- restore the purchase node to its native position.
	local widgets_by_name = view and view._widgets_by_name
	local ui_scenegraph = view and view._ui_scenegraph
	local purchase_button = ui_scenegraph and ui_scenegraph.purchase_button
	local sacrifice_button = widgets_by_name and widgets_by_name.quick_sacrifice_button
	local weapon_stats = view and view._weapon_stats

	if not sacrifice_button or not purchase_button or not purchase_button.position or not purchase_button.size or not weapon_stats or type(weapon_stats.scenegraph_world_position) ~= "function" or type(weapon_stats._scenegraph_size) ~= "function" or type(view._scenegraph_world_position) ~= "function" or type(view._set_scenegraph_position) ~= "function" then
		return
	end

	if type(weapon_stats._force_update_scenegraph) == "function" then
		pcall(weapon_stats._force_update_scenegraph, weapon_stats)
	end

	local position = purchase_button.position
	local purchase_width = tonumber(purchase_button.size[1])
	local purchase_widget = widgets_by_name.purchase_button
	local purchase_offset = purchase_widget and purchase_widget.offset and tonumber(purchase_widget.offset[1]) or 0
	local sacrifice_offset = sacrifice_button.offset and tonumber(sacrifice_button.offset[1])
	local purchase_world_position = view:_scenegraph_world_position("purchase_button")
	local weapon_stats_world_position = weapon_stats:scenegraph_world_position("grid_background")
	local weapon_stats_width = weapon_stats:_scenegraph_size("grid_background")
	local purchase_world_x = purchase_world_position and tonumber(purchase_world_position[1])
	local weapon_stats_world_x = weapon_stats_world_position and tonumber(weapon_stats_world_position[1])

	if type(position[1]) ~= "number" or not purchase_width or not purchase_world_x or not weapon_stats_world_x or type(weapon_stats_width) ~= "number" then
		return
	end

	sacrifice_offset = sacrifice_offset or purchase_offset + purchase_width

	local action_left = math.min(purchase_offset, sacrifice_offset)
	local action_right = math.max(purchase_offset + purchase_width, sacrifice_offset + purchase_width)
	local action_center = purchase_world_x + (action_left + action_right) * 0.5
	local weapon_stats_center = weapon_stats_world_x + weapon_stats_width * 0.5
	local delta = weapon_stats_center - action_center

	if math.abs(delta) < 0.01 then
		return
	end

	if type(Diagnostics.count) == "function" then
		Diagnostics.count("alignment_writes")
	end
	view:_set_scenegraph_position("purchase_button", position[1] + delta, position[2], position[3])
end

-- Darktide class tables can contain the exact same inherited function object.
-- Give each target class its own forwarder before DMF hooks it, preventing
-- duplicate-hook detection and keeping every view in the normal hook chain.
local function ensure_class_method(class, method)
	if type(class) ~= "table" then
		return false
	end

	local super = rawget(class, "super") or class.super
	local inherited_method = super and super[method]
	local own_method = rawget(class, method)

	if type(own_method) == "function" and own_method ~= inherited_method then
		return true
	end

	if type(inherited_method) ~= "function" then
		return false
	end

	local owner = class
	local fallback = inherited_method

	rawset(owner, method, function(self, ...)
		local parent = rawget(owner, "super") or owner.super
		local parent_method = parent and parent[method] or fallback

		return parent_method(self, ...)
	end)

	return true
end

local COLOR_PRESETS = {
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
	neutral = {
		220,
		230,
		210,
	},
}
local COLOR_TARGETS = {
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
	{
		prefix = "curio_secondary_text_color",
		default_preset = "neutral",
	},
	{
		prefix = "curio_health_color",
		default_preset = "red",
	},
	{
		prefix = "curio_toughness_color",
		default_preset = "light_blue",
	},
	{
		prefix = "curio_wound_color",
		default_preset = "purple",
	},
	{
		prefix = "curio_stamina_color",
		default_preset = "yellow",
	},
}
local color_target_by_setting_id = {}
local option_dependency_entries = {}
local CHARACTER_OVERVIEW_DUMP_STAT_STYLE_SETTING_IDS = {
	character_overview_dump_stat_horizontal_offset = true,
	character_overview_dump_stat_font_scale_percent = true,
	character_overview_dump_stat_color_preset = true,
	character_overview_dump_stat_color_r = true,
	character_overview_dump_stat_color_g = true,
	character_overview_dump_stat_color_b = true,
}

for i = 1, #COLOR_TARGETS do
	local target = COLOR_TARGETS[i]

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
	local color = COLOR_PRESETS[preset_id]

	if not color then
		return
	end

	for channel = 1, 3 do
		mod:set(target.channel_ids[channel], color[channel], false)
	end
end

local function apply_option_enabled(entry, enabled, reason)
	if not entry then
		return
	end

	entry.disabled = not enabled
	entry.disabled_by = enabled and nil or {
		reason,
	}
end

local function set_option_enabled(entry, enabled, reason)
	apply_option_enabled(entry, enabled, reason)
end

local function character_overview_dump_stat_style_state()
	local weapon_enabled = (mod:get("enable_character_overview_melee_mirror") ~= false or mod:get("enable_character_overview_ranged_mirror") ~= false)
		and mod:get("enable_quick_look_card_single_column_integration") ~= false
	local enabled = weapon_enabled and mod:get("character_overview_show_only_dump_stat") == true
	local reason = weapon_enabled and mod:localize("option_requires_character_overview_dump_stat_only") or mod:localize("option_requires_character_overview_weapon_mirror")

	return enabled, reason
end

local function bind_live_option_dependency(setting_id, entry)
	if not CHARACTER_OVERVIEW_DUMP_STAT_STYLE_SETTING_IDS[setting_id] or entry._better_inventory_live_dependency_getter then
		return
	end

	local original_get_function = entry.get_function

	if type(original_get_function) ~= "function" then
		return
	end

	entry._better_inventory_live_dependency_getter = true
	entry.get_function = function(...)
		local enabled, reason = character_overview_dump_stat_style_state()

		apply_option_enabled(entry, enabled, reason)

		return original_get_function(...)
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
		"enable_global_store_grid",
	}) do
		set_option_enabled(option_dependency_entries[setting_id], grid_enabled, native_reason)
	end

	-- These view-specific switches are the single-column counterparts to the
	-- grid integrations above. They remain available only when the global grid
	-- layout is disabled, so each vendor can mirror the detailed inventory card
	-- independently without changing the grid-mode controls.
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
	local weapon_perks_enabled = mod:get("show_weapon_perks") == true
	local weapon_perk_ranks_enabled = weapon_perks_enabled and mod:get("show_weapon_perk_rank_symbols") == true
	local weapon_blessing_mode = mod:get("weapon_blessing_display_mode")
	local weapon_blessing_icons_enabled = weapon_blessing_mode == "icons"
	local weapon_blessing_ranked_text_enabled = weapon_blessing_mode == "ranked_text"
	local weapon_blessing_text_enabled = weapon_blessing_mode == "text" or weapon_blessing_ranked_text_enabled
	local weapon_blessings_enabled = weapon_blessing_mode ~= "off"
	local single_column_blessing_icons_enabled = single_column_enabled and weapon_blessing_text_enabled and mod:get("single_column_blessing_icons_on_right") ~= false
	local blessing_icon_controls_enabled = weapon_blessing_icons_enabled or single_column_blessing_icons_enabled
	local blessing_icon_controls_reason = single_column_enabled and weapon_blessing_text_enabled and mod:localize("option_requires_single_column_blessing_icons") or mod:localize("option_requires_weapon_blessings")
	local weapon_rank_symbols_enabled = weapon_perk_ranks_enabled or weapon_blessing_ranked_text_enabled
	local weapon_perk_blessing_sections_enabled = weapon_perks_enabled and weapon_blessings_enabled
	local detailed_curio_profile = mod:get("curio_display_profile") == "detailed"
	local quick_discard_enabled = mod:get("enable_experimental_quick_discard") == true
	local quick_discard_reason = mod:localize("option_requires_experimental_quick_discard")
	local automatic_curio_enabled = mod:get("enable_automatic_curio_acquisition") == true
	local automatic_curio_reason = mod:localize("option_requires_automatic_curio_acquisition")
	local automatic_curio_character_mode = mod:get("automatic_curio_target_mode") == "characters"
	local automatic_curio_classes_enabled = automatic_curio_enabled and not automatic_curio_character_mode
	local automatic_curio_characters_enabled = automatic_curio_enabled and automatic_curio_character_mode
	local automatic_curio_classes_reason = automatic_curio_enabled and mod:localize("option_requires_automatic_curio_classes_mode") or automatic_curio_reason
	local automatic_curio_characters_reason = automatic_curio_enabled and mod:localize("option_requires_automatic_curio_characters_mode") or automatic_curio_reason
	local inventory_options_panel_enabled = mod:get("enable_inventory_options_panel_prototype") == true
	local inventory_options_panel_reason = mod:localize("option_requires_inventory_options_panel_prototype")
	local lantern_installed = get_mod("Lantern of the Omnissiah") ~= nil
	local lantern_reason = lantern_installed and inventory_options_panel_reason or mod:localize("option_requires_lantern_of_the_omnissiah")
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
	local global_store_integration_reason = grid_enabled and mod:localize("option_requires_global_store_integration") or native_reason
	local global_store_reason = global_store_integration_enabled and grid_enabled and mod:localize("option_requires_global_store_grid") or global_store_integration_reason
	set_option_enabled(option_dependency_entries.enable_global_store_integration, true)
	set_option_enabled(option_dependency_entries.enable_global_store_grid, global_store_integration_enabled and grid_enabled, global_store_integration_reason)
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
	set_option_enabled(option_dependency_entries.character_overview_show_melee_rarity_strip, character_overview_melee_enabled, mod:localize("option_requires_character_overview_melee_mirror"))
	set_option_enabled(option_dependency_entries.character_overview_show_ranged_rarity_strip, character_overview_ranged_enabled, mod:localize("option_requires_character_overview_ranged_mirror"))
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

	local auto_crafter_mastery_enabled = mod:get("auto_crafter_level_mastery_20") == true
	local auto_crafter_perks_enabled = auto_crafter_mastery_enabled and mod:get("auto_crafter_change_perks") == true
	local auto_crafter_allocate_enabled = auto_crafter_mastery_enabled and mod:get("auto_crafter_allocate_mastery_points") == true
	local auto_crafter_blessings_enabled = auto_crafter_allocate_enabled and mod:get("auto_crafter_change_blessings") == true
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
		set_option_enabled(option_dependency_entries[setting_id], inventory_options_panel_enabled, inventory_options_panel_reason)
	end

	set_option_enabled(option_dependency_entries.enable_lantern_inventory_section, lantern_installed and inventory_options_panel_enabled, lantern_reason)
	set_option_enabled(option_dependency_entries.keep_lantern_curio_panel_separate, lantern_installed and inventory_options_panel_enabled and mod:get("enable_lantern_inventory_section") == true, lantern_reason)

	for _, setting_id in ipairs({
		"quick_discard_mode",
		"quick_discard_rarity",
		"quick_discard_max_item_level",
		"quick_discard_protect_above_equipped_level",
		"quick_discard_include_melee",
		"quick_discard_include_ranged",
		"quick_discard_include_curios",
		"quick_discard_protect_perfect_weapons",
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

	set_option_enabled(option_dependency_entries.quick_discard_curio_protection_level, curio_protection_enabled, quick_discard_enabled and mod:localize("option_requires_curio_discard_protection") or quick_discard_reason)

	for _, setting_id in ipairs({
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
	}) do
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

	set_option_enabled(option_dependency_entries.automatic_curio_min_health, automatic_health_enabled, automatic_curio_enabled and mod:localize("option_requires_automatic_curio_health") or automatic_curio_reason)
	set_option_enabled(option_dependency_entries.automatic_curio_min_toughness, automatic_toughness_enabled, automatic_curio_enabled and mod:localize("option_requires_automatic_curio_toughness") or automatic_curio_reason)
end

local function bind_option_dependencies(options_templates)
	local settings = options_templates and options_templates.settings

	if type(settings) ~= "table" then
		return
	end

	local registry_status, registry_valid, _, duplicate_ids = Capabilities.mutation(SettingsRegistry, "register", settings)

	if registry_status == "ok" and not registry_valid and type(duplicate_ids) == "table" then

		if not registry_valid and type(mod.error) == "function" then
			mod:error("Duplicate BetterInventory setting IDs: " .. table.concat(duplicate_ids or {}, ", "))
		end
	end

	local category_name = mod:get_readable_name()
	local setting_by_title = {}
	local curio_buyer_subsection_titles = {
		[mod:localize("automatic_curio_types_group")] = true,
		[mod:localize("automatic_curio_classes_group")] = true,
		[mod:localize("automatic_curio_characters_group")] = true,
	}
	local class_group_title = mod:localize("automatic_curio_classes_group")
	local character_group_title = mod:localize("automatic_curio_characters_group")
	local class_group_entry
	local character_group_entry

	for _, setting_id in ipairs({
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
		"expand_curio_inventory_window",
		"curio_target_card_width",
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
	}) do
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

		-- DMF preserves indentation for ordinary nested controls but drops it from
		-- nested group-header templates. Restore the two buyer subheadings to the
		-- same depth as their schema nodes so they do not look like peer sections.
		if type(entry) == "table" and entry.category == category_name and entry.widget_type == "group_header" and curio_buyer_subsection_titles[entry.display_name] then
			entry.indentation_level = 2

			if entry.display_name == class_group_title then
				class_group_entry = entry
			elseif entry.display_name == character_group_title then
				character_group_entry = entry
			end
		end

		local setting_id = type(entry) == "table" and entry.category == category_name and setting_by_title[entry.display_name]

		if type(setting_id) == "table" then
			-- Two view-local controls intentionally share the same label. Consume
			-- duplicate titles in schema order so both dependency entries bind
			-- correctly instead of the later one overwriting the earlier one.
			setting_id = table.remove(setting_id, 1)
		end

		if setting_id then
			option_dependency_entries[setting_id] = entry
			-- DMF caches generated option trees per view. Let each live child derive
			-- its disabled state from saved settings while DMF polls its getter, so
			-- neither an older nor newer tree can strand the opposite visual state.
			bind_live_option_dependency(setting_id, entry)
		elseif type(entry) == "table" and entry._better_inventory_curio_character_slot_index then
			option_dependency_entries.automatic_curio_character_entries[#option_dependency_entries.automatic_curio_character_entries + 1] = entry
		end
	end

	-- Keep the final DMF template and rendered-widget arrays structurally
	-- identical. Alf's generalized tabs pair them by numeric index, so hiding
	-- mode-dependent entries through validation functions shifts every later
	-- section. PlayerAssist uses the stable pattern too: keep entries present and
	-- express dependencies exclusively through disabled state.
	option_dependency_entries.automatic_curio_classes_group = class_group_entry
	option_dependency_entries.automatic_curio_characters_group = character_group_entry

	refresh_option_dependencies()
end

local function migrate_grid_column_settings()
	if mod:get("_grid_columns_v1_migrated") then
		return
	end

	local legacy_columns = tonumber(mod:get("columns"))
	local dedicated_setting_ids = {
		"melee_columns",
		"ranged_columns",
		"curio_columns",
	}

	if legacy_columns then
		legacy_columns = math.max(2, math.min(5, math.floor(legacy_columns)))
		local has_dedicated_customization = false

		for _, setting_id in ipairs(dedicated_setting_ids) do
			local configured_columns = tonumber(mod:get(setting_id))

			if configured_columns and configured_columns ~= 3 then
				has_dedicated_customization = true

				break
			end
		end

		-- A legacy profile has no way to express per-category values. Preserve
		-- its old global choice only when all three new controls still have their
		-- defaults; once any slider is customized, leave every dedicated value
		-- untouched.
		if not has_dedicated_customization then
			for _, setting_id in ipairs(dedicated_setting_ids) do
				mod:set(setting_id, legacy_columns, false)
			end
		end
	end

	mod:set("_grid_columns_v1_migrated", true, false)
end

function mod.on_enabled()
	ItemCustomization.on_enabled(mod)
	if type(Diagnostics.configure) == "function" then
		Diagnostics.configure(mod)
	end

	-- DMF requires unique setting IDs. Keep Curio content's mirror row aligned
	-- with the established Name It setting, which remains authoritative across
	-- upgrades and preserves the user's existing choice.
	local name_it_curio_name_value = mod:get("name_it_force_curio_name_in_detailed_mode")

	if name_it_curio_name_value == nil then
		name_it_curio_name_value = true
	end

	if mod:get("curio_content_name_it_curio_name") ~= name_it_curio_name_value then
		mod:set("curio_content_name_it_curio_name", name_it_curio_name_value, false)
	end

	-- DMF preserves saved values when a default changes. Apply the new compact
	-- card defaults once for installs that already initialized the old values;
	-- all three settings remain freely configurable afterward.
	if not mod:get("_compact_card_defaults_v1_migrated") then
		mod:set("append_mark_to_name", true)
		mod:set("show_pattern_mark", false)
		mod:set("show_rarity_name", false)
		mod:set("_compact_card_defaults_v1_migrated", true)
	end

	migrate_grid_column_settings()

	-- Replace the unreleased Curio-name checkboxes with one mode selector while
	-- preserving the currently enabled one-line presentation for test profiles.
	if not mod:get("_character_overview_curio_name_mode_v1_migrated") then
		if mod:get("character_overview_show_curio_names") == true then
			mod:set("character_overview_curio_name_mode", "one_line")
		end

		mod:set("_character_overview_curio_name_mode_v1_migrated", true)
	end

	if not mod:get("_curio_compression_mode_v1_migrated") then
		local previous_compact_setting = mod:get("compact_curio_stat_text")

		if previous_compact_setting == false then
			mod:set("curio_stat_compression", "none")
		elseif previous_compact_setting == true then
			mod:set("curio_stat_compression", "compression")
		end

		mod:set("_curio_compression_mode_v1_migrated", true)
	end

	-- Heavy Compression supersedes Compression as the default. Preserve an
	-- explicit No compression choice while upgrading the former default once.
	if not mod:get("_curio_heavy_default_v1_migrated") then
		local compression_mode = mod:get("curio_stat_compression")

		if compression_mode == nil or compression_mode == "compression" then
			mod:set("curio_stat_compression", "heavy")
		end

		mod:set("_curio_heavy_default_v1_migrated", true)
	end

	-- Move only the former defaults so deliberately customized icon sizes stay
	-- untouched on existing installations.
	if not mod:get("_inventory_icon_size_defaults_v2_migrated") then
		local blessing_size = mod:get("blessing_icon_size")
		local perk_rank_size = mod:get("weapon_perk_rank_icon_size")

		if blessing_size == nil or blessing_size == 34 then
			mod:set("blessing_icon_size", 36)
		end

		if perk_rank_size == nil or perk_rank_size == 18 then
			mod:set("weapon_perk_rank_icon_size", 17)
		end

		mod:set("_inventory_icon_size_defaults_v2_migrated", true)
	end

	-- Replace the former blessing checkbox with a configurable display mode while
	-- preserving an explicit disabled choice from existing installations.
	if not mod:get("_weapon_blessing_display_mode_v1_migrated") then
		local previous_show_blessings = mod:get("show_weapon_blessings")

		if previous_show_blessings ~= nil then
			mod:set("weapon_blessing_display_mode", previous_show_blessings == false and "off" or "icons")
		end

		mod:set("_weapon_blessing_display_mode_v1_migrated", true)
	end

	for i = 1, #COLOR_TARGETS do
		apply_color_preset(COLOR_TARGETS[i])
	end

	-- The character rows themselves are part of the static DMF schema. Refresh
	-- their saved operative labels and backend-ID selection bindings before the
	-- user can open Mod Options; live discovery will refresh them again.
	if type(CurioAcquisition.refresh_character_options) == "function" then
		CurioAcquisition.refresh_character_options(mod)
	end

	-- Arm discovery independently of GameplayStateRun event ordering. On a true
	-- first install there is no persisted roster, so the pending request waits
	-- harmlessly until the player reaches the Morningstar and then replaces the
	-- static Character N labels without requiring a reload.
	if type(CurioAcquisition.request_profile_discovery) == "function" then
		CurioAcquisition.request_profile_discovery(true)
	end

	Features.rebind_sort_options(mod, Layout)
	refresh_option_dependencies()
end

function mod.on_all_mods_loaded()
	-- v1.8.0 used R/R3 for Background Color, which collides with Darktide's
	-- native inventory discard action. Move that legacy default to A/LT once;
	-- explicitly configured alternatives are preserved.
	if mod:get("custom_item_background_color_keybind") == "group_finder_refresh_groups" then
		mod:set("custom_item_background_color_keybind", "navigate_secondary_left_pressed", true)
	end

	-- v1.9.2 originally inherited Q/Y for Change Name. Y is Darktide's native
	-- Favorite action in inventory views, so migrate that released default once
	-- to I / View / Touchpad. Other explicitly selected bindings are preserved.
	if mod:get("_custom_item_name_keybind_v2_migrated") ~= true then
		if mod:get("custom_item_name_keybind") == "hotkey_menu_special_2" then
			mod:set("custom_item_name_keybind", "lobby_open_inventory", false)
		end

		mod:set("_custom_item_name_keybind_v2_migrated", true, true)
	end

	ItemCustomization.on_all_mods_loaded(mod)
	Features.set_lantern_integration(mod, get_mod("Lantern of the Omnissiah"))
	Features.set_item_sorting_integration(get_mod("ItemSorting"))
end

local function lantern_recommendations_active()
	return type(Features.lantern_recommendations_active) == "function" and Features.lantern_recommendations_active()
end

-- Extracted to BetterInventory_character_overview_ui.lua.

-- Extracted to BetterInventory_character_overview_ui.lua.


-- Extracted to BetterInventory_character_overview_ui.lua.

-- Extracted to BetterInventory_character_overview_ui.lua.

-- Extracted to BetterInventory_character_overview_ui.lua.

-- Extracted to BetterInventory_character_overview_ui.lua.

function mod.on_setting_changed(setting_id)
	local color_change = color_target_by_setting_id[setting_id]
	local automatic_curio_setting = type(setting_id) == "string" and string.sub(setting_id, 1, 16) == "automatic_curio_"

	if type(Features.invalidate_all_view_composition) == "function" then
		Features.invalidate_all_view_composition()
	end

	if CharacterOverviewUI.is_visual_setting(setting_id) then
		CharacterOverviewUI.bump_visual_settings_generation()
	end

	ItemCustomization.on_setting_changed(mod, setting_id)

	if type(setting_id) == "string" and string.sub(setting_id, 1, #"auto_crafter_") == "auto_crafter_" and AutoCrafter and type(AutoCrafter.on_setting_changed) == "function" then
		AutoCrafter.on_setting_changed(setting_id)
	end

	if setting_id == "name_it_force_curio_name_in_detailed_mode" then
		mod:set("curio_content_name_it_curio_name", mod:get(setting_id), false)
	elseif setting_id == "curio_content_name_it_curio_name" then
		mod:set("name_it_force_curio_name_in_detailed_mode", mod:get(setting_id), false)
	end

	if color_change then
		if color_change.is_preset then
			apply_color_preset(color_change.target)
		else
			mod:set(color_change.target.preset_id, "custom", false)
		end
	end

	local should_refresh_dependencies = Capabilities.registry_refresh_required(SettingsRegistry, "should_refresh_dependencies", setting_id)

	if should_refresh_dependencies then
		refresh_option_dependencies()
	end

	if setting_id == "prioritize_equipped_favorites" or setting_id == "prioritize_perfect_roll_weapons" then
		Features.sync_inventory_sort_setting(mod, Layout)
	end

	if setting_id == "debug_enable_hot_path_diagnostics" and type(Diagnostics.configure) == "function" then
		Diagnostics.configure(mod)
	end

	if type(setting_id) == "string" and string.sub(setting_id, 1, 14) == "quick_discard_" then
		Features.sync_quick_discard_settings(mod, Layout)
	end

	if setting_id == "enable_automatic_curio_acquisition" or automatic_curio_setting then
		CurioAcquisition.on_setting_changed(mod, setting_id)
		Features.sync_curio_acquisition_settings(mod, Layout)
	end
end

function mod.on_game_state_changed(status, state_name)
	if state_name ~= "GameplayStateRun" then
		return
	end

	if status == "enter" then
		Features.begin_morningstar_auto_discard(mod)
		CurioAcquisition.begin_morningstar_pass(mod)
	elseif status == "exit" then
		if AutoCrafter and type(AutoCrafter.on_context_exit) == "function" then
			AutoCrafter.on_context_exit("GameplayStateRun_exit")
		end

		Features.cancel_morningstar_auto_discard()
		if type(CurioAcquisition.leave_morningstar) == "function" then
			CurioAcquisition.leave_morningstar()
		else
			CurioAcquisition.cancel()
		end
	end
end

-- MainMenuView is Darktide's Operative Selection screen. Keep this lifecycle
-- separate from GameplayStateRun so buyer scheduling never mistakes a loading
-- state or a missing hub player for a usable context.
mod:hook_safe(MainMenuView, "on_enter", function()
	if AutoCrafter and type(AutoCrafter.on_context_exit) == "function" then
		AutoCrafter.on_context_exit("operative_selection_entered")
	end

	if type(CurioAcquisition.enter_operative_selection) == "function" then
		CurioAcquisition.enter_operative_selection(mod)
	end
end)

mod:hook_safe(MainMenuView, "on_exit", function()
	if AutoCrafter and type(AutoCrafter.on_context_exit) == "function" then
		AutoCrafter.on_context_exit("operative_selection_exited")
	end

	if type(CurioAcquisition.leave_operative_selection) == "function" then
		CurioAcquisition.leave_operative_selection()
	end
end)

function mod.update(dt)
	if AutoCrafter and type(AutoCrafter.update) == "function" then
		AutoCrafter.update(dt)
	end
	local auto_crafter_busy = AutoCrafter and type(AutoCrafter.is_busy) == "function" and AutoCrafter.is_busy() or false

	ItemCustomization.update_runtime(mod, dt)
	EquipmentPersistence.update(mod, dt)
	if Features.discard_owner() then
		Features.reconcile_discard_transaction()
	end
	if Features.morningstar_auto_discard_needs_update(mod) then
		Features.update_morningstar_auto_discard(mod, dt, auto_crafter_busy)
	end
	if CurioAcquisition.needs_update(mod) then
		CurioAcquisition.update(mod, dt, Features.morningstar_auto_discard_is_busy(mod) or auto_crafter_busy)
	end
	if type(Diagnostics.update) == "function" and type(Diagnostics.enabled) == "function" and Diagnostics.enabled() then
		Diagnostics.update(mod, dt, CurioAcquisition, Features)
	end
end

function mod.on_disabled()
	if AutoCrafter and type(AutoCrafter.shutdown) == "function" then
		AutoCrafter.shutdown()
	end

	ItemCustomization.on_disabled(mod)
	Features.cancel_morningstar_auto_discard()
	Features.cancel_manual_discard()
	CurioAcquisition.cancel()
	Features.disable_inventory_views()
	if type(Diagnostics.reset) == "function" then
		Diagnostics.reset()
	end
end

local dmf_mod = get_mod("DMF")

if dmf_mod and type(dmf_mod.create_mod_options_settings) == "function" then
	mod:hook_safe(dmf_mod, "create_mod_options_settings", function(_, options_templates)
		if type(CurioAcquisition.inject_character_options) == "function" then
			CurioAcquisition.inject_character_options(mod, options_templates)
		end

		bind_option_dependencies(options_templates)
	end)
end

mod:hook(ItemGridViewBase, "init", function(func, view, definitions, settings, context)
	if view.__class_name == "InventoryWeaponsView" then
		local adjusted_definitions = Features.add_inventory_sort_toggle_definition(mod, Layout, definitions, view)
		local expansion = 0

		if Layout.is_enabled_for_view(mod, view) then
			adjusted_definitions, expansion = Layout.expanded_view_definitions(mod, adjusted_definitions, view)
		end

		view._better_inventory_grid_expansion = expansion

		return func(view, adjusted_definitions, settings, context)
	end

	if is_armoury_requisition_view(view) and mod:get("enable_grid_layout") ~= false and mod:get("enable_armoury_requisition_grid") ~= false then
		local slot_kind = Layout.store_slot_kind and Layout.store_slot_kind(view)
		local adjusted_definitions, expansion = Layout.expanded_armoury_view_definitions(mod, definitions, ItemGridViewBaseDefinitions, nil, slot_kind)

		view._better_inventory_armoury_grid_expansion = expansion

		return func(view, adjusted_definitions, settings, context)
	end

	if is_global_store_view(view) and mod:get("enable_grid_layout") ~= false and mod:get("enable_global_store_integration") ~= false and mod:get("enable_global_store_grid") ~= false then
		local slot_kind = Layout.store_slot_kind and Layout.store_slot_kind(view)
		local adjusted_definitions, expansion

		if Layout.expanded_global_store_view_definitions then
			adjusted_definitions, expansion = Layout.expanded_global_store_view_definitions(mod, definitions, ItemGridViewBaseDefinitions, slot_kind)
		else
			adjusted_definitions, expansion = Layout.expanded_armoury_view_definitions(mod, definitions, ItemGridViewBaseDefinitions, "enable_global_store_grid", slot_kind)
		end

		view._better_inventory_armoury_grid_expansion = expansion

		return func(view, adjusted_definitions, settings, context)
	end

	return func(view, definitions, settings, context)
end)

if ensure_class_method(InventoryWeaponsView, "_setup_sort_options") then
	mod:hook(InventoryWeaponsView, "_setup_sort_options", function(func, view, ...)
		local selected_option = view._selected_sort_option or view._sort_options and view._sort_options[view._selected_sort_option_index or 1]
		local selected_display_name = selected_option and selected_option.display_name
		local result = func(view, ...)

		Features.preserve_item_sorting_native_options(view, selected_display_name)
		Features.configure_inventory_sort_options(mod, Layout, view)
		Features.setup_inventory_options_panel(mod, Layout, view, ViewElementGrid)
		Features.bind_inventory_sort_toggle(mod, Layout, view)

		return result
	end)
end

if ensure_class_method(CreditsVendorView, "_setup_sort_options") then
	mod:hook(CreditsVendorView, "_setup_sort_options", function(func, view, ...)
		local selected_option = view._selected_sort_option or view._sort_options and view._sort_options[view._selected_sort_option_index or 1]
		local selected_display_name = selected_option and selected_option.display_name
		local result = func(view, ...)

		Features.preserve_item_sorting_native_options(view, selected_display_name)
		if is_armoury_requisition_view(view) then
			Features.configure_armoury_sort_options(mod, view)

			if mod:get("enable_armoury_requisition_grid") ~= false and mod:get("enable_armoury_requisition_sorting_panel") ~= false then
				Features.setup_armoury_native_sort_panel(mod, Layout, view, ViewElementGrid)
			end
		elseif is_global_store_view(view) and mod:get("enable_global_store_integration") ~= false then
			Features.configure_global_store_sort_options(mod, view)

			if mod:get("enable_global_store_grid") ~= false and mod:get("enable_global_store_sorting_panel") ~= false then
				Features.setup_armoury_native_sort_panel(mod, Layout, view, ViewElementGrid)
			end
		end

		return result
	end)
end

if ensure_class_method(InventoryWeaponsView, "update") then
	mod:hook(InventoryWeaponsView, "update", function(func, view, dt, t, input_service)
		Features.capture_inventory_options_panel_controller_focus(mod, Layout, view, input_service)
		Features.capture_inventory_controller_navigation(view, input_service)
		-- InventoryWeaponsView ultimately returns BaseView's two-value input/draw
		-- contract. Keep those values without allocating a vararg table each frame.
		local pass_input, pass_draw = func(view, dt, t, input_service)

		Features.update_inventory_sort_toggle(mod, Layout, view)
		Features.update_inventory_options_panel_controller_selection(view, input_service)

		return pass_input, pass_draw
	end)
end

if ensure_class_method(InventoryWeaponsView, "_handle_input") then
	mod:hook(InventoryWeaponsView, "_handle_input", function(func, view, input_service, ...)
		if Features.inventory_options_panel_controller_focused(view) or Features.consume_inventory_controller_grid_navigation(view) then
			-- View elements process directional input before the parent view. The
			-- multi-column item grid has already moved right this frame, so bypass
			-- only InventoryWeaponsView's single-column-era focus transfer while
			-- retaining the normal ItemGridViewBase/BaseView input chain.
			return ItemGridViewBase._handle_input(view, input_service, ...)
		end

		return func(view, input_service, ...)
	end)
end

mod:hook_safe(InventoryWeaponsView, "cb_on_favorite_pressed", function(view)
	local item_grid = view and view._item_grid

	if item_grid and item_grid._better_inventory_myfavorites_active == true then
		item_grid._better_inventory_myfavorites_dirty = true
		item_grid._better_inventory_myfavorites_generation = (item_grid._better_inventory_myfavorites_generation or 0) + 1
	end

	if mod:get("prioritize_equipped_favorites") ~= false then
		Features.resort_inventory(mod, Layout, view)
	end
end)

if ensure_class_method(InventoryBackgroundView, "_equip_local_changes") then
	mod:hook(InventoryBackgroundView, "_equip_local_changes", function(func, view, ...)
		return EquipmentPersistence.persist_local_changes(mod, func, view, ...)
	end)
end

if ensure_class_method(InventoryBackgroundView, "event_player_profile_updated") then
	mod:hook_safe(InventoryBackgroundView, "event_player_profile_updated", function(view, peer_id, local_player_id)
		EquipmentPersistence.refresh_from_authoritative_profile(view, peer_id, local_player_id)
	end)
end

-- Manual discard is dispatched through Darktide's native event path. Observe
-- the single native deletion promise so the shared destructive-operation token
-- remains held until backend settlement; no replacement request is issued.
mod:hook("GearService", "delete_gear_batch", function(func, gear_service, gear_ids, ...)
		local result = func(gear_service, gear_ids, ...)
		Features.observe_manual_discard_settlement(result)

		return result
	end)

mod:hook_safe(InventoryWeaponsView, "_equip_item", function(view)
	if type(Features.invalidate_view_composition) == "function" then
		Features.invalidate_view_composition(view)
	end

	local item_grid = view and view._item_grid

	if item_grid and item_grid._better_inventory_myfavorites_active == true then
		item_grid._better_inventory_myfavorites_dirty = true
		item_grid._better_inventory_myfavorites_generation = (item_grid._better_inventory_myfavorites_generation or 0) + 1
	end

	if mod:get("prioritize_equipped_favorites") ~= false then
		Features.resort_inventory(mod, Layout, view)
	end
end)

mod:hook_safe(InventoryWeaponsView, "on_exit", function(view)
	Features.release_lantern_inventory_section(view)
	Features.unregister_inventory_view(view)
end)

if ensure_class_method(CreditsVendorView, "update") then
	mod:hook(CreditsVendorView, "update", function(func, view, dt, t, input_service)
		if is_armoury_sort_view(view) then
			Features.capture_armoury_sort_panel_controller_focus(mod, view, input_service)
		end

		-- VendorViewBase/BaseView has the same fixed two-value update contract.
		local pass_input, pass_draw = func(view, dt, t, input_service)

		if is_armoury_sort_view(view) then
			Features.update_armoury_native_sort_panel(view)
			align_quick_level_mastery_buttons(view)
		end

		return pass_input, pass_draw
	end)
end

if ensure_class_method(CreditsVendorView, "_handle_input") then
	mod:hook(CreditsVendorView, "_handle_input", function(func, view, input_service, ...)
		if Features.armoury_sort_panel_controller_focused(view) then
			-- The panel's ViewElementGrid already processed navigation this frame.
			-- Skip VendorViewBase's A-to-purchase path while widget focus is active.
			return ItemGridViewBase._handle_input(view, input_service, ...)
		end

		return func(view, input_service, ...)
	end)
end

if ensure_class_method(CreditsVendorView, "on_exit") then
	mod:hook_safe(CreditsVendorView, "on_exit", function(view)
		Features.unregister_armoury_view(view)
	end)
end

-- Brunt's Armoury uses CreditsGoodsVendorView, not CreditsVendorView. Keep
-- Auto Crafter lifecycle hooks on the exact vanilla view so the read-only
-- probe is armed only for Brunt and not for Requisition or GlobalStore.
if ensure_class_method(CreditsGoodsVendorView, "on_enter") then
	mod:hook_safe(CreditsGoodsVendorView, "on_enter", function(view)
		if AutoCrafter and type(AutoCrafter.on_brunt_view_ready) == "function" then
			AutoCrafter.on_brunt_view_ready(view)
		end
	end)
end

mod:hook(InventoryWeaponsView, "_setup_item_grid_materials", function(func, view, ...)
	func(view, ...)

	local expansion = view._better_inventory_grid_expansion or 0

	if expansion <= 0 then
		return
	end

	for _, widget_name in ipairs({
		"grid_divider_top",
		"grid_divider_bottom",
	}) do
		local widget = view:_grid_widget_by_name(widget_name)
		local texture_style = widget and widget.style and widget.style.texture
		local texture_size = texture_style and texture_style.size

		if texture_size and texture_size[1] then
			texture_size[1] = texture_size[1] + expansion
		end
	end
end)

local function present_grid_with_configuration(func, view, layout, on_present_callback, configuration)
	local previous_active_view = active_grid_view
	local previous_configuration = active_grid_configuration

	active_grid_view = view
	active_grid_configuration = configuration

	local results = pack_values(pcall(func, view, layout, on_present_callback))
	local success = results[1]
	local result_count = results.n

	if type(Features.invalidate_view_composition) == "function" then
		Features.invalidate_view_composition(view)
	end

	active_grid_view = previous_active_view
	active_grid_configuration = previous_configuration

	if not success then
		error(results[2])
	end

	return unpack_values(results, 2, result_count)
end

if ensure_class_method(InventoryWeaponsView, "present_grid_layout") then
	mod:hook(InventoryWeaponsView, "present_grid_layout", function(func, view, layout, on_present_callback)
		if not Layout.is_enabled_for_view(mod, view) then
			return func(view, layout, on_present_callback)
		end

		-- Mark only this call, then continue through the complete DMF hook chain.
		-- The grid hook below transforms whichever blueprints reach the base view,
		-- including changes made by compatible sorting or information mods.
		local configuration = table.clone(INVENTORY_GRID_CONFIGURATION)
		configuration.slot_kind = Layout.slot_kind(view)

		return present_grid_with_configuration(func, view, layout, on_present_callback, configuration)
	end)
end

CharacterOverviewUI.install_hooks(ensure_class_method)

local function present_additional_grid(func, view, layout, on_present_callback, setting_id, configuration)
	if mod:get("enable_grid_layout") == false or mod:get(setting_id) == false then
		return func(view, layout, on_present_callback)
	end

	local active_configuration = table.clone(configuration)

	if Layout.store_slot_kind then
		-- Hadron, Armoury and GlobalStore expose the same native category tabs.
		-- Their cards honor the matching category slider, while each vendor
		-- configuration's maximum_columns keeps non-inventory views capped at
		-- three.
		active_configuration.slot_kind = Layout.store_slot_kind(view, layout)
	end

	return present_grid_with_configuration(func, view, layout, on_present_callback, active_configuration)
end

-- "Entreat Hadron" opens this modern ItemGridViewBase subclass. The separate
-- sacrifice flow uses CraftingMechanicusBarterItemsView and is intentionally
-- outside this hook.
if ensure_class_method(CraftingMechanicusModifyView, "present_grid_layout") then
	mod:hook(CraftingMechanicusModifyView, "present_grid_layout", function(func, view, layout, on_present_callback)
		return present_additional_grid(func, view, layout, on_present_callback, "enable_hadron_entreat_grid", HADRON_GRID_CONFIGURATION)
	end)
end

-- The Armoury landing page maps "Requisition Weapons & Curios" and GlobalStore's
-- Multi-Operative Supply to CreditsVendorView service routes. CreditsGoodsVendorView
-- (Brunt's Armoury) is deliberately not hooked by these settings.
if ensure_class_method(CreditsVendorView, "present_grid_layout") then
	mod:hook(CreditsVendorView, "present_grid_layout", function(func, view, layout, on_present_callback)
		if is_global_store_view(view) and mod:get("enable_global_store_integration") ~= false then
			return present_additional_grid(func, view, layout, on_present_callback, "enable_global_store_grid", GLOBAL_STORE_GRID_CONFIGURATION)
		end

		if not is_armoury_requisition_view(view) then
			return func(view, layout, on_present_callback)
		end

		return present_additional_grid(func, view, layout, on_present_callback, "enable_armoury_requisition_grid", ARMOURY_GRID_CONFIGURATION)
	end)
end

mod:hook(CreditsVendorView, "on_enter", function(func, view, ...)
	local result = func(view, ...)

	if not is_armoury_sort_view(view) then
		return result
	end

	local expansion = view._better_inventory_armoury_grid_expansion or 0
	local item_grid = view._item_grid

	if expansion > 0 and item_grid and type(item_grid.update_dividers) == "function" then
		item_grid:update_dividers("content/ui/materials/frames/item_list_top_hollow", {
			652 + expansion,
			118,
		}, {
			0,
			-18,
			20,
		}, "content/ui/materials/frames/details_lower_armoury", {
			674 + expansion,
			80,
		}, {
			0,
			0,
			20,
		})
	end

	align_quick_level_mastery_buttons(view)

	return result
end)

local function normalize_global_store_widgets(item_grid)
	for _, entry_data in pairs(item_grid and item_grid._widgets_by_entry_id or {}) do
		local widget = entry_data and entry_data.widget
		local portrait = widget and widget.style and widget.style.portrait

		if portrait then
			-- GlobalStore's callback expands the portrait for its native full-width
			-- cards. Keep it at the configured size after BetterInventory remaps
			-- the card into a compact grid.
			local portrait_size = 34

			if Layout.global_store_character_photo_size then
				portrait_size = Layout.global_store_character_photo_size(mod)
			end

			portrait.size = {
				portrait_size,
				portrait_size,
			}
		end

		local content = widget and widget.content
		local character_info = widget and widget.style and widget.style.character_info_text
		local class_icon = widget and widget.style and widget.style.character_class_icon_text

		if content and character_info and class_icon then
			-- GlobalStore supplies one combined string (class glyph + name). Split
			-- it once so BetterInventory can size the glyph and name independently.
			-- Keep the parsed name as a marker so repeated normalization does not
			-- strip the first word from an already-split character name.
			local raw_info = content.character_info_text
			local parsed_name = content.better_inventory_global_store_character_name

			if type(raw_info) == "string" and raw_info ~= "" and raw_info ~= parsed_name then
				local icon_text, name_text = string.match(raw_info, "^(%S+)%s+(.+)$")

				if icon_text and name_text then
					name_text = string.match(name_text, "^%s*(.-)%s*$") or name_text
					content.character_class_icon_text = icon_text
					content.character_info_text = name_text
					content.better_inventory_global_store_character_name = name_text
				end
			end
		end
	end
end

-- MyFavorites attaches its input hotspot to grid item widgets. Blueprint styles
-- are cloned during widget construction, so retain the actual runtime hotspot
-- style on shared content. configure_favorite_marker's working favorite-icon
-- callback then moves both the visible icon and its click target together.
if ensure_class_method(ViewElementGrid, "_create_entry_widget_from_config") then
	mod:hook(ViewElementGrid, "_create_entry_widget_from_config", function(func, item_grid, config, suffix, callback_name, secondary_callback_name, double_click_callback_name)
		local widget, alignment_widget = func(item_grid, config, suffix, callback_name, secondary_callback_name, double_click_callback_name)
		attach_runtime_marker_styles(widget, item_grid)

		return widget, alignment_widget
	end)
end

local function synchronize_myfavorites_marker(widget)
	if type(Diagnostics.count) == "function" then
		Diagnostics.count("marked_grid_scans")
	end
	local content = widget and widget.content
	local styles = widget and widget.style
	local hotspot_style = content and content.better_inventory_myfavorites_hotspot_style
	local favorite_style = styles and styles.favorite_icon

	if not hotspot_style or not hotspot_style.offset or hotspot_style.horizontal_alignment ~= "right" or hotspot_style.vertical_alignment ~= "top" then
		return
	end

	local equipped_visible = content.equipped == true
	local visibility_function = content.better_inventory_equipped_icon_visibility_function

	if not equipped_visible and type(visibility_function) == "function" then
		local ok, visible = pcall(visibility_function, content, styles and styles.equipped_icon)

		equipped_visible = ok and visible == true
	end

	local offset_y = equipped_visible and 33 or 7
	local favorite_shift_y = favorite_style and favorite_style.better_inventory_native_curio_favorite_shift_y or 0
	offset_y = offset_y + favorite_shift_y
	local favorite_marker_min_y = favorite_style and favorite_style.better_inventory_native_curio_favorite_min_y

	if favorite_marker_min_y then
		offset_y = math.max(offset_y, favorite_marker_min_y)
	end

	-- Equipped/favorite state can be revisited every frame by the native grid,
	-- but the marker position usually remains unchanged for many frames. Avoid
	-- rewriting shared style tables unless an external update actually moved it.
	local favorite_offset = favorite_style and favorite_style.offset
	if hotspot_style.offset[2] == offset_y and (not favorite_offset or favorite_offset[2] == offset_y) then
		return
	end

	if type(Diagnostics.count) == "function" then
		Diagnostics.count("alignment_writes")
	end
	hotspot_style.offset[2] = offset_y

	if favorite_offset then
		favorite_offset[2] = offset_y
	end
end

-- Synchronize independently of favorite_icon visibility. This is required for
-- unfavorited items: equipping, unequipping, or adding/removing them from an
-- inactive loadout can move Equipped Icon+'s marker while the favorite text
-- pass is hidden. The input hotspot must still be ready at the correct place.
if ensure_class_method(ViewElementGrid, "_update_grid_widgets") then
	mod:hook(ViewElementGrid, "_update_grid_widgets", function(func, item_grid, ...)
		if not item_grid or item_grid._better_inventory_myfavorites_active ~= true then
			return func(item_grid, ...)
		end

		local tracked_widgets = item_grid and item_grid._better_inventory_myfavorites_widgets

		if not tracked_widgets or next(tracked_widgets) == nil then
			return func(item_grid, ...)
		end

		-- Darktide's _update_grid_widgets contract returns no values. Calling it
		-- directly avoids allocating a packed vararg table for every active grid.
		func(item_grid, ...)

		local native_generation = item_grid._grid_generation or item_grid._layout_generation or item_grid._content_generation
		local previous_native_generation = item_grid._better_inventory_myfavorites_native_generation

		if native_generation ~= nil and native_generation ~= previous_native_generation then
			item_grid._better_inventory_myfavorites_native_generation = native_generation
			item_grid._better_inventory_myfavorites_dirty = true
		elseif native_generation == nil then
			-- Some Darktide builds expose no grid generation. Keep a bounded,
			-- conservative fallback for backend-driven rebinds that bypass our
			-- creation/favorite/equip hooks, while leaving idle frames untouched.
			item_grid._better_inventory_myfavorites_fallback_frames = (item_grid._better_inventory_myfavorites_fallback_frames or 0) + 1

			if item_grid._better_inventory_myfavorites_fallback_frames >= 15 then
				item_grid._better_inventory_myfavorites_fallback_frames = 0
				item_grid._better_inventory_myfavorites_dirty = true
			end
		end

		if item_grid._better_inventory_myfavorites_dirty ~= true then
			return
		end

		for widget in pairs(tracked_widgets) do
			synchronize_myfavorites_marker(widget)
		end

		item_grid._better_inventory_myfavorites_dirty = false
	end)
end

mod:hook(ViewElementGrid, "present_grid_layout", function(func, item_grid, layout, content_blueprints, ...)
	invalidate_myfavorites_grid(item_grid)
	content_blueprints = Features.compact_inventory_curio_stats_blueprints(mod, item_grid, content_blueprints)

	local view = active_grid_view or item_grid and item_grid._parent
	local configuration = active_grid_configuration

	if not configuration and is_global_store_view(view) and mod:get("enable_global_store_integration") ~= false then
		configuration = mod:get("enable_grid_layout") ~= false and mod:get("enable_global_store_grid") ~= false and table.clone(GLOBAL_STORE_GRID_CONFIGURATION) or GLOBAL_STORE_NATIVE_CONFIGURATION

		if configuration.store_item and Layout.store_slot_kind then
			configuration.slot_kind = Layout.store_slot_kind(view, layout)
		end
	end

	-- When the global grid is disabled, the Hadron and Requisition routes keep
	-- their native one-column geometry. Opt-in mirror settings reuse the exact
	-- detailed single-column blueprint used by inventory instead of the compact
	-- native card. This fallback runs only for those two views and never changes
	-- inventory, GlobalStore, or any multi-column configuration.
	if not configuration and mod:get("enable_grid_layout") == false then
		if is_hadron_view(view) and mod:get("enable_hadron_single_column_mirror") ~= false then
			configuration = {
				blueprint_key = "item",
				native_single_column = true,
			}
		elseif is_armoury_requisition_view(view) and mod:get("enable_armoury_single_column_mirror") ~= false then
			configuration = {
				blueprint_key = "store_item",
				native_single_column = true,
				store_item = true,
			}
		end
	end

	local definitions = view and view._definitions
	local grid_settings = definitions and definitions.grid_settings
	local grid_size = grid_settings and grid_settings.grid_size
	local blueprint_key = configuration and configuration.blueprint_key
	local item_blueprint = blueprint_key and content_blueprints and content_blueprints[blueprint_key]

	-- Restrict the global grid seam to the exact active view and blueprint.
	-- Missing fields mean the game contract changed, so pass through.
	if not view or item_grid ~= view._item_grid or not grid_size or not grid_size[1] or not item_blueprint or not item_blueprint.pass_template then
		return func(item_grid, layout, content_blueprints, ...)
	end

	local local_blueprints = shallow_copy(content_blueprints)
	local local_item_blueprint = table.clone(item_blueprint)
	local callback_arguments = pack_values(...)

	local_blueprints[blueprint_key] = local_item_blueprint

	Layout.configure_item_blueprint(mod, local_item_blueprint, grid_size[1], configuration)
	Layout.configure_grid(mod, item_grid)

	if configuration.global_store and type(callback_arguments[5]) == "function" then
		local on_present_callback = callback_arguments[5]

		callback_arguments[5] = function(...)
			local callback_results = pack_values(on_present_callback(...))

			-- GlobalStore's callback resizes portraits after the grid callback
			-- runs. Normalize again afterward so entry and tab changes use the
			-- same configured size as the initial presentation.
			normalize_global_store_widgets(item_grid)

			return unpack_values(callback_results, 1, callback_results.n)
		end
	end

	local results = pack_values(func(item_grid, layout, local_blueprints, unpack_values(callback_arguments, 1, callback_arguments.n)))

	if configuration.global_store then
		normalize_global_store_widgets(item_grid)
	end

	return unpack_values(results, 1, results.n)
end)
end

return Runtime
