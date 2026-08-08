-- Curio purchase transaction domain. Revalidates stable fields and target
-- wallet ownership immediately before the serialized POST.
local CurioPurchase = {}
local dependencies = {}
local Promise = require("scripts/foundation/utilities/promise")

CurioPurchase.configure = function(options)
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

local function context_is_current(mod, token)
	return callback("context_is_current", mod, token)
end

local function profile_is_enabled(mod, profile)
	return callback("profile_is_enabled", mod, profile)
end

local function rejected(reason)
	return callback("rejected", reason)
end

local function call_promise(object, method, ...)
	return callback("call_promise", object, method, ...)
end

local function track_read_promise(promise)
	return callback("track_read_promise", promise)
end

local function fetch_storefront(profile)
	return callback("fetch_storefront", profile)
end

local function normalized_offer(mod, profile, offer)
	return callback("normalized_offer", mod, profile, offer)
end

local function candidate_key(candidate)
	return callback("candidate_key", candidate)
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

	local account_promise = track_read_promise(call_promise(wallet_interface, wallet_interface.account_wallets))

	if candidate.currency ~= "credits" and candidate.currency ~= "marks" then
		return account_promise:next(function(wallets)
			return find_wallet(wallets, candidate.currency)
		end)
	end

	local character_promise = track_read_promise(call_promise(wallet_interface, wallet_interface.character_wallets, candidate.character_id))

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

local function revalidate_and_purchase(mod, token, captured, on_purchase_dispatch, processed_offer_keys)
	if not context_is_current(mod, token) or not profile_is_enabled(mod, captured.profile) then
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
			log_diagnostic(mod, string.format(
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
				log_diagnostic(mod, string.format("Skipped %s: %s balance was insufficient.", tostring(current.offer_id), current.currency))

				return {
					available = available,
					candidate = current,
					status = "insufficient_funds",
				}
			end

			local store_service = Managers and Managers.data_service and Managers.data_service.store

			if not store_service or type(store_service.purchase_item_with_wallet) ~= "function" then
				return rejected("StoreService.purchase_item_with_wallet is unavailable")
			end

			processed_offer_keys[key] = "in_flight"

			if on_purchase_dispatch then
				on_purchase_dispatch()
			end

			return call_promise(store_service, store_service.purchase_item_with_wallet, current.offer, wallet):next(function()
				processed_offer_keys[key] = "complete"

				return {
					candidate = current,
					status = "purchased",
				}
			end):catch(function(error_value)
				-- A timeout can be ambiguous after the POST reaches the backend. Keep the
				-- session key blocked and never retry this offer automatically.
				processed_offer_keys[key] = "unknown"

				return rejected(error_value)
			end)
		end)
	end)
end
CurioPurchase.revalidate_and_purchase = function(mod, token, captured, on_purchase_dispatch, processed_offer_keys)
	return revalidate_and_purchase(mod, token, captured, on_purchase_dispatch, processed_offer_keys)
end

CurioPurchase.find_offer = find_offer
CurioPurchase.candidate_differences = candidate_differences
CurioPurchase.same_candidate = same_candidate
CurioPurchase._test = {
	STABLE_REVALIDATION_FIELDS = STABLE_REVALIDATION_FIELDS,
	VOLATILE_REVALIDATION_FIELDS = VOLATILE_REVALIDATION_FIELDS,
	candidate_differences = candidate_differences,
	find_offer = find_offer,
	same_candidate = same_candidate,
}

return CurioPurchase
