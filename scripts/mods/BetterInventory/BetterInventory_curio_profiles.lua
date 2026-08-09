-- Curio profile/discovery domain. Owns roster cache, slot reconciliation, and
-- generated Mod Options bindings. Live acquisition state stays in its caller.
local CurioProfiles = {}
local dependencies = {}

local DEFAULT_OPERATIVE_SLOT_CAPACITY = 10
local MAX_REASONABLE_OPERATIVE_SLOT_CAPACITY = 64
local PROFILE_DISCOVERY_DELAY = 1
local PROFILE_DISCOVERY_REFRESH_INTERVAL = 300
local PROFILE_DISCOVERY_RETRY_DELAY = 30
local CHARACTER_SELECTION_SETTING_ID = "automatic_curio_character_selection"
local KNOWN_CHARACTERS_SETTING_ID = "_automatic_curio_known_characters"
local CHARACTER_SLOTS_SETTING_ID = "_automatic_curio_character_slots"
local OPERATIVE_SLOT_CAPACITY_SETTING_ID = "_automatic_curio_operative_slot_capacity"
local CHARACTER_SLOT_SETTING_PREFIX = "automatic_curio_character_slot_"

local ARCHETYPE_SETTINGS = {
	adamant = "automatic_curio_class_adamant",
	broker = "automatic_curio_class_broker",
	cryptic = "automatic_curio_class_cryptic",
	ogryn = "automatic_curio_class_ogryn",
	psyker = "automatic_curio_class_psyker",
	veteran = "automatic_curio_class_veteran",
	zealot = "automatic_curio_class_zealot",
}

local function log_info(mod, message)
	local callback = dependencies.log_info

	if type(callback) == "function" then
		return callback(mod, message)
	end
end

local function log_diagnostic(mod, message)
	local callback = dependencies.log_diagnostic

	if type(callback) == "function" then
		return callback(mod, message)
	end
end

local function error_text(value)
	local callback = dependencies.error_text

	if type(callback) == "function" then
		return callback(value)
	end

	return tostring(value or "unknown error")
end

local function is_morningstar()
	local callback = dependencies.is_morningstar

	return type(callback) == "function" and callback() or false
end

local function is_operative_selection()
	local callback = dependencies.is_operative_selection

	return type(callback) == "function" and callback() or false
end

local function call_promise(object, method, ...)
	local callback = dependencies.call_promise

	if type(callback) == "function" then
		return callback(object, method, ...)
	end

	return nil
end

local function track_read_promise(promise)
	local callback = dependencies.track_read_promise

	if type(callback) == "function" then
		return callback(promise)
	end

	return promise
end

local function native_operative_slot_capacity()
	local success, settings = pcall(require, "scripts/ui/views/main_menu_view/main_menu_view_settings")
	local capacity = success and type(settings) == "table" and tonumber(settings.max_num_characters) or nil

	if not capacity or capacity < 1 then
		return DEFAULT_OPERATIVE_SLOT_CAPACITY
	end

	return math.min(math.floor(capacity), MAX_REASONABLE_OPERATIVE_SLOT_CAPACITY)
end

local NATIVE_OPERATIVE_SLOT_CAPACITY = native_operative_slot_capacity()

local profile_state = {
	character_selection = nil,
	character_slots = nil,
	known_profiles = nil,
	profile_discovery_elapsed = 0,
	profile_discovery_inflight = false,
	profile_discovery_pending = false,
	profile_discovery_refresh_elapsed = 0,
	profile_discovery_token = 0,
	profile_revision = 0,
}

CurioProfiles.configure = function(options)
	dependencies = type(options) == "table" and options or {}
end

CurioProfiles.reset_context = function()
	profile_state.profile_discovery_elapsed = 0
	profile_state.profile_discovery_inflight = false
	profile_state.profile_discovery_pending = true
	profile_state.profile_discovery_refresh_elapsed = 0
	profile_state.profile_discovery_token = profile_state.profile_discovery_token + 1
end

CurioProfiles.cancel = function()
	profile_state.profile_discovery_inflight = false
	profile_state.profile_discovery_pending = false
	profile_state.profile_discovery_elapsed = 0
	profile_state.profile_discovery_refresh_elapsed = 0
	profile_state.profile_discovery_token = profile_state.profile_discovery_token + 1
end

CurioProfiles.needs_update = function()
	return profile_state.profile_discovery_inflight or profile_state.profile_discovery_pending
end

local function archetype_name(profile)
	local archetype = profile and profile.archetype
	local name = type(archetype) == "table" and archetype.name or nil

	return type(name) == "string" and name or nil
end

local function class_is_enabled(mod, profile)
	local name = archetype_name(profile)
	local setting_id = name and ARCHETYPE_SETTINGS[name]

	-- A future archetype will not have a dedicated checkbox until BetterInventory
	-- is updated. Include it by default instead of silently making its Curios
	-- unreachable; the backend storefront map remains the final capability check.
	return name ~= nil and (setting_id == nil or mod:get(setting_id) ~= false) or false
end

local function localized_class_name(profile)
	local archetype = profile and profile.archetype
	local localization_id = type(archetype) == "table" and archetype.archetype_name or nil

	if type(localization_id) == "string" and type(Localize) == "function" then
		local success, name = pcall(Localize, localization_id)

		if success and type(name) == "string" and name ~= "" and not string.find(name, "<", 1, true) then
			return name
		end
	end

	local name = archetype_name(profile)

	if name then
		return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
	end

	return "?"
end

local function character_name(profile)
	local name = profile and profile.name

	if type(name) ~= "string" then
		return
	end

	name = string.match(name, "^%s*(.-)%s*$")

	return name ~= "" and name or nil
end

local function profile_label(profile)
	local class_name = localized_class_name(profile)
	local name = character_name(profile)

	return name and string.format("%s(%s)", name, class_name) or class_name
end

local function profile_summary(profile)
	local character_id = profile and profile.character_id

	if not character_id then
		return
	end

	return {
		archetype = archetype_name(profile),
		character_id = tostring(character_id),
		character_name = character_name(profile),
		class_name = localized_class_name(profile),
	}
end

local function sort_profile_summaries(profiles)
	table.sort(profiles, function(left, right)
		local left_name = tostring(left.character_name or left.class_name or "")
		local right_name = tostring(right.character_name or right.class_name or "")

		if left_name ~= right_name then
			return left_name < right_name
		elseif left.class_name ~= right.class_name then
			return tostring(left.class_name) < tostring(right.class_name)
		end

		return tostring(left.character_id) < tostring(right.character_id)
	end)
end

local function same_profile_summaries(left, right)
	if #left ~= #right then
		return false
	end

	for index = 1, #left do
		local left_profile = left[index]
		local right_profile = right[index]

		if left_profile.character_id ~= right_profile.character_id or left_profile.character_name ~= right_profile.character_name or left_profile.class_name ~= right_profile.class_name or left_profile.archetype ~= right_profile.archetype then
			return false
		end
	end

	return true
end

local function sanitize_profile_summaries(profiles)
	local summaries = {}

	if type(profiles) ~= "table" then
		return summaries
	end

	for index = 1, #profiles do
		local source = profiles[index]

		if type(source) == "table" and source.character_id then
			summaries[#summaries + 1] = {
				archetype = type(source.archetype) == "string" and source.archetype or nil,
				character_id = tostring(source.character_id),
				character_name = type(source.character_name) == "string" and source.character_name ~= "" and source.character_name or nil,
				class_name = type(source.class_name) == "string" and source.class_name ~= "" and source.class_name or "?",
			}
		end
	end

	sort_profile_summaries(summaries)

	return summaries
end

local function known_profiles(mod)
	if profile_state.known_profiles == nil then
		profile_state.known_profiles = sanitize_profile_summaries(mod:get(KNOWN_CHARACTERS_SETTING_ID))
	end

	return profile_state.known_profiles
end

local function bounded_slot_capacity(value)
	value = tonumber(value)

	if not value or value < 1 then
		return 0
	end

	return math.min(math.floor(value), MAX_REASONABLE_OPERATIVE_SLOT_CAPACITY)
end

local function stored_slot_extent(slots)
	local extent = 0

	if type(slots) == "table" then
		for key in pairs(slots) do
			local index = tonumber(key)

			if index and index >= 1 and index == math.floor(index) then
				extent = math.max(extent, index)
			end
		end
	end

	return bounded_slot_capacity(extent)
end

local function maximum_operative_slots(mod, observed_profiles)
	local saved_capacity = bounded_slot_capacity(mod:get(OPERATIVE_SLOT_CAPACITY_SETTING_ID))
	local saved_slots = mod:get(CHARACTER_SLOTS_SETTING_ID)
	local capacity = math.max(
		DEFAULT_OPERATIVE_SLOT_CAPACITY,
		NATIVE_OPERATIVE_SLOT_CAPACITY,
		saved_capacity,
		stored_slot_extent(saved_slots),
		bounded_slot_capacity(observed_profiles)
	)

	if saved_capacity ~= capacity then
		mod:set(OPERATIVE_SLOT_CAPACITY_SETTING_ID, capacity, false)
	end

	return capacity
end

local function sanitize_character_slots(source, capacity)
	local slots = {}

	for index = 1, capacity do
		local saved = type(source) == "table" and (source[index] or source[tostring(index)]) or nil
		local character_id = type(saved) == "table" and saved.character_id or nil

		if character_id then
			slots[index] = {
				archetype = type(saved.archetype) == "string" and saved.archetype or nil,
				character_id = tostring(character_id),
				character_name = type(saved.character_name) == "string" and saved.character_name ~= "" and saved.character_name or nil,
				class_name = type(saved.class_name) == "string" and saved.class_name ~= "" and saved.class_name or "?",
				missing_confirmations = math.max(0, math.floor(tonumber(saved.missing_confirmations) or 0)),
			}
		else
			slots[index] = {}
		end
	end

	return slots
end

local function same_character_slots(left, right, capacity)
	for index = 1, capacity do
		local left_slot = left[index] or {}
		local right_slot = right[index] or {}

		if left_slot.character_id ~= right_slot.character_id or left_slot.character_name ~= right_slot.character_name or left_slot.class_name ~= right_slot.class_name or left_slot.archetype ~= right_slot.archetype or (left_slot.missing_confirmations or 0) ~= (right_slot.missing_confirmations or 0) then
			return false
		end
	end

	return true
end

local function known_character_slots(mod, capacity)
	capacity = capacity or maximum_operative_slots(mod)

	if profile_state.character_slots == nil or #profile_state.character_slots ~= capacity then
		profile_state.character_slots = sanitize_character_slots(mod:get(CHARACTER_SLOTS_SETTING_ID), capacity)
	end

	return profile_state.character_slots
end

local function prune_character_exclusion(mod, character_id)
	local saved = mod:get(CHARACTER_SELECTION_SETTING_ID)
	local key = tostring(character_id)

	if type(saved) ~= "table" or saved[key] ~= false then
		return
	end

	local selection = {}

	for saved_id, enabled_value in pairs(saved) do
		if tostring(saved_id) ~= key and enabled_value == false then
			selection[tostring(saved_id)] = false
		end
	end

	mod:set(CHARACTER_SELECTION_SETTING_ID, next(selection) and selection or nil, false)
	profile_state.character_selection = nil
end

local function character_slot_setting_id(index)
	return CHARACTER_SLOT_SETTING_PREFIX .. tostring(index)
end

local function character_slot_index(setting_id)
	if type(setting_id) ~= "string" or string.sub(setting_id, 1, #CHARACTER_SLOT_SETTING_PREFIX) ~= CHARACTER_SLOT_SETTING_PREFIX then
		return nil
	end

	local index = tonumber(string.sub(setting_id, #CHARACTER_SLOT_SETTING_PREFIX + 1))

	if not index or index < 1 or index ~= math.floor(index) then
		return nil
	end

	return index
end

local function character_slot_bindings(mod, slots, summaries)
	local profiles_by_id = {}
	local duplicate_counts = {}
	local saved_selection = mod:get(CHARACTER_SELECTION_SETTING_ID)
	local bindings = {}

	for index = 1, #summaries do
		profiles_by_id[summaries[index].character_id] = summaries[index]
	end

	for index = 1, #slots do
		local slot = slots[index]

		if slot.character_id then
			local label = slot.character_name and string.format("%s(%s)", slot.character_name, slot.class_name) or slot.class_name

			duplicate_counts[label] = (duplicate_counts[label] or 0) + 1
		end
	end

	for index = 1, #slots do
		local slot = slots[index]
		local character_id = slot.character_id
		local available = character_id ~= nil and profiles_by_id[character_id] ~= nil
		local display_name = mod:localize("automatic_curio_character_slot_placeholder") .. " " .. tostring(index)

		if character_id then
			display_name = slot.character_name and string.format("%s(%s)", slot.character_name, slot.class_name) or slot.class_name

			if duplicate_counts[display_name] > 1 then
				display_name = string.format("%s [%s]", display_name, string.sub(character_id, -6))
			end

			if not available then
				display_name = display_name .. " " .. mod:localize("automatic_curio_character_slot_unavailable")
			end
		end

		bindings[index] = {
			available = available,
			character_id = available and character_id or nil,
			display_name = display_name,
			enabled = available and not (type(saved_selection) == "table" and saved_selection[tostring(character_id)] == false) or false,
			setting_id = character_slot_setting_id(index),
		}
	end

	return bindings
end

local function refresh_registered_character_options(mod, slots, summaries)
	local bindings = character_slot_bindings(mod, slots, summaries)
	local dmf = get_mod("DMF")
	local option_sets = dmf and dmf.options_widgets_data

	-- Keep the static slot values synchronized with the backend-ID selection map.
	-- No setting-change notification is emitted here: discovery is presentation
	-- synchronization, not a user filter change.
	for index = 1, #bindings do
		mod:set(bindings[index].setting_id, bindings[index].enabled, false)
	end

	if type(option_sets) ~= "table" then
		return bindings
	end

	for _, widgets in ipairs(option_sets) do
		local header = type(widgets) == "table" and widgets[1]

		if type(header) == "table" and header.mod_name == mod:get_name() then
			for _, widget in ipairs(widgets) do
				local index = type(widget) == "table" and character_slot_index(widget.setting_id) or nil
				local binding = index and bindings[index]

				if binding then
					widget.title = binding.display_name
					widget._better_inventory_curio_character_available = binding.available
					widget._better_inventory_curio_character_id = binding.character_id
					widget._better_inventory_curio_character_slot_index = index
				end
			end

			break
		end
	end

	return bindings
end

local function reconcile_character_slots(mod, summaries, confirm_absences)
	local capacity = maximum_operative_slots(mod, #summaries)
	local previous = known_character_slots(mod, capacity)
	local slots = sanitize_character_slots(previous, capacity)
	local summaries_by_id = {}
	local assigned_ids = {}
	local evicted_ids = {}

	for index = 1, #summaries do
		local summary = summaries[index]

		summaries_by_id[summary.character_id] = summary
	end

	for index = 1, capacity do
		local slot = slots[index]
		local character_id = slot.character_id
		local summary = character_id and summaries_by_id[character_id] or nil

		if summary then
			if not assigned_ids[character_id] then
				slots[index] = {
					archetype = summary.archetype,
					character_id = summary.character_id,
					character_name = summary.character_name,
					class_name = summary.class_name,
					missing_confirmations = 0,
				}
				assigned_ids[character_id] = true
			else
				-- Corrupt or legacy duplicate bindings must not let one character
				-- own multiple DMF rows.
				slots[index] = {}
			end
		elseif character_id and confirm_absences then
			local missing_confirmations = (slot.missing_confirmations or 0) + 1

			if missing_confirmations >= 2 then
				evicted_ids[#evicted_ids + 1] = character_id
				slots[index] = {}
			else
				slot.missing_confirmations = missing_confirmations
			end
		end
	end

	for summary_index = 1, #summaries do
		local summary = summaries[summary_index]

		if not assigned_ids[summary.character_id] then
			for slot_index = 1, capacity do
				if not slots[slot_index].character_id then
					slots[slot_index] = {
						archetype = summary.archetype,
						character_id = summary.character_id,
						character_name = summary.character_name,
						class_name = summary.class_name,
						missing_confirmations = 0,
					}
					assigned_ids[summary.character_id] = true

					break
				end
			end
		end
	end

	if not same_character_slots(previous, slots, capacity) then
		profile_state.character_slots = slots
		profile_state.profile_revision = profile_state.profile_revision + 1
		mod:set(CHARACTER_SLOTS_SETTING_ID, slots, false)
	end

	for index = 1, #evicted_ids do
		prune_character_exclusion(mod, evicted_ids[index])
	end

	if #summaries > capacity then
		log_info(mod, string.format("Discovered %d operatives but only %d stable Mod Options slots are available; all operatives remain available in the inventory panel.", #summaries, capacity))
	end

	refresh_registered_character_options(mod, profile_state.character_slots or slots, summaries)

	return profile_state.character_slots or slots, capacity
end

local function cache_profiles(mod, profiles)
	local summaries = {}

	for index = 1, #(profiles or {}) do
		local summary = profile_summary(profiles[index])

		if summary then
			summaries[#summaries + 1] = summary
		end
	end

	sort_profile_summaries(summaries)
	reconcile_character_slots(mod, summaries, true)

	if not same_profile_summaries(known_profiles(mod), summaries) then
		profile_state.known_profiles = summaries
		profile_state.profile_revision = profile_state.profile_revision + 1
		mod:set(KNOWN_CHARACTERS_SETTING_ID, summaries, false)
	end

	-- Character targeting is the default, but a successful backend response with
	-- no usable character IDs cannot populate its controls or produce a safe
	-- purchase target. Fall back only after that result is confirmed; an initial,
	-- pending, or failed discovery must not overwrite the user's chosen mode.
	if #summaries == 0 and mod:get("automatic_curio_target_mode") == "characters" then
		mod:set("automatic_curio_target_mode", "classes", false)
		log_info(mod, "No usable characters were returned; safely falling back to class targeting.")
	end

	return summaries
end

local function character_selection(mod)
	if profile_state.character_selection == nil then
		local saved = mod:get(CHARACTER_SELECTION_SETTING_ID)

		profile_state.character_selection = {}

		if type(saved) == "table" then
			for character_id, enabled_value in pairs(saved) do
				if enabled_value == false then
					profile_state.character_selection[tostring(character_id)] = false
				end
			end
		end
	end

	return profile_state.character_selection
end

local function character_is_enabled(mod, character_id)
	local selection = character_selection(mod)

	return selection[tostring(character_id)] ~= false
end

local function profile_is_enabled(mod, profile)
	if mod:get("automatic_curio_target_mode") == "characters" then
		return profile and profile.character_id and character_is_enabled(mod, profile.character_id) or false
	end

	return class_is_enabled(mod, profile)
end

local function profiles_service()
	return Managers and Managers.data_service and Managers.data_service.profiles
end

local function update_profile_discovery(mod, dt)
	if not is_morningstar() and not (is_operative_selection() and mod:get("automatic_curio_scan_operative_selection") == true) then
		return
	end

	if not profile_state.profile_discovery_pending then
		profile_state.profile_discovery_refresh_elapsed = profile_state.profile_discovery_refresh_elapsed + (tonumber(dt) or 0)

		if profile_state.profile_discovery_refresh_elapsed < PROFILE_DISCOVERY_REFRESH_INTERVAL then
			return
		end

		profile_state.profile_discovery_pending = true
		profile_state.profile_discovery_elapsed = PROFILE_DISCOVERY_DELAY
	end

	if profile_state.profile_discovery_inflight then
		return
	end

	profile_state.profile_discovery_elapsed = profile_state.profile_discovery_elapsed + (tonumber(dt) or 0)

	if profile_state.profile_discovery_elapsed < PROFILE_DISCOVERY_DELAY then
		return
	end

	local service = profiles_service()

	if not service or type(service.fetch_all_profiles) ~= "function" then
		return
	end

	profile_state.profile_discovery_inflight = true
	local discovery_token = profile_state.profile_discovery_token

	track_read_promise(call_promise(service, service.fetch_all_profiles)):next(function(result)
		if discovery_token ~= profile_state.profile_discovery_token then
			return
		end

		profile_state.profile_discovery_inflight = false

		local profiles = result and result.profiles

		if type(profiles) == "table" then
			cache_profiles(mod, profiles)
			profile_state.profile_discovery_pending = false
			profile_state.profile_discovery_refresh_elapsed = 0
		else
			profile_state.profile_discovery_elapsed = PROFILE_DISCOVERY_DELAY - PROFILE_DISCOVERY_RETRY_DELAY
		end
	end):catch(function(error_value)
		if discovery_token ~= profile_state.profile_discovery_token then
			return
		end

		profile_state.profile_discovery_inflight = false
		profile_state.profile_discovery_elapsed = PROFILE_DISCOVERY_DELAY - PROFILE_DISCOVERY_RETRY_DELAY
		log_diagnostic(mod, "Character discovery failed and will retry later: " .. error_text(error_value))
	end)
end

CurioProfiles.request_profile_discovery = function(force)
	if force == true or profile_state.known_profiles == nil or #profile_state.known_profiles == 0 or profile_state.profile_discovery_refresh_elapsed >= PROFILE_DISCOVERY_REFRESH_INTERVAL then
		profile_state.profile_discovery_pending = true
		profile_state.profile_discovery_elapsed = PROFILE_DISCOVERY_DELAY
	end
end

CurioProfiles.known_profiles = function(mod)
	return known_profiles(mod)
end

CurioProfiles.maximum_operative_slots = function(mod)
	return maximum_operative_slots(mod, #known_profiles(mod))
end

CurioProfiles.character_slots = function(mod)
	local profiles = known_profiles(mod)
	local slots = reconcile_character_slots(mod, profiles, false)

	return slots
end

CurioProfiles.profile_revision = function()
	return profile_state.profile_revision
end

CurioProfiles.character_is_enabled = function(mod, character_id)
	return character_is_enabled(mod, character_id)
end

CurioProfiles.set_character_enabled = function(mod, character_id, enabled_value)
	if not character_id then
		return false
	end

	local existing = character_selection(mod)
	local selection = {}

	for key, value in pairs(existing) do
		selection[key] = value
	end

	local key = tostring(character_id)

	if enabled_value == false then
		selection[key] = false
	else
		selection[key] = nil
	end

	mod:set(CHARACTER_SELECTION_SETTING_ID, next(selection) and selection or nil, false)
	profile_state.character_selection = selection

	for index = 1, #known_character_slots(mod) do
		if known_character_slots(mod)[index].character_id == key then
			mod:set(character_slot_setting_id(index), enabled_value ~= false, false)
			break
		end
	end

	return true
end

CurioProfiles.inject_character_options = function(mod, options_templates)
	local settings = options_templates and options_templates.settings

	if type(settings) ~= "table" then
		return false
	end

	local category_name = mod:get_readable_name()
	local profiles = known_profiles(mod)
	local slots = reconcile_character_slots(mod, profiles, false)
	local bindings = refresh_registered_character_options(mod, slots, profiles)
	local binding_by_title = {}

	if #profiles == 0 then
		CurioProfiles.request_profile_discovery()
	end

	for index = 1, #bindings do
		binding_by_title[bindings[index].display_name] = index
		binding_by_title[mod:localize(bindings[index].setting_id)] = index
	end

	for _, entry in ipairs(settings) do
		local index = type(entry) == "table" and entry.category == category_name and binding_by_title[entry.display_name] or nil
		local binding = index and bindings[index]

		if binding then
			entry._better_inventory_curio_character_available = binding.available
			entry._better_inventory_curio_character_id = binding.character_id
			entry._better_inventory_curio_character_slot_index = index
			entry.display_name = binding.display_name
		end
	end

	return #profiles > 0
end

CurioProfiles.refresh_character_options = function(mod)
	local profiles = known_profiles(mod)
	local slots = reconcile_character_slots(mod, profiles, false)

	refresh_registered_character_options(mod, slots, profiles)
end

CurioProfiles.on_setting_changed = function(mod, setting_id)
	local slot_index = character_slot_index(setting_id)

	if slot_index then
		local slot = known_character_slots(mod)[slot_index]

		if slot and slot.character_id then
			CurioProfiles.set_character_enabled(mod, slot.character_id, mod:get(setting_id) ~= false)
		end

		return
	end

	if setting_id == CHARACTER_SELECTION_SETTING_ID then
		profile_state.character_selection = nil
	end
end

CurioProfiles.update = function(mod, dt)
	update_profile_discovery(mod, dt)
end

CurioProfiles.discovery_inflight = function()
	return profile_state.profile_discovery_inflight
end

CurioProfiles.archetype_name = archetype_name
CurioProfiles.character_name = character_name
CurioProfiles.class_name = localized_class_name
CurioProfiles.profile_label = profile_label
CurioProfiles.class_is_enabled = class_is_enabled
CurioProfiles.profile_is_enabled = profile_is_enabled
CurioProfiles.cache_profiles = cache_profiles
CurioProfiles.reconcile_character_slots = reconcile_character_slots

CurioProfiles._test = {
	ARCHETYPE_SETTINGS = ARCHETYPE_SETTINGS,
	cache_profiles = cache_profiles,
	character_slots = known_character_slots,
	class_is_enabled = class_is_enabled,
	maximum_operative_slots = maximum_operative_slots,
	normalized_profile = profile_summary,
	profile_is_enabled = profile_is_enabled,
	reconcile_character_slots = reconcile_character_slots,
	sanitize_profile_summaries = sanitize_profile_summaries,
}

return CurioProfiles
