-- Narrow host adapter for the game/Lantern clipboard bridge.
-- URL validation remains in clipboard.lua; this module only reads text.
local HostClipboard = {}

function HostClipboard.read()
	local clipboard = rawget(_G, "Clipboard")
	if type(clipboard) ~= "table" then
		return nil, "clipboard_unavailable"
	end

	for _, method_name in ipairs({ "get", "get_text", "read" }) do
		local method = clipboard[method_name]

		if type(method) == "function" then
			local ok, value = pcall(method)

			if ok and type(value) == "string" then
				return value
			end
		end
	end

	return nil, "clipboard_empty"
end

return HostClipboard
