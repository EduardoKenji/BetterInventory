local ViewSession = {}
local sessions = setmetatable({}, {
	__mode = "k",
})

local function new_session(view, kind)
	return {
		closed = false,
		cleanup = {},
		cleanup_order = {},
		fields = {},
		kind = kind,
		view = view,
	}
end

ViewSession.begin = function(view, kind)
	if not view then
		return
	end

	local session = sessions[view]

	if session and not session.closed then
		return session
	end

	session = new_session(view, kind)
	sessions[view] = session

	return session
end

ViewSession.active = function(view)
	local session = view and sessions[view]

	return session and not session.closed and session or nil
end

ViewSession.register_cleanup = function(view, cleanup_id, callback)
	local session = ViewSession.active(view) or ViewSession.begin(view)

	if not session or type(cleanup_id) ~= "string" or type(callback) ~= "function" then
		return false
	end

	if not session.cleanup[cleanup_id] then
		session.cleanup_order[#session.cleanup_order + 1] = cleanup_id
	end

	session.cleanup[cleanup_id] = callback

	return true
end

ViewSession.set_field = function(view, field_name, value)
	local session = ViewSession.active(view) or ViewSession.begin(view)

	if not session or type(field_name) ~= "string" then
		return false
	end

	local field = session.fields[field_name]

	if not field then
		field = {
			current = nil,
			original = view[field_name],
		}
		session.fields[field_name] = field
	end

	view[field_name] = value
	field.current = value

	return true
end

ViewSession.close = function(view, reason)
	local session = ViewSession.active(view)

	if not session then
		return false
	end

	session.closed = true

	for index = #session.cleanup_order, 1, -1 do
		local cleanup_id = session.cleanup_order[index]
		local callback = session.cleanup[cleanup_id]

		if callback then
			pcall(callback, view, reason, session)
		end
	end

	for field_name, field in pairs(session.fields) do
		-- Preserve a value written by another owner after this session claimed
		-- the field. Only restore the value this session still owns.
		if view[field_name] == field.current then
			view[field_name] = field.original
		end
	end

	sessions[view] = nil

	return true
end

ViewSession.count = function()
	local count = 0

	for _ in pairs(sessions) do
		count = count + 1
	end

	return count
end

return ViewSession
