local mod = get_mod("BetterInventory")

local CraftingMechanicusModifyView = require("scripts/ui/views/crafting_mechanicus_modify_view/crafting_mechanicus_modify_view")
local CreditsVendorView = require("scripts/ui/views/credits_vendor_view/credits_vendor_view")
local ItemGridViewBase = require("scripts/ui/views/item_grid_view_base/item_grid_view_base")
local InventoryWeaponsView = require("scripts/ui/views/inventory_weapons_view/inventory_weapons_view")
local ViewElementGrid = require("scripts/ui/view_elements/view_element_grid/view_element_grid")
local Layout = mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout")
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
	neutral = {
		220,
		230,
		210,
	},
}
local CURIO_COLOR_TARGETS = {
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

for i = 1, #CURIO_COLOR_TARGETS do
	local target = CURIO_COLOR_TARGETS[i]

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
	local curio_target_reason = not window_expansion_enabled and expansion_reason or not curio_expansion_enabled and mod:localize("option_requires_curio_expansion") or nil
	local weapon_perks_enabled = mod:get("show_weapon_perks") == true

	set_option_enabled(option_dependency_entries.expand_curio_inventory_window, window_expansion_enabled, expansion_reason)
	set_option_enabled(option_dependency_entries.curio_target_card_width, curio_expansion_enabled, curio_target_reason)
	set_option_enabled(option_dependency_entries.weapon_perk_compression, weapon_perks_enabled, mod:localize("option_requires_weapon_perks"))
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
		"grid_spacing",
		"automatic_card_height",
		"card_height",
		"expand_curio_inventory_window",
		"curio_target_card_width",
		"enable_hadron_entreat_grid",
		"enable_armoury_requisition_grid",
		"weapon_perk_compression",
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

	for i = 1, #CURIO_COLOR_TARGETS do
		apply_color_preset(CURIO_COLOR_TARGETS[i])
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

	if setting_id == "enable_grid_layout" or setting_id == "automatic_card_height" or setting_id == "expand_inventory_window" or setting_id == "expand_curio_inventory_window" or setting_id == "show_weapon_perks" then
		refresh_option_dependencies()
	end
end

local dmf_mod = get_mod("DMF")

if dmf_mod and type(dmf_mod.create_mod_options_settings) == "function" then
	mod:hook_safe(dmf_mod, "create_mod_options_settings", function(_, options_templates)
		bind_option_dependencies(options_templates)
	end)
end

mod:hook(ItemGridViewBase, "init", function(func, view, definitions, settings, context)
	if view.__class_name ~= "InventoryWeaponsView" or not Layout.is_enabled_for_view(mod, view) then
		return func(view, definitions, settings, context)
	end

	local adjusted_definitions, expansion = Layout.expanded_view_definitions(mod, definitions, view)

	view._better_inventory_grid_expansion = expansion

	return func(view, adjusted_definitions, settings, context)
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

	local success, result = pcall(func, view, layout, on_present_callback)

	active_grid_view = previous_active_view
	active_grid_configuration = previous_configuration

	if not success then
		error(result)
	end

	return result
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
		return present_additional_grid(func, view, layout, on_present_callback, "enable_armoury_requisition_grid", ARMOURY_GRID_CONFIGURATION)
	end)
end

mod:hook(ViewElementGrid, "present_grid_layout", function(func, item_grid, layout, content_blueprints, ...)
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

	local local_blueprints = table.clone(content_blueprints)
	local local_item_blueprint = local_blueprints[blueprint_key]

	Layout.configure_item_blueprint(mod, local_item_blueprint, grid_size[1], configuration)
	Layout.configure_grid(mod, item_grid)

	return func(item_grid, layout, local_blueprints, ...)
end)
