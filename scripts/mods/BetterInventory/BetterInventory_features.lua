local Items = require("scripts/utilities/items")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local WeaponStats = require("scripts/utilities/weapon_stats")

local Features = {}
local INVENTORY_SORT_TOGGLE_ID = "better_inventory_sort_priority"
local registered_inventory_views = setmetatable({}, {
	__mode = "k",
})
local unpack_values = table.unpack or unpack

local function inventory_slot_kind(layout, view)
	if not view or view.__class_name ~= "InventoryWeaponsView" then
		return
	end

	local slot_kind = layout.slot_kind(view)

	if slot_kind == "slot_primary" or slot_kind == "slot_secondary" or slot_kind == "curio" then
		return slot_kind
	end
end

local function is_inventory_view(layout, view)
	return inventory_slot_kind(layout, view) ~= nil
end

local function precise_attribute_values(widget)
	local content = widget and widget.content
	local element = content and content.element
	local item = element and element.item

	if not item then
		return
	end

	local start_expertise = content.start_expertise_value or 0
	local preview_expertise = content.preview_expertise_value

	-- Expertise previews deliberately show Darktide's calculated future values,
	-- including its colour markup. Never replace those with the item's base data.
	if preview_expertise and preview_expertise > start_expertise and not content.disable_preview then
		return
	end

	local comparing_stats = WeaponStats:new(item):get_comparing_stats()

	for index = 1, #comparing_stats do
		local fraction = comparing_stats[index].fraction
		local percentage_id = "percentage_" .. index
		local current_text = content[percentage_id]

		if type(fraction) == "number" and type(current_text) == "string" then
			local precise_value = string.format("%.1f", fraction * 100)

			content[percentage_id] = string.gsub(current_text, "^%[[^/]+/", "[" .. precise_value .. "/", 1)
		end
	end
end

Features.configure_weapon_stats_blueprint = function(mod, blueprint)
	if not blueprint or blueprint._better_inventory_precise_values then
		return
	end

	local original_init = blueprint.init
	local original_update = blueprint.update

	if type(original_init) ~= "function" then
		return
	end

	blueprint._better_inventory_precise_values = true
	blueprint.init = function(...)
		local results = {
			original_init(...),
		}
		local widget = select(2, ...)

		if mod:get("show_weapon_attribute_decimals") == true then
			precise_attribute_values(widget)
		end

		return unpack_values(results)
	end

	if type(original_update) == "function" then
		blueprint.update = function(...)
			local results = {
				original_update(...),
			}
			local widget = select(2, ...)

			if mod:get("show_weapon_attribute_decimals") == true then
				precise_attribute_values(widget)
			end

			return unpack_values(results)
		end
	end
end

local function inventory_sort_toggle_passes()
	return {
		{
			content_id = "hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
		},
		{
			pass_type = "rect",
			style_id = "checkbox_background",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				color = Color.terminal_background(220, true),
				size = {
					26,
					26,
				},
				offset = {
					0,
					0,
					1,
				},
			},
		},
		{
			pass_type = "texture",
			style_id = "checkbox_frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				color = Color.terminal_frame(255, true),
				size = {
					26,
					26,
				},
				offset = {
					0,
					0,
					2,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "checkmark",
			value = "",
			style = {
				font_size = 20,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "left",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				vertical_alignment = "center",
				text_color = Color.terminal_corner_selected(255, true),
				size = {
					26,
					26,
				},
				offset = {
					0,
					0,
					3,
				},
			},
			visibility_function = function(content)
				return content.checked
			end,
		},
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			style = {
				font_size = 18,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "left",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					36,
					0,
					3,
				},
				size_addition = {
					-36,
					0,
				},
			},
		},
	}
end

Features.add_inventory_sort_toggle_definition = function(mod, layout, definitions, view)
	local slot_kind = inventory_slot_kind(layout, view)

	if not slot_kind or not definitions then
		return definitions
	end

	local adjusted_definitions = table.clone(definitions)
	local scenegraph = adjusted_definitions.scenegraph_definition
	local widget_definitions = adjusted_definitions.widget_definitions

	if not scenegraph or not widget_definitions then
		return adjusted_definitions
	end

	local is_curio = slot_kind == "curio"

	scenegraph[INVENTORY_SORT_TOGGLE_ID] = {
		horizontal_alignment = "left",
		parent = is_curio and "weapon_stats_pivot" or "weapon_compare_stats_pivot",
		vertical_alignment = "top",
		size = {
			is_curio and 530 or 420,
			32,
		},
		position = {
			is_curio and 0 or 20,
			is_curio and 600 or 320,
			20,
		},
	}
	widget_definitions[INVENTORY_SORT_TOGGLE_ID] = UIWidget.create_definition(inventory_sort_toggle_passes(), INVENTORY_SORT_TOGGLE_ID, {
		checked = mod:get("prioritize_equipped_favorites") ~= false,
		label = mod:localize("prioritize_equipped_favorites_inventory_label"),
	})

	return adjusted_definitions
end

local function item_priority(view, layout_entry)
	local item = layout_entry and (layout_entry.real_item or layout_entry.item)

	if not item then
		return 0
	end

	local slots = item.slots
	local equipped = slots and type(view.is_item_equipped_in_any_slot) == "function" and view:is_item_equipped_in_any_slot(item, slots)

	if equipped then
		return 2
	end

	if item.gear_id and Items.is_item_id_favorited(item.gear_id) then
		return 1
	end

	return 0
end

Features.configure_inventory_sort_options = function(mod, layout, view)
	if not is_inventory_view(layout, view) then
		return
	end

	local sort_options = view._sort_options

	if type(sort_options) ~= "table" then
		return
	end

	for index = 1, #sort_options do
		local option = sort_options[index]
		local original_sort = option and option.sort_function

		if type(original_sort) == "function" and not option._better_inventory_original_sort then
			option._better_inventory_original_sort = original_sort
			option.sort_function = function(left, right)
				if mod:get("prioritize_equipped_favorites") ~= false then
					local left_priority = item_priority(view, left)
					local right_priority = item_priority(view, right)

					if left_priority ~= right_priority then
						return left_priority > right_priority
					end
				end

				return original_sort(left, right)
			end
		end
	end
end

Features.resort_inventory = function(mod, layout, view)
	if not is_inventory_view(layout, view) or view._destroyed or type(view._sort_grid_layout) ~= "function" then
		return
	end

	local sort_options = view._sort_options
	local option = sort_options and (view._selected_sort_option or sort_options[view._selected_sort_option_index or 1])
	local sort_function = option and option.sort_function

	if sort_function then
		view:_sort_grid_layout(sort_function)
	end
end

Features.update_inventory_sort_toggle = function(mod, layout, view)
	local slot_kind = inventory_slot_kind(layout, view)

	if not slot_kind then
		return
	end

	local widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_SORT_TOGGLE_ID]
	local content = widget and widget.content

	if content then
		content.checked = mod:get("prioritize_equipped_favorites") ~= false
	end

	local scenegraph = view._ui_scenegraph
	local node = scenegraph and scenegraph[INVENTORY_SORT_TOGGLE_ID]
	local position = node and node.position

	if not position then
		return
	end

	if slot_kind == "curio" then
		local weapon_stats = view._weapon_stats
		local menu_settings = weapon_stats and weapon_stats._menu_settings
		local grid_size = menu_settings and menu_settings.grid_size
		local content_height

		if weapon_stats and type(weapon_stats.grid_length) == "function" then
			local grid_length = weapon_stats:grid_length()

			if type(grid_length) == "number" and grid_length > 0 then
				content_height = grid_length + 35
			end
		end

		position[1] = 0
		position[2] = (content_height or grid_size and grid_size[2] or 580) + 15
	else
		local menu_settings = view._weapon_options_element and view._weapon_options_element._menu_settings
		local grid_size = menu_settings and menu_settings.grid_size

		position[1] = 20
		position[2] = (grid_size and grid_size[2] or 300) + 15
	end
end

Features.sync_inventory_sort_setting = function(mod, layout)
	local enabled = mod:get("prioritize_equipped_favorites") ~= false

	for view in pairs(registered_inventory_views) do
		local widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_SORT_TOGGLE_ID]
		local content = widget and widget.content

		if content then
			content.checked = enabled
		end

		Features.resort_inventory(mod, layout, view)
	end
end

Features.bind_inventory_sort_toggle = function(mod, layout, view)
	if not is_inventory_view(layout, view) then
		return
	end

	local widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_SORT_TOGGLE_ID]
	local content = widget and widget.content
	local hotspot = content and content.hotspot

	if not hotspot then
		return
	end

	registered_inventory_views[view] = true
	Features.update_inventory_sort_toggle(mod, layout, view)
	hotspot.pressed_callback = function()
		local enabled = not content.checked

		mod:set("prioritize_equipped_favorites", enabled, false)
		Features.sync_inventory_sort_setting(mod, layout)
	end
end

Features.unregister_inventory_view = function(view)
	registered_inventory_views[view] = nil
end

return Features
