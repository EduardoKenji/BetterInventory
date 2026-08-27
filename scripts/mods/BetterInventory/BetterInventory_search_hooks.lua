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
	local CraftingMechanicusModifyView = dependencies.CraftingMechanicusModifyView
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

			if type(Features.search_filter_result) == "function" then
				return Features.search_filter_result(view, entry, native_result)
			end

			return native_result
		end)
	end

	if method_available(ItemGridViewBase, "update") then
		mod:hook_safe(ItemGridViewBase, "update", function(view, _, time, input_service)
			if type(SearchUI.update) == "function" then
				SearchUI.update(mod, Features, view, time, input_service)
			end
			if type(Features.search_update) == "function" then
				Features.search_update(view, time)
			end
		end)
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

	if method_available(ViewElementInputLegend, "_handle_input") then
		mod:hook(ViewElementInputLegend, "_handle_input", function(func, legend, ...)
			local parent = legend and legend._parent

			if parent and parent._better_inventory_search_block_legend_once then
				parent._better_inventory_search_block_legend_once = nil
				return
			elseif type(SearchUI.is_writing) == "function" and SearchUI.is_writing(parent) then
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
