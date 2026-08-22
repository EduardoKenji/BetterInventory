local CustomTier = {}
local Items = require("scripts/utilities/items")
local CurioValues = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_curio_values")

local TRANSCENDENT_RARITY = 5
local DARKEN_FACTOR = 0.4
local REFERENCE_RED = { 210, 30, 40 }
local COLOR_PREVIEW_SETTING_ID = "custom_tier_color_preview"
local WEAPON_TYPES = {
	WEAPON_MELEE = "melee",
	WEAPON_RANGED = "ranged",
}
local CURIO_TYPES = {
	gadget_innate_health_increase = {
		enabled_id = "custom_tier_curio_health_enabled",
		minimum_power_id = "custom_tier_curio_health_min_power",
		minimum_roll_id = "custom_tier_curio_health_min_roll",
		default_roll = 21,
	},
	gadget_innate_toughness_increase = {
		enabled_id = "custom_tier_curio_toughness_enabled",
		minimum_power_id = "custom_tier_curio_toughness_min_power",
		minimum_roll_id = "custom_tier_curio_toughness_min_roll",
		default_roll = 17,
	},
	gadget_innate_max_wounds_increase = {
		enabled_id = "custom_tier_curio_wounds_enabled",
		minimum_power_id = "custom_tier_curio_wounds_min_power",
		minimum_roll_id = "custom_tier_curio_wounds_min_roll",
		default_roll = 1,
	},
	gadget_stamina_increase = {
		enabled_id = "custom_tier_curio_stamina_enabled",
		minimum_power_id = "custom_tier_curio_stamina_min_power",
		minimum_roll_id = "custom_tier_curio_stamina_min_roll",
		default_roll = 3,
	},
}

local mod
local enabled = true
local color = { 255, REFERENCE_RED[1], REFERENCE_RED[2], REFERENCE_RED[3] }
local color_dark = { 255, REFERENCE_RED[1] * (1 - DARKEN_FACTOR), REFERENCE_RED[2] * (1 - DARKEN_FACTOR), REFERENCE_RED[3] * (1 - DARKEN_FACTOR) }
local display_name
local weapon_criteria = {}
local curio_criteria = {}

local function bounded_number(value, default, minimum, maximum)
	value = tonumber(value)

	if value == nil then
		value = default
	end

	return math.max(minimum, math.min(maximum, value))
end

local function setting(setting_id, default)
	if not mod or type(mod.get) ~= "function" then
		return default
	end

	local ok, value = pcall(mod.get, mod, setting_id)

	if ok and value ~= nil then
		return value
	end

	return default
end

local function set_setting(setting_id, value)
	if not mod or type(mod.set) ~= "function" then
		return false
	end

	return pcall(mod.set, mod, setting_id, value, false)
end

local function preview_channels(value)
	if type(value) ~= "table" then
		return
	end

	local red = tonumber(value[2])
	local green = tonumber(value[3])
	local blue = tonumber(value[4])

	if red == nil or green == nil or blue == nil then
		return
	end

	return bounded_number(red, REFERENCE_RED[1], 0, 255), bounded_number(green, REFERENCE_RED[2], 0, 255), bounded_number(blue, REFERENCE_RED[3], 0, 255)
end

local function sync_preview(red, green, blue)
	local current_red, current_green, current_blue = preview_channels(setting(COLOR_PREVIEW_SETTING_ID))

	if current_red == red and current_green == green and current_blue == blue then
		return false
	end

	return set_setting(COLOR_PREVIEW_SETTING_ID, { 255, red, green, blue })
end

local function item_power(item)
	if type(Items.expertise_level) ~= "function" then
		return
	end

	local ok, value = pcall(Items.expertise_level, item, true)

	return ok and tonumber(value) or nil
end

local function displayed_modifier_values(item)
	local base_stats = item and item.base_stats

	if type(base_stats) ~= "table" or #base_stats == 0 then
		return
	end

	local values = {}

	for index = 1, #base_stats do
		local value = type(base_stats[index]) == "table" and tonumber(base_stats[index].value)

		if value == nil then
			return
		end

		values[index] = math.floor((value <= 1.5 and value * 100 or value) + 0.5)
	end

	return values
end

local function total_base_stats(item, values)
	if type(Items.total_stats_value) == "function" then
		local ok, total = pcall(Items.total_stats_value, item)

		if ok and tonumber(total) then
			return tonumber(total)
		end
	end

	if type(values) ~= "table" then
		return
	end

	local total = 0

	for index = 1, #values do
		total = total + values[index]
	end

	return total
end

local function weapon_matches(item, kind)
	local criteria = weapon_criteria[kind]

	if not criteria or not criteria.enabled then
		return false
	end

	local power = item_power(item)

	if not power or power < criteria.minimum_power then
		return false
	end

	local needs_modifiers = criteria.minimum_total > 0 or criteria.minimum_modifier > 0 or criteria.required_high_stats > 0

	if not needs_modifiers then
		return true
	end

	local values = displayed_modifier_values(item)

	if not values then
		return false
	end

	if criteria.minimum_total > 0 then
		local total = total_base_stats(item, values)

		if not total or total < criteria.minimum_total then
			return false
		end
	end

	local high_stats = 0

	for index = 1, #values do
		local value = values[index]

		if criteria.minimum_modifier > 0 and value < criteria.minimum_modifier then
			return false
		end
		if value >= criteria.high_stat_threshold then
			high_stats = high_stats + 1
		end
	end

	return high_stats >= criteria.required_high_stats
end

local function curio_matches(item)
	local traits = item and item.traits
	local primary_trait = type(traits) == "table" and traits[1]

	if type(primary_trait) ~= "table" or type(CurioValues) ~= "table" or type(CurioValues.resolve) ~= "function" then
		return false
	end

	local ok, trait_name, roll = pcall(CurioValues.resolve, primary_trait)
	local criteria = ok and curio_criteria[trait_name] or nil

	if not criteria or not criteria.enabled or tonumber(roll) == nil or tonumber(roll) < criteria.minimum_roll then
		return false
	end

	local power = item_power(item)

	return power ~= nil and power >= criteria.minimum_power
end

local function matches(item)
	if not enabled or type(item) ~= "table" or tonumber(item.rarity) ~= TRANSCENDENT_RARITY then
		return false
	end

	local weapon_kind = WEAPON_TYPES[item.item_type]

	if weapon_kind then
		return weapon_matches(item, weapon_kind)
	elseif item.item_type == "GADGET" then
		return curio_matches(item)
	end

	return false
end

local function feature_active()
	if not enabled then
		return false
	end

	if mod and type(mod.is_enabled) == "function" then
		local ok, active = pcall(mod.is_enabled, mod)

		return ok and active ~= false
	end

	return true
end

local function patch_red_weapons_at_home()
	local resolver = rawget(_G, "get_mod")
	local red_mod = type(resolver) == "function" and resolver("red_weapons_at_home") or nil

	if type(red_mod) ~= "table" or type(red_mod.is_sainted_item) ~= "function" then
		return false
	end

	local state = red_mod._better_inventory_custom_tier_compatibility

	if type(state) ~= "table" then
		state = {}
		red_mod._better_inventory_custom_tier_compatibility = state
	end

	if red_mod.is_sainted_item ~= state.wrapper then
		state.fallback = red_mod.is_sainted_item
	end

	if type(state.fallback) ~= "function" then
		return false
	end

	state.wrapper = function(item)
		if feature_active() then
			return false
		end

		return state.fallback(item)
	end
	red_mod.is_sainted_item = state.wrapper

	return true
end

local function install_item_overrides()
	local state = Items._better_inventory_custom_tier_state

	if type(state) ~= "table" then
		state = {}
		Items._better_inventory_custom_tier_state = state
	end

	if Items.rarity_color ~= state.color_wrapper then
		state.color_fallback = Items.rarity_color
	end
	if Items.rarity_display_name ~= state.name_wrapper then
		state.name_fallback = Items.rarity_display_name
	end

	if type(state.color_fallback) ~= "function" or type(state.name_fallback) ~= "function" then
		return false
	end

	state.color_wrapper = function(item)
		if feature_active() and matches(item) then
			return color, color_dark
		end

		return state.color_fallback(item)
	end
	state.name_wrapper = function(item)
		if feature_active() and matches(item) then
			return display_name
		end

		return state.name_fallback(item)
	end
	Items.rarity_color = state.color_wrapper
	Items.rarity_display_name = state.name_wrapper

	return true
end

CustomTier.refresh = function(configured_mod)
	mod = configured_mod or mod
	enabled = setting("custom_tier_enabled", true) ~= false
	local red = bounded_number(setting("custom_tier_color_r", REFERENCE_RED[1]), REFERENCE_RED[1], 0, 255)
	local green = bounded_number(setting("custom_tier_color_g", REFERENCE_RED[2]), REFERENCE_RED[2], 0, 255)
	local blue = bounded_number(setting("custom_tier_color_b", REFERENCE_RED[3]), REFERENCE_RED[3], 0, 255)

	color = { 255, red, green, blue }
	color_dark = { 255, red * (1 - DARKEN_FACTOR), green * (1 - DARKEN_FACTOR), blue * (1 - DARKEN_FACTOR) }
	sync_preview(red, green, blue)

	for _, kind in pairs(WEAPON_TYPES) do
		weapon_criteria[kind] = {
			enabled = setting("custom_tier_" .. kind .. "_enabled", true) ~= false,
			minimum_power = bounded_number(setting("custom_tier_" .. kind .. "_min_power", 500), 500, 0, 500),
			minimum_total = bounded_number(setting("custom_tier_" .. kind .. "_min_base_stat_total", 0), 0, 0, 500),
			minimum_modifier = bounded_number(setting("custom_tier_" .. kind .. "_min_modifier", 0), 0, 0, 100),
			high_stat_threshold = bounded_number(setting("custom_tier_" .. kind .. "_high_stat_threshold", 80), 80, 0, 100),
			required_high_stats = bounded_number(setting("custom_tier_" .. kind .. "_required_high_stats", 0), 0, 0, 5),
		}
	end

	for trait_name, definition in pairs(CURIO_TYPES) do
		curio_criteria[trait_name] = {
			enabled = setting(definition.enabled_id, true) ~= false,
			minimum_power = bounded_number(setting(definition.minimum_power_id, 0), 0, 0, 500),
			minimum_roll = bounded_number(setting(definition.minimum_roll_id, definition.default_roll), definition.default_roll, 0, 100),
		}
	end

	local localize = rawget(_G, "Localize")
	local ok, localized = pcall(type(localize) == "function" and localize or function() return nil end, "loc_item_weapon_rarity_6")

	display_name = ok and type(localized) == "string" and localized ~= "" and localized or "Custom legendary"

	return enabled
end

CustomTier.install = function(configured_mod)
	CustomTier.refresh(configured_mod)
	local installed = install_item_overrides()

	patch_red_weapons_at_home()

	return installed
end

CustomTier.on_setting_changed = function(configured_mod, setting_id)
	if type(setting_id) ~= "string" or string.sub(setting_id, 1, #"custom_tier_") ~= "custom_tier_" then
		return false
	end

	mod = configured_mod or mod

	if setting_id == COLOR_PREVIEW_SETTING_ID then
		local red, green, blue = preview_channels(setting(COLOR_PREVIEW_SETTING_ID))

		if red ~= nil then
			set_setting("custom_tier_color_preset", "custom")
			set_setting("custom_tier_color_r", red)
			set_setting("custom_tier_color_g", green)
			set_setting("custom_tier_color_b", blue)
		end
	end

	CustomTier.refresh(configured_mod)

	return true
end

CustomTier.matches = matches
CustomTier.reference_red = REFERENCE_RED
CustomTier._test = {
	curio_types = CURIO_TYPES,
	displayed_modifier_values = displayed_modifier_values,
	feature_active = feature_active,
	preview_channels = preview_channels,
	weapon_types = WEAPON_TYPES,
}

return CustomTier
