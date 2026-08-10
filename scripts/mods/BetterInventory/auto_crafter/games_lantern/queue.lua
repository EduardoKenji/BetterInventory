-- Session-local, serial Games Lantern queue coordinator.
--
-- This module owns no account operation and does not touch persistent settings.
-- It only stages a fully resolved two-slot build and coordinates explicit,
-- boundary-safe transitions supplied by the host Auto Crafter controller.
local Queue = {}

Queue.CONTRACT_VERSION = "games_lantern_queue_v1"

local function safe_call(fn, ...)
	if type(fn) ~= "function" then
		return false, "method unavailable"
	end

	return pcall(fn, ...)
end

local function copy(value, seen)
	if type(value) ~= "table" then
		return value
	end

	seen = seen or {}
	if seen[value] then
		return seen[value]
	end

	local result = {}
	seen[value] = result

	for key, child in pairs(value) do
		result[key] = copy(child, seen)
	end

	return result
end

local function valid_job(job, expected_slot)
	return type(job) == "table" and job.kind == "games_lantern_job" and job.slot == expected_slot and type(job.offer) == "table" and job.dump_stat ~= nil and type(job.perks) == "table" and #job.perks == 2 and type(job.blessings) == "table" and #job.blessings == 2
end

local function valid_build(build)
	if type(build) ~= "table" or build.kind ~= "games_lantern_build" or type(build.jobs) ~= "table" or #build.jobs ~= 2 then
		return false, "invalid_build"
	end

	if not valid_job(build.jobs[1], "melee") then
		return false, "invalid_melee_job"
	end

	if not valid_job(build.jobs[2], "ranged") then
		return false, "invalid_ranged_job"
	end

	return true
end

function Queue.new(dependencies)
	dependencies = dependencies or {}

	local self = {
		_select_job = dependencies.select_job,
		_configure_job = dependencies.configure_job,
		_start_job = dependencies.start_job,
		_stop_job = dependencies.stop_job,
		_view_is_valid = dependencies.view_is_valid,
		_report = dependencies.report,
		_jobs = nil,
		_state = "empty",
		_current_index = 0,
		_last_error = nil,
		_last_event = nil,
		_stop_requested = false,
		_transition_count = 0,
		_selection_attempts = 0,
		_max_selection_attempts = tonumber(dependencies.max_selection_attempts) or 240,
	}

	local function emit(kind, payload)
		if type(self._report) == "function" then
			pcall(self._report, kind, payload or {})
		end
	end

	local function fail(reason, payload)
		self._state = "failed"
		self._last_error = tostring(reason or "queue_failed")
		self._stop_requested = false
		local details = payload or {}
		details.reason = self._last_error
		emit("queue_failed", details)

		return false
	end

	local function view_valid()
		if type(self._view_is_valid) ~= "function" then
			return true
		end

		local ok, valid = safe_call(self._view_is_valid)

		return ok and valid == true
	end

	local function begin_current()
		if self._stop_requested then
			self._state = "stopped"

			return false
		end

		local job = self._jobs and self._jobs[self._current_index]
		if not job then
			self._state = "complete"
			emit("queue_complete", { transition_count = self._transition_count })

			return true
		end

		if not view_valid() then
			return fail("brunt_view_unavailable", { index = self._current_index })
		end

		self._state = "selecting"
		self._selection_attempts = self._selection_attempts + 1
		if self._selection_attempts > self._max_selection_attempts then
			return fail("selection_timeout", { index = self._current_index })
		end

		local selected_ok, selected = safe_call(self._select_job, job, self._current_index)
		if not selected_ok then
			return fail("job_selection_crashed", { index = self._current_index, error = selected })
		end

		if selected ~= true then
			self._state = "selecting"

			return false
		end

		local configured_ok, configured = safe_call(self._configure_job, job, self._current_index)
		if not configured_ok or configured == false then
			return fail("job_configuration_failed", { index = self._current_index, error = configured })
		end

		if self._stop_requested then
			self._state = "stopped"

			return false
		end

		self._state = "dispatching"
		local started_ok, started = safe_call(self._start_job, job, self._current_index)
		if not started_ok or started == false then
			return fail("job_start_failed", { index = self._current_index, error = started })
		end

		self._state = "running"
		emit("queue_job_started", { index = self._current_index, job = job })

		return true
	end

	function self:install(build)
		if self._state == "running" or self._state == "selecting" or self._state == "dispatching" or self._state == "stopping" or self._state == "waiting_next" then
			return false, "queue_busy"
		end

		local valid, reason = valid_build(build)
		if not valid then
			return false, reason
		end

		self._jobs = { copy(build.jobs[1]), copy(build.jobs[2]) }
		self._state = "staged"
		self._current_index = 1
		self._last_error = nil
		self._last_event = nil
		self._stop_requested = false
		self._selection_attempts = 0
		self._transition_count = 0
		emit("queue_installed", { jobs = self._jobs })

		return true
	end

	function self:start()
		if self._state ~= "staged" and self._state ~= "stopped" and self._state ~= "failed" then
			return false, "queue_not_staged"
		end

		self._stop_requested = false
		self._last_error = nil
		self._selection_attempts = 0
		self._state = "starting"
		begin_current()

		return self._state ~= "failed"
	end

	function self:stop(reason)
		if self._state == "empty" or self._state == "complete" or self._state == "failed" or self._state == "stopped" then
			return false
		end

		self._stop_requested = true
		self._state = "stopping"
		local ok, stopped = safe_call(self._stop_job, reason or "queue_stopped")

		if not ok then
			return fail("queue_stop_crashed", { error = stopped })
		end

		if stopped == false then
			return fail("queue_stop_failed", {})
		end

		self._state = "stopped"
		emit("queue_stopped", { index = self._current_index, reason = reason or "queue_stopped" })

		return true
	end

	function self:on_event(kind, payload)
		self._last_event = { kind = kind, payload = copy(payload or {}) }

		if kind == "phase4_complete" then
			if self._state ~= "running" then
				return false
			end

			local completed_index = self._current_index
			self._current_index = self._current_index + 1

			if self._stop_requested then
				self._state = "stopped"

				return true
			end

			self._state = "waiting_next"
			self._transition_count = self._transition_count + 1
			emit("queue_boundary_reached", { index = completed_index, next_index = self._current_index, payload = payload })

			return true
		elseif kind == "character_changed" then
			if self._state == "running" or self._state == "dispatching" or self._state == "selecting" or self._state == "starting" or self._state == "waiting_next" then
				self._state = "failed"
				self._stop_requested = false
				self._last_error = "character_changed"
				emit("queue_failed", { index = self._current_index, reason = self._last_error })

				return true
			end
		elseif kind == "operation_failed" or kind == "phase4_stopped" or kind == "purchase_search_stopped" then
			if self._state == "running" or self._state == "dispatching" or self._state == "selecting" then
				self._state = self._stop_requested and "stopped" or "failed"
				self._last_error = self._stop_requested and nil or tostring(payload and payload.error or kind)
				emit(self._state == "stopped" and "queue_stopped" or "queue_failed", { index = self._current_index, reason = self._last_error })

				return true
			end
		end

		return false
	end

	function self:update()
		if self._state == "selecting" or self._state == "starting" then
			begin_current()
		elseif self._state == "waiting_next" then
			if self._stop_requested then
				self._state = "stopped"
			elseif not view_valid() then
				fail("brunt_view_unavailable_at_boundary", { index = self._current_index })
			else
				self._selection_attempts = 0
				begin_current()
			end
		end

		return self._state
	end

	function self:clear()
		if self._state == "running" or self._state == "selecting" or self._state == "dispatching" or self._state == "stopping" or self._state == "waiting_next" then
			return false, "queue_busy"
		end

		self._jobs = nil
		self._state = "empty"
		self._current_index = 0
		self._last_error = nil
		self._last_event = nil

		return true
	end

	function self:snapshot()
		local jobs = {}

		for index, job in ipairs(self._jobs or {}) do
			jobs[index] = copy(job)
			jobs[index].current = index == self._current_index
			jobs[index].status = index < self._current_index and "complete" or index == self._current_index and self._state or "queued"
		end

		return {
			contract_version = Queue.CONTRACT_VERSION,
			state = self._state,
			current_index = self._current_index,
			job_count = #jobs,
			jobs = jobs,
			last_error = self._last_error,
			last_event = copy(self._last_event),
			stop_requested = self._stop_requested,
			transition_count = self._transition_count,
		}
	end

	return self
end

Queue._test = {
	valid_build = valid_build,
}

return Queue
