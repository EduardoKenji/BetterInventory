local Diagnostics = {}

local state = {
	enabled = false,
	last_sample_at = 0,
	counters = {},
	samples = {},
}

local SAMPLE_INTERVAL = 1

local function reset_storage()
	state.last_sample_at = 0
	state.counters = {}
	state.samples = {}
end

Diagnostics.configure = function(mod)
	local enabled = mod and type(mod.get) == "function" and mod:get("debug_enable_hot_path_diagnostics") == true

	if enabled ~= state.enabled then
		state.enabled = enabled
		reset_storage()
	end

	return state.enabled
end

Diagnostics.count = function(name, amount)
	if not state.enabled or type(name) ~= "string" then
		return
	end

	state.counters[name] = (state.counters[name] or 0) + (tonumber(amount) or 1)
end

Diagnostics.update = function(mod, dt, curio_acquisition, features)
	if not state.enabled then
		return false
	end

	state.last_sample_at = state.last_sample_at + math.max(tonumber(dt) or 0, 0)

	if state.last_sample_at < SAMPLE_INTERVAL then
		return true
	end

	state.last_sample_at = 0
	local active_promises = 0
	local oldest_operation_age = 0

	if curio_acquisition then
		if type(curio_acquisition.active_read_requests) == "function" then
			active_promises = active_promises + (tonumber(curio_acquisition.active_read_requests()) or 0)
		end

		if type(curio_acquisition.oldest_read_request_age) == "function" then
			oldest_operation_age = math.max(oldest_operation_age, tonumber(curio_acquisition.oldest_read_request_age()) or 0)
		end
	end

	if features and type(features.automatic_discard_read_request_count) == "function" then
		active_promises = active_promises + (tonumber(features.automatic_discard_read_request_count()) or 0)
	end

	state.samples.active_promises = active_promises
	state.samples.oldest_operation_age = oldest_operation_age
	state.samples.lua_memory_kb = tonumber(collectgarbage("count")) or 0
	state.samples.sample_count = (state.samples.sample_count or 0) + 1

	return true
end

Diagnostics.enabled = function()
	return state.enabled
end

Diagnostics.snapshot = function()
	local counters = {}
	local samples = {}

	for name, value in pairs(state.counters) do
		counters[name] = value
	end

	for name, value in pairs(state.samples) do
		samples[name] = value
	end

	return {
		enabled = state.enabled,
		counters = counters,
		samples = samples,
	}
end

Diagnostics.reset = function()
	state.enabled = false
	reset_storage()
end

return Diagnostics
