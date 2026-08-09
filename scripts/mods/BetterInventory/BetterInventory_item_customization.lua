local ItemCustomization = {}
local storage_hooks_installed = false

local NAME_IT_OWNS_NAMES_SETTING_ID = "_custom_item_name_it_owns_names"

local Store = {}
local host_mod
do
	local resolver = rawget(_G, "get_mod")
	host_mod = type(resolver) == "function" and resolver("BetterInventory") or nil

	if host_mod and type(host_mod.io_dofile) == "function" then
		local ok, loaded = pcall(host_mod.io_dofile, host_mod, "BetterInventory/scripts/mods/BetterInventory/BetterInventory_item_customization_store")

		if ok and type(loaded) == "table" then
			Store = loaded
		end
	end
end

local NameIt = {}

if host_mod and type(host_mod.io_dofile) == "function" then
	local ok, loaded = pcall(host_mod.io_dofile, host_mod, "BetterInventory/scripts/mods/BetterInventory/BetterInventory_item_customization_name_it")

	if ok and type(loaded) == "table" then
		NameIt = loaded
	end
end

local Editor = {}

if host_mod and type(host_mod.io_dofile) == "function" then
	local ok, loaded = pcall(host_mod.io_dofile, host_mod, "BetterInventory/scripts/mods/BetterInventory/BetterInventory_item_customization_editor")

	if ok and type(loaded) == "table" then
		Editor = loaded
	end
end

if type(Editor.configure) == "function" then
	Editor.configure(ItemCustomization, NameIt, Store)
end

local sanitize_record = Store.sanitize_record
local customization_records = Store.records
local mark_persistence_pending = Store.mark_persistence_pending
local save_records = Store.save_records
local flush_persistence = Store.flush_persistence
local STORAGE_SETTING_ID = Store.storage_setting_id

local function name_it_mod()
	return NameIt.is_available and NameIt.is_available() and true or nil
end

local function sync_name_to_name_it(gear_id, name)
	return NameIt.sync_name and NameIt.sync_name(gear_id, name) or false
end

ItemCustomization.get = function(mod, gear_id)
	return Store.get(mod, gear_id)
end

ItemCustomization.update = function(mod, gear_id, changes)
	local updated = Store.update(mod, gear_id, changes)

	if updated and changes.name ~= nil then
		local record = Store.get(mod, gear_id)
		sync_name_to_name_it(gear_id, record and record.name)
	end

	return updated
end

ItemCustomization.remove = function(mod, gear_id)
	local removed = Store.remove(mod, gear_id)

	if removed then
		sync_name_to_name_it(gear_id, nil)
	end

	return removed
end

local function remove_records(mod, gear_ids)
	if type(gear_ids) ~= "table" then
		return 0
	end

	local removed = Store.remove_records(mod, gear_ids)
	NameIt.remove_names(mod, gear_ids, Store)

	return removed
end

local function drain_deleted_records(mod)
	local gear_ids = Store.take_pending_deleted_gear_ids()

	if not gear_ids then
		return 0
	end

	return remove_records(mod, gear_ids)
end

ItemCustomization.import_name_it_names = function(mod)
	return NameIt.import(mod, Store)
end

-- When BetterInventory's editor is disabled, Name It becomes the active name
-- editor. On handoff back to BetterInventory, its complete name table is
-- authoritative: changed/added names are imported and missing names are
-- treated as resets. Color data remains owned solely by BetterInventory.
ItemCustomization.reconcile_from_name_it = function(mod)
	return NameIt.reconcile(mod, Store)
end

ItemCustomization.on_enabled = function(mod)
	local records = customization_records(mod)
	local records_changed = false

	for gear_id, record in pairs(records) do
		local sanitized, changed = sanitize_record(record)

		if type(gear_id) ~= "string" or gear_id == "" or not sanitized then
			records[gear_id] = nil
			records_changed = true
		elseif changed then
			records[gear_id] = sanitized
			records_changed = true
		end
	end

	Store.cache_records(records)

	if type(mod:get(STORAGE_SETTING_ID)) ~= "table" or records_changed then
		save_records(mod, records)
	end

	-- on_all_mods_loaded is not guaranteed to run when a user re-enables the
	-- whole mod from Toggle Mods. Complete an ownership handoff here as well.
	if mod:get("enable_custom_item_name_and_colors") ~= false and mod:get(NAME_IT_OWNS_NAMES_SETTING_ID) == true then
		if not ItemCustomization.reconcile_from_name_it(mod) then
			mod:set(NAME_IT_OWNS_NAMES_SETTING_ID, false, false)
			mark_persistence_pending()
		end
	end
end

ItemCustomization.on_disabled = function(mod)
	Editor.clear_pending()
	Editor.close_input(mod)

	if NameIt.is_available() then
		mod:set(NAME_IT_OWNS_NAMES_SETTING_ID, true, false)
		mark_persistence_pending()
	end

	drain_deleted_records(mod)
	flush_persistence(true)

	-- DMF disables every hook before calling on_disabled. Keep only storage
	-- cleanup alive so discarded gear cannot become orphaned while the visual
	-- mod is toggled off.
	if type(mod.hook_enable) == "function" then
		mod:hook_enable("GearService", "on_gear_deleted")
		mod:hook_enable("GearService", "on_character_deleted")
	end
end

ItemCustomization.on_all_mods_loaded = function(mod)
	if mod:get("enable_custom_item_name_and_colors") == false then
		if NameIt.is_available() then
			mod:set(NAME_IT_OWNS_NAMES_SETTING_ID, true, false)
			mark_persistence_pending()
		end

		return false
	end

	if mod:get(NAME_IT_OWNS_NAMES_SETTING_ID) == true then
		if ItemCustomization.reconcile_from_name_it(mod) then
			return true
		end

		-- Name It was removed or disabled before the handoff completed. Resume
		-- BetterInventory ownership without leaving a stale future migration armed.
		mod:set(NAME_IT_OWNS_NAMES_SETTING_ID, false, false)
		mark_persistence_pending()
	end

	return ItemCustomization.import_name_it_names(mod)
end

ItemCustomization.on_setting_changed = function(mod, setting_id)
	if setting_id == "enable_custom_item_name_and_colors" then
		if mod:get(setting_id) == false then
			if NameIt.is_available() then
				mod:set(NAME_IT_OWNS_NAMES_SETTING_ID, true, false)
				mark_persistence_pending()
			end

			return false
		end

		if mod:get(NAME_IT_OWNS_NAMES_SETTING_ID) == true then
			if ItemCustomization.reconcile_from_name_it(mod) then
				return true
			end

			mod:set(NAME_IT_OWNS_NAMES_SETTING_ID, false, false)
			mark_persistence_pending()
		end

		return ItemCustomization.import_name_it_names(mod)
	end

	return false
end

ItemCustomization.update_runtime = function(mod, dt)
	Editor.run_pending()
	drain_deleted_records(mod)

	local _, persistence_pending = Store.persistence_status()

	if persistence_pending then
		Store.update_runtime(mod, dt)
	end
end

ItemCustomization.persistence_status = function()
	return Store.persistence_status()
end


local function install_storage_hooks(mod)
	if storage_hooks_installed then
		return
	end

	storage_hooks_installed = true

	mod:hook_safe("GearService", "on_gear_deleted", function(_, gear_id)
		if type(mod.is_enabled) == "function" and not mod:is_enabled() then
			remove_records(mod, { [gear_id] = true })
			flush_persistence()
		else
			Store.queue_deleted_gear(gear_id)
		end
	end)

	mod:hook("GearService", "on_character_deleted", function(func, gear_service, character_id, ...)
		local gear_ids = {}
		local records = customization_records(mod)

		for gear_id, record in pairs(records) do
			if type(record) == "table" and record.character_id == character_id then
				gear_ids[gear_id] = true
			end
		end

		-- Backfill coverage for records created before character ownership was
		-- stored, whenever Darktide still has the deleted character's gear cached.
		for gear_id, gear in pairs(gear_service._cached_gear_list or {}) do
			if gear and (gear.characterId == character_id or gear.character_id == character_id) then
				gear_ids[gear_id] = true
			end
		end

		local result = func(gear_service, character_id, ...)

		remove_records(mod, gear_ids)

		if type(mod.is_enabled) == "function" and not mod:is_enabled() then
			flush_persistence()
		end

		return result
	end)

end

	ItemCustomization.install = function(mod, InventoryWeaponsView, layout)
	local installed = Editor.install(mod, InventoryWeaponsView, layout)

	if installed then
		install_storage_hooks(mod)
	end

	return installed
end

ItemCustomization.show_color_picker = function(mod, target, context, layout)
	return Editor.show_color_picker(mod, target, context, layout)
end

ItemCustomization.show_name_editor = function(mod, context, layout)
	return Editor.show_name_editor(mod, context, layout)
end

return ItemCustomization
