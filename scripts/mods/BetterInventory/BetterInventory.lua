local mod = get_mod("BetterInventory")

local CraftingMechanicusModifyView = require("scripts/ui/views/crafting_mechanicus_modify_view/crafting_mechanicus_modify_view")
local CreditsVendorView = require("scripts/ui/views/credits_vendor_view/credits_vendor_view")
local ItemGridViewBase = require("scripts/ui/views/item_grid_view_base/item_grid_view_base")
local ItemGridViewBaseDefinitions = require("scripts/ui/views/item_grid_view_base/item_grid_view_base_definitions")
local InventoryWeaponsView = require("scripts/ui/views/inventory_weapons_view/inventory_weapons_view")
local ViewElementGrid = require("scripts/ui/view_elements/view_element_grid/view_element_grid")
local Layout = mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout")
local Features = mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_features")
local unpack_values = table.unpack or unpack
local active_grid_view
local active_grid_configuration
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

local function pack_values(...)
	return {
		n = select("#", ...),
		...,
	}
end

local function shallow_copy(source)
	local copy = {}

	for key, value in pairs(source or {}) do
		copy[key] = value
	end

	return copy
end

local function is_armoury_requisition_view(view)
	-- GlobalStore and similar mods reuse CreditsVendorView with a custom store
	-- service and add their own card footer content. Restrict BetterInventory's
	-- Armoury geometry to Darktide's native Requisition route.
	return view and view.__class_name == "CreditsVendorView" and view._optional_store_service == nil
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

local function set_option_enabled(entry, enabled, reason)
	if not entry then
		return
	end

	entry.disabled = not enabled
	entry.disabled_by = enabled and nil or {
		reason,
	}
end

local function refresh_option_dependencies()
	local grid_enabled = mod:get("enable_grid_layout") ~= false
	local automatic_height = mod:get("automatic_card_height") ~= false
	local native_reason = mod:localize("option_requires_grid_layout")

	for _, setting_id in ipairs({
		"columns",
		"expand_inventory_window",
		"grid_spacing",
		"automatic_card_height",
		"enable_hadron_entreat_grid",
		"enable_armoury_requisition_grid",
	}) do
		set_option_enabled(option_dependency_entries[setting_id], grid_enabled, native_reason)
	end

	local card_height_enabled = grid_enabled and not automatic_height
	local card_height_reason = grid_enabled and mod:localize("option_disabled_by_automatic_height") or native_reason

	set_option_enabled(option_dependency_entries.card_height, card_height_enabled, card_height_reason)

	local window_expansion_enabled = grid_enabled and mod:get("expand_inventory_window") ~= false
	local curio_expansion_enabled = window_expansion_enabled and mod:get("expand_curio_inventory_window") ~= false
	local expansion_reason = grid_enabled and mod:localize("option_requires_window_expansion") or native_reason
	local weapon_columns = math.floor(tonumber(mod:get("columns")) or 3)
	local weapon_width_threshold = mod:get("weapon_extra_width_column_threshold") == "five_only" and 5 or 4
	local weapon_extra_width_enabled = window_expansion_enabled and weapon_columns >= weapon_width_threshold
	local weapon_extra_width_reason = not window_expansion_enabled and expansion_reason or mod:localize("option_requires_weapon_extra_width_threshold")
	local curio_target_reason = not window_expansion_enabled and expansion_reason or not curio_expansion_enabled and mod:localize("option_requires_curio_expansion") or nil
	local armoury_grid_enabled = grid_enabled and mod:get("enable_armoury_requisition_grid") ~= false
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
	local weapon_rank_symbols_enabled = weapon_perk_ranks_enabled or weapon_blessing_ranked_text_enabled
	local weapon_perk_blessing_sections_enabled = weapon_perks_enabled and weapon_blessings_enabled
	local detailed_curio_profile = mod:get("curio_display_profile") == "detailed"
	local quick_discard_enabled = mod:get("enable_experimental_quick_discard") == true
	local quick_discard_reason = mod:localize("option_requires_experimental_quick_discard")
	local inventory_options_panel_enabled = mod:get("enable_inventory_options_panel_prototype") == true
	local inventory_options_panel_reason = mod:localize("option_requires_inventory_options_panel_prototype")
	local quick_look_card_grid_enabled = grid_enabled and mod:get("enable_quick_look_card_grid_integration") ~= false
	local quick_look_card_grid_reason = grid_enabled and mod:localize("option_requires_quick_look_card_grid_integration") or native_reason
	local quick_look_card_above_power = quick_look_card_grid_enabled and mod:get("quick_look_card_grid_stat_position") ~= "name_left" and mod:get("quick_look_card_grid_stat_position") ~= "name_right"
	local quick_look_card_bottom_padding_reason = quick_look_card_grid_enabled and mod:localize("option_requires_quick_look_card_above_power") or quick_look_card_grid_reason

	set_option_enabled(option_dependency_entries.expand_curio_inventory_window, window_expansion_enabled, expansion_reason)
	set_option_enabled(option_dependency_entries.weapon_extra_width_column_threshold, window_expansion_enabled, expansion_reason)
	set_option_enabled(option_dependency_entries.five_column_weapon_extra_width, weapon_extra_width_enabled, weapon_extra_width_reason)
	set_option_enabled(option_dependency_entries.curio_target_card_width, curio_expansion_enabled, curio_target_reason)
	set_option_enabled(option_dependency_entries.expand_armoury_requisition_window, armoury_grid_enabled, armoury_reason)
	set_option_enabled(option_dependency_entries.armoury_requisition_target_card_width, armoury_expansion_enabled, armoury_target_reason)
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
	set_option_enabled(option_dependency_entries.weapon_blessing_text_color_preset, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.weapon_blessing_text_color_r, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.weapon_blessing_text_color_g, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.weapon_blessing_text_color_b, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.weapon_blessing_text_opacity, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.weapon_blessing_text_vertical_spacing, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.weapon_blessing_text_bottom_padding, weapon_blessing_text_enabled, mod:localize("option_requires_weapon_blessing_text"))
	set_option_enabled(option_dependency_entries.blessing_icon_size, weapon_blessing_icons_enabled, mod:localize("option_requires_weapon_blessings"))
	set_option_enabled(option_dependency_entries.blessing_icon_spacing, weapon_blessing_icons_enabled, mod:localize("option_requires_weapon_blessings"))
	set_option_enabled(option_dependency_entries.weapon_perk_blessing_spacing, weapon_perk_blessing_sections_enabled, mod:localize("option_requires_perk_and_blessing_sections"))
	set_option_enabled(option_dependency_entries.curio_secondary_stat_font_size, detailed_curio_profile, mod:localize("option_requires_detailed_curio_profile"))
	set_option_enabled(option_dependency_entries.curio_primary_secondary_spacing, detailed_curio_profile, mod:localize("option_requires_detailed_curio_profile"))
	set_option_enabled(option_dependency_entries.quick_look_card_grid_stat_position, quick_look_card_grid_enabled, quick_look_card_grid_reason)
	set_option_enabled(option_dependency_entries.quick_look_card_grid_font_size, quick_look_card_grid_enabled, quick_look_card_grid_reason)
	set_option_enabled(option_dependency_entries.quick_look_card_grid_bottom_padding, quick_look_card_above_power, quick_look_card_bottom_padding_reason)

	for _, setting_id in ipairs({
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

	local curio_protection_enabled = quick_discard_enabled and mod:get("quick_discard_protect_high_level_curios") ~= false

	set_option_enabled(option_dependency_entries.quick_discard_curio_protection_level, curio_protection_enabled, quick_discard_enabled and mod:localize("option_requires_curio_discard_protection") or quick_discard_reason)
end

local function bind_option_dependencies(options_templates)
	local settings = options_templates and options_templates.settings

	if type(settings) ~= "table" then
		return
	end

	local category_name = mod:get_readable_name()
	local setting_by_title = {}

	for _, setting_id in ipairs({
		"columns",
		"expand_inventory_window",
		"weapon_extra_width_column_threshold",
		"five_column_weapon_extra_width",
		"grid_spacing",
		"automatic_card_height",
		"card_height",
		"expand_curio_inventory_window",
		"curio_target_card_width",
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
		"quick_look_card_grid_stat_position",
		"quick_look_card_grid_font_size",
		"quick_look_card_grid_bottom_padding",
		"curio_information_width_percent",
		"curio_preview_height_percent",
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
	}) do
		setting_by_title[mod:localize(setting_id)] = setting_id
	end

	option_dependency_entries = {}

	for i = 1, #settings do
		local entry = settings[i]
		local setting_id = type(entry) == "table" and entry.category == category_name and setting_by_title[entry.display_name]

		if setting_id then
			option_dependency_entries[setting_id] = entry
		end
	end

	-- DMF reevaluates validation functions while its options view is open and
	-- rebuilds the list when their result changes. Use that mechanism to remove
	-- the threshold entirely when its rule is off; the Curio-type filters remain
	-- visible and independently configurable.
	local curio_level_entry = option_dependency_entries.quick_discard_curio_protection_level

	if curio_level_entry then
		curio_level_entry.validation_function = function()
			return mod:get("quick_discard_protect_high_level_curios") ~= false
		end
	end

	refresh_option_dependencies()
end

function mod.on_enabled()
	-- DMF preserves saved values when a default changes. Apply the new compact
	-- card defaults once for installs that already initialized the old values;
	-- all three settings remain freely configurable afterward.
	if not mod:get("_compact_card_defaults_v1_migrated") then
		mod:set("append_mark_to_name", true)
		mod:set("show_pattern_mark", false)
		mod:set("show_rarity_name", false)
		mod:set("_compact_card_defaults_v1_migrated", true)
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

	refresh_option_dependencies()
end

function mod.on_setting_changed(setting_id)
	local color_change = color_target_by_setting_id[setting_id]

	if color_change then
		if color_change.is_preset then
			apply_color_preset(color_change.target)
		else
			mod:set(color_change.target.preset_id, "custom", false)
		end
	end

	if setting_id == "enable_grid_layout" or setting_id == "columns" or setting_id == "automatic_card_height" or setting_id == "expand_inventory_window" or setting_id == "weapon_extra_width_column_threshold" or setting_id == "expand_curio_inventory_window" or setting_id == "enable_armoury_requisition_grid" or setting_id == "expand_armoury_requisition_window" or setting_id == "weapon_blessing_display_mode" or setting_id == "show_weapon_perks" or setting_id == "show_weapon_perk_rank_symbols" or setting_id == "curio_display_profile" or setting_id == "enable_inventory_options_panel_prototype" or setting_id == "enable_experimental_quick_discard" or setting_id == "quick_discard_mode" or setting_id == "quick_discard_protect_high_level_curios" or setting_id == "enable_quick_look_card_grid_integration" or setting_id == "quick_look_card_grid_stat_position" then
		refresh_option_dependencies()
	end

	if setting_id == "prioritize_equipped_favorites" or setting_id == "prioritize_perfect_roll_weapons" then
		Features.sync_inventory_sort_setting(mod, Layout)
	end

	if type(setting_id) == "string" and string.sub(setting_id, 1, 14) == "quick_discard_" then
		Features.sync_quick_discard_settings(mod, Layout)
	end
end

function mod.on_game_state_changed(status, state_name)
	if state_name ~= "GameplayStateRun" then
		return
	end

	if status == "enter" then
		Features.begin_morningstar_auto_discard(mod)
	elseif status == "exit" then
		Features.cancel_morningstar_auto_discard()
	end
end

function mod.update(dt)
	Features.update_morningstar_auto_discard(mod, dt)
end

function mod.on_disabled()
	Features.cancel_morningstar_auto_discard()
	Features.disable_inventory_views()
end

local dmf_mod = get_mod("DMF")

if dmf_mod and type(dmf_mod.create_mod_options_settings) == "function" then
	mod:hook_safe(dmf_mod, "create_mod_options_settings", function(_, options_templates)
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
		local adjusted_definitions, expansion = Layout.expanded_armoury_view_definitions(mod, definitions, ItemGridViewBaseDefinitions)

		view._better_inventory_armoury_grid_expansion = expansion

		return func(view, adjusted_definitions, settings, context)
	end

	return func(view, definitions, settings, context)
end)

if ensure_class_method(InventoryWeaponsView, "_setup_sort_options") then
	mod:hook(InventoryWeaponsView, "_setup_sort_options", function(func, view, ...)
		local result = func(view, ...)

		Features.configure_inventory_sort_options(mod, Layout, view)
		Features.setup_inventory_options_panel(mod, Layout, view, ViewElementGrid)
		Features.bind_inventory_sort_toggle(mod, Layout, view)

		return result
	end)
end

mod:hook_safe(InventoryWeaponsView, "cb_on_favorite_pressed", function(view)
	if mod:get("prioritize_equipped_favorites") ~= false then
		Features.resort_inventory(mod, Layout, view)
	end
end)

mod:hook_safe(InventoryWeaponsView, "_equip_item", function(view)
	if mod:get("prioritize_equipped_favorites") ~= false then
		Features.resort_inventory(mod, Layout, view)
	end
end)

mod:hook_safe(InventoryWeaponsView, "update", function(view)
	Features.update_inventory_sort_toggle(mod, Layout, view)
end)

mod:hook_safe(InventoryWeaponsView, "on_exit", function(view)
	Features.unregister_inventory_view(view)
end)

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
		return present_grid_with_configuration(func, view, layout, on_present_callback, INVENTORY_GRID_CONFIGURATION)
	end)
end

local function present_additional_grid(func, view, layout, on_present_callback, setting_id, configuration)
	if mod:get("enable_grid_layout") == false or mod:get(setting_id) == false then
		return func(view, layout, on_present_callback)
	end

	return present_grid_with_configuration(func, view, layout, on_present_callback, configuration)
end

-- "Entreat Hadron" opens this modern ItemGridViewBase subclass. The separate
-- sacrifice flow uses CraftingMechanicusBarterItemsView and is intentionally
-- outside this hook.
if ensure_class_method(CraftingMechanicusModifyView, "present_grid_layout") then
	mod:hook(CraftingMechanicusModifyView, "present_grid_layout", function(func, view, layout, on_present_callback)
		return present_additional_grid(func, view, layout, on_present_callback, "enable_hadron_entreat_grid", HADRON_GRID_CONFIGURATION)
	end)
end

-- The Armoury landing page maps "Requisition Weapons & Curios" to
-- CreditsVendorView. CreditsGoodsVendorView (Brunt's Armoury) is deliberately
-- not hooked by this setting.
if ensure_class_method(CreditsVendorView, "present_grid_layout") then
	mod:hook(CreditsVendorView, "present_grid_layout", function(func, view, layout, on_present_callback)
		if not is_armoury_requisition_view(view) then
			return func(view, layout, on_present_callback)
		end

		return present_additional_grid(func, view, layout, on_present_callback, "enable_armoury_requisition_grid", ARMOURY_GRID_CONFIGURATION)
	end)
end

mod:hook(CreditsVendorView, "on_enter", function(func, view, ...)
	local result = func(view, ...)

	if not is_armoury_requisition_view(view) then
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

	return result
end)

mod:hook(ViewElementGrid, "present_grid_layout", function(func, item_grid, layout, content_blueprints, ...)
	content_blueprints = Features.compact_inventory_curio_stats_blueprints(mod, item_grid, content_blueprints)

	local view = active_grid_view
	local configuration = active_grid_configuration
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

	local_blueprints[blueprint_key] = local_item_blueprint

	Layout.configure_item_blueprint(mod, local_item_blueprint, grid_size[1], configuration)
	Layout.configure_grid(mod, item_grid)

	return func(item_grid, layout, local_blueprints, ...)
end)
