local Controller = {}

local configured_modules

local REQUIRED_MODULE_FUNCTIONS = {
	candidate_policy = {
		"candidate_matches_stat_targets",
		"candidate_stat",
		"candidate_stat_target_distance",
		"copy_stat_identity",
		"copy_stat_targets",
		"find_item",
		"has_pending_trait_replacement",
		"has_trait_targets",
		"offer_key",
		"offer_with_mark",
		"requires_temporary_swap",
		"same_optional_trait",
		"same_trait",
		"selected_offer_ids",
		"selected_offer_matches_target",
		"temporary_swap_trait",
		"trait_at",
		"valid_custom_stat_targets",
	},
	imported_queue_workflow = { "install" },
	inventory_workflow = { "install" },
	mastery_policy = {
		"allocation_operations",
		"allocation_progress",
		"claims_converged",
		"extraction_contains_all",
		"extraction_contains_gear_id",
		"parse_perk_target",
		"planner_config_signature",
		"remove_snapshot_gear",
		"sticker_status",
		"summary",
		"target_reached",
		"unseen_blessing_tier_count",
		"wallet_consumption",
		"wallet_values",
	},
	phase3_workflow = { "install" },
	phase4_workflow = { "install" },
}

local function validate_modules(modules)
	if type(modules) ~= "table" then
		return false, "controller modules are unavailable"
	end

	for module_name, function_names in pairs(REQUIRED_MODULE_FUNCTIONS) do
		local module = modules[module_name]
		if type(module) ~= "table" then
			return false, "controller module unavailable: " .. module_name
		end

		for _, function_name in ipairs(function_names) do
			if type(module[function_name]) ~= "function" then
				return false, "controller module function unavailable: " .. module_name .. "." .. function_name
			end
		end
	end

	return true
end

function Controller.configure(modules)
	local valid, validation_error = validate_modules(modules)

	if not valid then
		return false, validation_error
	end

	configured_modules = modules

	return true
end


local function read_member(object, key)
	return object[key]
end

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
local MAX_WORKFLOW_READ_SECONDS = 15
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

	local ok, value = pcall(read_member, object, key)

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


function Controller.new(dependencies)
	dependencies = dependencies or {}

	local modules = dependencies.modules or configured_modules
	local modules_valid, modules_error = validate_modules(modules)

	if not modules_valid then
		return nil, modules_error
	end

	local CandidatePolicy = modules.candidate_policy
	local MasteryPolicy = modules.mastery_policy
	local ImportedQueueWorkflow = modules.imported_queue_workflow
	local InventoryWorkflow = modules.inventory_workflow
	local Phase3Workflow = modules.phase3_workflow
	local Phase4Workflow = modules.phase4_workflow

	local offer_key = CandidatePolicy.offer_key
	local selected_offer_ids = CandidatePolicy.selected_offer_ids
	local selected_offer_matches_target = CandidatePolicy.selected_offer_matches_target
	local offer_with_mark = CandidatePolicy.offer_with_mark
	local find_item = CandidatePolicy.find_item
	local candidate_stat = CandidatePolicy.candidate_stat
	local copy_stat_identity = CandidatePolicy.copy_stat_identity
	local copy_stat_targets = CandidatePolicy.copy_stat_targets
	local valid_custom_stat_targets = CandidatePolicy.valid_custom_stat_targets
	local candidate_matches_stat_targets = CandidatePolicy.candidate_matches_stat_targets
	local candidate_stat_target_distance = CandidatePolicy.candidate_stat_target_distance
	local trait_at = CandidatePolicy.trait_at
	local same_trait = CandidatePolicy.same_trait
	local same_optional_trait = CandidatePolicy.same_optional_trait
	local has_pending_trait_replacement = CandidatePolicy.has_pending_trait_replacement
	local has_trait_targets = CandidatePolicy.has_trait_targets
	local temporary_swap_trait = CandidatePolicy.temporary_swap_trait
	local requires_temporary_swap = CandidatePolicy.requires_temporary_swap

	local sticker_status = MasteryPolicy.sticker_status
	local mastery_allocation_progress = MasteryPolicy.allocation_progress
	local unseen_blessing_tier_count = MasteryPolicy.unseen_blessing_tier_count
	local mastery_allocation_operations = MasteryPolicy.allocation_operations
	local parse_perk_target = MasteryPolicy.parse_perk_target
	local mastery_summary = MasteryPolicy.summary
	local mastery_target_reached = MasteryPolicy.target_reached
	local mastery_claims_converged = MasteryPolicy.claims_converged
	local extraction_contains_gear_id = MasteryPolicy.extraction_contains_gear_id
	local extraction_contains_all = MasteryPolicy.extraction_contains_all
	local remove_snapshot_gear = MasteryPolicy.remove_snapshot_gear
	local planner_config_signature = MasteryPolicy.planner_config_signature
	local wallet_values = MasteryPolicy.wallet_values
	local wallet_consumption = MasteryPolicy.wallet_consumption

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
		_operation_read_only = false,
		_operation_sequence = 0,
		_terminal_sequence = 0,
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
		_queue_operation_owner = false,
		_queue_run_policy = nil,
		_queue_preflight = nil,
		_imported_job = nil,
		_run_imported_job = nil,
		_manual_mark_master_id = nil,
		_manual_mark_offer_key = nil,
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

	local function raw_setting(id, default_value)
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

	local function setting(id, default_value)
		local policy_values = self._queue_operation_owner and self._queue_run_policy and self._queue_run_policy.values
		if type(policy_values) == "table" and policy_values[id] ~= nil then
			return policy_values[id]
		end

		return raw_setting(id, default_value)
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
		auto_crafter_custom_stats = true,
		auto_crafter_custom_stat_1 = true,
		auto_crafter_custom_stat_2 = true,
		auto_crafter_custom_stat_3 = true,
		auto_crafter_custom_stat_4 = true,
		auto_crafter_custom_stat_5 = true,
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
		auto_crafter_craft_duplicate_completed_queued_weapons = true,
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
		if self._queue_operation_owner then
			return false
		end

		if not run_is_active() and not self._operation_inflight and (self._auxiliary_inflight_count or 0) == 0 then
			local released = release_account_operation()
			if released then
				self._queue_run_policy = nil
				self._queue_preflight = nil
			end

			return released
		end

		return false
	end

	local function release_backend_read_cache_if_settled(force)
		if self._operation_inflight or (self._auxiliary_inflight_count or 0) > 0 or run_is_active() or self._view_is_valid and not force then
			return false
		end

		local release = self._backend and self._backend.release_read_cache
		if type(release) ~= "function" then
			return false
		end

		local ok, released = pcall(release, self._backend)

		return ok and released ~= false
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

		return raw_setting(setting_id) ~= frozen[setting_id]
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
		local imported_job = self._run_imported_job or self._imported_job
		local imported_custom_stats = imported_job and imported_job.custom_stats_enabled == true
		local custom_stats_enabled = imported_custom_stats or not imported_job and setting("auto_crafter_custom_stats", false) == true

		return {
			dump_stat = imported_job and imported_job.dump_stat or setting("auto_crafter_target_dump_stat", "damage"),
			dump_target = imported_job and imported_job.dump_target or setting("auto_crafter_dump_stat_target", 60),
			custom_stats_enabled = custom_stats_enabled,
			custom_stat_targets = imported_custom_stats and copy_stat_targets(imported_job.custom_stat_targets) or custom_stats_enabled and {
				setting("auto_crafter_custom_stat_1", 76),
				setting("auto_crafter_custom_stat_2", 76),
				setting("auto_crafter_custom_stat_3", 76),
				setting("auto_crafter_custom_stat_4", 76),
				setting("auto_crafter_custom_stat_5", 76),
			} or nil,
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
			craft_duplicate_completed_queued_weapons = setting("auto_crafter_craft_duplicate_completed_queued_weapons", false),
			trait_catalog = imported_job and imported_job.catalog or self._catalog,
			target_offer = imported_job and imported_job.offer or nil,
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
				local key = offer_key(offer)

				if self._manual_mark_offer_key ~= key then
					self._manual_mark_offer_key = key
					self._manual_mark_master_id = nil
				end

				for _, mark in ipairs(offer.marks or {}) do
					if self._manual_mark_master_id ~= nil and mark.master_id == self._manual_mark_master_id then
						return offer_with_mark(offer, mark)
					end
				end

				return offer
			end
		end

		return nil
	end

	function self:select_manual_mark(offer_id, master_id)
		local function reject_selection(reason)
			local payload = {
				offer_id = offer_id,
				master_id = master_id,
				reason = reason,
			}

			log("warning", diagnostic_message("mark_selection_rejected", payload))
			report("mark_selection_rejected", payload)

			return false, reason
		end

		if run_is_active() or self._imported_job or self._run_imported_job or master_id == nil then
			return reject_selection("mark_selection_unavailable")
		end
		local current_offer = self:_selected_offer_summary()

		if not current_offer or current_offer.offer_id ~= offer_id then
			return reject_selection("selected_weapon_changed")
		end

		local target_offer

		for _, offer in ipairs(self._snapshot and self._snapshot.store and self._snapshot.store.offers or {}) do
			if offer.offer_id == offer_id then
				target_offer = offer

				break
			end
		end

		if not target_offer then
			return reject_selection("weapon_offer_unavailable")
		end

		local selected_mark

		for _, mark in ipairs(target_offer.marks or {}) do
			if mark.master_id == master_id then
				selected_mark = mark

				break
			end
		end

		if not selected_mark then
			return reject_selection("weapon_mark_unavailable")
		end

		self._manual_mark_offer_key = offer_key(target_offer)
		self._manual_mark_master_id = master_id
		self._selected_target_key = nil
		self._catalog_key = nil
		self:_refresh_plan("manual_mark_changed")

		return true
	end

	function self:selected_manual_mark()
		local offer = self:_selected_offer_summary()

		return offer and offer.master_id or nil
	end

	function self:_refresh_plan(reason)
		if not self._snapshot or not self._planner or type(self._planner.build) ~= "function" then
			return false
		end

		local previous_target_key = self._selected_target_key
		local config = planner_config()
		config.target_offer = (self._run_imported_job or self._imported_job) and config.target_offer or self:_selected_offer_summary()
		self._selected_native_key = offer_key(config.target_offer)
		self._planner_signature = planner_config_signature(config)
		local ok, plan = pcall(self._planner.build, self._snapshot, config)

		if ok and type(plan) == "table" and type(self._planner.default_dump_stat) == "function" then
			local next_target_key = plan.target and offer_key(plan.target) or nil
			local target_changed = next_target_key ~= previous_target_key
			local default_dump_stat = self._planner.default_dump_stat(plan)

			if not self._run_imported_job and not self._imported_job and not run_is_active() and default_dump_stat and (target_changed or config.dump_stat == "auto") and config.dump_stat ~= default_dump_stat and set_setting("auto_crafter_target_dump_stat", default_dump_stat) then
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
		payload.run_generation = self._generation
		payload.operation_sequence = self._operation_sequence
		payload.character_id = self._run_character_id or current_character_id()
		local imported_job = self._run_imported_job or self._imported_job
		if imported_job then
			payload.queue_id = imported_job.queue_id
			payload.job_id = imported_job.job_id
		end
		if kind == "phase4_complete" or kind == "operation_failed" or kind == "operation_quarantined" or kind == "operation_reconciliation_required" or kind == "phase4_stopped" or kind == "purchase_search_stopped" then
			self._terminal_sequence = self._terminal_sequence + 1
			payload.terminal_sequence = self._terminal_sequence
		end
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

	function self:_operation_failed(generation, error_value, failed_kind_override)
		if generation ~= self._generation then
			log("info", string.format("[AutoCrafter] ignored stale failure run=%s current_run=%s error=%s", tostring(generation), tostring(self._generation), error_description(error_value)))
			return
		end

		local failed_kind = failed_kind_override or self._operation_kind
		self._operation_sequence = self._operation_sequence + 1
		self._operation_inflight = false
		self._operation_promise = nil
		self._operation_kind = nil
		self._operation_read_only = false
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
		release_backend_read_cache_if_settled()
	end

	local function retire_read_operation()
		if not self._operation_inflight or self._operation_read_only ~= true then
			return nil
		end

		local kind = self._operation_kind
		local promise = self._operation_promise
		local duration = self._operation_elapsed
		self._operation_sequence = self._operation_sequence + 1
		self._operation_inflight = false
		self._operation_promise = nil
		self._operation_kind = nil
		self._operation_read_only = false
		self._operation_elapsed = 0
		self._operation_started_at = nil
		self._operation_quarantined = false
		record_timing(kind, duration)

		-- Read callbacks are safe to retire: they own no account mutation. Sequence
		-- invalidation happens before cancellation so even synchronous cancellation
		-- callbacks cannot resume the workflow.
		if promise and type(promise.cancel) == "function" then
			pcall(promise.cancel, promise)
		end

		return kind, duration
	end

	function self:_timeout_read_operation(generation)
		if generation ~= self._generation or not self._operation_inflight or self._operation_read_only ~= true then
			return false
		end

		local kind, duration = retire_read_operation()
		local phase4 = self._phase4

		if kind == "authoritative_refresh" and phase4 and phase4.running and phase4.final_reconcile_started then
			phase4.final_reconcile_fallback = "read_timeout"
			phase4.final_reconcile_timeout_seconds = duration
			operation_report("phase4_final_reconcile_fallback", {
				duration = duration,
				reason = "read_timeout",
			})

			local item = find_item(self._snapshot and self._snapshot.gear and self._snapshot.gear.items, phase4.gear_id)

			return self:_phase4_complete(item, self._snapshot)
		end

		self:_operation_failed(generation, string.format("read-only operation %s timed out after %.1f seconds; no mutation was retried", tostring(kind), tonumber(duration) or 0), kind)

		return true
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
		self._operation_read_only = false
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
		if not self._view_is_valid then
			release_backend_read_cache_if_settled()
		end

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

	function self:_dispatch_operation(generation, kind, fn, on_success, options)
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
		self._operation_read_only = type(options) == "table" and options.read_only == true
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
				if not self._view_is_valid then
					release_backend_read_cache_if_settled()
				end

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
		end, {
			read_only = true,
		})
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
		release_backend_read_cache_if_settled()
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
		release_backend_read_cache_if_settled()

		return true
	end

	function self:_candidate_is_better(candidate, current)
		if not candidate then
			return false
		end

		local search = self._search or {}
		local candidate_distance = candidate_stat_target_distance(candidate, search.dump_stat, search.target_dump, search.custom_stat_targets, search.dump_stat_identity)
		candidate.target_distance = candidate_distance
		local custom_profile = type(search.custom_stat_targets) == "table" and next(search.custom_stat_targets) ~= nil

		-- A candidate that cannot be mapped to the frozen stat identity is never a
		-- usable fallback, even when it happens to be the first observed roll.
		if candidate_distance == math.huge then
			return false
		end

		if not current then
			return true
		end

		local current_distance = candidate_stat_target_distance(current, search.dump_stat, search.target_dump, search.custom_stat_targets, search.dump_stat_identity)
		current.target_distance = current_distance

		if candidate_distance ~= current_distance then
			return candidate_distance < current_distance
		end

		-- Exact custom profiles use Manhattan distance across all five named
		-- level-500 stats. Equal-distance rolls retain the earlier purchase so
		-- backend response timing cannot make fallback selection nondeterministic.
		if custom_profile then
			return false
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

		local imported_job = self._imported_job
		self:_refresh_plan("purchase_search_start")

		local plan = self._plan

		if not plan or not plan.target then
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

		if plan.custom_stats_enabled and (plan.custom_stats_valid ~= true or tonumber(plan.custom_stat_total) ~= 380 or type(plan.custom_stat_targets) ~= "table" or #plan.custom_stat_targets ~= 5) then
			operation_report("mutation_blocked", {
				reason = string.format("invalid custom stat total: expected 380, current %s", tostring(plan.custom_stat_total or "?")),
			})

			return false
		end

		if not plan.preflight or plan.preflight.ok ~= true then
			operation_report("mutation_blocked", {
				reason = plan.preflight and plan.preflight.summary or "purchase preflight unavailable",
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
			catalog = imported_job and imported_job.catalog or self._catalog,
			docket_cap = tonumber(setting("auto_crafter_docket_cap", 500000)) or 0,
			custom_stats_enabled = plan.custom_stats_enabled == true,
			custom_stat_targets = copy_stat_targets(plan.custom_stat_targets),
			dump_stat = dump_stat,
			dump_stat_identity = copy_stat_identity(plan.dump_stat_identity),
			favorite_result = setting("auto_crafter_favorite_result", true) == true,
			generation = self._generation,
			cap_by_max_purchases = setting("auto_crafter_cap_by_max_purchases", false) == true,
			max_purchases = tonumber(setting("auto_crafter_max_purchases", 100)) or 0,
			purchases = 0,
			phase3 = setting("auto_crafter_level_mastery_20", true) == true,
			running = true,
			spent = 0,
			target_dump = tonumber(imported_job and imported_job.dump_target or setting("auto_crafter_dump_stat_target", 60)) or 60,
			target_offer = plan.target,
			raw_offer = raw_offer,
			start_wallet = wallet_values(self._snapshot),
		}
		self._run_imported_job = imported_job
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
		self._queue_operation_owner = false
		self._queue_run_policy = nil
		self._queue_preflight = nil
		self._imported_job = nil
		self._run_imported_job = nil
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
		release_backend_read_cache_if_settled(true)
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
		release_backend_read_cache_if_settled()

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
		self._queue_operation_owner = false
		self._queue_run_policy = nil
		self._queue_preflight = nil
		self._imported_job = nil
		self._run_imported_job = nil
		report("context_exit", {
			reason = reason or "game_state_exit",
		})
		release_account_operation_if_settled()
		release_backend_read_cache_if_settled()
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

		local update_dt = finite_dt(dt)

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
			self._run_elapsed = self._run_elapsed + update_dt
		end

		if self._operation_inflight then
			self._operation_elapsed = self._operation_elapsed + update_dt

			if self._operation_read_only and self._operation_elapsed >= MAX_WORKFLOW_READ_SECONDS then
				self:_timeout_read_operation(self._generation)
			elseif self._operation_elapsed >= MAX_OPERATION_SECONDS and not self._operation_quarantined then
				self:_quarantine_operation(self._generation, string.format("operation %s timed out after %.1f seconds", tostring(self._operation_kind), self._operation_elapsed))
			end
		end

		if self._probe_inflight then
			self._probe_request_elapsed = self._probe_request_elapsed + update_dt

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
			self._catalog_elapsed = self._catalog_elapsed + update_dt

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
				entry.elapsed = (tonumber(entry.elapsed) or 0) + update_dt

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
			self._mastery_poll_elapsed = self._mastery_poll_elapsed + update_dt

			if self._mastery_poll_elapsed >= (self._mastery_poll_wait or DEFAULT_MASTERY_POLL_DELAY) then
				self:_poll_mastery()
			end
		end

		if self._purchase_confirmation and not self._operation_inflight then
			local confirmation = self._purchase_confirmation

			confirmation.elapsed = (tonumber(confirmation.elapsed) or 0) + update_dt

			if confirmation.elapsed >= (confirmation.wait or DEFAULT_PURCHASE_CONFIRMATION_POLL_DELAY) then
				self:_poll_purchase_confirmation()
			end
		end

		if self._phase4 and self._phase4.running and self._phase4.pending_blessing and not self._operation_inflight then
			self._phase4.blessing_poll_elapsed = (self._phase4.blessing_poll_elapsed or 0) + update_dt

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
			self._view_idle_poll_elapsed = self._view_idle_poll_elapsed + update_dt

			if self._view_idle_poll_elapsed >= DEFAULT_VIEW_IDLE_POLL_INTERVAL then
				self._view_idle_poll_elapsed = 0
				view_idle_poll_due = true
			end
		else
			self._view_idle_poll_elapsed = 0
		end

		if view_idle_poll_due and self._snapshot and not self._probe_inflight and type(self._get_selected_offer) == "function" then
			-- Planner settings refresh synchronously through on_setting_changed;
			-- this bounded poll owns only native weapon-selection reconciliation.
			local selected_ok, raw_offer = safe_call(self._get_selected_offer, self._active_view)
			local selected_key = selected_ok and offer_key(selected_offer_ids(raw_offer)) or nil

			if selected_key ~= self._selected_native_key then
				self:_stop_active_run("selected_weapon_changed")
				self._selected_native_key = selected_key
				self:_refresh_plan("target_changed")
				if self._imported_job then
					self._catalog = self._imported_job.catalog
				else
					self:_schedule_catalog("target_changed")
				end
			end
		end

		if self._view_is_valid and self._probe_scheduled and not self._probe_inflight then
			self._probe_elapsed = self._probe_elapsed + update_dt

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
			operation_read_only = self._operation_read_only,
			operation_sequence = self._operation_sequence,
			terminal_sequence = self._terminal_sequence,
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
			queue_operation_owner = self._queue_operation_owner,
			queue_run_policy = self._queue_run_policy,
			queue_preflight = self._queue_preflight,
			imported_job = self._imported_job,
			run_imported_job = self._run_imported_job,
		}
	end

	function self:is_busy()
		return self._operation_inflight == true or self._operation_quarantined == true or (tonumber(self._auxiliary_inflight_count) or 0) > 0 or run_is_active() == true
	end

	function self:needs_update()
		return enabled() and (self._view_is_valid == true or self._operation_inflight == true or self._operation_quarantined == true or (tonumber(self._auxiliary_inflight_count) or 0) > 0 or run_is_active() == true)
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
		self._catalog = nil
		self._catalog_key = nil
		self._purchase_confirmation = nil
		self._last_purchased = nil
		self._selected_target_key = nil
		self._selected_native_key = nil
		self._planner_signature = nil
		self._frozen_run_settings = nil
		self._run_elapsed = 0
		self._run_started_at = nil
		self._queue_operation_owner = false
		self._queue_run_policy = nil
		self._queue_preflight = nil
		self._imported_job = nil
		self._run_imported_job = nil
		release_account_operation_if_settled()
		release_backend_read_cache_if_settled()
	end


	local workflow_services = {
		acquire_account_operation = acquire_account_operation,
		blessing_poll_delay = blessing_poll_delay,
		cancel_catalog = cancel_catalog,
		candidate_matches_stat_targets = candidate_matches_stat_targets,
		candidate_stat = candidate_stat,
		candidate_stat_target_distance = candidate_stat_target_distance,
		clock_now = clock_now,
		copy_stat_identity = copy_stat_identity,
		copy_stat_targets = copy_stat_targets,
		current_character_id = current_character_id,
		estimated_fodder_xp = estimated_fodder_xp,
		extraction_contains_all = extraction_contains_all,
		fast_upgrade_pending = fast_upgrade_pending,
		find_item = find_item,
		has_pending_trait_replacement = has_pending_trait_replacement,
		has_trait_targets = has_trait_targets,
		invalidate_generation = invalidate_generation,
		mastery_allocation_operations = mastery_allocation_operations,
		mastery_allocation_progress = mastery_allocation_progress,
		mastery_claims_converged = mastery_claims_converged,
		mastery_level_target_xp = mastery_level_target_xp,
		mastery_poll_delay = mastery_poll_delay,
		mastery_summary = mastery_summary,
		mastery_target_reached = mastery_target_reached,
		offer_key = offer_key,
		operation_context_valid = operation_context_valid,
		operation_report = operation_report,
		parse_perk_target = parse_perk_target,
		pending_deferred_count = pending_deferred_count,
		pending_fodder_reaches_target = pending_fodder_reaches_target,
		planner_config = planner_config,
		planner_config_signature = planner_config_signature,
		planner_setting_ids = planner_setting_ids,
		release_account_operation_if_settled = release_account_operation_if_settled,
		release_backend_read_cache_if_settled = release_backend_read_cache_if_settled,
		remove_snapshot_gear = remove_snapshot_gear,
		requires_temporary_swap = requires_temporary_swap,
		run_is_active = run_is_active,
		safe_call = safe_call,
		same_optional_trait = same_optional_trait,
		same_trait = same_trait,
		selected_offer_ids = selected_offer_ids,
		setting = setting,
		snapshot_matches_character = snapshot_matches_character,
		sticker_status = sticker_status,
		temporary_swap_trait = temporary_swap_trait,
		track_purchased_spare = track_purchased_spare,
		trait_at = trait_at,
		unseen_blessing_tier_count = unseen_blessing_tier_count,
		valid_custom_stat_targets = valid_custom_stat_targets,
		wallet_consumption = wallet_consumption,
		wallet_values = wallet_values,
		constants = {
			MAX_BLESSING_SYNC_ATTEMPTS = MAX_BLESSING_SYNC_ATTEMPTS,
			MAX_EXPERTISE_LEVEL = MAX_EXPERTISE_LEVEL,
			PHASE3_FODDER_BATCH_SIZE = PHASE3_FODDER_BATCH_SIZE,
			REDEEMED_RARITY = REDEEMED_RARITY,
			TRANSCENDENT_RARITY = TRANSCENDENT_RARITY,
		},
	}
	local workflow_modules = {
		Phase4Workflow,
		Phase3Workflow,
		InventoryWorkflow,
		ImportedQueueWorkflow,
	}

	for _, workflow in ipairs(workflow_modules) do
		local ok, installed = pcall(workflow.install, self, workflow_services)

		if not ok or installed ~= true then
			return nil, ok and "Auto Crafter workflow installation failed" or tostring(installed)
		end
	end

	-- Installers localize their dependencies, so this transient composition
	-- table can be collected instead of being retained by every method closure.
	workflow_services = nil
	workflow_modules = nil

	return self
end

return Controller
