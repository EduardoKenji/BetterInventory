-- Windows curl adapter for games_lantern.transport.
-- All paths are owner-tagged exact files. The only value crossing the shell
-- boundary is the canonical UUID URL produced by clipboard.lua.
local Adapter = {}

local SEQUENCE = 0
local MAX_BYTES = 2 * 1024 * 1024
local CONNECT_TIMEOUT = 5
local REQUEST_TIMEOUT = 20

local function io_api()
	local mods = rawget(_G, "Mods")

	return mods and mods.lua and mods.lua.io or rawget(_G, "io")
end

local function remove(path)
	if type(path) ~= "string" or path == "" then
		return
	end

	local api = io_api()
	if api and type(api.open) == "function" then
		local file = api.open(path, "rb")
		if file then
			file:close()
			pcall(os.remove, path)
		end
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

local function safe_path(value)
	return type(value) == "string" and value ~= "" and not string.find(value, '["\r\n]')
end

local function quote(value)
	if not safe_path(value) then
		return nil
	end

	return '"' .. value .. '"'
end

local function write_file(path, lines)
	local api = io_api()
	if not api or type(api.open) ~= "function" or not safe_path(path) then
		return false
	end

	local file = api.open(path, "wb")
	if not file then
		return false
	end

	for _, line in ipairs(lines) do
		file:write(line, "\r\n")
	end

	file:close()

	return true
end

local function valid_url(url)
	return type(url) == "string" and string.match(url, "^https://darktide%.gameslantern%.com/builds/%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

function Adapter.spawn(url, generation, max_bytes)
	if not valid_url(url) then
		return nil, "non_canonical_url"
	end

	SEQUENCE = SEQUENCE + 1
	local temp = os.getenv("TEMP") or os.getenv("TMP") or "."
	local tag = string.format("%d_%d", tonumber(generation) or 0, SEQUENCE)
	local output_path = temp .. "\\BetterInventory_games_lantern_" .. tag .. ".html"
	local done_path = temp .. "\\BetterInventory_games_lantern_" .. tag .. ".done"
	local status_path = temp .. "\\BetterInventory_games_lantern_" .. tag .. ".status"
	local script_path = temp .. "\\BetterInventory_games_lantern_" .. tag .. ".bat"
	local error_path = temp .. "\\BetterInventory_games_lantern_" .. tag .. ".err"
	local curl = (os.getenv("SystemRoot") or "C:\\Windows") .. "\\System32\\curl.exe"
	local quoted = { quote(output_path), quote(done_path), quote(status_path), quote(script_path), quote(error_path), quote(curl) }

	for _, path in ipairs({ output_path, done_path, status_path, script_path, error_path }) do
		remove(path)
	end

	for _, value in ipairs(quoted) do
		if not value then
			return nil, "unsafe_transport_path"
		end
	end

	local limit = tonumber(max_bytes) or MAX_BYTES
	local script = {
		"@echo off",
		string.format("%s --silent --show-error --connect-timeout %d --max-time %d --max-filesize %d --proto =https -o %s -w \"%%{http_code}\" %s > %s 2> %s", quoted[6], CONNECT_TIMEOUT, REQUEST_TIMEOUT, limit, quoted[1], quote(url), quoted[3], quoted[5]),
		string.format(">%s echo %%ERRORLEVEL%%", quoted[2]),
	}

	if not write_file(script_path, script) then
		return nil, "script_write_failed"
	end

	local api = io_api()
	if not api or type(api.popen) ~= "function" then
		remove(script_path)

		return nil, "process_api_unavailable"
	end

	local handle = api.popen("cmd /c start \"\" /B " .. quoted[4])
	if handle then
		handle:close()
	else
		remove(script_path)

		return nil, "process_spawn_failed"
	end

	return {
		output_path = output_path,
		done_path = done_path,
		status_path = status_path,
		script_path = script_path,
		error_path = error_path,
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

	local exit_code = tonumber(string.match(done, "%-?%d+"))
	local status_text = read_file(handle.status_path, 32)
	local status = tonumber(status_text and string.match(status_text, "%d%d%d") or nil)
	local body, size = read_file(handle.output_path, handle.max_bytes)

	return {
		done = true,
		exit_code = exit_code,
		status = status,
		body = body,
		bytes = tonumber(size) or type(body) == "string" and #body or 0,
	}
end

function Adapter.cleanup(handle)
	if type(handle) ~= "table" then
		return true
	end

	for _, path in ipairs({ handle.output_path, handle.done_path, handle.status_path, handle.script_path, handle.error_path }) do
		remove(path)
	end

	return true
end

return Adapter
