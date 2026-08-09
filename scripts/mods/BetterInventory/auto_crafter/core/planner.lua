local Planner = {}

local DEFAULTS = {
	dump_stat = "auto",
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

local function stat_entries(base_stats)
	if type(base_stats) ~= "table" then
		return {}
	end

	local entries = {}

	for key, stat in pairs(base_stats) do
		local name
		local value

		if type(stat) == "table" then
			name = stat.name or stat.stat_name or stat.statName
			value = stat.value
		elseif type(key) == "string" and type(stat) == "number" then
			name = key
			value = stat
		end

		value = tonumber(value)

		if name ~= nil and value ~= nil then
			if value <= 1.01 then
				value = value * 100
			end

			entries[#entries + 1] = {
				name = tostring(name),
				value = value,
			}
		end
	end

	table.sort(entries, function (left, right)
		return string.lower(left.name) < string.lower(right.name)
	end)

	return entries
end

local STAT_ALIASES = {
	damage = { "damage" },
	finesse = { "finesse" },
	first_target = { "first_target", "firsttarget" },
	mobility = { "mobility" },
	penetration = { "penetration" },
	defenses = { "defence", "defences", "defense", "defenses" },
}

local function normalized_stat_name(value)
	local text = string.lower(tostring(value or ""))
	text = string.gsub(text, "[^%w]+", "_")
	text = string.gsub(text, "^_+", "")
	text = string.gsub(text, "_+$", "")

	return text
end

local function stat_name_matches(configured_name, candidate_name)
	local configured = normalized_stat_name(configured_name)
	local candidate = normalized_stat_name(candidate_name)

	if configured == "" or candidate == "" then
		return false
	end

	if configured == candidate then
		return true
	end

	local aliases = STAT_ALIASES[configured] or { configured }
	local compact_candidate = string.gsub(candidate, "_", "")

	for _, alias in ipairs(aliases) do
		local normalized_alias = normalized_stat_name(alias)
		local compact_alias = string.gsub(normalized_alias, "_", "")

		if candidate == normalized_alias or string.find(compact_candidate, compact_alias, 1, true) then
			return true
		end
	end

	return false
end

local function discover_from_stats(base_stats)
	local entries = stat_entries(base_stats)

	if #entries == 0 then
		return nil, "selected weapon preview exposed no base stats", nil
	end

	local minimum = math.huge
	local minimum_name
	local minimum_count = 0

	for _, entry in ipairs(entries) do
		if entry.value < minimum then
			minimum = entry.value
			minimum_name = entry.name
			minimum_count = 1
		elseif math.abs(entry.value - minimum) < 0.0001 then
			minimum_count = minimum_count + 1
		end
	end

	if minimum_count ~= 1 then
		return nil, "selected weapon preview has an ambiguous lowest base stat", entries
	end

	return minimum_name, nil, entries
end

local function discover_from_matching_gear(snapshot, target)
	if not target then
		return nil, "no matching weapon-family inventory item is available", nil
	end

	local items = snapshot and snapshot.gear and snapshot.gear.items or {}
	local sums = {}
	local counts = {}

	for _, item in ipairs(items) do
		local same_parent_pattern = target.parent_pattern and item and item.parent_pattern == target.parent_pattern
		local same_master_id = target.master_id and item and (item.master_id == target.master_id or item.name == target.master_id)
		local same_display_name = target.display_name and item and item.display_name == target.display_name

		if same_parent_pattern or same_master_id or same_display_name then
			for _, entry in ipairs(stat_entries(item.base_stats)) do
				sums[entry.name] = (sums[entry.name] or 0) + entry.value
				counts[entry.name] = (counts[entry.name] or 0) + 1
			end
		end
	end

	local averaged = {}

	for name, sum in pairs(sums) do
		averaged[#averaged + 1] = {
			name = name,
			value = sum / counts[name],
		}
	end

	if #averaged == 0 then
		return nil, "no matching weapon-family inventory item is available", nil
	end

	local candidates = stat_entries(averaged)
	local stat, reason = discover_from_stats(candidates)

	return stat, reason, candidates
end

local function resolve_dump_stat(snapshot, target, configured_dump_stat)
	if configured_dump_stat ~= "auto" then
		local candidates = stat_entries(target and target.base_stats)

		if #candidates == 0 then
			local _, _, fallback_candidates = discover_from_matching_gear(snapshot, target)

			candidates = fallback_candidates or {}
		end

		for _, candidate in ipairs(candidates) do
			if stat_name_matches(configured_dump_stat, candidate.name) then
				return candidate.name, "configured stat selected by user", candidates
			end
		end

		return nil, "configured dump stat is not available for the selected weapon", candidates
	end

	local direct_candidates = stat_entries(target and target.base_stats)
	local stat, reason = discover_from_stats(direct_candidates)

	if #direct_candidates > 0 then
		if stat then
			return stat, "auto-discovered from selected weapon preview", direct_candidates
		end

		return nil, reason, direct_candidates
	end

	local fallback_stat, fallback_reason, fallback_candidates = discover_from_matching_gear(snapshot, target)

	if fallback_stat then
		return fallback_stat, "auto-discovered from matching weapon-family inventory", fallback_candidates
	end

	return nil, reason or fallback_reason or "selected weapon stat discovery unavailable", fallback_candidates
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
		trait_catalog = config.trait_catalog,
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
	local resolved_dump_stat
	local dump_stat_resolution
	local dump_stat_candidates

	if snapshot == nil then
		append_reason(reasons, "probe data unavailable")
	end

	if store.available == false then
		append_reason(reasons, "Brunt offers unavailable")
	end

	if not target then
		append_reason(reasons, "select a weapon offer")
	end

	if target then
		resolved_dump_stat, dump_stat_resolution, dump_stat_candidates = resolve_dump_stat(snapshot, target, normalized.dump_stat)

		if not resolved_dump_stat then
			local reason_prefix = normalized.dump_stat == "auto" and "auto dump-stat discovery unavailable: " or "configured dump stat unavailable: "
			append_reason(reasons, reason_prefix .. tostring(dump_stat_resolution))
		end
	elseif normalized.dump_stat ~= "auto" then
		resolved_dump_stat, dump_stat_resolution = resolve_dump_stat(snapshot, target, normalized.dump_stat)
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
			base_stats = target.base_stats,
			parent_pattern = target.parent_pattern,
			price = price,
		} or nil,
		dump_stat = normalized.dump_stat,
		resolved_dump_stat = resolved_dump_stat,
		dump_stat_candidates = dump_stat_candidates,
		dump_stat_resolution = dump_stat_resolution,
		trait_catalog = normalized.trait_catalog,
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
