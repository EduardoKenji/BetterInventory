local Adapter = {}

local NAME_IT_OWNS_NAMES_SETTING_ID = "_custom_item_name_it_owns_names"

local function name_it_mod()
	local resolver = rawget(_G, "get_mod")

	if type(resolver) ~= "function" then
		return
	end

	local ok, other_mod = pcall(resolver, "name_it")

	if not ok or type(other_mod) ~= "table" then
		return
	end

	if type(other_mod.is_enabled) == "function" then
		local enabled_ok, enabled = pcall(other_mod.is_enabled, other_mod)

		if enabled_ok and enabled == false then
			return
		end
	end

	return other_mod
end

local function name_it_names()
	local other_mod = name_it_mod()

	if not other_mod then
		return
	end

	local ok, names

	if type(other_mod.get_custom_name_list) == "function" then
		ok, names = pcall(other_mod.get_custom_name_list)
	elseif type(other_mod.get) == "function" then
		ok, names = pcall(other_mod.get, other_mod, "name_list")
	end

	return other_mod, ok and type(names) == "table" and names or nil
end

local function replace_pattern_name(other_mod)
	if not other_mod or type(other_mod.get) ~= "function" then
		return false
	end

	local success, value = pcall(other_mod.get, other_mod, "replace_pattern_name")

	return success and value == true
end

Adapter.is_available = function()
	return name_it_mod() ~= nil
end

Adapter.sync_name = function(gear_id, name)
	local other_mod, names = name_it_names()

	if not other_mod or type(names) ~= "table" or type(other_mod.set) ~= "function" then
		return false
	end

	names[gear_id] = type(name) == "string" and name ~= "" and name or nil
	return pcall(other_mod.set, other_mod, "name_list", names, false)
end

Adapter.remove_names = function(mod, gear_ids, store)
	if type(gear_ids) ~= "table" then
		return false
	end

	local other_mod, names = name_it_names()

	if not other_mod or type(names) ~= "table" then
		return false
	end

	local names_changed = false

	for gear_id in pairs(gear_ids) do
		if names[gear_id] ~= nil then
			names[gear_id] = nil
			names_changed = true
		end
	end

	if names_changed and type(other_mod.set) == "function" then
		pcall(other_mod.set, other_mod, "name_list", names, false)
		store.mark_persistence_pending()
	end

	return names_changed
end

Adapter.import = function(mod, store)
	if mod:get("enable_custom_item_name_and_colors") == false then
		return 0
	end

	local other_mod, names = name_it_names()

	if not other_mod or type(names) ~= "table" then
		return 0
	end

	local records = store.records(mod)
	local imported = 0
	local records_changed = false
	local names_changed = false
	local replace_pattern = replace_pattern_name(other_mod)

	for gear_id, external_name in pairs(names) do
		local raw_external_name = external_name

		external_name = store.normalize_name(external_name)

		if external_name ~= raw_external_name then
			names[gear_id] = external_name
			names_changed = true
		end

		if type(gear_id) == "string" and type(external_name) == "string" and external_name ~= "" then
			local record = type(records[gear_id]) == "table" and records[gear_id] or {}

			if type(record.name) ~= "string" or record.name == "" then
				record.name = external_name
				record.name_target = replace_pattern and "sub" or "primary"
				records[gear_id] = record
				imported = imported + 1
				records_changed = true
			elseif record.name ~= external_name then
				names[gear_id] = record.name
				names_changed = true
			end
		end
	end

	for gear_id, record in pairs(records) do
		local internal_name = type(record) == "table" and record.name

		if type(internal_name) == "string" and internal_name ~= "" and names[gear_id] ~= internal_name then
			names[gear_id] = internal_name
			names_changed = true
		end
	end

	if records_changed then
		store.save_records(mod, records)
	else
		store.cache_records(records)
	end

	if names_changed and type(other_mod.set) == "function" then
		pcall(other_mod.set, other_mod, "name_list", names, false)
		store.mark_persistence_pending()
	end

	return imported
end

Adapter.reconcile = function(mod, store)
	local other_mod, names = name_it_names()

	if not other_mod or type(names) ~= "table" then
		return false
	end

	local records = store.records(mod)
	local replace_pattern = replace_pattern_name(other_mod)
	local names_changed = false

	for gear_id, record in pairs(records) do
		if type(record) == "table" and type(record.name) == "string" then
			local external_name = names[gear_id]

			if type(external_name) ~= "string" or external_name == "" then
				record.name = nil
				record.name_target = nil

				if record.name_color == nil and record.background_color == nil and record.background_preserve_shading == nil then
					records[gear_id] = nil
				end
			end
		end
	end

	for gear_id, external_name in pairs(names) do
		local raw_external_name = external_name

		external_name = store.normalize_name(external_name)

		if external_name ~= raw_external_name then
			names[gear_id] = external_name
			names_changed = true
		end

		if type(gear_id) == "string" and type(external_name) == "string" and external_name ~= "" then
			local record = type(records[gear_id]) == "table" and records[gear_id] or {}

			record.name = external_name
			record.name_target = replace_pattern and "sub" or "primary"
			records[gear_id] = record
		end
	end

	store.save_records(mod, records)

	if names_changed and type(other_mod.set) == "function" then
		pcall(other_mod.set, other_mod, "name_list", names, false)
	end

	mod:set(NAME_IT_OWNS_NAMES_SETTING_ID, false, false)
	store.mark_persistence_pending()

	return true
end

return Adapter
