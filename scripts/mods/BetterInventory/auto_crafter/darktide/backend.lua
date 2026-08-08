local Promise = require("scripts/foundation/utilities/promise")
local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")

local Backend = {}

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

	local ok, value = pcall(function()
		return object[key]
	end)

	return ok and value or nil
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

local function offer_master_id(offer)
	local description = safe_member(offer, "description")
	local choices = safe_member(description, "lootChoices") or safe_member(description, "loot_choices")
	local choice = type(choices) == "table" and choices[1] or nil

	if type(choice) == "table" then
		return choice.masterId or choice.master_id or choice.id or choice.name
	end

	return choice or safe_member(description, "masterId") or safe_member(description, "master_id")
end

local master_item_details
local summarize_base_stats
local store_item_preview

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
			local details = master_item_details(master_id)
			local description = safe_member(offer, "description")
			local preview_item = store_item_preview(description)
			local base_stats = summarize_base_stats(preview_item) or summarize_base_stats(description)
			local parent_pattern = details.parent_pattern or safe_member(preview_item, "parent_pattern") or safe_member(description, "parent_pattern")
			local sku = safe_member(offer, "sku")

			summary.offers[index] = {
				base_stats = base_stats,
				display_name = details.display_name,
				offer_id = safe_member(offer, "offerId") or safe_member(offer, "offer_id"),
				master_id = master_id,
				parent_pattern = parent_pattern,
				price_type = safe_member(amount, "type"),
				price_amount = tonumber(safe_member(amount, "discounted_price") or safe_member(amount, "amount")),
				sku_category = safe_member(sku, "category"),
				slot_type = details.slot_type,
				sub_display_name = details.sub_display_name,
				weapon_category = details.weapon_category,
			}
		end
	end

	return summary
end

master_item_details = function(master_id)
	if master_id == nil or type(MasterItems) ~= "table" or type(MasterItems.get_item) ~= "function" then
		return {}
	end

	local ok, master_item = pcall(MasterItems.get_item, master_id)

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

summarize_base_stats = function(source)
	local base_stats = safe_member(source, "base_stats") or safe_member(source, "baseStats")

	if type(base_stats) ~= "table" then
		return nil
	end

	local summary = {}

	for key, stat in pairs(base_stats) do
		local name = safe_member(stat, "name") or safe_member(stat, "stat_name") or safe_member(stat, "statName")
		local value = safe_member(stat, "value")

		if name == nil and type(key) == "string" and type(stat) == "number" then
			name = key
			value = stat
		end

		local numeric_value = tonumber(value)

		if name ~= nil and numeric_value ~= nil then
			summary[#summary + 1] = {
				name = tostring(name),
				value = numeric_value,
			}
		end
	end

	return #summary > 0 and summary or nil
end

store_item_preview = function(description)
	if description == nil or type(MasterItems) ~= "table" or type(MasterItems.get_store_item_instance) ~= "function" then
		return nil
	end

	local ok, item = pcall(MasterItems.get_store_item_instance, description)

	return ok and item or nil
end

local function summarize_item(gear, gear_id)
	local item = item_instance(gear, gear_id)

	if not item then
		return {
			gear_id = gear_id,
			available = false,
		}
	end

	local base_stats = safe_member(item, "base_stats")
	local stat_values = {}

	if type(base_stats) == "table" then
		for _, stat in ipairs(base_stats) do
			local name = safe_member(stat, "name")
			local value = tonumber(safe_member(stat, "value"))

			if name and value ~= nil then
				stat_values[name] = value <= 1.01 and math.floor(value * 100 + 0.5) or math.floor(value + 0.5)
			end
		end
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
		base_stats = stat_values,
		damage = item_stat_value(item, "damage"),
		display_name = display_name or safe_member(item, "name"),
		gear_id = gear_id,
		item_type = safe_member(item, "item_type"),
		mastery_id = safe_member(item, "parent_pattern"),
		parent_pattern = safe_member(item, "parent_pattern"),
		rarity = tonumber(safe_member(item, "rarity")),
	}
end

local function summarize_gear(gear)
	local summary = {
		available = gear ~= nil,
		item_count = count_collection(gear),
		items = {},
	}

	if type(gear) ~= "table" then
		return summary
	end

	local added = 0

	for gear_id, raw_gear in pairs(gear) do
		if added >= 256 then
			break
		end

		local resolved_gear_id = safe_member(raw_gear, "uuid") or safe_member(raw_gear, "gear_id") or gear_id

		if resolved_gear_id ~= nil then
			added = added + 1
			summary.items[added] = summarize_item(raw_gear, resolved_gear_id)
		end
	end

	return summary
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
		_services = dependencies.services,
	}

	function backend:_services_now()
		if self._services then
			return self._services
		end

		local managers = rawget(_G, "Managers")

		return managers and managers.data_service
	end

	function backend:_read(service_name, method_name, ...)
		local services = self:_services_now()
		local service = services and services[service_name]

		return call_service(service, method_name, ...)
	end

	function backend:_mutate(service_name, method_name, ...)
		local services = self:_services_now()
		local service = services and services[service_name]

		return call_service(service, method_name, ...)
	end

	function backend:probe_snapshot()
		local snapshot = {
			kind = "read_only_brunt_probe",
			store = nil,
			wallets = nil,
			gear = nil,
			mastery = {
				status = "deferred",
				reason = "No weapon-family target selected in Phase 0.",
			},
		}

		return self:_read("store", "get_credits_goods_store", true):next(function (store)
			snapshot.store = summarize_store(store)

			return self:_read("store", "combined_wallets")
		end):next(function (wallets)
			snapshot.wallets = summarize_wallets(wallets)

			return self:_read("gear", "fetch_gear")
		end):next(function (gear)
			snapshot.gear = summarize_gear(gear)

			return snapshot
		end)
	end

	function backend:purchase_offer(offer)
		if not offer then
			return rejected("purchase offer unavailable")
		end

		return self:_mutate("store", "purchase_item", offer):next(function (result)
			return summarize_purchase(result)
		end)
	end

	function backend:upgrade_weapon_rarity(gear_id)
		if gear_id == nil then
			return rejected("gear id unavailable for rarity upgrade")
		end

		return self:_mutate("crafting", "upgrade_weapon_rarity", gear_id)
	end

	function backend:extract_weapon_mastery(mastery_id, gear_ids)
		if mastery_id == nil or type(gear_ids) ~= "table" or #gear_ids ~= 1 then
			return rejected("phase 2 requires exactly one mastery item")
		end

		return self:_mutate("crafting", "extract_weapon_mastery", mastery_id, gear_ids):next(function (result)
			return summarize_extraction(result)
		end)
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

	return backend
end

return Backend
