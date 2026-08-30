local Lifecycle = {}

local dependencies = {}
local generation = {}
local adopted_views = setmetatable({}, {
	__mode = "k",
})
local managed_grids = setmetatable({}, {
	__mode = "k",
})
local unpack_values = table.unpack or unpack

local function pack_values(...)
	return {
		n = select("#", ...),
		...,
	}
end

local function invalidate_layout_entry_ids(layout)
	if type(layout) ~= "table" then
		return nil
	end

	for index = 1, #layout do
		local entry = layout[index]

		if type(entry) == "table" then
			entry.entry_id = nil
		end
	end

	return layout
end

local function invalidate_grid_entry_ids(item_grid)
	return invalidate_layout_entry_ids(item_grid and item_grid._grid_layout)
end

local function present_current_grid(view, layout)
	if type(view) ~= "table" or type(view.present_grid_layout) ~= "function" or type(layout) ~= "table" then
		return false
	end

	local on_present_callback

	if type(view._cb_on_present) == "function" then
		on_present_callback = function()
			if view._destroyed ~= true then
				view:_cb_on_present()
			end
		end
	end

	return pcall(view.present_grid_layout, view, layout, on_present_callback)
end

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

Lifecycle.mark_managed_grid = function(item_grid)
	if type(item_grid) ~= "table" then
		return false
	end

	item_grid._better_inventory_card_runtime_generation = generation
	item_grid._better_inventory_card_rebuild_pending = nil
	managed_grids[item_grid] = true

	return true
end

Lifecycle.prepare_grid_presentation = function(item_grid, layout)
	if type(item_grid) ~= "table" then
		return false
	end

	local previous_generation = item_grid._better_inventory_card_runtime_generation

	if previous_generation == generation then
		return false
	end
	if previous_generation == nil and (type(item_grid._grid_layout) ~= "table" or next(item_grid._grid_layout) == nil) then
		return false
	end

	local target_layout = type(layout) == "table" and layout or item_grid._grid_layout

	if not invalidate_layout_entry_ids(target_layout) then
		return false
	end

	item_grid._better_inventory_card_rebuild_pending = generation

	return true
end

Lifecycle.grid_layout_requires_generation = function(item_grid, layout)
	local current_layout = item_grid and item_grid._grid_layout

	if type(current_layout) == "table" and next(current_layout) ~= nil and type(layout) == "table" then
		local widgets = item_grid._widgets_by_entry_id

		for index = 1, #layout do
			local entry_id = layout[index] and layout[index].entry_id

			if entry_id == nil or type(widgets) ~= "table" or widgets[entry_id] == nil then
				return true
			end
		end

		return false
	end

	return layout ~= nil
end

Lifecycle.prepare_grid_generation = function(item_grid, layout)
	Lifecycle.prepare_grid_presentation(item_grid, layout)

	return Lifecycle.grid_layout_requires_generation(item_grid, layout)
end

Lifecycle.present_reused_grid = function(func, item_grid, layout, content_blueprints, callback_arguments, after_present)
	local results = pack_values(func(
		item_grid,
		layout,
		content_blueprints,
		unpack_values(callback_arguments, 1, callback_arguments.n)
	))

	if after_present then
		after_present(item_grid)
	end

	return results
end

Lifecycle.compact_curio_stats_blueprints = function(mod, Features, item_grid, content_blueprints)
	local height = tonumber(mod and mod:get("curio_preview_height_percent")) or 76
	height = math.max(60, math.min(100, height))
	local header = type(content_blueprints) == "table" and content_blueprints.gadget_header
	local cached = item_grid and item_grid._better_inventory_compact_curio_blueprints

	if cached and cached.source == content_blueprints and cached.header == header and cached.height == height then
		return cached.blueprints
	end

	local blueprints = Features.compact_inventory_curio_stats_blueprints(mod, item_grid, content_blueprints)

	if type(item_grid) == "table" and blueprints ~= content_blueprints then
		item_grid._better_inventory_compact_curio_blueprints = {
			blueprints = blueprints,
			header = header,
			height = height,
			source = content_blueprints,
		}
	end

	return blueprints
end

Lifecycle.release_compact_curio_stats_blueprints = function(view_or_grid)
	local item_grid = view_or_grid and (view_or_grid._weapon_stats or view_or_grid)
	local released = type(item_grid) == "table" and item_grid._better_inventory_compact_curio_blueprints ~= nil

	if type(item_grid) == "table" then
		item_grid._better_inventory_compact_curio_blueprints = nil
	end

	return released
end

Lifecycle.adopt_managed_grid = function(view)
	if type(view) ~= "table" or view._destroyed == true then
		return false
	end

	local item_grid = view._item_grid
	local previous_generation = item_grid and item_grid._better_inventory_card_runtime_generation

	if not item_grid or previous_generation == generation or item_grid._better_inventory_card_rebuild_pending == generation then
		return false
	end
	if previous_generation == nil and (type(item_grid._grid_layout) ~= "table" or next(item_grid._grid_layout) == nil) then
		return false
	end

	local layout = invalidate_grid_entry_ids(item_grid)

	if not layout then
		return false
	end

	item_grid._better_inventory_card_rebuild_pending = generation
	local present_ok = present_current_grid(view, layout)

	if not present_ok then
		item_grid._better_inventory_card_rebuild_pending = nil
	end

	return present_ok
end

Lifecycle.adopt_inventory = function(view, force)
	local grid_adopted = Lifecycle.adopt_managed_grid(view)

	if not view or view._destroyed or not force and view._better_inventory_runtime_generation == generation then
		return grid_adopted
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
	local grid_adopted = Lifecycle.adopt_managed_grid(view)

	if not view or view._destroyed or not force and view._better_inventory_runtime_generation == generation then
		return grid_adopted
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

	for item_grid in pairs(managed_grids) do
		if item_grid._better_inventory_card_runtime_generation == generation then
			-- A drawn ViewElementGrid defers presentation by storing one callback.
			-- That callback closes over the complete configured blueprint generation.
			-- Cancel it at DMF unload; the surviving view is adopted below by the new
			-- generation and presents its current layout once with fresh blueprints.
			item_grid._present_grid_layout = nil
			item_grid._better_inventory_card_rebuild_pending = nil
		end

		managed_grids[item_grid] = nil
	end

	for index = 1, #views do
		local entry = views[index]
		local view = entry.view

		clear_owned_widget_callbacks(view)
		Lifecycle.release_compact_curio_stats_blueprints(view)

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
