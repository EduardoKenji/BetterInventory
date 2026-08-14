-- Wine/Linux-host curl adapter for games_lantern.transport.
-- Uses only generated /tmp names and the canonical UUID URL; no clipboard
-- string is interpolated without validation.
local Adapter = {}

local SEQUENCE = 0
local MAX_BYTES = 2 * 1024 * 1024
local CONNECT_TIMEOUT = 5
local REQUEST_TIMEOUT = 20
local MAX_REDIRECTS = 3

local function io_api()
	local mods = rawget(_G, "Mods")

	return mods and mods.lua and mods.lua.io or rawget(_G, "io")
end

local function remove(path)
	if type(path) == "string" and path ~= "" then
		pcall(os.remove, path)
	end
end

local function cleanup_paths(paths)
	for _, path in ipairs(paths or {}) do
		remove(path)
	end
end

local function read_file(path, max_bytes)
	local api = io_api()
	if not api or type(api.open) ~= "function" then
		return nil, "io_unavailable"
	end

	local file = api.open(path, "rb")
	if not file then
		return nil, "not_ready"
	end

	local size = file:seek("end") or 0
	if max_bytes and size > max_bytes then
		file:close()

		return nil, size
	end

	file:seek("set")
	local value = file:read("*a")
	file:close()

	return value, size
end

local function write_file(path, lines)
	local api = io_api()
	if not api or type(api.open) ~= "function" then
		return false
	end

	local file = api.open(path, "wb")
	if not file then
		return false
	end

	for _, line in ipairs(lines) do
		file:write(line, "\n")
	end

	file:close()

	return true
end

local function parse_status_text(status_text)
	if type(status_text) ~= "string" then
		return nil, nil, nil
	end

	status_text = string.gsub(status_text, "\r\n", "\n")
	local status_line, content_type_line, effective_url = string.match(status_text, "^([^\n]*)\n([^\n]*)\n([^\n]*)")
	local status = tonumber(status_line and string.match(status_line, "%d%d%d") or nil)
	local content_type = content_type_line and string.match(content_type_line, "^([^%s;]+)") or nil

	return status, content_type, effective_url
end

local function valid_url(url)
	return type(url) == "string" and string.match(url, "^https://darktide%.gameslantern%.com/builds/%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

local function shell_single_quote(value)
	if type(value) ~= "string" or string.find(value, "'", 1, true) or string.find(value, "[\r\n]", 1) then
		return nil
	end

	return "'" .. value .. "'"
end

local function z_root_available()
	local api = io_api()
	if not api or type(api.open) ~= "function" then
		return false
	end

	local file = api.open("Z:\\proc\\version", "r")
	if not file then
		return false
	end

	local content = file:read(64)
	file:close()

	return type(content) == "string" and string.find(content, "Linux", 1, true) ~= nil
end

function Adapter.spawn(url, generation, max_bytes)
	if not valid_url(url) then
		return nil, "non_canonical_url"
	end

	if not z_root_available() then
		return nil, "wine_z_root_unavailable"
	end

	SEQUENCE = SEQUENCE + 1
	local tag = string.format("%d_%d_%d_%d", os.time(), math.floor((os.clock() or 0) * 1000000), tonumber(generation) or 0, SEQUENCE)
	local output_unix = "/tmp/BetterInventory_games_lantern_" .. tag .. ".html"
	local done_unix = "/tmp/BetterInventory_games_lantern_" .. tag .. ".done"
	local status_unix = "/tmp/BetterInventory_games_lantern_" .. tag .. ".status"
	local script_unix = "/tmp/BetterInventory_games_lantern_" .. tag .. ".sh"
	local pid_unix = "/tmp/BetterInventory_games_lantern_" .. tag .. ".pid"
	local output_win = "Z:\\tmp\\BetterInventory_games_lantern_" .. tag .. ".html"
	local done_win = "Z:\\tmp\\BetterInventory_games_lantern_" .. tag .. ".done"
	local status_win = "Z:\\tmp\\BetterInventory_games_lantern_" .. tag .. ".status"
	local script_win = "Z:\\tmp\\BetterInventory_games_lantern_" .. tag .. ".sh"
	local pid_win = "Z:\\tmp\\BetterInventory_games_lantern_" .. tag .. ".pid"
	local limit = tonumber(max_bytes) or MAX_BYTES
	local quoted_url = shell_single_quote(url)
	local paths = { output_win, done_win, status_win, script_win, pid_win }

	cleanup_paths(paths)

	if not quoted_url or not write_file(script_win, {
		"echo $$ > " .. shell_single_quote(pid_unix),
		"out=" .. shell_single_quote(output_unix) .. "; done=" .. shell_single_quote(done_unix) .. "; status=" .. shell_single_quote(status_unix),
		"child_pid=",
		"cleanup_child() { if [ -n \"$child_pid\" ]; then kill -TERM \"$child_pid\" 2>/dev/null; wait \"$child_pid\" 2>/dev/null; fi; }",
		"trap 'cleanup_child; exit 143' HUP INT TERM",
		-- Games Lantern canonical UUID URLs redirect once to their slugged page.
		-- Match the Windows adapter while bounding both count and protocol; the
		-- coordinator validates the final host, UUID, and slug before parsing.
		"curl -s -S --location --max-redirs " .. tostring(MAX_REDIRECTS) .. " --connect-timeout " .. tostring(CONNECT_TIMEOUT) .. " --max-time " .. tostring(REQUEST_TIMEOUT) .. " --max-filesize " .. tostring(limit) .. " --proto '=https' --proto-redir '=https' -o \"$out\" -w '%{http_code}\\n%{content_type}\\n%{url_effective}' " .. quoted_url .. " > \"$status\" &",
		"child_pid=$!; wait \"$child_pid\"; code=$?",
		"trap - HUP INT TERM; echo $code > \"$done\"",
	}) then
		cleanup_paths(paths)

		return nil, "script_write_failed"
	end

	local api = io_api()
	if not api or type(api.popen) ~= "function" then
		cleanup_paths(paths)

		return nil, "process_api_unavailable"
	end

	local handle = api.popen("cmd /c start /unix /bin/sh " .. script_unix)
	if handle then
		handle:close()
	else
		cleanup_paths(paths)

		return nil, "process_spawn_failed"
	end

	return {
		output_path = output_win,
		done_path = done_win,
		status_path = status_win,
		script_path = script_win,
		pid_path = pid_win,
		max_bytes = limit,
	}
end

function Adapter.poll(handle)
	if type(handle) ~= "table" then
		return { done = true, exit_code = 1, status = 0 }
	end

	local done = read_file(handle.done_path, 64)
	if not done then
		return { done = false }
	end
	handle.completed = true

	local exit_code = tonumber(string.match(done, "%-?%d+"))
	local status_text = read_file(handle.status_path, 1024)
	local status, content_type, effective_url = parse_status_text(status_text)
	local body, size = read_file(handle.output_path, handle.max_bytes)

	return {
		done = true,
		exit_code = exit_code,
		status = status,
		content_type = content_type,
		effective_url = effective_url,
		body = body,
		bytes = tonumber(size) or type(body) == "string" and #body or 0,
	}
end

function Adapter.cleanup(handle)
	if type(handle) ~= "table" then
		return true
	end
	if not handle.completed then
		local pid_text = read_file(handle.pid_path, 32)
		local pid = tonumber(pid_text and string.match(pid_text, "%d+") or nil)
		local api = io_api()
		if pid and api and type(api.popen) == "function" then
			local killer = api.popen("cmd /c start /unix /bin/kill -TERM " .. tostring(math.floor(pid)))
			if killer then killer:close() end
		end
	end

	cleanup_paths({ handle.output_path, handle.done_path, handle.status_path, handle.script_path, handle.pid_path })

	return true
end

Adapter._test = {
	parse_status_text = parse_status_text,
}

return Adapter
