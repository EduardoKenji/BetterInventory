local Promise = require("scripts/foundation/utilities/promise")
local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")
local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")

local Backend = {}
local GEAR_SUMMARY_LIMIT = 1024

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
local merge_stat_catalog
local summarize_base_stats
local summarize_weapon_template_stats
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

			summary.offers[index] = {
				base_item_level = tonumber(safe_member(preview_item, "baseItemLevel") or safe_member(description, "baseItemLevel")),
				base_stats = base_stats,
				display_name = details.display_name,
				offer_id = safe_member(offer, "offerId") or safe_member(offer, "offer_id"),
				master_id = master_id,
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

	return safe_member(value, "name") or safe_member(value, "id")
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

					catalog[#catalog + 1] = {
						display_name = display_name,
						display_name_key = trait_display_name_key(name, perk),
						id = tostring(name),
						tier = tier,
						trait = perk_item and safe_member(perk_item, "trait") or nil,
					}
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
		gear_id = gear_id,
		item_type = safe_member(item, "item_type"),
		master_id = safe_member(item, "name") or safe_member(item, "id"),
		name = safe_member(item, "name"),
		mastery_id = safe_member(item, "parent_pattern"),
		parent_pattern = safe_member(item, "parent_pattern"),
		rarity = tonumber(safe_member(item, "rarity")),
		weapon_template = safe_member(item, "weapon_progression_template") or safe_member(item, "weapon_template"),
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
		if added >= GEAR_SUMMARY_LIMIT then
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
