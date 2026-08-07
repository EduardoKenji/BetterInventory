local Contracts = {}
local unpack_values = table.unpack or unpack

local function supported_object(object)
	local object_type = type(object)

	return object_type == "table" or object_type == "userdata"
end

local function invoke_method(object, method_name, ...)
	if not supported_object(object) or type(method_name) ~= "string" then
		return "unavailable", "method unavailable"
	end

	local lookup_ok, method = pcall(function()
		return object[method_name]
	end)

	if not lookup_ok or type(method) ~= "function" then
		return "unavailable", lookup_ok and "method unavailable" or method
	end

	local call_results = {pcall(method, object, ...)}

	if not call_results[1] then
		return "error", call_results[2]
	end

	return "ok", unpack_values(call_results, 2)
end

-- Centralize guarded calls into Darktide/private or optional-mod APIs. Callers
-- still choose the conservative fallback; this module only owns invocation
-- safety and method binding.
Contracts.safe_call = function(method, ...)
	if type(method) ~= "function" then
		return false, "method unavailable"
	end

	return pcall(method, ...)
end

Contracts.safe_method = function(object, method_name, ...)
	if not supported_object(object) or type(method_name) ~= "string" then
		return false, "method unavailable"
	end

	local lookup_ok, method = pcall(function()
		return object[method_name]
	end)

	if not lookup_ok or type(method) ~= "function" then
		return false, lookup_ok and "method unavailable" or method
	end

	local call_results = {pcall(method, object, ...)}

	if not call_results[1] then
		return false, call_results[2]
	end

	return true, unpack_values(call_results, 2)
end

-- Typed capability results keep a real `false` return distinct from an absent
-- optional method and from a method that threw. Callers may select domain
-- defaults without collapsing these states into one generic false/no-op path.
Contracts.read_only = function(object, method_name, ...)
	return invoke_method(object, method_name, ...)
end

Contracts.mutation = function(object, method_name, ...)
	return invoke_method(object, method_name, ...)
end

Contracts.ui = function(object, method_name, ...)
	return invoke_method(object, method_name, ...)
end

Contracts.registry_refresh_required = function(object, method_name, ...)
	local status, value, detail = invoke_method(object, method_name, ...)

	if status ~= "ok" then
		-- A missing/broken settings registry must refresh dependencies
		-- conservatively; an explicit successful false remains meaningful.
		return true, status, detail or value
	end

	return value ~= false, status, value
end

return Contracts
