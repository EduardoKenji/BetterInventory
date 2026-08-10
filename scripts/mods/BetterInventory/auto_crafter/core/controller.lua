local Controller = {}

local DEFAULT_PROBE_DELAY = 0.5
local DEFAULT_VIEW_IDLE_POLL_INTERVAL = 0.1
local DEFAULT_MASTERY_POLL_DELAY = 0.05
local DEFAULT_BLESSING_POLL_DELAY = 0.05
local DEFAULT_PURCHASE_CONFIRMATION_POLL_DELAY = 0.05
local MAX_MASTERY_POLL_ATTEMPTS = 12
local MAX_BLESSING_SYNC_ATTEMPTS = 12
local MAX_PURCHASE_CONFIRMATION_ATTEMPTS = 6
local MAX_MASTERY_CLAIM_RETRIES = 2
local MAX_OPERATION_SECONDS = 45
local MAX_READ_SECONDS = 45
local MAX_IDLE_WORKFLOW_SECONDS = 5
local PHASE3_FODDER_BATCH_SIZE = 8
local MAX_PARALLEL_FODDER_UPGRADES = 1
local REDEEMED_RARITY = 2
local TRANSCENDENT_RARITY = 5
local MAX_EXPERTISE_LEVEL = 500

local function mastery_poll_delay(attempt)
	local exponent = math.max(0, tonumber(attempt) or 0)

	return math.min(0.5, DEFAULT_MASTERY_POLL_DELAY * 2 ^ exponent)
end

local function blessing_poll_delay(attempt)
	local exponent = math.max(0, tonumber(attempt) or 0)

	return math.min(1, DEFAULT_BLESSING_POLL_DELAY * 2 ^ exponent)
end

local function purchase_confirmation_poll_delay(attempt)
	local exponent = math.max(0, (tonumber(attempt) or 1) - 1)

	return math.min(0.5, DEFAULT_PURCHASE_CONFIRMATION_POLL_DELAY * 2 ^ exponent)
end

local function finite_dt(dt)
	local value = tonumber(dt)

	return value and value > 0 and value < 60 and value or 0
end

local function safe_call(fn, ...)
	if type(fn) ~= "function" then
		return false, "method unavailable"
	end

	return pcall(fn, ...)
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

local function error_description(error_value)
	if type(error_value) == "table" then
		local description = safe_member(error_value, "description") or safe_member(error_value, "message") or safe_member(error_value, "error")

		if description ~= nil and description ~= error_value then
			return error_description(description)
		end

		local code = safe_member(error_value, "code")

		if code ~= nil then
			return tostring(code)
		end

		return "unknown backend error"
	end

	return tostring(error_value or "unknown operation error")
end

local function offer_key(offer)
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

local function selected_offer_ids(raw_offer)
	if not raw_offer then
		return nil
	end

	local selected_offer = {
		offer_id = safe_member(raw_offer, "offerId") or safe_member(raw_offer, "offer_id"),
		master_id = safe_member(raw_offer, "masterId") or safe_member(raw_offer, "master_id"),
	}
	local description = safe_member(raw_offer, "description")
	local choices = safe_member(description, "lootChoices") or safe_member(description, "loot_choices")
	local choice = type(choices) == "table" and choices[1] or nil

	if selected_offer.master_id == nil then
		if type(choice) == "table" then
			selected_offer.master_id = choice.masterId or choice.master_id or choice.id or choice.name
		else
			selected_offer.master_id = choice
		end
	end

	if selected_offer.offer_id == nil and selected_offer.master_id == nil then
		return nil
	end

	return selected_offer
end

local function selected_offer_matches_target(selected_offer, target)
	if not selected_offer or not target then
		return false
	end

	if selected_offer.master_id ~= nil and target.master_id ~= nil and selected_offer.master_id ~= target.master_id then
		return false
	end

	if selected_offer.offer_id ~= nil and target.offer_id ~= nil and selected_offer.offer_id ~= target.offer_id then
		return false
	end

	return selected_offer.master_id ~= nil and target.master_id ~= nil or selected_offer.offer_id ~= nil and target.offer_id ~= nil
end

local function find_item(items, gear_id, items_by_id)
	items_by_id = items_by_id or type(items) == "table" and rawget(items, "by_id")
	local indexed = type(items_by_id) == "table" and items_by_id[gear_id] or nil

	if indexed ~= nil then
		return indexed
	end

	for _, item in ipairs(items or {}) do
		if item and item.gear_id == gear_id then
			return item
		end
	end

	return nil
end

local function candidate_stat(candidate, stat_name)
	if not candidate or not stat_name then
		return nil
	end

	local potential_stats = candidate.potential_base_stats

	return potential_stats and potential_stats[stat_name]
end

local function trait_at(traits, index)
	local trait = type(traits) == "table" and traits[index] or nil

	return trait and {
		id = trait.id,
		rarity = tonumber(trait.rarity),
	} or nil
end

local function same_trait(left, right)
	return left and right and left.id == right.id and tonumber(left.rarity) == tonumber(right.rarity)
end

local function same_optional_trait(left, right)
	return left == nil and right == nil or same_trait(left, right)
end

local function temporary_swap_trait(kind, current_traits, targets, catalog, sticker_book)
	local excluded = {}

	for index = 1, 2 do
		local current = trait_at(current_traits, index)
		local target = targets and targets[index]

		if current and current.id then
			excluded[current.id] = true
		end
		if target and target.id then
			excluded[target.id] = true
		end
	end

	if kind == "perk" then
		for _, entry in ipairs(catalog and catalog.perks or {}) do
			if entry.id and not excluded[entry.id] and tonumber(entry.tier) then
				return { id = entry.id, rarity = tonumber(entry.tier) }
			end
		end
	else
		for _, blessing in ipairs(sticker_book or {}) do
			if blessing.id and not excluded[blessing.id] then
				local highest_seen

				for _, entry in ipairs(blessing.tiers or {}) do
					if entry.status == "seen" and tonumber(entry.tier) then
						highest_seen = math.max(highest_seen or 0, tonumber(entry.tier))
					end
				end

				if highest_seen then
					return { id = blessing.id, rarity = highest_seen }
				end
			end
		end
	end

	return nil
end

local function requires_temporary_swap(current_traits, targets)
	local mismatch = false

	for index = 1, 2 do
		local desired = targets and targets[index]
		local current = trait_at(current_traits, index)

		if desired and not same_trait(current, desired) then
			mismatch = true

			if not same_trait(trait_at(current_traits, index == 1 and 2 or 1), desired) then
				return false
			end
		end
	end

	return mismatch
end

local function sticker_status(catalog, trait_id, tier)
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
		if target and sticker_status(catalog, target.id, target.rarity) ~= "seen" then
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

local function mastery_allocation_progress(catalog, costs)
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

local function unseen_blessing_tier_count(catalog)
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

local function mastery_allocation_operations(catalog, targets, costs)
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
	local _, _, unseen = mastery_allocation_progress(working, costs)
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

		_, _, unseen = mastery_allocation_progress(working, costs)
	end

	if unseen > 0 then
		return nil, "mastery blessing allocation plan exceeded its bounded operation count"
	end

	return operations
end

local function parse_perk_target(value)
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

local function mastery_summary(data)
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

local function mastery_target_reached(summary)
	return summary and tonumber(summary.mastery_level) ~= nil and tonumber(summary.mastery_level) >= 20
end

local function mastery_claims_converged(summary)
	local level = summary and tonumber(summary.mastery_level)
	local claimed = summary and tonumber(summary.claimed_level)

	return level ~= nil and claimed ~= nil and claimed >= math.max(0, level - 1)
end

local function extraction_contains_gear_id(gear_ids, gear_id)
	for _, extracted_id in ipairs(gear_ids or {}) do
		if extracted_id == gear_id then
			return true
		end
	end

	return false
end

local function extraction_contains_all(gear_ids, expected_ids)
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

local function remove_snapshot_gear(snapshot, gear_ids)
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

local function planner_config_signature(config)
	return table.concat({
		tostring(config.dump_stat),
		tostring(config.dump_target),
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
	}, "|")
end

local function wallet_values(snapshot)
	local currencies = snapshot and snapshot.wallets and snapshot.wallets.currencies or {}

	return {
		credits = tonumber(currencies.credits and currencies.credits.amount) or 0,
		diamantine = tonumber(currencies.diamantine and currencies.diamantine.amount) or 0,
		plasteel = tonumber(currencies.plasteel and currencies.plasteel.amount) or 0,
	}
end

local function wallet_consumption(start_wallet, current_wallet)
	start_wallet = start_wallet or {}
	current_wallet = current_wallet or {}

	return {
		credits = math.max(0, (tonumber(start_wallet.credits) or 0) - (tonumber(current_wallet.credits) or 0)),
		diamantine = math.max(0, (tonumber(start_wallet.diamantine) or 0) - (tonumber(current_wallet.diamantine) or 0)),
		plasteel = math.max(0, (tonumber(start_wallet.plasteel) or 0) - (tonumber(current_wallet.plasteel) or 0)),
	}
end

function Controller.new(dependencies)
	dependencies = dependencies or {}

	local self = {
		_backend = dependencies.backend,
		_account_operation = dependencies.account_operation or {},
		_planner = dependencies.planner,
		_get_selected_offer = dependencies.get_selected_offer,
		_context = dependencies.context or {},
		_reporter = dependencies.reporter or {},
		_logger = dependencies.logger or {},
		_settings = dependencies.settings or {},
		_clock = dependencies.clock or {},
		_generation = 0,
		_active_view = nil,
		_view_is_valid = false,
		_probe_elapsed = 0,
		_view_idle_poll_elapsed = 0,
		_probe_scheduled = false,
		_probe_inflight = false,
		_probe_promise = nil,
		_probe_request_elapsed = 0,
		_probe_sequence = 0,
		_phase = "idle",
		_snapshot = nil,
		_last_error = nil,
		_last_probe_at = nil,
		_probe_count = 0,
		_plan = nil,
		_last_purchased = nil,
		_operation_inflight = false,
		_operation_promise = nil,
		_operation_kind = nil,
		_operation_sequence = 0,
		_operation_elapsed = 0,
		_operation_started_at = nil,
		_operation_quarantined = false,
		_reconciliation_required = false,
		_auxiliary_inflight_count = 0,
		_search = nil,
		_phase3 = nil,
		_phase4 = nil,
		_mastery = nil,
		_mastery_poll_elapsed = 0,
		_mastery_poll_attempts = 0,
		_mastery_poll_wait = DEFAULT_MASTERY_POLL_DELAY,
		_purchase_confirmation = nil,
		_catalog = nil,
		_catalog_generation = 0,
		_catalog_inflight = false,
		_catalog_elapsed = 0,
		_catalog_key = nil,
		_catalog_promise = nil,
		_selected_target_key = nil,
		_selected_native_key = nil,
		_planner_signature = nil,
		_frozen_run_settings = nil,
		_run_elapsed = 0,
		_run_started_at = nil,
		_last_progress_elapsed = 0,
		_failure_at = nil,
		_operation_timings = {},
		_observed_character_id = nil,
		_run_character_id = nil,
		_account_operation_token = nil,
	}

	local function report(kind, payload)
		local emit = self._reporter.emit

		if type(emit) == "function" then
			pcall(emit, self._reporter, kind, payload or {})
		end
	end

	local function log(level, message)
		local fn = self._logger[level]

		if type(fn) == "function" then
			pcall(fn, self._logger, message)
		end
	end

	local function diagnostic_message(kind, payload)
		payload = payload or {}
		local fields = {
			"[AutoCrafter]",
			"event=" .. tostring(kind),
			"run=" .. tostring(self._generation),
			"op=" .. tostring(self._operation_sequence),
			"phase=" .. tostring(self._phase),
			string.format("elapsed=%.2fs", tonumber(self._run_elapsed) or 0),
		}
		local search = payload.search or self._search
		local current = payload.current or type(payload.phase3) == "table" and payload.phase3.current or self._phase3 and self._phase3.current
		local candidate = payload.candidate or payload.current_item
		local values = {
			{ "kind", payload.kind },
			{ "reason", payload.reason },
			{ "error", payload.error },
			{ "gear", payload.gear_id or candidate and candidate.gear_id },
			{ "count", payload.count },
			{ "amount", payload.amount },
			{ "expected_xp", payload.expected_xp },
			{ "attempt", payload.attempt or payload.attempts },
			{ "retry", payload.retry },
			{ "mastery", current and current.mastery_level },
			{ "claimed", current and current.claimed_level },
			{ "xp", current and current.current_xp },
			{ "purchases", search and search.purchases },
			{ "fodder", payload.fodder_count or self._phase3 and self._phase3.fodder_count },
			{ "rarity", candidate and candidate.rarity },
			{ "expertise", candidate and candidate.expertise_level },
			{ "duration", payload.duration and string.format("%.3fs", payload.duration) },
		}
		local timings = payload.timings

		if type(timings) == "table" then
			local timing_fields = {}

			for timing_kind, timing in pairs(timings) do
				timing_fields[#timing_fields + 1] = string.format("%s:%dx/%.2fs", tostring(timing_kind), tonumber(timing.count) or 0, tonumber(timing.total) or 0)
			end

			table.sort(timing_fields)
			values[#values + 1] = { "timings", table.concat(timing_fields, ",") }
		end

		for _, entry in ipairs(values) do
			if entry[2] ~= nil then
				fields[#fields + 1] = entry[1] .. "=" .. tostring(entry[2])
			end
		end

		return table.concat(fields, " ")
	end

	local function setting(id, default_value)
		local get = self._settings.get

		if type(get) ~= "function" then
			return default_value
		end

		local ok, value = pcall(get, self._settings, id)

		if not ok or value == nil then
			return default_value
		end

		return value
	end

	local function set_setting(id, value)
		local set = self._settings.set

		if type(set) ~= "function" then
			return false
		end

		local ok, result = pcall(set, self._settings, id, value)

		return ok and result ~= false
	end

	local function enabled()
		return setting("auto_crafter_enable", true) == true
	end

	local function probe_enabled()
		return enabled() and setting("auto_crafter_read_only_probe", true) == true
	end

	local function mutations_enabled()
		return enabled()
	end

	local planner_setting_ids = {
		auto_crafter_target_dump_stat = true,
		auto_crafter_dump_stat_target = true,
		auto_crafter_cap_by_dockets = true,
		auto_crafter_docket_cap = true,
		auto_crafter_cap_by_max_purchases = true,
		auto_crafter_max_purchases = true,
		auto_crafter_best_candidate_fallback = true,
		auto_crafter_defer_bad_weapon_processing = true,
		auto_crafter_consecrate_transcendent = true,
		auto_crafter_level_mastery_20 = true,
		auto_crafter_request_mode = true,
		auto_crafter_upgrade_expertise_500 = true,
		auto_crafter_reuse_inventory_base = true,
		auto_crafter_include_favorite_inventory_bases = true,
		auto_crafter_allocate_mastery_points = true,
		auto_crafter_change_perks = true,
		auto_crafter_change_blessings = true,
		auto_crafter_perk_1_target = true,
		auto_crafter_perk_2_target = true,
		auto_crafter_blessing_1_target = true,
		auto_crafter_blessing_2_target = true,
	}

	local function run_is_active()
		return self._search and self._search.running == true or self._phase3 and self._phase3.running == true or self._phase4 and self._phase4.running == true or self._mastery and self._mastery.running == true
	end

	local ACCOUNT_OPERATION_OWNER = "auto_crafter"

	local function account_operation_is_current()
		if self._account_operation_token == nil then
			return true
		end

		local is_current = self._account_operation.is_current
		local ok, current = safe_call(is_current, ACCOUNT_OPERATION_OWNER, self._account_operation_token)

		return type(is_current) ~= "function" or ok and current == true
	end

	local function acquire_account_operation()
		if self._account_operation_token ~= nil then
			return account_operation_is_current(), account_operation_is_current() and nil or "Auto Crafter lost account-operation ownership"
		end

		local conflict = self._account_operation.conflict
		if type(conflict) == "function" then
			local conflict_ok, reason = safe_call(conflict, self._active_view)

			if not conflict_ok then
				return false, "account-operation conflict check failed: " .. tostring(reason)
			elseif reason then
				return false, tostring(reason)
			end
		end

		local acquire = self._account_operation.acquire
		if type(acquire) ~= "function" then
			return true
		end

		local ok, token = safe_call(acquire, ACCOUNT_OPERATION_OWNER, self._active_view)
		if not ok or token == nil then
			return false, ok and "another BetterInventory account operation is active" or tostring(token)
		end

		self._account_operation_token = token

		return true
	end

	local function release_account_operation()
		local token = self._account_operation_token
		if token == nil then
			return true
		end

		local release = self._account_operation.release
		self._account_operation_token = nil
		if type(release) ~= "function" then
			return true
		end

		local ok, released = safe_call(release, ACCOUNT_OPERATION_OWNER, token)

		return ok and released ~= false
	end

	local function release_account_operation_if_settled()
		if not run_is_active() and not self._operation_inflight and (self._auxiliary_inflight_count or 0) == 0 then
			return release_account_operation()
		end

		return false
	end

	local function pending_deferred_count(phase3)
		local queue = phase3 and phase3.deferred_candidates or {}
		local first = phase3 and phase3.deferred_index or 1

		return math.max(0, #queue - first + 1)
	end

	local function mastery_level_target_xp(data, target_level)
		local milestones = type(data) == "table" and data.milestones or nil

		for index, milestone in ipairs(type(milestones) == "table" and milestones or {}) do
			local level = tonumber(milestone and milestone.level) or index

			if level == target_level then
				return tonumber(milestone.xpLimit or milestone.xp_limit)
			end
		end

		return nil
	end

	local function estimated_fodder_xp(candidate)
		local costs = self._snapshot and self._snapshot.crafting_costs and self._snapshot.crafting_costs.sacrifice_mastery
		local expertise = tonumber(candidate and candidate.expertise_level)

		if type(costs) ~= "table" or expertise == nil then
			return nil
		end

		local multiplier = tonumber(costs.sacrifice_muiltiplier or costs.sacrifice_multiplier) or 6
		local minimum = tonumber(costs.minimumExpertiseLevel) or 0
		local base_reward = tonumber(costs.baseReward) or 25
		local per_level = tonumber(costs.masteryXpPerExpertiseLevel) or 30

		return (base_reward + ((expertise - minimum) / 10 + 1) * per_level) * multiplier
	end

	local function pending_fodder_reaches_target(phase3)
		local target_xp = mastery_level_target_xp(phase3 and phase3.current_data, 20)
		local current_xp = tonumber(phase3 and phase3.current and phase3.current.current_xp)
		local queue = phase3 and phase3.deferred_candidates or {}
		local first = phase3 and phase3.deferred_index or 1

		if target_xp == nil or current_xp == nil then
			return false, nil
		end

		local projected_xp = current_xp

		for index = first, #queue do
			local amount = estimated_fodder_xp(queue[index])

			if amount == nil then
				return false, nil
			end

			projected_xp = projected_xp + amount
		end

		return projected_xp >= target_xp, projected_xp
	end

	local function track_purchased_spare(phase3, candidate)
		if not phase3 or not candidate or candidate.gear_id == nil then
			return
		end

		phase3.purchased_spare_ids = phase3.purchased_spare_ids or {}

		if phase3.purchased_spare_ids[candidate.gear_id] then
			return
		end

		phase3.purchased_spare_ids[candidate.gear_id] = true
		phase3.purchased_spares = phase3.purchased_spares or {}
		phase3.purchased_spares[#phase3.purchased_spares + 1] = candidate
	end

	local function clock_now()
		local now = self._clock and self._clock.now

		if type(now) ~= "function" then
			return nil
		end

		local ok, value = pcall(now, self._clock)

		return ok and tonumber(value) or nil
	end

	local function freeze_run_settings()
		local frozen = {}

		for setting_id in pairs(planner_setting_ids) do
			frozen[setting_id] = setting(setting_id)
		end

		frozen.auto_crafter_buy_until_target = setting("auto_crafter_buy_until_target", true)
		self._frozen_run_settings = frozen
	end

	local function run_setting_changed(setting_id)
		local frozen = self._frozen_run_settings

		if not frozen then
			return true
		end

		return setting(setting_id) ~= frozen[setting_id]
	end

	local mutation_setting_ids = {
		auto_crafter_defer_bad_weapon_processing = true,
		auto_crafter_level_mastery_20 = true,
		auto_crafter_consecrate_transcendent = true,
		auto_crafter_upgrade_expertise_500 = true,
		auto_crafter_allocate_mastery_points = true,
		auto_crafter_change_perks = true,
		auto_crafter_change_blessings = true,
	}

	local function planner_config()
		return {
			dump_stat = setting("auto_crafter_target_dump_stat", "damage"),
			dump_target = setting("auto_crafter_dump_stat_target", 60),
			cap_by_dockets = setting("auto_crafter_cap_by_dockets", true),
			docket_cap = setting("auto_crafter_docket_cap", 500000),
			cap_by_max_purchases = setting("auto_crafter_cap_by_max_purchases", false),
			max_purchases = setting("auto_crafter_max_purchases", 100),
			best_candidate_fallback = setting("auto_crafter_best_candidate_fallback", true),
			defer_bad_weapon_processing = setting("auto_crafter_defer_bad_weapon_processing", true),
			consecrate_transcendent = setting("auto_crafter_consecrate_transcendent", true),
			level_mastery_20 = setting("auto_crafter_level_mastery_20", true),
			request_mode = setting("auto_crafter_request_mode", "sequential"),
			upgrade_expertise_500 = setting("auto_crafter_upgrade_expertise_500", true),
			reuse_inventory_base = setting("auto_crafter_reuse_inventory_base", true),
			include_favorite_inventory_bases = setting("auto_crafter_include_favorite_inventory_bases", true),
			trait_catalog = self._catalog,
			target_offer = nil,
		}
	end

	function self:_selected_offer_summary()
		if not self._snapshot or type(self._get_selected_offer) ~= "function" then
			return nil
		end

		local ok, raw_offer = safe_call(self._get_selected_offer, self._active_view)
		local selected_offer = ok and selected_offer_ids(raw_offer) or nil

		if not selected_offer then
			return nil
		end

		local offers = self._snapshot.store and self._snapshot.store.offers or {}

		for _, offer in ipairs(offers) do
			local matches = selected_offer.offer_id and offer.offer_id == selected_offer.offer_id or selected_offer.master_id and offer.master_id == selected_offer.master_id

			if matches then
				return offer
			end
		end

		return nil
	end

	function self:_refresh_plan(reason)
		if not self._snapshot or not self._planner or type(self._planner.build) ~= "function" then
			return false
		end

		local previous_target_key = self._selected_target_key
		local config = planner_config()
		config.target_offer = self:_selected_offer_summary()
		self._selected_native_key = offer_key(config.target_offer)
		self._planner_signature = planner_config_signature(config)
		local ok, plan = pcall(self._planner.build, self._snapshot, config)

		if ok and type(plan) == "table" and type(self._planner.default_dump_stat) == "function" then
			local next_target_key = plan.target and offer_key(plan.target) or nil
			local target_changed = next_target_key ~= previous_target_key
			local default_dump_stat = self._planner.default_dump_stat(plan)

			if not run_is_active() and default_dump_stat and (target_changed or config.dump_stat == "auto") and config.dump_stat ~= default_dump_stat and set_setting("auto_crafter_target_dump_stat", default_dump_stat) then
				config.dump_stat = default_dump_stat
				self._planner_signature = planner_config_signature(config)
				ok, plan = pcall(self._planner.build, self._snapshot, config)
			end
		end

		if not ok or type(plan) ~= "table" then
			self._plan = {
				kind = "read_only_plan",
				status = "blocked",
				preflight = {
					ok = false,
					reasons = {
						"planner failed: " .. tostring(plan),
					},
					summary = "BLOCKED | planner failed",
				},
			}
		else
			self._plan = plan
		end

		self._selected_target_key = self._plan.target and offer_key(self._plan.target) or nil
		report("plan_updated", {
			reason = reason or "refresh",
			plan = self._plan,
		})

		return true
	end

	local function context_is_valid(view)
		local fn = self._context.is_valid_brunt_view

		if type(fn) ~= "function" then
			return true
		end

		local ok, valid = safe_call(fn, self._context, view)

		return ok and valid == true
	end

	local function runtime_context_valid()
		local fn = self._context.is_runtime_valid

		if type(fn) ~= "function" then
			return true
		end

		local ok, valid = safe_call(fn, self._context)

		return ok and valid == true
	end

	local function current_character_id()
		local fn = self._context.current_character_id

		if type(fn) ~= "function" then
			return nil
		end

		local ok, character_id = safe_call(fn, self._context)

		return ok and character_id ~= nil and tostring(character_id) or nil
	end

	local function snapshot_matches_character(snapshot, character_id)
		return type(snapshot) == "table" and character_id ~= nil and snapshot.character_id ~= nil and tostring(snapshot.character_id) == character_id
	end

	local function operation_context_valid(generation)
		local character_id = current_character_id()

		return generation == self._generation and runtime_context_valid() and mutations_enabled() and account_operation_is_current() and (self._run_character_id == nil or character_id == self._run_character_id)
	end

	local function operation_report(kind, payload)
		payload = payload or {}
		self._last_progress_elapsed = self._run_elapsed
		log(kind == "operation_failed" and "error" or "info", diagnostic_message(kind, payload))
		report(kind, payload)
	end

	local function record_timing(kind, duration)
		if kind == nil or tonumber(duration) == nil then
			return
		end

		local timings = self._operation_timings
		local timing = timings[kind] or {
			count = 0,
			maximum = 0,
			total = 0,
		}
		local elapsed = math.max(0, tonumber(duration) or 0)

		timing.count = timing.count + 1
		timing.maximum = math.max(timing.maximum, elapsed)
		timing.total = timing.total + elapsed
		timings[kind] = timing
	end

	function self:_operation_failed(generation, error_value)
		if generation ~= self._generation then
			log("info", string.format("[AutoCrafter] ignored stale failure run=%s current_run=%s error=%s", tostring(generation), tostring(self._generation), error_description(error_value)))
			return
		end

		local failed_kind = self._operation_kind
		self._operation_sequence = self._operation_sequence + 1
		self._operation_inflight = false
		self._operation_promise = nil
		self._operation_kind = nil
		self._operation_elapsed = 0
		self._operation_started_at = nil
		self._purchase_confirmation = nil
		self._phase = "operation_failed"
		error_value = error_description(error_value)
		self._last_error = error_value
		self._failure_at = clock_now()
		operation_report("operation_failed", {
			error = error_value,
			kind = failed_kind,
			timings = self._operation_timings,
		})

		if self._search then
			self._search.running = false
		end

		if self._phase3 and self._phase3.running then
			self._phase3.running = false

			if self._mastery and self._mastery.phase3 then
				self._mastery.running = false
			end

			if self._search then
				self._search.running = false

				if self._phase3.target_candidate then
					self._search.result = self._phase3.target_candidate
				end
			end

			operation_report("phase3_stopped", {
				error = error_value,
				reason = "operation_failed",
			})
		end

		if self._phase4 then
			self._phase4.running = false
		end

		if self._mastery then
			self._mastery.running = false
		end

		self._frozen_run_settings = nil
		self._run_character_id = nil
		release_account_operation_if_settled()
	end

	function self:_quarantine_operation(generation, error_value)
		if generation ~= self._generation or not self._operation_inflight then
			return false
		end

		-- Mutations cannot be cancelled safely. Stop all continuations but retain
		-- the dispatch gate until the original Promise settles.
		self._generation = self._generation + 1
		self._probe_scheduled = false
		self._probe_elapsed = 0
		self._purchase_confirmation = nil
		self._operation_quarantined = true
		self._reconciliation_required = true
		error_value = error_description(error_value)
		self._last_error = error_value
		self._failure_at = clock_now()

		if self._search then self._search.running = false end
		if self._phase3 then self._phase3.running = false end
		if self._phase4 then self._phase4.running = false end
		if self._mastery then self._mastery.running = false end

		self._phase = "operation_quarantined"
		self._frozen_run_settings = nil
		operation_report("operation_quarantined", {
			error = error_value,
			kind = self._operation_kind,
		})

		return true
	end

	function self:_abort_for_auxiliary_failure(generation, error_value)
		if generation ~= self._generation then
			return false
		end

		self._generation = self._generation + 1
		self._probe_scheduled = false
		self._probe_elapsed = 0
		self._purchase_confirmation = nil
		self._reconciliation_required = true
		self._operation_quarantined = self._operation_inflight == true
		error_value = error_description(error_value)
		self._last_error = error_value
		self._failure_at = clock_now()

		if self._search then self._search.running = false end
		if self._phase3 then self._phase3.running = false end
		if self._phase4 then self._phase4.running = false end
		if self._mastery then self._mastery.running = false end

		self._phase = self._operation_inflight and "operation_quarantined" or "operation_reconciliation_required"
		self._frozen_run_settings = nil
		operation_report("operation_quarantined", {
			error = error_value,
			kind = "phase3_fast_upgrade",
		})

		if not self._operation_inflight and (self._auxiliary_inflight_count or 0) == 0 and self._view_is_valid then
			self:_schedule_probe("auxiliary_failure")
		end

		return true
	end

	local function settle_operation(operation_sequence, kind)
		if operation_sequence ~= self._operation_sequence or not self._operation_inflight then
			return false, false, nil
		end

		local completed_at = clock_now()
		local duration = completed_at and self._operation_started_at and math.max(0, completed_at - self._operation_started_at) or self._operation_elapsed
		local was_quarantined = self._operation_quarantined
		self._operation_inflight = false
		self._operation_promise = nil
		self._operation_kind = nil
		self._operation_elapsed = 0
		self._operation_started_at = nil
		self._operation_quarantined = false
		record_timing(kind, duration)

		if was_quarantined then
			self._run_character_id = nil
			self._phase = "operation_reconciliation_required"
			operation_report("operation_quarantine_settled", {
				duration = duration,
				kind = kind,
			})

			if self._view_is_valid then
				self:_schedule_probe("operation_quarantine_settled")
			end
		end
		release_account_operation_if_settled()

		return true, was_quarantined, duration
	end

	local function require_reconciliation(reason)
		self._reconciliation_required = true
		if self._search then self._search.running = false end
		if self._phase3 then self._phase3.running = false end
		if self._phase4 then self._phase4.running = false end
		if self._mastery then self._mastery.running = false end
		self._phase = "operation_reconciliation_required"
		self._frozen_run_settings = nil
		operation_report("operation_reconciliation_required", {
			reason = reason,
		})

		if self._view_is_valid then
			self:_schedule_probe(reason)
		end
	end

	function self:_dispatch_operation(generation, kind, fn, on_success)
		if not operation_context_valid(generation) or self._operation_inflight then
			return false
		end

		self._operation_sequence = self._operation_sequence + 1
		local operation_sequence = self._operation_sequence
		local call_ok, promise = safe_call(fn)

		if not call_ok or not promise or type(promise.next) ~= "function" or type(promise.catch) ~= "function" then
			self:_operation_failed(generation, call_ok and "operation returned no Promise" or promise)

			return false
		end

		self._operation_inflight = true
		self._operation_kind = kind
		self._operation_elapsed = 0
		self._operation_started_at = clock_now()
		self._phase = kind .. "_inflight"
		operation_report("operation_started", {
			kind = kind,
		})

		local chain_ok, chain = pcall(function()
			return promise:next(function(result)
				local settled, was_quarantined, duration = settle_operation(operation_sequence, kind)

				if settled and not was_quarantined and generation == self._generation and not operation_context_valid(generation) then
					require_reconciliation("operation_settled_outside_frozen_context")
				end

				if not settled or was_quarantined or generation ~= self._generation or not operation_context_valid(generation) then
					return result
				end
				operation_report("operation_completed", {
					duration = duration,
					kind = kind,
				})

				local callback_ok, callback_error = pcall(on_success, result)

				if not callback_ok then
					self:_operation_failed(generation, callback_error)
				end

				return result
			end):catch(function (error_value)
				local settled, was_quarantined = settle_operation(operation_sequence, kind)

				if not settled or was_quarantined or generation ~= self._generation then
					return error_value
				end

				self:_operation_failed(generation, error_value)

				return error_value
			end)
		end)

		if not chain_ok then
			self:_operation_failed(generation, chain)
		elseif operation_sequence == self._operation_sequence and self._operation_inflight then
			self._operation_promise = chain
		end

		return true
	end

	local function fast_upgrade_pending(phase3)
		local queue = phase3 and phase3.fast_upgrade_queue or {}
		local head = phase3 and phase3.fast_upgrade_head or 1

		return phase3 and ((phase3.fast_upgrade_inflight_count or 0) > 0 or queue[head] ~= nil) or false
	end

	function self:_phase3_resume_after_fast_upgrades(generation)
		local phase3 = self._phase3

		if not phase3 or not phase3.running or generation ~= self._generation or not phase3.fast_purchase_paused or self._operation_inflight or fast_upgrade_pending(phase3) then
			return false
		end

		phase3.fast_purchase_paused = false

		return self:_phase3_process_deferred(generation, phase3.current)
	end

	function self:_phase3_pump_fast_upgrades(generation)
		local phase3 = self._phase3
		local backend = self._backend

		if not phase3 or not phase3.running or generation ~= self._generation or not operation_context_valid(generation) or not backend or type(backend.upgrade_weapon_rarity) ~= "function" then
			return false
		end

		phase3.fast_upgrade_inflight = phase3.fast_upgrade_inflight or {}
		phase3.fast_upgrade_inflight_count = phase3.fast_upgrade_inflight_count or 0
		phase3.fast_upgrade_head = phase3.fast_upgrade_head or 1

		while phase3.fast_upgrade_inflight_count < MAX_PARALLEL_FODDER_UPGRADES do
			local candidate = phase3.fast_upgrade_queue and phase3.fast_upgrade_queue[phase3.fast_upgrade_head]

			if not candidate then
				break
			end

			phase3.fast_upgrade_head = phase3.fast_upgrade_head + 1
			local gear_id = candidate.gear_id
			local call_ok, promise = safe_call(backend.upgrade_weapon_rarity, backend, gear_id)

			if not call_ok or not promise or type(promise.next) ~= "function" or type(promise.catch) ~= "function" then
				self:_operation_failed(generation, call_ok and "fast fodder upgrade returned no Promise" or promise)

				return false
			end

			local entry = {
				candidate = candidate,
				elapsed = 0,
				generation = generation,
				started_at = clock_now(),
			}
			phase3.fast_upgrade_inflight[gear_id] = entry
			phase3.fast_upgrade_inflight_count = phase3.fast_upgrade_inflight_count + 1
			self._auxiliary_inflight_count = (self._auxiliary_inflight_count or 0) + 1
			operation_report("phase3_fast_upgrade_started", {
				gear_id = gear_id,
			})

			local function settle_fast_entry()
				if entry.settled then
					return false
				end

				entry.settled = true
				if phase3.fast_upgrade_inflight[gear_id] == entry then
					phase3.fast_upgrade_inflight[gear_id] = nil
					phase3.fast_upgrade_inflight_count = math.max(0, phase3.fast_upgrade_inflight_count - 1)
				end
				self._auxiliary_inflight_count = math.max(0, (self._auxiliary_inflight_count or 0) - 1)

				if self._reconciliation_required and not self._operation_inflight and self._auxiliary_inflight_count == 0 and self._view_is_valid then
					self._phase = "operation_reconciliation_required"
					self:_schedule_probe("auxiliary_operation_settled")
				end
				release_account_operation_if_settled()

				return true
			end

			local chain_ok, chain_error = pcall(function ()
				return promise:next(function (result)
					if not settle_fast_entry() then
						return result
					end

					if generation ~= self._generation or self._phase3 ~= phase3 or not phase3.running or not operation_context_valid(generation) then
						return result
					end

					phase3.fast_upgrade_states[gear_id] = "complete"
					candidate.rarity = math.max(tonumber(candidate.rarity) or 0, REDEEMED_RARITY)
					local completed_at = clock_now()
					local duration = completed_at and entry.started_at and math.max(0, completed_at - entry.started_at) or entry.elapsed
					record_timing("phase3_fast_upgrade", duration)
					operation_report("phase3_fast_upgrade_complete", {
						duration = duration,
						gear_id = gear_id,
					})
					self:_phase3_pump_fast_upgrades(generation)
					self:_phase3_resume_after_fast_upgrades(generation)

					return result
				end):catch(function (error_value)
					if settle_fast_entry() and generation == self._generation and self._phase3 == phase3 and phase3.running then
						self:_abort_for_auxiliary_failure(generation, string.format("fast fodder rarity upgrade failed for gear %s: %s", tostring(gear_id), error_description(error_value)))
					end

					return error_value
				end)
			end)

			if not chain_ok then
				self:_abort_for_auxiliary_failure(generation, chain_error)

				return false
			end
		end

		return true
	end

	function self:_phase3_queue_fast_upgrade(generation, candidate)
		local phase3 = self._phase3

		if not phase3 or not phase3.running or not candidate or candidate.gear_id == nil then
			return false
		end

		phase3.fast_upgrade_states = phase3.fast_upgrade_states or {}

		if phase3.fast_upgrade_states[candidate.gear_id] then
			return true
		end

		if tonumber(candidate.rarity) and candidate.rarity >= REDEEMED_RARITY then
			phase3.fast_upgrade_states[candidate.gear_id] = "complete"

			return true
		end

		phase3.fast_upgrade_states[candidate.gear_id] = "queued"
		phase3.fast_upgrade_queue = phase3.fast_upgrade_queue or {}
		phase3.fast_upgrade_queue[#phase3.fast_upgrade_queue + 1] = candidate

		return self:_phase3_pump_fast_upgrades(generation)
	end

	function self:_refresh_after_operation(generation, callback, scope)
		if not operation_context_valid(generation) or self._operation_inflight then
			return false
		end

		local backend = self._backend

		local refresh_method

		if backend and scope == "runtime" and type(backend.refresh_runtime_snapshot) == "function" then
			refresh_method = backend.refresh_runtime_snapshot
		elseif backend and scope ~= "full" and type(backend.refresh_gear_snapshot) == "function" then
			refresh_method = backend.refresh_gear_snapshot
		elseif backend and type(backend.probe_snapshot) == "function" then
			refresh_method = backend.probe_snapshot
		end

		if type(refresh_method) ~= "function" then
			self:_operation_failed(generation, "backend probe unavailable after mutation")

			return false
		end

		return self:_dispatch_operation(generation, "authoritative_refresh", function ()
			if refresh_method == backend.probe_snapshot then
				return refresh_method(backend)
			end

			return refresh_method(backend, self._snapshot)
		end, function (snapshot)
			local character_id = current_character_id()

			if not snapshot_matches_character(snapshot, character_id) or self._run_character_id ~= nil and character_id ~= self._run_character_id then
				self:_operation_failed(generation, "active character changed during authoritative refresh")

				return
			end

			self._snapshot = snapshot
			self._last_probe_at = type(self._clock.now) == "function" and self._clock:now() or nil
			self._probe_count = self._probe_count + 1
			if self._view_is_valid and self._active_view then
				self:_refresh_plan("operation_refresh")
			end
			callback(snapshot)
		end)
	end

	function self:_poll_purchase_confirmation()
		local confirmation = self._purchase_confirmation
		local generation = self._generation

		if not confirmation or self._operation_inflight or not operation_context_valid(generation) then
			return false
		end

		confirmation.attempts = confirmation.attempts + 1
		confirmation.elapsed = 0
		operation_report("purchase_confirmation_poll", {
			attempt = confirmation.attempts,
			gear_id = confirmation.gear_id,
		})

		return self:_refresh_after_operation(generation, function (snapshot)
			if self._purchase_confirmation ~= confirmation then
				return
			end

			local gear = snapshot and snapshot.gear
			local candidate = find_item(gear and gear.items, confirmation.gear_id, gear and gear.items_by_id)

			if candidate and candidate.available == true then
				self._purchase_confirmation = nil
				operation_report("purchase_confirmation_complete", {
					attempt = confirmation.attempts,
					candidate = candidate,
				})
				confirmation.on_confirmed(candidate)

				return
			end

			if confirmation.attempts >= MAX_PURCHASE_CONFIRMATION_ATTEMPTS then
				self._purchase_confirmation = nil
				self:_operation_failed(generation, string.format(
					"purchased weapon %s was not found after %s authoritative inventory refreshes; purchase was confirmed and will not be repeated",
					tostring(confirmation.gear_id),
					tostring(confirmation.attempts)
				))

				return
			end

			confirmation.wait = purchase_confirmation_poll_delay(confirmation.attempts)
			self._phase = "purchase_confirmation_wait"
			operation_report("purchase_confirmation_pending", {
				attempt = confirmation.attempts,
				gear_id = confirmation.gear_id,
			})
		end)
	end

	function self:_begin_purchase_confirmation(generation, purchase_candidate, on_confirmed)
		if not operation_context_valid(generation) or self._purchase_confirmation then
			return false
		end

		self._purchase_confirmation = {
			attempts = 0,
			elapsed = 0,
			gear_id = purchase_candidate.gear_id,
			on_confirmed = on_confirmed,
			wait = 0,
		}

		return self:_poll_purchase_confirmation()
	end

	local function invalidate_generation()
		self._generation = self._generation + 1
		self._probe_scheduled = false
		self._probe_elapsed = 0
		self._purchase_confirmation = nil
	end

	local function cancel_probe()
		local promise = self._probe_promise

		if promise and type(promise.cancel) == "function" then
			pcall(promise.cancel, promise)
		end

		self._probe_sequence = self._probe_sequence + 1
		self._probe_inflight = false
		self._probe_promise = nil
		self._probe_request_elapsed = 0
	end

	local function cancel_catalog()
		local promise = self._catalog_promise

		if promise and type(promise.cancel) == "function" then
			pcall(promise.cancel, promise)
		end

		self._catalog_generation = self._catalog_generation + 1
		self._catalog_inflight = false
		self._catalog_promise = nil
		self._catalog_elapsed = 0
	end

	function self:_schedule_catalog(reason)
		if not self._snapshot or not self._view_is_valid then
			return false
		end

		local target = self:_selected_offer_summary()
		local key = offer_key(target)

		if not key then
			cancel_catalog()
			self._catalog = nil
			self._catalog_key = nil
			self:_refresh_plan("catalog_target_missing")

			return false
		end

		if key == self._catalog_key and (self._catalog_inflight or self._catalog) then
			return true
		end

		cancel_catalog()
		self._catalog = nil
		self._catalog_key = key
		self._catalog_inflight = true
		self._catalog_elapsed = 0
		self._phase = "trait_discovery"
		report("catalog_discovery_started", {
			reason = reason or "target_changed",
			target = target,
		})

		local backend = self._backend

		if not backend or type(backend.discover_weapon_catalog) ~= "function" then
			self._catalog_inflight = false
			self._catalog_elapsed = 0
			self._catalog = {
				available = false,
				reason = "weapon trait discovery adapter unavailable",
			}
			self:_refresh_plan("catalog_failed")
			report("catalog_discovery_failed", {
				error = self._catalog.reason,
			})

			return false
		end

		local generation = self._catalog_generation
		local call_ok, promise = safe_call(backend.discover_weapon_catalog, backend, target)

		if not call_ok or not promise or type(promise.next) ~= "function" or type(promise.catch) ~= "function" then
			self._catalog_inflight = false
			self._catalog_elapsed = 0
			self._catalog = {
				available = false,
				reason = call_ok and "backend returned no Promise" or tostring(promise),
			}
			self:_refresh_plan("catalog_failed")
			report("catalog_discovery_failed", {
				error = self._catalog.reason,
			})

			return false
		end

		self._catalog_promise = promise

		local chain_ok, chain = pcall(function ()
			return promise:next(function (catalog)
				if generation ~= self._catalog_generation or not self._view_is_valid or key ~= offer_key(self:_selected_offer_summary()) then
					return catalog
				end

				self._catalog_inflight = false
				self._catalog_elapsed = 0
				self._catalog_promise = nil
				self._catalog = type(catalog) == "table" and catalog or {
					available = false,
					reason = "weapon trait discovery returned malformed data",
				}
				self._phase = self._catalog.available == true and "probe_complete" or "trait_discovery_failed"
				self:_refresh_plan("catalog_complete")
				report("catalog_discovery_complete", {
					catalog = self._catalog,
					target = target,
				})

				return catalog
			end):catch(function (error_value)
				if generation ~= self._catalog_generation then
					return error_value
				end

				self._catalog_inflight = false
				self._catalog_elapsed = 0
				self._catalog_promise = nil
				self._catalog = {
					available = false,
					reason = tostring(error_value),
				}
				self._phase = "trait_discovery_failed"
				self:_refresh_plan("catalog_failed")
				report("catalog_discovery_failed", {
					error = self._catalog.reason,
					target = target,
				})

				return error_value
			end)
		end)

		if chain_ok then
			self._catalog_promise = chain
		else
			self._catalog_inflight = false
			self._catalog_elapsed = 0
			self._catalog_promise = nil
			self._catalog = {
				available = false,
				reason = tostring(chain),
			}
			self:_refresh_plan("catalog_failed")
			report("catalog_discovery_failed", {
				error = self._catalog.reason,
			})
		end

		return chain_ok
	end

	function self:_schedule_probe(reason)
		if not probe_enabled() or not self._view_is_valid or self._probe_inflight then
			return false
		end

		self._probe_elapsed = 0
		self._probe_scheduled = true
		self._phase = "probe_scheduled"
		self._last_error = nil
		report("probe_scheduled", {
			reason = reason or "view_ready",
		})

		return true
	end

	function self:_finish_probe(generation, probe_sequence, snapshot)
		if generation ~= self._generation or probe_sequence ~= self._probe_sequence then
			return
		end

		local character_id = current_character_id()

		if not snapshot_matches_character(snapshot, character_id) then
			self:_fail_probe(generation, probe_sequence, "active character changed during probe")

			return
		end

		self._probe_inflight = false
		self._probe_promise = nil
		self._probe_request_elapsed = 0
		self._probe_scheduled = false
		self._phase = "probe_complete"
		self._snapshot = snapshot
		self._reconciliation_required = false
		self._last_error = nil
		self._last_probe_at = type(self._clock.now) == "function" and self._clock:now() or nil
		self._probe_count = self._probe_count + 1
		self:_refresh_plan("probe_complete")
		self:_schedule_catalog("probe_complete")
		report("probe_complete", snapshot)
	end

	function self:_fail_probe(generation, probe_sequence, error_value)
		if generation ~= self._generation or probe_sequence ~= self._probe_sequence then
			return
		end

		self._probe_inflight = false
		self._probe_promise = nil
		self._probe_request_elapsed = 0
		self._probe_scheduled = false
		self._phase = "probe_failed"
		self._last_error = error_value
		report("probe_failed", {
			error = error_value,
		})
		log("error", "Auto Crafter read-only probe failed: " .. tostring(error_value))
	end

	function self:_start_probe()
		if self._probe_inflight or self._operation_inflight or (self._auxiliary_inflight_count or 0) > 0 or not self._view_is_valid or not probe_enabled() then
			return false
		end

		local backend = self._backend
		self._probe_sequence = self._probe_sequence + 1
		local probe_sequence = self._probe_sequence

		if not backend or type(backend.probe_snapshot) ~= "function" then
			self:_fail_probe(self._generation, probe_sequence, "backend probe unavailable")

			return false
		end

		local generation = self._generation
		local call_ok, promise = safe_call(backend.probe_snapshot, backend)

		if not call_ok or not promise or type(promise.next) ~= "function" or type(promise.catch) ~= "function" then
			self:_fail_probe(generation, probe_sequence, call_ok and "backend returned no Promise" or promise)

			return false
		end

		self._probe_inflight = true
		self._probe_scheduled = false
		self._phase = "probe_inflight"
		self._probe_promise = promise
		self._probe_request_elapsed = 0
		report("probe_started", {})

		local chain_ok, chain = pcall(function()
			return promise:next(function(snapshot)
				self:_finish_probe(generation, probe_sequence, snapshot)

				return snapshot
			end):catch(function(error_value)
				self:_fail_probe(generation, probe_sequence, error_value)

				return error_value
			end)
		end)

		if not chain_ok then
			self:_fail_probe(generation, probe_sequence, chain)
		else
			self._probe_promise = chain
		end

		return true
	end

	function self:_stop_search(reason, candidate)
		local search = self._search
		local phase3 = self._phase3
		local result = candidate or search and search.result

		if phase3 and phase3.target_candidate then
			result = phase3.target_candidate
		end

		if search then
			search.running = false
			search.result = result or search.best

			if not result and setting("auto_crafter_best_candidate_fallback", true) ~= true then
				search.result = nil
			end
		end

		if phase3 and phase3.running then
			phase3.running = false
			phase3.stop_reason = reason or "search_stopped"
			operation_report("phase3_stopped", {
				candidate = phase3.target_candidate,
				reason = reason or "search_stopped",
				search = search,
			})
		end

		self._phase = reason or "search_stopped"
		operation_report("purchase_search_stopped", {
			candidate = candidate or search and search.best,
			reason = reason or "search_stopped",
			search = search,
		})
		release_account_operation_if_settled()
	end

	function self:_stop_active_run(reason)
		local search = self._search
		local phase3 = self._phase3
		local mastery = self._mastery
		local phase4 = self._phase4
		local active = search and search.running or phase3 and phase3.running or phase4 and phase4.running or mastery and mastery.running

		if not active then
			return false
		end

		invalidate_generation()

		if search then
			search.running = false

			if phase3 and phase3.target_candidate then
				search.result = phase3.target_candidate
			end
		end

		if phase3 then
			phase3.running = false
			phase3.stop_reason = reason
		end

		if mastery then
			mastery.running = false
		end

		if phase4 then
			phase4.running = false
		end

		self._phase = reason
		self._frozen_run_settings = nil
		operation_report("purchase_search_stopped", {
			candidate = phase3 and phase3.target_candidate or search and search.result,
			reason = reason,
			search = search,
		})

		if phase3 then
			operation_report("phase3_stopped", {
				candidate = phase3.target_candidate,
				reason = reason,
				search = search,
			})
		end
		release_account_operation_if_settled()

		return true
	end

	function self:_candidate_is_better(candidate, current)
		if not candidate then
			return false
		end

		if not current then
			return true
		end

		local target = tonumber(self._search and self._search.target_dump) or 60
		local candidate_distance = math.abs((tonumber(candidate.dump_stat) or 0) - target)
		local current_distance = math.abs((tonumber(current.dump_stat) or 0) - target)

		if candidate_distance ~= current_distance then
			return candidate_distance < current_distance
		end

		return (tonumber(candidate.damage) or 0) > (tonumber(current.damage) or 0)
	end

	function self:_phase3_stop(reason, current)
		local phase3 = self._phase3
		local search = self._search

		if phase3 then
			phase3.running = false
			phase3.current = current or phase3.current
			phase3.stop_reason = reason or "phase3_stopped"
		end

		if self._mastery and self._mastery.phase3 then
			self._mastery.running = false
		end

		if search then
			search.running = false

			if phase3 and phase3.target_candidate then
				search.result = phase3.target_candidate
			end
		end

		self._phase = reason or "phase3_stopped"
		operation_report("phase3_stopped", {
			candidate = phase3 and phase3.target_candidate,
			current = current,
			reason = reason or "phase3_stopped",
			search = search,
		})
	end

	local function catalog_choice(catalog, value, current_trait, excluded_id, is_perk)
		if value == "keep" then
			return nil
		end

		local explicit = is_perk and parse_perk_target(value) or nil

		for _, entry in ipairs(catalog or {}) do
			local highest = entry.tier

			if not is_perk then
				for _, tier in ipairs(entry.tiers or {}) do
					highest = math.max(tonumber(highest) or 0, tonumber(tier.tier) or 0)
				end
			end

			local matches_explicit = explicit and entry.id == explicit.id and tonumber(highest) == tonumber(explicit.rarity)
			local matches_blessing = not is_perk and value ~= "auto" and entry.id == value
			local matches_auto = value == "auto" and entry.id ~= excluded_id and (not current_trait or entry.id ~= current_trait.id)

			if matches_explicit or matches_blessing or matches_auto then
				return {
					id = entry.id,
					rarity = explicit and explicit.rarity or tonumber(highest),
				}
			end
		end

		return nil
	end

	function self:_phase4_targets(item)
		local catalog = self._search and self._search.catalog or self._catalog
		local mastery_enabled = setting("auto_crafter_level_mastery_20", true) == true
		local allocate_mastery = mastery_enabled and setting("auto_crafter_allocate_mastery_points", true) == true
		local change_perks = mastery_enabled and setting("auto_crafter_change_perks", true) == true
		local change_blessings = mastery_enabled and setting("auto_crafter_change_blessings", true) == true

		if type(catalog) ~= "table" or catalog.available ~= true then
			return nil, "weapon perk/blessing catalogue unavailable"
		end

		local targets = {
			perks = {},
			traits = {},
		}
		local perk_values = {
			setting("auto_crafter_perk_1_target"),
			setting("auto_crafter_perk_2_target"),
		}
		local blessing_values = {
			setting("auto_crafter_blessing_1_target"),
			setting("auto_crafter_blessing_2_target"),
		}

		if change_perks then
			for index = 1, 2 do
				local excluded = targets.perks[index == 1 and 2 or 1]
				local peer_index = index == 1 and 2 or 1
				local kept_peer = perk_values[peer_index] == "keep" and trait_at(item.perks, peer_index) or nil
				targets.perks[index] = catalog_choice(catalog.perks, perk_values[index], trait_at(item.perks, index), excluded and excluded.id or kept_peer and kept_peer.id, true)

				if perk_values[index] ~= "keep" and not targets.perks[index] then
					return nil, "selected Tier IV perk target is unavailable"
				end
			end
		end

		if change_blessings then
			for index = 1, 2 do
				local excluded = targets.traits[index == 1 and 2 or 1]
				local peer_index = index == 1 and 2 or 1
				local kept_peer = blessing_values[peer_index] == "keep" and trait_at(item.traits, peer_index) or nil
				targets.traits[index] = catalog_choice(catalog.blessings, blessing_values[index], trait_at(item.traits, index), excluded and excluded.id or kept_peer and kept_peer.id, false)

				if blessing_values[index] ~= "keep" and not targets.traits[index] then
					return nil, "selected blessing target is unavailable"
				end
			end
		end

		if targets.perks[1] and targets.perks[2] and targets.perks[1].id == targets.perks[2].id then
			return nil, "perk targets must be different"
		end
		if targets.perks[1] and perk_values[2] == "keep" and targets.perks[1].id == (trait_at(item.perks, 2) or {}).id or targets.perks[2] and perk_values[1] == "keep" and targets.perks[2].id == (trait_at(item.perks, 1) or {}).id then
			return nil, "selected perk duplicates a kept perk"
		end

		if targets.traits[1] and targets.traits[2] and targets.traits[1].id == targets.traits[2].id then
			return nil, "blessing targets must be different"
		end
		if targets.traits[1] and blessing_values[2] == "keep" and targets.traits[1].id == (trait_at(item.traits, 2) or {}).id or targets.traits[2] and blessing_values[1] == "keep" and targets.traits[2].id == (trait_at(item.traits, 1) or {}).id then
			return nil, "selected blessing duplicates a kept blessing"
		end

		return targets
	end

	function self:_phase4_complete(item, snapshot)
		local phase4 = self._phase4

		if not phase4 or not phase4.running then
			return false
		end

		local completed_at = clock_now()
		local elapsed = completed_at and self._run_started_at and math.max(0, completed_at - self._run_started_at) or math.max(0, self._run_elapsed or 0)
		local resource_costs = wallet_consumption(self._search and self._search.start_wallet, wallet_values(snapshot or self._snapshot))

		phase4.running = false
		phase4.result = item
		phase4.completed_at = completed_at
		phase4.elapsed_seconds = elapsed
		phase4.resource_costs = resource_costs
		if self._search then
			self._search.running = false
			self._search.result = item
			self._search.elapsed_seconds = elapsed
		end
		self._phase = "phase4_complete"
		operation_report("phase4_complete", {
			candidate = item,
			elapsed_seconds = elapsed,
			phase4 = phase4,
			resource_costs = resource_costs,
		})
		release_account_operation_if_settled()

		return true
	end

	function self:_phase4_step(generation, snapshot)
		local phase4 = self._phase4
		local backend = self._backend
		local item = phase4 and find_item(snapshot and snapshot.gear and snapshot.gear.items, phase4.gear_id)

		if not phase4 or not phase4.running then
			return false
		end

		if phase4.pending_blessing then
			return true
		end

		if not item or item.available ~= true or item.parent_pattern ~= phase4.mastery_id or tonumber(candidate_stat(item, phase4.dump_stat)) ~= tonumber(phase4.target_dump) then
			self:_operation_failed(generation, "final weapon failed authoritative identity or level-500 stat verification")

			return false
		end

		phase4.current_item = item

		if phase4.consecrate and (tonumber(item.rarity) or -1) < TRANSCENDENT_RARITY then
			if not backend or type(backend.upgrade_weapon_rarity) ~= "function" then
				self:_operation_failed(generation, "final rarity upgrade adapter unavailable")
				return false
			end

			local before = tonumber(item.rarity) or -1
			return self:_dispatch_operation(generation, "phase4_consecrate", function ()
				return backend:upgrade_weapon_rarity(phase4.gear_id)
			end, function ()
				self:_refresh_after_operation(generation, function (updated)
					local upgraded = find_item(updated and updated.gear and updated.gear.items, phase4.gear_id)

					if not upgraded or (tonumber(upgraded.rarity) or -1) <= before then
						self:_operation_failed(generation, "final rarity upgrade was not confirmed")
						return
					end
					self:_phase4_step(generation, updated)
				end)
			end)
		end

		local expertise = tonumber(item.expertise_level)

		if phase4.expertise and (expertise == nil or expertise < MAX_EXPERTISE_LEVEL) then
			if expertise == nil then
				self:_operation_failed(generation, "final weapon expertise is unavailable")
				return false
			end

			if not backend or type(backend.add_weapon_expertise) ~= "function" then
				self:_operation_failed(generation, "weapon expertise adapter unavailable")
				return false
			end

			local target_level = math.min(MAX_EXPERTISE_LEVEL, (math.floor(expertise / 100) + 1) * 100)

			return self:_dispatch_operation(generation, "phase4_expertise", function ()
				return backend:add_weapon_expertise(phase4.gear_id, target_level)
			end, function ()
				self:_refresh_after_operation(generation, function (updated)
					local upgraded = find_item(updated and updated.gear and updated.gear.items, phase4.gear_id)

					if not upgraded or (tonumber(upgraded.expertise_level) or -1) < target_level then
						self:_operation_failed(generation, "weapon level milestone was not confirmed")
						return
					end
					operation_report("phase4_expertise_milestone", {
						candidate = upgraded,
						level = tonumber(upgraded.expertise_level),
					})
					self:_phase4_step(generation, updated)
				end)
			end)
		end

		if not phase4.replacement_baseline then
			phase4.replacement_baseline = {
				perks = { trait_at(item.perks, 1), trait_at(item.perks, 2) },
				traits = { trait_at(item.traits, 1), trait_at(item.traits, 2) },
			}
		else
			for _, group in ipairs({ "perks", "traits" }) do
				for index = 1, 2 do
					if not same_optional_trait(trait_at(item[group], index), phase4.replacement_baseline[group][index]) then
						self:_operation_failed(generation, "final weapon perks or blessings changed outside the active run")
						return false
					end
				end
			end
		end

		local blessing_targets_pending = false

		for index = 1, 2 do
			local desired = phase4.targets.traits[index]

			if desired and sticker_status(phase4.sticker_book, desired.id, desired.rarity) ~= "seen" then
				blessing_targets_pending = true
			end
		end

		local blessing_points_spent, blessing_points_total, unseen_blessing_tiers = mastery_allocation_progress(phase4.sticker_book, phase4.mastery_costs)
		phase4.blessing_points_spent = blessing_points_spent
		phase4.blessing_points_total = blessing_points_total
		phase4.blessing_tiers_remaining = unseen_blessing_tiers

		if blessing_targets_pending or phase4.allocate_mastery and unseen_blessing_tiers > 0 then
			if not phase4.allocate_mastery then
				self:_operation_failed(generation, "selected blessing tier is not allocated in mastery")
				return false
			end

			if not backend or type(backend.purchase_mastery_traits) ~= "function" or type(backend.get_trait_sticker_book) ~= "function" or type(backend.get_mastery_trait_costs) ~= "function" then
				self:_operation_failed(generation, "mastery blessing allocation adapter unavailable")
				return false
			end

			local operations, allocation_error = mastery_allocation_operations(phase4.sticker_book, phase4.targets.traits, phase4.mastery_costs)

			if not operations or #operations == 0 then
				self:_operation_failed(generation, allocation_error or "mastery blessing allocation prerequisites could not be resolved")
				return false
			end

			self._phase = "phase4_allocate_blessing_batch"
			phase4.blessing_operations_pending = #operations

			return self:_dispatch_operation(generation, "phase4_allocate_blessing_batch", function ()
				return backend:purchase_mastery_traits(phase4.mastery_id, operations)
			end, function ()
				phase4.pending_blessing = {
					operations = operations,
				}
				phase4.blessing_poll_attempts = 0
				phase4.blessing_poll_elapsed = 0
				phase4.blessing_poll_wait = blessing_poll_delay(0)
				self._phase = "phase4_blessing_sync"
				operation_report("phase4_blessing_allocation_batch_submitted", {
					count = #operations,
				})
			end)
		end

		local replacement_groups = {
			{ adapter = "replace_perk", current = item.perks, kind = "perk", source = "perks", targets = phase4.targets.perks },
			{ adapter = "replace_blessing", current = item.traits, kind = "blessing", source = "traits", targets = phase4.targets.traits },
		}

		for _, group in ipairs(replacement_groups) do
			local replacement_index
			local replacement_target
			local temporary_swap = false

			for index = 1, 2 do
				local desired = group.targets[index]
				local current = trait_at(group.current, index)

				if desired and not same_trait(current, desired) then
					local peer = trait_at(group.current, index == 1 and 2 or 1)

					-- Free an occupied desired trait first. Example: current [Stamina,
					-- Carapace], desired [Carapace, Unyielding] must replace slot 2
					-- before slot 1 or Darktide may reject a transient duplicate.
					if not peer or peer.id ~= desired.id then
						replacement_index = index
						break
					end
				end
			end

			if not replacement_index then
				for index = 1, 2 do
					local desired = group.targets[index]
					local current = trait_at(group.current, index)

					if desired and not same_trait(current, desired) then
						replacement_target = temporary_swap_trait(group.kind, group.current, group.targets, phase4.catalog, phase4.sticker_book)

						if not replacement_target then
							self:_operation_failed(generation, group.kind .. " two-slot swap has no safe temporary target")
							return false
						end

						replacement_index = index
						temporary_swap = true
						break
					end
				end
			end

			if replacement_index then
				local index = replacement_index
				local desired = replacement_target or group.targets[index]
				local adapter = backend and backend[group.adapter]

				if type(adapter) ~= "function" then
					self:_operation_failed(generation, group.kind .. " replacement adapter unavailable")
					return false
				end

				if temporary_swap then
					operation_report("phase4_temporary_swap_started", {
						gear_id = phase4.gear_id,
						kind = group.kind,
					})
				end

				return self:_dispatch_operation(generation, temporary_swap and "phase4_temporary_swap_" .. group.kind or "phase4_replace_" .. group.kind, function ()
					return adapter(backend, phase4.gear_id, index, desired.id, desired.rarity)
				end, function ()
					self:_refresh_after_operation(generation, function (updated)
						local changed = find_item(updated and updated.gear and updated.gear.items, phase4.gear_id)
						local changed_traits = changed and (group.kind == "perk" and changed.perks or changed.traits)

						if not same_trait(trait_at(changed_traits, index), desired) then
							self:_operation_failed(generation, group.kind .. " replacement was not confirmed")
							return
						end
						phase4.replacement_baseline[group.source][index] = desired
						self:_phase4_step(generation, updated)
					end)
				end)
			end
		end

		if not phase4.final_reconcile_started then
			phase4.final_reconcile_started = true
			self._phase = "phase4_final_reconcile"

			return self:_refresh_after_operation(generation, function (updated_snapshot)
				local completed_item = find_item(updated_snapshot and updated_snapshot.gear and updated_snapshot.gear.items, phase4.gear_id)

				if not completed_item or completed_item.available ~= true then
					self:_operation_failed(generation, "final crafted weapon was not found during authoritative reconciliation")

					return
				end

				self:_phase4_complete(completed_item, updated_snapshot)
			end, "runtime")
		end

		return false
	end

	function self:_poll_phase4_blessing()
		local phase4 = self._phase4
		local pending = phase4 and phase4.pending_blessing
		local generation = self._generation
		local backend = self._backend

		if not phase4 or not phase4.running or not pending or self._operation_inflight then
			return false
		end

		if not backend or type(backend.get_trait_sticker_book) ~= "function" then
			self:_operation_failed(generation, "fresh blessing sticker-book adapter unavailable")
			return false
		end

		phase4.blessing_poll_elapsed = 0

		return self:_dispatch_operation(generation, "phase4_verify_blessing", function ()
			return backend:get_trait_sticker_book(phase4.trait_category, true)
		end, function (sticker_book)
			phase4.sticker_book = sticker_book

			local all_seen = true

			for _, operation in ipairs(pending.operations or {}) do
				if sticker_status(sticker_book, operation.trait_id, operation.rarity) ~= "seen" then
					all_seen = false
					break
				end
			end

			if all_seen then
				phase4.pending_blessing = nil
				phase4.blessing_operations_pending = 0
				phase4.blessing_poll_attempts = 0
				phase4.blessing_poll_wait = blessing_poll_delay(0)
				phase4.blessing_points_spent, phase4.blessing_points_total, phase4.blessing_tiers_remaining = mastery_allocation_progress(sticker_book, phase4.mastery_costs)
				operation_report("phase4_blessing_allocation_confirmed", {
					points_spent = phase4.blessing_points_spent,
					points_total = phase4.blessing_points_total,
					count = #(pending.operations or {}),
				})
				self:_phase4_step(generation, self._snapshot)
				return
			end

			phase4.blessing_poll_attempts = (phase4.blessing_poll_attempts or 0) + 1

			if phase4.blessing_poll_attempts >= MAX_BLESSING_SYNC_ATTEMPTS then
				self:_operation_failed(generation, "mastery blessing allocation did not synchronize after bounded polling")
				return
			end

			phase4.blessing_poll_wait = blessing_poll_delay(phase4.blessing_poll_attempts)
			self._phase = "phase4_blessing_sync"
		end)
	end

	function self:_start_phase4(candidate)
		if not candidate or not candidate.gear_id then
			self:_operation_failed(self._generation, "final crafting candidate unavailable")
			return false
		end

		local consecrate = setting("auto_crafter_consecrate_transcendent", true) == true
		local expertise_enabled = setting("auto_crafter_upgrade_expertise_500", true) == true
		local mastery_enabled = setting("auto_crafter_level_mastery_20", true) == true
		local allocate_mastery = mastery_enabled and setting("auto_crafter_allocate_mastery_points", true) == true
		local change_perks = mastery_enabled and setting("auto_crafter_change_perks", true) == true
		local change_blessings = mastery_enabled and setting("auto_crafter_change_blessings", true) == true

		local item = find_item(self._snapshot and self._snapshot.gear and self._snapshot.gear.items, candidate.gear_id)

		if not item or item.available ~= true then
			self:_operation_failed(self._generation, "final crafting candidate is absent from authoritative inventory")
			return false
		end

		if not consecrate and not expertise_enabled and not allocate_mastery and not change_perks and not change_blessings then
			self._phase4 = {
				gear_id = candidate.gear_id,
				running = true,
			}

			return self:_phase4_complete(item, self._snapshot)
		end

		local needs_traits = allocate_mastery or change_perks or change_blessings
		local targets = { perks = {}, traits = {} }

		if needs_traits then
			local error_value
			targets, error_value = self:_phase4_targets(item)

			if not targets then
				self:_operation_failed(self._generation, error_value)
				return false
			end
		end

		local catalog = self._search and self._search.catalog or self._catalog
		local function validate_swap_preflight(sticker_book)
			for _, group in ipairs({
				{ current = item.perks, kind = "perk", targets = targets.perks },
				{ current = item.traits, kind = "blessing", targets = targets.traits },
			}) do
				if requires_temporary_swap(group.current, group.targets) and not temporary_swap_trait(group.kind, group.current, group.targets, catalog, sticker_book) then
					self:_operation_failed(self._generation, group.kind .. " two-slot swap has no safe temporary target; no final crafting materials were spent")

					return false
				end
			end

			return true
		end

		self._phase4 = {
			allocate_mastery = allocate_mastery,
			blessing_poll_attempts = 0,
			blessing_poll_elapsed = 0,
			blessing_poll_wait = blessing_poll_delay(0),
			catalog = catalog,
			consecrate = consecrate,
			dump_stat = self._search and self._search.dump_stat,
			expertise = expertise_enabled,
			gear_id = candidate.gear_id,
			mastery_id = candidate.mastery_id or candidate.parent_pattern,
			running = true,
			sticker_book = catalog and catalog.blessings or {},
			mastery_costs = nil,
			target_dump = self._search and self._search.target_dump,
			targets = targets,
			trait_category = catalog and catalog.trait_category,
		}
		self._phase = "phase4_preflight"
		operation_report("phase4_started", {
			candidate = candidate,
			phase4 = self._phase4,
		})

		return self:_refresh_after_operation(self._generation, function (snapshot)
			if allocate_mastery or next(targets.traits or {}) ~= nil then
				local backend = self._backend

				if not backend or type(backend.get_trait_sticker_book) ~= "function" or not self._phase4.trait_category then
					self:_operation_failed(self._generation, "fresh blessing sticker-book adapter unavailable")
					return
				end

				self:_dispatch_operation(self._generation, "phase4_sticker_preflight", function ()
					return backend:get_trait_sticker_book(self._phase4.trait_category, true)
				end, function (sticker_book)
					self._phase4.sticker_book = sticker_book

					if not validate_swap_preflight(sticker_book) then
						return
					end

					if not allocate_mastery or unseen_blessing_tier_count(sticker_book) == 0 then
						for _, target in pairs(targets.traits or {}) do
							if target and sticker_status(sticker_book, target.id, target.rarity) ~= "seen" then
								self:_operation_failed(self._generation, "selected blessing tier is not allocated in mastery")

								return
							end
						end

						self:_phase4_step(self._generation, snapshot)
						return
					end

					if type(backend.get_mastery_trait_costs) ~= "function" then
						self:_operation_failed(self._generation, "live mastery blessing cost adapter unavailable")
						return
					end

					self:_dispatch_operation(self._generation, "phase4_mastery_cost_preflight", function ()
						return backend:get_mastery_trait_costs()
					end, function (costs)
						self._phase4.mastery_costs = costs
						self:_phase4_step(self._generation, snapshot)
					end)
				end)
			else
				if not validate_swap_preflight(self._phase4.sticker_book) then
					return
				end

				self:_phase4_step(self._generation, snapshot)
			end
		end)
	end

	function self:_phase3_finish(current)
		local phase3 = self._phase3
		local search = self._search
		local target = phase3 and phase3.target_candidate
		local item = target and find_item(self._snapshot and self._snapshot.gear and self._snapshot.gear.items, target.gear_id)
		local authoritative_dump = candidate_stat(item, search and search.dump_stat)

		if not phase3 or not phase3.running or not target or not search then
			return false
		end

		phase3.current = current or phase3.current

		if mastery_target_reached(phase3.current) and not mastery_claims_converged(phase3.current) then
			if not phase3.current_data then
				self:_operation_failed(self._generation, "mastery level 20 reached but raw state is unavailable for missing tier claims")

				return false
			end

			return self:_phase3_sync_projected(self._generation)
		end

		if not item or item.available ~= true or item.parent_pattern ~= target.mastery_id or tonumber(authoritative_dump) ~= tonumber(target.dump_stat) then
			self:_operation_failed(self._generation, "Phase 3 target failed authoritative family or dump-stat reconciliation")

			return false
		end

		phase3.running = false
		search.running = false
		search.result = phase3.target_candidate
		self._phase = "phase3_complete"
		operation_report("phase3_complete", {
			candidate = phase3.target_candidate,
			current = phase3.current,
			fodder_count = phase3.fodder_count,
			search = search,
		})
		operation_report("phase3_timing_summary", {
			current = phase3.current,
			timings = self._operation_timings,
		})
		self:_start_phase4(phase3.target_candidate)

		return true
	end

	function self:_phase3_discard_deferred(generation, current)
		local phase3 = self._phase3
		local backend = self._backend

		if not phase3 or not phase3.running or not phase3.target_candidate then
			return false
		end

		if phase3.cleanup_started then
			return false
		end

		phase3.cleanup_started = true
		self._phase = "phase3_deferred_cleanup_preflight"

		return self:_refresh_after_operation(generation, function (snapshot)
			local target = phase3.target_candidate
			local queue = phase3.deferred_candidates or {}
			local cleanup_candidates = phase3.purchased_spares or queue
			local gear_ids = {}
			local included = {}

			for _, queued in ipairs(cleanup_candidates) do
				local item = queued and find_item(snapshot and snapshot.gear and snapshot.gear.items, queued.gear_id)

				if item and not included[item.gear_id] then
					if item.available ~= true or item.gear_id == target.gear_id or item.parent_pattern ~= target.mastery_id then
						if item.gear_id == target.gear_id then
							included[item.gear_id] = true
						else
							self:_operation_failed(generation, "run-owned spare cleanup failed authoritative family protection")

							return
						end
					else
						included[item.gear_id] = true
						gear_ids[#gear_ids + 1] = item.gear_id
					end
				end
			end

			if #gear_ids == 0 then
				phase3.deferred_index = #queue + 1
				self:_phase3_finish(current)

				return
			end

			if not backend or type(backend.discard_items) ~= "function" then
				self:_operation_failed(generation, "deferred weapon discard adapter unavailable")

				return
			end

			self:_dispatch_operation(generation, "phase3_deferred_cleanup", function ()
				return backend:discard_items(gear_ids)
			end, function ()
				self:_refresh_after_operation(generation, function (updated_snapshot)
					for _, gear_id in ipairs(gear_ids) do
						if find_item(updated_snapshot and updated_snapshot.gear and updated_snapshot.gear.items, gear_id) then
							self:_operation_failed(generation, "deferred weapon discard was not confirmed by authoritative inventory")

							return
						end
					end

					phase3.deferred_index = #queue + 1
					operation_report("phase3_deferred_cleanup_complete", {
						count = #gear_ids,
						current = current,
					})
					self:_phase3_finish(current)
				end)
			end)
		end)
	end

	function self:_phase3_process_deferred(generation, current)
		local phase3 = self._phase3

		if not phase3 or not phase3.running or not phase3.target_candidate then
			return false
		end

		if fast_upgrade_pending(phase3) then
			phase3.fast_purchase_paused = true
			self._phase = "phase3_fast_upgrade_wait"
			self:_phase3_pump_fast_upgrades(generation)

			return true
		end

		if mastery_target_reached(current) and phase3.projected_xp_pending then
			return self:_phase3_sync_projected(generation)
		elseif mastery_target_reached(current) then
			return self:_phase3_discard_deferred(generation, current)
		end

		local queue = phase3.deferred_candidates or {}

		if queue[phase3.deferred_index or 1] then
			return self:_phase3_start_deferred_batch(generation)
		end

		return self:_purchase_search_step(generation)
	end

	function self:_phase3_extract_deferred_batch(generation)
		local phase3 = self._phase3
		local backend = self._backend
		local batch = phase3 and phase3.deferred_batch

		if not phase3 or not phase3.running or not batch or #batch.gear_ids == 0 or not backend or type(backend.extract_weapon_mastery) ~= "function" then
			self:_operation_failed(generation, "deferred mastery extraction batch became invalid")

			return false
		end

		return self:_dispatch_operation(generation, "mastery_sacrifice_batch", function ()
			return backend:extract_weapon_mastery(batch.mastery_id, batch.gear_ids)
		end, function (result)
			local amount = tonumber(result and result.amount) or 0

			if amount <= 0 or not extraction_contains_all(result and result.gear_ids, batch.gear_ids) then
				self:_operation_failed(generation, "batched mastery extraction did not confirm every fodder item")

				return
			end

			local projected = type(backend.project_mastery) == "function" and backend:project_mastery(phase3.current_data, amount) or nil
			local current = mastery_summary(projected)

			if not projected or not current or current.current_xp == nil or current.mastery_level == nil then
				self:_operation_failed(generation, "local mastery projection failed after batched extraction")

				return
			end

			remove_snapshot_gear(self._snapshot, batch.gear_ids)
			phase3.current = current
			phase3.current_data = projected
			phase3.projected_xp_pending = true
			phase3.fodder_count = phase3.fodder_count + #batch.gear_ids
			phase3.deferred_index = batch.queue_end + 1
			phase3.deferred_batch = nil
			operation_report("phase3_fodder_batch_complete", {
				amount = amount,
				count = #batch.gear_ids,
				current = current,
				fodder_count = phase3.fodder_count,
			})

			if mastery_target_reached(current) then
				self:_phase3_sync_projected(generation)
			else
				self:_purchase_search_step(generation)
			end
		end)
	end

	function self:_phase3_upgrade_deferred_batch(generation)
		local phase3 = self._phase3
		local backend = self._backend
		local batch = phase3 and phase3.deferred_batch

		if not phase3 or not phase3.running or not batch then
			return false
		end

		local item = batch.items[batch.upgrade_index]

		if not item then
			return self:_phase3_extract_deferred_batch(generation)
		end

		if batch.upgrade_index == 1 and type(backend and backend.upgrade_weapon_rarities) == "function" then
			local gear_ids = {}

			for _, pending_item in ipairs(batch.items) do
				if tonumber(pending_item.rarity) == nil or pending_item.rarity < REDEEMED_RARITY then
					gear_ids[#gear_ids + 1] = pending_item.gear_id
				end
			end

			if #gear_ids == 0 then
				batch.upgrade_index = #batch.items + 1

				return self:_phase3_extract_deferred_batch(generation)
			end

			operation_report("phase3_fodder_batch_upgrade_started", {
				count = #gear_ids,
			})

			return self:_dispatch_operation(generation, "mastery_upgrade_batch", function ()
				return backend:upgrade_weapon_rarities(gear_ids)
			end, function ()
				for _, pending_item in ipairs(batch.items) do
					pending_item.rarity = math.max(tonumber(pending_item.rarity) or 0, REDEEMED_RARITY)
				end

				batch.upgrade_index = #batch.items + 1
				operation_report("phase3_fodder_batch_upgrade_complete", {
					count = #gear_ids,
				})
				self:_phase3_extract_deferred_batch(generation)
			end)
		end

		if tonumber(item.rarity) and item.rarity >= REDEEMED_RARITY then
			batch.upgrade_index = batch.upgrade_index + 1

			return self:_phase3_upgrade_deferred_batch(generation)
		end

		if not backend or type(backend.upgrade_weapon_rarity) ~= "function" then
			self:_operation_failed(generation, "batched fodder rarity upgrade adapter unavailable")

			return false
		end

		return self:_dispatch_operation(generation, "mastery_upgrade_batch_item", function ()
			return backend:upgrade_weapon_rarity(item.gear_id)
		end, function ()
			item.rarity = REDEEMED_RARITY
			batch.upgrade_index = batch.upgrade_index + 1
			self:_phase3_upgrade_deferred_batch(generation)
		end)
	end

	function self:_phase3_start_deferred_batch(generation)
		local phase3 = self._phase3

		if not phase3 or not phase3.running or not phase3.current_data or phase3.deferred_batch then
			return false
		end

		return self:_refresh_after_operation(generation, function (snapshot)
			local queue = phase3.deferred_candidates or {}
			local start_index = phase3.deferred_index or 1
			local items = {}
			local gear_ids = {}
			local queue_end = start_index - 1

			local target_xp = mastery_level_target_xp(phase3.current_data, 20)
			local projected_xp = tonumber(phase3.current and phase3.current.current_xp)

			for index = start_index, math.min(#queue, start_index + PHASE3_FODDER_BATCH_SIZE - 1) do
				local candidate = queue[index]
				local item = candidate and find_item(snapshot and snapshot.gear and snapshot.gear.items, candidate.gear_id)

				if item then
					if item.available ~= true or item.gear_id == phase3.target_candidate.gear_id or item.parent_pattern ~= phase3.target_candidate.mastery_id then
						self:_operation_failed(generation, "deferred mastery batch failed authoritative family protection")

						return
					end

					items[#items + 1] = item
					gear_ids[#gear_ids + 1] = item.gear_id
					local amount = estimated_fodder_xp(item)

					if projected_xp and amount then
						projected_xp = projected_xp + amount
					else
						projected_xp = nil
					end
				end

				queue_end = index

				if target_xp and projected_xp and projected_xp >= target_xp then
					break
				end
			end

			if #gear_ids == 0 then
				phase3.deferred_index = queue_end + 1
				self:_purchase_search_step(generation)

				return
			end

			phase3.deferred_batch = {
				gear_ids = gear_ids,
				items = items,
				mastery_id = phase3.target_candidate.mastery_id,
				queue_end = queue_end,
				upgrade_index = 1,
			}
			self._phase = "phase3_deferred_batch_upgrade"
			self:_phase3_upgrade_deferred_batch(generation)
		end)
	end

	function self:_phase3_sync_projected(generation)
		local phase3 = self._phase3
		local backend = self._backend
		local projected_data = phase3 and phase3.current_data
		local projected = mastery_summary(projected_data)

		if not phase3 or not phase3.running or not projected_data or not mastery_target_reached(projected) then
			self:_operation_failed(generation, "projected mastery level 20 state became unavailable before final claim")

			return false
		end

		if self._mastery and self._mastery.running then
			self:_operation_failed(generation, "projected mastery claim collided with an active mastery operation")

			return false
		end

		if not backend or type(backend.claim_mastery_levels) ~= "function" then
			self:_operation_failed(generation, "projected mastery claim adapter unavailable")

			return false
		end

		self._mastery = {
			before = phase3.authoritative_current or projected,
			expected_xp = projected.current_xp,
			mastery_id = projected.mastery_id or phase3.target_candidate and phase3.target_candidate.mastery_id,
			on_complete = function (current)
				local active = self._phase3

				self._mastery = nil

				if not active or not active.running then
					return
				end

				active.current = current
				active.current_data = nil
				active.projected_xp_pending = false

				if active.defer_bad_processing and active.target_candidate then
					self:_phase3_discard_deferred(generation, current)
				else
					self:_phase3_finish(current)
				end
			end,
			phase3 = true,
			claim_retries = 0,
			running = true,
		}
		self._phase = "phase3_mastery_claim"

		return self:_dispatch_operation(generation, "mastery_claim", function ()
			-- The projected object already contains the extraction XP, matching the
			-- vanilla sacrifice view's local update before it claims milestones.
			return backend:claim_mastery_levels(projected_data, 0)
		end, function (result)
			if self:_complete_mastery_sync(generation, mastery_summary(result), "claim_result") then
				return
			end

			self._mastery_poll_elapsed = 0
			self._mastery_poll_attempts = 0
			self._mastery_poll_wait = mastery_poll_delay(0)
			self._phase = "mastery_sync_wait"
			operation_report("mastery_sync_started", {
				expected_xp = projected.current_xp,
			})
		end)
	end

	function self:_phase3_start_fodder(generation, candidate)
		local phase3 = self._phase3

		if not phase3 or not phase3.running or not candidate or not candidate.gear_id or not candidate.mastery_id then
			self:_operation_failed(generation, "Phase 3 fodder candidate is missing gear or mastery identity")

			return false
		end

		if self._operation_inflight or self._mastery and self._mastery.running then
			return false
		end

		self._mastery = {
			candidate = candidate,
			claim_retries = 0,
			gear_id = candidate.gear_id,
			mastery_id = candidate.mastery_id,
			on_complete = function (current)
				local active_phase3 = self._phase3

				if not active_phase3 or not active_phase3.running then
					return
				end

				active_phase3.fodder_count = active_phase3.fodder_count + 1
				active_phase3.current = current
				operation_report("phase3_fodder_complete", {
					candidate = candidate,
					current = current,
					fodder_count = active_phase3.fodder_count,
				})
				self._mastery = nil

				if active_phase3.defer_bad_processing and active_phase3.target_candidate then
					self:_phase3_process_deferred(generation, current)
				elseif active_phase3.target_candidate and mastery_target_reached(current) then
					self:_phase3_sync_projected(generation)
				else
					self:_purchase_search_step(generation)
				end
			end,
			phase3 = true,
			running = true,
		}
		self._phase = "phase3_fodder_preflight"
		operation_report("phase3_fodder_started", {
			candidate = candidate,
			current = phase3.current,
		})

		local refreshed = self:_refresh_after_operation(generation, function (snapshot)
			self:_mastery_after_refresh(generation, snapshot)
		end)

		if not refreshed then
			if generation == self._generation and phase3.running then
				self:_operation_failed(generation, "Phase 3 fodder authoritative refresh could not start")
			end
		end

		return refreshed
	end

	function self:_phase3_check_mastery(generation, candidate)
		local phase3 = self._phase3
		local target = phase3 and (phase3.target_candidate or candidate)
		local backend = self._backend

		if not phase3 or not phase3.running or not target or not target.mastery_id then
			self:_operation_failed(generation, "Phase 3 mastery target identity is missing")

			return false
		end

		if not backend or type(backend.get_mastery_by_pattern) ~= "function" then
			self:_operation_failed(generation, "Phase 3 mastery read adapter is unavailable")

			return false
		end

		local function handle_mastery(data)
			local current = mastery_summary(data)
			local candidate_is_target = phase3.target_candidate and candidate and phase3.target_candidate.gear_id == candidate.gear_id

			if not current or current.mastery_level == nil then
				self:_operation_failed(generation, "Phase 3 authoritative mastery response omitted level data")

				return
			end

			phase3.current = current
			phase3.current_data = data
			if not phase3.projected_xp_pending then
				phase3.authoritative_current = current
			end
			operation_report("phase3_mastery_check_complete", {
				candidate = candidate,
				current = current,
			})

			if phase3.defer_bad_processing and phase3.target_candidate and candidate and not candidate_is_target then
				phase3.deferred_candidates[#phase3.deferred_candidates + 1] = candidate
				local projection_reaches_target, projected_xp = pending_fodder_reaches_target(phase3)
				operation_report("phase3_pending_fodder_projected", {
					count = pending_deferred_count(phase3),
					expected_xp = projected_xp,
				})

				if mastery_target_reached(current) then
					self:_phase3_discard_deferred(generation, current)
				elseif projection_reaches_target or pending_deferred_count(phase3) >= PHASE3_FODDER_BATCH_SIZE then
					self:_phase3_process_deferred(generation, current)
				else
					self:_purchase_search_step(generation)
				end
			elseif phase3.defer_bad_processing and phase3.target_candidate then
				self:_phase3_process_deferred(generation, current)
			elseif phase3.target_candidate and mastery_target_reached(current) then
				if phase3.projected_xp_pending then
					self:_phase3_sync_projected(generation)
				else
					self:_phase3_finish(current)
				end
			elseif candidate and not candidate_is_target and not mastery_target_reached(current) then
				if setting("auto_crafter_best_candidate_fallback", true) == true then
					local reserved = phase3.fallback_candidate

					if not reserved then
						phase3.fallback_candidate = candidate
						self:_purchase_search_step(generation)
					elseif self:_candidate_is_better(candidate, reserved) then
						phase3.fallback_candidate = candidate
						self:_phase3_start_fodder(generation, reserved)
					else
						self:_phase3_start_fodder(generation, candidate)
					end
				else
					if self._search and self._search.best == candidate then
						self._search.best = nil
					end

					self:_phase3_start_fodder(generation, candidate)
				end
			elseif phase3.target_candidate and phase3.fallback_candidate and not mastery_target_reached(current) then
				local fallback_candidate = phase3.fallback_candidate

				phase3.fallback_candidate = nil
				self:_phase3_start_fodder(generation, fallback_candidate)
			else
				self:_purchase_search_step(generation)
			end
		end

		if phase3.current_data then
			handle_mastery(phase3.current_data)

			return true
		end

		return self:_dispatch_operation(generation, "phase3_mastery_check", function ()
			return backend:get_mastery_by_pattern(target.mastery_id)
		end, handle_mastery)
	end

	function self:_accept_exact_candidate(generation, candidate, source)
		local search = self._search
		local backend = self._backend

		if not search or not search.running or not candidate or not candidate.gear_id then
			return false
		end

		candidate.dump_stat = candidate_stat(candidate, search.dump_stat)
		candidate.dump_stat_id = search.dump_stat
		candidate.dump_stat_label = candidate.base_stat_labels and candidate.base_stat_labels[search.dump_stat]
		candidate.damage = candidate.potential_damage or candidate_stat(candidate, "damage")
		candidate.exact_match = tonumber(candidate.dump_stat) == tonumber(search.target_dump)

		if not candidate.exact_match then
			return false
		end

		local function continue_exact_match()
			search.result = candidate
			search.last = candidate
			search.best = candidate

			if self._phase3 and self._phase3.running then
				self._phase3.target_candidate = candidate
			end

			self._phase = "search_complete"
			operation_report("purchase_search_complete", {
				candidate = candidate,
				reused_inventory = source == "inventory",
				search = search,
			})

			if self._phase3 and self._phase3.running then
				self:_phase3_check_mastery(generation, candidate)
			else
				self:_start_phase4(candidate)
			end
		end

		if source == "inventory" then
			operation_report("inventory_base_selected", {
				candidate = candidate,
			})
		end

		if search.favorite_result and candidate.favorited ~= true then
			if not backend or type(backend.favorite_item) ~= "function" then
				self:_operation_failed(generation, "favorite adapter unavailable")
				return false
			end

			return self:_dispatch_operation(generation, "favorite", function ()
				return backend:favorite_item(candidate.gear_id)
			end, function ()
				candidate.favorited = true
				candidate.favorite_known = true
				operation_report("candidate_favorited", {
					candidate = candidate,
				})
				continue_exact_match()
			end)
		end

		continue_exact_match()

		return true
	end

	function self:_find_inventory_base()
		local search = self._search

		if not search or setting("auto_crafter_reuse_inventory_base", true) ~= true then
			return nil
		end

		local include_favorites = setting("auto_crafter_include_favorite_inventory_bases", true) == true
		local best
		local best_analysis
		local target = search.target_offer or {}

		local function family_matches(candidate)
			if target.master_id ~= nil and candidate.master_id ~= nil then
				return target.master_id == candidate.master_id, "master_item"
			end

			if target.weapon_template ~= nil and candidate.weapon_template ~= nil then
				return target.weapon_template == candidate.weapon_template, "weapon_template"
			end

			local target_pattern = target.parent_pattern
			local candidate_pattern = candidate.parent_pattern or candidate.mastery_id

			-- Mastery family is a safe fallback only when exact mark/template identity
			-- is unavailable on one side.
			if target_pattern ~= nil and candidate_pattern ~= nil then
				return target_pattern == candidate_pattern, "mastery_family"
			end

			return false, "identity_unavailable"
		end

		local function profile_analysis(candidate)
			local names = {}

			for key, stat in pairs(type(target.base_stats) == "table" and target.base_stats or {}) do
				local name = type(stat) == "table" and stat.name or type(key) == "string" and key or nil

				if name ~= nil then
					names[tostring(name)] = true
				end
			end

			local expected = 0
			local known = 0
			local non_dump_min = math.huge
			local non_dump_sum = 0
			local all_other_stats_maxed = true

			for name in pairs(names) do
				expected = expected + 1
				local value = tonumber(candidate_stat(candidate, name))

				if value ~= nil then
					known = known + 1

					if name ~= search.dump_stat then
						non_dump_min = math.min(non_dump_min, value)
						non_dump_sum = non_dump_sum + value
						all_other_stats_maxed = all_other_stats_maxed and value >= 80
					end
				elseif name ~= search.dump_stat then
					all_other_stats_maxed = false
				end
			end

			if non_dump_min == math.huge then
				non_dump_min = -1
			end

			return {
				all_other_stats_maxed = expected > 1 and known == expected and all_other_stats_maxed,
				expected_stats = expected,
				known_stats = known,
				non_dump_min = non_dump_min,
				non_dump_sum = non_dump_sum,
			}
		end

		local function remaining_steps(candidate)
			local steps = 0

			if setting("auto_crafter_consecrate_transcendent", true) == true then
				steps = steps + math.max(0, 5 - (tonumber(candidate.rarity) or 0))
			end

			if setting("auto_crafter_upgrade_expertise_500", true) == true then
				steps = steps + math.max(0, math.ceil((500 - (tonumber(candidate.expertise_level) or 0)) / 100))
			end

			if search.favorite_result and candidate.favorited ~= true then
				steps = steps + 1
			end

			local targets = self:_phase4_targets(candidate)

			if type(targets) == "table" then
				for index = 1, 2 do
					if targets.perks[index] and not same_trait(trait_at(candidate.perks, index), targets.perks[index]) then
						steps = steps + 1
					end

					if targets.traits[index] and not same_trait(trait_at(candidate.traits, index), targets.traits[index]) then
						steps = steps + 1
					end
				end
			end

			return steps
		end

		local function analysis_is_better(left, right)
			if not right then
				return true
			end

			if left.all_other_stats_maxed ~= right.all_other_stats_maxed then
				return left.all_other_stats_maxed
			end

			if left.known_stats ~= right.known_stats then
				return left.known_stats > right.known_stats
			end

			if left.non_dump_min ~= right.non_dump_min then
				return left.non_dump_min > right.non_dump_min
			end

			if left.non_dump_sum ~= right.non_dump_sum then
				return left.non_dump_sum > right.non_dump_sum
			end

			if left.remaining_steps ~= right.remaining_steps then
				return left.remaining_steps < right.remaining_steps
			end

			if left.expertise ~= right.expertise then
				return left.expertise > right.expertise
			end

			if left.rarity ~= right.rarity then
				return left.rarity > right.rarity
			end

			return left.gear_id < right.gear_id
		end

		for _, candidate in ipairs(self._snapshot and self._snapshot.gear and self._snapshot.gear.items or {}) do
			local matched, identity_source = family_matches(candidate)
			local favorite_allowed = include_favorites or candidate.favorite_known == true and candidate.favorited ~= true

			if candidate.available == true and candidate.gear_id ~= nil and candidate.equipped ~= true and matched and favorite_allowed and tonumber(candidate_stat(candidate, search.dump_stat)) == tonumber(search.target_dump) then
				local analysis = profile_analysis(candidate)
				analysis.expertise = tonumber(candidate.expertise_level) or -1
				analysis.family_identity = identity_source
				analysis.gear_id = tostring(candidate.gear_id)
				analysis.rarity = tonumber(candidate.rarity) or -1
				analysis.remaining_steps = remaining_steps(candidate)

				if analysis_is_better(analysis, best_analysis) then
					best = candidate
					best_analysis = analysis
				end
			end
		end

		if best then
			best.resume_analysis = best_analysis
		end

		return best
	end

	function self:_purchase_search_step(generation)
		if not operation_context_valid(generation) then
			return false
		end

		local search = self._search
		local target = search and search.target_offer
		local max_purchases = tonumber(search and search.max_purchases) or 0
		local price = tonumber(target and (target.price_amount or target.price))
		local credits
		local function flush_pending_fodder()
			local phase3 = self._phase3

			if phase3 and phase3.running and phase3.target_candidate and pending_deferred_count(phase3) > 0 then
				self:_phase3_process_deferred(generation, phase3.current)

				return true
			end

			return false
		end

		if not search or not search.running or not target or not price or price <= 0 then
			self:_stop_search("search_blocked")

			return false
		end

		if search.cap_by_max_purchases and search.purchases >= max_purchases then
			if flush_pending_fodder() then
				return true
			end

			self:_stop_search("search_max_purchases")

			return false
		end

		if search.cap_by_dockets and search.spent + price > search.docket_cap then
			if flush_pending_fodder() then
				return true
			end

			self:_stop_search("search_docket_cap")

			return false
		end

		local snapshot_wallets = self._snapshot and self._snapshot.wallets
		local currency = snapshot_wallets and snapshot_wallets.currencies and snapshot_wallets.currencies.credits

		credits = tonumber(currency and currency.amount)

		if credits and credits < price then
			if flush_pending_fodder() then
				return true
			end

			self:_stop_search("search_insufficient_dockets")

			return false
		end

		local raw_offer = search.raw_offer

		if not raw_offer then
			self:_stop_search("search_offer_missing")

			return false
		end

		local backend = self._backend

		if not backend or type(backend.purchase_offer) ~= "function" then
			self:_operation_failed(generation, "purchase adapter unavailable")

			return false
		end

		return self:_dispatch_operation(generation, "purchase", function ()
			return backend:purchase_offer(raw_offer)
		end, function (purchase)
			local purchase_candidate = purchase and purchase.items and purchase.items[1]

			if not purchase_candidate or not purchase_candidate.gear_id then
				self:_operation_failed(generation, "purchase result did not expose a weapon id")

				return
			end

			search.purchases = search.purchases + 1
			search.spent = search.spent + price

			if purchase.wallets and self._snapshot then
				self._snapshot.wallets = purchase.wallets
			end

			local phase3 = self._phase3
			local phase3_has_target = phase3 and phase3.running and phase3.target_candidate ~= nil

			-- Once the exact target is frozen, later purchases are fodder only. The
			-- decorated purchase response owns their identity and rolled expertise;
			-- one batch preflight refresh will revalidate every ID before extraction.
			if phase3_has_target then
				if purchase_candidate.available ~= true or purchase_candidate.parent_pattern ~= phase3.target_candidate.mastery_id or purchase_candidate.rarity == nil or purchase_candidate.expertise_level == nil then
					self:_operation_failed(generation, "post-target fodder purchase omitted required identity, rarity, or expertise")

					return
				end

				track_purchased_spare(phase3, purchase_candidate)
				phase3.deferred_candidates[#phase3.deferred_candidates + 1] = purchase_candidate
				self:_phase3_queue_fast_upgrade(generation, purchase_candidate)
				search.last = purchase_candidate
				self._last_purchased = purchase_candidate
				operation_report("phase3_fast_fodder_purchase", {
					candidate = purchase_candidate,
					count = pending_deferred_count(phase3),
					search = search,
				})

				local projection_reaches_target, projected_xp = pending_fodder_reaches_target(phase3)
				operation_report("phase3_pending_fodder_projected", {
					count = pending_deferred_count(phase3),
					expected_xp = projected_xp,
				})

				if projection_reaches_target or pending_deferred_count(phase3) >= PHASE3_FODDER_BATCH_SIZE then
					self:_phase3_process_deferred(generation, phase3.current)
				else
					self:_purchase_search_step(generation)
				end

				return
			end

			local function process_candidate(candidate)
				if not candidate or candidate.available ~= true then
					self:_operation_failed(generation, "purchased weapon was not found in authoritative inventory")

					return
				end

				if target.parent_pattern and candidate.parent_pattern ~= target.parent_pattern then
					self:_operation_failed(generation, "purchased weapon family did not match frozen target")

					return
				end

				local dump_stat = candidate_stat(candidate, search.dump_stat)

				if dump_stat == nil then
					self:_operation_failed(generation, "authoritative weapon did not expose configured dump stat")

					return
				end

				candidate.dump_stat = dump_stat
				candidate.dump_stat_id = search.dump_stat
				candidate.dump_stat_label = candidate.base_stat_labels and candidate.base_stat_labels[search.dump_stat]
				candidate.damage = candidate.potential_damage or candidate_stat(candidate, "damage")
				candidate.exact_match = tonumber(dump_stat) == tonumber(search.target_dump)

				if self._phase3 and self._phase3.running and not candidate.exact_match then
					track_purchased_spare(self._phase3, candidate)
				end
				search.last = candidate
				self._last_purchased = candidate

				if self:_candidate_is_better(candidate, search.best) then
					search.best = candidate
				end

				operation_report("purchase_result", {
					candidate = candidate,
					search = search,
				})

				if candidate.exact_match and not phase3_has_target then
					self:_accept_exact_candidate(generation, candidate, "purchase")
				elseif self._phase3 and self._phase3.running and self._phase3.defer_bad_processing and not self._phase3.target_candidate then
					self._phase3.deferred_candidates[#self._phase3.deferred_candidates + 1] = candidate
					operation_report("phase3_candidate_deferred", {
						candidate = candidate,
						count = #self._phase3.deferred_candidates,
					})
					self:_purchase_search_step(generation)
				elseif self._phase3 and self._phase3.running then
					self:_phase3_check_mastery(generation, candidate)
				else
					self:_purchase_search_step(generation)
				end
			end

			operation_report("purchase_response_received", {
				candidate = purchase_candidate,
			})
			self:_begin_purchase_confirmation(generation, purchase_candidate, process_candidate)
		end)
	end

	function self:start_purchase_search()
		if not mutations_enabled() then
			operation_report("mutation_blocked", {
				reason = "account mutations are disabled",
			})

			return false
		end

		if self._operation_inflight or self._operation_quarantined or self._reconciliation_required or (self._auxiliary_inflight_count or 0) > 0 or self._search and self._search.running or self._mastery and self._mastery.running then
			return false
		end

		if not self._snapshot then
			operation_report("mutation_blocked", {
				reason = "authoritative probe has not completed",
			})

			return false
		end

		local character_id = current_character_id()

		if not snapshot_matches_character(self._snapshot, character_id) then
			operation_report("mutation_blocked", {
				reason = "inventory snapshot belongs to another or unknown character; wait for a fresh probe",
			})

			return false
		end

		if setting("auto_crafter_buy_until_target", true) ~= true then
			operation_report("mutation_blocked", {
				reason = "buy-until-target workflow is disabled",
			})

			return false
		end

		self:_refresh_plan("purchase_search_start")

		local plan = self._plan

		if not plan or not plan.preflight or plan.preflight.ok ~= true or not plan.target then
			operation_report("mutation_blocked", {
				reason = plan and plan.preflight and plan.preflight.summary or "purchase preflight unavailable",
			})

			return false
		end

		local configured_dump_stat = setting("auto_crafter_target_dump_stat", "damage")
		local dump_stat = plan.resolved_dump_stat

		if dump_stat == nil or dump_stat == "" then
			operation_report("mutation_blocked", {
				reason = plan.dump_stat_resolution or "configured dump stat is unavailable",
			})

			return false
		end

		local selected_ok, raw_offer = safe_call(self._get_selected_offer, self._active_view)
		local selected_offer = selected_ok and selected_offer_ids(raw_offer) or nil

		if not selected_ok or not raw_offer then
			operation_report("mutation_blocked", {
				reason = "selected Brunt weapon offer is unavailable",
			})

			return false
		end

		if not selected_offer_matches_target(selected_offer, plan.target) then
			operation_report("mutation_blocked", {
				reason = "selected Brunt weapon changed before search start",
			})

			return false
		end

		local acquired, ownership_error = acquire_account_operation()
		if not acquired then
			operation_report("mutation_blocked", {
				reason = ownership_error or "another account operation is active",
			})

			return false
		end

		self._generation = self._generation + 1
		self._run_character_id = character_id
		self._observed_character_id = character_id
		self._run_elapsed = 0
		self._run_started_at = clock_now()
		self._operation_timings = {}
		self._last_progress_elapsed = 0
		self._failure_at = nil
		self._search = {
			cap_by_dockets = setting("auto_crafter_cap_by_dockets", true) == true,
			catalog = self._catalog,
			docket_cap = tonumber(setting("auto_crafter_docket_cap", 500000)) or 0,
			dump_stat = dump_stat,
			favorite_result = setting("auto_crafter_favorite_result", true) == true,
			generation = self._generation,
			cap_by_max_purchases = setting("auto_crafter_cap_by_max_purchases", false) == true,
			max_purchases = tonumber(setting("auto_crafter_max_purchases", 100)) or 0,
			purchases = 0,
			phase3 = setting("auto_crafter_level_mastery_20", true) == true,
			running = true,
			spent = 0,
			target_dump = tonumber(setting("auto_crafter_dump_stat_target", 60)) or 60,
			target_offer = plan.target,
			raw_offer = raw_offer,
			start_wallet = wallet_values(self._snapshot),
		}
		self._phase3 = setting("auto_crafter_level_mastery_20", true) == true and {
			cleanup_started = false,
			current = nil,
			defer_bad_processing = setting("auto_crafter_defer_bad_weapon_processing", true) == true,
			deferred_candidates = {},
			deferred_index = 1,
			fallback_candidate = nil,
			fodder_count = 0,
			fast_purchase_paused = false,
			fast_upgrade_head = 1,
			fast_upgrade_inflight = {},
			fast_upgrade_inflight_count = 0,
			fast_upgrade_queue = {},
			fast_upgrade_states = {},
			purchased_spare_ids = {},
			purchased_spares = {},
			running = true,
			target_candidate = nil,
		} or nil
		freeze_run_settings()
		self._last_error = nil
		self._phase = self._phase3 and "phase3_search_purchase" or "search_purchase"
		operation_report("purchase_search_started", {
			phase3 = self._phase3 ~= nil,
			search = self._search,
		})

		if setting("auto_crafter_reuse_inventory_base", true) == true then
			return self:_refresh_after_operation(self._generation, function ()
				local inventory_base = self:_find_inventory_base()

				if inventory_base then
					self:_accept_exact_candidate(self._generation, inventory_base, "inventory")
				else
					self:_purchase_search_step(self._generation)
				end
			end)
		end

		return self:_purchase_search_step(self._generation)
	end

	function self:stop_active_run()
		return self:_stop_active_run("user_stopped")
	end

	function self:interrupt_for_external_mutation(kind)
		if self._operation_inflight or self._operation_quarantined or (self._auxiliary_inflight_count or 0) > 0 then
			return false
		end

		return self:_stop_active_run("external_mutation_" .. tostring(kind or "unknown"))
	end

	function self:_mastery_extract(generation)
		local mastery = self._mastery
		local backend = self._backend

		if not mastery or not backend or type(backend.extract_weapon_mastery) ~= "function" then
			self:_operation_failed(generation, "mastery extraction adapter unavailable")

			return false
		end

		return self:_dispatch_operation(generation, "mastery_sacrifice", function ()
			return backend:extract_weapon_mastery(mastery.mastery_id, { mastery.gear_id })
		end, function (result)
			local amount = tonumber(result and result.amount) or 0

			if amount <= 0 or not extraction_contains_gear_id(result and result.gear_ids, mastery.gear_id) then
				self:_operation_failed(generation, "mastery extraction did not confirm one positive-XP item")

				return
			end

			mastery.amount = amount
			mastery.expected_xp = mastery.before.current_xp + amount
			operation_report("mastery_sacrifice_complete", {
				amount = amount,
				gear_id = mastery.gear_id,
			})

			local phase3 = mastery.phase3 and self._phase3 or nil
			local project_mastery = backend and backend.project_mastery

			if phase3 and type(project_mastery) == "function" then
				local projected = project_mastery(backend, mastery.before_data, amount)
				local current = mastery_summary(projected)

				if not projected or not current or current.current_xp == nil or current.mastery_level == nil then
					self:_operation_failed(generation, "local mastery projection failed after confirmed extraction")

					return
				end

				remove_snapshot_gear(self._snapshot, { mastery.gear_id })
				phase3.current = current
				phase3.current_data = projected
				phase3.projected_xp_pending = true
				mastery.current = current
				mastery.running = false
				if tonumber(current.mastery_level) > (tonumber(mastery.before.mastery_level) or -1) then
					operation_report("mastery_level_increased", {
						current = current,
						previous_level = mastery.before.mastery_level,
					})
				end

				if type(mastery.on_complete) == "function" then
					mastery.on_complete(current)
				end

				return
			end

			self:_refresh_after_operation(generation, function (snapshot)
				if find_item(snapshot and snapshot.gear and snapshot.gear.items, mastery.gear_id) then
					self:_operation_failed(generation, "sacrificed mastery item still exists in authoritative gear")

					return
				end

				self:_mastery_claim_after_extract(generation)
			end)
		end)
	end

	function self:_complete_mastery_sync(generation, current, source)
		local mastery = self._mastery

		if not mastery or not mastery.running or generation ~= self._generation or not current then
			return false
		end

		local xp_converged = mastery_target_reached(current) or current.current_xp and mastery.expected_xp and current.current_xp >= mastery.expected_xp
		local required_claim = current.mastery_level and math.max(0, current.mastery_level - 1)
		local claims_converged = required_claim == nil or current.claimed_level ~= nil and current.claimed_level >= required_claim

		if not xp_converged or not claims_converged then
			return false
		end

		mastery.running = false
		mastery.current = current
		operation_report("mastery_sync_confirmed", {
			current = current,
			expected_xp = mastery.expected_xp,
			reason = source,
		})

		if mastery.before and tonumber(current.mastery_level) and tonumber(mastery.before.mastery_level) and current.mastery_level > mastery.before.mastery_level then
			operation_report("mastery_level_increased", {
				current = current,
				previous_level = mastery.before.mastery_level,
			})
		end

		if mastery.phase3 then
			self._phase = "phase3_fodder_sync_complete"
			operation_report("phase3_fodder_mastery_complete", {
				current = current,
				gear_id = mastery.gear_id,
			})

			if type(mastery.on_complete) == "function" then
				mastery.on_complete(current)
			end
		else
			self._phase = "mastery_complete"
			operation_report("mastery_operation_complete", {
				current = current,
				gear_id = mastery.gear_id,
			})
		end

		return true
	end

	function self:_mastery_claim_after_extract(generation)
		local mastery = self._mastery
		local backend = self._backend

		if not mastery or not mastery.before_data or not mastery.before or not mastery.amount or not backend or type(backend.claim_mastery_levels) ~= "function" then
			self:_operation_failed(generation, "pre-sacrifice mastery baseline unavailable for tier claim")

			return false
		end

		return self:_dispatch_operation(generation, "mastery_claim", function ()
			return backend:claim_mastery_levels(mastery.before_data, mastery.amount)
		end, function (result)
			if self:_complete_mastery_sync(generation, mastery_summary(result), "claim_result") then
				return
			end

			self._mastery_poll_elapsed = 0
			self._mastery_poll_attempts = 0
			self._mastery_poll_wait = mastery_poll_delay(0)
			self._phase = "mastery_sync_wait"
			operation_report("mastery_sync_started", {
				amount = mastery.amount,
				expected_xp = mastery.expected_xp,
			})
		end)
	end

	function self:_mastery_read_baseline(generation, snapshot)
		local mastery = self._mastery
		local backend = self._backend

		if not mastery or not backend or type(backend.get_mastery_by_pattern) ~= "function" then
			self:_operation_failed(generation, "mastery read adapter unavailable")

			return false
		end

		local function accept_baseline(data)
			local before = mastery_summary(data)

			if not before or before.current_xp == nil or before.mastery_level == nil then
				self:_operation_failed(generation, "mastery baseline missing XP or level")

				return
			end

			mastery.before = before
			mastery.before_data = data

			if mastery_target_reached(before) then
				mastery.running = false
				mastery.current = before
				self._phase = "mastery_already_complete"

				if mastery.phase3 then
					local phase3 = self._phase3

					self._mastery = nil

					if phase3 and phase3.target_candidate then
						self:_phase3_finish(before)
					elseif phase3 and phase3.running then
						self:_purchase_search_step(generation)
					end
				else
					operation_report("mastery_operation_complete", {
						current = before,
						gear_id = mastery.gear_id,
						skipped = "mastery_already_20",
					})
				end

				return
			end

			self:_mastery_after_refresh(generation, snapshot)
		end

		local phase3 = mastery.phase3 and self._phase3 or nil

		if phase3 and phase3.current_data then
			accept_baseline(phase3.current_data)

			return true
		end

		return self:_dispatch_operation(generation, "mastery_baseline", function ()
			return backend:get_mastery_by_pattern(mastery.mastery_id)
		end, accept_baseline)
	end

	function self:_mastery_after_refresh(generation, snapshot)
		local mastery = self._mastery
		local item = find_item(snapshot and snapshot.gear and snapshot.gear.items, mastery and mastery.gear_id)

		if not mastery or not item or item.available ~= true then
			self:_operation_failed(generation, "mastery item no longer exists in authoritative gear")

			return false
		end

		if item.parent_pattern ~= mastery.mastery_id then
			self:_operation_failed(generation, "mastery item family changed before operation")

			return false
		end

		if item.rarity == nil then
			self:_operation_failed(generation, "mastery item rarity unavailable")

			return false
		end

		if not mastery.before_data then
			return self:_mastery_read_baseline(generation, snapshot)
		end

		if item.rarity >= REDEEMED_RARITY then
			return self:_mastery_extract(generation)
		end

		local backend = self._backend

		if not backend or type(backend.upgrade_weapon_rarity) ~= "function" then
			self:_operation_failed(generation, "rarity upgrade adapter unavailable")

			return false
		end

		return self:_dispatch_operation(generation, "mastery_upgrade", function ()
			return backend:upgrade_weapon_rarity(mastery.gear_id)
		end, function ()
			operation_report("mastery_upgrade_complete", {
				gear_id = mastery.gear_id,
			})

			if mastery.phase3 and type(backend.project_mastery) == "function" then
				-- A resolved crafting mutation is sufficient to feed the immediately
				-- following extraction. Avoid two inventory reads per fodder item;
				-- the extraction result and final reconciliation remain authoritative.
				item.rarity = REDEEMED_RARITY
				self:_mastery_extract(generation)

				return
			end

			self:_refresh_after_operation(generation, function (updated_snapshot)
				local upgraded = find_item(updated_snapshot and updated_snapshot.gear and updated_snapshot.gear.items, mastery.gear_id)

				if not upgraded or upgraded.rarity == nil or upgraded.rarity < REDEEMED_RARITY then
					self:_operation_failed(generation, "rarity upgrade was not confirmed as Redeemed")

					return
				end

				-- Rarity mutation can take long enough for external mastery state to
				-- move. Re-read baseline immediately before destructive extraction.
				mastery.before = nil
				mastery.before_data = nil
				self:_mastery_after_refresh(generation, updated_snapshot)
			end)
		end)
	end

	function self:start_mastery_operation(candidate)
		if not mutations_enabled() then
			operation_report("mutation_blocked", {
				reason = "account mutations are disabled",
			})

			return false
		end

		if self._operation_inflight or self._search and self._search.running or self._mastery and self._mastery.running then
			return false
		end

		candidate = candidate or self._search and self._search.result or self._last_purchased

		if not candidate or not candidate.gear_id or not candidate.mastery_id then
			operation_report("mutation_blocked", {
				reason = "no explicit purchased weapon is available for Phase 2",
			})

			return false
		end

		local item = find_item(self._snapshot and self._snapshot.gear and self._snapshot.gear.items, candidate.gear_id)

		if not item then
			operation_report("mutation_blocked", {
				reason = "selected Phase 2 weapon is not present in authoritative gear",
			})

			return false
		end

		local acquired, ownership_error = acquire_account_operation()
		if not acquired then
			operation_report("mutation_blocked", {
				reason = ownership_error or "another account operation is active",
			})

			return false
		end

		self._generation = self._generation + 1
		self._run_elapsed = 0
		self._run_started_at = clock_now()
		self._operation_timings = {}
		self._last_progress_elapsed = 0
		self._failure_at = nil
		self._mastery = {
			candidate = candidate,
			claim_retries = 0,
			gear_id = candidate.gear_id,
			mastery_id = candidate.mastery_id,
			running = true,
		}
		self._last_error = nil
		self._phase = "mastery_preflight"
		operation_report("mastery_operation_started", {
			candidate = candidate,
		})

		return self:_refresh_after_operation(self._generation, function (snapshot)
			self:_mastery_after_refresh(self._generation, snapshot)
		end)
	end

	function self:_poll_mastery()
		local mastery = self._mastery
		local generation = self._generation
		local backend = self._backend

		if not mastery or not mastery.running or self._operation_inflight or not operation_context_valid(generation) then
			return false
		end

		return self:_dispatch_operation(generation, "mastery_poll", function ()
			return backend:get_mastery_by_pattern(mastery.mastery_id)
		end, function (data)
			local current = mastery_summary(data)
			local xp_converged = current and (mastery_target_reached(current) or current.current_xp and mastery.expected_xp and current.current_xp >= mastery.expected_xp)
			local required_claim = current and current.mastery_level and math.max(0, current.mastery_level - 1)
			local claims_converged = required_claim == nil or current.claimed_level ~= nil and current.claimed_level >= required_claim

			operation_report("mastery_poll_result", {
				current = current,
				attempt = self._mastery_poll_attempts + 1,
			})

			if xp_converged and claims_converged and self:_complete_mastery_sync(generation, current, "poll") then
				return
			end

			self._mastery_poll_attempts = self._mastery_poll_attempts + 1

			if self._mastery_poll_attempts >= MAX_MASTERY_POLL_ATTEMPTS then
				mastery.current = current

				if xp_converged and not claims_converged and (mastery.claim_retries or 0) < MAX_MASTERY_CLAIM_RETRIES and backend and type(backend.claim_mastery_levels) == "function" then
					mastery.claim_retries = (mastery.claim_retries or 0) + 1
					operation_report("mastery_claim_retry_started", {
						current = current,
						retry = mastery.claim_retries,
					})

					return self:_dispatch_operation(generation, "mastery_claim_retry", function ()
						return backend:claim_mastery_levels(data, 0)
					end, function (result)
						if self:_complete_mastery_sync(generation, mastery_summary(result), "claim_retry_result") then
							return
						end

						self._mastery_poll_elapsed = 0
						self._mastery_poll_attempts = 0
						self._mastery_poll_wait = mastery_poll_delay(0)
						self._phase = "mastery_sync_wait"
					end)
				end

				operation_report("mastery_sync_timeout", {
					current = current,
					attempts = self._mastery_poll_attempts,
				})
				self:_operation_failed(generation, string.format(
					"mastery synchronization failed after %s polls and %s claim retries (expected XP %s, current XP %s, level %s, claimed %s)",
					tostring(self._mastery_poll_attempts),
					tostring(mastery.claim_retries or 0),
					tostring(mastery.expected_xp),
					tostring(current and current.current_xp),
					tostring(current and current.mastery_level),
					tostring(current and current.claimed_level)
				))

				return
			end

			self._mastery_poll_elapsed = 0
			self._mastery_poll_wait = mastery_poll_delay(self._mastery_poll_attempts)
		end)
	end

	function self:on_brunt_view_ready(view)
		if not view or not context_is_valid(view) then
			return false
		end

		if self._active_view ~= view then
			cancel_probe()
			cancel_catalog()

			if run_is_active() then
				self._active_view = view
				self._view_is_valid = true

				return true
			end

			invalidate_generation()
			self._search = nil
			self._phase3 = nil
			self._phase4 = nil
			self._mastery = nil
			self._last_purchased = nil
			self._active_view = view
			self._view_is_valid = true
			self._phase = "view_ready"
			self._catalog = nil
			self._catalog_key = nil
			self._plan = nil
			self._selected_target_key = nil
			self._selected_native_key = nil
			self._planner_signature = nil
			self._observed_character_id = current_character_id()
		end

		if self._observed_character_id == nil then
			self._observed_character_id = current_character_id()
		end

		return self:_schedule_probe("brunt_view_ready")
	end

	function self:on_character_changed(previous_character_id, character_id)
		local had_active_run = run_is_active()
		local failed_kind = self._operation_kind
		local unresolved_operation = self._operation_inflight or (self._auxiliary_inflight_count or 0) > 0

		invalidate_generation()
		cancel_probe()
		cancel_catalog()
		if unresolved_operation then
			self._operation_quarantined = true
			self._reconciliation_required = true
		else
			self._operation_sequence = self._operation_sequence + 1
			self._operation_inflight = false
			self._operation_promise = nil
			self._operation_kind = nil
			self._operation_elapsed = 0
			self._operation_started_at = nil
		end
		self._snapshot = nil
		self._plan = nil
		self._search = nil
		self._phase3 = nil
		self._phase4 = nil
		self._mastery = nil
		self._catalog = nil
		self._catalog_key = nil
		self._last_purchased = nil
		self._purchase_confirmation = nil
		self._selected_target_key = nil
		self._selected_native_key = nil
		self._planner_signature = nil
		self._frozen_run_settings = nil
		self._run_character_id = nil
		self._observed_character_id = character_id
		self._phase = "character_changed"
		self._last_error = had_active_run and "active character changed; run stopped before any further operation" or nil

		if had_active_run then
			operation_report("operation_failed", {
				error = self._last_error,
				kind = failed_kind,
			})
		end

		operation_report("character_changed", {
			current_character_id = character_id,
			previous_character_id = previous_character_id,
		})

		if self._view_is_valid and self._active_view and context_is_valid(self._active_view) then
			self:_schedule_probe("character_changed")
		end
		release_account_operation_if_settled()
	end

	function self:on_view_closed(view)
		if view and self._active_view ~= view then
			return false
		end

		cancel_probe()
		cancel_catalog()
		self._active_view = nil
		self._view_is_valid = false

		if run_is_active() then
			return true
		end

		invalidate_generation()
		self._phase = "idle"
		self._snapshot = nil
		self._plan = nil
		self._search = nil
		self._phase3 = nil
		self._phase4 = nil
		self._mastery = nil
		self._catalog = nil
		self._catalog_key = nil
		self._last_purchased = nil
		self._purchase_confirmation = nil
		self._selected_target_key = nil
		self._selected_native_key = nil
		self._planner_signature = nil
		self._frozen_run_settings = nil
		self._run_character_id = nil
		release_account_operation_if_settled()

		return true
	end

	function self:on_context_exit(reason)
		if self._operation_inflight or (self._auxiliary_inflight_count or 0) > 0 then
			self._operation_quarantined = true
			self._reconciliation_required = true
		end
		invalidate_generation()
		cancel_probe()
		cancel_catalog()
		self._active_view = nil
		self._view_is_valid = false
		self._phase = "context_exit"
		self._snapshot = nil
		self._plan = nil
		self._search = nil
		self._phase3 = nil
		self._phase4 = nil
		self._mastery = nil
		self._catalog = nil
		self._catalog_key = nil
		self._last_purchased = nil
		self._purchase_confirmation = nil
		self._selected_target_key = nil
		self._selected_native_key = nil
		self._planner_signature = nil
		self._frozen_run_settings = nil
		self._run_character_id = nil
		report("context_exit", {
			reason = reason or "game_state_exit",
		})
		release_account_operation_if_settled()
	end

	function self:on_setting_changed(setting_id)
		if type(setting_id) ~= "string" or string.sub(setting_id, 1, #"auto_crafter_") ~= "auto_crafter_" then
			return false
		end

		if not enabled() then
			invalidate_generation()
			cancel_probe()
			cancel_catalog()
			if self._search then
				self._search.running = false
			end
			if self._phase3 then
				self._phase3.running = false
			end
			if self._mastery then
				self._mastery.running = false
			end
			if self._phase4 then
				self._phase4.running = false
			end
			self._phase = "disabled"
			self._plan = nil
			return true
		end

		local run_setting = planner_setting_ids[setting_id] or setting_id == "auto_crafter_buy_until_target"

		if run_setting and run_is_active() then
			if not run_setting_changed(setting_id) then
				return true
			end

			if self:_stop_active_run("run_configuration_changed") then
				if self._view_is_valid then
					self:_refresh_plan("planner_setting_changed")
				end

				return true
			end
		end

		if mutation_setting_ids[setting_id] and not mutations_enabled() then
			invalidate_generation()

			if self._search then
				self._search.running = false
			end
			if self._phase3 then
				self._phase3.running = false
			end
			if self._mastery then
				self._mastery.running = false
			end
			if self._phase4 then
				self._phase4.running = false
			end

			self._phase = "mutations_disabled"
			return true
		end

		if setting_id == "auto_crafter_level_mastery_20" and self._phase3 and self._phase3.running and setting("auto_crafter_level_mastery_20", true) ~= true then
			invalidate_generation()
			self._phase3.running = false

			if self._search then
				self._search.running = false

				if self._phase3.target_candidate then
					self._search.result = self._phase3.target_candidate
				end
			end

			if self._mastery then
				self._mastery.running = false
			end

			self._phase = "phase3_disabled"
			operation_report("phase3_stopped", {
				reason = "phase3_disabled",
			})

			return true
		end

		if planner_setting_ids[setting_id] then
			self:_refresh_plan("planner_setting_changed")

			return true
		end

		if self._view_is_valid then
			return self:_schedule_probe("setting_changed")
		end

		return true
	end

	function self:update(dt)
		if not enabled() or not self._view_is_valid and not run_is_active() then
			return
		end

		if not runtime_context_valid() then
			self:on_context_exit("runtime_context_invalid")

			return
		end

		local character_id = current_character_id()

		if character_id ~= nil and self._observed_character_id ~= nil and character_id ~= self._observed_character_id then
			self:on_character_changed(self._observed_character_id, character_id)

			return
		elseif character_id ~= nil and self._observed_character_id == nil then
			self._observed_character_id = character_id
		end

		if run_is_active() then
			self._run_elapsed = self._run_elapsed + finite_dt(dt)
		end

		if self._operation_inflight then
			self._operation_elapsed = self._operation_elapsed + finite_dt(dt)

			if self._operation_elapsed >= MAX_OPERATION_SECONDS and not self._operation_quarantined then
				self:_quarantine_operation(self._generation, string.format("operation %s timed out after %.1f seconds", tostring(self._operation_kind), self._operation_elapsed))
			end
		end

		if self._probe_inflight then
			self._probe_request_elapsed = self._probe_request_elapsed + finite_dt(dt)

			if self._probe_request_elapsed >= MAX_READ_SECONDS then
				local generation = self._generation
				local probe_sequence = self._probe_sequence
				local promise = self._probe_promise
				if promise and type(promise.cancel) == "function" then
					pcall(promise.cancel, promise)
				end
				self:_fail_probe(generation, probe_sequence, string.format("read-only probe timed out after %.1f seconds", self._probe_request_elapsed))
				self._probe_sequence = self._probe_sequence + 1
			end
		end

		if self._catalog_inflight then
			self._catalog_elapsed = self._catalog_elapsed + finite_dt(dt)

			if self._catalog_elapsed >= MAX_READ_SECONDS then
				local target = self:_selected_offer_summary()
				local reason = string.format("weapon trait discovery timed out after %.1f seconds", self._catalog_elapsed)
				cancel_catalog()
				self._catalog = {
					available = false,
					reason = reason,
				}
				self._phase = "trait_discovery_failed"
				self:_refresh_plan("catalog_timeout")
				report("catalog_discovery_failed", {
					error = reason,
					target = target,
				})
			end
		end

		local phase3 = self._phase3

		if phase3 and type(phase3.fast_upgrade_inflight) == "table" then
			for gear_id, entry in pairs(phase3.fast_upgrade_inflight) do
				entry.elapsed = (tonumber(entry.elapsed) or 0) + finite_dt(dt)

				if entry.elapsed >= MAX_OPERATION_SECONDS and not entry.timed_out then
					entry.timed_out = true
					self:_abort_for_auxiliary_failure(entry.generation, string.format("fast fodder rarity upgrade timed out for gear %s after %.1f seconds", tostring(gear_id), entry.elapsed))

					return
				end
			end
		end

		if self._view_is_valid and not context_is_valid(self._active_view) then
			self:on_view_closed(self._active_view)
		end

		if self._mastery and self._mastery.running and not self._operation_inflight then
			self._mastery_poll_elapsed = self._mastery_poll_elapsed + finite_dt(dt)

			if self._mastery_poll_elapsed >= (self._mastery_poll_wait or DEFAULT_MASTERY_POLL_DELAY) then
				self:_poll_mastery()
			end
		end

		if self._purchase_confirmation and not self._operation_inflight then
			local confirmation = self._purchase_confirmation

			confirmation.elapsed = (tonumber(confirmation.elapsed) or 0) + finite_dt(dt)

			if confirmation.elapsed >= (confirmation.wait or DEFAULT_PURCHASE_CONFIRMATION_POLL_DELAY) then
				self:_poll_purchase_confirmation()
			end
		end

		if self._phase4 and self._phase4.running and self._phase4.pending_blessing and not self._operation_inflight then
			self._phase4.blessing_poll_elapsed = (self._phase4.blessing_poll_elapsed or 0) + finite_dt(dt)

			if self._phase4.blessing_poll_elapsed >= (self._phase4.blessing_poll_wait or DEFAULT_BLESSING_POLL_DELAY) then
				self:_poll_phase4_blessing()
			end
		end

		if run_is_active() and not self._operation_inflight then
			local mastery_waiting = self._mastery and self._mastery.running and self._phase == "mastery_sync_wait"
			local blessing_waiting = self._phase4 and self._phase4.running and self._phase4.pending_blessing ~= nil
			local purchase_confirmation_waiting = self._purchase_confirmation ~= nil
			local fast_upgrades_waiting = fast_upgrade_pending(self._phase3)
			local idle_seconds = self._run_elapsed - (tonumber(self._last_progress_elapsed) or 0)

			if not mastery_waiting and not blessing_waiting and not purchase_confirmation_waiting and not fast_upgrades_waiting and idle_seconds >= MAX_IDLE_WORKFLOW_SECONDS then
				self:_operation_failed(self._generation, string.format("workflow stalled in phase %s for %.1f seconds with no request or bounded poll pending", tostring(self._phase), idle_seconds))
			end
		end

		local view_idle_poll_due = false

		if self._view_is_valid and not run_is_active() then
			self._view_idle_poll_elapsed = self._view_idle_poll_elapsed + finite_dt(dt)

			if self._view_idle_poll_elapsed >= DEFAULT_VIEW_IDLE_POLL_INTERVAL then
				self._view_idle_poll_elapsed = 0
				view_idle_poll_due = true
			end
		else
			self._view_idle_poll_elapsed = 0
		end

		if view_idle_poll_due and self._snapshot and not self._probe_inflight and type(self._get_selected_offer) == "function" then
			local current_config = planner_config()

			if planner_config_signature(current_config) ~= self._planner_signature then
				self:_refresh_plan("planner_setting_changed")
			end

			local selected_ok, raw_offer = safe_call(self._get_selected_offer, self._active_view)
			local selected_key = selected_ok and offer_key(selected_offer_ids(raw_offer)) or nil

			if selected_key ~= self._selected_native_key then
				self:_stop_active_run("selected_weapon_changed")
				self._selected_native_key = selected_key
				self:_refresh_plan("target_changed")
				self:_schedule_catalog("target_changed")
			end
		end

		if self._view_is_valid and self._probe_scheduled and not self._probe_inflight then
			self._probe_elapsed = self._probe_elapsed + finite_dt(dt)

			if self._probe_elapsed >= DEFAULT_PROBE_DELAY then
				self:_start_probe()
			end
		end
	end

	function self:snapshot()
		local resource_costs = self._search and wallet_consumption(self._search.start_wallet, wallet_values(self._snapshot)) or nil

		return {
			phase = self._phase,
			view_is_valid = self._view_is_valid,
			probe_inflight = self._probe_inflight,
			probe_elapsed_seconds = self._probe_request_elapsed,
			probe_count = self._probe_count,
			operation_inflight = self._operation_inflight,
			operation_kind = self._operation_kind,
			operation_sequence = self._operation_sequence,
			operation_elapsed_seconds = self._operation_elapsed,
			operation_quarantined = self._operation_quarantined,
			reconciliation_required = self._reconciliation_required,
			auxiliary_inflight_count = self._auxiliary_inflight_count,
			operation_timings = self._operation_timings,
			last_probe_at = self._last_probe_at,
			last_error = self._last_error,
			failure_at = self._failure_at,
			data = self._snapshot,
			plan = self._plan,
			catalog = self._catalog,
			catalog_inflight = self._catalog_inflight,
			catalog_elapsed_seconds = self._catalog_elapsed,
			last_purchased = self._last_purchased,
			search = self._search,
			phase3 = self._phase3,
			phase4 = self._phase4,
			mastery = self._mastery,
			run_elapsed_seconds = self._run_elapsed,
			resource_costs = resource_costs,
		}
	end

	function self:preview_plan()
		if not self._snapshot then
			return false
		end

		self:_refresh_plan("manual_preview")
		self._phase = "plan_preview"
		report("plan_preview", {
			plan = self._plan,
		})

		return true
	end

	function self:shutdown()
		invalidate_generation()
		cancel_probe()
		cancel_catalog()
		self._active_view = nil
		self._view_is_valid = false
		self._phase = "shutdown"
		self._snapshot = nil
		self._plan = nil
		self._search = nil
		self._phase3 = nil
		self._phase4 = nil
		self._mastery = nil
		self._last_purchased = nil
		self._selected_target_key = nil
		self._selected_native_key = nil
		self._planner_signature = nil
		self._frozen_run_settings = nil
		self._run_elapsed = 0
		self._run_started_at = nil
		release_account_operation_if_settled()
	end

	return self
end

return Controller
