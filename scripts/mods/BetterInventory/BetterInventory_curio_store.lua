-- Curio storefront boundary and candidate-scan domain. Stateless by design:
-- snapshots/tokens/cancellation remain owned by the acquisition orchestrator.
local CurioStore = {}
local dependencies = {}

local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")
local Promise = require("scripts/foundation/utilities/promise")
local StoreNames = require("scripts/settings/backend/store_names")
local CurioValues = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_curio_values")

CurioStore.configure = function(options)
	dependencies = type(options) == "table" and options or {}
end

local function callback(name, ...)
	local fn = dependencies[name]

	if type(fn) == "function" then
		return fn(...)
	end
end

local function error_text(value)
	return callback("error_text", value) or tostring(value or "unknown error")
end

local function log_info(mod, message)
	return callback("log_info", mod, message)
end

local function log_diagnostic(mod, message)
	return callback("log_diagnostic", mod, message)
end

local function log_scan_summary(mod, diagnostics)
	return callback("log_scan_summary", mod, diagnostics)
end

local function count_exclusion(diagnostics, reason)
	return callback("count_exclusion", diagnostics, reason)
end

local function new_scan_diagnostics()
	return callback("new_scan_diagnostics")
end

local function profile_label(profile)
	return callback("profile_label", profile)
end

local function archetype_name(profile)
	return callback("archetype_name", profile)
end

local function character_name(profile)
	return callback("character_name", profile)
end

local function localized_class_name(profile)
	return callback("localized_class_name", profile)
end

local function profile_is_enabled(mod, profile)
	return callback("profile_is_enabled", mod, profile)
end

local function cache_profiles(mod, profiles)
	return callback("cache_profiles", mod, profiles)
end

local function server_time()
	return callback("server_time")
end

local function sane_rotation_boundary(value, now)
	return callback("sane_rotation_boundary", value, now)
end

local function application_time()
	return callback("application_time")
end

local function rejected(reason)
	return callback("rejected", reason)
end

local function rotation_pending(reason)
	return callback("rotation_pending", reason)
end

local function context_is_current(mod, token)
	return callback("context_is_current", mod, token)
end

local function call_promise(object, method, ...)
	return callback("call_promise", object, method, ...)
end

local function track_read_promise(promise)
	return callback("track_read_promise", promise)
end

local PRIMARY_TRAITS = {
	gadget_innate_health_increase = {
		color_default = {235, 85, 85},
		color_prefix = "curio_health_color",
		minimum_roll_default = 21,
		minimum_roll_setting_id = "automatic_curio_min_health",
		setting_id = "automatic_curio_buy_health",
		label_id = "automatic_curio_health",
		unit = "%",
	},
	gadget_innate_toughness_increase = {
		color_default = {105, 200, 235},
		color_prefix = "curio_toughness_color",
		minimum_roll_default = 17,
		minimum_roll_setting_id = "automatic_curio_min_toughness",
		setting_id = "automatic_curio_buy_toughness",
		label_id = "automatic_curio_toughness",
		unit = "%",
	},
	gadget_innate_max_wounds_increase = {
		color_default = {190, 105, 230},
		color_prefix = "curio_wound_color",
		setting_id = "automatic_curio_buy_wounds",
		label_id = "automatic_curio_wounds",
		unit = "",
	},
	gadget_stamina_increase = {
		color_default = {235, 205, 80},
		color_prefix = "curio_stamina_color",
		setting_id = "automatic_curio_buy_stamina",
		label_id = "automatic_curio_stamina",
		unit = "",
	},
}

local function primary_trait(item)
	local traits = item and item.traits

	if type(traits) ~= "table" then
		return
	end

	for index = 1, #traits do
		local entry = traits[index]
		local trait_name, value = CurioValues.resolve(entry)
		local config = trait_name and PRIMARY_TRAITS[trait_name]

		if config then
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
	elseif type(offer.price) == "table" then
		local now = server_time()

		if now then
			local valid_from = offer.price.validFrom and tonumber(offer.price.validFrom)
			local valid_to = offer.price.validTo and tonumber(offer.price.validTo)

			if (offer.price.validFrom ~= nil and not valid_from) or (offer.price.validTo ~= nil and not valid_to) then
				return false
			end

			if (valid_from and now <= valid_from) or (valid_to and now >= valid_to) then
				return false
			end
		end
	end

	return true
end

local function log_curio_evaluation(mod, profile, offer_id, level, trait_name, trait_value, result)
	log_diagnostic(mod, string.format(
		"%s Curio offer %s: item_level=%s, primary_trait=%s, primary_value=%s; %s.",
		profile_label(profile),
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

	if trait_config.minimum_roll_setting_id then
		local minimum_roll = math.clamp(tonumber(mod:get(trait_config.minimum_roll_setting_id)) or trait_config.minimum_roll_default, 0, 100)

		if not trait_value then
			count_exclusion(diagnostics, "unreadable_primary_value")

			if diagnostics then
				log_curio_evaluation(mod, profile, offer_id, level, trait_name, trait_value, "excluded: unreadable primary value for configured roll threshold")
			end

			return
		elseif trait_value + 0.0001 < minimum_roll then
			count_exclusion(diagnostics, "below_minimum_primary_roll")

			if diagnostics then
				log_curio_evaluation(mod, profile, offer_id, level, trait_name, trait_value, "excluded: below configured primary-roll minimum " .. tostring(minimum_roll))
			end

			return
		end
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
		character_name = character_name(profile),
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

	return track_read_promise(call_promise(store_interface, method, application_time(), profile.character_id))
end

local function observed_rotation_boundary(storefront)
	local now = server_time()
	local data = storefront and storefront.data
	local boundary

	local function consider(value)
		local candidate = sane_rotation_boundary(value, now)

		if candidate and (not boundary or candidate < boundary) then
			boundary = candidate
		end
	end

	consider(data and data.currentRotationEnd)
	consider(data and data.catalog and data.catalog.validTo)

	local offers = data and data.personal

	if type(offers) == "table" then
		for index = 1, #offers do
			consider(offers[index] and offers[index].price and offers[index].price.validTo)
		end
	end

	return boundary
end

local function rotation_boundary_compatible(current_boundary, observed_boundary, missing_metadata)
	if not observed_boundary then
		return current_boundary == nil, current_boundary, true
	end

	if missing_metadata or current_boundary and observed_boundary ~= current_boundary then
		return false, current_boundary, missing_metadata
	end

	return true, current_boundary or observed_boundary, false
end

local function scan_candidates(mod, token, minimum_rotation_boundary_ms, processed_offer_keys)
	local profiles_service = Managers and Managers.data_service and Managers.data_service.profiles

	if not profiles_service or type(profiles_service.fetch_all_profiles) ~= "function" then
		return rejected("ProfilesService.fetch_all_profiles is unavailable")
	end

	local profile_promise = track_read_promise(call_promise(profiles_service, profiles_service.fetch_all_profiles))

	return profile_promise:next(function(result)
		if not context_is_current(mod, token) then
			return {}
		end

		local profiles = result and result.profiles

		if type(profiles) ~= "table" then
			return rejected("profile scan returned no profile list")
		end

		cache_profiles(mod, profiles)

		local candidates = {}
		local chain = Promise.resolved()
		local diagnostics = new_scan_diagnostics()
		local rotation_boundary_ms
		local rotation_boundary_missing = false

		diagnostics.profiles = #profiles

		for index = 1, #profiles do
			local profile = profiles[index]

			if profile and profile.character_id and profile_is_enabled(mod, profile) then
				diagnostics.enabled_profiles = diagnostics.enabled_profiles + 1
				local _, storefront_method = store_method_for_profile(profile)

				if storefront_method then
					chain = chain:next(function()
					if not context_is_current(mod, token) then
						return
					end

					return fetch_storefront(profile):next(function(storefront)
						if not context_is_current(mod, token) then
							return
						end

						local observed_boundary = observed_rotation_boundary(storefront)

						-- The backend can briefly return the expired storefront after its
						-- advertised rotation boundary. A boundary-based pass must prove
						-- that every character storefront advanced before it evaluates or
						-- consumes the new rotation. Falling back to the next wall-clock
						-- hour here would incorrectly bless stale offers and suppress the
						-- real refreshed pass.
						if minimum_rotation_boundary_ms and (not observed_boundary or observed_boundary <= minimum_rotation_boundary_ms) then
							return rotation_pending(string.format(
								"Armoury storefront for %s has not advanced beyond rotation boundary %s",
								profile_label(profile),
								tostring(minimum_rotation_boundary_ms)
							))
						end

						-- A single account-wide pass must observe one coherent backend
						-- boundary. Mixed or missing per-character metadata means the
						-- storefronts are not synchronized enough to evaluate or purchase.
						local boundary_compatible, next_boundary, next_missing = rotation_boundary_compatible(rotation_boundary_ms, observed_boundary, rotation_boundary_missing)

						if not boundary_compatible then
							return rotation_pending(string.format(
								"Armoury storefront rotation boundary mismatch or missing metadata for %s",
								profile_label(profile)
							))
						end

						rotation_boundary_ms = next_boundary
						rotation_boundary_missing = next_missing

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

							if success and candidate and not (processed_offer_keys and processed_offer_keys[candidate_key(candidate)]) then
								candidates[#candidates + 1] = candidate
							elseif not success then
								diagnostics.offer_errors = diagnostics.offer_errors + 1

								if diagnostics.offer_errors_logged < MAX_OFFER_ERROR_LOGS_PER_SCAN then
									diagnostics.offer_errors_logged = diagnostics.offer_errors_logged + 1
									log_info(mod, "Safety-excluded an unreadable offer: " .. error_text(candidate))
								end
							end
						end

						log_diagnostic(mod, string.format(
							"%s storefront summary: offers=%d, Curios=%d, eligible=%d.",
							profile_label(profile),
							diagnostics.offers - offers_before,
							diagnostics.curios - curios_before,
							diagnostics.eligible - eligible_before
						))
					end)
					end)
				else
					log_diagnostic(mod, profile_label(profile) .. " was skipped because Darktide exposes no Armoury storefront for its archetype.")
				end
			end
		end

		return chain:next(function()
			if diagnostics.offer_errors > diagnostics.offer_errors_logged then
				log_info(mod, string.format(
					"Suppressed %d additional unreadable-offer error log(s) during this scan.",
					diagnostics.offer_errors - diagnostics.offer_errors_logged
				))
			end

			log_scan_summary(mod, diagnostics)

			table.sort(candidates, function(left, right)
				if left.class_name ~= right.class_name then
					return left.class_name < right.class_name
				elseif left.item_level ~= right.item_level then
					return left.item_level > right.item_level
				end

				return tostring(left.offer_id) < tostring(right.offer_id)
			end)

			return {
				candidates = candidates,
				rotation_boundary_ms = rotation_boundary_ms,
			}
		end)
	end)
end
CurioStore.scan_candidates = function(mod, token, minimum_rotation_boundary_ms, processed_offer_keys)
	return scan_candidates(mod, token, minimum_rotation_boundary_ms, processed_offer_keys)
end

CurioStore.fetch_storefront = fetch_storefront
CurioStore.normalized_offer = normalized_offer
CurioStore.primary_trait = primary_trait
CurioStore.item_level = item_level
CurioStore.offer_is_active = offer_is_active
CurioStore.observed_rotation_boundary = observed_rotation_boundary
CurioStore.rotation_boundary_compatible = rotation_boundary_compatible
CurioStore.candidate_key = candidate_key
CurioStore.store_method_for_profile = store_method_for_profile

CurioStore._test = {
	PRIMARY_TRAITS = PRIMARY_TRAITS,
	candidate_key = candidate_key,
	normalized_offer = normalized_offer,
	observed_rotation_boundary = observed_rotation_boundary,
	primary_trait = primary_trait,
	rotation_boundary_compatible = rotation_boundary_compatible,
}

return CurioStore
