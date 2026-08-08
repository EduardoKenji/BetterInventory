local Controller = {}

local DEFAULT_PROBE_DELAY = 0.5

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

	local planner_setting_ids = {
		auto_crafter_target_dump_stat = true,
		auto_crafter_dump_stat_target = true,
		auto_crafter_docket_cap = true,
		auto_crafter_max_purchases = true,
		auto_crafter_best_candidate_fallback = true,
		auto_crafter_request_mode = true,
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

	function self:on_brunt_view_ready(view)
		if not view or not context_is_valid(view) then
			return false
		end

		if self._active_view ~= view then
			cancel_probe()
			invalidate_generation()
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
			self._phase = "disabled"
			self._plan = nil
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
			last_probe_at = self._last_probe_at,
			last_error = self._last_error,
			data = self._snapshot,
			plan = self._plan,
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
		self._selected_target_key = nil
		self._selected_native_key = nil
		self._planner_signature = nil
	end

	return self
end

return Controller
