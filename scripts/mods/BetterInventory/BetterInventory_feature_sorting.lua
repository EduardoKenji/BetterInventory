local Sorting = {}

local integration_mod
local definitions
local invalidate_view = function() end

local INVENTORY_VANILLA_SETTINGS = {
	"enable_vanilla_level_desc",
	"enable_vanilla_level_asc",
	"enable_vanilla_rarity_desc",
	"enable_vanilla_rarity_asc",
	"enable_vanilla_name_asc",
	"enable_vanilla_name_desc",
}

local STORE_VANILLA_SETTINGS = {
	"enable_vanilla_level_desc",
	"enable_vanilla_level_asc",
	"enable_vanilla_rarity_desc",
	"enable_vanilla_rarity_asc",
	"enable_vanilla_price_asc",
	"enable_vanilla_price_desc",
	"enable_vanilla_name_asc",
	"enable_vanilla_name_desc",
}

Sorting.set_invalidation = function(callback)
	invalidate_view = type(callback) == "function" and callback or function() end
end

Sorting.mod = function()
	return integration_mod
end

Sorting.definitions = function()
	return definitions
end

Sorting.is_enabled = function()
	if not integration_mod then
		return false
	end

	if type(integration_mod.is_enabled) ~= "function" then
		return true
	end

	local success, enabled = pcall(integration_mod.is_enabled, integration_mod)

	return success and enabled == true
end

Sorting.set_integration = function(new_integration_mod, callback)
	invalidate_view = type(callback) == "function" and callback or invalidate_view
	integration_mod = type(new_integration_mod) == "table" and new_integration_mod or nil
	definitions = nil
	invalidate_view()

	if integration_mod and type(integration_mod.io_dofile) == "function" then
		local success, loaded_definitions = pcall(integration_mod.io_dofile, integration_mod, "ItemSorting/scripts/mods/ItemSorting/ItemSorting_definitions")

		if success and type(loaded_definitions) == "table" then
			definitions = loaded_definitions
		end
	end

	return Sorting.is_enabled()
end

Sorting.native_option_start = function(view, is_store_view)
	local sort_options = view and view._sort_options or {}

	if not Sorting.is_enabled() or not integration_mod or type(integration_mod.get) ~= "function" then
		return #sort_options + 1
	end

	local view_type = type(is_store_view) == "function" and is_store_view(view) and "store" or "inventory"
	local definition_group = definitions and definitions.customized_vanilla_methods
	local vanilla_definitions = definition_group and definition_group[view_type]

	if type(vanilla_definitions) == "table" then
		return math.min(#vanilla_definitions + 1, #sort_options + 1)
	end

	local setting_ids = view_type == "store" and STORE_VANILLA_SETTINGS or INVENTORY_VANILLA_SETTINGS
	local native_count = 0

	for index = 1, #setting_ids do
		local success, enabled = pcall(integration_mod.get, integration_mod, setting_ids[index])

		if success and enabled == true then
			native_count = native_count + 1
		end
	end

	return math.min(native_count + 1, #sort_options + 1)
end

Sorting.preserve_native_options = function(view, selected_display_name, is_store_view, callback)
	if not Sorting.is_enabled() or type(definitions) ~= "table" or not view then
		return false
	end

	local view_type = type(is_store_view) == "function" and is_store_view(view) and "store" or view.__class_name == "InventoryWeaponsView" and "inventory" or nil
	local vanilla_group = definitions.customized_vanilla_methods
	local custom_group = definitions.modded_methods
	local vanilla_definitions = view_type and vanilla_group and vanilla_group[view_type]
	local custom_definitions = view_type and custom_group and custom_group[view_type]

	if type(vanilla_definitions) ~= "table" or type(custom_definitions) ~= "table" then
		return false
	end

	local options = {}
	local function append_option(definition)
		if type(definition) == "table" and type(definition.sort_function) == "function" then
			options[#options + 1] = {
				display_name = definition.display_name,
				sort_function = definition.sort_function,
			}
		end
	end

	for index = 1, #vanilla_definitions do
		append_option(vanilla_definitions[index])
	end

	for index = 1, #custom_definitions do
		append_option(custom_definitions[index])
	end

	view._sort_options = options
	view._better_inventory_item_sorting_signature_cache = nil
	view._better_inventory_item_sorting_signature_poll = 0
	local invalidate = type(callback) == "function" and callback or invalidate_view
	invalidate(view)
	local selected_index = 1

	if selected_display_name ~= nil then
		for index = 1, #options do
			if options[index].display_name == selected_display_name then
				selected_index = index
				break
			end
		end
	end

	view._selected_sort_option_index = selected_index
	view._selected_sort_option = options[selected_index]

	local item_grid = view._item_grid

	if item_grid and type(item_grid.setup_sort_button) == "function" and type(view.cb_on_sort_button_pressed) == "function" then
		item_grid:setup_sort_button(options, function(...)
			return view:cb_on_sort_button_pressed(...)
		end)
	end

	return true
end

return Sorting
