--
-- Coordinates staged Games Lantern queue selection with Brunt's deferred tab
-- switch. This module owns no queue cursor and dispatches no account mutation.
local SelectionCoordinator = {}

SelectionCoordinator.CONTRACT_VERSION = "games_lantern_selection_v1"

local DEFAULT_RETRY_INTERVAL = 0.1
local DEFAULT_MAX_ATTEMPTS = 30

local function safe_call(fn, ...)
	if type(fn) ~= "function" then
		return false, "method unavailable"
	end

	return pcall(fn, ...)
end

local function copy_identity(offer)
	if type(offer) ~= "table" then
		return nil
	end

	local identity = {
		offer_id = offer.offer_id or offer.offerId,
		master_id = offer.master_id or offer.masterId,
		slot_type = offer.slot_type,
		tab_index = tonumber(offer.tab_index),
	}

	if identity.offer_id == nil and identity.master_id == nil then
		return nil
	end

	return identity
end

function SelectionCoordinator.new(dependencies)
	dependencies = dependencies or {}

	local self = {
		_current_selection = dependencies.current_selection,
		_max_attempts = math.max(1, math.floor(tonumber(dependencies.max_attempts) or DEFAULT_MAX_ATTEMPTS)),
		_retry_interval = math.max(0.01, tonumber(dependencies.retry_interval) or DEFAULT_RETRY_INTERVAL),
		_original = nil,
		_pending = nil,
		_report = dependencies.report,
		_select_offer = dependencies.select_offer,
		_view_is_valid = dependencies.view_is_valid,
	}

	self._max_wait_seconds = math.max(
		self._retry_interval,
		tonumber(dependencies.max_wait_seconds) or self._retry_interval * self._max_attempts
	)

	local function emit(kind, payload)
		if type(self._report) == "function" then
			pcall(self._report, kind, payload or {})
		end
	end

	local function view_valid(view)
		if type(self._view_is_valid) ~= "function" then
			return view ~= nil
		end

		local ok, valid = safe_call(self._view_is_valid, view)

		return ok and valid == true
	end

	local function fail_pending(pending, timeout_reason)
		emit("selection_failed", {
			attempts = pending.attempts,
			detail = pending.last_detail,
			elapsed = pending.elapsed,
			error = pending.last_error or timeout_reason or "selection unavailable",
			offer = copy_identity(pending.offer),
			reason = pending.reason,
			timeout_reason = timeout_reason,
		})
		self._pending = nil

		return false
	end

	local function attempt(view)
		local pending = self._pending
		if not pending or not view_valid(view) then
			return false
		end

		pending.attempts = pending.attempts + 1
		local ok, selected, selection_error, selection_detail = safe_call(self._select_offer, view, pending.offer)

		if ok and selected == true then
			emit("selection_complete", {
				attempts = pending.attempts,
				offer = copy_identity(pending.offer),
				reason = pending.reason,
			})
			self._pending = nil

			return true
		end

		pending.last_error = ok and tostring(selection_error or "selection unavailable") or tostring(selected)
		pending.last_detail = selection_detail

		if pending.attempts >= self._max_attempts then
			return fail_pending(pending, "attempt_limit")
		end

		return false
	end

	function self:capture_original(view)
		if self._original ~= nil then
			return true
		end

		local ok, selected = safe_call(self._current_selection, view)
		local identity = ok and copy_identity(selected) or nil
		if not identity then
			return false, ok and "selected offer unavailable" or tostring(selected)
		end

		self._original = identity
		emit("selection_original_captured", { offer = copy_identity(identity) })

		return true
	end

	function self:request(view, offer, reason)
		local identity = copy_identity(offer)
		if not identity then
			return false, "invalid offer identity"
		end

		self._pending = {
			attempts = 0,
			elapsed = 0,
			offer = identity,
			reason = tostring(reason or "queue_selection"),
			retry_elapsed = 0,
		}
		attempt(view)

		return true
	end

	function self:update(view, dt)
		local pending = self._pending

		if not pending or not view_valid(view) then
			return false
		end

		local elapsed = math.max(0, tonumber(dt) or self._retry_interval)

		pending.elapsed = pending.elapsed + elapsed
		pending.retry_elapsed = pending.retry_elapsed + elapsed

		if pending.retry_elapsed >= self._retry_interval then
			pending.retry_elapsed = 0

			if attempt(view) then
				return true
			end

			pending = self._pending
		end

		if pending and pending.elapsed >= self._max_wait_seconds then
			return fail_pending(pending, "elapsed_timeout")
		end

		return false
	end

	function self:restore(view)
		local original = self._original
		self._original = nil
		self._pending = nil
		if not original then
			return false, "original selection unavailable"
		end

		return self:request(view, original, "queue_cleared_restore")
	end

	function self:cancel_pending()
		self._pending = nil

		return true
	end

	function self:abandon()
		self._original = nil
		self._pending = nil

		return true
	end

	function self:has_pending()
		return self._pending ~= nil
	end

	function self:snapshot()
		return {
			contract_version = SelectionCoordinator.CONTRACT_VERSION,
			max_wait_seconds = self._max_wait_seconds,
			original = copy_identity(self._original),
			pending = self._pending and {
				attempts = self._pending.attempts,
				elapsed = self._pending.elapsed,
				last_detail = self._pending.last_detail,
				last_error = self._pending.last_error,
				offer = copy_identity(self._pending.offer),
				reason = self._pending.reason,
				retry_elapsed = self._pending.retry_elapsed,
			} or nil,
			retry_interval = self._retry_interval,
		}
	end

	return self
end

return SelectionCoordinator
