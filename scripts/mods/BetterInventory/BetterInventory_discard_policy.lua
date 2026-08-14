local Policy = {}
local Items = require("scripts/utilities/items")
local CurioValues = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_curio_values")
local perfect_roll_cache = setmetatable({}, { __mode = "k" })

Policy.clear_runtime_cache = function()
	-- Native gear caches can strongly own item keys long after a grid closes.
	-- Replace the table at a UI ownership boundary without disturbing hot sorts.
	perfect_roll_cache = setmetatable({}, { __mode = "k" })
end

local function item_level(item)
	local expertise = Items.expertise_level(item, true)

	return tonumber(expertise)
end

local function item_type_is_enabled(mod, item_type)
	if item_type == "WEAPON_MELEE" then
		return mod:get("quick_discard_include_melee") ~= false
	elseif item_type == "WEAPON_RANGED" then
		return mod:get("quick_discard_include_ranged") ~= false
	elseif item_type == "GADGET" then
		return mod:get("quick_discard_include_curios") ~= false
	end

	return false
end

local function displayed_base_stat_values(item)
	local base_stats = item and item.base_stats

	if type(base_stats) ~= "table" or #base_stats ~= 5 then
		return
	end

	local values = {}

	for index = 1, #base_stats do
		local stat = base_stats[index]
		local raw_value = type(stat) == "table" and tonumber(stat.value)

		if not raw_value then
			return
		end

		values[index] = math.floor(raw_value * 100 + 0.5)
	end

	return values
end

local function projected_max_base_stat_values(item)
	local base_stats = item and item.base_stats

	if type(base_stats) ~= "table" or #base_stats ~= 5 or type(Items.preview_stats_change) ~= "function" or type(Items.max_expertise_level) ~= "function" then
		return
	end

	-- expertise_level also returns a boolean indicating whether baseItemLevel was
	-- present. Passing the call directly to tonumber forwards that boolean as
	-- tonumber's optional numeric base and raises for virtually every weapon.
	local current_expertise = Items.expertise_level(item, true)

	current_expertise = tonumber(current_expertise)
	local maximum_expertise = tonumber(Items.max_expertise_level())

	if not current_expertise or not maximum_expertise or current_expertise >= maximum_expertise then
		return
	end

	local preview_stats = {}
	local preview_keys = {}

	for index = 1, #base_stats do
		local stat = base_stats[index]
		local raw_value = type(stat) == "table" and tonumber(stat.value)

		if not raw_value then
			return
		end

		local preview_key = "better_inventory_stat_" .. index

		preview_keys[index] = preview_key
		preview_stats[index] = {
			display_name = preview_key,
			fraction = raw_value,
			name = stat.name or preview_key,
		}
	end

	local projected_stats = Items.preview_stats_change(item, maximum_expertise - current_expertise, preview_stats)

	if type(projected_stats) ~= "table" then
		return
	end

	local values = {}

	for index = 1, #preview_keys do
		local projected_stat = projected_stats[preview_keys[index]]
		local projected_value = tonumber(projected_stat and projected_stat.value)

		if not projected_value then
			return
		end

		values[index] = math.floor(projected_value + 0.5)
	end

	return values
end

local function perfect_roll_dump_stat_value(values)
	if type(values) ~= "table" or #values ~= 5 then
		return
	end

	local maximum_stats = 0
	local dump_stat_value

	for index = 1, #values do
		local displayed_value = values[index]

		if displayed_value == 80 then
			maximum_stats = maximum_stats + 1
		elseif displayed_value >= 60 and dump_stat_value == nil then
			dump_stat_value = displayed_value
		else
			return
		end
	end

	return maximum_stats == 4 and dump_stat_value or nil
end

local function calculate_perfect_roll_dump_stat_value(item)
	if not item or not Items.is_weapon(item.item_type) then
		return
	end

	local total = Items.total_stats_value(item)

	if not total or total > 380 then
		return
	end

	local base_stats = item.base_stats
	local current_expertise

	if total ~= 380 then
		local expertise = Items.expertise_level(item, true)

		current_expertise = tonumber(expertise)
	end
	local cached = perfect_roll_cache[item]
	local cache_matches = cached and cached.total == total and cached.current_expertise == current_expertise and type(base_stats) == "table" and #base_stats == 5

	if cache_matches then
		for index = 1, 5 do
			local raw_value = type(base_stats[index]) == "table" and tonumber(base_stats[index].value)

			if raw_value ~= cached.raw_values[index] then
				cache_matches = false
				break
			end
		end
	end

	if cache_matches then
		return cached.dump_stat_value
	end

	-- Total power is calculated from unrounded backend values, while each visible
	-- attribute is rounded independently. Consequently the fifth visible stat can
	-- legitimately show 61 or 62 on an otherwise perfect 380 roll.
	local dump_stat_value = total == 380 and perfect_roll_dump_stat_value(displayed_base_stat_values(item)) or perfect_roll_dump_stat_value(projected_max_base_stat_values(item))

	if type(base_stats) == "table" and #base_stats == 5 then
		local raw_values = {}

		for index = 1, 5 do
			raw_values[index] = type(base_stats[index]) == "table" and tonumber(base_stats[index].value) or false
		end

		perfect_roll_cache[item] = {
			current_expertise = current_expertise,
			dump_stat_value = dump_stat_value or false,
			raw_values = raw_values,
			total = total,
		}
	end

	-- Rarity upgrades do not change base attributes, but expertise upgrades do.
	-- Protect an underpowered weapon when Darktide's own maximum-expertise preview
	-- resolves to the same four-at-80, fifth-at-least-60 distribution.
	return dump_stat_value
end

Policy.perfect_roll_dump_stat_value = function(item)
	-- Sorting invokes this from a native comparator. A legacy or partially
	-- materialized item must sort as ordinary instead of taking down the view.
	local success, dump_stat_value = pcall(calculate_perfect_roll_dump_stat_value, item)

	return success and dump_stat_value or nil
end

Policy.is_perfect_roll_weapon = function(item)
	return Policy.perfect_roll_dump_stat_value(item) ~= nil
end

local CURIO_PRIMARY_TRAIT_SETTINGS = {
	gadget_innate_health_increase = "quick_discard_keep_health_curios",
	gadget_innate_toughness_increase = "quick_discard_keep_toughness_curios",
	gadget_innate_max_wounds_increase = "quick_discard_keep_wound_curios",
	gadget_stamina_increase = "quick_discard_keep_stamina_curios",
}
local CURIO_BUYER_PRIMARY_TRAIT_SETTINGS = {
	gadget_innate_health_increase = "automatic_curio_buy_health",
	gadget_innate_toughness_increase = "automatic_curio_buy_toughness",
	gadget_innate_max_wounds_increase = "automatic_curio_buy_wounds",
	gadget_stamina_increase = "automatic_curio_buy_stamina",
}
local CURIO_BUYER_PRIMARY_ROLL_SETTINGS = {
	gadget_innate_health_increase = {
		default = 21,
		setting_id = "automatic_curio_min_health",
	},
	gadget_innate_toughness_increase = {
		default = 17,
		setting_id = "automatic_curio_min_toughness",
	},
}

local function curio_primary_trait_name(item)
	local primary_trait = item and item.traits and item.traits[1]
	local trait_name, value = CurioValues.resolve(primary_trait)

	if type(trait_name) ~= "string" then
		return
	end

	for known_trait_name in pairs(CURIO_PRIMARY_TRAIT_SETTINGS) do
		if trait_name == known_trait_name or string.find(trait_name, known_trait_name, 1, true) then
			return known_trait_name, value
		end
	end
end

local function high_level_curio_is_protected(mod, item, level, protected_level)
	if level < protected_level then
		return false
	end

	local primary_trait_name = curio_primary_trait_name(item)
	local setting_id = primary_trait_name and CURIO_PRIMARY_TRAIT_SETTINGS[primary_trait_name]

	-- Unknown or future primary blessings fail closed. A game update must not turn
	-- an unrecognized high-level Curio into an automatic-discard candidate.
	return not setting_id or mod:get(setting_id) ~= false
end

local function automatic_curio_acquisition_protects(mod, item, level)
	if mod:get("enable_automatic_curio_acquisition") ~= true then
		return false
	end

	local minimum_level = math.clamp(math.floor(tonumber(mod:get("automatic_curio_min_item_level")) or 410), 0, 500)

	if level < minimum_level then
		return false
	end

	local primary_trait_name, primary_value = curio_primary_trait_name(item)
	local setting_id = primary_trait_name and CURIO_BUYER_PRIMARY_TRAIT_SETTINGS[primary_trait_name]

	if not setting_id or mod:get(setting_id) == false then
		return false
	end

	local roll_config = CURIO_BUYER_PRIMARY_ROLL_SETTINGS[primary_trait_name]

	if roll_config then
		-- Missing inventory roll data fails safe. It must never make an acquired or
		-- partially materialized Curio eligible for destructive automatic discard.
		if primary_value then
			local minimum_roll = math.clamp(tonumber(mod:get(roll_config.setting_id)) or roll_config.default, 0, 100)

			if primary_value + 0.0001 < minimum_roll then
				return false
			end
		end
	end

	return true
end

Policy.automatic_curio_acquisition_protects = automatic_curio_acquisition_protects

local function eligible_for_quick_discard(mod, item, is_equipped, maximum_equipped_levels, favorite_gear_ids)
	if not item or not item.gear_id or not item_type_is_enabled(mod, item.item_type) then
		return false
	end

	local rarity = tonumber(item.rarity)
	local rarity_threshold = math.clamp(math.floor(tonumber(mod:get("quick_discard_rarity")) or 1), 1, 5)

	if not rarity or rarity < 1 or rarity > rarity_threshold then
		return false
	end

	local favorited = favorite_gear_ids and favorite_gear_ids[item.gear_id] or not favorite_gear_ids and Items.is_item_id_favorited(item.gear_id)

	if favorited then
		return false
	end

	if is_equipped and is_equipped(item) then
		return false
	end

	local level = item_level(item)
	local maximum_level = math.clamp(math.floor(tonumber(mod:get("quick_discard_max_item_level")) or 490), 0, 500)

	if not level or level > maximum_level then
		return false
	end

	if mod:get("quick_discard_protect_above_equipped_level") ~= false then
		local maximum_equipped_level = maximum_equipped_levels and maximum_equipped_levels[item.item_type]

		if maximum_equipped_level and level > maximum_equipped_level then
			return false
		end
	end

	if Items.is_weapon(item.item_type) and mod:get("quick_discard_protect_perfect_weapons") ~= false and Policy.is_perfect_roll_weapon(item) then
		return false
	end

	-- Buying and automatically discarding the same Curio on a later hub entry is
	-- incoherent and wastes currency. Acquisition-filter matches remain protected
	-- even when the general high-level Curio protection is configured differently.
	if item.item_type == "GADGET" and automatic_curio_acquisition_protects(mod, item, level) then
		return false
	end

	if item.item_type == "GADGET" and mod:get("quick_discard_protect_high_level_curios") ~= false then
		local protected_level = math.clamp(math.floor(tonumber(mod:get("quick_discard_curio_protection_level")) or 410), 0, 500)

		if high_level_curio_is_protected(mod, item, level, protected_level) then
			return false
		end
	end

	return true
end

local function collect_quick_discard_candidates(mod, source_items, is_equipped, allowed_gear_ids, maximum_equipped_levels, favorite_gear_ids)
	local candidates = {}
	local excluded_errors = 0
	local first_error
	local seen = {}

	for _, entry in pairs(source_items or {}) do
		local item = entry and (entry.real_item or entry.item or entry)
		local gear_id = item and item.gear_id

		if gear_id and not seen[gear_id] and (not allowed_gear_ids or allowed_gear_ids[gear_id]) then
			local success, eligible = pcall(eligible_for_quick_discard, mod, item, is_equipped, maximum_equipped_levels, favorite_gear_ids)

			if success and eligible then
				seen[gear_id] = true
				candidates[#candidates + 1] = item
			elseif not success then
				-- Account inventories can contain legacy or partially materialized gear
				-- that current item utilities cannot evaluate. Automatic discard must
				-- fail closed for those entries instead of aborting the entire scan.
				excluded_errors = excluded_errors + 1
				first_error = first_error or eligible
			end
		end
	end

	return candidates, excluded_errors, first_error
end

local function add_loadout_gear_ids(target, loadout)
	for _, item in pairs(loadout or {}) do
		local gear_id = type(item) == "table" and item.gear_id or type(item) == "string" and item or nil

		if gear_id then
			target[gear_id] = true
		end
	end
end

local function equipped_gear_ids(profile, profile_presets)
	local equipped = {}

	add_loadout_gear_ids(equipped, profile and profile.loadout)
	add_loadout_gear_ids(equipped, profile and profile.loadout_item_ids)

	-- Profile presets are saved independently from the currently active profile.
	-- Treat every item referenced by every preset as equipped: an unfavorited item
	-- used only by an inactive loadout must never enter any discard candidate set.
	if type(profile_presets) == "table" then
		for _, preset in pairs(profile_presets) do
			if type(preset) == "table" then
				add_loadout_gear_ids(equipped, preset.loadout)
				add_loadout_gear_ids(equipped, preset.loadout_item_ids)
			end
		end
	end

	return equipped
end

local function maximum_equipped_levels(source_items, protected_gear_ids)
	local maximums = {}
	local unreadable_level = -1

	for _, entry in pairs(source_items or {}) do
		local item = entry and (entry.real_item or entry.item or entry)
		local gear_id = item and item.gear_id
		local item_type = item and item.item_type

		-- Item level 500 is the absolute ceiling. Once a category reaches it,
		-- subsequent equipped items of that category cannot improve its maximum.
		-- An unreadable equipped/loadout item is more important than any readable
		-- maximum: use a sentinel below every valid level so the later
		-- `level > maximum` check protects the entire category. This keeps both
		-- manual and automatic discard fail-closed for legacy account gear.
		if gear_id and protected_gear_ids[gear_id] and item_type and maximums[item_type] ~= 500 and maximums[item_type] ~= unreadable_level then
			local level_ok, level = pcall(item_level, item)

			if level_ok and level then
				maximums[item_type] = math.min(math.max(maximums[item_type] or 0, level), 500)
			else
				maximums[item_type] = unreadable_level
			end
		end
	end

	return maximums
end

local function quick_discard_candidates_from_items_detailed(mod, source_items, equipped_gear_ids, allowed_gear_ids, favorite_gear_ids)
	local equipped_levels = maximum_equipped_levels(source_items, equipped_gear_ids or {})
	local function is_equipped(item)
		return equipped_gear_ids and equipped_gear_ids[item.gear_id] == true
	end

	return collect_quick_discard_candidates(mod, source_items, is_equipped, allowed_gear_ids, equipped_levels, favorite_gear_ids)
end

Policy.quick_discard_candidates_from_items = function(mod, source_items, equipped_gear_ids, allowed_gear_ids, favorite_gear_ids)
	local candidates = quick_discard_candidates_from_items_detailed(mod, source_items, equipped_gear_ids, allowed_gear_ids, favorite_gear_ids)

	return candidates
end

Policy.equipped_gear_ids = equipped_gear_ids
Policy.quick_discard_candidates_from_items_detailed = quick_discard_candidates_from_items_detailed
Policy.quick_discard_candidates_from_source = function(mod, source_items, is_equipped, protected_gear_ids, allowed_gear_ids, favorite_gear_ids)
	local equipped_levels = maximum_equipped_levels(source_items, protected_gear_ids or {})

	return collect_quick_discard_candidates(mod, source_items, is_equipped, allowed_gear_ids, equipped_levels, favorite_gear_ids)
end

return Policy
