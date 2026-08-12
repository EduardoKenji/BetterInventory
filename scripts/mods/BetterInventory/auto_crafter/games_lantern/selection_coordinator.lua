--
-- Coordinates staged Games Lantern queue selection with Brunt's deferred tab
-- switch. This module owns no queue cursor and dispatches no account mutation.
local SelectionCoordinator = {}

SelectionCoordinator.CONTRACT_VERSION = "games_lantern_selection_v1"

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
		_max_attempts = math.max(1, math.floor(tonumber(dependencies.max_attempts) or 30)),
		_original = nil,
		_pending = nil,
		_report = dependencies.report,
		_select_offer = dependencies.select_offer,
		_view_is_valid = dependencies.view_is_valid,
	}

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

	local function attempt(view)
		local pending = self._pending
		if not pending or not view_valid(view) then
			return false
		end

		pending.attempts = pending.attempts + 1
		local ok, selected = safe_call(self._select_offer, view, pending.offer)

		if ok and selected == true then
			emit("selection_complete", {
				attempts = pending.attempts,
				offer = copy_identity(pending.offer),
				reason = pending.reason,
			})
			self._pending = nil

			return true
		end

		if pending.attempts >= self._max_attempts then
			emit("selection_failed", {
				attempts = pending.attempts,
				error = ok and "selection unavailable" or tostring(selected),
				offer = copy_identity(pending.offer),
				reason = pending.reason,
			})
			self._pending = nil
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
			offer = identity,
			reason = tostring(reason or "queue_selection"),
		}
		attempt(view)

		return true
	end

	function self:update(view)
		return attempt(view)
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
			original = copy_identity(self._original),
			pending = self._pending and {
				attempts = self._pending.attempts,
				offer = copy_identity(self._pending.offer),
				reason = self._pending.reason,
			} or nil,
		}
	end

	return self
end

return SelectionCoordinator
