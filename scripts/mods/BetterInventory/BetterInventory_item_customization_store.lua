local Store = {}

local STORAGE_SETTING_ID = "custom_item_name_and_colors"
local MAX_NAME_LENGTH = 80
local DEFAULT_NAME_COLOR = { 255, 220, 230, 210 }
local DEFAULT_BACKGROUND_COLOR = { 255, 45, 55, 45 }
local MAX_PERSISTENCE_ATTEMPTS = 3

local cached_records = {}
local persistence_pending = false
local persistence_retry_elapsed = 0
local persistence_attempts = 0
local persistence_last_outcome = "idle"
local pending_deleted_gear_ids = {}

local function normalize_name(value)
	if type(value) ~= "string" then
		return
	end

	-- Keep names single-line and prevent invisible whitespace-only records.
	value = string.gsub(value, "[%c]", " ")
	value = string.gsub(value, "%s+", " ")
	value = string.gsub(value, "^%s+", "")
	value = string.gsub(value, "%s+$", "")

	if value == "" then
		return
	end

	local utf8 = rawget(_G, "Utf8")

	if utf8 and type(utf8.string_length) == "function" and type(utf8.sub_string) == "function" then
		if utf8.string_length(value) > MAX_NAME_LENGTH then
			value = utf8.sub_string(value, 1, MAX_NAME_LENGTH)
		end
	elseif #value > MAX_NAME_LENGTH then
		value = string.sub(value, 1, MAX_NAME_LENGTH)
	end

	return value
end

local function clone_color(color, fallback)
	local source = type(color) == "table" and color or fallback

	return {
		255,
		math.max(0, math.min(255, math.floor(tonumber(source[2]) or fallback[2]))),
		math.max(0, math.min(255, math.floor(tonumber(source[3]) or fallback[3]))),
		math.max(0, math.min(255, math.floor(tonumber(source[4]) or fallback[4]))),
	}
end

local function records_for(mod)
	local records = mod:get(STORAGE_SETTING_ID)

	if type(records) ~= "table" then
		records = {}
	end

	cached_records = records

	return records
end

local function mark_persistence_pending()
	persistence_pending = true
	persistence_last_outcome = "pending"
	persistence_attempts = 0
	-- A new mutation should be eligible for the next runtime flush. Once a
	-- save attempt is made, unknown/failing outcomes are retried at a bounded
	-- cadence instead of every frame.
	persistence_retry_elapsed = 1
end

local function save_records(mod, records)
	cached_records = records
	mod:set(STORAGE_SETTING_ID, records, false)
	mark_persistence_pending()
end

local function record_has_customization(record)
	return record.name ~= nil or record.name_color ~= nil or record.background_color ~= nil
end

local function sanitize_record(record)
	if type(record) ~= "table" then
		return nil, true
	end

	local changed = false
	local name = normalize_name(record.name)

	if name ~= record.name then
		record.name = name
		changed = true
	end

	for _, field in ipairs({ "name_color", "background_color" }) do
		if record[field] ~= nil and type(record[field]) ~= "table" then
			record[field] = nil
			changed = true
		end
	end

	if record.background_color == nil and record.background_preserve_shading ~= nil then
		record.background_preserve_shading = nil
		changed = true
	elseif record.background_preserve_shading ~= nil and type(record.background_preserve_shading) ~= "boolean" then
		record.background_preserve_shading = nil
		changed = true
	end

	if record.name == nil or (record.name_target ~= "primary" and record.name_target ~= "sub") then
		if record.name_target ~= nil then
			record.name_target = nil
			changed = true
		end
	end

	if record.character_id ~= nil and (type(record.character_id) ~= "string" or record.character_id == "") then
		record.character_id = nil
		changed = true
	end

	if not record_has_customization(record) then
		return nil, true
	end

	return record, changed
end

local function flush_persistence(force)
	if not persistence_pending then
		return false
	end

	if not force and persistence_retry_elapsed < 1 then
		return false
	end

	if persistence_attempts >= MAX_PERSISTENCE_ATTEMPTS then
		persistence_pending = false
		persistence_last_outcome = "exhausted"
		return false
	end

	persistence_retry_elapsed = 0
	persistence_attempts = persistence_attempts + 1

	local resolver = rawget(_G, "get_mod")

	if type(resolver) ~= "function" then
		persistence_last_outcome = persistence_attempts >= MAX_PERSISTENCE_ATTEMPTS and "unavailable_exhausted" or "unavailable"
		if persistence_attempts >= MAX_PERSISTENCE_ATTEMPTS then
			persistence_pending = false
		end
		return false
	end

	local ok, dmf = pcall(resolver, "DMF")

	if not ok or type(dmf) ~= "table" or type(dmf.save_unsaved_settings_to_file) ~= "function" then
		persistence_last_outcome = persistence_attempts >= MAX_PERSISTENCE_ATTEMPTS and "unavailable_exhausted" or "unavailable"
		if persistence_attempts >= MAX_PERSISTENCE_ATTEMPTS then
			persistence_pending = false
		end
		return false
	end

	-- One deferred flush batches all edits/deletions performed in the same
	-- frame while reducing the hard-crash loss window from an entire game state
	-- to, normally, a single frame.
	local save_ok, save_result = pcall(dmf.save_unsaved_settings_to_file)

	-- Current DMF releases swallow Application.set_user_setting failures and
	-- return nil. Treat only an explicit true result as durable success; keep
	-- the dirty state otherwise so a later lifecycle/save boundary can retry.
	if save_ok and save_result == true then
		persistence_pending = false
		persistence_last_outcome = "saved"
	elseif save_ok and save_result == nil then
		-- DMF's normal implementation delegates the actual application-setting
		-- write and returns no value. It cannot report durability to us, but the
		-- call itself is the complete obligation BetterInventory owns. Retrying
		-- this path forever causes repeated writes and misleading warnings.
		persistence_pending = false
		persistence_last_outcome = "delegated"
	elseif not save_ok then
		persistence_last_outcome = persistence_attempts >= MAX_PERSISTENCE_ATTEMPTS and "error_exhausted" or "error"
		if persistence_attempts >= MAX_PERSISTENCE_ATTEMPTS then
			persistence_pending = false
		end
	else
		persistence_last_outcome = persistence_attempts >= MAX_PERSISTENCE_ATTEMPTS and "rejected_exhausted" or "rejected"
		if persistence_attempts >= MAX_PERSISTENCE_ATTEMPTS then
			persistence_pending = false
		end
	end

	return save_ok and save_result == true
end

Store.normalize_name = normalize_name
Store.clone_color = clone_color
Store.sanitize_record = sanitize_record
Store.record_has_customization = record_has_customization
Store.default_name_color = DEFAULT_NAME_COLOR
Store.default_background_color = DEFAULT_BACKGROUND_COLOR
Store.max_name_length = MAX_NAME_LENGTH
Store.storage_setting_id = STORAGE_SETTING_ID

Store.records = function(mod)
	return records_for(mod)
end

Store.cache_records = function(records)
	cached_records = type(records) == "table" and records or {}
end

Store.save_records = save_records
Store.mark_persistence_pending = mark_persistence_pending
Store.flush_persistence = flush_persistence

Store.get = function(_, gear_id)
	local record = gear_id and cached_records[gear_id]

	return type(record) == "table" and record or nil
end

Store.update = function(mod, gear_id, changes)
	if type(gear_id) ~= "string" or gear_id == "" or type(changes) ~= "table" then
		return false
	end

	local records = records_for(mod)
	local record = type(records[gear_id]) == "table" and records[gear_id] or {}

	if changes.name ~= nil then
		record.name = normalize_name(changes.name)
		-- name_target only describes names imported from Name It's optional
		-- pattern-name mode. Names entered through BetterInventory always replace
		-- the primary card name and must not inherit stale imported metadata.
		record.name_target = nil
	end

	if type(changes.character_id) == "string" and changes.character_id ~= "" then
		record.character_id = changes.character_id
	end

	if changes.name_color ~= nil then
		record.name_color = changes.name_color ~= false and clone_color(changes.name_color, DEFAULT_NAME_COLOR) or nil
	end

	if changes.background_color ~= nil then
		record.background_color = changes.background_color ~= false and clone_color(changes.background_color, DEFAULT_BACKGROUND_COLOR) or nil

		if changes.background_color == false then
			record.background_preserve_shading = nil
		end
	end

	if changes.background_preserve_shading ~= nil and record.background_color ~= nil then
		record.background_preserve_shading = changes.background_preserve_shading == true
	end

	if record.name == nil and record.name_color == nil and record.background_color == nil and record.background_preserve_shading == nil then
		records[gear_id] = nil
	else
		records[gear_id] = record
	end

	save_records(mod, records)

	return true
end

Store.remove = function(mod, gear_id)
	local records = records_for(mod)

	if gear_id == nil or records[gear_id] == nil then
		return false
	end

	records[gear_id] = nil
	save_records(mod, records)

	return true
end

Store.remove_records = function(mod, gear_ids)
	if type(gear_ids) ~= "table" then
		return 0, {}
	end

	local records = records_for(mod)
	local removed = 0
	local removed_ids = {}

	for gear_id in pairs(gear_ids) do
		if records[gear_id] ~= nil then
			records[gear_id] = nil
			removed = removed + 1
			removed_ids[gear_id] = true
		end
	end

	if removed > 0 then
		save_records(mod, records)
	end

	return removed, removed_ids
end

Store.queue_deleted_gear = function(gear_id)
	if type(gear_id) == "string" and gear_id ~= "" then
		pending_deleted_gear_ids[gear_id] = true
	end
end

Store.has_pending_deleted_gear = function()
	return next(pending_deleted_gear_ids) ~= nil
end

Store.take_pending_deleted_gear_ids = function()
	if next(pending_deleted_gear_ids) == nil then
		return nil
	end

	local gear_ids = pending_deleted_gear_ids

	pending_deleted_gear_ids = {}

	return gear_ids
end

Store.update_runtime = function(mod, dt)
	persistence_retry_elapsed = math.min(1, persistence_retry_elapsed + math.max(tonumber(dt) or 0, 0))
	flush_persistence(false)
end

Store.persistence_status = function()
	return persistence_last_outcome, persistence_pending
end

return Store
