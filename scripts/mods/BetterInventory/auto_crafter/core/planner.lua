local Planner = {}

local DEFAULTS = {
	dump_stat = "damage",
	dump_target = 60,
	dump_comparison = "exact",
	cap_by_dockets = true,
	docket_cap = 500000,
	cap_by_max_purchases = false,
	max_purchases = 100,
	best_candidate_fallback = true,
	consecrate_transcendent = true,
	level_mastery_20 = true,
	upgrade_expertise_500 = true,
	request_mode = "sequential",
}

local ESTIMATE_BASE_LEVEL_MIN = 290
local ESTIMATE_BASE_LEVEL_MAX = 330
local CUSTOM_STAT_COUNT = 5
local CUSTOM_STAT_MIN = 60
local CUSTOM_STAT_MAX = 80
local CUSTOM_STAT_TOTAL = 380

local STAT_INDEX_BY_DISPLAY_NAME = {
	loc_stats_display_damage_stat = 0,
	loc_stats_display_mobility_stat = 1,
	loc_stats_display_finesse_stat = 2,
	loc_stats_display_first_target_stat = 3,
	loc_stats_display_ap_stat = 4,
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

local function rounded(value)
	return math.floor((tonumber(value) or 0) + 0.5)
end

local function add_costs(total, costs, multiplier)
	for _, cost in ipairs(costs or {}) do
		local currency = cost.type
		local amount = tonumber(cost.amount)

		if currency and amount then
			total[currency] = (total[currency] or 0) + amount * (multiplier or 1)
		end
	end
end

local function scaled_rarity_costs(weapon_costs, rarity, item_level)
	local rarity_upgrade = type(weapon_costs) == "table" and weapon_costs.rarityUpgrade
	local start_costs = type(rarity_upgrade) == "table" and rarity_upgrade.startCost
	local costs = type(start_costs) == "table" and start_costs[tostring(rarity)] or nil

	if type(costs) ~= "table" then
		return nil
	end

	local item_level_span = weapon_costs.baseItemLevelSpan or {}
	local scaling_span = weapon_costs.costScalingSpan or {}
	local scale = tonumber(item_level_span.scale) or 1
	local source_min = tonumber(item_level_span.minInt or item_level_span.min) or scale
	local source_max = tonumber(item_level_span.maxInt or item_level_span.max) or 380 * scale
	local target_min = tonumber(scaling_span.minInt or scaling_span.min) or scale
	local target_max = tonumber(scaling_span.maxInt or scaling_span.max) or scale
	local scaled_level = (tonumber(item_level) or ESTIMATE_BASE_LEVEL_MAX) * scale
	local clamped_level = math.max(source_min, math.min(source_max, scaled_level))
	local ratio = source_max ~= source_min and (clamped_level - source_min) / (source_max - source_min) or 0
	local span_multiplier = (target_min + (target_max - target_min) * ratio) / scale
	local scaled = {}

	for _, cost in ipairs(costs) do
		scaled[#scaled + 1] = {
			amount = rounded((tonumber(cost.amount) or 0) * span_multiplier),
			type = cost.type,
		}
	end

	return scaled
end

local function material_result(total)
	return {
		diamantine = rounded(total.diamantine or 0),
		plasteel = rounded(total.plasteel or 0),
	}
end

local function rarity_material_quote(snapshot, target, base_level, resulting_rarity)
	local crafting_costs = snapshot and snapshot.crafting_costs
	local weapon_costs = crafting_costs and crafting_costs.weapon

	if type(weapon_costs) ~= "table" then
		return nil, "live crafting recipe costs unavailable"
	end

	local total = {}
	-- Brunt always generates Profane weapons (rarity 1). Recipe costs are keyed
	-- by source rarity, so reaching rarity N spends entries start..N-1.
	local start_rarity = tonumber(target and target.rarity) or 1

	for rarity = start_rarity, resulting_rarity - 1 do
		local costs = scaled_rarity_costs(weapon_costs, rarity, base_level)

		if costs == nil then
			return nil, "rarity-upgrade recipe quote incomplete"
		end

		add_costs(total, costs)
	end

	return material_result(total)
end

local function expertise_material_quote(snapshot, base_level)
	local crafting_costs = snapshot and snapshot.crafting_costs
	local weapon_costs = crafting_costs and crafting_costs.weapon

	if type(weapon_costs) ~= "table" then
		return nil, "live crafting recipe costs unavailable"
	end

	local total = {}
	local add_expertise = weapon_costs.addExpertise
	local start_costs = type(add_expertise) == "table" and add_expertise.startCost

	if type(start_costs) ~= "table" then
		return nil, "expertise recipe quote unavailable"
	end

	for level = base_level + 1, 500 do
		local bucket = math.floor(level / 10) * 10
		add_costs(total, start_costs[tostring(math.max(1, bucket))])
	end

	return material_result(total)
end

local function quote_range(low_quote, high_quote)
	if not low_quote or not high_quote then
		return nil
	end

	return {
		diamantine_max = math.max(low_quote.diamantine, high_quote.diamantine),
		diamantine_min = math.min(low_quote.diamantine, high_quote.diamantine),
		plasteel_max = math.max(low_quote.plasteel, high_quote.plasteel),
		plasteel_min = math.min(low_quote.plasteel, high_quote.plasteel),
	}
end

local function mastery_target_xp(mastery, target_level)
	local milestones = mastery and mastery.milestones

	if type(milestones) ~= "table" then
		return nil
	end

	for index, milestone in ipairs(milestones) do
		local level = tonumber(milestone and milestone.level) or index

		if level == target_level then
			return tonumber(milestone.xpLimit or milestone.xp_limit)
		end
	end

	return nil
end

local function sacrifice_xp(costs, expertise_level)
	if type(costs) ~= "table" then
		return nil
	end

	local multiplier = tonumber(costs.sacrifice_muiltiplier or costs.sacrifice_multiplier) or 6
	local minimum = tonumber(costs.minimumExpertiseLevel) or 0
	local base_reward = tonumber(costs.baseReward) or 25
	local per_level = tonumber(costs.masteryXpPerExpertiseLevel) or 30

	return (base_reward + (((tonumber(expertise_level) or 0) - minimum) / 10 + 1) * per_level) * multiplier
end

local function mastery_fodder_estimate(snapshot, normalized, target)
	if not normalized.level_mastery_20 then
		return nil, "disabled"
	end

	local mastery = normalized.trait_catalog and normalized.trait_catalog.mastery
	local target_xp = mastery_target_xp(mastery, 20)
	local current_xp = tonumber(mastery and mastery.current_xp)
	local sacrifice_costs = snapshot and snapshot.crafting_costs and snapshot.crafting_costs.sacrifice_mastery

	if not target_xp or not current_xp or type(sacrifice_costs) ~= "table" then
		return nil, "mastery curve or sacrifice XP costs unavailable"
	end

	local remaining_xp = math.max(0, target_xp - current_xp)
	local xp_low = sacrifice_xp(sacrifice_costs, ESTIMATE_BASE_LEVEL_MIN)
	local xp_high = sacrifice_xp(sacrifice_costs, ESTIMATE_BASE_LEVEL_MAX)

	if not xp_low or not xp_high or xp_low <= 0 or xp_high <= 0 then
		return nil, "sacrifice XP quote unavailable"
	end

	local count_min = math.ceil(remaining_xp / math.max(xp_low, xp_high))
	local count_max = math.ceil(remaining_xp / math.min(xp_low, xp_high))
	local price = tonumber(target and target.price_amount) or 0
	local redeem_low, redeem_low_reason = rarity_material_quote(snapshot, target, ESTIMATE_BASE_LEVEL_MIN, 2)
	local redeem_high, redeem_high_reason = rarity_material_quote(snapshot, target, ESTIMATE_BASE_LEVEL_MAX, 2)
	local redeem_range = quote_range(redeem_low, redeem_high)

	return {
		count_max = count_max,
		count_min = count_min,
		dockets_max = price * count_max,
		dockets_min = price * count_min,
		remaining_xp = remaining_xp,
		target_xp = target_xp,
		diamantine_max = redeem_range and redeem_range.diamantine_max * count_max or nil,
		diamantine_min = redeem_range and redeem_range.diamantine_min * count_min or nil,
		plasteel_max = redeem_range and redeem_range.plasteel_max * count_max or nil,
		plasteel_min = redeem_range and redeem_range.plasteel_min * count_min or nil,
	}, redeem_range and "live mastery curve, sacrifice XP and Redeemed recipe costs" or redeem_low_reason or redeem_high_reason
end

local function workflow_material_estimate(snapshot, normalized, target)
	local phases = {}
	local reason

	if normalized.consecrate_transcendent then
		local low, low_reason = rarity_material_quote(snapshot, target, ESTIMATE_BASE_LEVEL_MIN, 5)
		local high, high_reason = rarity_material_quote(snapshot, target, ESTIMATE_BASE_LEVEL_MAX, 5)

		phases.consecrate = quote_range(low, high)
		reason = reason or low_reason or high_reason
	end

	if normalized.upgrade_expertise_500 then
		local low, low_reason = expertise_material_quote(snapshot, ESTIMATE_BASE_LEVEL_MIN)
		local high, high_reason = expertise_material_quote(snapshot, ESTIMATE_BASE_LEVEL_MAX)

		phases.expertise = quote_range(low, high)
		reason = reason or low_reason or high_reason
	end

	phases.mastery, phases.mastery_note = mastery_fodder_estimate(snapshot, normalized, target)

	local total = { diamantine_max = 0, diamantine_min = 0, plasteel_max = 0, plasteel_min = 0 }
	local any

	for _, phase in pairs({ phases.consecrate, phases.expertise, phases.mastery }) do
		if phase then
			any = true
			for _, currency in ipairs({ "diamantine", "plasteel" }) do
				total[currency .. "_min"] = total[currency .. "_min"] + (phase[currency .. "_min"] or 0)
				total[currency .. "_max"] = total[currency .. "_max"] + (phase[currency .. "_max"] or 0)
			end
		end
	end

	phases.total = any and total or nil

	return phases, reason or phases.mastery_note or "live recipe range for a 290-330 starting base level"
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
		local display_name_key

		if type(stat) == "table" then
			name = stat.name or stat.stat_name or stat.statName
			value = stat.value
			display_name_key = stat.display_name_key or stat.display_name or stat.displayName
		elseif type(key) == "string" and type(stat) == "number" then
			name = key
			value = stat
		end

		value = tonumber(value)

		if name ~= nil then
			if value ~= nil and value <= 1.01 then
				value = value * 100
			end

			entries[#entries + 1] = {
				display_name_key = display_name_key,
				name = tostring(name),
				value = value,
			}
		end
	end

	table.sort(entries, function (left, right)
		local left_key = string.lower(tostring(left.display_name_key or left.name))
		local right_key = string.lower(tostring(right.display_name_key or right.name))
		local left_index = STAT_INDEX_BY_DISPLAY_NAME[left.display_name_key] or 100
		local right_index = STAT_INDEX_BY_DISPLAY_NAME[right.display_name_key] or 100

		if left_index ~= right_index then
			return left_index < right_index
		end

		return left_key == right_key and string.lower(left.name) < string.lower(right.name) or left_key < right_key
	end)

	return entries
end

local STAT_ALIASES = {
	damage = { "damage", "dps", "stats_display_damage" },
	finesse = { "finesse", "crit", "stats_display_finesse" },
	first_target = { "first_target", "firsttarget" },
	mobility = { "mobility" },
	penetration = { "penetration", "armor_pierce", "armour_pierce", "stats_display_ap_stat" },
	defenses = { "defence", "defences", "defense", "defenses", "stats_display_defense" },
}

local function normalized_stat_name(value)
	local text = string.lower(tostring(value or ""))
	text = string.gsub(text, "[^%w]+", "_")
	text = string.gsub(text, "^_+", "")
	text = string.gsub(text, "_+$", "")

	return text
end

local function stat_name_matches(configured_name, candidate)
	local configured = normalized_stat_name(configured_name)
	local candidate_name = type(candidate) == "table" and candidate.name or candidate
	local candidate_display_name = type(candidate) == "table" and candidate.display_name_key or nil
	local normalized_candidate = normalized_stat_name(candidate_name)
	local normalized_display_name = normalized_stat_name(candidate_display_name)

	if configured == "" or normalized_candidate == "" then
		return false
	end

	if configured == normalized_candidate then
		return true
	end

	local aliases = STAT_ALIASES[configured] or { configured }
	local compact_candidate = string.gsub(normalized_candidate, "_", "")
	local compact_display_name = string.gsub(normalized_display_name, "_", "")

	for _, alias in ipairs(aliases) do
		local normalized_alias = normalized_stat_name(alias)
		local compact_alias = string.gsub(normalized_alias, "_", "")

		if normalized_candidate == normalized_alias or string.find(compact_candidate, compact_alias, 1, true) or compact_display_name ~= "" and string.find(compact_display_name, compact_alias, 1, true) then
			return true
		end
	end

	return false
end

local function resolve_dump_stat(_, target, configured_dump_stat)
	local candidates = stat_entries(target and target.base_stats)

	if #candidates == 0 then
		return nil, "selected weapon exposed no base-stat catalogue", candidates
	end

	if configured_dump_stat ~= nil and configured_dump_stat ~= "auto" then
		for _, candidate in ipairs(candidates) do
			if stat_name_matches(configured_dump_stat, candidate) then
				return candidate.name, "configured stat selected by user", candidates
			end
		end
	end

	return candidates[1].name, "defaulted to dump-stat index 0", candidates
end

local function resolved_stat_identity(candidates, stat_name)
	for _, candidate in ipairs(candidates or {}) do
		if candidate.name == stat_name then
			return {
				display_name_key = candidate.display_name_key,
				name = candidate.name,
			}
		end
	end

	return nil
end

local function resolve_custom_stat_targets(candidates, configured_targets)
	local targets = {}
	local target_map = {}
	local total = 0
	local reason
	local identity_targets = type(configured_targets) == "table" and type(configured_targets[1]) == "table"

	local function configured_for(candidate, index)
		if not identity_targets then
			return type(configured_targets) == "table" and configured_targets[index] or nil
		end

		local matched

		for _, configured in ipairs(configured_targets) do
			if configured.name ~= nil and candidate and tostring(configured.name) == tostring(candidate.name) then
				if matched ~= nil then return nil end
				matched = configured
			end
		end

		if matched ~= nil then return matched end

		for _, configured in ipairs(configured_targets) do
			if configured.display_name_key ~= nil and candidate and candidate.display_name_key ~= nil and tostring(configured.display_name_key) == tostring(candidate.display_name_key) then
				if matched ~= nil then return nil end
				matched = configured
			end
		end

		return matched
	end

	if #candidates ~= CUSTOM_STAT_COUNT then
		reason = string.format("custom stats require exactly %d weapon stats; selected weapon exposed %d", CUSTOM_STAT_COUNT, #candidates)
	end

	for index = 1, CUSTOM_STAT_COUNT do
		local candidate = candidates[index]
		local configured = configured_for(candidate, index)
		local value = tonumber(type(configured) == "table" and configured.value or configured)

		if value == nil or value ~= math.floor(value) or value < CUSTOM_STAT_MIN or value > CUSTOM_STAT_MAX then
			reason = reason or (identity_targets and string.format("custom stat identity %s is missing or ambiguous", tostring(candidate and candidate.name or index)) or string.format("custom stat %d must be a whole number between %d and %d", index, CUSTOM_STAT_MIN, CUSTOM_STAT_MAX))
			value = value and math.floor(value) or CUSTOM_STAT_MIN
		end

		total = total + value
		targets[index] = {
			display_name_key = candidate and candidate.display_name_key,
			label = type(configured) == "table" and configured.label or nil,
			name = candidate and candidate.name,
			value = value,
		}

		if candidate and candidate.name then
			target_map[candidate.name] = value
		end
	end

	if total ~= CUSTOM_STAT_TOTAL then
		reason = reason or string.format("custom stat total must equal %d before crafting (current: %d)", CUSTOM_STAT_TOTAL, total)
	end

	return targets, target_map, total, reason
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
		dump_comparison = config.dump_comparison == "at_most" and "at_most" or DEFAULTS.dump_comparison,
		custom_stats_enabled = config.custom_stats_enabled == true,
		custom_stat_targets = type(config.custom_stat_targets) == "table" and config.custom_stat_targets or {},
		cap_by_dockets = config.cap_by_dockets == true,
		docket_cap = number_or(config.docket_cap, DEFAULTS.docket_cap),
		cap_by_max_purchases = config.cap_by_max_purchases == true,
		max_purchases = number_or(config.max_purchases, DEFAULTS.max_purchases),
		best_candidate_fallback = config.best_candidate_fallback == true,
		consecrate_transcendent = config.consecrate_transcendent ~= false,
		level_mastery_20 = config.level_mastery_20 == true,
		request_mode = request_mode,
		upgrade_expertise_500 = config.upgrade_expertise_500 ~= false,
		trait_catalog = config.trait_catalog,
		target_offer = config.target_offer,
	}
end

local function append_reason(reasons, reason)
	reasons[#reasons + 1] = reason
end

local function preflight_summary(preflight)
	if preflight.ok then
		return "READY"
	end

	return "BLOCKED | " .. tostring(preflight.reasons[1] or "preflight incomplete")
end

local function estimate_summary(estimate)
	local floor_text = estimate.dockets_floor and tostring(estimate.dockets_floor) or "?"
	local cap_text = estimate.dockets_cap and tostring(estimate.dockets_cap) or "uncapped"

	return string.format("acquisition %s-%s dockets | upgrades modeled separately", floor_text, cap_text)
end

function Planner.build(snapshot, config)
	local normalized = normalize_config(config)
	local store = snapshot and snapshot.store or {}
	local target = normalized.target_offer
	local wallets = snapshot and snapshot.wallets or {}
	local reasons = {}
	local resolved_dump_stat
	local dump_stat_identity
	local dump_stat_resolution
	local dump_stat_candidates
	local custom_stat_targets
	local custom_stat_target_map
	local custom_stat_total
	local custom_stat_error

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
		dump_stat_identity = resolved_stat_identity(dump_stat_candidates, resolved_dump_stat)

		if not resolved_dump_stat then
			local reason_prefix = normalized.dump_stat == "auto" and "auto dump-stat discovery unavailable: " or "configured dump stat unavailable: "
			append_reason(reasons, reason_prefix .. tostring(dump_stat_resolution))
		end
	elseif normalized.dump_stat ~= "auto" then
		resolved_dump_stat, dump_stat_resolution = resolve_dump_stat(snapshot, target, normalized.dump_stat)
	end

	if normalized.custom_stats_enabled then
		custom_stat_targets, custom_stat_target_map, custom_stat_total, custom_stat_error = resolve_custom_stat_targets(dump_stat_candidates or {}, normalized.custom_stat_targets)

		if custom_stat_error then
			append_reason(reasons, custom_stat_error)
		end
	end

	local price = target and tonumber(target.price_amount)

	if not price or price <= 0 then
		append_reason(reasons, "selected offer price unavailable")
	end

	if target and target.price_type and target.price_type ~= "credits" then
		append_reason(reasons, "selected offer does not use dockets")
	end

	if not normalized.custom_stats_enabled and (normalized.dump_target <= 0 or normalized.dump_target > 100) then
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

	local phases, material_note = workflow_material_estimate(snapshot, normalized, target)
	local material_estimate = phases and phases.total
	local plasteel = currency_amount(snapshot, "plasteel")
	local diamantine = currency_amount(snapshot, "diamantine")

	-- Only block against the live-recipe minimum. Maximums remain estimates and
	-- must never reject a run that can complete more cheaply.
	if material_estimate and plasteel and material_estimate.plasteel_min and plasteel < material_estimate.plasteel_min then
		append_reason(reasons, "insufficient plasteel for minimum enabled workflow")
	end

	if material_estimate and diamantine and material_estimate.diamantine_min and diamantine < material_estimate.diamantine_min then
		append_reason(reasons, "insufficient diamantine for minimum enabled workflow")
	end

	local purchase_count_cap = price and dockets_cap and math.floor(dockets_cap / price) or nil
	local estimate = {
		base_level_max = material_estimate and material_estimate.base_level_max or ESTIMATE_BASE_LEVEL_MAX,
		base_level_min = material_estimate and material_estimate.base_level_min or ESTIMATE_BASE_LEVEL_MIN,
		confidence = material_estimate and "live_recipe_range" or "acquisition_only",
		dockets_floor = price,
		dockets_cap = dockets_cap,
		dockets_max = phases and phases.mastery and phases.mastery.dockets_max or nil,
		dockets_min = phases and phases.mastery and phases.mastery.dockets_min or nil,
		diamantine_max = material_estimate and material_estimate.diamantine_max or nil,
		diamantine_min = material_estimate and material_estimate.diamantine_min or nil,
		material_note = material_note,
		phases = phases,
		plasteel_max = material_estimate and material_estimate.plasteel_max or nil,
		plasteel_min = material_estimate and material_estimate.plasteel_min or nil,
		purchase_count_floor = price and 1 or nil,
		purchase_count_cap = purchase_count_cap,
	}

	local preflight = {
		ok = #reasons == 0,
		reasons = reasons,
	}
	preflight.summary = preflight_summary(preflight)
	estimate.summary = estimate_summary(estimate)

	local mode_note

	if normalized.request_mode == "parallel_reads" then
		mode_note = "parallel-read preference saved; current reads and mutations remain serialized"
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
			base_item_level = target.base_item_level,
			key = target_key(target),
			display_name = target.display_name,
			family_mark_selection = target.family_mark_selection,
			offer_id = target.offer_id,
			master_id = target.master_id,
			base_stats = target.base_stats,
			parent_pattern = target.parent_pattern,
			price = price,
			rarity = target.rarity,
			weapon_template = target.weapon_template,
		} or nil,
		dump_stat = normalized.dump_stat,
		resolved_dump_stat = resolved_dump_stat,
		dump_stat_identity = dump_stat_identity,
		dump_stat_candidates = dump_stat_candidates,
		dump_stat_resolution = dump_stat_resolution,
		custom_stats_enabled = normalized.custom_stats_enabled,
		custom_stat_targets = custom_stat_targets,
		custom_stat_target_map = custom_stat_target_map,
		custom_stat_total = custom_stat_total,
		custom_stats_valid = normalized.custom_stats_enabled and custom_stat_error == nil or not normalized.custom_stats_enabled,
		trait_catalog = normalized.trait_catalog,
		dump_target = normalized.dump_target,
		dump_comparison = normalized.dump_comparison,
		cap_by_dockets = normalized.cap_by_dockets,
		best_candidate_fallback = normalized.best_candidate_fallback,
		cap_by_max_purchases = normalized.cap_by_max_purchases,
		max_purchases = normalized.max_purchases,
		docket_cap = normalized.docket_cap,
		preflight = preflight,
		estimate = estimate,
		wallet = {
			credits = credits,
			plasteel = plasteel,
			diamantine = diamantine,
		},
	}
end

Planner.DEFAULTS = DEFAULTS
Planner.REQUEST_MODES = REQUEST_MODES
Planner.CUSTOM_STAT_COUNT = CUSTOM_STAT_COUNT
Planner.CUSTOM_STAT_MIN = CUSTOM_STAT_MIN
Planner.CUSTOM_STAT_MAX = CUSTOM_STAT_MAX
Planner.CUSTOM_STAT_TOTAL = CUSTOM_STAT_TOTAL

function Planner.default_dump_stat(plan)
	local candidates = type(plan) == "table" and plan.dump_stat_candidates or {}
	local first = candidates[1]

	return type(first) == "table" and first.name or nil
end

return Planner
