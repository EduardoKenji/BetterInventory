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
