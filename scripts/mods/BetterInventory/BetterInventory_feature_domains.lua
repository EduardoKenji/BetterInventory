local Domains = {}

Domains.grid_scope = {}

local OWNED_GRID_VIEW_CLASSES = {
	CraftingMechanicusBarterItemsView = true,
	CraftingMechanicusModifyView = true,
	CreditsGoodsVendorView = true,
	CreditsVendorView = true,
	InventoryWeaponsView = true,
	MarksGoodsVendorView = true,
	MarksVendorView = true,
}

Domains.grid_scope.supported = function(view)
	return type(view) == "table"
		and view._destroyed ~= true
		and OWNED_GRID_VIEW_CLASSES[view.__class_name] == true
end

Domains.grid_scope.resolve = function(item_grid, configured_view, configured_configuration)
	if configured_view and item_grid == configured_view._item_grid
		and Domains.grid_scope.supported(configured_view) then
		return configured_view, configured_configuration
	end

	local parent = item_grid and item_grid._parent

	if Domains.grid_scope.supported(parent) then
		return parent, nil
	end

	return nil, nil
end

Domains.markers = {}

local tracked_marker_grids = setmetatable({}, { __mode = "k" })
local dirty_marker_grids = setmetatable({}, { __mode = "k" })
local marker_poll_elapsed = 0
local MARKER_POLL_INTERVAL = 1

Domains.markers.next_generation = function(current_generation)
	return (tonumber(current_generation) or 0) + 1
end

Domains.markers.invalidate_grid = function(item_grid)
	if not item_grid or item_grid._better_inventory_myfavorites_active ~= true then
		return false
	end

	tracked_marker_grids[item_grid] = true
	dirty_marker_grids[item_grid] = true
	item_grid._better_inventory_myfavorites_dirty = true
	item_grid._better_inventory_myfavorites_generation = Domains.markers.next_generation(item_grid._better_inventory_myfavorites_generation)

	return true
end

Domains.markers.track_grid = function(item_grid)
	if not item_grid or item_grid._better_inventory_myfavorites_active ~= true then
		return false
	end

	tracked_marker_grids[item_grid] = true

	return true
end

-- A destructive ViewElementGrid presentation retires every current widget at
-- once. Replace the weak marker set before the new generation is created so a
-- third-party asynchronous callback cannot make reconciliation walk retired
-- cards until Lua's next collection cycle.
Domains.markers.begin_grid_generation = function(item_grid)
	if not item_grid or item_grid._better_inventory_myfavorites_active ~= true then
		return false
	end

	item_grid._better_inventory_myfavorites_widgets = setmetatable({}, { __mode = "k" })
	item_grid._better_inventory_myfavorites_dirty = true
	dirty_marker_grids[item_grid] = true
	tracked_marker_grids[item_grid] = true
	item_grid._better_inventory_myfavorites_generation = Domains.markers.next_generation(item_grid._better_inventory_myfavorites_generation)

	return true
end

Domains.markers.release_grid = function(item_grid)
	if not item_grid then
		return false
	end

	local tracked = tracked_marker_grids[item_grid] ~= nil or dirty_marker_grids[item_grid] ~= nil or item_grid._better_inventory_myfavorites_active == true

	tracked_marker_grids[item_grid] = nil
	dirty_marker_grids[item_grid] = nil
	item_grid._better_inventory_myfavorites_active = nil
	item_grid._better_inventory_myfavorites_dirty = nil
	item_grid._better_inventory_myfavorites_generation = nil
	item_grid._better_inventory_myfavorites_native_generation = nil
	item_grid._better_inventory_myfavorites_widgets = nil

	return tracked
end

Domains.markers.release_all = function()
	local grids = {}

	for item_grid in pairs(tracked_marker_grids) do
		grids[#grids + 1] = item_grid
	end

	for item_grid in pairs(dirty_marker_grids) do
		if tracked_marker_grids[item_grid] == nil then
			grids[#grids + 1] = item_grid
		end
	end

	for index = 1, #grids do
		Domains.markers.release_grid(grids[index])
	end

	marker_poll_elapsed = 0

	return #grids
end

Domains.markers.count = function()
	local tracked = 0
	local dirty = 0

	for _ in pairs(tracked_marker_grids) do
		tracked = tracked + 1
	end

	for _ in pairs(dirty_marker_grids) do
		dirty = dirty + 1
	end

	return tracked, dirty
end

local function poll_marker_grids()
	for item_grid in pairs(tracked_marker_grids) do
		if item_grid._better_inventory_myfavorites_active ~= true then
			Domains.markers.release_grid(item_grid)
		else
			local native_generation = item_grid._grid_generation or item_grid._layout_generation or item_grid._content_generation
			local previous_native_generation = item_grid._better_inventory_myfavorites_native_generation

			if native_generation ~= nil then
				if native_generation ~= previous_native_generation then
					item_grid._better_inventory_myfavorites_native_generation = native_generation
					item_grid._better_inventory_myfavorites_dirty = true
					dirty_marker_grids[item_grid] = true
				end
			else
				-- Older Darktide builds expose no grid generation. Preserve the old
				-- one-second fallback without wrapping every native grid update.
				item_grid._better_inventory_myfavorites_dirty = true
				dirty_marker_grids[item_grid] = true
			end
		end
	end
end

Domains.markers.update = function(dt, synchronize_grid)
	marker_poll_elapsed = marker_poll_elapsed + math.max(tonumber(dt) or 0, 0)

	if marker_poll_elapsed >= MARKER_POLL_INTERVAL then
		marker_poll_elapsed = marker_poll_elapsed % MARKER_POLL_INTERVAL
		poll_marker_grids()
	end

	if next(dirty_marker_grids) == nil then
		return 0
	end

	local refreshed = 0

	for item_grid in pairs(dirty_marker_grids) do
		if item_grid._better_inventory_myfavorites_active ~= true then
			Domains.markers.release_grid(item_grid)
		elseif item_grid._visible ~= false then
			local tracked_widgets = item_grid._better_inventory_myfavorites_widgets

			if not tracked_widgets or next(tracked_widgets) == nil then
				item_grid._better_inventory_myfavorites_dirty = false
				dirty_marker_grids[item_grid] = nil
			elseif type(synchronize_grid) == "function" then
				synchronize_grid(item_grid, tracked_widgets)
				item_grid._better_inventory_myfavorites_dirty = false
				dirty_marker_grids[item_grid] = nil
				refreshed = refreshed + 1
			end
		end
	end

	return refreshed
end

Domains.markers.needs_update = function()
	return next(tracked_marker_grids) ~= nil or next(dirty_marker_grids) ~= nil
end

Domains.markers.needs_refresh = function(last_generation, current_generation, dirty)
	return dirty == true or (tonumber(last_generation) or 0) ~= (tonumber(current_generation) or 0)
end

Domains.global_store = {}

-- Mirror Darktide's ViewElementGrid rebuild decision. Incoming entries without
-- a live entry_id force native code to destroy all current widgets; disjoint
-- GlobalStore category tabs normally take this path.
Domains.global_store.grid_rebuild_required = function(item_grid, layout)
	if type(item_grid) ~= "table" or type(layout) ~= "table" then
		return false
	end

	local current_layout = item_grid._grid_layout

	if type(current_layout) ~= "table" or next(current_layout) == nil then
		return true
	end

	local widgets_by_entry_id = item_grid._widgets_by_entry_id

	for index = 1, #layout do
		local entry = layout[index]
		local entry_id = type(entry) == "table" and entry.entry_id

		if not entry_id or type(widgets_by_entry_id) ~= "table" or widgets_by_entry_id[entry_id] == nil then
			return true
		end
	end

	return false
end

-- GlobalStore 1.x attaches an asynchronous profile-portrait load to each card
-- but unloads it only when the final Credits/Marks vendor view is destroyed.
-- Category switches destroy the card widgets first, losing those IDs while
-- their callbacks retain the old widgets. Retire only the outgoing generation,
-- immediately before Darktide's own destructive presentation, and leave
-- in-place search reorders untouched.
Domains.global_store.retire_grid_generation = function(item_grid, layout, ui_manager)
	if not Domains.global_store.grid_rebuild_required(item_grid, layout) then
		return 0, false
	end

	local widgets = item_grid._all_grid_widgets or item_grid._grid_widgets
	local unload_portrait = ui_manager and ui_manager.unload_profile_portrait
	local released = 0

	if type(unload_portrait) == "function" then
		for index = 1, #(widgets or {}) do
			local widget = widgets[index]
			local content = widget and widget.content
			local load_id = content and content.portrait_load_id

			if load_id ~= nil then
				-- Clear ownership before invoking the external manager. Its unload
				-- callback may synchronously revisit the widget.
				content.portrait_load_id = nil
				local ok = pcall(unload_portrait, ui_manager, load_id)

				if ok then
					released = released + 1
				else
					-- Preserve the ID if the service rejected the call so GlobalStore's
					-- normal destroy fallback can still retry it.
					content.portrait_load_id = load_id
				end
			end
		end
	end

	Domains.markers.begin_grid_generation(item_grid)

	return released, true
end

Domains.quick_level_alignment = {}

local QUICK_LEVEL_ALIGNMENT_PROBE_INTERVAL = 15
local VENDOR_ACTION_ROW_GAP = 8

local function live_weapon_panel_height(weapon_stats)
	local scenegraph = weapon_stats and weapon_stats._ui_scenegraph
	local background = scenegraph and scenegraph.grid_background
	local size = background and background.size

	return tonumber(size and size[2])
end

Domains.quick_level_alignment.update = function(view, count_diagnostic, god_stat_checker_active)
	local widgets_by_name = view and view._widgets_by_name
	local ui_scenegraph = view and view._ui_scenegraph
	local purchase_button = ui_scenegraph and ui_scenegraph.purchase_button
	local sacrifice_button = widgets_by_name and widgets_by_name.quick_sacrifice_button
	local weapon_stats = view and view._weapon_stats
	local probe = view and view._better_inventory_quick_level_alignment_probe
	local gsc_active = god_stat_checker_active == true

	if (not sacrifice_button and not gsc_active and not probe)
		or not purchase_button or not purchase_button.position or not purchase_button.size
		or not weapon_stats or type(weapon_stats.scenegraph_world_position) ~= "function"
		or type(weapon_stats._scenegraph_size) ~= "function"
		or type(view._scenegraph_world_position) ~= "function"
		or type(view._set_scenegraph_position) ~= "function" then
		return false
	end

	local position = purchase_button.position
	local purchase_width = tonumber(purchase_button.size[1])
	local purchase_height = tonumber(purchase_button.size[2])
	local purchase_widget = widgets_by_name and widgets_by_name.purchase_button
	local purchase_offset = purchase_widget and purchase_widget.offset and tonumber(purchase_widget.offset[1]) or 0
	local sacrifice_offset_input = sacrifice_button and sacrifice_button.offset and tonumber(sacrifice_button.offset[1])
	local weapon_stats_pivot = weapon_stats._pivot_offset
	local weapon_stats_pivot_x = weapon_stats_pivot and tonumber(weapon_stats_pivot[1])
	local weapon_stats_pivot_y = weapon_stats_pivot and tonumber(weapon_stats_pivot[2])
	local panel_height_input = live_weapon_panel_height(weapon_stats)
	local probe_count = (probe and probe.count or QUICK_LEVEL_ALIGNMENT_PROBE_INTERVAL) + 1
	local probe_due = probe_count >= QUICK_LEVEL_ALIGNMENT_PROBE_INTERVAL
	local inputs_changed = not probe
		or probe.purchase_button ~= purchase_button
		or probe.sacrifice_button ~= sacrifice_button
		or probe.weapon_stats ~= weapon_stats
		or probe.gsc_active ~= gsc_active
		or probe.purchase_x ~= position[1]
		or probe.purchase_y ~= position[2]
		or probe.purchase_width ~= purchase_width
		or probe.purchase_height ~= purchase_height
		or probe.purchase_offset ~= purchase_offset
		or probe.sacrifice_offset_input ~= sacrifice_offset_input
		or probe.weapon_stats_pivot_x ~= weapon_stats_pivot_x
		or probe.weapon_stats_pivot_y ~= weapon_stats_pivot_y
		or probe.panel_height_input ~= panel_height_input

	if not inputs_changed and not probe_due then
		probe.count = probe_count

		return false
	end

	if not probe then
		probe = {}
		view._better_inventory_quick_level_alignment_probe = probe
	end

	probe.count = 0

	if type(weapon_stats._force_update_scenegraph) == "function" then
		pcall(weapon_stats._force_update_scenegraph, weapon_stats)
	end

	if type(count_diagnostic) == "function" then
		count_diagnostic("alignment_queries")
	end

	local purchase_world_position = view:_scenegraph_world_position("purchase_button")
	local weapon_stats_world_position = weapon_stats:scenegraph_world_position("grid_background")
	local weapon_stats_width, weapon_stats_height = weapon_stats:_scenegraph_size("grid_background")
	local purchase_world_x = purchase_world_position and tonumber(purchase_world_position[1])
	local purchase_world_y = purchase_world_position and tonumber(purchase_world_position[2])
	local weapon_stats_world_x = weapon_stats_world_position and tonumber(weapon_stats_world_position[1])
	local weapon_stats_world_y = weapon_stats_world_position and tonumber(weapon_stats_world_position[2])

	if type(position[1]) ~= "number" or type(position[2]) ~= "number"
		or not purchase_width or not purchase_height or not purchase_world_x or not purchase_world_y
		or not weapon_stats_world_x or not weapon_stats_world_y
		or type(weapon_stats_width) ~= "number" or type(weapon_stats_height) ~= "number" then
		return false
	end

	local target_x = position[1]

	if sacrifice_button then
		local sacrifice_offset = sacrifice_offset_input or purchase_offset + purchase_width
		local action_left = math.min(purchase_offset, sacrifice_offset)
		local action_right = math.max(purchase_offset + purchase_width, sacrifice_offset + purchase_width)
		local action_center = purchase_world_x + (action_left + action_right) * 0.5
		local weapon_stats_center = weapon_stats_world_x + weapon_stats_width * 0.5

		target_x = position[1] + weapon_stats_center - action_center
	end

	local current_y = position[2]
	local owns_y = probe.owned_purchase_y ~= nil
		and math.abs(current_y - probe.owned_purchase_y) < 0.01

	if probe.owned_purchase_y ~= nil and not owns_y then
		-- Another layout owner rewrote the row after us. Treat that value as the
		-- new native baseline instead of restoring an obsolete coordinate later.
		probe.native_purchase_y = current_y
		probe.owned_purchase_y = nil
	end

	local native_y = probe.native_purchase_y or current_y
	local native_world_y = purchase_world_y + native_y - current_y
	local target_y = native_y

	if gsc_active and weapon_stats_height > 0 then
		local desired_world_y = weapon_stats_world_y + weapon_stats_height + VENDOR_ACTION_ROW_GAP

		if desired_world_y > native_world_y then
			target_y = native_y + desired_world_y - native_world_y
		end
	end

	local x_changed = math.abs(target_x - position[1]) >= 0.01
	local y_changed = math.abs(target_y - position[2]) >= 0.01

	if x_changed or y_changed then
		if type(count_diagnostic) == "function" then
			count_diagnostic("alignment_writes")
		end
		view:_set_scenegraph_position("purchase_button", target_x, target_y, position[3])
	end

	probe.native_purchase_y = native_y
	probe.owned_purchase_y = math.abs(target_y - native_y) >= 0.01 and target_y or nil

	probe.purchase_button = purchase_button
	probe.sacrifice_button = sacrifice_button
	probe.weapon_stats = weapon_stats
	probe.gsc_active = gsc_active
	probe.purchase_x = position[1]
	probe.purchase_y = position[2]
	probe.purchase_width = purchase_width
	probe.purchase_height = purchase_height
	probe.purchase_offset = purchase_offset
	probe.sacrifice_offset_input = sacrifice_offset_input
	probe.weapon_stats_pivot_x = weapon_stats_pivot_x
	probe.weapon_stats_pivot_y = weapon_stats_pivot_y
	probe.panel_height_input = live_weapon_panel_height(weapon_stats)

	return true
end

Domains.quick_level_alignment.release = function(view)
	if not view then
		return false
	end

	local probe = view._better_inventory_quick_level_alignment_probe
	local owned = probe ~= nil
	local purchase_button = view._ui_scenegraph and view._ui_scenegraph.purchase_button
	local position = purchase_button and purchase_button.position

	if probe and probe.owned_purchase_y ~= nil and probe.native_purchase_y ~= nil
		and position and type(position[2]) == "number"
		and math.abs(position[2] - probe.owned_purchase_y) < 0.01
		and type(view._set_scenegraph_position) == "function" then
		view:_set_scenegraph_position("purchase_button", position[1], probe.native_purchase_y, position[3])
	end

	view._better_inventory_quick_level_alignment_probe = nil

	return owned
end

Domains.sorting = {}

Domains.sorting.signature = function(parts)
	local normalized = {}

	for index = 1, #(parts or {}) do
		normalized[index] = tostring(parts[index] or "")
	end

	return table.concat(normalized, "|")
end

Domains.sorting.selected_index = function(options, requested_index)
	local count = #(options or {})

	if count == 0 then
		return nil
	end

	local index = math.floor(tonumber(requested_index) or 1)

	return math.max(1, math.min(index, count))
end

Domains.panels = {}

Domains.panels.composite_key = function(structure_key, lantern_signature, sorting_signature)
	return tostring(structure_key or 0) .. ":" .. tostring(lantern_signature or "") .. ":" .. tostring(sorting_signature or "")
end

Domains.panels.invalidate = function(view)
	if not view then
		return false
	end

	view._better_inventory_composition_generation = (view._better_inventory_composition_generation or 0) + 1
	view._better_inventory_composition_dirty = true

	return true
end

Domains.integration = {}

Domains.integration.method_enabled = function(object, method_name)
	if type(object) ~= "table" and type(object) ~= "userdata" then
		return false
	end

	if type(object[method_name]) ~= "function" then
		return true
	end

	local success, enabled = pcall(object[method_name], object)

	return success and enabled == true
end

return Domains
