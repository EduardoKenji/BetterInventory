-- Games Lantern import lifecycle.  Clipboard/network/parser/catalog reads are
-- isolated from the existing manual Auto Crafter controller until an entire
-- two-slot build is resolved and atomically handed to the queue host.
local ImportController = {}

ImportController.CONTRACT_VERSION = "games_lantern_import_controller_v1"
ImportController.READ_TIMEOUT = 30
ImportController.STORE_POLL_INTERVAL = 0.25

local function safe_call(fn, ...)
	if type(fn) ~= "function" then
		return false, "method unavailable"
	end

	return pcall(fn, ...)
end

local function copy(value, seen)
	if type(value) ~= "table" then
		return value
	end

	seen = seen or {}
	if seen[value] then
		return seen[value]
	end

	local result = {}
	seen[value] = result

	for key, child in pairs(value) do
		result[key] = copy(child, seen)
	end

	return result
end

local function same_identity_build(left, right)
	local left_jobs = type(left) == "table" and left.jobs
	local right_jobs = type(right) == "table" and right.jobs

	if type(left_jobs) ~= "table" or type(right_jobs) ~= "table" or #left_jobs ~= #right_jobs then
		return false
	end

	for index, left_job in ipairs(left_jobs) do
		local right_job = right_jobs[index]
		local left_offer = left_job and left_job.offer or {}
		local right_offer = right_job and right_job.offer or {}

		if not right_job
			or tostring(left_job.slot) ~= tostring(right_job.slot)
			or tostring(left_offer.offer_id) ~= tostring(right_offer.offer_id)
			or tostring(left_job.master_id or left_offer.master_id) ~= tostring(right_job.master_id or right_offer.master_id)
		then
			return false
		end
	end

	return true
end

function ImportController.new(dependencies)
	dependencies = dependencies or {}

	local self = {
		_clipboard_read = dependencies.clipboard_read,
		_clipboard = dependencies.clipboard,
		_transport = dependencies.transport,
		_parser = dependencies.parser,
		_resolver = dependencies.resolver,
		_get_resolution_context = dependencies.get_resolution_context,
		_fetch_catalogs = dependencies.fetch_catalogs,
		_cancel_catalogs = dependencies.cancel_catalogs,
		_install_queue = dependencies.install_queue,
		_queue_snapshot = dependencies.queue_snapshot,
		_can_import = dependencies.can_import,
		_report = dependencies.report,
		_clock = dependencies.clock,
		_resolution_elapsed = 0,
		_poll_elapsed = 0,
		_catalog_serial = 0,
		_state = "idle",
		_generation = 0,
		_url = nil,
		_model = nil,
		_identity_build = nil,
		_resolved_build = nil,
		_last_error = nil,
		_catalog_pending = false,
		_catalog_generation = nil,
		_choice_request = nil,
		_weapon_choices = {},
		_presentation_cache = nil,
		_presentation_signature = nil,
	}

	local function emit(kind, payload)
		if type(self._report) == "function" then
			pcall(self._report, kind, payload or {})
		end
	end

	local function queue_busy()
		if type(self._queue_snapshot) ~= "function" then
			return false
		end

		local ok, snapshot = pcall(self._queue_snapshot)
		local state = ok and snapshot and snapshot.state

		return state == "running" or state == "starting" or state == "selecting" or state == "preflighting" or state == "dispatching" or state == "waiting_next" or state == "stopping" or state == "quarantined" or state == "reconciliation_required"
	end

	local function fail(reason, payload)
		self._generation = self._generation + 1
		if self._transport and type(self._transport.cancel) == "function" then
			pcall(self._transport.cancel, self._transport, "import_failed")
		end
		if self._catalog_pending and type(self._cancel_catalogs) == "function" then
			pcall(self._cancel_catalogs, self._catalog_generation)
		end
		self._state = "failed"
		self._last_error = tostring(reason or "import_failed")
		self._catalog_pending = false
		self._catalog_generation = nil
		local details = payload or {}
		details.reason = self._last_error
		emit("import_failed", details)

		return false
	end

	local function cancel_catalog_read()
		if self._catalog_pending and type(self._cancel_catalogs) == "function" then
			pcall(self._cancel_catalogs, self._catalog_generation)
		end

		self._catalog_pending = false
		self._catalog_generation = nil
	end

	local function resolution_expired()
		local ok, now = safe_call(self._clock)
		if ok and type(now) == "number" and self._resolution_started_at then
			return now - self._resolution_started_at >= ImportController.READ_TIMEOUT
		end
		return self._resolution_elapsed >= ImportController.READ_TIMEOUT
	end

	local function read_clipboard_url()
		local ok, raw_clipboard = safe_call(self._clipboard_read)
		if not ok or type(raw_clipboard) ~= "string" then
			return nil, ok and "clipboard_empty" or "clipboard_read_failed"
		end

		local extract = self._clipboard and self._clipboard.extract_url
		if type(extract) ~= "function" then
			return nil, "clipboard_parser_unavailable"
		end

		local extract_ok, url, extract_reason = pcall(extract, raw_clipboard)
		if not extract_ok or not url then
			return nil, extract_ok and extract_reason or "clipboard_parser_failed"
		end

		return url
	end

	local function current_import_state()
		return self._state == "fetching" or self._state == "waiting_for_store" or self._state == "resolving_catalogues" or self._state == "awaiting_weapon_choice" or self._state == "staged"
	end

	function self:clipboard_matches_current()
		local url, reason = read_clipboard_url()
		if not url then
			return false, reason
		end

		return current_import_state() and url == self._url, nil
	end

	function self:paste()
		if queue_busy() then
			return false, "queue_busy"
		end

		if type(self._can_import) == "function" then
			local admission_ok, admitted, admission_reason = safe_call(self._can_import)

			if not admission_ok or admitted ~= true then
				return false, admission_ok and admission_reason or "import_admission_failed"
			end
		end

		local url, clipboard_reason = read_clipboard_url()
		if not url then
			return fail(clipboard_reason, {})
		end
		if current_import_state() and url == self._url then
			return true, "already_current"
		end

		self._generation = self._generation + 1
		cancel_catalog_read()

		if type(self._transport) == "table" and type(self._transport.cancel) == "function" then
			pcall(self._transport.cancel, self._transport, "new_paste")
		end

		self._url = url
		self._model = nil
		self._identity_build = nil
		self._resolved_build = nil
		self._choice_request = nil
		self._weapon_choices = {}
		self._last_error = nil
		self._resolution_elapsed = 0
		self._resolution_started_at = nil
		self._poll_elapsed = 0

		local start = self._transport and self._transport.start
		local transport_ok, started, transport_error = pcall(start, self._transport, url)
		if not transport_ok or started ~= true then
			return fail("transport_start_failed", { error = transport_ok and transport_error or started })
		end

		self._state = "fetching"
		emit("import_started", { generation = self._generation })

		return true
	end

	function self:_begin_catalog_resolution()
		local generation = self._generation
		if not self._resolution_started_at then
			local ok, now = safe_call(self._clock)
			if ok and type(now) == "number" then self._resolution_started_at = now end
		end
		if resolution_expired() then return fail("resolution_timeout") end
		local context_ok, context = safe_call(self._get_resolution_context)
		if not context_ok or type(context) ~= "table" then
			return fail("resolution_context_unavailable", { error = context })
		end
		if context.identity_stable == false then
			return fail(context.identity_reason or "character_context_settling", {
				error = "wait for the active character profile to finish switching",
			})
		end
		if context.native_store_ready == false then
			local already_waiting = self._state == "waiting_for_store"
			self._state = "waiting_for_store"
			if not already_waiting then
				emit("import_waiting_for_store", {
					error = context.native_store_reason,
					generation = generation,
				})
			end

			return true
		end
		context.weapon_choices = self._weapon_choices

		local identity, identity_reason, choice_request = self._resolver.resolve_identities(self._model, context)
		if not identity then
			if identity_reason == "weapon_choice_required" and type(choice_request) == "table" then
				self._choice_request = choice_request
				self._state = "awaiting_weapon_choice"
				emit("import_choice_required", { generation = generation })

				return true
			end
			local details = {}
			if identity_reason == "archetype_mismatch" then
				local canonicalize = self._resolver and self._resolver.canonical_archetype
				local source = self._model and self._model.source_archetype
				local active = context.active_archetype
				local canonical_source = type(canonicalize) == "function" and canonicalize(source) or source
				local canonical_active = type(canonicalize) == "function" and canonicalize(active) or active
				details.error = string.format("source=%s->%s active=%s->%s", tostring(source), tostring(canonical_source), tostring(active), tostring(canonical_active))
			end

			return fail(identity_reason or "weapon_identity_unavailable", details)
		end

		self._choice_request = nil
		self._identity_build = identity
		self._state = "resolving_catalogues"
		self._catalog_pending = true
		self._catalog_serial = self._catalog_serial + 1
		local catalog_token = self._catalog_serial
		self._catalog_generation = catalog_token

		local function complete(catalogs, error_value)
			if generation ~= self._generation or not self._catalog_pending or self._catalog_generation ~= catalog_token then
				return false
			end
			if resolution_expired() then return fail("catalog_resolution_timeout") end

			self._catalog_pending = false
			self._catalog_generation = nil

			if error_value or type(catalogs) ~= "table" then
				return fail(error_value or "trait_catalog_unavailable", {})
			end

			local current_context_ok, current_context = safe_call(self._get_resolution_context)
			if not current_context_ok or type(current_context) ~= "table" then
				return fail("resolution_context_unavailable", { error = current_context })
			end
			if current_context.identity_stable == false then
				return fail(current_context.identity_reason or "character_context_settling", {
					error = "active character changed during catalogue resolution",
				})
			end
			if current_context.native_store_ready == false then
				self._state = "waiting_for_store"
				emit("import_waiting_for_store", {
					error = current_context.native_store_reason,
					generation = generation,
				})

				return true
			end

			current_context.weapon_choices = self._weapon_choices
			local current_identity = self._resolver.resolve_identities(self._model, current_context)
			if not same_identity_build(identity, current_identity) then
				emit("import_store_changed", { generation = generation })

				return self:_begin_catalog_resolution()
			end

			identity = current_identity
			context = current_context
			self._identity_build = identity

			local resolved, resolve_reason, resolve_detail = self._resolver.attach_catalogs(identity, catalogs, context)
			if not resolved then
				return fail(resolve_reason or "trait_resolution_failed", { error = resolve_detail })
			end

			local install_ok, install_result = safe_call(self._install_queue, resolved)
			if not install_ok or install_result == false then
				return fail("queue_install_failed", { error = install_result })
			end

			self._resolved_build = resolved
			self._state = "staged"
			emit("import_staged", { build = resolved })

			return true
		end

		local fetch_ok, fetch_result = safe_call(self._fetch_catalogs, identity, complete, catalog_token)
		if not fetch_ok or fetch_result == false then
			return fail("catalog_fetch_start_failed", { error = fetch_result })
		end

		return true
	end

	function self:select_weapon_choice(slot, card_index)
		if self._state ~= "awaiting_weapon_choice" or slot ~= "melee" and slot ~= "ranged" then
			return false, "weapon_choice_unavailable"
		end

		local candidates = self._choice_request and self._choice_request[slot] or {}
		local found = false
		for _, candidate in ipairs(candidates) do
			if tostring(candidate.external and candidate.external.card_index) == tostring(card_index) then
				found = true
				break
			end
		end
		if not found then
			return false, "invalid_weapon_choice"
		end

		self._weapon_choices[slot] = card_index
		-- User deliberation is not a stalled network/store read.
		self._resolution_started_at = nil
		self._resolution_elapsed = 0
		self._poll_elapsed = 0

		return self:_begin_catalog_resolution()
	end

	function self:update(dt)
		if self._state == "waiting_for_store" or self._state == "resolving_catalogues" then
			local elapsed = type(dt) == "number" and dt == dt and dt > 0 and dt < math.huge and dt or 0
			self._resolution_elapsed = self._resolution_elapsed + elapsed
			self._poll_elapsed = self._poll_elapsed + elapsed
			if resolution_expired() then
				local reason = self._state == "waiting_for_store" and "native_store_timeout" or "catalog_resolution_timeout"
				fail(reason)
				return self._state
			end
		end
		if self._state == "waiting_for_store" then
			if self._poll_elapsed >= ImportController.STORE_POLL_INTERVAL then
				self._poll_elapsed = 0
				self:_begin_catalog_resolution()
			end

			return self._state
		end
		if self._state ~= "fetching" then
			return self._state
		end

		local transport_state = self._transport:update()
		if transport_state == "complete" then
			local result, result_reason = self._transport:take_result()

			if not result or type(result.body) ~= "string" then
				return fail("transport_result_unavailable", { error = result_reason })
			end

			local model, parse_reason = self._parser.parse(result.body)
			if not model then
				return fail(parse_reason or "build_parse_failed", {})
			end

			local requested_uuid = string.match(self._url or "", "/([0-9a-fA-F%-]+)$")
			if model.source_uuid and requested_uuid and string.lower(model.source_uuid) ~= string.lower(requested_uuid) then
				return fail("build_uuid_mismatch", {})
			end
			model.source_uuid = requested_uuid
			self._model = model

			return self:_begin_catalog_resolution() and self._state or self._state
		elseif transport_state == "failed" or transport_state == "cancelled" then
			return fail(self._transport:snapshot().last_error or "transport_failed", {})
		end

		return self._state
	end

	function self:clear()
		if queue_busy() then
			return false, "import_busy"
		end
		self:cancel("cleared")

		self._generation = self._generation + 1
		self._state = "idle"
		self._resolution_elapsed = 0
		self._resolution_started_at = nil
		self._poll_elapsed = 0
		self._url = nil
		self._model = nil
		self._identity_build = nil
		self._resolved_build = nil
		self._choice_request = nil
		self._weapon_choices = {}
		self._last_error = nil
		self._presentation_cache = nil
		self._presentation_signature = nil

		return true
	end

	function self:cancel(reason)
		self._generation = self._generation + 1
		cancel_catalog_read()

		if type(self._transport) == "table" and type(self._transport.cancel) == "function" then
			pcall(self._transport.cancel, self._transport, reason or "import_cancelled")
		end

		self._state = "cancelled"
		self._last_error = tostring(reason or "import_cancelled")
		self._presentation_cache = nil
		self._presentation_signature = nil

		return true
	end

	function self:snapshot()
		return {
			contract_version = ImportController.CONTRACT_VERSION,
			state = self._state,
			generation = self._generation,
			url = self._url,
			source_uuid = self._model and self._model.source_uuid,
			last_error = self._last_error,
			identity_build = copy(self._identity_build),
			resolved_build = copy(self._resolved_build),
			choice_request = copy(self._choice_request),
			weapon_choices = copy(self._weapon_choices),
			catalog_pending = self._catalog_pending,
		}
	end

	function self:state()
		return self._state
	end

	function self:presentation_snapshot()
		local signature = table.concat({
			tostring(self._generation or 0),
			tostring(self._state or "idle"),
			tostring(self._last_error or ""),
			tostring(self._choice_request or ""),
		}, "|")
		if self._presentation_cache and self._presentation_signature == signature then
			return self._presentation_cache
		end

		local choices = {}
		for _, slot in ipairs({ "melee", "ranged" }) do
			choices[slot] = {}
			for index, candidate in ipairs(self._choice_request and self._choice_request[slot] or {}) do
				local external = candidate.external or {}
				choices[slot][index] = {
					display_name = candidate.display_name or external.display_name,
					external = { card_index = external.card_index },
				}
			end
		end

		self._presentation_signature = signature
		self._presentation_cache = {
			choice_request = choices,
			last_error = self._last_error,
			state = self._state,
		}

		return self._presentation_cache
	end

	return self
end

return ImportController
