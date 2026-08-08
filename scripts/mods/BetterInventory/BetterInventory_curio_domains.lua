local Domains = {}

Domains.context = {}

Domains.context.snapshot = function(state)
	return {
		account_key = state and state.account_key,
		context = state and state.active_context,
		context_entry_id = state and state.context_entry_id,
		read_request_generation = state and state.read_request_generation,
		token = state and state.token,
	}
end

Domains.context.matches = function(snapshot, state)
	if type(snapshot) ~= "table" or type(state) ~= "table" then
		return false
	end

	return snapshot.account_key == state.account_key and snapshot.context == state.active_context and snapshot.context_entry_id == state.context_entry_id and snapshot.read_request_generation == state.read_request_generation and snapshot.token == state.token
end

Domains.context.token_matches = function(state, token)
	return type(state) == "table" and state.token == token
end

Domains.reports = {}

local function clone_queue(queue)
	local result = {}

	for index = 1, #(queue or {}) do
		result[index] = queue[index]
	end

	return result
end

Domains.reports.upsert_bounded = function(queue, report, maximum)
	if type(report) ~= "table" or type(report.report_id) ~= "string" or report.report_id == "" then
		return clone_queue(queue), false
	end

	local result = clone_queue(queue)
	local replaced = false

	for index = 1, #result do
		if result[index] and result[index].report_id == report.report_id then
			result[index] = report
			replaced = true
			break
		end
	end

	if not replaced then
		result[#result + 1] = report
	end

	maximum = math.max(1, math.floor(tonumber(maximum) or #result))

	while #result > maximum do
		table.remove(result, 1)
	end

	return result, not replaced
end

Domains.reports.remove_head = function(queue)
	if type(queue) ~= "table" or #queue == 0 then
		return {}, nil
	end

	local result = clone_queue(queue)
	local report = table.remove(result, 1)

	return result, report
end

Domains.scheduler = {}

Domains.scheduler.next_retry_delay = function(context, retry_delay, morningstar_delay, operative_selection_delay)
	local base_delay = context == "operative_selection" and operative_selection_delay or morningstar_delay

	return math.max((tonumber(base_delay) or 0) - (tonumber(retry_delay) or 0), 0)
end

return Domains
