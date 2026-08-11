local Items = require("scripts/utilities/items")
local ItemSlotSettings = require("scripts/settings/item/item_slot_settings")
local Promise = require("scripts/foundation/utilities/promise")

local EquipmentPersistence = {}

local RETRY_DELAY = 1.5
local MAX_RETRIES = 2
local MAX_PENDING_SECONDS = 120

local state = {
	active = nil,
	generation = 0,
}

local function compatible_promise(value)
	return value and type(value.next) == "function" and type(value.catch) == "function"
end

local function item_identity(item)
	if type(item) ~= "table" then
		return nil
	end

	return item.gear_id or item.always_owned and item.name or nil
end

local function resolve_item(view, item)
	if type(view) == "table" and type(view._get_item) == "function" then
		local success, resolved = pcall(view._get_item, view, item)

		if success then
			return resolved
		end
	end

	return item
end

local function slot_is_valid(view, slot_name)
	if type(view) ~= "table" then
		return false
	end

	if type(view._invalid_slots) == "table" and view._invalid_slots[slot_name] then
		return false
	end

	if type(view._duplicated_slots) == "table" and view._duplicated_slots[slot_name] then
		return false
	end

	if type(view._valid_slot_for_archetype) == "function" then
		local success, valid = pcall(view._valid_slot_for_archetype, view, slot_name)

		return success and valid == true
	end

	return true
end

local function view_character_id(view)
	local player = type(view) == "table" and view._preview_player or nil

	if player and not player.__deleted and type(player.character_id) == "function" then
		local success, character_id = pcall(player.character_id, player)

		if success and character_id ~= nil then
			return tostring(character_id)
		end
	end
end

local function current_character_id()
	local player_manager = Managers and Managers.player

	if not player_manager then
		return
	end

	local player

	if type(player_manager.local_player_safe) == "function" then
		local success, value = pcall(player_manager.local_player_safe, player_manager, 1)

		player = success and value or nil
	elseif type(player_manager.local_player) == "function" then
		local success, value = pcall(player_manager.local_player, player_manager, 1)

		player = success and value or nil
	end

	if player and not player.__deleted and type(player.character_id) == "function" then
		local success, character_id = pcall(player.character_id, player)

		if success and character_id ~= nil then
			return tostring(character_id)
		end
	end
end

local function current_account_key()
	local backend = Managers and Managers.backend

	if backend and type(backend.account_id) == "function" then
		local success, account_id = pcall(backend.account_id, backend)

		if success and account_id ~= nil then
			return tostring(account_id)
		end
	end

	return "default"
end

local function capture_intent(view)
	if type(view) ~= "table" or view._is_own_player == false or view._is_readonly == true then
		return
	end

	local preview = view._preview_profile_equipped_items
	local starting = view._starting_profile_equipped_items

	if type(preview) ~= "table" or type(starting) ~= "table" then
		return
	end

	local intent = {
		account_key = current_account_key(),
		character_id = view_character_id(view),
		gear_items = {},
		local_items = {},
		records = {},
		signature_parts = {},
		unequip_slots = {},
	}

	for slot_name in pairs(ItemSlotSettings or {}) do
		if slot_is_valid(view, slot_name) then
			local item = resolve_item(view, preview[slot_name])
			local previous = resolve_item(view, starting[slot_name])
			local identity = item_identity(item)
			local previous_identity = item_identity(previous)

			if identity ~= previous_identity then
				intent.records[#intent.records + 1] = {
					item = item,
					slot_name = slot_name,
				}
				intent.signature_parts[#intent.signature_parts + 1] = tostring(slot_name) .. "=" .. tostring(identity or "<empty>")

				if item and item.gear_id then
					intent.gear_items[slot_name] = item
				elseif item and item.always_owned and item.name then
					intent.local_items[slot_name] = item
				elseif not item then
					intent.unequip_slots[slot_name] = true
				end
			end
		end
	end

	if #intent.records == 0 then
		return
	end

	table.sort(intent.signature_parts)
	intent.signature = table.concat(intent.signature_parts, "|")
	intent.signature_parts = nil

	return intent
end

local function result_succeeded(result)
	if result == false then
		return false
	end

	if type(result) == "table" then
		for _, value in pairs(result) do
			if value == false then
				return false
			end
		end
	end

	return true
end

local function apply_confirmed_intent(operation)
	local view = operation and operation.view
	local starting = type(view) == "table" and view._starting_profile_equipped_items or nil

	if type(starting) ~= "table" then
		return
	end

	for index = 1, #operation.intent.records do
		local record = operation.intent.records[index]

		starting[record.slot_name] = record.item
	end
end

local function log_failure(mod, message)
	if mod and type(mod.error) == "function" then
		mod:error("[Equipment Persistence] " .. tostring(message))
	end
end

local function context_is_current(operation)
	return operation
		and operation.account_key == current_account_key()
		and operation.character_id ~= nil
		and operation.character_id == current_character_id()
end

local observe_promise

local function execute_intent(operation)
	local intent = operation.intent
	local promises = {}
	local function append_required_promise(method, argument, label)
		if type(method) ~= "function" then
			return false, label .. " is unavailable"
		end

		local call_ok, promise = pcall(method, argument)

		if not call_ok then
			return false, promise
		end

		if not compatible_promise(promise) then
			return false, label .. " returned no compatible promise"
		end

		promises[#promises + 1] = promise

		return true
	end

	if next(intent.gear_items) then
		local appended, error_value = append_required_promise(Items.equip_slot_items, intent.gear_items, "Items.equip_slot_items")

		if not appended then
			return nil, error_value
		end
	end

	if next(intent.local_items) then
		local appended, error_value = append_required_promise(Items.equip_slot_master_items, intent.local_items, "Items.equip_slot_master_items")

		if not appended then
			return nil, error_value
		end
	end

	if next(intent.unequip_slots) then
		local appended, error_value = append_required_promise(Items.unequip_slots, intent.unequip_slots, "Items.unequip_slots")

		if not appended then
			return nil, error_value
		end
	end

	if #promises == 0 then
		return
	end

	local aggregate_ok, aggregate = pcall(Promise.all, unpack(promises))

	if not aggregate_ok or not compatible_promise(aggregate) then
		return nil, aggregate_ok and "Promise.all returned no compatible promise" or aggregate
	end

	return aggregate
end

local function schedule_retry(mod, operation, reason)
	if state.active ~= operation or not context_is_current(operation) then
		if state.active == operation then
			state.active = nil
		end

		return
	end

	if operation.retries >= MAX_RETRIES then
		state.active = nil
		log_failure(mod, string.format(
			"Failed to persist loadout %s after %d retries: %s",
			operation.intent.signature,
			operation.retries,
			tostring(reason)
		))
		return
	end

	operation.waiting_retry = true
	operation.retry_elapsed = 0
	operation.pending_elapsed = 0
	operation.promise = nil
	operation.last_error = reason
end

observe_promise = function(mod, operation, promise)
	if not compatible_promise(promise) then
		schedule_retry(mod, operation, "native equip returned no compatible promise")
		return promise
	end

	operation.promise = promise
	operation.waiting_retry = false
	operation.pending_elapsed = 0

	promise:next(function(result)
		if state.active ~= operation then
			return result
		end

		if result_succeeded(result) then
			apply_confirmed_intent(operation)
			state.active = nil
		else
			schedule_retry(mod, operation, "backend equip resolved false")
		end

		return result
	end):catch(function(error_value)
		schedule_retry(mod, operation, error_value)
	end)

	return promise
end

EquipmentPersistence.persist_local_changes = function(mod, native_function, view, ...)
	local intent = capture_intent(view)
	local promise = native_function(view, ...)

	if not intent then
		return promise
	end

	state.generation = state.generation + 1

	local operation = {
		account_key = intent.account_key,
		character_id = intent.character_id,
		generation = state.generation,
		intent = intent,
		retries = 0,
		pending_elapsed = 0,
		view = view,
	}

	state.active = operation
	observe_promise(mod, operation, promise)

	return promise
end

EquipmentPersistence.update = function(mod, dt)
	local operation = state.active

	if not operation then
		return
	end

	if not operation.waiting_retry then
		operation.pending_elapsed = (tonumber(operation.pending_elapsed) or 0) + math.max(tonumber(dt) or 0, 0)

		if operation.pending_elapsed >= MAX_PENDING_SECONDS then
			-- The native request may still settle later. Its callback is generation-
			-- guarded, so retire BetterInventory's immutable intent/view graph without
			-- issuing an ambiguous duplicate equip request.
			state.active = nil
			log_failure(mod, string.format(
				"Stopped retaining unresolved loadout %s after %d seconds; no retry was dispatched",
				operation.intent.signature,
				MAX_PENDING_SECONDS
			))
		end

		return
	end

	if not context_is_current(operation) then
		state.active = nil
		return
	end

	operation.retry_elapsed = operation.retry_elapsed + (tonumber(dt) or 0)

	if operation.retry_elapsed < RETRY_DELAY then
		return
	end

	operation.retries = operation.retries + 1
	operation.waiting_retry = false
	operation.retry_elapsed = 0

	local promise, retry_error = execute_intent(operation)

	if not promise then
		return schedule_retry(mod, operation, retry_error or "retry methods were unavailable")
	end

	observe_promise(mod, operation, promise)
end

EquipmentPersistence.refresh_from_authoritative_profile = function(view, peer_id, local_player_id)
	if type(view) ~= "table" or view._destroyed or view._is_own_player == false then
		return false
	end

	if local_player_id ~= nil and local_player_id ~= 1 then
		return false
	end

	if peer_id ~= nil and Network and type(Network.peer_id) == "function" then
		local peer_ok, own_peer_id = pcall(Network.peer_id)

		if peer_ok and own_peer_id ~= nil and peer_id ~= own_peer_id then
			return false
		end
	end

	local operation = state.active

	if operation and operation.character_id == view_character_id(view) then
		-- Do not let an unrelated profile event erase the optimistic loadout while
		-- its backend write is still pending or awaiting a confirmed-failure retry.
		return false
	end

	-- A child inventory equip updates the parent preview immediately, but
	-- Darktide does not start its backend write until the outer Character
	-- Overview exits. An unrelated or delayed profile event during that window
	-- must not replace the local Y preview with authoritative X.
	if capture_intent(view) then
		return false
	end

	local player = view._preview_player

	if not player or player.__deleted or type(player.profile) ~= "function" or type(view._update_equipped_items) ~= "function" then
		return false
	end

	local profile_ok, profile = pcall(player.profile, player)

	if not profile_ok or type(profile) ~= "table" then
		return false
	end

	view._presentation_profile = profile

	local update_ok = pcall(view._update_equipped_items, view)

	return update_ok
end

EquipmentPersistence.has_pending = function()
	return state.active ~= nil
end

EquipmentPersistence.on_view_closed = function(view)
	local operation = state.active

	if operation and operation.view == view then
		-- The backend intent and retry contract are view-independent. Drop only
		-- the optional Character Overview cache-update target so a slow request
		-- cannot retain a closed InventoryBackgroundView.
		operation.view = nil

		return true
	end

	return false
end

EquipmentPersistence.reset = function()
	state.generation = state.generation + 1
	state.active = nil
end

EquipmentPersistence.status = function()
	local operation = state.active

	if not operation then
		return "idle", 0
	end

	return operation.waiting_retry and "waiting_retry" or "pending", operation.retries
end

EquipmentPersistence._test = {
	capture_intent = capture_intent,
	result_succeeded = result_succeeded,
}

return EquipmentPersistence
