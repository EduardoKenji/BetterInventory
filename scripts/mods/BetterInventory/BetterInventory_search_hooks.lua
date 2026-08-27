local GameCraftingMechanicusBarterItemsView = require("scripts/ui/views/crafting_mechanicus_barter_items_view/crafting_mechanicus_barter_items_view")
local SearchHooks = {}

local function method_available(target, method_name)
	return type(target) == "table" and type(target[method_name]) == "function"
end

SearchHooks.install = function(dependencies)
	dependencies = type(dependencies) == "table" and dependencies or {}
	local mod = dependencies.mod
	local Features = dependencies.Features
	local SearchUI = dependencies.SearchUI
	local ItemGridViewBase = dependencies.ItemGridViewBase
	local BaseView = dependencies.BaseView
	local CraftingMechanicusModifyView = dependencies.CraftingMechanicusModifyView
	local CraftingMechanicusBarterItemsView = dependencies.CraftingMechanicusBarterItemsView or GameCraftingMechanicusBarterItemsView
	local VendorViewBase = dependencies.VendorViewBase
	local ViewElementGrid = dependencies.ViewElementGrid
	local ViewElementInputLegend = dependencies.ViewElementInputLegend

	if type(mod) ~= "table" or type(Features) ~= "table" or type(SearchUI) ~= "table" then
		return false
	end

	if method_available(ItemGridViewBase, "_present_layout_by_slot_filter") then
		mod:hook(ItemGridViewBase, "_present_layout_by_slot_filter", function(func, view, slot_filter, item_type_filter, optional_display_name)
			if type(Features.search_capture_presentation) == "function" then
				Features.search_capture_presentation(mod, view, slot_filter, item_type_filter, optional_display_name)
			end
			if type(SearchUI.sync_query) == "function" then
				SearchUI.sync_query(Features, view)
			end

			return func(view, slot_filter, item_type_filter, optional_display_name)
		end)
	end

	if method_available(ItemGridViewBase, "_filter_by_filter_option") then
		mod:hook(ItemGridViewBase, "_filter_by_filter_option", function(func, view, entry, ...)
			local native_result = func(view, entry, ...)

			if view._better_inventory_search_filter_active and type(Features.search_filter_result) == "function" then
				return Features.search_filter_result(view, entry, native_result)
			end

			return native_result
		end)
	end

	if method_available(ItemGridViewBase, "_cb_on_present") then
		-- Grid presentation replaces widget instances. Reapply dim state once
		-- after new cards exist; no frame-level widget scan required.
		mod:hook_safe(ItemGridViewBase, "_cb_on_present", function(view)
			if view._better_inventory_search_rank_active and type(Features.search_apply_widget_alpha) == "function" then
				Features.search_apply_widget_alpha(view)
			end
		end)
	end

	local function update_search(view, _, time, input_service)
		if type(SearchUI.update) == "function" then
			SearchUI.update(mod, Features, view, time, input_service)
		end
		if view._better_inventory_search_needs_update and type(Features.search_update) == "function" then
			Features.search_update(view, time)
		end
	end

	if method_available(CraftingMechanicusModifyView, "update") then
		mod:hook_safe(CraftingMechanicusModifyView, "update", update_search)
	end

	if method_available(VendorViewBase, "update") then
		mod:hook_safe(VendorViewBase, "update", update_search)
	end

	local function install_view_input_hook(view_class)
		if not method_available(view_class, "_handle_input") then
			return
		end

		mod:hook(view_class, "_handle_input", function(func, view, input_service, ...)
			if type(SearchUI.handle_view_input) == "function" and SearchUI.handle_view_input(mod, view, input_service) then
				return
			end

			return func(view, input_service, ...)
		end)
	end

	install_view_input_hook(CraftingMechanicusModifyView)
	install_view_input_hook(VendorViewBase)
	install_view_input_hook(CraftingMechanicusBarterItemsView)

	if method_available(BaseView, "init") then
		mod:hook(BaseView, "init", function(func, view, definitions, settings, context)
			if view and view.__class_name == "CraftingMechanicusBarterItemsView" and mod:get("enable_inventory_search") ~= false and type(SearchUI.decorate_definitions) == "function" then
				definitions = SearchUI.decorate_definitions(definitions, view, mod)
			end

			return func(view, definitions, settings, context)
		end)
	end

	if method_available(CraftingMechanicusBarterItemsView, "_cb_fetch_inventory_items") then
		mod:hook_safe(CraftingMechanicusBarterItemsView, "_cb_fetch_inventory_items", function(view)
			if mod:get("enable_inventory_search") == false or view._better_inventory_search_grid_shifted or not view._item_grid or type(view._scenegraph_world_position) ~= "function" then
				return
			end

			local position = view:_scenegraph_world_position("item_grid_pivot")
			local x = type(position) == "table" and position[1]
			local y = type(position) == "table" and position[2]

			local grid_offset = type(SearchUI.barter_grid_offset) == "function" and SearchUI.barter_grid_offset() or 100

			if type(x) == "number" and type(y) == "number" and type(grid_offset) == "number" and type(view._item_grid.set_pivot_offset) == "function" then
				view._item_grid:set_pivot_offset(x, y + grid_offset)
				view._better_inventory_search_grid_shifted = true
			end
		end)
	end

	if method_available(CraftingMechanicusBarterItemsView, "_sort_grid_layout") then
		mod:hook(CraftingMechanicusBarterItemsView, "_sort_grid_layout", function(func, view, sort_function, ...)
			local original_callback = view._current_present_grid_layout_callback

			if mod:get("enable_inventory_search") == false or type(original_callback) ~= "function" or type(Features.search_compose_layout) ~= "function" then
				return func(view, sort_function, ...)
			end

			local wrapped_callback = function(callback_view, layout)
				local composed = Features.search_compose_layout(callback_view, layout)

				if type(SearchUI.sync_query) == "function" then
					SearchUI.sync_query(Features, callback_view)
				end

				return original_callback(callback_view, composed)
			end

			view._current_present_grid_layout_callback = wrapped_callback
			local result = func(view, sort_function, ...)

			if view._current_present_grid_layout_callback == wrapped_callback then
				view._current_present_grid_layout_callback = original_callback
			end

			return result
		end)
	end

	if method_available(CraftingMechanicusBarterItemsView, "update") then
		mod:hook_safe(CraftingMechanicusBarterItemsView, "update", update_search)
	end

	if method_available(CraftingMechanicusBarterItemsView, "on_exit") then
		mod:hook_safe(CraftingMechanicusBarterItemsView, "on_exit", function(view)
			if type(SearchUI.release) == "function" then
				SearchUI.release(view)
			end
			if type(Features.search_release) == "function" then
				Features.search_release(view)
			end
			view._better_inventory_search_grid_shifted = nil
		end)
	end

	if method_available(ViewElementInputLegend, "_handle_input") then
		mod:hook(ViewElementInputLegend, "_handle_input", function(func, legend, ...)
			local parent = legend and legend._parent
			local search_input = parent and parent._widgets_by_name and parent._widgets_by_name.better_inventory_search_input
			local search_content = search_input and search_input.content

			if parent and parent._better_inventory_search_block_legend_once then
				parent._better_inventory_search_block_legend_once = nil
				return
			elseif parent and parent._better_inventory_search_controller_focused
				or search_content and search_content.is_writing == true then
				return
			end

			return func(legend, ...)
		end)
	end

	if method_available(ViewElementGrid, "cb_on_grid_entry_left_pressed") then
		mod:hook_safe(ViewElementGrid, "cb_on_grid_entry_left_pressed", function(item_grid)
			if type(SearchUI.defocus) == "function" then
				SearchUI.defocus(item_grid and item_grid._parent)
			end
		end)
	end

	return true
end

return SearchHooks
