local OperationArbiter = {}

function OperationArbiter.new()
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
			if state.owner == "manual" and state.token == transaction_token and state.manual_delete_transaction_token == transaction_token then
				if type(on_settled) == "function" then
					on_settled(transaction_token)
				end
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

return OperationArbiter
