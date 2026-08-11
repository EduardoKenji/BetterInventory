-- Bounded asynchronous transport coordinator for Games Lantern HTML.
-- Platform adapters only report completed responses; this module owns timeout,
-- size, status, cancellation, and generation rules.
local Transport = {}

Transport.CONTRACT_VERSION = "games_lantern_transport_v1"
Transport.MAX_HTML_BYTES = 2 * 1024 * 1024
Transport.DEFAULT_TIMEOUT_SECONDS = 20
Transport.DEFAULT_CONNECT_TIMEOUT_SECONDS = 5

local function safe_call(fn, ...)
	if type(fn) ~= "function" then
		return false, "method unavailable"
	end

	return pcall(fn, ...)
end

local function canonical_url(url)
	if type(url) ~= "string" then
		return false
	end

	local prefix = "https://darktide.gameslantern.com/builds/"
	local uuid = string.sub(url, #prefix + 1)

	return string.sub(url, 1, #prefix) == prefix and #uuid == 36 and string.match(uuid, "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

local function trusted_effective_url(request_url, effective_url)
	if not canonical_url(request_url) or type(effective_url) ~= "string" then
		return false
	end

	if effective_url == request_url then
		return true
	end

	local slug_prefix = request_url .. "/"
	if string.sub(effective_url, 1, #slug_prefix) ~= slug_prefix then
		return false
	end

	local slug = string.sub(effective_url, #slug_prefix + 1)

	return #slug >= 1 and #slug <= 160 and string.match(slug, "^[a-z0-9][a-z0-9%-]*$") ~= nil
end

function Transport.new(dependencies)
	dependencies = dependencies or {}

	local self = {
		_adapter = dependencies.adapter or {},
		_clock = dependencies.clock,
		_report = dependencies.report,
		_timeout_seconds = tonumber(dependencies.timeout_seconds) or Transport.DEFAULT_TIMEOUT_SECONDS,
		_poll_interval_seconds = tonumber(dependencies.poll_interval_seconds) or 0.15,
		_last_poll_at = nil,
		_max_bytes = tonumber(dependencies.max_bytes) or Transport.MAX_HTML_BYTES,
		_generation = 0,
		_state = "idle",
		_handle = nil,
		_started_at = nil,
		_url = nil,
		_result = nil,
		_last_error = nil,
	}

	local function now()
		if type(self._clock) == "function" then
			local ok, value = pcall(self._clock)

			return ok and tonumber(value) or 0
		end

		return 0
	end

	local function emit(kind, payload)
		if type(self._report) == "function" then
			pcall(self._report, kind, payload or {})
		end
	end

	local function cleanup_handle()
		if self._handle == nil then
			return true
		end

		local cleanup = self._adapter.cleanup or self._adapter.cancel
		local ok = true

		if type(cleanup) == "function" then
			local cleanup_ok, cleanup_result = safe_call(cleanup, self._handle)
			ok = cleanup_ok and cleanup_result ~= false
		end

		self._handle = nil

		return ok
	end

	local function fail(reason, details)
		cleanup_handle()
		self._state = "failed"
		self._last_error = tostring(reason or "transport_failed")
		self._result = nil
		local payload = details or {}
		payload.generation = payload.generation or self._generation
		payload.reason = self._last_error
		emit("transport_failed", payload)

		return false
	end

	function self:start(url)
		self._generation = self._generation + 1
		cleanup_handle()

		if not canonical_url(url) then
			self._state = "failed"
			self._last_error = "non_canonical_url"

			return false, self._last_error
		end

		local spawn = self._adapter.spawn
		local ok, handle, spawn_error = pcall(spawn, url, self._generation, self._max_bytes)
		if not ok or handle == nil then
			self._state = "failed"
			self._last_error = tostring(ok and (spawn_error or "transport_spawn_failed") or handle)

			return false, self._last_error
		end

		self._state = "running"
		self._handle = handle
		self._started_at = now()
		self._last_poll_at = self._started_at - self._poll_interval_seconds
		self._url = url
		self._result = nil
		self._last_error = nil
		emit("transport_started", { generation = self._generation })

		return true, self._generation
	end

	function self:cancel(reason)
		self._generation = self._generation + 1
		local had_work = self._state == "running"
		cleanup_handle()
		self._state = "cancelled"
		self._last_error = reason and tostring(reason) or "cancelled"
		self._result = nil

		if had_work then
			emit("transport_cancelled", { reason = self._last_error })
		end

		return had_work
	end

	function self:update()
		if self._state ~= "running" then
			return self._state
		end

		if now() - (self._started_at or 0) > self._timeout_seconds then
			fail("transport_timeout", { generation = self._generation })

			return self._state
		end

		local polled_at = now()
		if self._last_poll_at and polled_at - self._last_poll_at < self._poll_interval_seconds then
			return self._state
		end
		self._last_poll_at = polled_at

		local poll = self._adapter.poll
		local ok, response = safe_call(poll, self._handle, self._generation, self._max_bytes)
		if not ok then
			fail("transport_poll_crashed", { error = response })

			return self._state
		end

		if response == nil or response.done ~= true then
			return self._state
		end

		local status = tonumber(response.status)
		local content_type = type(response.content_type) == "string" and string.lower(response.content_type) or nil
		local exit_code = tonumber(response.exit_code)
		local body = response.body
		local bytes = tonumber(response.bytes) or type(body) == "string" and #body or 0
		local effective_url = response.effective_url

		if exit_code ~= nil and exit_code ~= 0 then
			fail("transport_process_failed", { exit_code = exit_code })

			return self._state
		end

		if not status or status < 200 or status >= 300 then
			fail("transport_http_status", { status = status or 0, bytes = bytes, content_type = content_type })

			return self._state
		end

		if not trusted_effective_url(self._url, effective_url) then
			fail("transport_redirect_target", { status = status, bytes = bytes, effective_url = effective_url })

			return self._state
		end

		if content_type ~= "text/html" and content_type ~= "application/xhtml+xml" then
			fail("transport_content_type", { content_type = content_type or "missing" })

			return self._state
		end

		if bytes > self._max_bytes then
			fail("transport_response_too_large", { bytes = bytes })

			return self._state
		end

		if type(body) ~= "string" then
			fail("transport_empty_response", {})

			return self._state
		end

		cleanup_handle()
		self._state = "complete"
		self._result = { status = status, content_type = content_type, bytes = bytes, body = body, generation = self._generation, effective_url = effective_url }
		emit("transport_complete", { generation = self._generation, bytes = bytes })

		return self._state
	end

	function self:take_result()
		if self._state ~= "complete" or not self._result then
			return nil, self._state
		end

		local result = self._result
		self._result = nil
		self._state = "idle"

		return result
	end

	function self:snapshot()
		return {
			contract_version = Transport.CONTRACT_VERSION,
			state = self._state,
			generation = self._generation,
			url = self._url,
			last_error = self._last_error,
			started_at = self._started_at,
			result_bytes = self._result and self._result.bytes or nil,
		}
	end

	return self
end

Transport._test = {
	canonical_url = canonical_url,
	trusted_effective_url = trusted_effective_url,
}

return Transport
