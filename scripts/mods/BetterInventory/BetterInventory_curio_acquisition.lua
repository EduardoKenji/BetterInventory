local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")
local Promise = require("scripts/foundation/utilities/promise")
local StoreNames = require("scripts/settings/backend/store_names")

local CurioAcquisition = {}

local MORNINGSTAR_DELAY = 6
local MAX_SCAN_ATTEMPTS = 3
local RETRY_DELAY = 5

local PRIMARY_TRAITS = {
	gadget_innate_health_increase = {
		setting_id = "automatic_curio_buy_health",
		label_id = "automatic_curio_health",
		unit = "%",
	},
	gadget_innate_toughness_increase = {
		setting_id = "automatic_curio_buy_toughness",
		label_id = "automatic_curio_toughness",
		unit = "%",
	},
	gadget_innate_max_wounds_increase = {
		setting_id = "automatic_curio_buy_wounds",
		label_id = "automatic_curio_wounds",
		unit = "",
	},
	gadget_stamina_increase = {
		setting_id = "automatic_curio_buy_stamina",
		label_id = "automatic_curio_stamina",
		unit = "",
	},
}

local ARCHETYPE_SETTINGS = {
	adamant = "automatic_curio_class_adamant",
	broker = "automatic_curio_class_broker",
	cryptic = "automatic_curio_class_cryptic",
	ogryn = "automatic_curio_class_ogryn",
	psyker = "automatic_curio_class_psyker",
	veteran = "automatic_curio_class_veteran",
	zealot = "automatic_curio_class_zealot",
}

local state = {
	completed = false,
	elapsed = 0,
	hub_character_id = nil,
	scan_attempts = 0,
	scheduled = false,
	started = false,
	token = 0,
}
local processed_offer_keys = {}

local function log_info(mod, message)
	if mod and type(mod.info) == "function" then
		mod:info("[Automatic Curio Buyer] " .. message)
	end
end

local function new_scan_diagnostics()
	return {
		curios = 0,
		enabled_profiles = 0,
		eligible = 0,
		exclusions = {},
		offers = 0,
		profiles = 0,
		storefronts = 0,
	}
end

local function count_exclusion(diagnostics, reason)
	if diagnostics and reason then
		local exclusions = diagnostics.exclusions

		exclusions[reason] = (exclusions[reason] or 0) + 1
	end
end

local function exclusion_summary(exclusions)
	local entries = {}

	for reason, count in pairs(exclusions or {}) do
		entries[#entries + 1] = string.format("%s=%d", reason, count)
	end

	table.sort(entries)

	return #entries > 0 and table.concat(entries, ", ") or "none"
end

local function log_scan_summary(mod, diagnostics)
	log_info(mod, string.format(
		"Scan diagnostics: profiles=%d, enabled_profiles=%d, storefronts=%d, offers=%d, Curios=%d, eligible=%d; Curio exclusions: %s.",
		diagnostics.profiles,
		diagnostics.enabled_profiles,
		diagnostics.storefronts,
		diagnostics.offers,
		diagnostics.curios,
		diagnostics.eligible,
		exclusion_summary(diagnostics.exclusions)
	))
end

local function error_text(error_value)
	if type(error_value) == "table" then
		local message = error_value.message or error_value.error or error_value[1]

		if message then
			return tostring(message)
		elseif type(table.tostring) == "function" then
			return table.tostring(error_value, 2)
		end
	end

	return tostring(error_value)
end

local function enabled(mod)
	return mod:get("enable_automatic_curio_acquisition") == true
end

local function current_game_mode_name()
	local managers = Managers
	local game_mode = managers and managers.state and managers.state.game_mode

	if not game_mode or type(game_mode.game_mode_name) ~= "function" then
		return
	end

	local success, name = pcall(game_mode.game_mode_name, game_mode)

	return success and name or nil
end

local function is_morningstar()
	local name = current_game_mode_name()

	return name == "hub" or name == "hub_singleplay"
end

local function current_character_id()
	local player_manager = Managers and Managers.player
	local player

	if player_manager and type(player_manager.local_player) == "function" then
		local success, value = pcall(player_manager.local_player, player_manager, 1)

		player = success and value or nil
	end

	if not player or player.__deleted or type(player.character_id) ~= "function" then
		return
	end

	local success, character_id = pcall(player.character_id, player)

	return success and character_id or nil
end

local function backend_ready()
	local backend = Managers and Managers.backend
	local data_service = Managers and Managers.data_service

	if not backend or type(backend.authenticated) ~= "function" then
		return false
	end

	local authenticated, value = pcall(backend.authenticated, backend)

	if not authenticated or not value then
		return false
	end

	return type(backend.interfaces) == "table" and type(backend.interfaces.store) == "table" and type(backend.interfaces.wallet) == "table" and data_service and data_service.profiles and data_service.store
end

local function application_time()
	if Application and type(Application.time_since_launch) == "function" then
		local success, value = pcall(Application.time_since_launch)

		if success and type(value) == "number" then
			return value
		end
	end

	return 0
end

local function server_time()
	local backend = Managers and Managers.backend

	if backend and type(backend.get_server_time) == "function" then
		local success, value = pcall(backend.get_server_time, backend, application_time())

		if success and type(value) == "number" then
			return value
		end
	end
end

local function compatible_promise(value)
	return value and type(value.next) == "function" and type(value.catch) == "function"
end

local function rejected(reason)
	return Promise.rejected(reason)
end

local function call_promise(object, method, ...)
	if type(object) ~= "table" or type(method) ~= "function" then
		return rejected("required backend method is unavailable")
	end

	local success, result = pcall(method, object, ...)

	if not success then
		return rejected(result)
	end

	if not compatible_promise(result) then
		return rejected("backend method returned no compatible promise")
	end

	return result
end

local function context_is_current(mod, token)
	return state.token == token and enabled(mod) and is_morningstar()
end

local function archetype_name(profile)
	local archetype = profile and profile.archetype
	local name = type(archetype) == "table" and archetype.name or nil

	return type(name) == "string" and name or nil
end

local function class_is_enabled(mod, profile)
	local name = archetype_name(profile)
	local setting_id = name and ARCHETYPE_SETTINGS[name]

	return setting_id and mod:get(setting_id) ~= false or false
end

local function localized_class_name(profile)
	local archetype = profile and profile.archetype
	local localization_id = type(archetype) == "table" and archetype.archetype_name or nil

	if type(localization_id) == "string" and type(Localize) == "function" then
		local success, name = pcall(Localize, localization_id)

		if success and type(name) == "string" and name ~= "" and not string.find(name, "<", 1, true) then
			return name
		end
	end

	local name = archetype_name(profile)

	if name then
		return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
	end

	return "?"
end

local function first_number(value)
	if type(value) ~= "string" then
		return
	end

	-- Enhanced Descriptions and similar localization mods can wrap the visible
	-- value in numeric rich-text tags such as `{#color(192,255,26)}`. Those tag
	-- parameters must never be mistaken for the Curio's actual primary value.
	value = string.gsub(value, "{#[^}]*}", "")
	value = string.gsub(value, "<[^>]*>", "")

	local number = string.match(value, "([%d]+%.?[%d]*)")

	return number and tonumber(number) or nil
end

local function backend_trait_value(trait_name, entry)
	local value = entry and tonumber(entry.value)

	if not value then
		return
	end

	if (trait_name == "gadget_innate_health_increase" or trait_name == "gadget_innate_toughness_increase") and math.abs(value) <= 1 then
		value = value * 100
	end

	return math.floor(value * 100 + 0.5) / 100
end

local function trait_definition(entry)
	if type(entry) ~= "table" or not entry.id then
		return
	end

	if type(Items.perk_item_by_id) == "function" then
		local success, item = pcall(Items.perk_item_by_id, entry.id)

		if success and item then
			return item
		end
	end

	if type(MasterItems.get_item) == "function" then
		local success, item = pcall(MasterItems.get_item, entry.id)

		return success and item or nil
	end
end

local function primary_trait(item)
	local traits = item and item.traits

	if type(traits) ~= "table" then
		return
	end

	for index = 1, #traits do
		local entry = traits[index]
		local definition = trait_definition(entry)
		local trait_name = definition and definition.trait
		local config = trait_name and PRIMARY_TRAITS[trait_name]

		if config then
			local value = backend_trait_value(trait_name, entry)

			if type(Items.trait_description) == "function" then
				local described, description = pcall(Items.trait_description, definition, entry.rarity or 0, entry.value or 0)

				value = described and first_number(description) or value
			end

			-- Eligibility is based on the stable trait identifier, never localized
			-- presentation text. A missing value only affects notification detail.
			return trait_name, value, config
		end
	end
end

local function item_level(item)
	if not item or type(Items.expertise_level) ~= "function" then
		return
	end

	local success, level = pcall(Items.expertise_level, item, true)

	return success and tonumber(level) or nil
end

local function offer_is_active(offer)
	if not offer or type(offer) ~= "table" then
		return false
	end

	if type(offer.state) == "string" and offer.state ~= "active" then
		return false
	end

	if type(offer.is_valid_at) == "function" then
		local now = server_time()

		if now then
			local success, valid = pcall(offer.is_valid_at, offer, now)

			if not success or not valid then
				return false
			end
		end
	end

	return true
end

local function log_curio_evaluation(mod, profile, offer_id, level, trait_name, trait_value, result)
	log_info(mod, string.format(
		"%s Curio offer %s: item_level=%s, primary_trait=%s, primary_value=%s; %s.",
		localized_class_name(profile),
		tostring(offer_id or "?"),
		tostring(level or "?"),
		tostring(trait_name or "?"),
		tostring(trait_value or "?"),
		result
	))
end

local function normalized_offer(mod, profile, offer, diagnostics)
	local sku = offer and offer.sku
	local description = offer and offer.description
	local offer_id = offer and offer.offerId
	local price = offer and offer.price and offer.price.amount

	if diagnostics then
		diagnostics.offers = diagnostics.offers + 1
	end

	if not offer_is_active(offer) or not sku or sku.category ~= "item_instance" or type(description) ~= "table" or not offer_id or type(price) ~= "table" then
		return
	end

	local resolved, item = pcall(MasterItems.get_store_item_instance, description)

	if not resolved or not item or item.item_type ~= "GADGET" then
		return
	end

	if diagnostics then
		diagnostics.curios = diagnostics.curios + 1
	end

	local level = item_level(item)
	local minimum_level = math.clamp(math.floor(tonumber(mod:get("automatic_curio_min_item_level")) or 410), 0, 500)

	if not level then
		count_exclusion(diagnostics, "unreadable_item_level")

		if diagnostics then
			log_curio_evaluation(mod, profile, offer_id, level, nil, nil, "excluded: unreadable item level")
		end

		return
	elseif level < minimum_level then
		count_exclusion(diagnostics, "below_minimum_level")

		if diagnostics then
			log_curio_evaluation(mod, profile, offer_id, level, nil, nil, "excluded: below configured minimum " .. tostring(minimum_level))
		end

		return
	end

	local trait_name, trait_value, trait_config = primary_trait(item)

	if not trait_name or not trait_config then
		count_exclusion(diagnostics, "unsupported_primary_trait")

		if diagnostics then
			log_curio_evaluation(mod, profile, offer_id, level, trait_name, trait_value, "excluded: unsupported or unreadable primary trait")
		end

		return
	elseif mod:get(trait_config.setting_id) == false then
		count_exclusion(diagnostics, "primary_type_disabled")

		if diagnostics then
			log_curio_evaluation(mod, profile, offer_id, level, trait_name, trait_value, "excluded: primary type disabled")
		end

		return
	end

	local amount = tonumber(price.amount)
	local currency = price.type

	if not amount or amount < 0 or type(currency) ~= "string" then
		count_exclusion(diagnostics, "invalid_price")

		if diagnostics then
			log_curio_evaluation(mod, profile, offer_id, level, trait_name, trait_value, "excluded: invalid price")
		end

		return
	end

	if diagnostics then
		diagnostics.eligible = diagnostics.eligible + 1
		log_curio_evaluation(mod, profile, offer_id, level, trait_name, trait_value, string.format("eligible at %s %s", tostring(amount), currency))
	end

	return {
		archetype = archetype_name(profile),
		character_id = profile.character_id,
		class_name = localized_class_name(profile),
		currency = currency,
		gear_id = description.gear_id or description.gearId,
		item_level = math.floor(level + 0.5),
		offer = offer,
		offer_id = offer_id,
		price = amount,
		primary_config = trait_config,
		primary_trait = trait_name,
		primary_value = trait_value,
		profile = profile,
	}
end

local function candidate_key(candidate)
	return table.concat({
		tostring(candidate.character_id or "?"),
		tostring(candidate.offer_id or "?"),
	}, ":")
end

local function store_method_for_profile(profile)
	local store_interface = Managers and Managers.backend and Managers.backend.interfaces and Managers.backend.interfaces.store
	local by_archetype = StoreNames and StoreNames.by_archetype and StoreNames.by_archetype.credit
	local method_name = by_archetype and by_archetype[archetype_name(profile)]
	local method = method_name and store_interface and store_interface[method_name]

	return store_interface, method
end

local function fetch_storefront(profile)
	local store_interface, method = store_method_for_profile(profile)

	if not method then
		return rejected("no Armoury storefront mapping for " .. tostring(archetype_name(profile)))
	end

	return call_promise(store_interface, method, application_time(), profile.character_id)
end

local function scan_candidates(mod, token)
	local profiles_service = Managers and Managers.data_service and Managers.data_service.profiles

	if not profiles_service or type(profiles_service.fetch_all_profiles) ~= "function" then
		return rejected("ProfilesService.fetch_all_profiles is unavailable")
	end

	return call_promise(profiles_service, profiles_service.fetch_all_profiles):next(function(result)
		if not context_is_current(mod, token) then
			return {}
		end

		local profiles = result and result.profiles

		if type(profiles) ~= "table" then
			return rejected("profile scan returned no profile list")
		end

		local candidates = {}
		local chain = Promise.resolved()
		local diagnostics = new_scan_diagnostics()

		diagnostics.profiles = #profiles

		for index = 1, #profiles do
			local profile = profiles[index]

			if profile and profile.character_id and class_is_enabled(mod, profile) then
				diagnostics.enabled_profiles = diagnostics.enabled_profiles + 1
				chain = chain:next(function()
					if not context_is_current(mod, token) then
						return
					end

					return fetch_storefront(profile):next(function(storefront)
						if not context_is_current(mod, token) then
							return
						end

						local offers = storefront and storefront.data and storefront.data.personal

						if type(offers) ~= "table" then
							return rejected("Armoury storefront returned no personal offers")
						end

						diagnostics.storefronts = diagnostics.storefronts + 1

						local offers_before = diagnostics.offers
						local curios_before = diagnostics.curios
						local eligible_before = diagnostics.eligible

						for offer_index = 1, #offers do
							local success, candidate = pcall(normalized_offer, mod, profile, offers[offer_index], diagnostics)

							if success and candidate and not processed_offer_keys[candidate_key(candidate)] then
								candidates[#candidates + 1] = candidate
							elseif not success then
								log_info(mod, "Safety-excluded an unreadable offer: " .. error_text(candidate))
							end
						end

						log_info(mod, string.format(
							"%s storefront summary: offers=%d, Curios=%d, eligible=%d.",
							localized_class_name(profile),
							diagnostics.offers - offers_before,
							diagnostics.curios - curios_before,
							diagnostics.eligible - eligible_before
						))
					end)
				end)
			end
		end

		return chain:next(function()
			log_scan_summary(mod, diagnostics)

			table.sort(candidates, function(left, right)
				if left.class_name ~= right.class_name then
					return left.class_name < right.class_name
				elseif left.item_level ~= right.item_level then
					return left.item_level > right.item_level
				end

				return tostring(left.offer_id) < tostring(right.offer_id)
			end)

			return candidates
		end)
	end)
end

local function find_offer(storefront, offer_id)
	local offers = storefront and storefront.data and storefront.data.personal

	if type(offers) ~= "table" then
		return
	end

	for index = 1, #offers do
		if offers[index] and offers[index].offerId == offer_id then
			return offers[index]
		end
	end
end

local STABLE_REVALIDATION_FIELDS = {
	"character_id",
	"offer_id",
	"currency",
	"price",
	"item_level",
	"primary_trait",
}

local VOLATILE_REVALIDATION_FIELDS = {
	"gear_id",
	"primary_value",
}

local function candidate_differences(left, right, fields)
	local differences = {}

	if not left or not right then
		return {"candidate_missing"}
	end

	for index = 1, #fields do
		local field = fields[index]

		if left[field] ~= right[field] then
			differences[#differences + 1] = string.format("%s:%s->%s", field, tostring(left[field]), tostring(right[field]))
		end
	end

	return differences
end

local function same_candidate(left, right)
	return #candidate_differences(left, right, STABLE_REVALIDATION_FIELDS) == 0
end

local function find_wallet(wallets, currency)
	if type(wallets) ~= "table" then
		return
	end

	for index = 1, #wallets do
		local wallet = wallets[index]
		local balance = wallet and wallet.balance

		if balance and balance.type == currency then
			return wallet
		end
	end
end

local function fetch_target_wallet(candidate)
	local wallet_interface = Managers and Managers.backend and Managers.backend.interfaces and Managers.backend.interfaces.wallet

	if not wallet_interface then
		return rejected("wallet backend is unavailable")
	end

	local account_promise = call_promise(wallet_interface, wallet_interface.account_wallets)

	if candidate.currency ~= "credits" and candidate.currency ~= "marks" then
		return account_promise:next(function(wallets)
			return find_wallet(wallets, candidate.currency)
		end)
	end

	local character_promise = call_promise(wallet_interface, wallet_interface.character_wallets, candidate.character_id)

	return Promise.all(account_promise, character_promise):next(function(results)
		local account_wallet = find_wallet(results and results[1], candidate.currency)
		local character_wallet = find_wallet(results and results[2], candidate.currency)
		local wallet = account_wallet or character_wallet

		if wallet == character_wallet and wallet and wallet.owner and tostring(wallet.owner) ~= tostring(candidate.character_id) then
			return rejected("target character wallet owner did not match the offer character")
		end

		return wallet
	end)
end

local function revalidate_and_purchase(mod, token, captured)
	if not context_is_current(mod, token) or not class_is_enabled(mod, captured.profile) then
		return Promise.resolved()
	end

	return fetch_storefront(captured.profile):next(function(storefront)
		if not context_is_current(mod, token) then
			return
		end

		local offer = find_offer(storefront, captured.offer_id)

		if not offer then
			log_info(mod, "Revalidation rejected offer " .. tostring(captured.offer_id) .. ": offer ID was no longer present in the target storefront.")
			return
		end

		local success, current = pcall(normalized_offer, mod, captured.profile, offer)

		if not success then
			return rejected(current)
		end

		if not current then
			log_info(mod, "Revalidation rejected offer " .. tostring(captured.offer_id) .. ": it no longer passed the current Curio filters or safety checks.")
			return
		end

		if not same_candidate(captured, current) then
			local differences = candidate_differences(captured, current, STABLE_REVALIDATION_FIELDS)

			log_info(mod, string.format(
				"Revalidation rejected offer %s because stable field(s) changed: %s.",
				tostring(captured.offer_id),
				table.concat(differences, ", ")
			))
			return
		end

		local volatile_differences = candidate_differences(captured, current, VOLATILE_REVALIDATION_FIELDS)

		if #volatile_differences > 0 then
			log_info(mod, string.format(
				"Revalidation accepted offer %s; non-transactional field(s) changed after refetch: %s.",
				tostring(captured.offer_id),
				table.concat(volatile_differences, ", ")
			))
		end

		local key = candidate_key(current)

		if processed_offer_keys[key] then
			return
		end

		return fetch_target_wallet(current):next(function(wallet)
			if not context_is_current(mod, token) then
				return
			end

			local balance = wallet and wallet.balance
			local available = balance and tonumber(balance.amount)

			if not wallet or not balance or balance.type ~= current.currency or not available then
				return rejected("matching target wallet was unavailable")
		end

			if available < current.price then
				log_info(mod, string.format("Skipped %s: %s balance was insufficient.", tostring(current.offer_id), current.currency))
				return
			end

			local store_service = Managers and Managers.data_service and Managers.data_service.store

			if not store_service or type(store_service.purchase_item_with_wallet) ~= "function" then
				return rejected("StoreService.purchase_item_with_wallet is unavailable")
			end

			processed_offer_keys[key] = "in_flight"

			return call_promise(store_service, store_service.purchase_item_with_wallet, current.offer, wallet):next(function(result)
				processed_offer_keys[key] = "complete"

				return current, result
			end):catch(function(error_value)
				-- A timeout can be ambiguous after the POST reaches the backend. Keep the
				-- session key blocked and never retry this offer automatically.
				processed_offer_keys[key] = "unknown"

				return rejected(error_value)
			end)
		end)
	end)
end

local function notify(mod, title_id, description)
	local event_manager = Managers and Managers.event

	if not event_manager or type(event_manager.trigger) ~= "function" then
		return
	end

	pcall(event_manager.trigger, event_manager, "event_add_notification_message", "custom", {
		line_1 = mod:localize(title_id),
		line_1_color = Color.terminal_text_header(255, true),
		line_2 = description,
		line_2_color = Color.white(255, true),
	})
end

local function purchased_lines(mod, purchased, partial_failure)
	local lines = {}

	for index = 1, #purchased do
		local candidate = purchased[index]
		local config = candidate.primary_config
		local value = tonumber(candidate.primary_value)
		local shown_value = value and (value == math.floor(value) and tostring(math.floor(value)) or tostring(value)) or "?"

		lines[#lines + 1] = string.format("- %d, %s%s %s, %s", candidate.item_level, shown_value, config.unit, mod:localize(config.label_id), candidate.class_name)
	end

	if partial_failure then
		lines[#lines + 1] = mod:localize("automatic_curio_partial_failure")
	end

	return table.concat(lines, "\n")
end

local function refresh_after_purchase()
	local store_service = Managers and Managers.data_service and Managers.data_service.store

	if store_service and type(store_service.invalidate_wallets_cache) == "function" then
		pcall(store_service.invalidate_wallets_cache, store_service)
	end

	local event_manager = Managers and Managers.event

	if event_manager and type(event_manager.trigger) == "function" then
		pcall(event_manager.trigger, event_manager, "event_force_wallet_update")
		pcall(event_manager.trigger, event_manager, "event_force_refresh_inventory")
	end
end

local function finish_pass()
	state.completed = true
	state.scheduled = false
	state.started = false
end

local function purchase_candidates(mod, token, candidates)
	local purchased = {}
	local chain = Promise.resolved()

	for index = 1, #candidates do
		local candidate = candidates[index]

		chain = chain:next(function()
			if not context_is_current(mod, token) then
				return
			end

			return revalidate_and_purchase(mod, token, candidate):next(function(result)
				if result then
					purchased[#purchased + 1] = result
				end
			end)
		end)
	end

	chain:next(function()
		if not context_is_current(mod, token) then
			-- A purchase POST cannot be cancelled once sent. If the user disables the
			-- feature, changes a filter, or leaves the hub while that request is in
			-- flight, still acknowledge every confirmed spend. The invalid token keeps
			-- the remaining queue inert and must not mutate the newer session state.
			if #purchased > 0 then
				refresh_after_purchase()
				notify(mod, "automatic_curio_purchased_title", purchased_lines(mod, purchased, false))
				log_info(mod, string.format("Reported %d Curio purchase(s) after the pass was cancelled.", #purchased))
			end

			return
		end

		finish_pass()

		if #purchased > 0 then
			refresh_after_purchase()
			notify(mod, "automatic_curio_purchased_title", purchased_lines(mod, purchased, false))
			log_info(mod, string.format("Purchased %d Curio(s).", #purchased))
		else
			notify(mod, "automatic_curio_none_title", mod:localize("automatic_curio_none_description"))
			log_info(mod, "No eligible Curios were available after final revalidation.")
		end
	end):catch(function(error_value)
		if not context_is_current(mod, token) then
			if #purchased > 0 then
				refresh_after_purchase()
				notify(mod, "automatic_curio_purchased_title", purchased_lines(mod, purchased, true))
				log_info(mod, string.format("Reported %d Curio purchase(s) after a cancelled pass encountered an error: %s", #purchased, error_text(error_value)))
			end

			return
		end

		finish_pass()
		refresh_after_purchase()

		if #purchased > 0 then
			notify(mod, "automatic_curio_purchased_title", purchased_lines(mod, purchased, true))
		else
			notify(mod, "automatic_curio_failed_title", mod:localize("automatic_curio_failed_description"))
		end

		log_info(mod, "Purchase queue stopped safely: " .. error_text(error_value))
	end)
end

local function schedule_scan_retry(mod, token, error_value)
	if not context_is_current(mod, token) then
		return
	end

	state.started = false
	state.elapsed = MORNINGSTAR_DELAY - RETRY_DELAY
	state.scheduled = state.scan_attempts < MAX_SCAN_ATTEMPTS

	if state.scheduled then
		log_info(mod, string.format("Scan attempt %d failed; scheduling a bounded retry: %s", state.scan_attempts, error_text(error_value)))
	else
		finish_pass()
		notify(mod, "automatic_curio_failed_title", mod:localize("automatic_curio_failed_description"))
		log_info(mod, "Scan failed after bounded retries: " .. error_text(error_value))
	end
end

local function start_scan(mod)
	local token = state.token

	state.started = true
	state.scan_attempts = state.scan_attempts + 1
	log_info(mod, string.format("Starting all-character Armoury scan attempt %d.", state.scan_attempts))

	scan_candidates(mod, token):next(function(candidates)
		if not context_is_current(mod, token) then
			return
		end

		state.scheduled = false

		if type(candidates) ~= "table" then
			return schedule_scan_retry(mod, token, "scan returned no candidate list")
		end

		log_info(mod, string.format("Scan found %d eligible Curio offer(s).", #candidates))

		if #candidates == 0 then
			finish_pass()
			notify(mod, "automatic_curio_none_title", mod:localize("automatic_curio_none_description"))
		else
			purchase_candidates(mod, token, candidates)
		end
	end):catch(function(error_value)
		schedule_scan_retry(mod, token, error_value)
	end)
end

CurioAcquisition.begin_morningstar_pass = function(mod)
	state.token = state.token + 1
	state.completed = false
	state.elapsed = 0
	state.hub_character_id = nil
	state.scan_attempts = 0
	state.scheduled = enabled(mod)
	state.started = false
	processed_offer_keys = {}
end

CurioAcquisition.cancel = function()
	state.token = state.token + 1
	state.completed = false
	state.elapsed = 0
	state.hub_character_id = nil
	state.scan_attempts = 0
	state.scheduled = false
	state.started = false
end

CurioAcquisition.on_setting_changed = function(mod, setting_id)
	if setting_id == "enable_automatic_curio_acquisition" then
		if enabled(mod) then
			-- Let the live Morningstar observer arm a fresh pass. This also handles
			-- enabling the feature without leaving and re-entering the hub.
			state.completed = false
			state.hub_character_id = nil
			state.scheduled = false
			state.started = false
			state.elapsed = 0
			state.scan_attempts = 0
			state.token = state.token + 1
		else
			CurioAcquisition.cancel()
		end
	elseif type(setting_id) == "string" and string.sub(setting_id, 1, 16) == "automatic_curio_" and state.started then
		-- Changing a destructive filter invalidates every captured offer. Do not
		-- re-run automatically in the same hub session after a partial transaction.
		state.token = state.token + 1
		state.completed = true
		state.scheduled = false
		state.started = false
	end
end

CurioAcquisition.update = function(mod, dt, automatic_discard_busy)
	if not enabled(mod) then
		if state.scheduled or state.started or state.hub_character_id then
			CurioAcquisition.cancel()
		end

		return
	end

	local game_mode_name = current_game_mode_name()

	if not game_mode_name then
		return
	end

	if not is_morningstar() then
		if state.scheduled or state.started or state.hub_character_id then
			CurioAcquisition.cancel()
		end

		return
	end

	local character_id = current_character_id()

	if not character_id then
		return
	end

	if not state.hub_character_id then
		state.token = state.token + 1
		state.completed = false
		state.elapsed = 0
		state.hub_character_id = character_id
		state.scan_attempts = 0
		state.scheduled = true
		state.started = false
		processed_offer_keys = {}
		log_info(mod, "Scheduled one all-character pass after detecting a ready Morningstar session.")
	end

	if state.completed or not state.scheduled or state.started or automatic_discard_busy then
		return
	end

	state.elapsed = state.elapsed + (tonumber(dt) or 0)

	if state.elapsed < MORNINGSTAR_DELAY or not backend_ready() then
		return
	end

	local progression_manager = Managers and Managers.progression

	if progression_manager and type(progression_manager.is_fetching_session_report) == "function" and progression_manager:is_fetching_session_report() then
		state.elapsed = 0
		return
	end

	start_scan(mod)
end

CurioAcquisition._test = {
	ARCHETYPE_SETTINGS = ARCHETYPE_SETTINGS,
	PRIMARY_TRAITS = PRIMARY_TRAITS,
	candidate_differences = candidate_differences,
	candidate_key = candidate_key,
	normalized_offer = normalized_offer,
	primary_trait = primary_trait,
	same_candidate = same_candidate,
}

return CurioAcquisition
