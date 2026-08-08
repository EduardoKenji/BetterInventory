local Controller = {}

local DEFAULT_PROBE_DELAY = 0.5
local DEFAULT_MASTERY_POLL_DELAY = 0.5
local MAX_MASTERY_POLL_ATTEMPTS = 12
local REDEEMED_RARITY = 2

local function mastery_poll_delay(attempt)
	local exponent = math.max(0, tonumber(attempt) or 0)

	return math.min(5, DEFAULT_MASTERY_POLL_DELAY * 2 ^ exponent)
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

local function find_item(items, gear_id)
	for _, item in ipairs(items or {}) do
		if item and item.gear_id == gear_id then
			return item
		end
	end

	return nil
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

local function extraction_contains_gear_id(gear_ids, gear_id)
	for _, extracted_id in ipairs(gear_ids or {}) do
		if extracted_id == gear_id then
			return true
		end
	end

	return false
end

local function planner_config_signature(config)
	return table.concat({
		tostring(config.dump_stat),
		tostring(config.dump_target),
		tostring(config.docket_cap),
		tostring(config.max_purchases),
		tostring(config.best_candidate_fallback),
		tostring(config.request_mode),
	}, "|")
end

function Controller.new(dependencies)
	dependencies = dependencies or {}

	local self = {
		_backend = dependencies.backend,
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
		_probe_scheduled = false,
		_probe_inflight = false,
		_probe_promise = nil,
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
		_search = nil,
		_mastery = nil,
		_mastery_poll_elapsed = 0,
		_mastery_poll_attempts = 0,
		_mastery_poll_wait = DEFAULT_MASTERY_POLL_DELAY,
		_selected_target_key = nil,
		_selected_native_key = nil,
		_planner_signature = nil,
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

	local function enabled()
		return setting("auto_crafter_enable", false) == true
	end

	local function probe_enabled()
		return enabled() and setting("auto_crafter_read_only_probe", true) == true
	end

	local function mutations_enabled()
		return enabled() and setting("auto_crafter_allow_mutations", false) == true
	end

	local planner_setting_ids = {
		auto_crafter_target_dump_stat = true,
		auto_crafter_dump_stat_target = true,
		auto_crafter_docket_cap = true,
		auto_crafter_max_purchases = true,
		auto_crafter_best_candidate_fallback = true,
		auto_crafter_request_mode = true,
	}

	local mutation_setting_ids = {
		auto_crafter_allow_mutations = true,
	}

	local function planner_config()
		return {
			dump_stat = setting("auto_crafter_target_dump_stat", "damage"),
			dump_target = setting("auto_crafter_dump_stat_target", 60),
			docket_cap = setting("auto_crafter_docket_cap", 1000000),
			max_purchases = setting("auto_crafter_max_purchases", 100),
			best_candidate_fallback = setting("auto_crafter_best_candidate_fallback", false),
			request_mode = setting("auto_crafter_request_mode", "sequential"),
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

		local config = planner_config()
		config.target_offer = self:_selected_offer_summary()
		self._selected_native_key = offer_key(config.target_offer)
		self._planner_signature = planner_config_signature(config)
		local ok, plan = pcall(self._planner.build, self._snapshot, config)

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

	local function operation_context_valid(generation)
		return generation == self._generation and self._view_is_valid and context_is_valid(self._active_view) and mutations_enabled()
	end

	local function operation_report(kind, payload)
		report(kind, payload or {})
	end

	function self:_operation_failed(generation, error_value)
		if generation ~= self._generation then
			self._operation_inflight = false
			self._operation_promise = nil
			self._operation_kind = nil

			return
		end

		self._operation_inflight = false
		self._operation_promise = nil
		self._operation_kind = nil
		self._phase = "operation_failed"
		self._last_error = error_value
		operation_report("operation_failed", {
			error = error_value,
		})
	end

	function self:_dispatch_operation(generation, kind, fn, on_success)
		if not operation_context_valid(generation) or self._operation_inflight then
			return false
		end

		local call_ok, promise = safe_call(fn)

		if not call_ok or not promise or type(promise.next) ~= "function" or type(promise.catch) ~= "function" then
			self:_operation_failed(generation, call_ok and "operation returned no Promise" or promise)

			return false
		end

		self._operation_inflight = true
		self._operation_kind = kind
		self._phase = kind .. "_inflight"
		operation_report("operation_started", {
			kind = kind,
		})

		local chain_ok, chain = pcall(function()
			return promise:next(function(result)
				self._operation_inflight = false
				self._operation_promise = nil
				self._operation_kind = nil

				if generation ~= self._generation then
					return result
				end

				local callback_ok, callback_error = pcall(on_success, result)

				if not callback_ok then
					self:_operation_failed(generation, callback_error)
				end

				return result
			end):catch(function (error_value)
				self:_operation_failed(generation, error_value)

				return error_value
			end)
		end)

		if not chain_ok then
			self:_operation_failed(generation, chain)
		else
			self._operation_promise = chain
		end

		return true
	end

	function self:_refresh_after_operation(generation, callback)
		if not operation_context_valid(generation) or self._operation_inflight then
			return false
		end

		local backend = self._backend

		if not backend or type(backend.probe_snapshot) ~= "function" then
			self:_operation_failed(generation, "backend probe unavailable after mutation")

			return false
		end

		return self:_dispatch_operation(generation, "authoritative_refresh", function ()
			return backend:probe_snapshot()
		end, function (snapshot)
			self._snapshot = snapshot
			self._last_probe_at = type(self._clock.now) == "function" and self._clock:now() or nil
			self._probe_count = self._probe_count + 1
			self:_refresh_plan("operation_refresh")
			callback(snapshot)
		end)
	end

	local function invalidate_generation()
		self._generation = self._generation + 1
		self._probe_scheduled = false
		self._probe_elapsed = 0
	end

	local function cancel_probe()
		local promise = self._probe_promise

		if promise and type(promise.cancel) == "function" then
			pcall(promise.cancel, promise)
		end

		self._probe_inflight = false
		self._probe_promise = nil
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

	function self:_finish_probe(generation, snapshot)
		if generation ~= self._generation then
			return
		end

		self._probe_inflight = false
		self._probe_promise = nil
		self._probe_scheduled = false
		self._phase = "probe_complete"
		self._snapshot = snapshot
		self._last_error = nil
		self._last_probe_at = type(self._clock.now) == "function" and self._clock:now() or nil
		self._probe_count = self._probe_count + 1
		self:_refresh_plan("probe_complete")
		report("probe_complete", snapshot)
	end

	function self:_fail_probe(generation, error_value)
		if generation ~= self._generation then
			return
		end

		self._probe_inflight = false
		self._probe_promise = nil
		self._probe_scheduled = false
		self._phase = "probe_failed"
		self._last_error = error_value
		report("probe_failed", {
			error = error_value,
		})
		log("error", "Auto Crafter read-only probe failed: " .. tostring(error_value))
	end

	function self:_start_probe()
		if self._probe_inflight or not self._view_is_valid or not probe_enabled() then
			return false
		end

		local backend = self._backend

		if not backend or type(backend.probe_snapshot) ~= "function" then
			self:_fail_probe(self._generation, "backend probe unavailable")

			return false
		end

		local generation = self._generation
		local call_ok, promise = safe_call(backend.probe_snapshot, backend)

		if not call_ok or not promise or type(promise.next) ~= "function" or type(promise.catch) ~= "function" then
			self:_fail_probe(generation, call_ok and "backend returned no Promise" or promise)

			return false
		end

		self._probe_inflight = true
		self._probe_scheduled = false
		self._phase = "probe_inflight"
		self._probe_promise = promise
		report("probe_started", {})

		local chain_ok, chain = pcall(function()
			return promise:next(function(snapshot)
				self:_finish_probe(generation, snapshot)

				return snapshot
			end):catch(function(error_value)
				self:_fail_probe(generation, error_value)

				return error_value
			end)
		end)

		if not chain_ok then
			self:_fail_probe(generation, chain)
		else
			self._probe_promise = chain
		end

		return true
	end

	function self:_stop_search(reason, candidate)
		local search = self._search

		if search then
			search.running = false
			search.result = candidate or search.best

			if not candidate and setting("auto_crafter_best_candidate_fallback", false) ~= true then
				search.result = nil
			end
		end

		self._phase = reason or "search_stopped"
		operation_report("purchase_search_stopped", {
			candidate = candidate or search and search.best,
			reason = reason or "search_stopped",
			search = search,
		})
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

	function self:_purchase_search_step(generation)
		if not operation_context_valid(generation) then
			return false
		end

		local search = self._search
		local plan = self._plan
		local target = plan and plan.target
		local max_purchases = tonumber(search and search.max_purchases) or 0
		local price = tonumber(target and target.price_amount)
		local credits

		if not search or not search.running or not target or not price or price <= 0 then
			self:_stop_search("search_blocked")

			return false
		end

		if search.purchases >= max_purchases then
			self:_stop_search("search_max_purchases")

			return false
		end

		if search.spent + price > search.docket_cap then
			self:_stop_search("search_docket_cap")

			return false
		end

		local snapshot_wallets = self._snapshot and self._snapshot.wallets
		local currency = snapshot_wallets and snapshot_wallets.currencies and snapshot_wallets.currencies.credits

		credits = tonumber(currency and currency.amount)

		if credits and credits < price then
			self:_stop_search("search_insufficient_dockets")

			return false
		end

		local selected_ok, raw_offer = safe_call(self._get_selected_offer, self._active_view)

		if not selected_ok or not raw_offer then
			self:_stop_search("search_selected_offer_missing")

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
			local candidate = purchase and purchase.items and purchase.items[1]

			if not candidate or not candidate.gear_id or candidate.available ~= true then
				self:_operation_failed(generation, "purchase result did not expose a usable weapon")

				return
			end

			local dump_stat = candidate.base_stats and candidate.base_stats[search.dump_stat]

			if dump_stat == nil then
				self:_operation_failed(generation, "purchase result did not expose configured dump stat")

				return
			end

			candidate.dump_stat = dump_stat
			candidate.damage = candidate.damage or candidate.base_stats.damage
			candidate.exact_match = dump_stat == search.target_dump
			search.purchases = search.purchases + 1
			search.spent = search.spent + price
			search.last = candidate
			self._last_purchased = candidate

			if self:_candidate_is_better(candidate, search.best) then
				search.best = candidate
			end

			operation_report("purchase_result", {
				candidate = candidate,
				search = search,
			})

			self:_refresh_after_operation(generation, function ()
				if candidate.exact_match then
					search.running = false
					search.result = candidate
					self._phase = "search_complete"
					operation_report("purchase_search_complete", {
						candidate = candidate,
						search = search,
					})
				else
					self:_purchase_search_step(generation)
				end
			end)
		end)
	end

	function self:start_purchase_search()
		if not mutations_enabled() then
			operation_report("mutation_blocked", {
				reason = "account mutations are disabled",
			})

			return false
		end

		if self._operation_inflight or self._search and self._search.running or self._mastery and self._mastery.running then
			return false
		end

		if not self._snapshot then
			operation_report("mutation_blocked", {
				reason = "authoritative probe has not completed",
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

		local dump_stat = setting("auto_crafter_target_dump_stat", "damage")

		if dump_stat == "auto" then
			operation_report("mutation_blocked", {
				reason = "auto dump-stat discovery is not implemented",
			})

			return false
		end

		self._generation = self._generation + 1
		self._search = {
			docket_cap = tonumber(setting("auto_crafter_docket_cap", 1000000)) or 0,
			dump_stat = dump_stat,
			generation = self._generation,
			max_purchases = tonumber(setting("auto_crafter_max_purchases", 100)) or 0,
			purchases = 0,
			running = true,
			spent = 0,
			target_dump = tonumber(setting("auto_crafter_dump_stat_target", 60)) or 60,
			target_offer = plan.target,
		}
		self._last_error = nil
		self._phase = "search_purchase"
		operation_report("purchase_search_started", {
			search = self._search,
		})

		return self:_purchase_search_step(self._generation)
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
			operation_report("mastery_sacrifice_complete", {
				amount = amount,
				gear_id = mastery.gear_id,
			})
			self:_refresh_after_operation(generation, function ()
				self:_mastery_fetch_before_claim(generation)
			end)
		end)
	end

	function self:_mastery_fetch_before_claim(generation)
		local mastery = self._mastery
		local backend = self._backend

		if not mastery or not backend or type(backend.get_mastery_by_pattern) ~= "function" then
			self:_operation_failed(generation, "mastery read adapter unavailable")

			return false
		end

		return self:_dispatch_operation(generation, "mastery_read", function ()
			return backend:get_mastery_by_pattern(mastery.mastery_id)
		end, function (data)
			local before = mastery_summary(data)

			if not before or before.current_xp == nil then
				self:_operation_failed(generation, "mastery response missing current XP")

				return
			end

			mastery.before = before
			mastery.expected_xp = before.current_xp + mastery.amount

			if type(backend.claim_mastery_levels) ~= "function" then
				self:_operation_failed(generation, "mastery tier-claim adapter unavailable")

				return
			end

			self:_dispatch_operation(generation, "mastery_claim", function ()
				return backend:claim_mastery_levels(data, mastery.amount)
			end, function ()
				self._mastery_poll_elapsed = 0
				self._mastery_poll_attempts = 0
				self._mastery_poll_wait = mastery_poll_delay(0)
				self._phase = "mastery_sync_wait"
				operation_report("mastery_sync_started", {
					amount = mastery.amount,
					expected_xp = mastery.expected_xp,
				})
			end)
		end)
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
			self:_refresh_after_operation(generation, function (updated_snapshot)
				local upgraded = find_item(updated_snapshot and updated_snapshot.gear and updated_snapshot.gear.items, mastery.gear_id)

				if not upgraded or upgraded.rarity == nil or upgraded.rarity < REDEEMED_RARITY then
					self:_operation_failed(generation, "rarity upgrade was not confirmed as Redeemed")

					return
				end

				self:_mastery_extract(generation)
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

		self._generation = self._generation + 1
		self._mastery = {
			candidate = candidate,
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
			local xp_converged = current and current.current_xp and mastery.expected_xp and current.current_xp >= mastery.expected_xp
			local required_claim = current and current.mastery_level and math.max(0, current.mastery_level - 1)
			local claims_converged = required_claim == nil or current.claimed_level ~= nil and current.claimed_level >= required_claim

			operation_report("mastery_poll_result", {
				current = current,
				attempt = self._mastery_poll_attempts + 1,
			})

			if xp_converged and claims_converged then
				mastery.running = false
				mastery.current = current
				self._phase = "mastery_complete"
				operation_report("mastery_operation_complete", {
					current = current,
					gear_id = mastery.gear_id,
				})

				return
			end

			self._mastery_poll_attempts = self._mastery_poll_attempts + 1

			if self._mastery_poll_attempts >= MAX_MASTERY_POLL_ATTEMPTS then
				mastery.running = false
				mastery.current = current
				self._phase = "mastery_sync_timeout"
				operation_report("mastery_sync_timeout", {
					current = current,
					attempts = self._mastery_poll_attempts,
				})

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
			invalidate_generation()
			self._search = nil
			self._mastery = nil
			self._last_purchased = nil
			self._active_view = view
			self._view_is_valid = true
			self._phase = "view_ready"
			self._plan = nil
			self._selected_target_key = nil
			self._selected_native_key = nil
			self._planner_signature = nil
		end

		return self:_schedule_probe("brunt_view_ready")
	end

	function self:on_view_closed(view)
		if view and self._active_view ~= view then
			return false
		end

		invalidate_generation()
		cancel_probe()
		self._active_view = nil
		self._view_is_valid = false
		self._phase = "idle"
		self._snapshot = nil
		self._plan = nil
		self._search = nil
		self._mastery = nil
		self._last_purchased = nil
		self._selected_target_key = nil
		self._selected_native_key = nil
		self._planner_signature = nil

		return true
	end

	function self:on_context_exit(reason)
		invalidate_generation()
		cancel_probe()
		self._active_view = nil
		self._view_is_valid = false
		self._phase = "context_exit"
		self._snapshot = nil
		self._plan = nil
		self._search = nil
		self._mastery = nil
		self._last_purchased = nil
		self._selected_target_key = nil
		self._selected_native_key = nil
		self._planner_signature = nil
		report("context_exit", {
			reason = reason or "game_state_exit",
		})
	end

	function self:on_setting_changed(setting_id)
		if type(setting_id) ~= "string" or string.sub(setting_id, 1, #"auto_crafter_") ~= "auto_crafter_" then
			return false
		end

		if not enabled() then
			invalidate_generation()
			cancel_probe()
			if self._search then
				self._search.running = false
			end
			if self._mastery then
				self._mastery.running = false
			end
			self._phase = "disabled"
			self._plan = nil
			return true
		end

		if mutation_setting_ids[setting_id] and not mutations_enabled() then
			invalidate_generation()

			if self._search then
				self._search.running = false
			end
			if self._mastery then
				self._mastery.running = false
			end

			self._phase = "mutations_disabled"
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
		if not enabled() or not self._view_is_valid then
			return
		end

		local runtime_valid = self._context.is_runtime_valid

		if type(runtime_valid) == "function" then
			local ok, valid = safe_call(runtime_valid, self._context)

			if not ok or valid ~= true then
				self:on_context_exit("runtime_context_invalid")

				return
			end
		end

		if not context_is_valid(self._active_view) then
			self:on_context_exit("brunt_context_invalid")

			return
		end

		if self._mastery and self._mastery.running and not self._operation_inflight then
			self._mastery_poll_elapsed = self._mastery_poll_elapsed + finite_dt(dt)

			if self._mastery_poll_elapsed >= (self._mastery_poll_wait or DEFAULT_MASTERY_POLL_DELAY) then
				self:_poll_mastery()
			end
		end

		if self._snapshot and not self._probe_inflight and type(self._get_selected_offer) == "function" then
			local current_config = planner_config()

			if planner_config_signature(current_config) ~= self._planner_signature then
				self:_refresh_plan("planner_setting_changed")
			end

			local selected_ok, raw_offer = safe_call(self._get_selected_offer, self._active_view)
			local selected_key = selected_ok and offer_key(selected_offer_ids(raw_offer)) or nil

			if selected_key ~= self._selected_native_key then
				self._selected_native_key = selected_key
				self:_refresh_plan("target_changed")
			end
		end

		if self._probe_scheduled and not self._probe_inflight then
			self._probe_elapsed = self._probe_elapsed + finite_dt(dt)

			if self._probe_elapsed >= DEFAULT_PROBE_DELAY then
				self:_start_probe()
			end
		end
	end

	function self:snapshot()
		return {
			phase = self._phase,
			view_is_valid = self._view_is_valid,
			probe_inflight = self._probe_inflight,
			probe_count = self._probe_count,
			operation_inflight = self._operation_inflight,
			operation_kind = self._operation_kind,
			last_probe_at = self._last_probe_at,
			last_error = self._last_error,
			data = self._snapshot,
			plan = self._plan,
			last_purchased = self._last_purchased,
			search = self._search,
			mastery = self._mastery,
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
		self._active_view = nil
		self._view_is_valid = false
		self._phase = "shutdown"
		self._snapshot = nil
		self._plan = nil
		self._search = nil
		self._mastery = nil
		self._last_purchased = nil
		self._selected_target_key = nil
		self._selected_native_key = nil
		self._planner_signature = nil
	end

	return self
end

return Controller
