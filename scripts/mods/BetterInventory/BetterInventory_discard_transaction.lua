local Transaction = {}

local function remove_popup(popup_id)
	if not popup_id then
		return
	end

	local event_manager = Managers and Managers.event

	if event_manager and type(event_manager.trigger) == "function" then
		pcall(event_manager.trigger, event_manager, "event_remove_ui_popup", popup_id)
	end
end

local function show_popup(context, callback)
	local event_manager = Managers and Managers.event

	if not event_manager or type(event_manager.trigger) ~= "function" then
		return false
	end

	return pcall(event_manager.trigger, event_manager, "event_show_ui_popup", context, callback)
end

local function popup_is_active(popup_id)
	local ui_manager = Managers and Managers.ui

	if not ui_manager or type(ui_manager.active_popups) ~= "function" then
		return nil
	end

	local ok, active_popups = pcall(ui_manager.active_popups, ui_manager)

	if not ok or type(active_popups) ~= "table" then
		return nil
	end

	for index = 1, #active_popups do
		if active_popups[index] and active_popups[index].id == popup_id then
			return true
		end
	end

	return false
end

local function fallback_arbiter()
	local state = {
		manual_delete_inflight = false,
		manual_delete_transaction_token = nil,
		owner = nil,
		popup_id = nil,
		token = 0,
		view = nil,
	}
	local arbiter = {}

	function arbiter:acquire(owner, view)
		if state.owner then
			return
		end

		state.token = state.token + 1
		state.owner = owner
		state.view = view
		state.popup_id = nil

		return state.token
	end

	function arbiter:release(owner, token)
		if state.owner ~= owner or token and state.token ~= token then
			return false
		end

		local view = state.view
		local popup_id = state.popup_id

		state.owner = nil
		state.view = nil
		state.popup_id = nil
		state.manual_delete_inflight = false
		state.manual_delete_transaction_token = nil

		return true, view, popup_id
	end

	function arbiter:is_current(owner, token)
		return state.owner == owner and state.token == token
	end

	function arbiter:active_owner()
		return state.owner
	end

	function arbiter:active_view()
		return state.view
	end

	function arbiter:active_token()
		return state.token
	end

	function arbiter:detach_view(view)
		if state.view == nil or view ~= nil and state.view ~= view then
			return false
		end

		local detached = state.view
		state.view = nil

		return true, detached
	end

	function arbiter:current_popup()
		return state.popup_id
	end

	function arbiter:set_popup(owner, token, popup_id)
		if not self:is_current(owner, token) then
			return false
		end

		state.popup_id = popup_id

		return true
	end

	function arbiter:clear_popup(owner, token)
		if not self:is_current(owner, token) then
			return false
		end

		state.popup_id = nil

		return true
	end

	function arbiter:manual_settlement_active()
		return state.owner == "manual" and state.manual_delete_inflight == true
	end

	function arbiter:observe_manual_settlement(promise, on_settled)
		if state.owner ~= "manual" or state.manual_delete_inflight or not promise or type(promise.next) ~= "function" or type(promise.catch) ~= "function" then
			return false
		end

		local transaction_token = state.token
		state.manual_delete_inflight = true
		state.manual_delete_transaction_token = transaction_token

		local function settle()
			if state.owner == "manual" and state.token == transaction_token and state.manual_delete_transaction_token == transaction_token and type(on_settled) == "function" then
				on_settled(transaction_token)
			end
		end

		local continuation = promise:next(function(result)
			settle()

			return result
		end)

		if continuation and type(continuation.next) == "function" and type(continuation.catch) == "function" then
			continuation:catch(function(error_value)
				settle()

				return error_value
			end)
		end

		return true
	end

	return arbiter
end

function Transaction.new(operation_arbiter, callbacks)
	local arbiter = operation_arbiter and type(operation_arbiter.new) == "function" and operation_arbiter.new() or fallback_arbiter()
	local transaction = {
		_arbiter = arbiter,
		_callbacks = callbacks or {},
	}

	function transaction:active_owner()
		return self._arbiter:active_owner()
	end

	function transaction:active_view()
		return self._arbiter:active_view()
	end

	function transaction:active_token()
		return self._arbiter:active_token()
	end

	function transaction:detach_view(view)
		if type(self._arbiter.detach_view) ~= "function" then
			return false
		end

		local detached, detached_view = self._arbiter:detach_view(view)

		if detached and detached_view then
			detached_view._better_inventory_discard_pending = false
		end

		return detached == true
	end

	function transaction:current_popup()
		return self._arbiter:current_popup()
	end

	function transaction:popup_is_active(popup_id)
		return popup_is_active(popup_id)
	end

	function transaction:is_current(owner, token)
		return self._arbiter:is_current(owner, token)
	end

	function transaction:acquire(owner, view)
		local token = self._arbiter:acquire(owner, view)

		if token and view then
			view._better_inventory_discard_pending = true
		end

		return token
	end

	function transaction:remove_popup(popup_id)
		remove_popup(popup_id)
	end

	function transaction:set_popup(owner, token, popup_id)
		if self._arbiter:set_popup(owner, token, popup_id) then
			return true
		end

		remove_popup(popup_id)

		return false
	end

	function transaction:clear_popup(owner, token)
		return self._arbiter:clear_popup(owner, token)
	end

	function transaction:release(owner, token)
		local released, view, popup_id = self._arbiter:release(owner, token)

		if not released then
			return false
		end

		remove_popup(popup_id)

		if view then
			view._better_inventory_discard_pending = false
		end

		return true, view, popup_id
	end

	function transaction:observe_manual_settlement(promise)
		return self._arbiter:observe_manual_settlement(promise, function(transaction_token)
			self:release("manual", transaction_token)
		end)
	end

	function transaction:manual_settlement_active()
		return self._arbiter:manual_settlement_active()
	end

	function transaction:reconcile()
		-- A closed confirmation popup is not a completed destructive operation.
		-- Manual settlement remains the terminal owner until GearService resolves.
		if self:manual_settlement_active() then
			return
		end

		local popup_id = self:current_popup()

		if popup_id and popup_is_active(popup_id) == false then
			self:release(self:active_owner(), self:active_token())
		end
	end

	function transaction:request_manual(mod, layout, view)
		local collect_candidates = self._callbacks.collect_candidates

		if not view or view._better_inventory_discard_pending or self:active_owner() or type(collect_candidates) ~= "function" then
			return
		end

		local candidates_ok, candidates = pcall(collect_candidates, mod, layout, view)

		if not candidates_ok or type(candidates) ~= "table" or #candidates == 0 then
			show_popup({
				description_text_unlocalized = mod:localize("quick_discard_nothing_description"),
				options = {
					{
						close_on_pressed = true,
						no_localization = true,
						text = mod:localize("quick_discard_close"),
					},
				},
				title_text_unlocalized = mod:localize("quick_discard_nothing_title"),
			})

			return
		end

		local captured_ids = {}

		for index = 1, #candidates do
			local gear_id = candidates[index] and candidates[index].gear_id

			if gear_id then
				captured_ids[gear_id] = true
			end
		end

		local transaction_token = self:acquire("manual", view)

		if not transaction_token then
			return
		end

		local resolved = false

		local function clear_pending()
			if resolved then
				return
			end

			resolved = true
			self:release("manual", transaction_token)
		end

		local function confirm_discard()
			if resolved or not self:is_current("manual", transaction_token) then
				return
			end

			local revalidated_ok, revalidated = pcall(collect_candidates, mod, layout, view, captured_ids)
			local gear_ids = {}

			if revalidated_ok and type(revalidated) == "table" then
				for index = 1, #revalidated do
					local gear_id = revalidated[index] and revalidated[index].gear_id

					if gear_id then
						gear_ids[#gear_ids + 1] = gear_id
					end
				end
			end

			-- Popup closure is only presentation. Native deletion settlement owns the
			-- transaction after dispatch, when the bridge can observe a promise.
			self:clear_popup("manual", transaction_token)

			local event_manager = Managers and Managers.event
			local event_ok = false

			if #gear_ids > 0 and event_manager and type(event_manager.trigger) == "function" then
				event_ok = pcall(event_manager.trigger, event_manager, "event_discard_items", gear_ids)
			end

			-- If dispatch failed or no compatible settlement was exposed, release the
			-- UI lock. The native event remains the only owner of its request.
			if not event_ok or not self:manual_settlement_active() then
				clear_pending()
			end
		end

		local rarity_summary = ""

		if type(self._callbacks.rarity_summary) == "function" then
			local summary_ok, summary = pcall(self._callbacks.rarity_summary, mod, candidates)

			if summary_ok and type(summary) == "string" then
				rarity_summary = summary
			end
		end

		local popup_shown = show_popup({
			description_text_unlocalized = tostring(#candidates) .. " " .. mod:localize("quick_discard_confirmation_description") .. "\n\n" .. rarity_summary .. "\n\n" .. mod:localize("quick_discard_confirmation_warning"),
			options = {
				{
					callback = confirm_discard,
					close_on_pressed = true,
					no_localization = true,
					text = mod:localize("quick_discard_confirmation_yes"),
				},
				{
					callback = clear_pending,
					close_on_pressed = true,
					hotkey = "back",
					no_localization = true,
					template_type = "terminal_button_small",
					text = mod:localize("quick_discard_confirmation_no"),
				},
			},
			title_text_unlocalized = mod:localize("quick_discard_confirmation_title"),
		}, function(popup_id)
			self:set_popup("manual", transaction_token, popup_id)
		end)

		if not popup_shown then
			clear_pending()
		end
	end

	return transaction
end

return Transaction
