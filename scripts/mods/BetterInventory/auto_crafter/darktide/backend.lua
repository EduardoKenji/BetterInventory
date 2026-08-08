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
			local sku = safe_member(offer, "sku")

			summary.offers[index] = {
				display_name = details.display_name,
				offer_id = safe_member(offer, "offerId") or safe_member(offer, "offer_id"),
				master_id = master_id,
				parent_pattern = details.parent_pattern,
				price_type = safe_member(amount, "type"),
				price_amount = tonumber(safe_member(amount, "discounted_price") or safe_member(amount, "amount")),
				sku_category = safe_member(sku, "category"),
				sub_display_name = details.sub_display_name,
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
		sub_display_name = sub_display_name,
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

local function summarize_gear(gear)
	return {
		available = gear ~= nil,
		item_count = count_collection(gear),
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

	return backend
end

return Backend
