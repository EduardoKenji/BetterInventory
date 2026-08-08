local Planner = {}

local DEFAULTS = {
	dump_stat = "damage",
	dump_target = 60,
	cap_by_dockets = false,
	docket_cap = 1000000,
	cap_by_max_purchases = false,
	max_purchases = 100,
	best_candidate_fallback = false,
	request_mode = "sequential",
}

local REQUEST_MODES = {
	sequential = true,
	parallel_reads = true,
	experimental_parallel_mutations = true,
}

local function number_or(value, fallback)
	local number = tonumber(value)

	return number and number >= 0 and number or fallback
end

local function text_or(value, fallback)
	if value == nil or value == "" then
		return fallback
	end

	return tostring(value)
end

local function currency_amount(snapshot, currency)
	local wallets = snapshot and snapshot.wallets
	local currencies = wallets and wallets.currencies
	local entry = currencies and currencies[currency]

	return entry and tonumber(entry.amount)
end

local function target_key(offer)
	if not offer then
		return nil
	end

	if offer.offer_id ~= nil then
		return "offer:" .. tostring(offer.offer_id)
	end

	if offer.master_id ~= nil then
		return "master:" .. tostring(offer.master_id)
	end

	return nil
end

local function normalize_config(config)
	config = config or {}

	local request_mode = text_or(config.request_mode, DEFAULTS.request_mode)

	if not REQUEST_MODES[request_mode] then
		request_mode = DEFAULTS.request_mode
	end

	return {
		dump_stat = text_or(config.dump_stat, DEFAULTS.dump_stat),
		dump_target = number_or(config.dump_target, DEFAULTS.dump_target),
		cap_by_dockets = config.cap_by_dockets == true,
		docket_cap = number_or(config.docket_cap, DEFAULTS.docket_cap),
		cap_by_max_purchases = config.cap_by_max_purchases == true,
		max_purchases = number_or(config.max_purchases, DEFAULTS.max_purchases),
		best_candidate_fallback = config.best_candidate_fallback == true,
		request_mode = request_mode,
		target_offer = config.target_offer,
	}
end

local function append_reason(reasons, reason)
	reasons[#reasons + 1] = reason
end

local function preflight_summary(preflight)
	if preflight.ok then
		return "READY | read-only preview"
	end

	return "BLOCKED | " .. tostring(preflight.reasons[1] or "preflight incomplete")
end

local function estimate_summary(estimate)
	local floor_text = estimate.dockets_floor and tostring(estimate.dockets_floor) or "?"
	local cap_text = estimate.dockets_cap and tostring(estimate.dockets_cap) or "?"

	return string.format("floor %s dockets | cap %s | materials deferred | expected: estimating", floor_text, cap_text)
end

function Planner.build(snapshot, config)
	local normalized = normalize_config(config)
	local store = snapshot and snapshot.store or {}
	local target = normalized.target_offer
	local wallets = snapshot and snapshot.wallets or {}
	local reasons = {}

	if snapshot == nil then
		append_reason(reasons, "probe data unavailable")
	end

	if store.available == false then
		append_reason(reasons, "Brunt offers unavailable")
	end

	if not target then
		append_reason(reasons, "select a weapon offer")
	end

	local price = target and tonumber(target.price_amount)

	if not price or price <= 0 then
		append_reason(reasons, "selected offer price unavailable")
	end

	if target and target.price_type and target.price_type ~= "credits" then
		append_reason(reasons, "selected offer does not use dockets")
	end

	if normalized.dump_target <= 0 or normalized.dump_target > 100 then
		append_reason(reasons, "dump-stat target must be between 1 and 100")
	end

	if not normalized.cap_by_dockets and not normalized.cap_by_max_purchases then
		append_reason(reasons, "enable at least one acquisition cap")
	end

	if normalized.cap_by_max_purchases and normalized.max_purchases <= 0 then
		append_reason(reasons, "maximum purchases must be greater than zero")
	end

	if normalized.cap_by_dockets and normalized.docket_cap <= 0 then
		append_reason(reasons, "docket cap must be greater than zero")
	end

	if normalized.request_mode == "experimental_parallel_mutations" then
		append_reason(reasons, "experimental parallel mutations are blocked in Phase 1B")
	end

	local credits = currency_amount(snapshot, "credits")

	if price and credits and credits < price then
		append_reason(reasons, "insufficient dockets for one offer")
	end

	if normalized.cap_by_dockets and price and normalized.docket_cap < price then
		append_reason(reasons, "docket cap is below one offer")
	end

	local dockets_cap

	if normalized.cap_by_dockets and normalized.docket_cap > 0 then
		dockets_cap = normalized.docket_cap
	end

	if normalized.cap_by_max_purchases and price and normalized.max_purchases > 0 then
		local purchase_cap = price * normalized.max_purchases

		dockets_cap = dockets_cap and math.min(dockets_cap, purchase_cap) or purchase_cap
	end

	local estimate = {
		confidence = "floor_only",
		dockets_floor = price,
		dockets_cap = dockets_cap,
		plasteel = "deferred until a candidate exists",
		diamantine = "deferred until a candidate exists",
		purchase_count_floor = price and 1 or nil,
		purchase_count_cap = normalized.cap_by_max_purchases and normalized.max_purchases or nil,
	}

	local preflight = {
		ok = #reasons == 0,
		reasons = reasons,
	}
	preflight.summary = preflight_summary(preflight)
	estimate.summary = estimate_summary(estimate)

	local mode_note

	if normalized.request_mode == "parallel_reads" then
		mode_note = "parallel reads selected; mutations remain unavailable"
	elseif normalized.request_mode == "experimental_parallel_mutations" then
		mode_note = "experimental mutation mode selected; blocked in Phase 1B"
	else
		mode_note = "sequential requests (recommended)"
	end

	local dump_stat_resolution = normalized.dump_stat == "auto" and "deferred until candidate exists" or "configured canonical stat"

	return {
		kind = "read_only_plan",
		status = preflight.ok and "ready" or "blocked",
		mode = normalized.request_mode,
		mode_note = mode_note,
		target = target and {
			key = target_key(target),
			display_name = target.display_name,
			offer_id = target.offer_id,
			master_id = target.master_id,
			price = price,
		} or nil,
		dump_stat = normalized.dump_stat,
		dump_stat_resolution = dump_stat_resolution,
		dump_target = normalized.dump_target,
		cap_by_dockets = normalized.cap_by_dockets,
		best_candidate_fallback = normalized.best_candidate_fallback,
		cap_by_max_purchases = normalized.cap_by_max_purchases,
		max_purchases = normalized.max_purchases,
		docket_cap = normalized.docket_cap,
		preflight = preflight,
		estimate = estimate,
		wallet = {
			credits = credits,
			plasteel = currency_amount(snapshot, "plasteel"),
			diamantine = currency_amount(snapshot, "diamantine"),
		},
	}
end

Planner.DEFAULTS = DEFAULTS
Planner.REQUEST_MODES = REQUEST_MODES

return Planner
