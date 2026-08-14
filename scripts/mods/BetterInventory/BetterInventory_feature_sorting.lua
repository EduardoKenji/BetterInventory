local Items = require("scripts/utilities/items")
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

-- Comparator lifecycle belongs to the sorting domain. The facade supplies
-- feature-specific predicates and session callbacks, but this module owns
-- wrapper identity, external replacement detection, weak registration, and
-- restoration.
Sorting.new_comparator_manager = function(dependencies)
	local manager = {}
	local EQUIPPED_FAVORITE_PRIORITY_OFFSET = 3
	local registered_views = setmetatable({}, {
		__mode = "k",
	})

	manager.registered_views = registered_views

	local function is_armoury_sort_view(view)
		return dependencies.is_armoury_sort_view(view)
	end

	local function item_priority(view, layout_entry)
		local item = layout_entry and (layout_entry.real_item or layout_entry.item)

		if not item then
			return 0
		end

		local slots = item.slots
		local equipped = false

		if slots then
			local equipped_ok, equipped_value = dependencies.contracts.safe_method(view, "is_item_equipped_in_any_slot", item, slots)
			equipped = equipped_ok and equipped_value == true
		end

		if equipped then
			return 2
		end

		if item.gear_id and type(Items.is_item_id_favorited) == "function" then
			local favorite_ok, favorite_value = dependencies.contracts.safe_call(Items.is_item_id_favorited, item.gear_id)

			if favorite_ok and favorite_value == true then
				return 1
			end
		end

		return 0
	end

	local function inventory_sort_priority(mod, view, layout_entry)
		local priority_cache = view and view._better_inventory_sort_priority_cache
		local cached_priority = priority_cache and priority_cache[layout_entry]

		if cached_priority ~= nil then
			return cached_priority
		end

		local item = layout_entry and (layout_entry.real_item or layout_entry.item)

		if not item then
			return 0
		end

		local priority = 0

		if mod:get("prioritize_equipped_favorites") ~= false then
			local equipped_favorite_priority = item_priority(view, layout_entry)

			if equipped_favorite_priority > 0 then
				priority = equipped_favorite_priority + EQUIPPED_FAVORITE_PRIORITY_OFFSET
			end
		end

		if priority == 0 and mod:get("prioritize_perfect_roll_weapons") == true then
			local dump_stat_value = dependencies.perfect_roll_dump_stat_value(item)

			if dump_stat_value then
				-- Backend fractions can produce visible 61/62 dump stats on a
				-- 380-total four-at-80 roll. Keep every such weapon in the perfect
				-- group while ordering the anomalous higher values before 60.
				priority = math.clamp(math.floor(dump_stat_value) - 59, 1, 3)
			end
		end

		if priority_cache then
			priority_cache[layout_entry] = priority
		end

		return priority
	end

	local function reset_priority_cache(view)
		view._better_inventory_sort_priority_cache = setmetatable({}, {
			__mode = "k",
		})
	end

	manager.configure = function(mod, view)
		local sort_options = view and view._sort_options

		if type(sort_options) ~= "table" then
			return
		end

		local session_kind = is_armoury_sort_view(view) and "armoury" or "inventory"
		dependencies.begin_view_session(view, session_kind)
		dependencies.register_view_session_cleanup(view, "sort_options", function(session_view)
			manager.restore(session_view)
		end)

		registered_views[view] = true
		-- Native table.sort invokes the comparator O(n log n) times. Resolve each
		-- item's equipped/favorite/perfect-roll state once per sort generation.
		reset_priority_cache(view)

		for index = 1, #sort_options do
			local option = sort_options[index]
			local wrapped_sort = option and option._better_inventory_wrapped_sort

			if option and option._better_inventory_original_sort and option.sort_function ~= wrapped_sort then
				-- Another integration replaced the comparator after BetterInventory
				-- wrapped it. Treat that comparator as the new native baseline.
				option._better_inventory_original_sort = nil
				option._better_inventory_wrapped_sort = nil
			end

			local original_sort = option and option.sort_function

			if type(original_sort) == "function" and not option._better_inventory_original_sort then
				option._better_inventory_original_sort = original_sort
				local better_inventory_sort = function(left, right)
					local left_priority = inventory_sort_priority(mod, view, left)
					local right_priority = inventory_sort_priority(mod, view, right)

					if left_priority ~= right_priority then
						return left_priority > right_priority
					end

					return original_sort(left, right)
				end
				option._better_inventory_wrapped_sort = better_inventory_sort
				option.sort_function = better_inventory_sort
			end
		end
	end

	manager.restore = function(view)
		if view then
			view._better_inventory_sort_priority_cache = nil
		end

		local sort_options = view and view._sort_options

		if type(sort_options) ~= "table" then
			return
		end

		for index = 1, #sort_options do
			local option = sort_options[index]
			local original_sort = option and option._better_inventory_original_sort
			local wrapped_sort = option and option._better_inventory_wrapped_sort

			if option and type(original_sort) == "function" and option.sort_function == wrapped_sort then
				option.sort_function = original_sort
			end

			if option then
				option._better_inventory_original_sort = nil
				option._better_inventory_wrapped_sort = nil
			end
		end
	end

	manager.configure_inventory = function(mod, layout, view)
		if dependencies.is_inventory_view(layout, view) then
			manager.configure(mod, view)
		end
	end

	manager.configure_armoury = function(mod, view)
		if dependencies.is_armoury_requisition_view(view) then
			manager.configure(mod, view)
		end
	end

	manager.configure_global_store = function(mod, view)
		if dependencies.is_global_store_view(view) then
			manager.configure(mod, view)
		end
	end

	manager.rebind = function(mod, layout)
		for view in pairs(registered_views) do
			if view._destroyed then
				registered_views[view] = nil
			elseif (layout and dependencies.is_inventory_view(layout, view)) or is_armoury_sort_view(view) then
				manager.configure(mod, view)
			end
		end
	end

	manager.resort = function(mod, layout, view)
		if not dependencies.is_sortable_view(layout, view) or view._destroyed or type(view._sort_grid_layout) ~= "function" then
			return
		end

		-- The native discard view temporarily presents a filtered copy of the
		-- inventory. Let Darktide restore/sort the full layout when it closes.
		if view._discard_items_element then
			return
		end

		local sort_options = view._sort_options
		local option = sort_options and (view._selected_sort_option or sort_options[view._selected_sort_option_index or 1])
		local sort_function = option and option.sort_function

		if sort_function then
			reset_priority_cache(view)
			view:_sort_grid_layout(sort_function)
		end
	end

	return manager
end

return Sorting
