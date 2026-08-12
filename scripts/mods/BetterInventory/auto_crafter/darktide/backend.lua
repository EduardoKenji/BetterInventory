local Promise = require("scripts/foundation/utilities/promise")
local pack_values = table.pack or function(...)
	return { n = select("#", ...), ... }
end
local unpack_values = table.unpack or unpack
local Items = require("scripts/utilities/items")
local Mastery = require("scripts/utilities/mastery")
local MasterItems = require("scripts/backend/master_items")
local ProfileUtils = require("scripts/utilities/profile_utils")
local CraftingSettings = require("scripts/settings/item/crafting_settings")
local RankSettings = require("scripts/settings/item/rank_settings")
local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")

local Backend = {}

local function read_member(object, key)
	return object[key]
end

local function rejected(description)
	return Promise.rejected({
		code = "auto_crafter_unavailable",
		description = description,
	})
end

local function promise_or_resolved(value)
	if value and type(value.next) == "function" and type(value.catch) == "function" then
		return value
	end

	return Promise.resolved(value)
end

local function safe_member(object, key)
	if type(object) ~= "table" and type(object) ~= "userdata" then
		return nil
	end

	local ok, value = pcall(read_member, object, key)

	return ok and value or nil
end

local function error_description(error_value)
	if type(error_value) == "table" then
		local description = safe_member(error_value, "description") or safe_member(error_value, "message") or safe_member(error_value, "error")

		if description ~= nil and description ~= error_value then
			return error_description(description)
		end

		local code = safe_member(error_value, "code")

		return code ~= nil and tostring(code) or "unknown backend error"
	end

	return tostring(error_value or "unknown backend error")
end

local function transaction_id_mismatch(error_value)
	return string.find(string.lower(error_description(error_value)), "transaction id mismatch", 1, true) ~= nil
end

local function call_service(service, method_name, ...)
	if not service then
		return rejected("service unavailable: " .. tostring(method_name))
	end

	local method = safe_member(service, method_name)

	if type(method) ~= "function" then
		return rejected("method unavailable: " .. tostring(method_name))
	end

	local ok, result = pcall(method, service, ...)

	if not ok then
		return rejected(result)
	end

	return promise_or_resolved(result)
end

local function normalized_trait_mutation(kind, gear_id, index, trait_id, tier)
	local normalized_index = tonumber(index)
	local normalized_tier = tonumber(tier)
	local maximum_tier = kind == "perk" and safe_member(RankSettings, "max_perk_rank") or safe_member(RankSettings, "max_trait_rank")

	if type(gear_id) ~= "string" or gear_id == "" then
		return nil, kind .. " replacement gear id is invalid"
	end

	if normalized_index == nil or normalized_index ~= math.floor(normalized_index) or normalized_index < 1 or normalized_index > 2 then
		return nil, kind .. " replacement slot must be 1 or 2"
	end

	if type(trait_id) ~= "string" or trait_id == "" then
		return nil, kind .. " replacement master item id is invalid"
	end

	if normalized_tier == nil or normalized_tier ~= math.floor(normalized_tier) or normalized_tier < 1 or (tonumber(maximum_tier) and normalized_tier > tonumber(maximum_tier)) then
		return nil, kind .. " replacement tier is outside Darktide's supported rank range"
	end

	if type(MasterItems) ~= "table" or type(MasterItems.get_item) ~= "function" then
		return nil, kind .. " replacement master item registry is unavailable"
	end

	local item_ok, trait_item = pcall(MasterItems.get_item, trait_id)

	if not item_ok or trait_item == nil then
		return nil, kind .. " replacement master item is unavailable: " .. trait_id
	end

	return {
		gear_id = gear_id,
		index = normalized_index,
		trait_id = trait_id,
		tier = normalized_tier,
	}
end

local function nonempty_string(value)
	return type(value) == "string" and value ~= ""
end

local function finite_number(value)
	local number = tonumber(value)

	return number and number == number and number ~= math.huge and number ~= -math.huge and number or nil
end

local function normalized_mastery_trait(trait_id, tier)
	local normalized_tier = finite_number(tier)
	local maximum_tier = tonumber(safe_member(RankSettings, "max_trait_rank"))

	if not nonempty_string(trait_id) then
		return nil, "mastery blessing id is invalid"
	end
	if not normalized_tier or normalized_tier ~= math.floor(normalized_tier) or normalized_tier < 1 or maximum_tier and normalized_tier > maximum_tier then
		return nil, "mastery blessing tier is outside Darktide's supported rank range"
	end
	if type(MasterItems) ~= "table" or type(MasterItems.get_item) ~= "function" then
		return nil, "mastery blessing registry is unavailable"
	end

	local item_ok, item = pcall(MasterItems.get_item, trait_id)
	if not item_ok or item == nil then
		return nil, "mastery blessing master item is unavailable: " .. trait_id
	end

	return {
		rarity = normalized_tier,
		trait_name = trait_id,
	}
end

local function normalized_gear_ids(gear_ids, label)
	if type(gear_ids) ~= "table" or #gear_ids == 0 then
		return nil, tostring(label) .. " requires at least one item"
	end

	local normalized = {}
	local unique = {}
	for index, gear_id in ipairs(gear_ids) do
		if not nonempty_string(gear_id) or unique[gear_id] then
			return nil, tostring(label) .. " contains an invalid or duplicate gear id"
		end

		unique[gear_id] = true
		normalized[index] = gear_id
	end

	return normalized
end

local function confirmed_trait_mutation(kind, operation)
	return function(result)
		local items = safe_member(result, "items")

		if type(items) ~= "table" or next(items) == nil then
			return rejected(kind .. " replacement returned no authoritative item confirmation; mutation will not be retried")
		end

		for _, item in pairs(items) do
			local gear = safe_member(item, "gear")
			local result_gear_id = safe_member(item, "gear_id") or safe_member(item, "uuid") or safe_member(gear, "uuid") or safe_member(gear, "gear_id")

			if result_gear_id ~= nil and tostring(result_gear_id) == operation.gear_id then
				return result
			end
		end

		return rejected(kind .. " replacement response did not confirm the requested gear; mutation will not be retried")
	end
end

local function add_loadout_gear_ids(target, loadout)
	for _, item in pairs(loadout or {}) do
		local gear_id = type(item) == "table" and item.gear_id or type(item) == "string" and item or nil

		if gear_id then
			target[gear_id] = true
		end
	end
end

local function discard_protection_snapshot()
	local managers = rawget(_G, "Managers")
	local player_manager = managers and managers.player
	local save_manager = managers and managers.save
	local player_ok, player = pcall(player_manager and player_manager.local_player or function () end, player_manager, 1)

	if not player_ok or not player or player.__deleted or type(player.profile) ~= "function" or type(player.character_id) ~= "function" then
		return nil, "current player is unavailable"
	end

	local profile_ok, profile = pcall(player.profile, player)
	local character_ok, character_id = pcall(player.character_id, player)

	if not profile_ok or type(profile) ~= "table" or not character_ok or character_id == nil then
		return nil, "current profile is unavailable"
	end

	if not save_manager or type(save_manager.character_data) ~= "function" then
		return nil, "character save data is unavailable"
	end

	local save_ok, character_data = pcall(save_manager.character_data, save_manager, character_id)
	local presets_ok, profile_presets = pcall(ProfileUtils.get_profile_presets)

	if not save_ok or type(character_data) ~= "table" or type(character_data.favorite_items) ~= "table" then
		return nil, "favorite-item data is unavailable"
	end

	if not presets_ok or type(profile_presets) ~= "table" then
		return nil, "saved loadout data is unavailable"
	end

	local equipped = {}

	add_loadout_gear_ids(equipped, profile.loadout)
	add_loadout_gear_ids(equipped, profile.loadout_item_ids)

	for _, preset in pairs(profile_presets) do
		if type(preset) == "table" then
			add_loadout_gear_ids(equipped, preset.loadout)
			add_loadout_gear_ids(equipped, preset.loadout_item_ids)
		end
	end

	return {
		equipped = equipped,
		favorites = character_data.favorite_items,
	}
end

local function current_character_id()
	local managers = rawget(_G, "Managers")
	local player_manager = managers and managers.player
	local ok, player = pcall(player_manager and player_manager.local_player or function () end, player_manager, 1)

	if not ok or not player or player.__deleted then
		return nil
	end

	if type(player.character_id) == "function" then
		local id_ok, character_id = pcall(player.character_id, player)

		if id_ok and character_id ~= nil then
			return tostring(character_id)
		end
	end

	return nil
end

local function choice_master_id(choice)
	if type(choice) == "table" then
		return choice.masterId or choice.master_id or choice.id or choice.name
	end

	return choice
end

local function offer_master_id(offer)
	local description = safe_member(offer, "description")
	local choices = safe_member(description, "lootChoices") or safe_member(description, "loot_choices")
	local choice = type(choices) == "table" and choices[1] or nil

	return choice_master_id(choice) or safe_member(description, "masterId") or safe_member(description, "master_id")
end

local master_item_details
local merge_stat_catalog
local summarize_base_stats
local summarize_weapon_template_stats
local store_item_preview
local weapon_mark_index
local weapon_mark_index_source

local function non_empty_localization_id(item, field_name)
	local metadata = safe_member(item, field_name)
	local loc_id = safe_member(metadata, "loc_id")

	return type(loc_id) == "string" and string.find(loc_id, "%S") ~= nil
end

local function displayable_weapon_mark_identity(item)
	return type(item) == "table"
		and non_empty_localization_id(item, "weapon_family_display_name")
		and (
			non_empty_localization_id(item, "weapon_pattern_display_name")
			or non_empty_localization_id(item, "weapon_mark_display_name")
		)
end

local function displayable_weapon_mark_text(value)
	return type(value) == "string"
		and string.find(value, "%S") ~= nil
		and value ~= "n/a"
		and string.find(value, "<unlocalized", 1, true) == nil
end

local function indexed_weapon_marks(parent_pattern)
	if parent_pattern == nil or type(MasterItems) ~= "table" or type(MasterItems.get_cached) ~= "function" then
		return {}
	end

	local ok, cached = pcall(MasterItems.get_cached)

	if not ok or type(cached) ~= "table" then
		return {}
	end

	if cached ~= weapon_mark_index_source then
		local index = {}

		for master_id, item in pairs(cached) do
			local pattern = safe_member(item, "parent_pattern")
			local slots = safe_member(item, "slots")
			local slot = type(slots) == "table" and slots[1] or nil
			local weapon_template = safe_member(item, "weapon_progression_template") or safe_member(item, "weapon_template")

			if pattern ~= nil
				and (slot == "slot_primary" or slot == "slot_secondary")
				and weapon_template ~= nil
				and displayable_weapon_mark_identity(item)
			then
				local marks = index[pattern] or {}

				marks[#marks + 1] = {
					item = item,
					master_id = master_id,
				}
				index[pattern] = marks
			end
		end

		for _, marks in pairs(index) do
			table.sort(marks, function(left, right)
				return tostring(left.master_id) < tostring(right.master_id)
			end)
		end

		weapon_mark_index = index
		weapon_mark_index_source = cached
	end

	return weapon_mark_index and weapon_mark_index[parent_pattern] or {}
end

local function valid_weapon_slot(slot_type)
	return slot_type == "slot_primary" or slot_type == "slot_secondary"
end

local function mark_matches_offer_contract(mark_master_id, mark_item, mark_details, parent_pattern, offer_details)
	return type(mark_master_id) == "string"
		and mark_master_id ~= ""
		and type(mark_item) == "table"
		and type(parent_pattern) == "string"
		and parent_pattern ~= ""
		and valid_weapon_slot(offer_details and offer_details.slot_type)
		and mark_details.parent_pattern == parent_pattern
		and mark_details.slot_type == offer_details.slot_type
		and mark_details.weapon_category == offer_details.weapon_category
		and mark_details.weapon_template ~= nil
		and displayable_weapon_mark_identity(mark_item)
		and displayable_weapon_mark_text(mark_details.display_name)
		and displayable_weapon_mark_text(mark_details.sub_display_name)
end

local function summarize_store(store)
	local offers = safe_member(store, "offers") or {}
	local summary = {
		available = type(offers) == "table",
		offer_count = 0,
		offers = {},
		current_rotation_end = safe_member(store, "current_rotation_end"),
	}

	if type(offers) ~= "table" then
		return summary
	end

	for index, offer in ipairs(offers) do
		summary.offer_count = summary.offer_count + 1

		if index <= 128 then
			local price = safe_member(offer, "price")
			local amount = safe_member(price, "amount")
			local master_id = offer_master_id(offer)
			local description = safe_member(offer, "description")
			local preview_item = store_item_preview(description)
			local master_item

			if master_id and type(MasterItems) == "table" and type(MasterItems.get_item) == "function" then
				local master_ok, resolved_master_item = pcall(MasterItems.get_item, master_id)

				master_item = master_ok and resolved_master_item or nil
			end

			local details = master_item_details(master_id, master_item)
			local rolled_stats = summarize_base_stats(preview_item) or summarize_base_stats(description)
			local template_stats = summarize_weapon_template_stats(preview_item or master_item)
			local base_stats = merge_stat_catalog(template_stats, rolled_stats)
			local parent_pattern = details.parent_pattern or safe_member(preview_item, "parent_pattern") or safe_member(description, "parent_pattern")
			local sku = safe_member(offer, "sku")
			local choices = safe_member(description, "lootChoices") or safe_member(description, "loot_choices") or {}
			local marks = {}
			local seen_marks = {}
			local mark_candidates = {}

			for _, indexed in ipairs(indexed_weapon_marks(parent_pattern)) do
				mark_candidates[#mark_candidates + 1] = indexed
			end
			for _, choice in ipairs(choices) do
				mark_candidates[#mark_candidates + 1] = {
					master_id = choice_master_id(choice),
				}
			end

			for _, candidate in ipairs(mark_candidates) do
				local mark_master_id = candidate.master_id

				if type(mark_master_id) == "string" and mark_master_id ~= "" and not seen_marks[mark_master_id] then
					local mark_item = candidate.item
					local mark_ok, resolved_mark = false, nil

					if mark_item == nil and type(MasterItems) == "table" and type(MasterItems.get_item) == "function" then
						mark_ok, resolved_mark = pcall(MasterItems.get_item, mark_master_id)
					end

					if mark_ok then
						mark_item = resolved_mark
					end

					local mark_details = master_item_details(mark_master_id, mark_item)

					if mark_matches_offer_contract(mark_master_id, mark_item, mark_details, parent_pattern, details) then
						seen_marks[mark_master_id] = true
						marks[#marks + 1] = {
							base_stats = summarize_weapon_template_stats(mark_item),
							display_name = mark_details.display_name,
							master_id = mark_master_id,
							parent_pattern = mark_details.parent_pattern,
							slot_type = mark_details.slot_type,
							sub_display_name = mark_details.sub_display_name,
							weapon_category = mark_details.weapon_category,
							weapon_template = mark_details.weapon_template,
						}
					end
				end
			end

			summary.offers[index] = {
				base_item_level = tonumber(safe_member(preview_item, "baseItemLevel") or safe_member(description, "baseItemLevel")),
				base_stats = base_stats,
				display_name = details.display_name,
				offer_id = safe_member(offer, "offerId") or safe_member(offer, "offer_id"),
				master_id = master_id,
				marks = marks,
				parent_pattern = parent_pattern,
				price_type = safe_member(amount, "type"),
				price_amount = tonumber(safe_member(amount, "discounted_price") or safe_member(amount, "amount")),
				rarity = tonumber(safe_member(preview_item, "rarity") or safe_member(description, "rarity")),
				sku_category = safe_member(sku, "category"),
				slot_type = details.slot_type,
				sub_display_name = details.sub_display_name,
				weapon_category = details.weapon_category,
				weapon_template = details.weapon_template,
			}
		end
	end

	return summary
end

local function local_weapon_crafting_costs()
	local managers = rawget(_G, "Managers")
	local backend_manager = safe_member(managers, "backend")
	local interfaces = safe_member(backend_manager, "interfaces")
	local crafting = safe_member(interfaces, "crafting")
	local crafting_costs = safe_member(crafting, "crafting_costs")

	if type(crafting_costs) ~= "function" then
		return nil
	end

	local ok, costs = pcall(crafting_costs, crafting)

	return ok and safe_member(costs, "weapon") or nil
end

local function local_sacrifice_mastery_costs()
	local managers = rawget(_G, "Managers")
	local data_service = safe_member(managers, "data_service")
	local crafting = safe_member(data_service, "crafting")
	local get_costs = safe_member(crafting, "get_sacrifice_mastery_costs")

	if type(get_costs) ~= "function" then
		return nil
	end

	local ok, costs = pcall(get_costs, crafting)

	return ok and costs or nil
end

master_item_details = function(master_id, resolved_master_item)
	if master_id == nil or type(MasterItems) ~= "table" or type(MasterItems.get_item) ~= "function" then
		return {}
	end

	local master_item = resolved_master_item
	local ok = master_item ~= nil

	if not master_item then
		ok, master_item = pcall(MasterItems.get_item, master_id)
	end

	if not ok or not master_item then
		return {}
	end

	local display_name
	local sub_display_name
	local slots = safe_member(master_item, "slots")
	local slot_type = type(slots) == "table" and slots[1] or nil
	local weapon_category = slot_type == "slot_secondary" and "ranged" or slot_type == "slot_primary" and "melee" or nil

	if type(Items) == "table" and type(Items.weapon_card_display_name) == "function" then
		local name_ok, value = pcall(Items.weapon_card_display_name, master_item)

		if name_ok then
			display_name = value
		end
	end

	if type(Items) == "table" and type(Items.weapon_card_sub_display_name) == "function" then
		local sub_ok, value = pcall(Items.weapon_card_sub_display_name, master_item)

		if sub_ok then
			sub_display_name = value
		end
	end

	return {
		display_name = display_name or safe_member(master_item, "name"),
		parent_pattern = safe_member(master_item, "parent_pattern"),
		slot_type = slot_type,
		sub_display_name = sub_display_name,
		weapon_category = weapon_category,
		weapon_template = safe_member(master_item, "weapon_progression_template") or safe_member(master_item, "weapon_template"),
	}
end

local function find_wallet(data, currency_type)
	local by_type = safe_member(data, "by_type")

	if type(by_type) == "function" then
		local ok, wallet = pcall(by_type, data, currency_type)

		if ok then
			return wallet
		end
	end

	local wallets = safe_member(data, "wallets") or data

	if type(wallets) ~= "table" then
		return nil
	end

	for _, wallet in ipairs(wallets) do
		local balance = safe_member(wallet, "balance")

		if safe_member(balance, "type") == currency_type then
			return wallet
		end
	end

	return nil
end

local function summarize_wallets(wallet_data)
	local summary = {
		available = wallet_data ~= nil,
		currencies = {},
	}

	for _, currency_type in ipairs({ "credits", "plasteel", "diamantine" }) do
		local wallet = find_wallet(wallet_data, currency_type)
		local balance = safe_member(wallet, "balance")

		summary.currencies[currency_type] = {
			amount = tonumber(safe_member(balance, "amount")),
			owner = safe_member(wallet, "owner"),
		}
	end

	return summary
end

local function count_collection(collection)
	if type(collection) ~= "table" then
		return 0
	end

	local array_count = #collection

	if array_count > 0 then
		return array_count
	end

	local count = 0

	for _ in pairs(collection) do
		count = count + 1
	end

	return count
end

local function item_instance(gear, gear_id)
	if type(MasterItems) ~= "table" or type(MasterItems.get_item_instance) ~= "function" then
		return nil
	end

	local ok, item = pcall(MasterItems.get_item_instance, gear, gear_id)

	return ok and item or nil
end

local function item_stat_value(item, stat_name)
	local base_stats = safe_member(item, "base_stats")

	if type(base_stats) ~= "table" then
		return nil
	end

	for _, stat in ipairs(base_stats) do
		local name = safe_member(stat, "name")

		if name == stat_name then
			local value = tonumber(safe_member(stat, "value"))

			if value == nil then
				return nil
			end

			return value <= 1.01 and math.floor(value * 100 + 0.5) or math.floor(value + 0.5)
		end
	end

	return nil
end

local function damage_stat_value(stat_values, stat_labels)
	for name, value in pairs(stat_values or {}) do
		local normalized_name = string.lower(tostring(name))
		local display_name_key = stat_labels and stat_labels[name]

		if display_name_key == "loc_stats_display_damage_stat" or string.find(normalized_name, "dps", 1, true) or string.find(normalized_name, "damage", 1, true) then
			return value
		end
	end

	return nil
end

summarize_base_stats = function(source)
	local base_stats = safe_member(source, "base_stats") or safe_member(source, "baseStats")

	if type(base_stats) ~= "table" then
		return nil
	end

	local summary = {}

	for key, stat in pairs(base_stats) do
		local name = safe_member(stat, "name") or safe_member(stat, "stat_name") or safe_member(stat, "statName")
		local value = safe_member(stat, "value")
		local display_name_key = safe_member(stat, "display_name") or safe_member(stat, "displayName")

		if name == nil and type(key) == "string" and type(stat) == "number" then
			name = key
			value = stat
		end

		local numeric_value = tonumber(value)

		if name ~= nil and numeric_value ~= nil then
			summary[#summary + 1] = {
				display_name_key = display_name_key,
				name = tostring(name),
				value = numeric_value,
			}
		end
	end

	return #summary > 0 and summary or nil
end

local function summarize_potential_base_stats(item, rolled_stats)
	if type(Items) ~= "table" or type(Items.preview_stats_change) ~= "function" or type(Items.expertise_level) ~= "function" or type(Items.max_expertise_level) ~= "function" then
		return nil
	end

	local comparing_stats = {}

	for _, stat in ipairs(rolled_stats or {}) do
		local value = tonumber(stat.value)

		if stat.name and value ~= nil then
			comparing_stats[#comparing_stats + 1] = {
				display_name = stat.name,
				fraction = value <= 1.01 and value or value / 100,
				name = stat.name,
			}
		end
	end

	if #comparing_stats == 0 then
		return nil
	end

	local expertise_ok, current_expertise = pcall(Items.expertise_level, item, true)
	local maximum_ok, maximum_expertise = pcall(Items.max_expertise_level)
	current_expertise = expertise_ok and tonumber(current_expertise) or nil
	maximum_expertise = maximum_ok and tonumber(maximum_expertise) or nil

	if current_expertise == nil or maximum_expertise == nil or maximum_expertise < current_expertise then
		return nil
	end

	-- A level-500 item already exposes its final values. Some game builds return no
	-- preview table for a zero-level change, so do not make completed weapons
	-- invisible to inventory-base reuse.
	if maximum_expertise == current_expertise then
		local summary = {}

		for _, stat in ipairs(comparing_stats) do
			summary[stat.name] = math.floor(stat.fraction * 100 + 0.5)
		end

		return next(summary) and summary or nil
	end

	local preview_ok, preview = pcall(Items.preview_stats_change, item, maximum_expertise - current_expertise, comparing_stats)

	if not preview_ok or type(preview) ~= "table" then
		return nil
	end

	local summary = {}

	for _, stat in ipairs(comparing_stats) do
		local preview_stat = preview[stat.name]
		local value = tonumber(safe_member(preview_stat, "value"))

		if value ~= nil then
			summary[stat.name] = math.floor(value + 0.5)
		end
	end

	return next(summary) and summary or nil
end

summarize_weapon_template_stats = function(source)
	if source == nil or type(WeaponTemplate) ~= "table" or type(WeaponTemplate.weapon_template_from_item) ~= "function" then
		return nil
	end

	local ok, weapon_template = pcall(WeaponTemplate.weapon_template_from_item, source)

	if not ok or type(weapon_template) ~= "table" then
		return nil
	end

	local definitions = safe_member(weapon_template, "base_stats")

	if type(definitions) ~= "table" then
		return nil
	end

	local summary = {}

	for name, definition in pairs(definitions) do
		if type(name) == "string" and type(definition) == "table" and safe_member(definition, "is_stat_trait") ~= false then
			summary[#summary + 1] = {
				display_name_key = safe_member(definition, "display_name") or safe_member(definition, "displayName"),
				name = name,
			}
		end
	end

	table.sort(summary, function (left, right)
		local left_key = tostring(left.display_name_key or left.name)
		local right_key = tostring(right.display_name_key or right.name)

		return left_key == right_key and left.name < right.name or left_key < right_key
	end)

	return #summary > 0 and summary or nil
end

merge_stat_catalog = function(template_stats, rolled_stats)
	local merged = {}
	local by_name = {}

	for _, stat in ipairs(template_stats or {}) do
		local entry = {
			display_name_key = stat.display_name_key,
			name = stat.name,
			value = stat.value,
		}

		merged[#merged + 1] = entry
		by_name[entry.name] = entry
	end

	for _, stat in ipairs(rolled_stats or {}) do
		local entry = by_name[stat.name]

		if entry then
			entry.display_name_key = entry.display_name_key or stat.display_name_key
			entry.value = stat.value
		else
			entry = {
				display_name_key = stat.display_name_key,
				name = stat.name,
				value = stat.value,
			}
			merged[#merged + 1] = entry
			by_name[entry.name] = entry
		end
	end

	table.sort(merged, function (left, right)
		local left_key = tostring(left.display_name_key or left.name)
		local right_key = tostring(right.display_name_key or right.name)

		return left_key == right_key and left.name < right.name or left_key < right_key
	end)

	return #merged > 0 and merged or nil
end

store_item_preview = function(description)
	if description == nil or type(MasterItems) ~= "table" or type(MasterItems.get_store_item_instance) ~= "function" then
		return nil
	end

	local ok, item = pcall(MasterItems.get_store_item_instance, description)

	return ok and item or nil
end

local function canonical_master_item_name(value)
	if type(value) == "string" then
		return value
	end

	local direct = safe_member(value, "name")
		or safe_member(value, "id")
		or safe_member(value, "master_id")
		or safe_member(value, "masterId")

	if direct ~= nil then
		return direct
	end

	local nested = safe_member(value, "item") or safe_member(value, "trait")

	if nested ~= value then
		return canonical_master_item_name(nested)
	end

	return nil
end

local function trait_display_name_key(trait_id, source)
	local display_name = safe_member(source, "display_name") or safe_member(source, "displayName")

	if display_name ~= nil then
		return display_name
	end

	if trait_id ~= nil and type(MasterItems) == "table" and type(MasterItems.get_item) == "function" then
		local ok, trait_item = pcall(MasterItems.get_item, trait_id)

		if ok and trait_item then
			return safe_member(trait_item, "display_name") or safe_member(trait_item, "displayName")
		end
	end

	return nil
end

local function summarize_perk_catalog(metadata)
	local ranks = safe_member(metadata, "perks") or {}
	local catalog = {}
	local catalog_by_id = {}
	local maximum_tier

	if type(ranks) ~= "table" then
		return catalog
	end

	for rank, rank_data in pairs(ranks) do
		local tier = tonumber(safe_member(rank_data, "rarity") or safe_member(rank_data, "rank") or rank)

		if tier ~= nil then
			maximum_tier = math.max(maximum_tier or tier, tier)
		end
	end

	for rank, rank_data in pairs(ranks) do
		local tier = tonumber(safe_member(rank_data, "rarity") or safe_member(rank_data, "rank") or rank)
		local perks = safe_member(rank_data, "perks") or rank_data

		-- Auto Crafter always targets best-in-slot perk rank. Lower tiers are
		-- valid vanilla choices before their mastery reward unlocks, but exposing
		-- them here creates accidental Tier I plans that nobody wants to keep.
		if type(perks) == "table" and (maximum_tier == nil or tier == maximum_tier) then
			for _, perk in pairs(perks) do
				local name = canonical_master_item_name(perk)

				if name ~= nil then
					local perk_item
					local display_name

					if type(MasterItems) == "table" and type(MasterItems.get_item) == "function" then
						local item_ok, resolved_item = pcall(MasterItems.get_item, name)

						perk_item = item_ok and resolved_item or nil
					end

					-- Match ViewElementPerksItem exactly. Perk master-item display_name is
					-- an internal content label; vanilla renders the interpolated trait
					-- description instead (for example "+25% Damage vs Flak Armoured").
					if perk_item and tier and type(Items) == "table" and type(Items.trait_description) == "function" then
						local description_ok, description = pcall(Items.trait_description, perk_item, tier, 1)

						display_name = description_ok and description or nil
					end

					local entry = {
						description_key = perk_item and safe_member(perk_item, "description") or nil,
						display_name = display_name,
						display_name_key = trait_display_name_key(name, perk),
						id = tostring(name),
						tier = tier,
						trait = perk_item and safe_member(perk_item, "trait") or nil,
					}
					local existing = catalog_by_id[entry.id]

					-- The metadata endpoint may repeat the same canonical perk inside a
					-- rank. It is still one backend mutation target and must not become
					-- an artificial Games Lantern ambiguity.
					if existing == nil then
						catalog[#catalog + 1] = entry
						catalog_by_id[entry.id] = entry
					elseif (tonumber(entry.tier) or 0) > (tonumber(existing.tier) or 0) then
						for key, value in pairs(entry) do
							existing[key] = value
						end
					end
				end
			end
		end
	end

	table.sort(catalog, function (left, right)
		if left.tier == right.tier then
			return left.id < right.id
		end

		return (left.tier or 0) < (right.tier or 0)
	end)

	return catalog
end

local function summarize_blessing_catalog(sticker_book)
	local catalog = {}

	if type(sticker_book) ~= "table" then
		return catalog
	end

	for trait_name, statuses in pairs(sticker_book) do
		local valid_master_item = false
		local trait_item

		if type(MasterItems) == "table" and type(MasterItems.get_item) == "function" then
			local ok, item = pcall(MasterItems.get_item, trait_name)
			valid_master_item = ok and item ~= nil
			trait_item = valid_master_item and item or nil
		end

		if valid_master_item then
			local tiers = {}

			if type(statuses) == "table" then
				for tier, status in pairs(statuses) do
					local numeric_tier = tonumber(tier)

					if numeric_tier ~= nil and status ~= "invalid" then
						tiers[#tiers + 1] = {
							status = tostring(status),
							tier = numeric_tier,
						}
					end
				end
			end

			table.sort(tiers, function (left, right)
				return left.tier < right.tier
			end)

			local icon
			local frame
			local highest_tier = tiers[#tiers] and tiers[#tiers].tier

			if trait_item and highest_tier and type(Items) == "table" and type(Items.trait_textures) == "function" then
				local textures_ok, texture_icon, texture_frame = pcall(Items.trait_textures, trait_item, highest_tier)

				if textures_ok then
					icon = texture_icon
					frame = texture_frame
				end
			end

			catalog[#catalog + 1] = {
				description_key = safe_member(trait_item, "description"),
				display_name_key = trait_display_name_key(trait_name),
				frame = frame,
				id = tostring(trait_name),
				icon = icon,
				tiers = tiers,
			}
		end
	end

	table.sort(catalog, function (left, right)
		return left.id < right.id
	end)

	return catalog
end

local function summarize_item(gear, gear_id)
	local item = item_instance(gear, gear_id)

	if not item then
		return {
			gear_id = gear_id,
			available = false,
		}
	end

	local stat_values = {}
	local base_stat_labels = {}
	local rolled_stats = summarize_base_stats(item) or {}
	local template_stats = summarize_weapon_template_stats(item) or {}

	for _, stat in ipairs(template_stats) do
		if stat.name and stat.display_name_key then
			base_stat_labels[stat.name] = stat.display_name_key
		end
	end

	for _, stat in ipairs(rolled_stats) do
		local value = tonumber(stat.value)

		if stat.name and value ~= nil then
			stat_values[stat.name] = value <= 1.01 and math.floor(value * 100 + 0.5) or math.floor(value + 0.5)
			base_stat_labels[stat.name] = base_stat_labels[stat.name] or stat.display_name_key
		end
	end

	local potential_stat_values = summarize_potential_base_stats(item, rolled_stats)
	local expertise_level
	local favorite_known = false
	local favorited = false

	if type(Items) == "table" and type(Items.expertise_level) == "function" then
		local ok, value = pcall(Items.expertise_level, item, true)

		expertise_level = ok and tonumber(value) or nil
	end

	if type(Items) == "table" and type(Items.is_item_id_favorited) == "function" then
		local ok, value = pcall(Items.is_item_id_favorited, gear_id)

		favorite_known = ok
		favorited = ok and value == true or false
	end

	local function summarize_traits(source)
		local result = {}

		for index, trait in ipairs(type(source) == "table" and source or {}) do
			result[#result + 1] = {
				id = safe_member(trait, "id") or safe_member(trait, "name") or safe_member(trait, "trait"),
				index = index,
				rarity = tonumber(safe_member(trait, "rarity") or safe_member(trait, "tier")),
			}
		end

		return result
	end

	local display_name

	if type(Items) == "table" and type(Items.weapon_card_display_name) == "function" then
		local ok, value = pcall(Items.weapon_card_display_name, item)

		if ok then
			display_name = value
		end
	end

	return {
		available = true,
		base_item_level = tonumber(safe_member(item, "baseItemLevel")),
		base_stat_labels = base_stat_labels,
		base_stats = stat_values,
		damage = damage_stat_value(stat_values, base_stat_labels) or item_stat_value(item, "damage"),
		display_name = display_name or safe_member(item, "name"),
		expertise_level = expertise_level,
		favorite_known = favorite_known,
		favorited = favorited,
		gear_id = gear_id,
		item_type = safe_member(item, "item_type"),
		master_id = safe_member(item, "name") or safe_member(item, "id"),
		name = safe_member(item, "name"),
		mastery_id = safe_member(item, "parent_pattern"),
		parent_pattern = safe_member(item, "parent_pattern"),
		potential_base_stats = potential_stat_values,
		potential_damage = damage_stat_value(potential_stat_values, base_stat_labels),
		perks = summarize_traits(safe_member(item, "perks")),
		rarity = tonumber(safe_member(item, "rarity")),
		traits = summarize_traits(safe_member(item, "traits")),
		weapon_template = safe_member(item, "weapon_progression_template") or safe_member(item, "weapon_template"),
	}
end

local function summarize_gear(gear, character_id)
	local protection = discard_protection_snapshot()
	local summary = {
		available = gear ~= nil,
		item_count = 0,
		items_by_id = {},
		raw_item_count = count_collection(gear),
		unavailable_item_count = 0,
		items = {},
	}

	if type(gear) ~= "table" then
		return summary
	end

	local added = 0

	for gear_id, raw_gear in pairs(gear) do
		local owner_id = safe_member(raw_gear, "characterId") or safe_member(raw_gear, "character_id")
		local belongs_to_character = owner_id == nil or character_id == nil or tostring(owner_id) == tostring(character_id)
		local resolved_gear_id = belongs_to_character and (safe_member(raw_gear, "uuid") or safe_member(raw_gear, "gear_id") or gear_id) or nil

		if resolved_gear_id ~= nil then
			local item = summarize_item(raw_gear, resolved_gear_id)
			item.equipped = protection ~= nil and protection.equipped[resolved_gear_id] == true
			item.equipped_known = protection ~= nil

			added = added + 1
			summary.items[added] = item
			summary.items_by_id[resolved_gear_id] = item

			if item.available ~= true then
				summary.unavailable_item_count = summary.unavailable_item_count + 1
			end
		end
	end

	summary.item_count = added
	summary.items.by_id = summary.items_by_id

	return summary
end

local function raw_gear_item(gear, gear_id)
	if type(gear) ~= "table" then
		return nil
	end

	local direct = gear[gear_id]

	if direct ~= nil then
		return direct
	end

	for key, raw_item in pairs(gear) do
		local resolved_id = safe_member(raw_item, "uuid") or safe_member(raw_item, "gear_id") or key

		if resolved_id == gear_id then
			return raw_item
		end
	end

	return nil
end

local function validate_trait_mutation_item(backend, kind, operation)
	local raw_item = raw_gear_item(backend and backend._raw_gear, operation.gear_id)
	local item = raw_item and item_instance(raw_item, operation.gear_id)

	if not item then
		return nil, kind .. " replacement item is unavailable in authoritative gear"
	end

	local recipes = safe_member(CraftingSettings, "recipes")
	local recipe = safe_member(recipes, kind == "perk" and "replace_perk" or "replace_trait")
	local is_valid_item = safe_member(recipe, "is_valid_item")

	if type(is_valid_item) ~= "function" then
		return nil, kind .. " replacement recipe validation is unavailable"
	end

	local recipe_ok, valid = pcall(is_valid_item, item)
	if not recipe_ok or valid ~= true then
		return nil, kind .. " replacement recipe rejected the authoritative item"
	end

	local source = kind == "perk" and safe_member(item, "perks") or safe_member(item, "traits")
	local current = type(source) == "table" and source[operation.index] or nil
	local peer = type(source) == "table" and source[operation.index == 1 and 2 or 1] or nil
	local current_id = safe_member(current, "id") or safe_member(current, "name") or safe_member(current, "trait")
	local peer_id = safe_member(peer, "id") or safe_member(peer, "name") or safe_member(peer, "trait")
	local current_tier = tonumber(safe_member(current, "rarity") or safe_member(current, "tier")) or 0

	if type(current) ~= "table" then
		return nil, kind .. " replacement slot is absent from the authoritative item"
	end
	if peer_id == operation.trait_id then
		return nil, kind .. " replacement would create a duplicate trait"
	end
	if current_id == operation.trait_id and current_tier >= operation.tier then
		return nil, kind .. " replacement is an invalid no-op or downgrade"
	end

	local maximum_ok, maximum = pcall(Items.max_expertise_level)
	local expertise_ok, expertise = pcall(Items.expertise_level, item, true)
	if not maximum_ok or not expertise_ok or tonumber(maximum) == nil or tonumber(expertise) == nil or tonumber(expertise) < tonumber(maximum) then
		return nil, kind .. " replacement was blocked until authoritative item level 500"
	end

	local target_ok, target_item = pcall(MasterItems.get_item, operation.trait_id)
	local target_type = target_ok and safe_member(target_item, "item_type") or nil
	local expected_type = kind == "perk" and "PERK" or "TRAIT"

	if target_type ~= nil and target_type ~= expected_type then
		return nil, kind .. " replacement target has incompatible item type " .. tostring(target_type)
	end

	return item
end

local function summarize_purchase(result)
	local items = safe_member(result, "items") or {}
	local summary = {
		available = type(items) == "table",
		item_count = 0,
		items = {},
		transaction_id = safe_member(result, "transactionId") or safe_member(result, "transaction_id"),
	}

	if type(items) ~= "table" then
		return summary
	end

	for index, item in ipairs(items) do
		local gear_id = safe_member(item, "uuid") or safe_member(item, "gear_id") or safe_member(item, "gearId")

		if gear_id ~= nil then
			summary.item_count = summary.item_count + 1
			summary.items[summary.item_count] = summarize_item(item, gear_id)
		end
	end

	return summary
end

local function summarize_extraction(result)
	local details = safe_member(result, "details")
	local amounts = safe_member(details, "amounts") or {}
	local amount = tonumber(safe_member(result, "amount"))

	if amount == nil and type(amounts) == "table" then
		for _, value in pairs(amounts) do
			amount = tonumber(value)

			if amount ~= nil then
				break
			end
		end
	end

	local gear_ids = safe_member(result, "gear_ids") or safe_member(result, "gearIds") or {}

	return {
		amount = amount or 0,
		gear_ids = gear_ids,
	}
end

function Backend.new(dependencies)
	dependencies = dependencies or {}

	local backend = {
		_mutation_guard = dependencies.mutation_guard,
		_purchase_wallets = {},
		_raw_gear = {},
		_services = dependencies.services,
	}

	function backend:_services_now()
		if self._services then
			return self._services
		end

		local managers = rawget(_G, "Managers")

		return managers and managers.data_service
	end

	function backend:release_read_cache()
		-- The native gear service owns its authoritative cache. BetterInventory only
		-- needs this full response while validating/dispatching a workflow mutation.
		self._raw_gear = {}
		self._purchase_wallets = {}

		return true
	end

	function backend:_read(service_name, method_name, ...)
		local services = self:_services_now()
		local service = services and services[service_name]

		return call_service(service, method_name, ...)
	end

	function backend:_mutate(service_name, method_name, ...)
		local services = self:_services_now()
		local service = services and services[service_name]
		local arguments = pack_values(...)
		local function invoke()
			return call_service(service, method_name, unpack_values(arguments, 1, arguments.n))
		end
		local with_owned_call = self._mutation_guard and self._mutation_guard.with_owned_call

		if type(with_owned_call) == "function" then
			local ok, result = pcall(with_owned_call, invoke)

			return ok and promise_or_resolved(result) or rejected(result)
		end

		return invoke()
	end

	function backend:probe_snapshot()
		self._purchase_wallets = {}
		local character_id = current_character_id()
		local snapshot = {
			character_id = character_id,
			crafting_costs = {
				available = false,
				sacrifice_mastery = nil,
				weapon = nil,
			},
			kind = "read_only_brunt_probe",
			store = nil,
			wallets = nil,
			gear = nil,
			mastery = {
				status = "deferred",
				reason = "No weapon-family target selected in Phase 0.",
			},
		}
		snapshot.crafting_costs.weapon = local_weapon_crafting_costs()
		snapshot.crafting_costs.sacrifice_mastery = local_sacrifice_mastery_costs()
		snapshot.crafting_costs.available = snapshot.crafting_costs.weapon ~= nil

		return self:_read("store", "get_credits_goods_store", true):next(function (store)
			snapshot.store = summarize_store(store)

			return self:_read("store", "combined_wallets")
		end):next(function (wallets)
			snapshot.wallets = summarize_wallets(wallets)

			return self:_read("gear", "fetch_gear")
		end):next(function (gear)
			self._raw_gear = gear or {}
			snapshot.gear = summarize_gear(gear, character_id)

			return snapshot
		end)
	end

	local function inherited_snapshot(previous)
		local snapshot = {}

		for key, value in pairs(type(previous) == "table" and previous or {}) do
			snapshot[key] = value
		end

		return snapshot
	end

	function backend:refresh_gear_snapshot(previous)
		local snapshot = inherited_snapshot(previous)
		local character_id = current_character_id()
		snapshot.character_id = character_id

		return self:_read("gear", "fetch_gear"):next(function (gear)
			self._raw_gear = gear or {}
			snapshot.gear = summarize_gear(gear, character_id)

			return snapshot
		end)
	end

	function backend:refresh_runtime_snapshot(previous)
		self._purchase_wallets = {}
		local snapshot = inherited_snapshot(previous)
		local character_id = current_character_id()
		snapshot.character_id = character_id

		-- Keep reads serial by default. The frozen Brunt catalogue and local cost
		-- tables are inherited; only mutable wallet and gear state are reconciled.
		return self:_read("store", "combined_wallets"):next(function (wallets)
			snapshot.wallets = summarize_wallets(wallets)

			return self:_read("gear", "fetch_gear")
		end):next(function (gear)
			self._raw_gear = gear or {}
			snapshot.gear = summarize_gear(gear, character_id)

			return snapshot
		end)
	end

	function backend:purchase_offer(offer)
		if not offer then
			return rejected("purchase offer unavailable")
		end

		local services = self:_services_now()
		local store_service = services and services.store
		local price = safe_member(offer, "price")
		local amount = safe_member(price, "amount")
		local wallet_type = safe_member(amount, "type")

		if not store_service or wallet_type == nil then
			return rejected("purchase wallet unavailable")
		end

		local function fresh_purchase(retried)
			local wallet_method = (wallet_type == "credits" or wallet_type == "marks") and "combined_wallets" or "account_wallets"
			local cached = self._purchase_wallets[wallet_type]
			local wallet_promise = cached and Promise.resolved(cached) or call_service(store_service, wallet_method):next(function (wallets)
				local by_type = safe_member(wallets, "by_type")
				local wallet

				if type(by_type) == "function" then
					local wallet_ok, resolved_wallet = pcall(by_type, wallets, wallet_type)

					wallet = wallet_ok and resolved_wallet or nil
				end

				if not wallet then
					return rejected("purchase wallet unavailable: " .. tostring(wallet_type))
				end

				local entry = {
					wallet = wallet,
					wallets = wallets,
				}
				self._purchase_wallets[wallet_type] = entry

				return entry
			end)

			-- Offer.make_purchase mutates this wallet's balance and transaction id after
			-- each successful POST. Reusing that exact object keeps the serial chain fast
			-- and correct; mismatch fallback below performs one forced authoritative read.
			return wallet_promise:next(function (entry)
				local arguments = pack_values(offer, entry.wallet)
				local function purchase()
					return call_service(store_service, "purchase_item_with_wallet", unpack_values(arguments, 1, arguments.n))
				end
				local with_owned_call = self._mutation_guard and self._mutation_guard.with_owned_call
				local purchase_promise

				if type(with_owned_call) == "function" then
					local purchase_ok, result = pcall(with_owned_call, purchase)
					purchase_promise = purchase_ok and promise_or_resolved(result) or rejected(result)
				else
					purchase_promise = purchase()
				end

				return purchase_promise:next(function (result)
					if type(result) == "table" then
						result._auto_crafter_wallets = summarize_wallets(entry.wallets)
					end

					return result
				end)
			end):catch(function (error_value)
				self._purchase_wallets[wallet_type] = nil
				local invalidate = safe_member(store_service, "invalidate_wallets_cache")

				if type(invalidate) == "function" then
					pcall(invalidate, store_service)
				end

				-- A transaction-id mismatch is a confirmed rejection before item creation,
				-- so one fresh-wallet retry is safe. Never retry ambiguous failures.
				if not retried and transaction_id_mismatch(error_value) then
					return fresh_purchase(true)
				end

				return Promise.rejected(error_value)
			end)
		end

		return fresh_purchase(false):next(function (result)
			for _, raw_item in ipairs(type(result) == "table" and type(result.items) == "table" and result.items or {}) do
				local gear_id = safe_member(raw_item, "uuid") or safe_member(raw_item, "gear_id") or safe_member(raw_item, "gearId")

				if gear_id ~= nil then
					self._raw_gear[gear_id] = raw_item
				end
			end

			local summary = summarize_purchase(result)

			summary.wallets = safe_member(result, "_auto_crafter_wallets")

			return summary
		end)
	end

	function backend:favorite_item(gear_id)
		if not nonempty_string(gear_id) then
			return rejected("gear id unavailable for favorite")
		end

		if type(Items) ~= "table" or type(Items.is_item_id_favorited) ~= "function" or type(Items.set_item_id_as_favorite) ~= "function" then
			return rejected("favorite item API unavailable")
		end

		local query_ok, already_favorited = pcall(Items.is_item_id_favorited, gear_id)

		if query_ok and already_favorited == true then
			return Promise.resolved({
				already_favorited = true,
				favorited = true,
				gear_id = gear_id,
			})
		end

		local function set_favorite()
			return Items.set_item_id_as_favorite(gear_id, true)
		end
		local with_owned_call = self._mutation_guard and self._mutation_guard.with_owned_call
		local set_ok, set_error

		if type(with_owned_call) == "function" then
			set_ok, set_error = pcall(with_owned_call, set_favorite)
		else
			set_ok, set_error = pcall(set_favorite)
		end

		if not set_ok then
			return rejected(set_error)
		end

		local verify_ok, favorited = pcall(Items.is_item_id_favorited, gear_id)

		if not verify_ok or favorited ~= true then
			return rejected("favorite state was not confirmed")
		end

		return Promise.resolved({
			favorited = true,
			gear_id = gear_id,
		})
	end

	function backend:discard_items(gear_ids)
		local normalized, normalization_error = normalized_gear_ids(gear_ids, "discard")
		if not normalized then
			return rejected(normalization_error)
		end

		local protection, protection_error = discard_protection_snapshot()

		if not protection then
			return rejected(protection_error)
		end

		local validated = {}

		for _, gear_id in ipairs(normalized) do
			if protection.favorites[gear_id] == true then
				return rejected("queued weapon became favorited before discard")
			end

			if protection.equipped[gear_id] == true then
				return rejected("queued weapon became equipped or used by a saved loadout")
			end

			validated[#validated + 1] = gear_id
		end

		return self:_mutate("gear", "delete_gear_batch", validated)
	end

	function backend:upgrade_weapon_rarity(gear_id)
		if not nonempty_string(gear_id) then
			return rejected("gear id unavailable for rarity upgrade")
		end

		local raw_item = raw_gear_item(self._raw_gear, gear_id)
		local local_item = raw_item and item_instance(raw_item, gear_id)
		local recipes = safe_member(CraftingSettings, "recipes")
		local recipe = safe_member(recipes, "upgrade_item")
		local is_valid_item = safe_member(recipe, "is_valid_item")
		local get_costs = safe_member(recipe, "get_costs")

		if not local_item then
			return rejected("rarity upgrade item unavailable in authoritative gear: " .. tostring(gear_id))
		end

		if type(is_valid_item) ~= "function" or type(get_costs) ~= "function" then
			return rejected("rarity upgrade recipe unavailable for gear: " .. tostring(gear_id))
		end

		local valid_ok, valid = pcall(is_valid_item, local_item)

		if not valid_ok or valid ~= true then
			return rejected("rarity upgrade recipe rejected gear: " .. tostring(gear_id))
		end

		local costs_ok, costs = pcall(get_costs, {
			item = local_item,
		})

		if not costs_ok or type(costs) ~= "table" then
			return rejected("rarity upgrade costs unavailable for gear: " .. tostring(gear_id))
		end

		return self:_mutate("crafting", "upgrade_weapon_rarity", gear_id, costs):catch(function (error_value)
			return Promise.rejected({
				code = safe_member(error_value, "code") or "rarity_upgrade_failed",
				description = string.format("rarity upgrade failed for gear %s: %s", tostring(gear_id), error_description(error_value)),
			})
		end)
	end

	function backend:upgrade_weapon_rarities(gear_ids)
		local normalized, normalization_error = normalized_gear_ids(gear_ids, "rarity upgrade batch")
		if not normalized then
			return rejected(normalization_error)
		end

		local results = {}
		local sequence = Promise.resolved(results)

		for _, gear_id in ipairs(normalized) do
			local pending_gear_id = gear_id
			sequence = sequence:next(function ()
				return self:upgrade_weapon_rarity(pending_gear_id):next(function (result)
					results[#results + 1] = result

					return results
				end)
			end)
		end

		-- Crafting requests share backend material/cache state. Keep them ordered;
		-- the controller may still overlap this lane with one Credits purchase.
		return sequence:next(function ()
			return {
				count = #normalized,
				results = results,
			}
		end)
	end

	function backend:add_weapon_expertise(gear_id, displayed_target)
		local target = finite_number(displayed_target)
		if not nonempty_string(gear_id) or not target or target <= 0 or target ~= math.floor(target) then
			return rejected("gear id or expertise target unavailable")
		end

		if type(Items) ~= "table" or type(Items.get_expertise_multiplier) ~= "function" then
			return rejected("expertise multiplier unavailable")
		end

		local ok, multiplier = pcall(Items.get_expertise_multiplier)

		if not ok or tonumber(multiplier) == nil or tonumber(multiplier) <= 0 then
			return rejected("expertise multiplier invalid")
		end

		local maximum_ok, maximum = pcall(Items.max_expertise_level)
		if maximum_ok and tonumber(maximum) and target > tonumber(maximum) then
			return rejected("expertise target exceeds Darktide's supported maximum")
		end

		return self:_mutate("crafting", "add_weapon_expertise", gear_id, target / tonumber(multiplier))
	end

	function backend:replace_perk(gear_id, index, perk_id, tier)
		local operation, validation_error = normalized_trait_mutation("perk", gear_id, index, perk_id, tier)

		if not operation then
			return rejected(validation_error)
		end
		local _, item_error = validate_trait_mutation_item(self, "perk", operation)
		if item_error then
			return rejected(item_error)
		end

		-- Darktide's CraftingService perk signature is intentionally asymmetric:
		-- (gear, slot, perk, costs, tier). Never leave a nil hole before tier because
		-- third-party/older hook dispatchers can truncate varargs at that hole and
		-- submit replaceTrait without traitTier. `false` preserves arity while keeping
		-- StoreService.on_crafting_done on its no-cost immediate-resolve path; an empty
		-- table would trigger an unnecessary wallet-cap request after mutation.
		return self:_mutate("crafting", "replace_perk_in_weapon", operation.gear_id, operation.index, operation.trait_id, false, operation.tier)
			:next(confirmed_trait_mutation("perk", operation))
	end

	function backend:replace_blessing(gear_id, index, blessing_id, tier)
		local operation, validation_error = normalized_trait_mutation("blessing", gear_id, index, blessing_id, tier)

		if not operation then
			return rejected(validation_error)
		end
		local _, item_error = validate_trait_mutation_item(self, "blessing", operation)
		if item_error then
			return rejected(item_error)
		end

		return self:_mutate("crafting", "replace_trait_in_weapon", operation.gear_id, operation.index, operation.trait_id, operation.tier)
			:next(confirmed_trait_mutation("blessing", operation))
	end

	function backend:purchase_mastery_trait(pattern_id, trait_id, tier)
		local operation, validation_error = normalized_mastery_trait(trait_id, tier)
		if not nonempty_string(pattern_id) or not operation then
			return rejected(validation_error or "mastery pattern id is invalid")
		end

		-- Follow vanilla MasteryView. purchase_trait() swallows a rejected PUT into
		-- a resolved error value; purchase_traits() returns explicit failed entries
		-- and resets/warms the sticker-book cache after its serialized batch.
		return self:_mutate("mastery", "purchase_traits", pattern_id, { operation }):next(function (failed_traits)
			if type(failed_traits) ~= "table" then
				return rejected("mastery blessing allocation returned an invalid result")
			end

			if next(failed_traits) ~= nil then
				return rejected(string.format("mastery blessing allocation was rejected by the backend (%s Tier %s); its tier may still be locked by mastery-tree spend requirements", tostring(trait_id), tostring(tier)))
			end

			return {
				rarity = tonumber(tier),
				submitted = true,
				trait_id = trait_id,
			}
		end)
	end

	function backend:purchase_mastery_traits(pattern_id, requested_operations)
		if not nonempty_string(pattern_id) or type(requested_operations) ~= "table" or #requested_operations == 0 then
			return rejected("mastery trait batch parameters unavailable")
		end

		local operations = {}
		local unique = {}

		for index, requested in ipairs(requested_operations) do
			local trait_id = requested and requested.trait_id
			local operation, validation_error = normalized_mastery_trait(trait_id, requested and requested.rarity)
			local key = operation and operation.trait_name .. ":" .. tostring(operation.rarity)

			if not operation or unique[key] then
				return rejected(validation_error or "mastery trait batch contains a duplicate operation")
			end

			unique[key] = true
			operations[index] = operation
		end

		-- MasteryService.purchase_traits performs these operations recursively and
		-- serially at backend-response speed, then resets the sticker-book cache once.
		return self:_mutate("mastery", "purchase_traits", pattern_id, operations):next(function (failed_traits)
			if type(failed_traits) ~= "table" then
				return rejected("mastery blessing batch returned an invalid result")
			end

			if next(failed_traits) ~= nil then
				return rejected(string.format("mastery blessing batch rejected %s of %s operations", tostring(#failed_traits), tostring(#operations)))
			end

			return {
				count = #operations,
				submitted = true,
			}
		end)
	end

	function backend:get_mastery_trait_costs()
		return self:_read("crafting", "get_traits_mastery_costs"):next(function (costs)
			if type(costs) ~= "table" then
				return {
					tier_costs = {},
					tier_thresholds = {},
				}
			end

			return {
				tier_costs = type(costs.tierCosts) == "table" and costs.tierCosts or type(costs.tier_costs) == "table" and costs.tier_costs or {},
				tier_thresholds = type(costs.tierThresholds) == "table" and costs.tierThresholds or type(costs.tier_thresholds) == "table" and costs.tier_thresholds or {},
			}
		end)
	end

	function backend:get_trait_sticker_book(trait_category, force_refresh)
		if trait_category == nil then
			return rejected("trait category unavailable")
		end

		local function read_sticker_book()
			return self:_read("crafting", "trait_sticker_book", trait_category):next(function (sticker_book)
				return summarize_blessing_catalog(sticker_book)
			end)
		end

		if force_refresh == true then
			return self:_mutate("crafting", "reset_sticker_book"):next(read_sticker_book)
		end

		return read_sticker_book()
	end

	function backend:extract_weapon_mastery(mastery_id, gear_ids)
		local normalized, normalization_error = normalized_gear_ids(gear_ids, "mastery extraction")
		if not nonempty_string(mastery_id) or not normalized then
			return rejected(normalization_error or "mastery extraction pattern id is invalid")
		end

		return self:_mutate("crafting", "extract_weapon_mastery", mastery_id, normalized):next(function (result)
			return summarize_extraction(result)
		end)
	end

	function backend:project_mastery(mastery_data, added_xp)
		if type(mastery_data) ~= "table" or type(Mastery) ~= "table" or type(Mastery.get_level_by_xp) ~= "function" then
			return nil
		end

		local projected = {}

		for key, value in pairs(mastery_data) do
			projected[key] = value
		end

		projected.current_xp = (tonumber(mastery_data.current_xp) or 0) + (tonumber(added_xp) or 0)
		projected.mastery_level = Mastery.get_level_by_xp(projected, projected.current_xp)

		return projected
	end

	function backend:get_mastery_by_pattern(pattern_id)
		if pattern_id == nil then
			return rejected("mastery pattern unavailable")
		end

		return self:_read("mastery", "get_mastery_by_pattern", pattern_id)
	end

	function backend:claim_mastery_levels(mastery_data, added_xp)
		if type(mastery_data) ~= "table" then
			return rejected("mastery data unavailable for tier claim")
		end

		return self:_mutate("mastery", "claim_levels_by_new_exp", mastery_data, added_xp)
	end

	function backend:discover_weapon_catalog(offer)
		if type(offer) ~= "table" or offer.master_id == nil then
			return rejected("selected weapon master item unavailable for trait discovery")
		end

		if type(MasterItems) ~= "table" or type(MasterItems.get_item) ~= "function" then
			return rejected("master item service unavailable for trait discovery")
		end

		local item_ok, master_item = pcall(MasterItems.get_item, offer.master_id)

		if not item_ok or not master_item then
			return rejected("selected weapon master item could not be resolved")
		end

		local item_name = safe_member(master_item, "name") or offer.master_id
		local parent_pattern = offer.parent_pattern or safe_member(master_item, "parent_pattern")
		local category_ok, trait_category = pcall(Items.trait_category, master_item)

		if not category_ok or trait_category == nil then
			return rejected("selected weapon trait category unavailable")
		end

		return self:_read("crafting", "get_item_crafting_metadata", item_name):next(function (metadata)
			return self:_read("mastery", "get_mastery_by_pattern", parent_pattern):next(function (mastery_data)
				return self:_read("crafting", "trait_sticker_book", trait_category):next(function (sticker_book)
					local perks = summarize_perk_catalog(metadata)
					local blessings = summarize_blessing_catalog(sticker_book)

					return {
						available = true,
						blessing_count = #blessings,
						blessings = blessings,
						item_name = item_name,
						mastery = {
							claimed_level = tonumber(safe_member(mastery_data, "claimed_level")),
							current_xp = tonumber(safe_member(mastery_data, "current_xp")),
							milestones = safe_member(mastery_data, "milestones"),
							mastery_id = safe_member(mastery_data, "mastery_id") or parent_pattern,
							mastery_level = tonumber(safe_member(mastery_data, "mastery_level")),
						},
						parent_pattern = parent_pattern,
						perk_count = #perks,
						perks = perks,
						trait_category = trait_category,
					}
				end)
			end)
		end)
	end

	return backend
end

return Backend
