-- Session-local, serial Games Lantern queue coordinator.
--
-- This module owns no account operation and does not touch persistent settings.
-- It only stages a fully resolved two-slot build and coordinates explicit,
-- boundary-safe transitions supplied by the host Auto Crafter controller.
local Queue = {}

Queue.CONTRACT_VERSION = "games_lantern_queue_v3"

local QUEUE_SEQUENCE = 0

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

local function valid_custom_profile(job)
	if not job or job.custom_stats_enabled ~= true then return true end
	if type(job.custom_stat_targets) ~= "table" or #job.custom_stat_targets ~= 5 then return false end

	local seen = {}
	local total = 0
	for _, target in ipairs(job.custom_stat_targets) do
		local name = type(target) == "table" and target.name or nil
		local value = tonumber(type(target) == "table" and target.value or nil)
		if name == nil or name == "" or seen[tostring(name)] or value == nil or value ~= math.floor(value) or value < 60 or value > 80 then
			return false
		end
		seen[tostring(name)] = true
		total = total + value
	end

	return total == 380 and (job.custom_stat_total == nil or tonumber(job.custom_stat_total) == total)
end

local function valid_job(job, expected_slot)
	local custom_valid = valid_custom_profile(job)
	return type(job) == "table" and job.kind == "games_lantern_job" and job.slot == expected_slot and type(job.offer) == "table" and job.dump_stat ~= nil and custom_valid and type(job.perks) == "table" and #job.perks == 2 and type(job.blessings) == "table" and #job.blessings == 2
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

local function unresolved_state(state)
	return state == "starting" or state == "selecting" or state == "preflighting" or state == "dispatching" or state == "running" or state == "waiting_next" or state == "stopping" or state == "quarantined" or state == "reconciliation_required"
end

function Queue.new(dependencies)
	dependencies = dependencies or {}

	local self = {
		_select_job = dependencies.select_job,
		_configure_job = dependencies.configure_job,
		_prepare_job = dependencies.prepare_job,
		_start_job = dependencies.start_job,
		_stop_job = dependencies.stop_job,
		_verify_results = dependencies.verify_results,
		_validate_event = dependencies.validate_event,
		_current_character_id = dependencies.current_character_id,
		_view_is_valid = dependencies.view_is_valid,
		_report = dependencies.report,
		_jobs = nil,
		_state = "empty",
		_current_index = 0,
		_planner_index = 0,
		_last_error = nil,
		_last_event = nil,
		_stop_requested = false,
		_transition_count = 0,
		_presentation_cache = nil,
		_presentation_signature = nil,
		_queue_id = nil,
		_completed_results = {},
		_last_terminal_sequence = 0,
		_selected_job_id = nil,
		_configured_job_id = nil,
		_character_id = nil,
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
		details.queue_id = self._queue_id
		emit("queue_failed", details)

		return false
	end

	local function block(reason, payload)
		self._state = "blocked"
		self._last_error = tostring(reason or "queue_blocked")
		self._stop_requested = false
		local details = payload or {}
		details.reason = self._last_error
		details.queue_id = self._queue_id
		emit("queue_blocked", details)

		return false
	end

	local function view_valid()
		if type(self._view_is_valid) ~= "function" then
			return true
		end

		local ok, valid = safe_call(self._view_is_valid)

		return ok and valid == true
	end

	local function accept_completed_result(job, payload, source)
		local gear_id = payload and (payload.gear_id or payload.candidate and (payload.candidate.gear_id or payload.candidate.uuid))
		local character_id = payload and payload.character_id

		if not job or type(payload) ~= "table" or payload.queue_id ~= self._queue_id or payload.job_id ~= job.job_id or gear_id == nil or self._character_id ~= nil and character_id ~= self._character_id then
			return false
		end

		local completed_index = self._current_index
		self._completed_results[completed_index] = {
			character_id = character_id,
			completion_source = source,
			fallback_accepted = payload.phase4 and payload.phase4.fallback_accepted == true,
			fallback_target_distance = tonumber(payload.phase4 and payload.phase4.fallback_target_distance),
			gear_id = gear_id,
			job_id = job.job_id,
			queue_id = self._queue_id,
			terminal_sequence = payload.terminal_sequence,
		}
		self._selected_job_id = nil
		self._configured_job_id = nil
		self._current_index = self._current_index + 1

		if self._stop_requested then
			self._state = "stopped"

			return true
		end

		self._state = "waiting_next"
		self._transition_count = self._transition_count + 1
		if source == "inventory_complete" then
			emit("queue_job_skipped", { index = completed_index, job = job, payload = payload, queue_id = self._queue_id, reason = "already_complete" })
		end
		emit("queue_boundary_reached", { index = completed_index, next_index = self._current_index, payload = payload, queue_id = self._queue_id })

		return true
	end

	local function begin_current()
		if self._stop_requested then
			self._state = "stopped"

			return false
		end

		local job = self._jobs and self._jobs[self._current_index]
		if not job then
			local verified_ok, verified, verify_reason = safe_call(self._verify_results, self._completed_results, self._queue_id, self._jobs)
			if type(self._verify_results) == "function" and (not verified_ok or verified ~= true) then
				return fail("final_queue_verification_failed", { error = verified_ok and verify_reason or verified })
			end

			self._state = "complete"
			emit("queue_complete", { queue_id = self._queue_id, results = copy(self._completed_results), transition_count = self._transition_count })

			return true
		end

		if not view_valid() then
			return fail("brunt_view_unavailable", { index = self._current_index })
		end

		if self._selected_job_id ~= job.job_id then
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
				return false
			end

			self._selected_job_id = job.job_id
		end

		if self._configured_job_id ~= job.job_id then
			local configured_ok, configured = safe_call(self._configure_job, job, self._current_index)
			if not configured_ok or configured == false then
				return fail("job_configuration_failed", { index = self._current_index, error = configured })
			end

			self._configured_job_id = job.job_id
		end

		if type(self._prepare_job) == "function" then
			self._state = "preflighting"
			local prepared_ok, prepared, prepare_reason = safe_call(self._prepare_job, job, self._current_index, self._completed_results, self._jobs)
			if not prepared_ok then
				return fail("job_preflight_crashed", { index = self._current_index, error = prepared })
			elseif prepared == false then
				local reason_text = string.lower(tostring(prepare_reason or ""))
				if reason_text:find("resource", 1, true) or reason_text:find("insufficient", 1, true) or reason_text:find("inventory full", 1, true) or reason_text:find("capacity", 1, true) or reason_text:find("cap", 1, true) then
					return block("job_preflight_blocked", { index = self._current_index, error = prepare_reason })
				end

				return fail("job_preflight_failed", { index = self._current_index, error = prepare_reason })
			elseif type(prepared) == "table" then
				if prepared.kind ~= "games_lantern_completed_inventory_result" or not accept_completed_result(job, prepared, "inventory_complete") then
					return fail("job_preflight_result_invalid", { index = self._current_index })
				end

				return true
			elseif prepared ~= true then
				return false
			end
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
		emit("queue_job_started", { index = self._current_index, job = job, queue_id = self._queue_id })

		return true
	end

	function self:install(build)
		if unresolved_state(self._state) then
			return false, "queue_busy"
		end

		local valid, reason = valid_build(build)
		if not valid then
			return false, reason
		end

		QUEUE_SEQUENCE = QUEUE_SEQUENCE + 1
		self._queue_id = tostring(build.source_uuid or "games_lantern") .. ":" .. tostring(QUEUE_SEQUENCE)
		self._jobs = { copy(build.jobs[1]), copy(build.jobs[2]) }
		local character_ok, character_id = safe_call(self._current_character_id)
		self._character_id = character_ok and character_id or nil
		for index, job in ipairs(self._jobs) do
			job.queue_id = self._queue_id
			job.job_id = self._queue_id .. ":" .. tostring(index)
		end
		self._state = "staged"
		self._current_index = 1
		self._planner_index = 1
		self._last_error = nil
		self._last_event = nil
		self._stop_requested = false
		self._selection_attempts = 0
		self._transition_count = 0
		self._completed_results = {}
		self._last_terminal_sequence = 0
		self._selected_job_id = nil
		self._configured_job_id = nil
		emit("queue_installed", { queue_id = self._queue_id, jobs = self._jobs })

		return true
	end

	function self:start()
		if self._state ~= "staged" and self._state ~= "stopped" and self._state ~= "failed" and self._state ~= "blocked" then
			return false, "queue_not_staged"
		end
		local valid, reason = valid_build({ kind = "games_lantern_build", jobs = self._jobs })
		if not valid then return false, reason end

		self._stop_requested = false
		self._last_error = nil
		self._selection_attempts = 0
		self._state = "starting"
		begin_current()

		return self._state ~= "failed" and self._state ~= "blocked"
	end

	function self:stop(reason)
		if self._state == "empty" or self._state == "complete" or self._state == "failed" or self._state == "stopped" or self._state == "blocked" then
			return false
		end

		self._stop_requested = true
		self._state = "stopping"
		local ok, stopped, settled = safe_call(self._stop_job, reason or "queue_stopped")

		if not ok then
			return fail("queue_stop_crashed", { error = stopped })
		end

		if stopped == false then
			return fail("queue_stop_failed", {})
		end

		if settled ~= false then
			self._state = "stopped"
			emit("queue_stopped", { index = self._current_index, queue_id = self._queue_id, reason = reason or "queue_stopped" })
		end

		return true
	end

	function self:on_event(kind, payload)
		self._last_event = { kind = kind, payload = copy(payload or {}) }

		if kind == "phase4_complete" then
			if self._state ~= "running" then
				return false
			end

			local job = self._jobs and self._jobs[self._current_index]
			local terminal_sequence = tonumber(payload and payload.terminal_sequence)
			local candidate = payload and payload.candidate
			local gear_id = candidate and (candidate.gear_id or candidate.uuid) or payload and payload.gear_id
			local event_ok, event_valid = safe_call(self._validate_event, job, payload)
			if not job or payload.queue_id ~= self._queue_id or payload.job_id ~= job.job_id or self._character_id ~= nil and payload.character_id ~= self._character_id or type(self._validate_event) == "function" and (not event_ok or event_valid ~= true) or not terminal_sequence or terminal_sequence <= self._last_terminal_sequence or gear_id == nil then
				return false
			end

			self._last_terminal_sequence = terminal_sequence

			return accept_completed_result(job, payload, "crafted")
		elseif kind == "character_changed" then
			if unresolved_state(self._state) then
				self._state = "failed"
				self._stop_requested = false
				self._last_error = "character_changed"
				emit("queue_failed", { index = self._current_index, reason = self._last_error })

				return true
			end
		elseif kind == "operation_quarantined" then
			if self._state == "running" or self._state == "stopping" or self._state == "dispatching" then
				self._state = "quarantined"
				self._last_error = tostring(payload and (payload.error or payload.reason) or kind)
				emit("queue_quarantined", { index = self._current_index, queue_id = self._queue_id, reason = self._last_error })

				return true
			end
		elseif kind == "operation_reconciliation_required" then
			if self._state == "running" or self._state == "stopping" or self._state == "quarantined" or self._state == "dispatching" then
				self._state = "reconciliation_required"
				self._last_error = tostring(payload and (payload.error or payload.reason) or kind)
				emit("queue_reconciliation_required", { index = self._current_index, queue_id = self._queue_id, reason = self._last_error })

				return true
			end
		elseif kind == "probe_complete" then
			if self._state == "quarantined" or self._state == "reconciliation_required" then
				self._state = "stopped"
				self._last_error = nil
				emit("queue_stopped", { index = self._current_index, queue_id = self._queue_id, reason = "reconciled" })

				return true
			end
		elseif kind == "operation_failed" or kind == "phase4_stopped" or kind == "purchase_search_stopped" then
			if self._state == "running" or self._state == "stopping" or self._state == "dispatching" or self._state == "selecting" then
				local error_text = string.lower(tostring(payload and (payload.error or payload.reason) or kind))
				local resource_block = error_text:find("resource", 1, true) or error_text:find("insufficient", 1, true) or error_text:find("inventory full", 1, true) or error_text:find("capacity", 1, true) or error_text:find("cap reached", 1, true)
				self._state = self._stop_requested and "stopped" or resource_block and "blocked" or "failed"
				self._last_error = self._stop_requested and nil or tostring(payload and (payload.error or payload.reason) or kind)
				local event = self._state == "stopped" and "queue_stopped" or self._state == "blocked" and "queue_blocked" or "queue_failed"
				emit(event, { index = self._current_index, queue_id = self._queue_id, reason = self._last_error })

				return true
			end
		end

		return false
	end

	function self:update()
		if self._state == "selecting" or self._state == "preflighting" or self._state == "starting" then
			begin_current()
		elseif self._state == "waiting_next" then
			if self._stop_requested then
				self._state = "stopped"
			elseif not view_valid() then
				self._state = "stopped"
				self._last_error = nil
				emit("queue_stopped", { index = self._current_index, queue_id = self._queue_id, reason = "brunt_view_closed_at_boundary" })
			else
				self._selection_attempts = 0
				begin_current()
			end
		end

		return self._state
	end

	function self:clear()
		if unresolved_state(self._state) then
			return false, "queue_busy"
		end

		self._jobs = nil
		self._state = "empty"
		self._current_index = 0
		self._planner_index = 0
		self._last_error = nil
		self._last_event = nil
		self._queue_id = nil
		self._completed_results = {}
		self._last_terminal_sequence = 0
		self._selected_job_id = nil
		self._configured_job_id = nil
		self._character_id = nil
		self._presentation_cache = nil
		self._presentation_signature = nil

		return true
	end

	function self:select_for_planning(index)
		index = tonumber(index)
		if self._state ~= "staged" or index == nil or index ~= math.floor(index) or not self._jobs or not self._jobs[index] then
			return false, self._state ~= "staged" and "queue_editor_locked" or "invalid_queue_index"
		end

		self._planner_index = index
		self._presentation_signature = nil
		emit("queue_planner_selected", { index = index, job = self._jobs[index], queue_id = self._queue_id })

		return true, self._jobs[index]
	end

	function self:update_selected_custom_stat(stat_index, value)
		stat_index = tonumber(stat_index)
		value = tonumber(value)
		local job = self._jobs and self._jobs[self._planner_index]
		local targets = job and job.custom_stat_targets

		if self._state ~= "staged" then
			return false, "queue_editor_locked"
		end
		if not job or job.custom_stats_enabled ~= true or type(targets) ~= "table" or #targets ~= 5 then
			return false, "custom_stats_unavailable"
		end
		if stat_index == nil or stat_index ~= math.floor(stat_index) or stat_index < 1 or stat_index > 5 or value == nil or value ~= math.floor(value) or value < 60 or value > 80 then
			return false, "invalid_custom_stat"
		end

		local total = value
		for index, target in ipairs(targets) do
			if index ~= stat_index then
				total = total + (tonumber(target.value) or 0)
			end
		end
		if total > 380 then
			return false, "custom_stat_total_exceeded"
		end

		targets[stat_index].value = value
		job.custom_stat_total = total
		local lowest = targets[1]
		for index = 2, #targets do
			if targets[index].value < lowest.value then lowest = targets[index] end
		end
		job.dump_stat = lowest.name
		job.dump_stat_label = lowest.label or lowest.display_name_key
		job.dump_target = lowest.value
		self._presentation_signature = nil
		emit("queue_job_edited", { index = self._planner_index, job = job, queue_id = self._queue_id })

		return true, job
	end

	function self:update_selected_trait(kind, target_index, requested)
		target_index = tonumber(target_index)
		local job = self._jobs and self._jobs[self._planner_index]
		local catalog_kind = kind == "perk" and "perks" or kind == "blessing" and "blessings" or nil

		if self._state ~= "staged" then return false, "queue_editor_locked" end
		if not job or not catalog_kind or target_index == nil or target_index ~= math.floor(target_index) or target_index < 1 or target_index > 2 or type(requested) ~= "table" or requested.id == nil then
			return false, "invalid_trait_edit"
		end

		local catalog = job.catalog and job.catalog[catalog_kind] or {}
		local selected
		for _, entry in ipairs(catalog) do
			if entry.id == requested.id then
				local rarity = tonumber(entry.rarity or entry.tier)
				if catalog_kind == "blessings" then
					for _, tier in ipairs(entry.tiers or {}) do rarity = math.max(rarity or 0, tonumber(tier.tier) or 0) end
				end
				if rarity and rarity > 0 and (requested.rarity == nil or tonumber(requested.rarity) == rarity) then
					selected = { id = entry.id, rarity = rarity, label = requested.label or entry.display_name }
					break
				end
			end
		end
		if not selected then return false, "trait_not_in_catalog" end

		local peer_index = target_index == 1 and 2 or 1
		if job[catalog_kind][peer_index] and job[catalog_kind][peer_index].id == selected.id then
			return false, "duplicate_trait_target"
		end

		job[catalog_kind][target_index] = selected
		self._presentation_signature = nil
		emit("queue_job_edited", { index = self._planner_index, job = job, queue_id = self._queue_id })

		return true, job
	end

	function self:snapshot()
		local jobs = {}

		for index, job in ipairs(self._jobs or {}) do
			jobs[index] = copy(job)
			jobs[index].current = index == self._current_index
			jobs[index].selected = index == self._planner_index
			jobs[index].status = index < self._current_index and "complete" or index == self._current_index and self._state or "queued"
		end

		return {
			contract_version = Queue.CONTRACT_VERSION,
			queue_id = self._queue_id,
			character_id = self._character_id,
			state = self._state,
			current_index = self._current_index,
			planner_index = self._planner_index,
			job_count = #jobs,
			jobs = jobs,
			last_error = self._last_error,
			last_event = copy(self._last_event),
			completed_results = copy(self._completed_results),
			last_terminal_sequence = self._last_terminal_sequence,
			stop_requested = self._stop_requested,
			transition_count = self._transition_count,
		}
	end

	function self:state()
		return self._state
	end

	function self:presentation_snapshot()
		local signature = table.concat({
			tostring(self._queue_id or ""),
			tostring(self._state or "empty"),
			tostring(self._current_index or 0),
			tostring(self._planner_index or 0),
			tostring(self._last_error or ""),
		}, "|")
		for _, job in ipairs(self._jobs or {}) do
			for _, target in ipairs(job.custom_stat_targets or {}) do
				signature = signature .. "|" .. tostring(target.name) .. ":" .. tostring(target.value)
			end
		end
		if self._presentation_cache and self._presentation_signature == signature then
			return self._presentation_cache
		end

		local jobs = {}
		for index, job in ipairs(self._jobs or {}) do
			local function compact_targets(values)
				local targets = {}
				for target_index, target in ipairs(values or {}) do
					targets[target_index] = {
						id = target.id,
						label = target.label or target.display_name,
						rarity = target.rarity,
					}
				end
				return targets
			end
			local function compact_stats(values)
				local targets = {}
				for target_index, target in ipairs(values or {}) do
					targets[target_index] = {
						display_name_key = target.display_name_key,
						label = target.label,
						name = target.name,
						value = target.value,
					}
				end
				return targets
			end
			jobs[index] = {
				blessings = compact_targets(job.blessings),
				current = index == self._current_index,
				selected = index == self._planner_index,
				custom_stats_enabled = job.custom_stats_enabled == true,
				custom_stat_targets = compact_stats(job.custom_stat_targets),
				custom_stat_total = job.custom_stat_total,
				display_name = job.display_name or job.offer and job.offer.display_name,
				dump_stat = job.dump_stat,
				dump_stat_label = job.dump_stat_label,
				dump_target = job.dump_target,
				job_id = job.job_id,
				master_id = job.master_id or job.offer and job.offer.master_id,
				perks = compact_targets(job.perks),
				slot = job.slot,
				status = index < self._current_index and "complete" or index == self._current_index and self._state or "queued",
			}
		end

		self._presentation_signature = signature
		self._presentation_cache = {
			current_index = self._current_index,
			planner_index = self._planner_index,
			job_count = #jobs,
			jobs = jobs,
			last_error = self._last_error,
			queue_id = self._queue_id,
			state = self._state,
		}

		return self._presentation_cache
	end

	return self
end

Queue._test = {
	unresolved_state = unresolved_state,
	valid_build = valid_build,
}

return Queue
