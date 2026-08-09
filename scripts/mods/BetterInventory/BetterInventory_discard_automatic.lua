local ProfileUtils = require("scripts/utilities/profile_utils")

local AutomaticDiscard = {}

local AUTOMATIC_DISCARD_DELAY = 5
local AUTOMATIC_DISCARD_MAX_FETCH_ATTEMPTS = 3

local function current_game_mode_name()
	local state = Managers and Managers.state
	local game_mode = state and state.game_mode

	if not game_mode or type(game_mode.game_mode_name) ~= "function" then
		return
	end

	local success, name = pcall(game_mode.game_mode_name, game_mode)

	return success and name or nil
end

local function is_morningstar()
	local game_mode_name = current_game_mode_name()

	return game_mode_name == "hub" or game_mode_name == "hub_singleplay"
end

local function current_player_and_character()
	local player_manager = Managers and Managers.player
	local player
	local character_id

	if player_manager and type(player_manager.local_player) == "function" then
		local success, value = pcall(player_manager.local_player, player_manager, 1)

		player = success and value or nil
	end

	if player and not player.__deleted and type(player.character_id) == "function" then
		local success, value = pcall(player.character_id, player)

		character_id = success and value or nil
	end

	return player, character_id
end

local function player_profile(player)
	if not player or player.__deleted or type(player.profile) ~= "function" then
		return
	end

	local success, profile = pcall(player.profile, player)

	return success and profile or nil
end

local function error_text(error_value)
	if type(error_value) == "table" then
		local message = error_value.message or error_value.error or error_value[1]

		if message then
			return tostring(message)
		elseif type(table.tostring) == "function" then
			return table.tostring(error_value, 2)
		end
	end

	return tostring(error_value)
end

local function new_state()
	return {
		delete_inflight = false,
		delete_transaction_token = nil,
		elapsed = 0,
		fetch_attempts = 0,
		read_promise = nil,
		read_inflight = false,
		hub_character_id = nil,
		scheduled = false,
		started = false,
		token = 0,
	}
end

function AutomaticDiscard.new(transaction, dependencies)
	local dependencies = dependencies or {}
	local policy = dependencies.policy or {}
	local state = new_state()
	local automatic = {
		_state = state,
		_transaction = transaction,
	}

	local function enabled(mod)
		return mod and mod:get("enable_experimental_quick_discard") == true and mod:get("quick_discard_mode") == "automatic"
	end

	local function info(mod, message)
		if mod and type(mod.info) == "function" then
			mod:info("[Automatic discard] " .. message)
		end
	end

	local function protection_snapshot(character_id)
		local player, current_character_id = current_player_and_character()

		if not player or current_character_id ~= character_id then
			return nil, "the current player or character changed"
		end

		local profile = player_profile(player)

		if type(profile) ~= "table" then
			return nil, "the current profile is unavailable"
		end

		local save_manager = Managers and Managers.save

		if not save_manager or type(save_manager.character_data) ~= "function" then
			return nil, "character save data is unavailable"
		end

		local save_ok, character_data = pcall(save_manager.character_data, save_manager, character_id)

		if not save_ok or type(character_data) ~= "table" or type(character_data.favorite_items) ~= "table" then
			return nil, "favorite-item save data is unavailable"
		end

		local presets_ok, profile_presets = pcall(ProfileUtils.get_profile_presets)

		if not presets_ok or type(profile_presets) ~= "table" or type(policy.equipped_gear_ids) ~= "function" then
			return nil, "saved loadout presets are unavailable"
		end

		return {
			equipped_gear_ids = policy.equipped_gear_ids(profile, profile_presets),
			favorite_gear_ids = character_data.favorite_items,
		}
	end

	local function context_is_current(mod, token, character_id)
		if state.token ~= token or not enabled(mod) or not is_morningstar() then
			return false
		end

		local _, current_character_id = current_player_and_character()

		return current_character_id == character_id
	end

	local function fetch_inventory_promise(gear_service, character_id)
		if not gear_service or type(gear_service.fetch_inventory) ~= "function" then
			return nil, "GearService.fetch_inventory is unavailable"
		end

		local success, promise = pcall(gear_service.fetch_inventory, gear_service, character_id)

		if not success then
			return nil, promise
		end

		if not promise or type(promise.next) ~= "function" or type(promise.catch) ~= "function" then
			return nil, "GearService.fetch_inventory returned no compatible promise"
		end

		return automatic:track_read_promise(promise)
	end

	local function notify_result(mod, candidates, result)
		local total_rewards = {}
		local deleted_ids = {}

		for index = 1, #(result or {}) do
			local operation = result[index]
			local gear_id = operation and operation.gearId

			if gear_id then
				deleted_ids[gear_id] = true
			end

			for reward_index = 1, #(operation and operation.rewards or {}) do
				local reward = operation.rewards[reward_index]
				local reward_type = reward and reward.type
				local amount = tonumber(reward and reward.amount)

				if reward_type and amount then
					total_rewards[reward_type] = (total_rewards[reward_type] or 0) + amount
				end
			end
		end

		local event_manager = Managers and Managers.event

		if event_manager and type(event_manager.trigger) == "function" then
			pcall(event_manager.trigger, event_manager, "event_force_wallet_update")
			pcall(event_manager.trigger, event_manager, "event_force_refresh_inventory")

			for reward_type, reward_amount in pairs(total_rewards) do
				pcall(event_manager.trigger, event_manager, "event_add_notification_message", "currency", {
					amount = reward_amount,
					currency = reward_type,
				})
			end
		end

		local discarded_candidates = {}

		for index = 1, #(candidates or {}) do
			local candidate = candidates[index]

			if candidate and deleted_ids[candidate.gear_id] then
				discarded_candidates[#discarded_candidates + 1] = candidate
			end
		end

		if type(dependencies.show_discard_summary_notification) == "function" then
			dependencies.show_discard_summary_notification(mod, discarded_candidates)
		end
	end

	local function delete_candidates(mod, token, character_id, captured_ids, transaction_token)
		if not context_is_current(mod, token, character_id) then
			automatic._transaction:release("automatic", transaction_token)
			return
		end

		local gear_service = Managers and Managers.data_service and Managers.data_service.gear

		if not gear_service or type(gear_service.fetch_inventory) ~= "function" or type(gear_service.delete_gear_batch) ~= "function" then
			automatic._transaction:release("automatic", transaction_token)
			return
		end

		local fetch_promise, fetch_error = fetch_inventory_promise(gear_service, character_id)

		if not fetch_promise then
			info(mod, "Final revalidation could not start: " .. error_text(fetch_error))
			automatic._transaction:release("automatic", transaction_token)
			return
		end

		local continuation = fetch_promise:next(function(items)
			if not context_is_current(mod, token, character_id) or type(items) ~= "table" then
				automatic._transaction:release("automatic", transaction_token)
				return
			end

			local protection, protection_error = protection_snapshot(character_id)

			if not protection then
				info(mod, "Final revalidation stopped safely because " .. error_text(protection_error) .. ".")
				automatic._transaction:release("automatic", transaction_token)

				return
			end

			local candidates = type(dependencies.candidates_from_items) == "function" and dependencies.candidates_from_items(mod, items, protection.equipped_gear_ids, captured_ids, protection.favorite_gear_ids) or {}
			local gear_ids = {}

			for index = 1, #candidates do
				gear_ids[index] = candidates[index].gear_id
			end

			info(mod, string.format("Revalidated %d candidate(s) immediately before deletion.", #gear_ids))

			if #gear_ids == 0 then
				automatic._transaction:release("automatic", transaction_token)
				return
			end

			local delete_ok, delete_promise = pcall(gear_service.delete_gear_batch, gear_service, gear_ids)

			if not delete_ok or not delete_promise or type(delete_promise.next) ~= "function" or type(delete_promise.catch) ~= "function" then
				automatic._transaction:release("automatic", transaction_token)
				error(delete_ok and "GearService.delete_gear_batch returned no compatible promise" or delete_promise)
			end

			state.delete_inflight = true
			state.delete_transaction_token = transaction_token

			return delete_promise:next(function(result)
				if state.delete_transaction_token == transaction_token then
					state.delete_inflight = false
					state.delete_transaction_token = nil
				end

				notify_result(mod, candidates, result)
				automatic._transaction:release("automatic", transaction_token)

				return result
			end)
		end)

		if continuation and type(continuation.catch) == "function" then
			continuation:catch(function(error_value)
				info(mod, "Final revalidation failed: " .. error_text(error_value))

				if state.delete_transaction_token == transaction_token then
					state.delete_inflight = false
					state.delete_transaction_token = nil
				end

				automatic._transaction:release("automatic", transaction_token)

				return error_value
			end)
		end
	end

	local function present(mod, token, character_id, candidates)
		local transaction_token = automatic._transaction:acquire("automatic")

		if not transaction_token then
			info(mod, "Suppressed a duplicate automatic discard confirmation preview.")

			return
		end

		local captured_ids = {}

		for index = 1, #candidates do
			captured_ids[candidates[index].gear_id] = true
		end

		if mod:get("quick_discard_skip_automatic_confirmation") == true then
			info(mod, "Confirmation skipping is enabled; starting final safety revalidation.")
			delete_candidates(mod, token, character_id, captured_ids, transaction_token)

			return
		end

		local confirmation_resolved = false

		local function clear_confirmation()
			if confirmation_resolved then
				return
			end

			confirmation_resolved = true
			automatic._transaction:release("automatic", transaction_token)
		end

		local popup_shown = type(dependencies.show_popup) == "function" and dependencies.show_popup({
			description_text_unlocalized = tostring(#candidates) .. " " .. mod:localize("quick_discard_confirmation_description") .. "\n\n" .. (type(dependencies.rarity_summary) == "function" and dependencies.rarity_summary(mod, candidates) or "") .. "\n\n" .. mod:localize("quick_discard_confirmation_warning"),
			options = {
				{
					callback = function()
						if not confirmation_resolved and automatic._transaction:is_current("automatic", transaction_token) then
							confirmation_resolved = true
							automatic._transaction:clear_popup("automatic", transaction_token)
							delete_candidates(mod, token, character_id, captured_ids, transaction_token)
						end
					end,
					close_on_pressed = true,
					no_localization = true,
					text = mod:localize("quick_discard_confirmation_yes"),
				},
				{
					callback = clear_confirmation,
					close_on_pressed = true,
					hotkey = "back",
					no_localization = true,
					template_type = "terminal_button_small",
					text = mod:localize("quick_discard_confirmation_no"),
				},
			},
			title_text_unlocalized = mod:localize("quick_discard_automatic_confirmation_title"),
		}, function(popup_id)
			automatic._transaction:set_popup("automatic", transaction_token, popup_id)
		end) or false

		if not popup_shown then
			clear_confirmation()
		end

		info(mod, popup_shown and "Displayed the automatic discard confirmation preview." or "Could not display the automatic discard confirmation preview; no items were deleted.")
	end

	function automatic:clear_read_promise(promise)
		if state.read_promise == promise then
			state.read_promise = nil
			state.read_inflight = false
		end
	end

	function automatic:track_read_promise(promise)
		if not promise then
			return promise
		end

		state.read_promise = promise
		state.read_inflight = true

		if type(promise.next) == "function" and type(promise.catch) == "function" then
			local continuation = promise:next(function(result)
				automatic:clear_read_promise(promise)

				return result
			end)

			if continuation and type(continuation.catch) == "function" then
				continuation:catch(function(error_value)
					automatic:clear_read_promise(promise)

					return error_value
				end)
			end
		end

		return promise
	end

	function automatic:cancel_read_promise()
		local promise = state.read_promise

		state.read_promise = nil
		state.read_inflight = false

		if promise and type(promise.cancel) == "function" then
			pcall(promise.cancel, promise)
		end
	end

	function automatic:morningstar_auto_discard_is_busy(mod)
		return state.delete_inflight or self._transaction:active_owner() == "automatic" or enabled(mod) and state.scheduled
	end

	function automatic:automatic_discard_read_request_count()
		return state.read_inflight and 1 or 0
	end

	function automatic:begin(mod)
		if self._transaction:active_owner() == "automatic" then
			info(mod, "Ignored a duplicate automatic discard re-arm while a transaction is active.")

			return
		end

		state.token = state.token + 1
		state.elapsed = 0
		state.fetch_attempts = 0
		state.hub_character_id = nil
		state.scheduled = enabled(mod)
		state.started = false
	end

	function automatic:cancel(preserve_transaction)
		if preserve_transaction and self._transaction:active_owner() == "automatic" then
			state.scheduled = false
			state.started = true

			return
		end

		self:cancel_read_promise()
		state.token = state.token + 1

		if not state.delete_inflight then
			self._transaction:release("automatic")
		end

		state.elapsed = 0
		state.fetch_attempts = 0
		state.hub_character_id = nil
		state.scheduled = false
		state.started = false
	end

	function automatic:update(mod, dt)
		if not enabled(mod) then
			if state.scheduled or state.started or state.hub_character_id or self._transaction:active_owner() == "automatic" then
				self:cancel()
			end

			return
		end

		local game_mode_name = current_game_mode_name()

		if not game_mode_name then
			return
		end

		if not is_morningstar() then
			if state.scheduled or state.started or state.hub_character_id then
				self:cancel(true)
			end

			return
		end

		local player, character_id = current_player_and_character()

		if not player or not character_id then
			return
		end

		if state.hub_character_id ~= character_id then
			self:cancel_read_promise()
			state.token = state.token + 1
			state.elapsed = 0
			state.fetch_attempts = 0
			state.hub_character_id = character_id
			state.scheduled = true
			state.started = false
			info(mod, "Scheduled one pass after detecting a ready Morningstar character.")
		end

		if not state.scheduled or state.started then
			return
		end

		state.elapsed = state.elapsed + (tonumber(dt) or 0)

		if state.elapsed < AUTOMATIC_DISCARD_DELAY then
			return
		end

		local progression_manager = Managers and Managers.progression

		if progression_manager and type(progression_manager.is_fetching_session_report) == "function" and progression_manager:is_fetching_session_report() then
			state.elapsed = 0
			info(mod, "Waiting for the mission reward report before scanning inventory.")

			return
		end

		local gear_service = Managers and Managers.data_service and Managers.data_service.gear

		if not gear_service or type(gear_service.fetch_inventory) ~= "function" then
			return
		end

		local token = state.token

		state.started = true
		state.fetch_attempts = state.fetch_attempts + 1

		if type(gear_service.invalidate_gear_cache) == "function" then
			gear_service:invalidate_gear_cache()
		end

		info(mod, string.format("Starting inventory scan attempt %d.", state.fetch_attempts))
		local fetch_promise, fetch_error = fetch_inventory_promise(gear_service, character_id)

		if not fetch_promise then
			state.started = false
			state.elapsed = 0
			state.scheduled = state.fetch_attempts < AUTOMATIC_DISCARD_MAX_FETCH_ATTEMPTS
			info(mod, "Inventory scan could not start; scheduling a bounded retry. Reason: " .. error_text(fetch_error))
			return
		end

		local continuation = fetch_promise:next(function(items)
			if not context_is_current(mod, token, character_id) then
				return
			end

			if type(items) ~= "table" then
				info(mod, "Inventory scan returned no item table; scheduling a bounded retry.")
				state.started = false
				state.elapsed = 0
				state.scheduled = state.fetch_attempts < AUTOMATIC_DISCARD_MAX_FETCH_ATTEMPTS

				return
			end

			state.scheduled = false
			local protection, protection_error = protection_snapshot(character_id)

			if not protection then
				info(mod, "Inventory scan stopped safely because " .. error_text(protection_error) .. "; scheduling a bounded retry.")
				state.started = false
				state.elapsed = 0
				state.scheduled = state.fetch_attempts < AUTOMATIC_DISCARD_MAX_FETCH_ATTEMPTS

				return
			end

			local candidates, excluded_errors, first_error = {}, 0, nil

			if type(dependencies.candidates_from_items_detailed) == "function" then
				candidates, excluded_errors, first_error = dependencies.candidates_from_items_detailed(mod, items, protection.equipped_gear_ids, nil, protection.favorite_gear_ids)
			end

			if excluded_errors > 0 then
				info(mod, string.format("Safety-excluded %d unreadable item(s). First error: %s", excluded_errors, error_text(first_error)))
			end

			info(mod, string.format("Inventory scan found %d eligible candidate(s).", #candidates))

			if #candidates > 0 then
				present(mod, token, character_id, candidates)
			elseif type(dependencies.show_no_candidates_notification) == "function" then
				local displayed = dependencies.show_no_candidates_notification(mod)
				info(mod, displayed and "Displayed the no-eligible-items notification." or "Suppressed the no-eligible-items notification.")
			end
		end)

		if continuation and type(continuation.catch) == "function" then
			continuation:catch(function(error_value)
				info(mod, "Inventory scan failed; scheduling a bounded retry. Reason: " .. error_text(error_value))
				if state.token == token then
					state.started = false
					state.elapsed = 0
					state.scheduled = state.fetch_attempts < AUTOMATIC_DISCARD_MAX_FETCH_ATTEMPTS
				end

				return error_value
			end)
		end
	end

	function automatic:needs_update(mod)
		return enabled(mod)
			or state.scheduled
			or state.started
			or state.read_inflight
			or state.delete_inflight
			or state.hub_character_id ~= nil
			or self._transaction:active_owner() == "automatic"
	end

	return automatic
end

return AutomaticDiscard
