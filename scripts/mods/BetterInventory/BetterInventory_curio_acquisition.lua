local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")
local Promise = require("scripts/foundation/utilities/promise")
local StoreNames = require("scripts/settings/backend/store_names")
local CurioValues = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_curio_values")

if type(CurioValues) ~= "table" then
	CurioValues = {
		resolve = function()
			return
		end,
	}
end

local CurioAcquisition = {}

local MORNINGSTAR_DELAY = 6
local MAX_SCAN_ATTEMPTS = 3
local RETRY_DELAY = 5
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

local PRIMARY_TRAITS = {
	gadget_innate_health_increase = {
		color_default = {235, 85, 85},
		color_prefix = "curio_health_color",
		minimum_roll_default = 21,
		minimum_roll_setting_id = "automatic_curio_min_health",
		setting_id = "automatic_curio_buy_health",
		label_id = "automatic_curio_health",
		unit = "%",
	},
	gadget_innate_toughness_increase = {
		color_default = {105, 200, 235},
		color_prefix = "curio_toughness_color",
		minimum_roll_default = 17,
		minimum_roll_setting_id = "automatic_curio_min_toughness",
		setting_id = "automatic_curio_buy_toughness",
		label_id = "automatic_curio_toughness",
		unit = "%",
	},
	gadget_innate_max_wounds_increase = {
		color_default = {190, 105, 230},
		color_prefix = "curio_wound_color",
		setting_id = "automatic_curio_buy_wounds",
		label_id = "automatic_curio_wounds",
		unit = "",
	},
	gadget_stamina_increase = {
		color_default = {235, 205, 80},
		color_prefix = "curio_stamina_color",
		setting_id = "automatic_curio_buy_stamina",
		label_id = "automatic_curio_stamina",
		unit = "",
	},
}

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
	character_selection = nil,
	character_slots = nil,
	completed = false,
	elapsed = 0,
	hub_character_id = nil,
	known_profiles = nil,
	profile_discovery_elapsed = 0,
	profile_discovery_inflight = false,
	profile_discovery_pending = false,
	profile_discovery_refresh_elapsed = 0,
	profile_discovery_token = 0,
	profile_revision = 0,
	scan_attempts = 0,
	scheduled = false,
	started = false,
	token = 0,
}
local processed_offer_keys = {}

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

local function current_character_id()
	local player_manager = Managers and Managers.player
	local player

	if player_manager and type(player_manager.local_player) == "function" then
		local success, value = pcall(player_manager.local_player, player_manager, 1)

		player = success and value or nil
	end

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

local function compatible_promise(value)
	return value and type(value.next) == "function" and type(value.catch) == "function"
end

local function rejected(reason)
	return Promise.rejected(reason)
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
	return state.token == token and enabled(mod) and is_morningstar()
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
	if state.known_profiles == nil then
		state.known_profiles = sanitize_profile_summaries(mod:get(KNOWN_CHARACTERS_SETTING_ID))
	end

	return state.known_profiles
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

	if state.character_slots == nil or #state.character_slots ~= capacity then
		state.character_slots = sanitize_character_slots(mod:get(CHARACTER_SLOTS_SETTING_ID), capacity)
	end

	return state.character_slots
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
	state.character_selection = nil
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
		state.character_slots = slots
		state.profile_revision = state.profile_revision + 1
		mod:set(CHARACTER_SLOTS_SETTING_ID, slots, false)
	end

	for index = 1, #evicted_ids do
		prune_character_exclusion(mod, evicted_ids[index])
	end

	if #summaries > capacity then
		log_info(mod, string.format("Discovered %d operatives but only %d stable Mod Options slots are available; all operatives remain available in the inventory panel.", #summaries, capacity))
	end

	refresh_registered_character_options(mod, state.character_slots or slots, summaries)

	return state.character_slots or slots, capacity
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
		state.known_profiles = summaries
		state.profile_revision = state.profile_revision + 1
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
	if state.character_selection == nil then
		local saved = mod:get(CHARACTER_SELECTION_SETTING_ID)

		state.character_selection = {}

		if type(saved) == "table" then
			for character_id, enabled_value in pairs(saved) do
				if enabled_value == false then
					state.character_selection[tostring(character_id)] = false
				end
			end
		end
	end

	return state.character_selection
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

local function primary_trait(item)
	local traits = item and item.traits

	if type(traits) ~= "table" then
		return
	end

	for index = 1, #traits do
		local entry = traits[index]
		local trait_name, value = CurioValues.resolve(entry)
		local config = trait_name and PRIMARY_TRAITS[trait_name]

		if config then
			return trait_name, value, config
		end
	end
end

local function item_level(item)
	if not item or type(Items.expertise_level) ~= "function" then
		return
	end

	local success, level = pcall(Items.expertise_level, item, true)

	return success and tonumber(level) or nil
end

local function offer_is_active(offer)
	if not offer or type(offer) ~= "table" then
		return false
	end

	if type(offer.state) == "string" and offer.state ~= "active" then
		return false
	end

	if type(offer.is_valid_at) == "function" then
		local now = server_time()

		if now then
			local success, valid = pcall(offer.is_valid_at, offer, now)

			if not success or not valid then
				return false
			end
		end
	end

	return true
end

local function log_curio_evaluation(mod, profile, offer_id, level, trait_name, trait_value, result)
	log_diagnostic(mod, string.format(
		"%s Curio offer %s: item_level=%s, primary_trait=%s, primary_value=%s; %s.",
		profile_label(profile),
		tostring(offer_id or "?"),
		tostring(level or "?"),
		tostring(trait_name or "?"),
		tostring(trait_value or "?"),
		result
	))
end

local function normalized_offer(mod, profile, offer, diagnostics)
	local sku = offer and offer.sku
	local description = offer and offer.description
	local offer_id = offer and offer.offerId
	local price = offer and offer.price and offer.price.amount

	if diagnostics then
		diagnostics.offers = diagnostics.offers + 1
	end

	if not offer_is_active(offer) or not sku or sku.category ~= "item_instance" or type(description) ~= "table" or not offer_id or type(price) ~= "table" then
		return
	end

	local resolved, item = pcall(MasterItems.get_store_item_instance, description)

	if not resolved or not item or item.item_type ~= "GADGET" then
		return
	end

	if diagnostics then
		diagnostics.curios = diagnostics.curios + 1
	end

	local level = item_level(item)
	local minimum_level = math.clamp(math.floor(tonumber(mod:get("automatic_curio_min_item_level")) or 410), 0, 500)

	if not level then
		count_exclusion(diagnostics, "unreadable_item_level")

		if diagnostics then
			log_curio_evaluation(mod, profile, offer_id, level, nil, nil, "excluded: unreadable item level")
		end

		return
	elseif level < minimum_level then
		count_exclusion(diagnostics, "below_minimum_level")

		if diagnostics then
			log_curio_evaluation(mod, profile, offer_id, level, nil, nil, "excluded: below configured minimum " .. tostring(minimum_level))
		end

		return
	end

	local trait_name, trait_value, trait_config = primary_trait(item)

	if not trait_name or not trait_config then
		count_exclusion(diagnostics, "unsupported_primary_trait")

		if diagnostics then
			log_curio_evaluation(mod, profile, offer_id, level, trait_name, trait_value, "excluded: unsupported or unreadable primary trait")
		end

		return
	elseif mod:get(trait_config.setting_id) == false then
		count_exclusion(diagnostics, "primary_type_disabled")

		if diagnostics then
			log_curio_evaluation(mod, profile, offer_id, level, trait_name, trait_value, "excluded: primary type disabled")
		end

		return
	end

	if trait_config.minimum_roll_setting_id then
		local minimum_roll = math.clamp(tonumber(mod:get(trait_config.minimum_roll_setting_id)) or trait_config.minimum_roll_default, 0, 100)

		if not trait_value then
			count_exclusion(diagnostics, "unreadable_primary_value")

			if diagnostics then
				log_curio_evaluation(mod, profile, offer_id, level, trait_name, trait_value, "excluded: unreadable primary value for configured roll threshold")
			end

			return
		elseif trait_value + 0.0001 < minimum_roll then
			count_exclusion(diagnostics, "below_minimum_primary_roll")

			if diagnostics then
				log_curio_evaluation(mod, profile, offer_id, level, trait_name, trait_value, "excluded: below configured primary-roll minimum " .. tostring(minimum_roll))
			end

			return
		end
	end

	local amount = tonumber(price.amount)
	local currency = price.type

	if not amount or amount < 0 or type(currency) ~= "string" then
		count_exclusion(diagnostics, "invalid_price")

		if diagnostics then
			log_curio_evaluation(mod, profile, offer_id, level, trait_name, trait_value, "excluded: invalid price")
		end

		return
	end

	if diagnostics then
		diagnostics.eligible = diagnostics.eligible + 1
		log_curio_evaluation(mod, profile, offer_id, level, trait_name, trait_value, string.format("eligible at %s %s", tostring(amount), currency))
	end

	return {
		archetype = archetype_name(profile),
		character_id = profile.character_id,
		character_name = character_name(profile),
		class_name = localized_class_name(profile),
		currency = currency,
		gear_id = description.gear_id or description.gearId,
		item_level = math.floor(level + 0.5),
		offer = offer,
		offer_id = offer_id,
		price = amount,
		primary_config = trait_config,
		primary_trait = trait_name,
		primary_value = trait_value,
		profile = profile,
	}
end

local function candidate_key(candidate)
	return table.concat({
		tostring(candidate.character_id or "?"),
		tostring(candidate.offer_id or "?"),
	}, ":")
end

local function store_method_for_profile(profile)
	local store_interface = Managers and Managers.backend and Managers.backend.interfaces and Managers.backend.interfaces.store
	local by_archetype = StoreNames and StoreNames.by_archetype and StoreNames.by_archetype.credit
	local method_name = by_archetype and by_archetype[archetype_name(profile)]
	local method = method_name and store_interface and store_interface[method_name]

	return store_interface, method
end

local function fetch_storefront(profile)
	local store_interface, method = store_method_for_profile(profile)

	if not method then
		return rejected("no Armoury storefront mapping for " .. tostring(archetype_name(profile)))
	end

	return call_promise(store_interface, method, application_time(), profile.character_id)
end

local function scan_candidates(mod, token)
	local profiles_service = Managers and Managers.data_service and Managers.data_service.profiles

	if not profiles_service or type(profiles_service.fetch_all_profiles) ~= "function" then
		return rejected("ProfilesService.fetch_all_profiles is unavailable")
	end

	return call_promise(profiles_service, profiles_service.fetch_all_profiles):next(function(result)
		if not context_is_current(mod, token) then
			return {}
		end

		local profiles = result and result.profiles

		if type(profiles) ~= "table" then
			return rejected("profile scan returned no profile list")
		end

		cache_profiles(mod, profiles)

		local candidates = {}
		local chain = Promise.resolved()
		local diagnostics = new_scan_diagnostics()

		diagnostics.profiles = #profiles

		for index = 1, #profiles do
			local profile = profiles[index]

			if profile and profile.character_id and profile_is_enabled(mod, profile) then
				diagnostics.enabled_profiles = diagnostics.enabled_profiles + 1
				local _, storefront_method = store_method_for_profile(profile)

				if storefront_method then
					chain = chain:next(function()
					if not context_is_current(mod, token) then
						return
					end

					return fetch_storefront(profile):next(function(storefront)
						if not context_is_current(mod, token) then
							return
						end

						local offers = storefront and storefront.data and storefront.data.personal

						if type(offers) ~= "table" then
							return rejected("Armoury storefront returned no personal offers")
						end

						diagnostics.storefronts = diagnostics.storefronts + 1

						local offers_before = diagnostics.offers
						local curios_before = diagnostics.curios
						local eligible_before = diagnostics.eligible

						for offer_index = 1, #offers do
							local success, candidate = pcall(normalized_offer, mod, profile, offers[offer_index], diagnostics)

							if success and candidate and not processed_offer_keys[candidate_key(candidate)] then
								candidates[#candidates + 1] = candidate
							elseif not success then
								diagnostics.offer_errors = diagnostics.offer_errors + 1

								if diagnostics.offer_errors_logged < MAX_OFFER_ERROR_LOGS_PER_SCAN then
									diagnostics.offer_errors_logged = diagnostics.offer_errors_logged + 1
									log_info(mod, "Safety-excluded an unreadable offer: " .. error_text(candidate))
								end
							end
						end

						log_diagnostic(mod, string.format(
							"%s storefront summary: offers=%d, Curios=%d, eligible=%d.",
							profile_label(profile),
							diagnostics.offers - offers_before,
							diagnostics.curios - curios_before,
							diagnostics.eligible - eligible_before
						))
					end)
					end)
				else
					log_diagnostic(mod, profile_label(profile) .. " was skipped because Darktide exposes no Armoury storefront for its archetype.")
				end
			end
		end

		return chain:next(function()
			if diagnostics.offer_errors > diagnostics.offer_errors_logged then
				log_info(mod, string.format(
					"Suppressed %d additional unreadable-offer error log(s) during this scan.",
					diagnostics.offer_errors - diagnostics.offer_errors_logged
				))
			end

			log_scan_summary(mod, diagnostics)

			table.sort(candidates, function(left, right)
				if left.class_name ~= right.class_name then
					return left.class_name < right.class_name
				elseif left.item_level ~= right.item_level then
					return left.item_level > right.item_level
				end

				return tostring(left.offer_id) < tostring(right.offer_id)
			end)

			return candidates
		end)
	end)
end

local function find_offer(storefront, offer_id)
	local offers = storefront and storefront.data and storefront.data.personal

	if type(offers) ~= "table" then
		return
	end

	for index = 1, #offers do
		if offers[index] and offers[index].offerId == offer_id then
			return offers[index]
		end
	end
end

local STABLE_REVALIDATION_FIELDS = {
	"character_id",
	"offer_id",
	"currency",
	"price",
	"item_level",
	"primary_trait",
}

local VOLATILE_REVALIDATION_FIELDS = {
	"gear_id",
	"primary_value",
}

local function candidate_differences(left, right, fields)
	local differences = {}

	if not left or not right then
		return {"candidate_missing"}
	end

	for index = 1, #fields do
		local field = fields[index]

		if left[field] ~= right[field] then
			differences[#differences + 1] = string.format("%s:%s->%s", field, tostring(left[field]), tostring(right[field]))
		end
	end

	return differences
end

local function same_candidate(left, right)
	return #candidate_differences(left, right, STABLE_REVALIDATION_FIELDS) == 0
end

local function find_wallet(wallets, currency)
	if type(wallets) ~= "table" then
		return
	end

	for index = 1, #wallets do
		local wallet = wallets[index]
		local balance = wallet and wallet.balance

		if balance and balance.type == currency then
			return wallet
		end
	end
end

local function fetch_target_wallet(candidate)
	local wallet_interface = Managers and Managers.backend and Managers.backend.interfaces and Managers.backend.interfaces.wallet

	if not wallet_interface then
		return rejected("wallet backend is unavailable")
	end

	local account_promise = call_promise(wallet_interface, wallet_interface.account_wallets)

	if candidate.currency ~= "credits" and candidate.currency ~= "marks" then
		return account_promise:next(function(wallets)
			return find_wallet(wallets, candidate.currency)
		end)
	end

	local character_promise = call_promise(wallet_interface, wallet_interface.character_wallets, candidate.character_id)

	return Promise.all(account_promise, character_promise):next(function(results)
		local account_wallet = find_wallet(results and results[1], candidate.currency)
		local character_wallet = find_wallet(results and results[2], candidate.currency)
		local wallet = account_wallet or character_wallet

		if wallet == character_wallet and wallet and wallet.owner and tostring(wallet.owner) ~= tostring(candidate.character_id) then
			return rejected("target character wallet owner did not match the offer character")
		end

		return wallet
	end)
end

local function revalidate_and_purchase(mod, token, captured)
	if not context_is_current(mod, token) or not profile_is_enabled(mod, captured.profile) then
		return Promise.resolved()
	end

	return fetch_storefront(captured.profile):next(function(storefront)
		if not context_is_current(mod, token) then
			return
		end

		local offer = find_offer(storefront, captured.offer_id)

		if not offer then
			log_info(mod, "Revalidation rejected offer " .. tostring(captured.offer_id) .. ": offer ID was no longer present in the target storefront.")
			return
		end

		local success, current = pcall(normalized_offer, mod, captured.profile, offer)

		if not success then
			return rejected(current)
		end

		if not current then
			log_info(mod, "Revalidation rejected offer " .. tostring(captured.offer_id) .. ": it no longer passed the current Curio filters or safety checks.")
			return
		end

		if not same_candidate(captured, current) then
			local differences = candidate_differences(captured, current, STABLE_REVALIDATION_FIELDS)

			log_info(mod, string.format(
				"Revalidation rejected offer %s because stable field(s) changed: %s.",
				tostring(captured.offer_id),
				table.concat(differences, ", ")
			))
			return
		end

		local volatile_differences = candidate_differences(captured, current, VOLATILE_REVALIDATION_FIELDS)

		if #volatile_differences > 0 then
			log_diagnostic(mod, string.format(
				"Revalidation accepted offer %s; non-transactional field(s) changed after refetch: %s.",
				tostring(captured.offer_id),
				table.concat(volatile_differences, ", ")
			))
		end

		local key = candidate_key(current)

		if processed_offer_keys[key] then
			return
		end

		return fetch_target_wallet(current):next(function(wallet)
			if not context_is_current(mod, token) then
				return
			end

			local balance = wallet and wallet.balance
			local available = balance and tonumber(balance.amount)

			if not wallet or not balance or balance.type ~= current.currency or not available then
				return rejected("matching target wallet was unavailable")
		end

			if available < current.price then
				log_diagnostic(mod, string.format("Skipped %s: %s balance was insufficient.", tostring(current.offer_id), current.currency))

				return {
					available = available,
					candidate = current,
					status = "insufficient_funds",
				}
			end

			local store_service = Managers and Managers.data_service and Managers.data_service.store

			if not store_service or type(store_service.purchase_item_with_wallet) ~= "function" then
				return rejected("StoreService.purchase_item_with_wallet is unavailable")
			end

			processed_offer_keys[key] = "in_flight"

			return call_promise(store_service, store_service.purchase_item_with_wallet, current.offer, wallet):next(function()
				processed_offer_keys[key] = "complete"

				return {
					candidate = current,
					status = "purchased",
				}
			end):catch(function(error_value)
				-- A timeout can be ambiguous after the POST reaches the backend. Keep the
				-- session key blocked and never retry this offer automatically.
				processed_offer_keys[key] = "unknown"

				return rejected(error_value)
			end)
		end)
	end)
end

local function notify(mod, title_id, description, final_line, final_line_color)
	local event_manager = Managers and Managers.event

	if not event_manager or type(event_manager.trigger) ~= "function" then
		return
	end

	pcall(event_manager.trigger, event_manager, "event_add_notification_message", "custom", {
		line_1 = mod:localize(title_id),
		line_1_color = Color.terminal_text_header(255, true),
		line_2 = description,
		line_2_color = Color.white(255, true),
		line_3 = final_line,
		line_3_color = final_line_color,
	})
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

local function report_purchase_outcomes(mod, purchased, insufficient, partial_failure)
	local reported = false

	if #purchased > 0 then
		notify(
			mod,
			"automatic_curio_purchased_title",
			candidate_lines(mod, purchased, partial_failure),
			spending_line(mod, purchased),
			Color.terminal_corner_selected(255, true)
		)
		reported = true
	end

	if #insufficient > 0 then
		notify(mod, "automatic_curio_insufficient_title", candidate_lines(mod, insufficient, false))
		reported = true
	end

	return reported
end

local function finish_pass()
	state.completed = true
	state.scheduled = false
	state.started = false
end

local function purchase_candidates(mod, token, candidates)
	local purchased = {}
	local insufficient = {}
	local chain = Promise.resolved()

	for index = 1, #candidates do
		local candidate = candidates[index]

		chain = chain:next(function()
			if not context_is_current(mod, token) then
				return
			end

			return revalidate_and_purchase(mod, token, candidate):next(function(result)
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

			report_purchase_outcomes(mod, purchased, insufficient, false)

			if #purchased > 0 or #insufficient > 0 then
				log_diagnostic(mod, string.format("Reported %d purchase(s) and %d insufficient-funds match(es) after the pass was cancelled.", #purchased, #insufficient))
			end

			return
		end

		finish_pass()

		if #purchased > 0 then
			refresh_after_purchase()
		end

		local reported = report_purchase_outcomes(mod, purchased, insufficient, false)

		if reported then
			log_diagnostic(mod, string.format("Purchase pass completed with %d purchase(s) and %d insufficient-funds match(es).", #purchased, #insufficient))
		else
			notify_no_eligible(mod)
			log_diagnostic(mod, "No eligible Curios were available after final revalidation.")
		end
	end):catch(function(error_value)
		if not context_is_current(mod, token) then
			if #purchased > 0 then
				refresh_after_purchase()
			end

			report_purchase_outcomes(mod, purchased, insufficient, true)
			log_info(mod, string.format("Reported %d purchase(s) and %d insufficient-funds match(es) after a cancelled pass encountered an error: %s", #purchased, #insufficient, error_text(error_value)))

			return
		end

		finish_pass()
		if #purchased > 0 then
			refresh_after_purchase()
		end

		report_purchase_outcomes(mod, purchased, insufficient, true)

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

	state.started = false
	state.elapsed = MORNINGSTAR_DELAY - RETRY_DELAY
	state.scheduled = state.scan_attempts < MAX_SCAN_ATTEMPTS

	if state.scheduled then
		log_info(mod, string.format("Scan attempt %d failed; scheduling a bounded retry: %s", state.scan_attempts, error_text(error_value)))
	else
		finish_pass()
		notify(mod, "automatic_curio_failed_title", mod:localize("automatic_curio_failed_description"))
		log_info(mod, "Scan failed after bounded retries: " .. error_text(error_value))
	end
end

local function start_scan(mod)
	local token = state.token

	state.started = true
	state.scan_attempts = state.scan_attempts + 1
	log_diagnostic(mod, string.format("Starting all-character Armoury scan attempt %d.", state.scan_attempts))

	scan_candidates(mod, token):next(function(candidates)
		if not context_is_current(mod, token) then
			return
		end

		state.scheduled = false

		if type(candidates) ~= "table" then
			return schedule_scan_retry(mod, token, "scan returned no candidate list")
		end

		log_diagnostic(mod, string.format("Scan found %d eligible Curio offer(s).", #candidates))

		if #candidates == 0 then
			finish_pass()
			notify_no_eligible(mod)
		else
			purchase_candidates(mod, token, candidates)
		end
	end):catch(function(error_value)
		schedule_scan_retry(mod, token, error_value)
	end)
end

CurioAcquisition.begin_morningstar_pass = function(mod)
	state.token = state.token + 1
	state.completed = false
	state.elapsed = 0
	state.hub_character_id = nil
	state.profile_discovery_elapsed = 0
	state.profile_discovery_inflight = false
	state.profile_discovery_pending = true
	state.profile_discovery_refresh_elapsed = 0
	state.profile_discovery_token = state.profile_discovery_token + 1
	state.scan_attempts = 0
	state.scheduled = enabled(mod)
	state.started = false
	processed_offer_keys = {}
end

CurioAcquisition.cancel = function()
	state.token = state.token + 1
	state.completed = false
	state.elapsed = 0
	state.hub_character_id = nil
	state.scan_attempts = 0
	state.scheduled = false
	state.started = false
end

local function profiles_service()
	return Managers and Managers.data_service and Managers.data_service.profiles
end

local function update_profile_discovery(mod, dt)
	if not is_morningstar() then
		return
	end

	if not state.profile_discovery_pending then
		state.profile_discovery_refresh_elapsed = state.profile_discovery_refresh_elapsed + (tonumber(dt) or 0)

		if state.profile_discovery_refresh_elapsed < PROFILE_DISCOVERY_REFRESH_INTERVAL then
			return
		end

		state.profile_discovery_pending = true
		state.profile_discovery_elapsed = PROFILE_DISCOVERY_DELAY
	end

	if state.profile_discovery_inflight then
		return
	end

	state.profile_discovery_elapsed = state.profile_discovery_elapsed + (tonumber(dt) or 0)

	if state.profile_discovery_elapsed < PROFILE_DISCOVERY_DELAY then
		return
	end

	local service = profiles_service()

	if not service or type(service.fetch_all_profiles) ~= "function" then
		return
	end

	state.profile_discovery_inflight = true
	local discovery_token = state.profile_discovery_token

	call_promise(service, service.fetch_all_profiles):next(function(result)
		if discovery_token ~= state.profile_discovery_token then
			return
		end

		state.profile_discovery_inflight = false

		local profiles = result and result.profiles

		if type(profiles) == "table" then
			cache_profiles(mod, profiles)
			state.profile_discovery_pending = false
			state.profile_discovery_refresh_elapsed = 0
		else
			state.profile_discovery_elapsed = PROFILE_DISCOVERY_DELAY - PROFILE_DISCOVERY_RETRY_DELAY
		end
	end):catch(function(error_value)
		if discovery_token ~= state.profile_discovery_token then
			return
		end

		state.profile_discovery_inflight = false
		state.profile_discovery_elapsed = PROFILE_DISCOVERY_DELAY - PROFILE_DISCOVERY_RETRY_DELAY
		log_diagnostic(mod, "Character discovery failed and will retry later: " .. error_text(error_value))
	end)
end

CurioAcquisition.request_profile_discovery = function(force)
	if force == true or state.known_profiles == nil or #state.known_profiles == 0 or state.profile_discovery_refresh_elapsed >= PROFILE_DISCOVERY_REFRESH_INTERVAL then
		state.profile_discovery_pending = true
		state.profile_discovery_elapsed = PROFILE_DISCOVERY_DELAY
	end
end

CurioAcquisition.known_profiles = function(mod)
	return known_profiles(mod)
end

CurioAcquisition.maximum_operative_slots = function(mod)
	return maximum_operative_slots(mod, #known_profiles(mod))
end

CurioAcquisition.character_slots = function(mod)
	local profiles = known_profiles(mod)
	local slots = reconcile_character_slots(mod, profiles, false)

	return slots
end

CurioAcquisition.profile_revision = function()
	return state.profile_revision
end

CurioAcquisition.character_is_enabled = function(mod, character_id)
	return character_is_enabled(mod, character_id)
end

CurioAcquisition.set_character_enabled = function(mod, character_id, enabled_value)
	if not character_id then
		return false
	end

	local existing = character_selection(mod)
	local selection = {}

	for key, value in pairs(existing) do
		selection[key] = value
	end

	local key = tostring(character_id)

	-- Missing entries mean enabled, so new characters are automatically covered
	-- and the persisted table contains only explicit exclusions.
	if enabled_value == false then
		selection[key] = false
	else
		selection[key] = nil
	end
	mod:set(CHARACTER_SELECTION_SETTING_ID, next(selection) and selection or nil, false)

	if type(CurioAcquisition.on_setting_changed) == "function" then
		CurioAcquisition.on_setting_changed(mod, CHARACTER_SELECTION_SETTING_ID)
	end

	state.character_selection = selection

	for index = 1, #known_character_slots(mod) do
		if known_character_slots(mod)[index].character_id == key then
			mod:set(character_slot_setting_id(index), enabled_value ~= false, false)
			break
		end
	end

	return true
end

CurioAcquisition.inject_character_options = function(mod, options_templates)
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
		CurioAcquisition.request_profile_discovery()
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

CurioAcquisition.refresh_character_options = function(mod)
	local profiles = known_profiles(mod)
	local slots = reconcile_character_slots(mod, profiles, false)

	refresh_registered_character_options(mod, slots, profiles)
end

CurioAcquisition.on_setting_changed = function(mod, setting_id)
	local slot_index = character_slot_index(setting_id)

	if slot_index then
		local slot = known_character_slots(mod)[slot_index]

		if slot and slot.character_id then
			CurioAcquisition.set_character_enabled(mod, slot.character_id, mod:get(setting_id) ~= false)
		end

		return
	end

	if setting_id == CHARACTER_SELECTION_SETTING_ID then
		state.character_selection = nil
	end

	if setting_id == "enable_automatic_curio_acquisition" then
		if enabled(mod) then
			-- Let the live Morningstar observer arm a fresh pass. This also handles
			-- enabling the feature without leaving and re-entering the hub.
			state.completed = false
			state.hub_character_id = nil
			state.scheduled = false
			state.started = false
			state.elapsed = 0
			state.scan_attempts = 0
			state.token = state.token + 1
		else
			CurioAcquisition.cancel()
		end
	elseif setting_id ~= "automatic_curio_diagnostic_logging" and type(setting_id) == "string" and string.sub(setting_id, 1, 16) == "automatic_curio_" and state.started then
		-- Changing a destructive filter invalidates every captured offer. Do not
		-- re-run automatically in the same hub session after a partial transaction.
		state.token = state.token + 1
		state.completed = true
		state.scheduled = false
		state.started = false
	end
end

CurioAcquisition.update = function(mod, dt, automatic_discard_busy)
	update_profile_discovery(mod, dt)

	if not enabled(mod) then
		if state.scheduled or state.started or state.hub_character_id then
			CurioAcquisition.cancel()
		end

		return
	end

	local game_mode_name = current_game_mode_name()

	if not game_mode_name then
		return
	end

	if not is_morningstar() then
		if state.scheduled or state.started or state.hub_character_id then
			CurioAcquisition.cancel()
		end

		return
	end

	local character_id = current_character_id()

	if not character_id then
		return
	end

	if not state.hub_character_id then
		state.token = state.token + 1
		state.completed = false
		state.elapsed = 0
		state.hub_character_id = character_id
		state.scan_attempts = 0
		state.scheduled = true
		state.started = false
		processed_offer_keys = {}
		log_diagnostic(mod, "Scheduled one all-character pass after detecting a ready Morningstar session.")
	end

	if state.completed or not state.scheduled or state.started or automatic_discard_busy then
		return
	end

	state.elapsed = state.elapsed + (tonumber(dt) or 0)

	if state.elapsed < MORNINGSTAR_DELAY or not backend_ready() then
		return
	end

	local progression_manager = Managers and Managers.progression

	if progression_manager and type(progression_manager.is_fetching_session_report) == "function" and progression_manager:is_fetching_session_report() then
		state.elapsed = 0
		return
	end

	start_scan(mod)
end

CurioAcquisition._test = {
	ARCHETYPE_SETTINGS = ARCHETYPE_SETTINGS,
	PRIMARY_TRAITS = PRIMARY_TRAITS,
	cache_profiles = cache_profiles,
	candidate_differences = candidate_differences,
	candidate_key = candidate_key,
	character_slots = known_character_slots,
	class_is_enabled = class_is_enabled,
	maximum_operative_slots = maximum_operative_slots,
	normalized_offer = normalized_offer,
	primary_trait = primary_trait,
	profile_is_enabled = profile_is_enabled,
	reconcile_character_slots = reconcile_character_slots,
	same_candidate = same_candidate,
}

return CurioAcquisition
