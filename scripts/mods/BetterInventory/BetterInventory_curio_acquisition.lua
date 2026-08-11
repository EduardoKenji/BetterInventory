local Promise = require("scripts/foundation/utilities/promise")
local CurioDomains = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_curio_domains")
local CurioProfiles = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_curio_profiles")
local CurioLedger = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_curio_ledger")
local CurioStore = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_curio_store")
local CurioPurchase = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_curio_purchase")
local PromiseContainer

do
	local promise_container_ok, promise_container_module = pcall(require, "scripts/utilities/ui/promise_container")

	if promise_container_ok and type(promise_container_module) == "table" then
		PromiseContainer = promise_container_module
	end
end

local CurioAcquisition = {}

local MORNINGSTAR_DELAY = 6
local OPERATIVE_SELECTION_DELAY = 1
local MAX_SCAN_ATTEMPTS = 3
local RETRY_DELAY = 5
local SCHEDULER_POLL_INTERVAL = 1
local STORE_ROTATION_GRACE_MS = 5000
local STORE_ROTATION_HOUR_MS = 60 * 60 * 1000
local MAX_STORE_ROTATION_AHEAD_MS = 2 * STORE_ROTATION_HOUR_MS
local MAX_ROTATION_HISTORY_ACCOUNTS = 4
local MAX_PENDING_REPORT_ITEMS = 8
local MAX_PENDING_REPORTS = 8
local MAX_PENDING_REPORT_TEXT_LENGTH = 96
local MAX_PENDING_REPORT_ID_LENGTH = 64
local MAX_OFFER_ERROR_LOGS_PER_SCAN = 5
local MAX_ERROR_TEXT_LENGTH = 1000
local PROFILE_DISCOVERY_DELAY = 1
local PROFILE_DISCOVERY_REFRESH_INTERVAL = 300
local PROFILE_DISCOVERY_RETRY_DELAY = 30
local DEFAULT_OPERATIVE_SLOT_CAPACITY = 10
local MAX_REASONABLE_OPERATIVE_SLOT_CAPACITY = 64
local CHARACTER_SELECTION_SETTING_ID = "automatic_curio_character_selection"
local KNOWN_CHARACTERS_SETTING_ID = "_automatic_curio_known_characters"
local CHARACTER_SLOTS_SETTING_ID = "_automatic_curio_character_slots"
local OPERATIVE_SLOT_CAPACITY_SETTING_ID = "_automatic_curio_operative_slot_capacity"
local ROTATION_HISTORY_SETTING_ID = "_automatic_curio_rotation_history"
local ROTATION_HISTORY_SCHEMA_VERSION = 3
local CHARACTER_SLOT_SETTING_PREFIX = "automatic_curio_character_slot_"

local function native_operative_slot_capacity()
	local success, settings = pcall(require, "scripts/ui/views/main_menu_view/main_menu_view_settings")
	local capacity = success and type(settings) == "table" and tonumber(settings.max_num_characters) or nil

	if not capacity or capacity < 1 then
		return DEFAULT_OPERATIVE_SLOT_CAPACITY
	end

	return math.min(math.floor(capacity), MAX_REASONABLE_OPERATIVE_SLOT_CAPACITY)
end

local NATIVE_OPERATIVE_SLOT_CAPACITY = native_operative_slot_capacity()

local PRIMARY_TRAITS = CurioStore._test.PRIMARY_TRAITS

local ARCHETYPE_SETTINGS = {
	adamant = "automatic_curio_class_adamant",
	broker = "automatic_curio_class_broker",
	cryptic = "automatic_curio_class_cryptic",
	ogryn = "automatic_curio_class_ogryn",
	psyker = "automatic_curio_class_psyker",
	veteran = "automatic_curio_class_veteran",
	zealot = "automatic_curio_class_zealot",
}

local state = {
	active_context = nil,
	account_key = nil,
	rotation_history = nil,
	next_rotation_at_ms = nil,
	rotation_boundary_ms = nil,
	ledger_rotation_boundary_ms = nil,
	context_entry_id = 0,
	report_sequence = 0,
	entry_consumed = false,
	scheduled_reason = nil,
	scheduler_poll_elapsed = 0,
	completed = false,
	elapsed = 0,
	hub_character_id = nil,
	last_delivered_report_account = nil,
	last_delivered_report_id = nil,
	read_promise_container = nil,
	read_request_generation = 0,
	read_request_clock = 0,
	read_request_started_at = {},
	oldest_read_request_age = 0,
	active_read_requests = 0,
	operation_snapshot = nil,
	purchase_requests_inflight = 0,
	scan_attempts = 0,
	scheduled = false,
	started = false,
	token = 0,
}
local processed_offer_keys = {}

local function new_read_promise_container()
	if PromiseContainer and type(PromiseContainer.new) == "function" then
		local success, container = pcall(PromiseContainer.new, PromiseContainer)

		if success and container then
			return container
		end
	end

	-- Older/partial test or game environments may not expose the UI helper.
	-- Keep the ownership contract locally: cancellation is best-effort, while
	-- generation checks still make every late callback inert.
	local fallback = {
		_promises = {},
	}

	function fallback:cancel_on_destroy(promise)
		if not promise then
			return promise
		end

		local pending = type(promise.is_pending) ~= "function" or promise:is_pending()

		if pending then
			self._promises[promise] = true

			if type(promise.next) == "function" and type(promise.catch) == "function" then
				promise:next(function()
					self._promises[promise] = nil
				end):catch(function()
					self._promises[promise] = nil
				end)
			end
		end

		return promise
	end

	function fallback:destroy()
		for promise in pairs(self._promises) do
			if type(promise.cancel) == "function" then
				pcall(promise.cancel, promise)
			end
		end

		self._promises = {}
	end

	return fallback
end

if type(CurioDomains) ~= "table" or type(CurioDomains.context) ~= "table" or type(CurioDomains.context.token_matches) ~= "function" or type(CurioDomains.context.snapshot) ~= "function" or type(CurioDomains.context.matches) ~= "function" then
	CurioDomains = {
		context = {
			snapshot = function(current_state)
				return {
					account_key = current_state and current_state.account_key,
					context = current_state and current_state.active_context,
					context_entry_id = current_state and current_state.context_entry_id,
					read_request_generation = current_state and current_state.read_request_generation,
					token = current_state and current_state.token,
				}
			end,
			matches = function(snapshot, current_state)
				return type(snapshot) == "table" and type(current_state) == "table" and snapshot.account_key == current_state.account_key and snapshot.context == current_state.active_context and snapshot.context_entry_id == current_state.context_entry_id and snapshot.read_request_generation == current_state.read_request_generation and snapshot.token == current_state.token
			end,
			token_matches = function(current_state, token)
				return current_state and current_state.token == token
			end,
		},
		reports = {
			upsert_bounded = function(queue, report)
				local result = {}

				for index = 1, #(queue or {}) do
					result[index] = queue[index]
				end

				result[#result + 1] = report

				return result, true
			end,
			remove_head = function(queue)
				local result = {}

				for index = 2, #(queue or {}) do
					result[#result + 1] = queue[index]
				end

				return result, queue and queue[1]
			end,
		},
		scheduler = {
			next_retry_delay = function(context, retry_delay, morningstar_delay, operative_selection_delay)
				local base_delay = context == "operative_selection" and operative_selection_delay or morningstar_delay

				return math.max((tonumber(base_delay) or 0) - (tonumber(retry_delay) or 0), 0)
			end,
		},
	}
end

state.read_promise_container = new_read_promise_container()

local function log_info(mod, message)
	if mod and type(mod.info) == "function" then
		mod:info("[Automatic Curio Buyer] " .. message)
	end
end

local function log_diagnostic(mod, message)
	if mod and mod:get("automatic_curio_diagnostic_logging") == true then
		log_info(mod, message)
	end
end

local function new_scan_diagnostics()
	return {
		curios = 0,
		enabled_profiles = 0,
		eligible = 0,
		exclusions = {},
		offer_errors = 0,
		offer_errors_logged = 0,
		offers = 0,
		profiles = 0,
		storefronts = 0,
	}
end

local function count_exclusion(diagnostics, reason)
	if diagnostics and reason then
		local exclusions = diagnostics.exclusions

		exclusions[reason] = (exclusions[reason] or 0) + 1
	end
end

local function exclusion_summary(exclusions)
	local entries = {}

	for reason, count in pairs(exclusions or {}) do
		entries[#entries + 1] = string.format("%s=%d", reason, count)
	end

	table.sort(entries)

	return #entries > 0 and table.concat(entries, ", ") or "none"
end

local function log_scan_summary(mod, diagnostics)
	log_diagnostic(mod, string.format(
		"Scan diagnostics: profiles=%d, enabled_profiles=%d, storefronts=%d, offers=%d, offer_errors=%d, Curios=%d, eligible=%d; Curio exclusions: %s.",
		diagnostics.profiles,
		diagnostics.enabled_profiles,
		diagnostics.storefronts,
		diagnostics.offers,
		diagnostics.offer_errors,
		diagnostics.curios,
		diagnostics.eligible,
		exclusion_summary(diagnostics.exclusions)
	))
end

local function error_text(error_value)
	local result

	if type(error_value) == "table" then
		local message = error_value.message or error_value.error or error_value[1]

		if message then
			result = tostring(message)
		elseif type(table.tostring) == "function" then
			result = table.tostring(error_value, 2)
		end
	end

	result = result or tostring(error_value)

	if #result > MAX_ERROR_TEXT_LENGTH then
		return string.sub(result, 1, MAX_ERROR_TEXT_LENGTH) .. "... [truncated]"
	end

	return result
end

local function bounded_report_text(value, maximum)
	local text = tostring(value or "")

	if #text > maximum then
		return string.sub(text, 1, maximum)
	end

	return text
end

local function enabled(mod)
	return mod:get("enable_automatic_curio_acquisition") == true
end

local function current_game_mode_name()
	local managers = Managers
	local game_mode = managers and managers.state and managers.state.game_mode

	if not game_mode or type(game_mode.game_mode_name) ~= "function" then
		return
	end

	local success, name = pcall(game_mode.game_mode_name, game_mode)

	return success and name or nil
end

local function is_morningstar()
	local name = current_game_mode_name()

	return name == "hub" or name == "hub_singleplay"
end

local function is_operative_selection()
	local ui_manager = Managers and Managers.ui

	if not ui_manager or type(ui_manager.view_active) ~= "function" then
		return false
	end

	local success, active = pcall(ui_manager.view_active, ui_manager, "main_menu_view")

	return success and active == true
end

local function local_player_safe()
	local player_manager = Managers and Managers.player

	if not player_manager or type(player_manager.local_player_safe) ~= "function" then
		return
	end

	local success, player = pcall(player_manager.local_player_safe, player_manager, 1)

	return success and player or nil
end

local function current_character_id()
	local player = local_player_safe()

	if not player or player.__deleted or type(player.character_id) ~= "function" then
		return
	end

	local success, character_id = pcall(player.character_id, player)

	return success and character_id or nil
end

local function backend_ready()
	local backend = Managers and Managers.backend
	local data_service = Managers and Managers.data_service

	if not backend or type(backend.authenticated) ~= "function" then
		return false
	end

	local authenticated, value = pcall(backend.authenticated, backend)

	if not authenticated or not value then
		return false
	end

	return type(backend.interfaces) == "table" and type(backend.interfaces.store) == "table" and type(backend.interfaces.wallet) == "table" and data_service and data_service.profiles and data_service.store
end

local function application_time()
	if Application and type(Application.time_since_launch) == "function" then
		local success, value = pcall(Application.time_since_launch)

		if success and type(value) == "number" then
			return value
		end
	end

	return 0
end

local function server_time()
	local backend = Managers and Managers.backend

	if backend and type(backend.get_server_time) == "function" then
		local success, value = pcall(backend.get_server_time, backend, application_time())

		if success and type(value) == "number" then
			return value
		end
	end
end

local function current_account_key()
	local backend = Managers and Managers.backend

	if backend and type(backend.account_id) == "function" then
		local success, account_id = pcall(backend.account_id, backend)

		if success and account_id ~= nil and tostring(account_id) ~= "" then
			return tostring(account_id)
		end
	end

	local player = local_player_safe()

	if player and not player.__deleted and type(player.account_id) == "function" then
		local success, account_id = pcall(player.account_id, player)

		if success and account_id ~= nil and tostring(account_id) ~= "" then
			return tostring(account_id)
		end
	end

	return "default"
end

local function sane_rotation_boundary(value, now)
	return CurioLedger.sane_rotation_boundary(value, now)
end

local function fallback_rotation_boundary(now)
	return CurioLedger.fallback_rotation_boundary(now)
end

local function sanitize_pending_report_item(source)
	return CurioLedger.sanitize_pending_report_item(source)
end

local function sanitize_pending_report(source)
	return CurioLedger.sanitize_pending_report(source)
end

local function sanitize_pending_reports(source, legacy_report)
	return CurioLedger.sanitize_pending_reports(source, legacy_report)
end

local function sanitize_rotation_history(source, now)
	return CurioLedger.sanitize_rotation_history(source, now)
end

local function ensure_rotation_history(mod)
	return CurioLedger.ensure_rotation_history(mod, state)
end

local function persist_rotation_boundary(mod, boundary_ms, context)
	return CurioLedger.persist_rotation_boundary(mod, state, boundary_ms, context)
end

local function commit_rotation_boundary(mod, boundary_ms, context)
	return CurioLedger.commit_rotation_boundary(mod, state, boundary_ms, context)
end

local function rotation_gate_status(mod)
	return CurioLedger.rotation_gate_status(mod, state)
end

local function compatible_promise(value)
	return value and type(value.next) == "function" and type(value.catch) == "function"
end

local function reset_read_requests()
	if state.read_promise_container and type(state.read_promise_container.destroy) == "function" then
		pcall(state.read_promise_container.destroy, state.read_promise_container)
	end

	state.read_request_generation = state.read_request_generation + 1
	state.active_read_requests = 0
	state.read_request_started_at = {}
	state.oldest_read_request_age = 0
	state.read_promise_container = new_read_promise_container()
end

local function update_read_request_metrics(dt)
	state.read_request_clock = state.read_request_clock + math.max(tonumber(dt) or 0, 0)
	local oldest_age = 0

	for _, started_at in pairs(state.read_request_started_at) do
		oldest_age = math.max(oldest_age, state.read_request_clock - started_at)
	end

	state.oldest_read_request_age = oldest_age
end

local function track_read_promise(promise)
	if not compatible_promise(promise) then
		return promise
	end

	local request_generation = state.read_request_generation
	local released = false
	local request_id = tostring(promise) .. ":" .. tostring(state.active_read_requests + 1)
	state.read_request_started_at[request_id] = state.read_request_clock
	state.active_read_requests = state.active_read_requests + 1

	local function release_request()
		if released then
			return
		end

		released = true
		state.read_request_started_at[request_id] = nil

		if request_generation == state.read_request_generation then
			state.active_read_requests = math.max(state.active_read_requests - 1, 0)
		end
	end

	local tracked = promise

	if state.read_promise_container and type(state.read_promise_container.cancel_on_destroy) == "function" then
		local track_ok, tracked_promise = pcall(state.read_promise_container.cancel_on_destroy, state.read_promise_container, promise)

		if track_ok and tracked_promise then
			tracked = tracked_promise
		end
	end

	tracked:next(release_request):catch(release_request)

	return tracked
end

local function rejected(reason)
	return Promise.rejected(reason)
end

local function rotation_pending(reason)
	return rejected({
		kind = "store_rotation_pending",
		message = reason,
	})
end

local function call_promise(object, method, ...)
	if type(object) ~= "table" or type(method) ~= "function" then
		return rejected("required backend method is unavailable")
	end

	local success, result = pcall(method, object, ...)

	if not success then
		return rejected(result)
	end

	if not compatible_promise(result) then
		return rejected("backend method returned no compatible promise")
	end

	return result
end

local function context_is_current(mod, token)
	local snapshot = state.operation_snapshot

	if type(snapshot) == "table" and snapshot.token == token then
		if not CurioDomains.context.matches(snapshot, state) then
			return false
		end
	elseif not CurioDomains.context.token_matches(state, token) then
		return false
	end

	if not enabled(mod) then
		return false
	end

	if state.active_context == "morningstar" then
		return is_morningstar()
	elseif state.active_context == "operative_selection" then
		return mod:get("automatic_curio_scan_operative_selection") == true and is_operative_selection()
	end

	return false
end

local function archetype_name(profile)
	return CurioProfiles.archetype_name(profile)
end

local function class_is_enabled(mod, profile)
	return CurioProfiles.class_is_enabled(mod, profile)
end

local function localized_class_name(profile)
	return CurioProfiles.class_name(profile)
end

local function character_name(profile)
	return CurioProfiles.character_name(profile)
end

local function profile_label(profile)
	return CurioProfiles.profile_label(profile)
end

local function known_profiles(mod)
	return CurioProfiles.known_profiles(mod)
end

local function maximum_operative_slots(mod, observed_profiles)
	return CurioProfiles.maximum_operative_slots(mod)
end

local function known_character_slots(mod, capacity)
	return CurioProfiles.character_slots(mod)
end

local function reconcile_character_slots(mod, summaries, confirm_absences)
	return CurioProfiles.reconcile_character_slots(mod, summaries, confirm_absences)
end

local function cache_profiles(mod, profiles)
	return CurioProfiles.cache_profiles(mod, profiles)
end

local function character_is_enabled(mod, character_id)
	return CurioProfiles.character_is_enabled(mod, character_id)
end

local function profile_is_enabled(mod, profile)
	return CurioProfiles.profile_is_enabled(mod, profile)
end

CurioProfiles.configure({
	call_promise = call_promise,
	error_text = error_text,
	is_morningstar = is_morningstar,
	is_operative_selection = is_operative_selection,
	log_diagnostic = log_diagnostic,
	log_info = log_info,
	track_read_promise = track_read_promise,
})

CurioLedger.configure({
	account_key = current_account_key,
	enabled = enabled,
	log_info = log_info,
	on_account_changed = function()
		CurioProfiles.reset_context()
		processed_offer_keys = {}
	end,
	server_time = server_time,
})


local function primary_trait(item)
	return CurioStore.primary_trait(item)
end

local function item_level(item)
	return CurioStore.item_level(item)
end

local function offer_is_active(offer)
	return CurioStore.offer_is_active(offer)
end

local function normalized_offer(mod, profile, offer, diagnostics)
	return CurioStore.normalized_offer(mod, profile, offer, diagnostics)
end

local function candidate_key(candidate)
	return CurioStore.candidate_key(candidate)
end

local function store_method_for_profile(profile)
	return CurioStore.store_method_for_profile(profile)
end

local function fetch_storefront(profile)
	return CurioStore.fetch_storefront(profile)
end

local function observed_rotation_boundary(storefront)
	return CurioStore.observed_rotation_boundary(storefront)
end

local function rotation_boundary_compatible(current_boundary, observed_boundary, missing_metadata)
	return CurioStore.rotation_boundary_compatible(current_boundary, observed_boundary, missing_metadata)
end

local function scan_candidates(mod, token, minimum_rotation_boundary_ms)
	return CurioStore.scan_candidates(mod, token, minimum_rotation_boundary_ms, processed_offer_keys)
end

local function find_offer(storefront, offer_id)
	return CurioPurchase.find_offer(storefront, offer_id)
end

local function candidate_differences(left, right, fields)
	return CurioPurchase.candidate_differences(left, right, fields)
end

local function same_candidate(left, right)
	return CurioPurchase.same_candidate(left, right)
end

local function revalidate_and_purchase(mod, token, captured, on_purchase_dispatch, on_purchase_settle)
	return CurioPurchase.revalidate_and_purchase(mod, token, captured, on_purchase_dispatch, on_purchase_settle, processed_offer_keys)
end

CurioStore.configure({
	application_time = application_time,
	archetype_name = archetype_name,
	cache_profiles = cache_profiles,
	call_promise = call_promise,
	character_name = character_name,
	context_is_current = context_is_current,
	count_exclusion = count_exclusion,
	error_text = error_text,
	localized_class_name = localized_class_name,
	log_diagnostic = log_diagnostic,
	log_info = log_info,
	log_scan_summary = log_scan_summary,
	new_scan_diagnostics = new_scan_diagnostics,
	profile_is_enabled = profile_is_enabled,
	profile_label = profile_label,
	rejected = rejected,
	rotation_pending = rotation_pending,
	sane_rotation_boundary = sane_rotation_boundary,
	server_time = server_time,
	track_read_promise = track_read_promise,
})

CurioPurchase.configure({
	call_promise = call_promise,
	candidate_key = candidate_key,
	context_is_current = context_is_current,
	error_text = error_text,
	fetch_storefront = fetch_storefront,
	log_diagnostic = log_diagnostic,
	log_info = log_info,
	normalized_offer = normalized_offer,
	profile_is_enabled = profile_is_enabled,
	rejected = rejected,
	track_read_promise = track_read_promise,
})

local function notify(mod, title_id, description, final_line, final_line_color)
	local event_manager = Managers and Managers.event

	if not event_manager or type(event_manager.trigger) ~= "function" then
		return false
	end

	local success = pcall(event_manager.trigger, event_manager, "event_add_notification_message", "custom", {
		line_1 = mod:localize(title_id),
		line_1_color = Color.terminal_text_header(255, true),
		line_2 = description,
		line_2_color = Color.white(255, true),
		line_3 = final_line,
		line_3_color = final_line_color,
	})

	return success
end

local function notify_no_eligible(mod)
	if mod:get("automatic_curio_disable_no_eligible_notification") == true then
		return false
	end

	notify(mod, "automatic_curio_none_title", mod:localize("automatic_curio_none_description"))

	return true
end

local function color_channel(mod, setting_id, fallback)
	local value = tonumber(mod:get(setting_id)) or fallback

	return math.floor(math.max(0, math.min(255, value)) + 0.5)
end

local function candidate_line(mod, candidate)
	local config = candidate.primary_config
	local defaults = config.color_default
	local prefix = config.color_prefix
	local red = color_channel(mod, prefix .. "_r", defaults[1])
	local green = color_channel(mod, prefix .. "_g", defaults[2])
	local blue = color_channel(mod, prefix .. "_b", defaults[3])
	local value = tonumber(candidate.primary_value)
	local shown_value = value and (value == math.floor(value) and tostring(math.floor(value)) or tostring(value)) or "?"
	local owner = candidate.character_name and string.format("%s(%s)", candidate.character_name, candidate.class_name) or candidate.class_name
	local text = string.format("%s: %s%s %s (%d)", owner, shown_value, config.unit, mod:localize(config.label_id), candidate.item_level)

	return string.format("{#color(%d,%d,%d)}%s{#reset()}", red, green, blue, text)
end

local function candidate_lines(mod, candidates, partial_failure)
	local lines = {}

	for index = 1, #candidates do
		lines[#lines + 1] = candidate_line(mod, candidates[index])
	end

	if partial_failure then
		lines[#lines + 1] = mod:localize("automatic_curio_partial_failure")
	end

	return table.concat(lines, "\n")
end

local function format_currency(value)
	local value_string = tostring(math.floor((tonumber(value) or 0) + 0.5))
	local formatted = ""
	local count = 0

	for index = #value_string, 1, -1 do
		if count == 3 then
			formatted = " " .. formatted
			count = 0
		end

		formatted = string.sub(value_string, index, index) .. formatted
		count = count + 1
	end

	return formatted
end


local function localized_currency_name(currency)
	local localization_ids = {
		credits = "loc_currency_name_credits",
		marks = "loc_currency_name_marks",
	}
	local localization_id = localization_ids[currency]

	if localization_id and type(Localize) == "function" then
		local success, name = pcall(Localize, localization_id)

		if success and type(name) == "string" and name ~= "" then
			return name
		end
	end

	return tostring(currency)
end

local function spending_line(mod, purchased)
	local totals = {}
	local currencies = {}

	for index = 1, #purchased do
		local candidate = purchased[index]
		local currency = candidate.currency

		if totals[currency] == nil then
			currencies[#currencies + 1] = currency
			totals[currency] = 0
		end

		totals[currency] = totals[currency] + candidate.price
	end

	table.sort(currencies)

	local lines = {}

	for index = 1, #currencies do
		local currency = currencies[index]
		local amount_and_currency = string.format("%s %s", format_currency(totals[currency]), localized_currency_name(currency))

		lines[#lines + 1] = mod:localize("automatic_curio_currency_spent_label") .. " " .. amount_and_currency
	end

	return #lines > 0 and "\n" .. table.concat(lines, "\n") or nil
end

local function compact_pending_report_item(candidate)
	local config = candidate and candidate.primary_config

	if not candidate or type(config) ~= "table" then
		return
	end

	return sanitize_pending_report_item({
		character_id = candidate.character_id,
		character_name = candidate.character_name,
		class_name = candidate.class_name,
		item_level = candidate.item_level,
		label_id = config.label_id,
		primary_value = candidate.primary_value,
		price = candidate.price,
		unit = config.unit,
		currency = candidate.currency,
	})
end

local function build_pending_report(account_key, context, purchased, insufficient, partial_failure, notification_dispatched)
	state.report_sequence = state.report_sequence + 1
	local report = {
		account_key = account_key,
		context = context,
		created_at_ms = server_time() or 0,
		insufficient = {},
		notification_dispatched = notification_dispatched == true,
		partial_failure = partial_failure == true,
		purchased = {},
		report_id = string.format("%s:%s:%d:%d", tostring(context), tostring(math.floor(server_time() or application_time())), state.context_entry_id, state.report_sequence),
		spent = {
			credits = 0,
			marks = 0,
		},
	}

	for _, source in ipairs({
		{field = "purchased", values = purchased},
		{field = "insufficient", values = insufficient},
	}) do
		for index = 1, #(source.values or {}) do
			if #report.purchased + #report.insufficient >= MAX_PENDING_REPORT_ITEMS then
				break
			end

			local item = compact_pending_report_item(source.values[index])

			if item then
				report[source.field][#report[source.field] + 1] = item
				if source.field == "purchased" and report.spent[item.currency] then
					report.spent[item.currency] = report.spent[item.currency] + item.price
				end
			end
		end
	end

	return sanitize_pending_report(report)
end

local function persist_pending_report(mod, account_key, report)
	if not report or not account_key then
		return false
	end

	local history = sanitize_rotation_history(mod:get(ROTATION_HISTORY_SETTING_ID), server_time())
	local entry = history.accounts[account_key] or {}
	local pending_reports = CurioDomains.reports.upsert_bounded(entry.pending_reports or {}, report, MAX_PENDING_REPORTS)

	-- Preserve the newest bounded history. A prune is preferable to allowing
	-- account settings to grow without limit, and delivery remains ordered
	-- for every report retained in the queue.

	entry.pending_reports = pending_reports
	history.accounts[account_key] = entry

	local success = pcall(mod.set, mod, ROTATION_HISTORY_SETTING_ID, history, false)

	if not success then
		log_info(mod, "Could not persist the pending Automatic Curio Buyer report; the confirmed result remains in the current session log.")
	elseif state.account_key == account_key then
		state.rotation_history = history
	end

	return success
end

local function pending_report_item_line(mod, item)
	local owner = item.character_name ~= "" and string.format("%s(%s)", item.character_name, item.class_name) or item.class_name
	local shown_value = item.primary_value == math.floor(item.primary_value) and tostring(math.floor(item.primary_value)) or tostring(item.primary_value)
	local label = item.label_id

	if type(mod.localize) == "function" then
		local success, localized = pcall(mod.localize, mod, item.label_id)

		if success and type(localized) == "string" and localized ~= "" then
			label = localized
		end
	end

	return string.format("%s: %s%s %s (%d)", owner, shown_value, item.unit, label, item.item_level)
end

local function pending_report_description(mod, report)
	local lines = {}

	for index = 1, #report.purchased do
		lines[#lines + 1] = pending_report_item_line(mod, report.purchased[index])
	end

	if #report.insufficient > 0 then
		local insufficient_lines = {}

		for index = 1, #report.insufficient do
			insufficient_lines[#insufficient_lines + 1] = pending_report_item_line(mod, report.insufficient[index])
		end

		lines[#lines + 1] = mod:localize("automatic_curio_insufficient_title") .. ": " .. table.concat(insufficient_lines, "; ")
	end

	if report.partial_failure then
		lines[#lines + 1] = mod:localize("automatic_curio_partial_failure")
	end

	return table.concat(lines, "\n")
end

local function deliver_pending_report(mod)
	if not is_morningstar() or is_operative_selection() then
		return false
	end

	local account_key = state.account_key
	local history = state.rotation_history

	if not account_key or type(history) ~= "table" then
		return false
	end

	local entry = history.accounts[account_key]
	local pending_reports = entry and entry.pending_reports
	local report = pending_reports and pending_reports[1]

	if not report then
		return false
	end

	local already_dispatched = report.notification_dispatched == true or state.last_delivered_report_account == account_key and state.last_delivered_report_id == report.report_id

	if not already_dispatched then
		local title_id = #report.purchased > 0 and "automatic_curio_purchased_title" or "automatic_curio_insufficient_title"
		local delivered = notify(
			mod,
			title_id,
			pending_report_description(mod, report),
			spending_line(mod, report.purchased),
			Color.terminal_corner_selected(255, true)
		)

		if not delivered then
			return false
		end

		state.last_delivered_report_account = account_key
		state.last_delivered_report_id = report.report_id
	end

	local remaining_reports, removed_report = CurioDomains.reports.remove_head(pending_reports)

	if removed_report ~= report then
		return false
	end

	entry.pending_reports = remaining_reports
	local success = pcall(mod.set, mod, ROTATION_HISTORY_SETTING_ID, history, false)

	if not success then
		table.insert(remaining_reports, 1, report)
		entry.pending_reports = remaining_reports
		return false
	end

	if state.account_key == account_key then
		state.rotation_history = history
	end

	local action = already_dispatched and "Acknowledged" or "Delivered"

	log_info(mod, action .. " the pending Automatic Curio Buyer report from " .. tostring(report.context) .. " (" .. tostring(report.report_id) .. ").")

	return true
end

local function refresh_after_purchase()
	local store_service = Managers and Managers.data_service and Managers.data_service.store

	if store_service and type(store_service.invalidate_wallets_cache) == "function" then
		pcall(store_service.invalidate_wallets_cache, store_service)
	end

	local event_manager = Managers and Managers.event

	if event_manager and type(event_manager.trigger) == "function" then
		pcall(event_manager.trigger, event_manager, "event_force_wallet_update")
		pcall(event_manager.trigger, event_manager, "event_force_refresh_inventory")
	end
end

local function report_purchase_outcomes(mod, purchased, insufficient, partial_failure, report_context, report_account_key)
	local reported = false
	local notifications_dispatched = true

	if #purchased > 0 then
		notifications_dispatched = notify(
			mod,
			"automatic_curio_purchased_title",
			candidate_lines(mod, purchased, partial_failure),
			spending_line(mod, purchased),
			Color.terminal_corner_selected(255, true)
		) and notifications_dispatched
		reported = true
	end

	if #insufficient > 0 then
		notifications_dispatched = notify(mod, "automatic_curio_insufficient_title", candidate_lines(mod, insufficient, false)) and notifications_dispatched
		reported = true
	end

	if report_context == "operative_selection" and (#purchased > 0 or #insufficient > 0) then
		local pending_report = build_pending_report(report_account_key, report_context, purchased, insufficient, partial_failure, notifications_dispatched)

		if pending_report then
			-- Persist whether the immediate notification was dispatched. Unlike a
			-- Lua-local marker, this survives module/VM recreation during the loading
			-- transition. Failed dispatches remain eligible for Morningstar fallback.
			persist_pending_report(mod, report_account_key, pending_report)
		end
	end

	return reported
end

local function finish_pass()
	state.completed = true
	state.scheduled = false
	state.started = false
	state.scheduled_reason = nil
end

local function purchase_candidates(mod, token, candidates, boundary_ms)
	local purchased = {}
	local insufficient = {}
	local report_account_key = state.account_key
	local report_context = state.active_context
	local boundary_committed = false
	local chain = Promise.resolved()

	local function commit_before_purchase()
		if boundary_committed then
			return
		end

		boundary_committed = commit_rotation_boundary(mod, boundary_ms, state.active_context)
	end

	local function purchase_dispatched()
		commit_before_purchase()
		state.purchase_requests_inflight = state.purchase_requests_inflight + 1
	end

	local function purchase_settled()
		state.purchase_requests_inflight = math.max(0, state.purchase_requests_inflight - 1)
	end

	for index = 1, #candidates do
		local candidate = candidates[index]

		chain = chain:next(function()
			if not context_is_current(mod, token) then
				return
			end

			return revalidate_and_purchase(mod, token, candidate, purchase_dispatched, purchase_settled):next(function(result)
				if result and result.status == "purchased" and result.candidate then
					purchased[#purchased + 1] = result.candidate
				elseif result and result.status == "insufficient_funds" and result.candidate then
					insufficient[#insufficient + 1] = result.candidate
				end
			end)
		end)
	end

	chain:next(function()
		if not context_is_current(mod, token) then
			-- A purchase POST cannot be cancelled once sent. If the user disables the
			-- feature, changes a filter, or leaves the hub while that request is in
			-- flight, still acknowledge every confirmed spend. The invalid token keeps
			-- the remaining queue inert and must not mutate the newer session state.
			if #purchased > 0 then
				refresh_after_purchase()
			end

			report_purchase_outcomes(mod, purchased, insufficient, false, report_context, report_account_key)

			if #purchased > 0 or #insufficient > 0 then
				log_diagnostic(mod, string.format("Reported %d purchase(s) and %d insufficient-funds match(es) after the pass was cancelled.", #purchased, #insufficient))
			end

			return
		end

		-- No purchase was dispatched, but the current pass completed its full
		-- candidate queue. Consume this rotation after final evaluation so empty
		-- and insufficient-funds passes do not repeat on every context entry.
		if not boundary_committed then
			commit_rotation_boundary(mod, boundary_ms, state.active_context)
		end

		finish_pass()

		if #purchased > 0 then
			refresh_after_purchase()
		end

		local reported = report_purchase_outcomes(mod, purchased, insufficient, false, report_context, report_account_key)

		if reported then
			log_info(mod, string.format("Purchase pass completed with %d purchase(s) and %d insufficient-funds match(es).", #purchased, #insufficient))
		else
			notify_no_eligible(mod)
			log_diagnostic(mod, "No eligible Curios were available after final revalidation.")
		end
	end):catch(function(error_value)
		if not context_is_current(mod, token) then
			if #purchased > 0 then
				refresh_after_purchase()
			end

			report_purchase_outcomes(mod, purchased, insufficient, true, report_context, report_account_key)
			log_info(mod, string.format("Reported %d purchase(s) and %d insufficient-funds match(es) after a cancelled pass encountered an error: %s", #purchased, #insufficient, error_text(error_value)))

			return
		end

		finish_pass()
		if #purchased > 0 then
			refresh_after_purchase()
		end

		report_purchase_outcomes(mod, purchased, insufficient, true, report_context, report_account_key)

		if #purchased == 0 then
			notify(mod, "automatic_curio_failed_title", mod:localize("automatic_curio_failed_description"))
		end

		log_info(mod, "Purchase queue stopped safely: " .. error_text(error_value))
	end)
end

local function schedule_scan_retry(mod, token, error_value)
	if not context_is_current(mod, token) then
		return
	end

	if type(error_value) == "table" and error_value.kind == "store_rotation_pending" then
		state.started = false
		state.elapsed = CurioDomains.scheduler.next_retry_delay(state.active_context, RETRY_DELAY, MORNINGSTAR_DELAY, OPERATIVE_SELECTION_DELAY)
		state.scan_attempts = 0
		state.scheduled = true
		state.scheduled_reason = "rotation_wait"
		log_diagnostic(mod, "Store rotation is not published yet; waiting before the next synchronization check: " .. error_text(error_value))
		return
	end

	state.started = false
	state.elapsed = CurioDomains.scheduler.next_retry_delay(state.active_context, RETRY_DELAY, MORNINGSTAR_DELAY, OPERATIVE_SELECTION_DELAY)
	state.scheduled = state.scan_attempts < MAX_SCAN_ATTEMPTS

	if state.scheduled then
		state.scheduled_reason = "retry"
		log_info(mod, string.format("Scan attempt %d failed; scheduling a bounded retry: %s", state.scan_attempts, error_text(error_value)))
	else
		finish_pass()
		notify(mod, "automatic_curio_failed_title", mod:localize("automatic_curio_failed_description"))
		log_info(mod, "Scan failed after bounded retries: " .. error_text(error_value))
	end
end

local function start_scan(mod)
	local token = state.token
	state.operation_snapshot = CurioDomains.context.snapshot(state)
	state.operation_snapshot.token = token
	local now = server_time()
	local previous_boundary = tonumber(state.rotation_boundary_ms)
	local minimum_rotation_boundary_ms = previous_boundary and now and now >= previous_boundary + STORE_ROTATION_GRACE_MS and previous_boundary or nil

	state.started = true
	state.scan_attempts = state.scan_attempts + 1
	log_diagnostic(mod, string.format("Starting all-character Armoury scan attempt %d.", state.scan_attempts))

	scan_candidates(mod, token, minimum_rotation_boundary_ms):next(function(scan_result)
		if not context_is_current(mod, token) then
			return
		end

		state.scheduled = false

		if type(scan_result) ~= "table" or type(scan_result.candidates) ~= "table" then
			return schedule_scan_retry(mod, token, "scan returned no candidate list")
		end

		local candidates = scan_result.candidates
		local boundary = scan_result.rotation_boundary_ms or fallback_rotation_boundary(server_time())

		if not boundary then
			return schedule_scan_retry(mod, token, "scan returned no trustworthy store rotation boundary")
		end

		-- Keep boundary pending until the pass either finishes evaluation or reaches
		-- the first purchase POST. Leaving during scan/revalidation can therefore
		-- retry the same rotation without risking a duplicate spend.
		state.rotation_boundary_ms = boundary

		log_diagnostic(mod, string.format("Scan found %d eligible Curio offer(s).", #candidates))

		if #candidates == 0 then
			commit_rotation_boundary(mod, boundary, state.active_context)
			finish_pass()
			notify_no_eligible(mod)
		else
			purchase_candidates(mod, token, candidates, boundary)
		end
	end):catch(function(error_value)
		schedule_scan_retry(mod, token, error_value)
	end)
end

local function initialize_context(mod, context)
	reset_read_requests()
	state.token = state.token + 1
	state.active_context = context
	state.context_entry_id = state.context_entry_id + 1
	state.entry_consumed = false
	state.completed = false
	state.elapsed = 0
	state.hub_character_id = nil
	state.scan_attempts = 0
	state.scheduled = enabled(mod)
	state.scheduled_reason = "entry"
	state.started = false
	state.scheduler_poll_elapsed = 0
	CurioProfiles.reset_context()
	state.operation_snapshot = nil
	ensure_rotation_history(mod)
	state.rotation_boundary_ms = state.next_rotation_at_ms

	if mod:get("automatic_curio_once_per_store_rotation") == false then
		processed_offer_keys = {}
	end
end

local function arm_rotation_refresh(mod)
	if state.started or state.scheduled or not state.active_context then
		return
	end

	state.token = state.token + 1
	state.completed = false
	state.elapsed = 0
	state.scan_attempts = 0
	state.scheduled = enabled(mod)
	state.scheduled_reason = "rotation_refresh"
	state.started = false
	state.entry_consumed = true
	processed_offer_keys = {}
	log_diagnostic(mod, "Scheduled one pass after the Armoury store rotation boundary while remaining in the current context.")
end

CurioAcquisition.enter_operative_selection = function(mod)
	if mod:get("automatic_curio_scan_operative_selection") ~= true then
		return false
	end

	initialize_context(mod, "operative_selection")
	return true
end

CurioAcquisition.leave_operative_selection = function()
	if state.active_context == "operative_selection" then
		CurioAcquisition.cancel()
	end
end

CurioAcquisition.leave_morningstar = function()
	if state.active_context == "morningstar" then
		CurioAcquisition.cancel()
	end
end

CurioAcquisition.begin_morningstar_pass = function(mod)
	initialize_context(mod, "morningstar")
end

CurioAcquisition.cancel = function()
	reset_read_requests()
	state.token = state.token + 1
	state.active_context = nil
	state.entry_consumed = false
	state.completed = false
	state.elapsed = 0
	state.hub_character_id = nil
	state.scan_attempts = 0
	state.scheduled = false
	state.scheduled_reason = nil
	state.started = false
	state.next_rotation_at_ms = nil
	state.rotation_boundary_ms = nil
	state.operation_snapshot = nil
	CurioProfiles.cancel()
end

CurioAcquisition.request_profile_discovery = function(force)
	return CurioProfiles.request_profile_discovery(force)
end

CurioAcquisition.known_profiles = function(mod)
	return CurioProfiles.known_profiles(mod)
end

CurioAcquisition.maximum_operative_slots = function(mod)
	return CurioProfiles.maximum_operative_slots(mod)
end

CurioAcquisition.character_slots = function(mod)
	return CurioProfiles.character_slots(mod)
end

CurioAcquisition.profile_revision = function()
	return CurioProfiles.profile_revision()
end

CurioAcquisition.character_is_enabled = function(mod, character_id)
	return CurioProfiles.character_is_enabled(mod, character_id)
end

CurioAcquisition.set_character_enabled = function(mod, character_id, enabled_value)
	return CurioProfiles.set_character_enabled(mod, character_id, enabled_value)
end

CurioAcquisition.inject_character_options = function(mod, options_templates)
	return CurioProfiles.inject_character_options(mod, options_templates)
end

CurioAcquisition.refresh_character_options = function(mod)
	return CurioProfiles.refresh_character_options(mod)
end

CurioAcquisition.on_setting_changed = function(mod, setting_id)
	CurioProfiles.on_setting_changed(mod, setting_id)

	if setting_id == "enable_automatic_curio_acquisition" then
		if enabled(mod) then
			if state.active_context then
				initialize_context(mod, state.active_context)
			else
				state.completed = false
				state.scheduled = false
				state.started = false
				state.elapsed = 0
				state.scan_attempts = 0
				state.token = state.token + 1
			end
		else
			CurioAcquisition.cancel()
		end
	elseif setting_id == "automatic_curio_scan_operative_selection" then
		if state.active_context == "operative_selection" and mod:get(setting_id) ~= true then
			CurioAcquisition.cancel()
		elseif mod:get(setting_id) == true and is_operative_selection() and enabled(mod) then
			initialize_context(mod, "operative_selection")
		end
	elseif setting_id == "automatic_curio_once_per_store_rotation" then
		if state.active_context and not state.started then
			if state.entry_consumed then
				state.completed = true
				state.scheduled = false
				state.scheduled_reason = nil
			else
				state.completed = false
				state.scheduled = true
				state.scheduled_reason = "entry"
				state.elapsed = 0
			end
		end
	elseif setting_id == "automatic_curio_rescan_on_store_refresh" then
		if mod:get(setting_id) ~= true and state.scheduled_reason == "rotation_refresh" and not state.started then
			state.completed = true
			state.scheduled = false
			state.scheduled_reason = nil
		end
	elseif setting_id ~= "automatic_curio_diagnostic_logging" and setting_id ~= "automatic_curio_rescan_on_store_refresh" and type(setting_id) == "string" and string.sub(setting_id, 1, 16) == "automatic_curio_" and state.started then
		state.token = state.token + 1
		state.completed = true
		state.scheduled = false
		state.started = false
	end
end

CurioAcquisition.update = function(mod, dt, automatic_discard_busy)
	update_read_request_metrics(dt)
	ensure_rotation_history(mod)
	deliver_pending_report(mod)
	CurioProfiles.update(mod, dt)

	if not enabled(mod) then
		if state.active_context or state.scheduled or state.started then
			CurioAcquisition.cancel()
		end

		return
	end

	if not state.active_context then
		if is_morningstar() then
			CurioAcquisition.begin_morningstar_pass(mod)
		elseif is_operative_selection() and mod:get("automatic_curio_scan_operative_selection") == true then
			CurioAcquisition.enter_operative_selection(mod)
		else
			return
		end
	end

	if state.active_context == "morningstar" then
		if not is_morningstar() then
			CurioAcquisition.cancel()
			return
		end

		local character_id = current_character_id()

		if not character_id then
			return
		end

		if not state.hub_character_id then
			state.hub_character_id = character_id
			log_diagnostic(mod, "Observed a ready Morningstar session for the scheduled all-character pass.")
		end
	elseif state.active_context == "operative_selection" then
		if mod:get("automatic_curio_scan_operative_selection") ~= true or not is_operative_selection() then
			CurioAcquisition.cancel()
			return
		end
	else
		CurioAcquisition.cancel()
		return
	end

	local now = server_time()

	if state.next_rotation_at_ms and now and now >= state.next_rotation_at_ms + STORE_ROTATION_GRACE_MS and state.ledger_rotation_boundary_ms == state.next_rotation_at_ms then
		-- Offer IDs are safe to reuse only after the observed store boundary. A
		-- fresh ledger lets the new rotation consider the same slot again.
		processed_offer_keys = {}
		state.ledger_rotation_boundary_ms = nil
	end

	if state.completed then
		state.scheduler_poll_elapsed = state.scheduler_poll_elapsed + (tonumber(dt) or 0)

		if state.scheduler_poll_elapsed < SCHEDULER_POLL_INTERVAL then
			return
		end

		state.scheduler_poll_elapsed = 0

		if mod:get("automatic_curio_rescan_on_store_refresh") == true and state.rotation_boundary_ms then
			local now = server_time()

			if now and now >= state.rotation_boundary_ms + STORE_ROTATION_GRACE_MS then
				arm_rotation_refresh(mod)
			end
		end

		return
	end

	if not state.scheduled or state.started then
		return
	end

	if state.active_context == "morningstar" and automatic_discard_busy then
		return
	end

	state.elapsed = state.elapsed + (tonumber(dt) or 0)
	local delay = state.active_context == "operative_selection" and OPERATIVE_SELECTION_DELAY or MORNINGSTAR_DELAY

	if state.elapsed < delay or not backend_ready() then
		return
	end

	if state.active_context == "operative_selection" and CurioProfiles.discovery_inflight() then
		-- Do not compete with the menu's roster synchronization. The next scheduler
		-- tick will start the buyer after the shared profile request settles.
		return
	end

	local gate = rotation_gate_status(mod)

	if gate == nil then
		return
	elseif gate == false then
		state.entry_consumed = true
		finish_pass()
		log_diagnostic(mod, "Skipped scheduled pass because the current Armoury store rotation was already consumed.")
		return
	end

	if state.active_context == "morningstar" then
		local progression_manager = Managers and Managers.progression

		if progression_manager and type(progression_manager.is_fetching_session_report) == "function" and progression_manager:is_fetching_session_report() then
			state.elapsed = 0
			return
		end
	end

	state.entry_consumed = true
	start_scan(mod)
end

CurioAcquisition.needs_update = function(mod)
	if state.active_context ~= nil
		or state.scheduled
		or state.started
		or state.active_read_requests > 0
		or CurioProfiles.needs_update() then
		return true
	end

	if not state.rotation_history or not state.account_key then
		return true
	end

	local entry = state.rotation_history.accounts and state.rotation_history.accounts[state.account_key]
	local pending_reports = entry and entry.pending_reports

	if pending_reports and pending_reports[1] ~= nil then
		return true
	end

	return enabled(mod) and (is_morningstar() or mod:get("automatic_curio_scan_operative_selection") == true and is_operative_selection()) or false
end

CurioAcquisition.active_read_request_count = function()
	return state.active_read_requests
end

CurioAcquisition.read_request_generation = function()
	return state.read_request_generation
end

CurioAcquisition.oldest_read_request_age = function()
	return state.oldest_read_request_age
end

CurioAcquisition.is_busy = function()
	return state.started == true or state.purchase_requests_inflight > 0
end

CurioAcquisition.account_mutation_inflight = function()
	return state.purchase_requests_inflight > 0
end

CurioAcquisition.defer_for_account_operation = function(mod)
	if state.purchase_requests_inflight > 0 then
		return false, "automatic Curio acquisition has a purchase request in flight"
	end

	local profile_work_pending = CurioProfiles.needs_update()
	local read_work_pending = state.active_read_requests > 0

	if state.started or read_work_pending or profile_work_pending then
		-- Auto Crafter may preempt Curio Buyer while it is doing read-only scans or
		-- revalidation. Generation invalidation makes late GET callbacks inert; the
		-- same pass remains scheduled and resumes after crafting releases the gate.
		reset_read_requests()
		CurioProfiles.cancel()
		state.token = state.token + 1
		state.completed = false
		state.elapsed = 0
		state.scan_attempts = 0
		state.scheduled = enabled(mod) and state.active_context ~= nil
		state.scheduled_reason = state.scheduled and "account_operation_deferred" or nil
		state.started = false
		state.operation_snapshot = nil

		if profile_work_pending and state.scheduled then
			CurioProfiles.request_profile_discovery(true)
		end
	end

	return true
end

CurioAcquisition._test = {
	ARCHETYPE_SETTINGS = ARCHETYPE_SETTINGS,
	PRIMARY_TRAITS = PRIMARY_TRAITS,
	cache_profiles = cache_profiles,
	candidate_differences = candidate_differences,
	candidate_key = candidate_key,
	character_slots = known_character_slots,
	class_is_enabled = class_is_enabled,
	fallback_rotation_boundary = fallback_rotation_boundary,
	maximum_operative_slots = maximum_operative_slots,
	normalized_offer = normalized_offer,
	observed_rotation_boundary = observed_rotation_boundary,
	rotation_boundary_compatible = rotation_boundary_compatible,
	primary_trait = primary_trait,
	profile_is_enabled = profile_is_enabled,
	reconcile_character_slots = reconcile_character_slots,
	rotation_gate_status = rotation_gate_status,
	sanitize_pending_reports = sanitize_pending_reports,
	sanitize_rotation_history = sanitize_rotation_history,
	sane_rotation_boundary = sane_rotation_boundary,
	same_candidate = same_candidate,
	operation_snapshot = function()
		return state.operation_snapshot
	end,
}

return CurioAcquisition
