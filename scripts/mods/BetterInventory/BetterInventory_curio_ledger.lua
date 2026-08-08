-- Curio rotation ledger. Sanitizes persisted history and bounded pending reports,
-- owns migration/eviction rules, and receives live acquisition state explicitly.
local CurioLedger = {}
local dependencies = {}

local STORE_ROTATION_GRACE_MS = 5000
local STORE_ROTATION_HOUR_MS = 60 * 60 * 1000
local MAX_STORE_ROTATION_AHEAD_MS = 2 * STORE_ROTATION_HOUR_MS
local MAX_ROTATION_HISTORY_ACCOUNTS = 4
local MAX_PENDING_REPORT_ITEMS = 8
local MAX_PENDING_REPORTS = 8
local MAX_PENDING_REPORT_TEXT_LENGTH = 96
local MAX_PENDING_REPORT_ID_LENGTH = 64
local ROTATION_HISTORY_SETTING_ID = "_automatic_curio_rotation_history"
local ROTATION_HISTORY_SCHEMA_VERSION = 3

CurioLedger.configure = function(options)
	dependencies = type(options) == "table" and options or {}
end

local function server_time()
	local callback = dependencies.server_time

	return type(callback) == "function" and callback() or nil
end

local function account_key()
	local callback = dependencies.account_key

	return type(callback) == "function" and callback() or "default"
end

local function enabled(mod)
	local callback = dependencies.enabled

	return type(callback) == "function" and callback(mod) or false
end

local function log_info(mod, message)
	local callback = dependencies.log_info

	if type(callback) == "function" then
		return callback(mod, message)
	end
end

local function bounded_report_text(value, maximum)
	if type(value) ~= "string" then
		return ""
	end

	value = string.gsub(value, "[%c]", " ")

	if #value > maximum then
		return string.sub(value, 1, maximum)
	end

	return value
end

local function sane_rotation_boundary(value, now)
	value = tonumber(value)
	now = tonumber(now) or server_time()

	if not value or value ~= value or not now or value <= now then
		return
	end

	if value > now + MAX_STORE_ROTATION_AHEAD_MS then
		return
	end

	return math.floor(value + 0.5)
end

local function fallback_rotation_boundary(now)
	now = tonumber(now)

	if not now then
		return
	end

	return (math.floor(now / STORE_ROTATION_HOUR_MS) + 1) * STORE_ROTATION_HOUR_MS
end

local function sanitize_pending_report_item(source)
	if type(source) ~= "table" then
		return
	end

	local character_id = bounded_report_text(source.character_id, MAX_PENDING_REPORT_TEXT_LENGTH)
	local character_name = bounded_report_text(source.character_name, MAX_PENDING_REPORT_TEXT_LENGTH)
	local class_name = bounded_report_text(source.class_name, MAX_PENDING_REPORT_TEXT_LENGTH)
	local label_id = bounded_report_text(source.label_id, MAX_PENDING_REPORT_TEXT_LENGTH)
	local currency

	if source.currency == "credits" or source.currency == "marks" then
		currency = source.currency
	end
	local primary_value = tonumber(source.primary_value)
	local item_level = tonumber(source.item_level)
	local price = tonumber(source.price)

	if label_id == "" or not currency or not primary_value or not item_level or not price then
		return
	end

	return {
		character_id = character_id,
		character_name = character_name,
		class_name = class_name,
		item_level = math.max(0, math.floor(item_level + 0.5)),
		label_id = label_id,
		primary_value = primary_value,
		price = math.max(0, math.floor(price + 0.5)),
		unit = bounded_report_text(source.unit, 16),
		currency = currency,
	}
end

local function sanitize_pending_report(source)
	if type(source) ~= "table" then
		return
	end

	local report_id = bounded_report_text(source.report_id, MAX_PENDING_REPORT_ID_LENGTH)

	if report_id == "" then
		return
	end

	local result = {
		account_key = bounded_report_text(source.account_key, MAX_PENDING_REPORT_TEXT_LENGTH),
		context = source.context == "operative_selection" and source.context or "morningstar",
		created_at_ms = tonumber(source.created_at_ms) or 0,
		insufficient = {},
		notification_dispatched = source.notification_dispatched == true,
		partial_failure = source.partial_failure == true,
		purchased = {},
		report_id = report_id,
		spent = {
			credits = 0,
			marks = 0,
		},
	}

	local item_count = 0

	for _, field in ipairs({"purchased", "insufficient"}) do
		local source_items = source[field]

		if type(source_items) == "table" then
			for index = 1, #source_items do
				if item_count >= MAX_PENDING_REPORT_ITEMS then
					break
				end

				local item = sanitize_pending_report_item(source_items[index])

				if item then
					result[field][#result[field] + 1] = item
					item_count = item_count + 1
				end
			end
		end
	end

	local source_spent = source.spent

	if type(source_spent) == "table" then
		for _, currency in ipairs({"credits", "marks"}) do
			result.spent[currency] = math.max(0, math.floor(tonumber(source_spent[currency]) or 0))
		end
	end

	if item_count == 0 then
		return
	end

	return result
end

local function sanitize_pending_reports(source, legacy_report)
	local result = {}
	local seen_ids = {}

	local function append(candidate)
		local report = sanitize_pending_report(candidate)

		if not report or seen_ids[report.report_id] then
			return
		end

		seen_ids[report.report_id] = true
		result[#result + 1] = report
	end

	if type(source) == "table" then
		for index = 1, #source do
			if #result >= MAX_PENDING_REPORTS then
				break
			end

			append(source[index])
		end
	end

	-- Schema 1/2 installations have one pending_report. Migrate it once and
	-- keep all newer reports in the ordered queue thereafter.
	if #result == 0 then
		append(legacy_report)
	end

	return result
end

local function sanitize_rotation_history(source, now)
	local result = {
		schema_version = ROTATION_HISTORY_SCHEMA_VERSION,
		accounts = {},
	}

	if type(source) ~= "table" or type(source.accounts) ~= "table" then
		return result
	end

	local source_schema_version = math.floor(tonumber(source.schema_version) or 1)
	-- Schema 3 only adds the pending-report queue. Schema 2's confirmed
	-- storefront boundaries remain trustworthy during this additive migration.
	local boundaries_are_trusted = source_schema_version >= 2

	for key, entry in pairs(source.accounts) do
		if type(entry) == "table" then
			local account = {}
			local next_refresh_at_ms = tonumber(entry.next_refresh_at_ms)
			local last_successful_scan_at_ms = tonumber(entry.last_successful_scan_at_ms)
			local last_used_at_ms = tonumber(entry.last_used_at_ms)

			-- Schema 1 could persist the next fallback hour after evaluating an
			-- expired pre-refresh response. Preserve reports and account metadata,
			-- but force one safe scan under the confirmed-boundary rules instead of
			-- trusting a potentially poisoned consumption gate.
			if boundaries_are_trusted and next_refresh_at_ms and next_refresh_at_ms > 0 and (not now or next_refresh_at_ms <= now + MAX_STORE_ROTATION_AHEAD_MS) then
				account.next_refresh_at_ms = math.floor(next_refresh_at_ms + 0.5)
			end

			if boundaries_are_trusted and last_successful_scan_at_ms and last_successful_scan_at_ms > 0 then
				account.last_successful_scan_at_ms = math.floor(last_successful_scan_at_ms + 0.5)
			end

			if last_used_at_ms and last_used_at_ms > 0 then
				account.last_used_at_ms = math.floor(last_used_at_ms + 0.5)
			end

			if type(entry.last_context) == "string" and #entry.last_context <= 32 then
				account.last_context = entry.last_context
			end

			account.pending_reports = sanitize_pending_reports(entry.pending_reports, entry.pending_report)

			if account.next_refresh_at_ms or account.last_successful_scan_at_ms or account.last_used_at_ms or #account.pending_reports > 0 then
				result.accounts[tostring(key)] = account
			end
		end
	end

	return result
end

local function ensure_rotation_history(mod, state)
	local account_key = account_key()

	if state.account_key == account_key and state.rotation_history then
		local entry = state.rotation_history.accounts[account_key]

		if not entry then
			entry = {
				pending_reports = {},
			}
			state.rotation_history.accounts[account_key] = entry
		end

		entry.pending_reports = entry.pending_reports or {}

		state.next_rotation_at_ms = entry.next_refresh_at_ms

		return entry
	end

	if state.account_key and state.account_key ~= account_key then
		state.token = state.token + 1
		state.entry_consumed = false
		state.completed = false
		state.elapsed = 0
		state.scan_attempts = 0
		state.scheduled = enabled(mod)
		state.started = false
		state.rotation_boundary_ms = nil
		state.ledger_rotation_boundary_ms = nil
		if dependencies.on_account_changed then
			dependencies.on_account_changed(mod, state)
		end
	end

	state.account_key = account_key
	state.rotation_history = sanitize_rotation_history(mod:get(ROTATION_HISTORY_SETTING_ID), server_time())
	local entry = state.rotation_history.accounts[account_key]

	if not entry then
		entry = {
			pending_reports = {},
		}
		state.rotation_history.accounts[account_key] = entry
	end

	entry.pending_reports = entry.pending_reports or {}

	state.next_rotation_at_ms = entry.next_refresh_at_ms
	state.rotation_boundary_ms = state.next_rotation_at_ms

	return entry
end

local function persist_rotation_boundary(mod, state, boundary_ms, context)
	local entry = ensure_rotation_history(mod, state)
	local now = server_time() or 0

	if not boundary_ms or boundary_ms <= now then
		return false
	end

	entry.next_refresh_at_ms = math.floor(boundary_ms + 0.5)
	entry.last_successful_scan_at_ms = math.floor(now + 0.5)
	entry.last_used_at_ms = math.floor(now + 0.5)
	entry.last_context = context
	state.next_rotation_at_ms = entry.next_refresh_at_ms

	local accounts = state.rotation_history.accounts
	local account_count = 0

	for _ in pairs(accounts) do
		account_count = account_count + 1
	end

	while account_count > MAX_ROTATION_HISTORY_ACCOUNTS do
		local oldest_key
		local oldest_time = math.huge

		for key, value in pairs(accounts) do
			if key ~= state.account_key then
				local used_at = tonumber(value.last_used_at_ms) or 0

				if used_at < oldest_time then
					oldest_key = key
					oldest_time = used_at
				end
			end
		end

		if not oldest_key then
			break
		end

		accounts[oldest_key] = nil
		account_count = account_count - 1
	end

	local success = pcall(mod.set, mod, ROTATION_HISTORY_SETTING_ID, state.rotation_history, false)

	if not success then
		log_info(mod, "Could not persist the Automatic Curio Buyer rotation boundary; session memory remains protective.")
	end

	return success
end

local function commit_rotation_boundary(mod, state, boundary_ms, context)
	local now = server_time()
	boundary_ms = sane_rotation_boundary(boundary_ms, now)

	if not boundary_ms then
		return false
	end

	-- Keep the in-memory gate protective even if the settings write fails. The
	-- boundary is committed only when a pass is terminal or immediately before
	-- the first purchase POST is dispatched.
	state.rotation_boundary_ms = boundary_ms
	state.next_rotation_at_ms = boundary_ms
	state.ledger_rotation_boundary_ms = boundary_ms

	if mod:get("automatic_curio_once_per_store_rotation") ~= false then
		persist_rotation_boundary(mod, state, boundary_ms, context)
		-- persist_rotation_boundary rehydrates state from the old entry before
		-- writing it; restore the committed value for this live session.
		state.next_rotation_at_ms = boundary_ms
	end

	return true
end

local function rotation_gate_status(mod, state)
	if mod:get("automatic_curio_once_per_store_rotation") == false then
		return true
	end

	local now = server_time()

	if not now then
		return
	end

	local entry = ensure_rotation_history(mod, state)
	local next_refresh_at_ms = tonumber(entry.next_refresh_at_ms or state.next_rotation_at_ms)

	if not next_refresh_at_ms then
		return true
	end

	return now >= next_refresh_at_ms + STORE_ROTATION_GRACE_MS
end
CurioLedger.sane_rotation_boundary = sane_rotation_boundary
CurioLedger.fallback_rotation_boundary = fallback_rotation_boundary
CurioLedger.sanitize_pending_report_item = sanitize_pending_report_item
CurioLedger.sanitize_pending_report = sanitize_pending_report
CurioLedger.sanitize_pending_reports = sanitize_pending_reports
CurioLedger.sanitize_rotation_history = sanitize_rotation_history
CurioLedger.ensure_rotation_history = ensure_rotation_history
CurioLedger.persist_rotation_boundary = persist_rotation_boundary
CurioLedger.commit_rotation_boundary = commit_rotation_boundary
CurioLedger.rotation_gate_status = rotation_gate_status

CurioLedger._test = {
	fallback_rotation_boundary = fallback_rotation_boundary,
	sanitize_pending_reports = sanitize_pending_reports,
	sanitize_rotation_history = sanitize_rotation_history,
	sane_rotation_boundary = sane_rotation_boundary,
}

return CurioLedger
