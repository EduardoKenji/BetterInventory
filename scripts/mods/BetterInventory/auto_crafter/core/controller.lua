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

function Controller.new(dependencies)
	dependencies = dependencies or {}

	local self = {
		_backend = dependencies.backend,
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

		return true
	end

	function self:on_context_exit(reason)
		invalidate_generation()
		cancel_probe()
		self._active_view = nil
		self._view_is_valid = false
		self._phase = "context_exit"
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
		}
	end

	function self:shutdown()
		invalidate_generation()
		cancel_probe()
		self._active_view = nil
		self._view_is_valid = false
		self._phase = "shutdown"
	end

	return self
end

return Controller
