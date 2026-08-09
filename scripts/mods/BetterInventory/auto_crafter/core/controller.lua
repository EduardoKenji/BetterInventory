local Controller = {}

local DEFAULT_PROBE_DELAY = 0.5
local DEFAULT_MASTERY_POLL_DELAY = 0.5
local MAX_MASTERY_POLL_ATTEMPTS = 12
local REDEEMED_RARITY = 2
local TRANSCENDENT_RARITY = 5
local MAX_EXPERTISE_LEVEL = 500

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

local function find_item(items, gear_id)
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
		_phase3 = nil,
		_phase4 = nil,
		_mastery = nil,
		_mastery_poll_elapsed = 0,
		_mastery_poll_attempts = 0,
		_mastery_poll_wait = DEFAULT_MASTERY_POLL_DELAY,
		_catalog = nil,
		_catalog_generation = 0,
		_catalog_inflight = false,
		_catalog_key = nil,
		_catalog_promise = nil,
		_selected_target_key = nil,
		_selected_native_key = nil,
		_planner_signature = nil,
		_frozen_run_settings = nil,
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

	local function set_setting(id, value)
		local set = self._settings.set

		if type(set) ~= "function" then
			return false
		end

		local ok, result = pcall(set, self._settings, id, value)

		return ok and result ~= false
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
		auto_crafter_allow_mutations = true,
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
			cap_by_dockets = setting("auto_crafter_cap_by_dockets", false),
			docket_cap = setting("auto_crafter_docket_cap", 1000000),
			cap_by_max_purchases = setting("auto_crafter_cap_by_max_purchases", false),
			max_purchases = setting("auto_crafter_max_purchases", 100),
			best_candidate_fallback = setting("auto_crafter_best_candidate_fallback", false),
			defer_bad_weapon_processing = setting("auto_crafter_defer_bad_weapon_processing", false),
			consecrate_transcendent = setting("auto_crafter_consecrate_transcendent", true),
			level_mastery_20 = setting("auto_crafter_level_mastery_20", false),
			request_mode = setting("auto_crafter_request_mode", "sequential"),
			upgrade_expertise_500 = setting("auto_crafter_upgrade_expertise_500", true),
			reuse_inventory_base = setting("auto_crafter_reuse_inventory_base", true),
			include_favorite_inventory_bases = setting("auto_crafter_include_favorite_inventory_bases", false),
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

	local function operation_context_valid(generation)
		return generation == self._generation and runtime_context_valid() and mutations_enabled()
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
			if self._view_is_valid and self._active_view then
				self:_refresh_plan("operation_refresh")
			end
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

	local function cancel_catalog()
		local promise = self._catalog_promise

		if promise and type(promise.cancel) == "function" then
			pcall(promise.cancel, promise)
		end

		self._catalog_generation = self._catalog_generation + 1
		self._catalog_inflight = false
		self._catalog_promise = nil
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
		self._phase = "trait_discovery"
		report("catalog_discovery_started", {
			reason = reason or "target_changed",
			target = target,
		})

		local backend = self._backend

		if not backend or type(backend.discover_weapon_catalog) ~= "function" then
			self._catalog_inflight = false
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
		self:_schedule_catalog("probe_complete")
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
		local phase3 = self._phase3
		local result = candidate or search and search.result

		if phase3 and phase3.target_candidate then
			result = phase3.target_candidate
		end

		if search then
			search.running = false
			search.result = result or search.best

			if not result and setting("auto_crafter_best_candidate_fallback", false) ~= true then
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
		local mastery_enabled = setting("auto_crafter_level_mastery_20", false) == true
		local allocate_mastery = mastery_enabled and setting("auto_crafter_allocate_mastery_points", false) == true
		local change_perks = mastery_enabled and setting("auto_crafter_change_perks", false) == true
		local change_blessings = allocate_mastery and setting("auto_crafter_change_blessings", false) == true

		if type(catalog) ~= "table" or catalog.available ~= true then
			return nil, "weapon perk/blessing catalogue unavailable"
		end

		local targets = {
			perks = {},
			traits = {},
		}
		local perk_values = {
			setting("auto_crafter_perk_1_target", "keep"),
			setting("auto_crafter_perk_2_target", "auto"),
		}
		local blessing_values = {
			setting("auto_crafter_blessing_1_target", "keep"),
			setting("auto_crafter_blessing_2_target", "auto"),
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

	function self:_phase4_complete(item)
		local phase4 = self._phase4

		if not phase4 or not phase4.running then
			return false
		end

		phase4.running = false
		phase4.result = item
		if self._search then
			self._search.running = false
			self._search.result = item
		end
		self._phase = "phase4_complete"
		operation_report("phase4_complete", {
			candidate = item,
			phase4 = phase4,
		})

		return true
	end

	function self:_phase4_step(generation, snapshot)
		local phase4 = self._phase4
		local backend = self._backend
		local item = phase4 and find_item(snapshot and snapshot.gear and snapshot.gear.items, phase4.gear_id)

		if not phase4 or not phase4.running then
			return false
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

		for index = 1, 2 do
			local desired = phase4.targets.traits[index]

			if desired and sticker_status(phase4.sticker_book, desired.id, desired.rarity) ~= "seen" then
				if not phase4.allocate_mastery then
					self:_operation_failed(generation, "selected blessing tier is not allocated in mastery")
					return false
				end

				if not backend or type(backend.purchase_mastery_trait) ~= "function" or type(backend.get_trait_sticker_book) ~= "function" then
					self:_operation_failed(generation, "mastery blessing allocation adapter unavailable")
					return false
				end

				local purchase_tier = desired.rarity

				for _, blessing in ipairs(phase4.sticker_book or {}) do
					if blessing.id == desired.id then
						for _, tier in ipairs(blessing.tiers or {}) do
							if tonumber(tier.tier) <= tonumber(desired.rarity) and tier.status ~= "seen" then
								purchase_tier = tonumber(tier.tier)
								break
							end
						end
					end
				end

				return self:_dispatch_operation(generation, "phase4_allocate_blessing", function ()
					return backend:purchase_mastery_trait(phase4.mastery_id, desired.id, purchase_tier)
				end, function ()
					self:_dispatch_operation(generation, "phase4_verify_blessing", function ()
						return backend:get_trait_sticker_book(phase4.trait_category)
					end, function (sticker_book)
						phase4.sticker_book = sticker_book
						if sticker_status(sticker_book, desired.id, purchase_tier) ~= "seen" then
							self:_operation_failed(generation, "mastery blessing allocation was not confirmed")
							return
						end
						self:_phase4_step(generation, self._snapshot)
					end)
				end)
			end
		end

		local replacement_groups = {
			{ adapter = "replace_perk", current = item.perks, kind = "perk", targets = phase4.targets.perks },
			{ adapter = "replace_blessing", current = item.traits, kind = "blessing", targets = phase4.targets.traits },
		}

		for _, group in ipairs(replacement_groups) do
			for index = 1, 2 do
				local desired = group.targets[index]
				local current = trait_at(group.current, index)

				if desired and not same_trait(current, desired) then
					local adapter = backend and backend[group.adapter]

					if type(adapter) ~= "function" then
						self:_operation_failed(generation, group.kind .. " replacement adapter unavailable")
						return false
					end

					return self:_dispatch_operation(generation, "phase4_replace_" .. group.kind, function ()
						return adapter(backend, phase4.gear_id, index, desired.id, desired.rarity)
					end, function ()
						self:_refresh_after_operation(generation, function (updated)
							local changed = find_item(updated and updated.gear and updated.gear.items, phase4.gear_id)
							local changed_traits = changed and (group.kind == "perk" and changed.perks or changed.traits)

							if not same_trait(trait_at(changed_traits, index), desired) then
								self:_operation_failed(generation, group.kind .. " replacement was not confirmed")
								return
							end
							phase4.replacement_baseline[group.kind == "perk" and "perks" or "traits"][index] = desired
							self:_phase4_step(generation, updated)
						end)
					end)
				end
			end
		end

		return self:_phase4_complete(item)
	end

	function self:_start_phase4(candidate)
		if not candidate or not candidate.gear_id then
			self:_operation_failed(self._generation, "final crafting candidate unavailable")
			return false
		end

		local consecrate = setting("auto_crafter_consecrate_transcendent", true) == true
		local expertise_enabled = setting("auto_crafter_upgrade_expertise_500", true) == true
		local mastery_enabled = setting("auto_crafter_level_mastery_20", false) == true
		local allocate_mastery = mastery_enabled and setting("auto_crafter_allocate_mastery_points", false) == true
		local change_perks = mastery_enabled and setting("auto_crafter_change_perks", false) == true
		local change_blessings = allocate_mastery and setting("auto_crafter_change_blessings", false) == true

		if not consecrate and not expertise_enabled and not change_perks and not change_blessings then
			if self._search then
				self._search.running = false
			end
			return true
		end

		local item = find_item(self._snapshot and self._snapshot.gear and self._snapshot.gear.items, candidate.gear_id)

		if not item or item.available ~= true then
			self:_operation_failed(self._generation, "final crafting candidate is absent from authoritative inventory")
			return false
		end

		local needs_traits = change_perks or change_blessings
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

		self._phase4 = {
			allocate_mastery = allocate_mastery,
			consecrate = consecrate,
			dump_stat = self._search and self._search.dump_stat,
			expertise = expertise_enabled,
			gear_id = candidate.gear_id,
			mastery_id = candidate.mastery_id or candidate.parent_pattern,
			running = true,
			sticker_book = catalog and catalog.blessings or {},
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
			if next(targets.traits or {}) ~= nil then
				local backend = self._backend

				if not backend or type(backend.get_trait_sticker_book) ~= "function" or not self._phase4.trait_category then
					self:_operation_failed(self._generation, "fresh blessing sticker-book adapter unavailable")
					return
				end

				self:_dispatch_operation(self._generation, "phase4_sticker_preflight", function ()
					return backend:get_trait_sticker_book(self._phase4.trait_category)
				end, function (sticker_book)
					self._phase4.sticker_book = sticker_book
					self:_phase4_step(self._generation, snapshot)
				end)
			else
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

		if not item or item.available ~= true or item.parent_pattern ~= target.mastery_id or tonumber(authoritative_dump) ~= tonumber(target.dump_stat) then
			self:_phase3_stop("phase3_target_reconciliation_failed", current)

			return false
		end

		phase3.running = false
		phase3.current = current or phase3.current
		search.running = false
		search.result = phase3.target_candidate
		self._phase = "phase3_complete"
		operation_report("phase3_complete", {
			candidate = phase3.target_candidate,
			current = phase3.current,
			fodder_count = phase3.fodder_count,
			search = search,
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
			local gear_ids = {}

			for index = phase3.deferred_index or 1, #queue do
				local queued = queue[index]
				local item = queued and find_item(snapshot and snapshot.gear and snapshot.gear.items, queued.gear_id)

				if item then
					if item.available ~= true or item.gear_id == target.gear_id or item.parent_pattern ~= target.mastery_id then
						self:_operation_failed(generation, "deferred weapon cleanup failed authoritative family protection")

						return
					end

					gear_ids[#gear_ids + 1] = item.gear_id
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

		if mastery_target_reached(current) then
			return self:_phase3_discard_deferred(generation, current)
		end

		local queue = phase3.deferred_candidates or {}
		local index = phase3.deferred_index or 1
		local candidate = queue[index]

		if candidate then
			phase3.deferred_index = index + 1

			return self:_phase3_start_fodder(generation, candidate)
		end

		return self:_purchase_search_step(generation)
	end

	function self:_phase3_start_fodder(generation, candidate)
		local phase3 = self._phase3

		if not phase3 or not phase3.running or not candidate or not candidate.gear_id or not candidate.mastery_id then
			self:_phase3_stop("phase3_fodder_candidate_invalid")

			return false
		end

		if self._operation_inflight or self._mastery and self._mastery.running then
			return false
		end

		self._mastery = {
			candidate = candidate,
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
					self:_phase3_finish(current)
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
			self:_phase3_stop("phase3_fodder_refresh_failed")
		end

		return refreshed
	end

	function self:_phase3_check_mastery(generation, candidate)
		local phase3 = self._phase3
		local target = phase3 and (phase3.target_candidate or candidate)
		local backend = self._backend

		if not phase3 or not phase3.running or not target or not target.mastery_id then
			self:_phase3_stop("phase3_mastery_target_missing")

			return false
		end

		if not backend or type(backend.get_mastery_by_pattern) ~= "function" then
			self:_phase3_stop("phase3_mastery_read_unavailable")

			return false
		end

		return self:_dispatch_operation(generation, "phase3_mastery_check", function ()
			return backend:get_mastery_by_pattern(target.mastery_id)
		end, function (data)
			local current = mastery_summary(data)
			local candidate_is_target = phase3.target_candidate and candidate and phase3.target_candidate.gear_id == candidate.gear_id

			if not current or current.mastery_level == nil then
				self:_phase3_stop("phase3_mastery_level_unavailable")

				return
			end

			phase3.current = current
			operation_report("phase3_mastery_check_complete", {
				candidate = candidate,
				current = current,
			})

			if phase3.defer_bad_processing and phase3.target_candidate and candidate and not candidate_is_target then
				if mastery_target_reached(current) then
					phase3.deferred_candidates[#phase3.deferred_candidates + 1] = candidate
					self:_phase3_discard_deferred(generation, current)
				else
					self:_phase3_start_fodder(generation, candidate)
				end
			elseif phase3.defer_bad_processing and phase3.target_candidate then
				self:_phase3_process_deferred(generation, current)
			elseif phase3.target_candidate and mastery_target_reached(current) then
				self:_phase3_finish(current)
			elseif candidate and not candidate_is_target and not mastery_target_reached(current) then
				if setting("auto_crafter_best_candidate_fallback", false) == true then
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
		end)
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

		local include_favorites = setting("auto_crafter_include_favorite_inventory_bases", false) == true
		local best

		for _, candidate in ipairs(self._snapshot and self._snapshot.gear and self._snapshot.gear.items or {}) do
			local family_matches = candidate.parent_pattern ~= nil and candidate.parent_pattern == search.target_offer.parent_pattern
			local favorite_allowed = include_favorites and candidate.favorite_known == true or candidate.favorite_known == true and candidate.favorited ~= true

			if candidate.available == true and family_matches and favorite_allowed and tonumber(candidate_stat(candidate, search.dump_stat)) == tonumber(search.target_dump) then
				local better = not best
					or (tonumber(candidate.expertise_level) or -1) > (tonumber(best.expertise_level) or -1)
					or tonumber(candidate.expertise_level) == tonumber(best.expertise_level) and (tonumber(candidate.rarity) or -1) > (tonumber(best.rarity) or -1)
					or tonumber(candidate.expertise_level) == tonumber(best.expertise_level) and tonumber(candidate.rarity) == tonumber(best.rarity) and tostring(candidate.gear_id) < tostring(best.gear_id)

				if better then
					best = candidate
				end
			end
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

		if not search or not search.running or not target or not price or price <= 0 then
			self:_stop_search("search_blocked")

			return false
		end

		if search.cap_by_max_purchases and search.purchases >= max_purchases then
			self:_stop_search("search_max_purchases")

			return false
		end

		if search.cap_by_dockets and search.spent + price > search.docket_cap then
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

			if not purchase_candidate or not purchase_candidate.gear_id or purchase_candidate.available ~= true then
				self:_operation_failed(generation, "purchase result did not expose a usable weapon")

				return
			end

			search.purchases = search.purchases + 1
			search.spent = search.spent + price

			self:_refresh_after_operation(generation, function (snapshot)
				local candidate = find_item(snapshot and snapshot.gear and snapshot.gear.items, purchase_candidate.gear_id)

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
				search.last = candidate
				self._last_purchased = candidate

				if self:_candidate_is_better(candidate, search.best) then
					search.best = candidate
				end

				operation_report("purchase_result", {
					candidate = candidate,
					search = search,
				})

				local phase3_has_target = self._phase3 and self._phase3.running and self._phase3.target_candidate ~= nil

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

		self._generation = self._generation + 1
		self._search = {
			cap_by_dockets = setting("auto_crafter_cap_by_dockets", false) == true,
			catalog = self._catalog,
			docket_cap = tonumber(setting("auto_crafter_docket_cap", 1000000)) or 0,
			dump_stat = dump_stat,
			favorite_result = setting("auto_crafter_favorite_result", true) == true,
			generation = self._generation,
			cap_by_max_purchases = setting("auto_crafter_cap_by_max_purchases", false) == true,
			max_purchases = tonumber(setting("auto_crafter_max_purchases", 100)) or 0,
			purchases = 0,
			phase3 = setting("auto_crafter_level_mastery_20", false) == true,
			running = true,
			spent = 0,
			target_dump = tonumber(setting("auto_crafter_dump_stat_target", 60)) or 60,
			target_offer = plan.target,
			raw_offer = raw_offer,
		}
		self._phase3 = setting("auto_crafter_level_mastery_20", false) == true and {
			cleanup_started = false,
			current = nil,
			defer_bad_processing = setting("auto_crafter_defer_bad_weapon_processing", false) == true,
			deferred_candidates = {},
			deferred_index = 1,
			fallback_candidate = nil,
			fodder_count = 0,
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
			self:_refresh_after_operation(generation, function (snapshot)
				if find_item(snapshot and snapshot.gear and snapshot.gear.items, mastery.gear_id) then
					self:_operation_failed(generation, "sacrificed mastery item still exists in authoritative gear")

					return
				end

				self:_mastery_claim_after_extract(generation)
			end)
		end)
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
	end

	function self:_mastery_read_baseline(generation, snapshot)
		local mastery = self._mastery
		local backend = self._backend

		if not mastery or not backend or type(backend.get_mastery_by_pattern) ~= "function" then
			self:_operation_failed(generation, "mastery read adapter unavailable")

			return false
		end

		return self:_dispatch_operation(generation, "mastery_baseline", function ()
			return backend:get_mastery_by_pattern(mastery.mastery_id)
		end, function (data)
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
			local xp_converged = current and (mastery_target_reached(current) or current.current_xp and mastery.expected_xp and current.current_xp >= mastery.expected_xp)
			local required_claim = current and current.mastery_level and math.max(0, current.mastery_level - 1)
			local claims_converged = required_claim == nil or current.claimed_level ~= nil and current.claimed_level >= required_claim

			operation_report("mastery_poll_result", {
				current = current,
				attempt = self._mastery_poll_attempts + 1,
			})

			if xp_converged and claims_converged then
				mastery.running = false
				mastery.current = current

				if current and mastery.before and tonumber(current.mastery_level) and tonumber(mastery.before.mastery_level) and current.mastery_level > mastery.before.mastery_level then
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

				return
			end

			self._mastery_poll_attempts = self._mastery_poll_attempts + 1

			if self._mastery_poll_attempts >= MAX_MASTERY_POLL_ATTEMPTS then
				mastery.running = false
				mastery.current = current

				if mastery.phase3 then
					self:_phase3_stop("phase3_mastery_sync_timeout", current)
				else
					self._phase = "mastery_sync_timeout"
					operation_report("mastery_sync_timeout", {
						current = current,
						attempts = self._mastery_poll_attempts,
					})
				end

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
		end

		return self:_schedule_probe("brunt_view_ready")
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
		self._selected_target_key = nil
		self._selected_native_key = nil
		self._planner_signature = nil
		self._frozen_run_settings = nil

		return true
	end

	function self:on_context_exit(reason)
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
		self._selected_target_key = nil
		self._selected_native_key = nil
		self._planner_signature = nil
		self._frozen_run_settings = nil
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

		if setting_id == "auto_crafter_level_mastery_20" and self._phase3 and self._phase3.running and setting("auto_crafter_level_mastery_20", false) ~= true then
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

		if self._view_is_valid and not context_is_valid(self._active_view) then
			self:on_view_closed(self._active_view)
		end

		if self._mastery and self._mastery.running and not self._operation_inflight then
			self._mastery_poll_elapsed = self._mastery_poll_elapsed + finite_dt(dt)

			if self._mastery_poll_elapsed >= (self._mastery_poll_wait or DEFAULT_MASTERY_POLL_DELAY) then
				self:_poll_mastery()
			end
		end

		if self._view_is_valid and not run_is_active() and self._snapshot and not self._probe_inflight and type(self._get_selected_offer) == "function" then
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
			catalog = self._catalog,
			catalog_inflight = self._catalog_inflight,
			last_purchased = self._last_purchased,
			search = self._search,
			phase3 = self._phase3,
			phase4 = self._phase4,
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
	end

	return self
end

return Controller
