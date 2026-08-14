-- Games Lantern import lifecycle.  Clipboard/network/parser/catalog reads are
-- isolated from the existing manual Auto Crafter controller until an entire
-- two-slot build is resolved and atomically handed to the queue host.
local ImportController = {}

ImportController.CONTRACT_VERSION = "games_lantern_import_controller_v1"

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
		self._state = "failed"
		self._last_error = tostring(reason or "import_failed")
		self._catalog_pending = false
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
		return self._state == "fetching" or self._state == "resolving_catalogues" or self._state == "awaiting_weapon_choice" or self._state == "staged"
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
		local context_ok, context = safe_call(self._get_resolution_context)
		if not context_ok or type(context) ~= "table" then
			return fail("resolution_context_unavailable", { error = context })
		end
		if context.identity_stable == false then
			return fail(context.identity_reason or "character_context_settling", {
				error = "wait for the active character profile to finish switching",
			})
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
		self._catalog_generation = generation

		local function complete(catalogs, error_value)
			if generation ~= self._generation or not self._catalog_pending then
				return false
			end

			self._catalog_pending = false
			self._catalog_generation = nil

			if error_value or type(catalogs) ~= "table" then
				return fail(error_value or "trait_catalog_unavailable", {})
			end

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

		local fetch_ok, fetch_result = safe_call(self._fetch_catalogs, identity, complete, generation)
		if not fetch_ok or fetch_result == false then
			self._catalog_pending = false

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

		return self:_begin_catalog_resolution()
	end

	function self:update()
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
		if queue_busy() or self._catalog_pending then
			return false, "import_busy"
		end

		self._generation = self._generation + 1
		self._state = "idle"
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
