local Domains = {}

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

Domains.quick_level_alignment = {}

local QUICK_LEVEL_ALIGNMENT_PROBE_INTERVAL = 15

Domains.quick_level_alignment.update = function(view, count_diagnostic)
	local widgets_by_name = view and view._widgets_by_name
	local ui_scenegraph = view and view._ui_scenegraph
	local purchase_button = ui_scenegraph and ui_scenegraph.purchase_button
	local sacrifice_button = widgets_by_name and widgets_by_name.quick_sacrifice_button
	local weapon_stats = view and view._weapon_stats

	if not sacrifice_button or not purchase_button or not purchase_button.position or not purchase_button.size or not weapon_stats or type(weapon_stats.scenegraph_world_position) ~= "function" or type(weapon_stats._scenegraph_size) ~= "function" or type(view._scenegraph_world_position) ~= "function" or type(view._set_scenegraph_position) ~= "function" then
		return false
	end

	local position = purchase_button.position
	local purchase_width = tonumber(purchase_button.size[1])
	local purchase_widget = widgets_by_name.purchase_button
	local purchase_offset = purchase_widget and purchase_widget.offset and tonumber(purchase_widget.offset[1]) or 0
	local sacrifice_offset_input = sacrifice_button.offset and tonumber(sacrifice_button.offset[1])
	local weapon_stats_pivot = weapon_stats._pivot_offset
	local weapon_stats_pivot_x = weapon_stats_pivot and tonumber(weapon_stats_pivot[1])
	local weapon_stats_pivot_y = weapon_stats_pivot and tonumber(weapon_stats_pivot[2])
	local probe = view._better_inventory_quick_level_alignment_probe
	local probe_count = (probe and probe.count or QUICK_LEVEL_ALIGNMENT_PROBE_INTERVAL) + 1
	local probe_due = probe_count >= QUICK_LEVEL_ALIGNMENT_PROBE_INTERVAL
	local inputs_changed = not probe
		or probe.purchase_button ~= purchase_button
		or probe.sacrifice_button ~= sacrifice_button
		or probe.weapon_stats ~= weapon_stats
		or probe.purchase_x ~= position[1]
		or probe.purchase_y ~= position[2]
		or probe.purchase_width ~= purchase_width
		or probe.purchase_offset ~= purchase_offset
		or probe.sacrifice_offset_input ~= sacrifice_offset_input
		or probe.weapon_stats_pivot_x ~= weapon_stats_pivot_x
		or probe.weapon_stats_pivot_y ~= weapon_stats_pivot_y

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
	local weapon_stats_width = weapon_stats:_scenegraph_size("grid_background")
	local purchase_world_x = purchase_world_position and tonumber(purchase_world_position[1])
	local weapon_stats_world_x = weapon_stats_world_position and tonumber(weapon_stats_world_position[1])

	if type(position[1]) ~= "number" or not purchase_width or not purchase_world_x or not weapon_stats_world_x or type(weapon_stats_width) ~= "number" then
		return false
	end

	local sacrifice_offset = sacrifice_offset_input or purchase_offset + purchase_width
	local action_left = math.min(purchase_offset, sacrifice_offset)
	local action_right = math.max(purchase_offset + purchase_width, sacrifice_offset + purchase_width)
	local action_center = purchase_world_x + (action_left + action_right) * 0.5
	local weapon_stats_center = weapon_stats_world_x + weapon_stats_width * 0.5
	local delta = weapon_stats_center - action_center

	if math.abs(delta) >= 0.01 then
		if type(count_diagnostic) == "function" then
			count_diagnostic("alignment_writes")
		end
		view:_set_scenegraph_position("purchase_button", position[1] + delta, position[2], position[3])
	end

	probe.purchase_button = purchase_button
	probe.sacrifice_button = sacrifice_button
	probe.weapon_stats = weapon_stats
	probe.purchase_x = position[1]
	probe.purchase_y = position[2]
	probe.purchase_width = purchase_width
	probe.purchase_offset = purchase_offset
	probe.sacrifice_offset_input = sacrifice_offset_input
	probe.weapon_stats_pivot_x = weapon_stats_pivot_x
	probe.weapon_stats_pivot_y = weapon_stats_pivot_y

	return true
end

Domains.quick_level_alignment.release = function(view)
	if not view then
		return false
	end

	local owned = view._better_inventory_quick_level_alignment_probe ~= nil

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
