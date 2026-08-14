local Composition = {}

local function read_member(object, field_name)
	return object[field_name]
end

-- Darktide scenegraph definitions can be strict tables. Optional geometry
-- probes must therefore use raw reads; a missing node is a normal degraded
-- state during Character Overview transitions, not a fatal contract error.
local function optional_field(object, field_name)
	if type(object) == "table" then
		return rawget(object, field_name)
	elseif object ~= nil then
		local success, value = pcall(read_member, object, field_name)

		if success then
			return value
		end
	end

	return nil
end

Composition.invalidate_view = function(view)
	if not view then
		return false
	end

	view._better_inventory_composition_generation = (view._better_inventory_composition_generation or 0) + 1
	view._better_inventory_composition_dirty = true

	return true
end

Composition.inputs_changed = function(view, slot_kind, sorting_mod, fast_only)
	if not view then
		return false
	end

	local weapon_stats = view._weapon_stats
	local weapon_stats_pivot = weapon_stats and weapon_stats._pivot_offset
	local weapon_options = view._weapon_options_element
	local weapon_options_pivot = weapon_options and weapon_options._pivot_offset
	local discard_element = view._discard_items_element
	local discard_position_reader = optional_field(discard_element, "scenegraph_world_position")
	local discard_size_reader = optional_field(discard_element, "_scenegraph_size")
	local sorting_enabled = sorting_mod and sorting_mod.enabled

	if fast_only then
		local unchanged = view._better_inventory_composition_slot_kind == slot_kind
			and view._better_inventory_composition_stats_x == (weapon_stats_pivot and weapon_stats_pivot[1])
			and view._better_inventory_composition_stats_y == (weapon_stats_pivot and weapon_stats_pivot[2])
			and view._better_inventory_composition_options_x == (weapon_options_pivot and weapon_options_pivot[1])
			and view._better_inventory_composition_options_y == (weapon_options_pivot and weapon_options_pivot[2])
			and view._better_inventory_composition_context == view._context
			and view._better_inventory_composition_discard == (discard_element ~= nil)
			and view._better_inventory_composition_discard_position_reader == discard_position_reader
			and view._better_inventory_composition_discard_size_reader == discard_size_reader
			and view._better_inventory_composition_filter == (view._show_filter_panel == true)
			and view._better_inventory_composition_selected_slot == view._selected_slot
			and view._better_inventory_composition_lantern_state == view._lantern_weapon_panel
			and view._better_inventory_composition_item_sorting_mod == sorting_mod
			and view._better_inventory_composition_item_sorting_enabled == sorting_enabled

		if unchanged then
			return false
		end
	end

	local scenegraph = view._ui_scenegraph
	local window = optional_field(scenegraph, "window")
	local window_position = optional_field(window, "position")
	local window_size = optional_field(window, "size")
	local canvas = optional_field(scenegraph, "canvas")
	local canvas_size = optional_field(canvas, "size")
	local window_x = window_position and window_position[1]
	local window_y = window_position and window_position[2]
	local window_width = window_size and window_size[1]
	local window_height = window_size and window_size[2]
	local stats_x = weapon_stats_pivot and weapon_stats_pivot[1]
	local stats_y = weapon_stats_pivot and weapon_stats_pivot[2]
	local options_x = weapon_options_pivot and weapon_options_pivot[1]
	local options_y = weapon_options_pivot and weapon_options_pivot[2]
	local discard_active = view._discard_items_element ~= nil
	local filter_active = view._show_filter_panel == true
	local selected_slot = view._selected_slot
	local lantern_state = view._lantern_weapon_panel
	local canvas_width = canvas_size and canvas_size[1]
	local canvas_height = canvas_size and canvas_size[2]
	local changed = view._better_inventory_composition_slot_kind ~= slot_kind or view._better_inventory_composition_window_x ~= window_x or view._better_inventory_composition_window_y ~= window_y or view._better_inventory_composition_window_width ~= window_width or view._better_inventory_composition_window_height ~= window_height or view._better_inventory_composition_canvas_width ~= canvas_width or view._better_inventory_composition_canvas_height ~= canvas_height or view._better_inventory_composition_stats_x ~= stats_x or view._better_inventory_composition_stats_y ~= stats_y or view._better_inventory_composition_options_x ~= options_x or view._better_inventory_composition_options_y ~= options_y or view._better_inventory_composition_context ~= view._context or view._better_inventory_composition_discard ~= discard_active or view._better_inventory_composition_discard_position_reader ~= discard_position_reader or view._better_inventory_composition_discard_size_reader ~= discard_size_reader or view._better_inventory_composition_filter ~= filter_active or view._better_inventory_composition_selected_slot ~= selected_slot or view._better_inventory_composition_lantern_state ~= lantern_state or view._better_inventory_composition_item_sorting_mod ~= sorting_mod or view._better_inventory_composition_item_sorting_enabled ~= sorting_enabled

	view._better_inventory_composition_slot_kind = slot_kind
	view._better_inventory_composition_window_x = window_x
	view._better_inventory_composition_window_y = window_y
	view._better_inventory_composition_window_width = window_width
	view._better_inventory_composition_window_height = window_height
	view._better_inventory_composition_canvas_width = canvas_width
	view._better_inventory_composition_canvas_height = canvas_height
	view._better_inventory_composition_stats_x = stats_x
	view._better_inventory_composition_stats_y = stats_y
	view._better_inventory_composition_options_x = options_x
	view._better_inventory_composition_options_y = options_y
	view._better_inventory_composition_context = view._context
	view._better_inventory_composition_discard_position_reader = discard_position_reader
	view._better_inventory_composition_discard_size_reader = discard_size_reader
	view._better_inventory_composition_selected_slot = selected_slot
	view._better_inventory_composition_lantern_state = lantern_state
	view._better_inventory_composition_item_sorting_mod = sorting_mod
	view._better_inventory_composition_item_sorting_enabled = sorting_enabled
	view._better_inventory_composition_discard = discard_active
	view._better_inventory_composition_filter = filter_active

	return changed
end

return Composition
