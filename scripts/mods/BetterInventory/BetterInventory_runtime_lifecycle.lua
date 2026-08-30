local Lifecycle = {}

local dependencies = {}
local generation = {}
local adopted_views = setmetatable({}, {
	__mode = "k",
})

local function clear_owned_widget_callbacks(view)
	local widgets = view and view._widgets_by_name

	if type(widgets) ~= "table" then
		return 0
	end

	local cleared = 0

	for widget_name, widget in pairs(widgets) do
		if type(widget_name) == "string" and string.sub(widget_name, 1, 17) == "better_inventory_" then
			local content = widget and widget.content

			if type(content) == "table" then
				if type(content.pressed_callback) == "function" then
					content.pressed_callback = nil
					cleared = cleared + 1
				end

				for _, value in pairs(content) do
					if type(value) == "table" and type(value.pressed_callback) == "function" then
						value.pressed_callback = nil
						cleared = cleared + 1
					end
				end
			end
		end
	end

	return cleared
end

Lifecycle.configure = function(values)
	dependencies = type(values) == "table" and values or {}
end

Lifecycle.adopt_inventory = function(view, force)
	if not view or view._destroyed or not force and view._better_inventory_runtime_generation == generation then
		return false
	end

	local Features = dependencies.Features

	if type(Features) ~= "table" then
		return false
	end

	view._better_inventory_runtime_generation = generation
	adopted_views[view] = "inventory"
	Features.configure_inventory_sort_options(dependencies.mod, dependencies.Layout, view)
	Features.setup_inventory_options_panel(dependencies.mod, dependencies.Layout, view, dependencies.ViewElementGrid)
	Features.bind_inventory_sort_toggle(dependencies.mod, dependencies.Layout, view)

	return true
end

Lifecycle.adopt_armoury = function(view, family, force)
	if not view or view._destroyed or not force and view._better_inventory_runtime_generation == generation then
		return false
	end

	local Features = dependencies.Features
	local mod = dependencies.mod

	if type(Features) ~= "table" or (family ~= "armoury" and family ~= "global_store") then
		return false
	end
	if family == "global_store" and mod:get("enable_global_store_integration") == false then
		return false
	end

	view._better_inventory_runtime_generation = generation
	adopted_views[view] = "armoury"

	if family == "armoury" then
		Features.configure_armoury_sort_options(mod, view)

		if mod:get("enable_armoury_requisition_grid") ~= false and mod:get("enable_armoury_requisition_sorting_panel") ~= false then
			Features.setup_armoury_native_sort_panel(mod, dependencies.Layout, view, dependencies.ViewElementGrid)
		end
	else
		Features.configure_global_store_sort_options(mod, view)

		if mod:get("enable_global_store_grid") ~= false and mod:get("enable_global_store_sorting_panel") ~= false then
			Features.setup_armoury_native_sort_panel(mod, dependencies.Layout, view, dependencies.ViewElementGrid)
		end
	end

	return true
end

Lifecycle.release_all = function(reason)
	local views = {}

	for view, family in pairs(adopted_views) do
		views[#views + 1] = {
			family = family,
			view = view,
		}
	end

	local Features = dependencies.Features
	local SearchUI = dependencies.SearchUI

	for index = 1, #views do
		local entry = views[index]
		local view = entry.view

		clear_owned_widget_callbacks(view)

		if SearchUI and type(SearchUI.release) == "function" then
			SearchUI.release(view)
		end

		if entry.family == "inventory" and Features and type(Features.unregister_inventory_view) == "function" then
			Features.unregister_inventory_view(view)
		elseif entry.family == "armoury" and Features and type(Features.unregister_armoury_view) == "function" then
			Features.unregister_armoury_view(view)
		end

		view._better_inventory_runtime_generation = nil
		adopted_views[view] = nil
	end

	if SearchUI and type(SearchUI.release_all) == "function" then
		SearchUI.release_all(reason)
	end

	return #views
end

Lifecycle.generation = function()
	return generation
end

return Lifecycle
