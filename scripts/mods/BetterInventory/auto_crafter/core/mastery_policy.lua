local MasteryPolicy = {}

function MasteryPolicy.sticker_status(catalog, trait_id, tier)
	for _, blessing in ipairs(catalog or {}) do
		if blessing.id == trait_id then
			for _, entry in ipairs(blessing.tiers or {}) do
				if tonumber(entry.tier) == tonumber(tier) then
					return entry.status
				end
			end
		end
	end

	return nil
end

local function mastery_cost(costs, field, tier)
	local values = type(costs) == "table" and costs[field] or nil

	return type(values) == "table" and (tonumber(values[tostring(tier)]) or tonumber(values[tier])) or nil
end

local function next_unseen_blessing_tier(blessing, maximum_tier)
	for _, entry in ipairs(blessing and blessing.tiers or {}) do
		local tier = tonumber(entry.tier)

		if tier and tier <= (tonumber(maximum_tier) or tier) and entry.status ~= "seen" then
			return tier
		end
	end

	return nil
end

local function mastery_allocation_candidate(catalog, targets, costs)
	local tier_costs = type(costs) == "table" and costs.tier_costs or nil
	local thresholds = type(costs) == "table" and costs.tier_thresholds or nil

	if type(tier_costs) ~= "table" or next(tier_costs) == nil or type(thresholds) ~= "table" or next(thresholds) == nil then
		return nil, nil, nil, "live mastery blessing costs or tier thresholds are unavailable"
	end

	local spent = 0
	local maximum_rank = 1

	for _, blessing in ipairs(catalog or {}) do
		for _, entry in ipairs(blessing.tiers or {}) do
			local tier = tonumber(entry.tier)

			if tier then
				maximum_rank = math.max(maximum_rank, tier)

				if entry.status == "seen" then
					spent = spent + (mastery_cost(costs, "tier_costs", tier) or 0)
				end
			end
		end
	end

	local unlocked_rank = maximum_rank

	if spent == 0 then
		unlocked_rank = 1
	else
		for tier = 1, maximum_rank do
			local threshold = mastery_cost(costs, "tier_thresholds", tier)

			if threshold and spent < threshold then
				unlocked_rank = math.max(1, tier - 1)
				break
			end
		end
	end

	for _, target in ipairs(targets or {}) do
		if target and MasteryPolicy.sticker_status(catalog, target.id, target.rarity) ~= "seen" then
			for _, blessing in ipairs(catalog or {}) do
				if blessing.id == target.id then
					local tier = next_unseen_blessing_tier(blessing, target.rarity)

					if tier and tier <= unlocked_rank then
						return target.id, tier, "selected"
					end
				end
			end
		end
	end

	for _, blessing in ipairs(catalog or {}) do
		local tier = next_unseen_blessing_tier(blessing, unlocked_rank)

		if tier then
			return blessing.id, tier, "prerequisite"
		end
	end

	return nil, nil, nil, string.format("no valid mastery blessing can be allocated at unlocked Tier %s after spending %s points", tostring(unlocked_rank), tostring(spent))
end

function MasteryPolicy.allocation_progress(catalog, costs)
	local spent = 0
	local total = 0
	local unseen = 0

	for _, blessing in ipairs(catalog or {}) do
		for _, entry in ipairs(blessing.tiers or {}) do
			local tier = tonumber(entry.tier)
			local cost = tier and mastery_cost(costs, "tier_costs", tier) or nil

			if cost then
				total = total + cost

				if entry.status == "seen" then
					spent = spent + cost
				else
					unseen = unseen + 1
				end
			end
		end
	end

	return spent, total, unseen
end

function MasteryPolicy.unseen_blessing_tier_count(catalog)
	local unseen = 0

	for _, blessing in ipairs(catalog or {}) do
		for _, entry in ipairs(blessing.tiers or {}) do
			if tonumber(entry.tier) ~= nil and entry.status ~= "seen" then
				unseen = unseen + 1
			end
		end
	end

	return unseen
end

function MasteryPolicy.allocation_operations(catalog, targets, costs)
	local working = {}

	for blessing_index, blessing in ipairs(catalog or {}) do
		local copy = {
			id = blessing.id,
			tiers = {},
		}

		for tier_index, entry in ipairs(blessing.tiers or {}) do
			copy.tiers[tier_index] = {
				status = entry.status,
				tier = entry.tier,
			}
		end

		working[blessing_index] = copy
	end

	local operations = {}
	local _, _, unseen = MasteryPolicy.allocation_progress(working, costs)
	local maximum_operations = math.max(1, unseen)

	while unseen > 0 and #operations < maximum_operations do
		local trait_id, tier, allocation_kind, allocation_error = mastery_allocation_candidate(working, targets, costs)

		if not trait_id or not tier then
			return nil, allocation_error or "mastery blessing allocation prerequisites could not be resolved"
		end

		operations[#operations + 1] = {
			allocation_kind = allocation_kind,
			rarity = tier,
			trait_id = trait_id,
		}

		for _, blessing in ipairs(working) do
			if blessing.id == trait_id then
				for _, entry in ipairs(blessing.tiers) do
					if tonumber(entry.tier) == tonumber(tier) then
						entry.status = "seen"
					end
				end
			end
		end

		_, _, unseen = MasteryPolicy.allocation_progress(working, costs)
	end

	if unseen > 0 then
		return nil, "mastery blessing allocation plan exceeded its bounded operation count"
	end

	return operations
end

function MasteryPolicy.parse_perk_target(value)
	local id
	local tier

	if type(value) == "string" then
		id, tier = string.match(value, "^perk:(.+):(%d+)$")
	end

	return id and {
		id = id,
		rarity = tonumber(tier),
	} or nil
end

function MasteryPolicy.summary(data)
	if type(data) ~= "table" then
		return nil
	end

	local milestones = data.milestones
	local max_level = tonumber(data.mastery_max_level) or type(milestones) == "table" and #milestones or nil

	return {
		claimed_level = tonumber(data.claimed_level),
		current_xp = tonumber(data.current_xp),
		mastery_id = data.mastery_id,
		mastery_level = tonumber(data.mastery_level),
		mastery_max_level = max_level,
	}
end

function MasteryPolicy.target_reached(summary)
	return summary and tonumber(summary.mastery_level) ~= nil and tonumber(summary.mastery_level) >= 20
end

function MasteryPolicy.claims_converged(summary)
	local level = summary and tonumber(summary.mastery_level)
	local claimed = summary and tonumber(summary.claimed_level)

	return level ~= nil and claimed ~= nil and claimed >= math.max(0, level - 1)
end

function MasteryPolicy.extraction_contains_gear_id(gear_ids, gear_id)
	for _, extracted_id in ipairs(gear_ids or {}) do
		if extracted_id == gear_id then
			return true
		end
	end

	return false
end

function MasteryPolicy.extraction_contains_all(gear_ids, expected_ids)
	local extracted = {}

	for _, gear_id in ipairs(gear_ids or {}) do
		extracted[gear_id] = true
	end

	for _, gear_id in ipairs(expected_ids or {}) do
		if extracted[gear_id] ~= true then
			return false
		end
	end

	return true
end

function MasteryPolicy.remove_snapshot_gear(snapshot, gear_ids)
	local gear = snapshot and snapshot.gear
	local items = gear and gear.items

	if type(items) ~= "table" then
		return
	end

	local removed = {}

	for _, gear_id in ipairs(gear_ids or {}) do
		removed[gear_id] = true
	end

	local retained = {}

	for _, item in ipairs(items) do
		if not removed[item and item.gear_id] then
			retained[#retained + 1] = item
		end
	end

	gear.items = retained
	gear.item_count = #retained
end

function MasteryPolicy.planner_config_signature(config)
	local fields = {
		tostring(config.dump_stat),
		tostring(config.dump_target),
		tostring(config.custom_stats_enabled),
		tostring(config.cap_by_dockets),
		tostring(config.docket_cap),
		tostring(config.cap_by_max_purchases),
		tostring(config.max_purchases),
		tostring(config.best_candidate_fallback),
		tostring(config.defer_bad_weapon_processing),
		tostring(config.consecrate_transcendent),
		tostring(config.level_mastery_20),
		tostring(config.request_mode),
		tostring(config.upgrade_expertise_500),
		tostring(config.reuse_inventory_base),
		tostring(config.include_favorite_inventory_bases),
		tostring(config.craft_duplicate_completed_queued_weapons),
	}

	for index = 1, 5 do
		local target = config.custom_stat_targets and config.custom_stat_targets[index]
		fields[#fields + 1] = type(target) == "table" and table.concat({ tostring(target.name), tostring(target.display_name_key), tostring(target.value) }, ":") or tostring(target)
	end

	return table.concat(fields, "|")
end

function MasteryPolicy.wallet_values(snapshot)
	local currencies = snapshot and snapshot.wallets and snapshot.wallets.currencies or {}

	return {
		credits = tonumber(currencies.credits and currencies.credits.amount) or 0,
		diamantine = tonumber(currencies.diamantine and currencies.diamantine.amount) or 0,
		plasteel = tonumber(currencies.plasteel and currencies.plasteel.amount) or 0,
	}
end

function MasteryPolicy.wallet_consumption(start_wallet, current_wallet)
	start_wallet = start_wallet or {}
	current_wallet = current_wallet or {}

	return {
		credits = math.max(0, (tonumber(start_wallet.credits) or 0) - (tonumber(current_wallet.credits) or 0)),
		diamantine = math.max(0, (tonumber(start_wallet.diamantine) or 0) - (tonumber(current_wallet.diamantine) or 0)),
		plasteel = math.max(0, (tonumber(start_wallet.plasteel) or 0) - (tonumber(current_wallet.plasteel) or 0)),
	}
end

local DIAGNOSTIC_FIELD_COUNT = 17

-- Single-line diagnostic log text for a controller report event.
function MasteryPolicy.diagnostic_message(state, kind, payload)
	payload = payload or {}
	local fields = {
		"[AutoCrafter]",
		"event=" .. tostring(kind),
		"run=" .. tostring(state._generation),
		"op=" .. tostring(state._operation_sequence),
		"phase=" .. tostring(state._phase),
		string.format("elapsed=%.2fs", tonumber(state._run_elapsed) or 0),
	}
	local search = payload.search or state._search
	local current = payload.current or type(payload.phase3) == "table" and payload.phase3.current or state._phase3 and state._phase3.current
	local candidate = payload.candidate or payload.current_item
	-- Flat name/value pairs (values may be nil, so iterate a fixed count).
	local values = {
		"kind", payload.kind,
		"reason", payload.reason,
		"error", payload.error,
		"gear", payload.gear_id or candidate and candidate.gear_id,
		"count", payload.count,
		"amount", payload.amount,
		"expected_xp", payload.expected_xp,
		"attempt", payload.attempt or payload.attempts,
		"retry", payload.retry,
		"mastery", current and current.mastery_level,
		"claimed", current and current.claimed_level,
		"xp", current and current.current_xp,
		"purchases", search and search.purchases,
		"fodder", payload.fodder_count or state._phase3 and state._phase3.fodder_count,
		"rarity", candidate and candidate.rarity,
		"expertise", candidate and candidate.expertise_level,
		"duration", payload.duration and string.format("%.3fs", payload.duration),
	}
	local timings = payload.timings

	if type(timings) == "table" then
		local timing_fields = {}

		for timing_kind, timing in pairs(timings) do
			timing_fields[#timing_fields + 1] = string.format("%s:%dx/%.2fs", tostring(timing_kind), tonumber(timing.count) or 0, tonumber(timing.total) or 0)
		end

		table.sort(timing_fields)
		values[DIAGNOSTIC_FIELD_COUNT * 2 + 1] = "timings"
		values[DIAGNOSTIC_FIELD_COUNT * 2 + 2] = table.concat(timing_fields, ",")
	end

	for index = 1, (DIAGNOSTIC_FIELD_COUNT + (type(timings) == "table" and 1 or 0)) * 2, 2 do
		if values[index + 1] ~= nil then
			fields[#fields + 1] = values[index] .. "=" .. tostring(values[index + 1])
		end
	end

	return table.concat(fields, " ")
end

return MasteryPolicy
