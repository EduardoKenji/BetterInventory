-- Windows curl adapter for games_lantern.transport.
-- All paths are owner-tagged exact files. The only value crossing the shell
-- boundary is the canonical UUID URL produced by clipboard.lua.
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

function Adapter.spawn(url, generation, max_bytes)
	if not valid_url(url) then
		return nil, "non_canonical_url"
	end

	SEQUENCE = SEQUENCE + 1
	local temp = os.getenv("TEMP") or os.getenv("TMP") or "."
	local tag = string.format("%d_%d_%d_%d", os.time(), math.floor((os.clock() or 0) * 1000000), tonumber(generation) or 0, SEQUENCE)
	local output_path = temp .. "\\BetterInventory_games_lantern_" .. tag .. ".html"
	local done_path = temp .. "\\BetterInventory_games_lantern_" .. tag .. ".done"
	local status_path = temp .. "\\BetterInventory_games_lantern_" .. tag .. ".status"
	local script_path = temp .. "\\BetterInventory_games_lantern_" .. tag .. ".bat"
	local launcher_path = temp .. "\\BetterInventory_games_lantern_" .. tag .. ".ps1"
	local error_path = temp .. "\\BetterInventory_games_lantern_" .. tag .. ".err"
	local curl = (os.getenv("SystemRoot") or "C:\\Windows") .. "\\System32\\curl.exe"
	local powershell = (os.getenv("SystemRoot") or "C:\\Windows") .. "\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
	local quoted = { quote(output_path), quote(done_path), quote(status_path), quote(script_path), quote(error_path), quote(curl), quote(launcher_path), quote(powershell) }
	local paths = { output_path, done_path, status_path, script_path, launcher_path, error_path }

	cleanup_paths(paths)

	for _, value in ipairs(quoted) do
		if not value then
			return nil, "unsafe_transport_path"
		end
	end

	local limit = tonumber(max_bytes) or MAX_BYTES
	local script = {
		"@echo off",
		-- The batch file needs doubled percent signs so cmd.exe passes curl's
		-- write-out placeholders through unchanged.  Follow the canonical URL's
		-- same-origin slug redirect, which Games Lantern uses for build pages.
		string.format("%s --silent --show-error --location --max-redirs %d --connect-timeout %d --max-time %d --max-filesize %d --proto =https --proto-redir =https -o %s -w \"%%%%{http_code}\\n%%%%{content_type}\\n%%%%{url_effective}\" %s > %s 2> %s", quoted[6], MAX_REDIRECTS, CONNECT_TIMEOUT, REQUEST_TIMEOUT, limit, quoted[1], quote(url), quoted[3], quoted[5]),
		string.format(">%s echo %%ERRORLEVEL%%", quoted[2]),
	}

	if not write_file(script_path, script) then
		cleanup_paths(paths)

		return nil, "script_write_failed"
	end
	local ps_script_path = string.gsub(script_path, "'", "''")
	if not write_file(launcher_path, {
		"$p = Start-Process -FilePath 'cmd.exe' -ArgumentList '/d','/s','/c','\"\"" .. ps_script_path .. "\"\"' -WindowStyle Hidden -PassThru",
		"$p.Id",
	}) then
		cleanup_paths(paths)

		return nil, "launcher_write_failed"
	end

	local api = io_api()
	if not api or type(api.popen) ~= "function" then
		cleanup_paths(paths)

		return nil, "process_api_unavailable"
	end

	-- io.popen is itself hosted by cmd.exe on Windows.  Starting its command
	-- with a quoted executable makes cmd consume the quote pair as command-line
	-- decoration and corrupt the remaining path.  SystemRoot's canonical
	-- PowerShell path has no spaces, so launch that validated path directly.
	local process = api.popen(powershell .. " -NoProfile -NonInteractive -ExecutionPolicy Bypass -File " .. quoted[7])
	local pid = process and tonumber(process:read("*l")) or nil
	if process then
		process:close()
	end
	if not pid then
		cleanup_paths(paths)

		return nil, "process_spawn_failed"
	end

	return {
		output_path = output_path,
		done_path = done_path,
		status_path = status_path,
		script_path = script_path,
		error_path = error_path,
		launcher_path = launcher_path,
		pid = pid,
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
	if not handle.completed and tonumber(handle.pid) then
		local api = io_api()
		if api and type(api.popen) == "function" then
			local killer = api.popen("cmd /c taskkill /PID " .. tostring(math.floor(handle.pid)) .. " /T /F >nul 2>nul")
			if killer then killer:close() end
		end
	end

	cleanup_paths({ handle.output_path, handle.done_path, handle.status_path, handle.script_path, handle.launcher_path, handle.error_path })

	return true
end

Adapter._test = {
	parse_status_text = parse_status_text,
}

return Adapter
