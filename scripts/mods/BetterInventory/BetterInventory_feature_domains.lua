local Domains = {}

Domains.markers = {}

Domains.markers.next_generation = function(current_generation)
	return (tonumber(current_generation) or 0) + 1
end

Domains.markers.invalidate_grid = function(item_grid)
	if not item_grid or item_grid._better_inventory_myfavorites_active ~= true then
		return false
	end

	item_grid._better_inventory_myfavorites_dirty = true
	item_grid._better_inventory_myfavorites_generation = Domains.markers.next_generation(item_grid._better_inventory_myfavorites_generation)

	return true
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
