local Contracts = {}

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
	if type(object) ~= "table" or type(method_name) ~= "string" or type(object[method_name]) ~= "function" then
		return false, "method unavailable"
	end

	return pcall(object[method_name], object, ...)
end

return Contracts
