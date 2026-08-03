local Items = require("scripts/utilities/items")
local RaritySettings = require("scripts/settings/item/rarity_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

local Features = {}
local INVENTORY_SORT_TOGGLE_ID = "better_inventory_sort_priority"
local INVENTORY_QUICK_DISCARD_ID = "better_inventory_quick_discard"
local INVENTORY_DISCARD_PROTECTION_ID = "better_inventory_discard_protection"
local registered_inventory_views = setmetatable({}, {
	__mode = "k",
})

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

local function quick_discard_passes()
	local function visible(content)
		return content.visible
	end

	return {
		{
			pass_type = "text",
			style_id = "prefix",
			value_id = "prefix",
			style = {
				font_size = 16,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					0,
					0,
					3,
				},
				size = {
					75,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			content_id = "rarity_hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
			style = {
				offset = {
					75,
					0,
					5,
				},
				size = {
					115,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			pass_type = "rect",
			style_id = "rarity_background",
			style = {
				color = Color.terminal_background(220, true),
				offset = {
					75,
					0,
					1,
				},
				size = {
					115,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			pass_type = "texture",
			style_id = "rarity_frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				color = Color.terminal_frame(255, true),
				offset = {
					75,
					0,
					2,
				},
				size = {
					115,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			pass_type = "text",
			style_id = "rarity_label",
			value_id = "rarity_label",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					75,
					0,
					3,
				},
				size = {
					115,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			pass_type = "text",
			style_id = "suffix",
			value_id = "suffix",
			style = {
				font_size = 14,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					194,
					0,
					3,
				},
				size = {
					76,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			content_id = "discard_hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
			style = {
				horizontal_alignment = "right",
				offset = {
					0,
					0,
					5,
				},
				size = {
					140,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			pass_type = "rect",
			style_id = "discard_background",
			style = {
				horizontal_alignment = "right",
				color = Color.terminal_background_selected(230, true),
				offset = {
					0,
					0,
					1,
				},
				size = {
					140,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			pass_type = "texture",
			style_id = "discard_frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				horizontal_alignment = "right",
				color = Color.terminal_frame_selected(255, true),
				offset = {
					0,
					0,
					2,
				},
				size = {
					140,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			pass_type = "text",
			style_id = "discard_label",
			value_id = "discard_label",
			style = {
				horizontal_alignment = "right",
				font_size = 16,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_header(255, true),
				offset = {
					0,
					0,
					3,
				},
				size = {
					140,
					32,
				},
			},
			visibility_function = visible,
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
			is_curio and 500 or 320,
			20,
		},
	}
	widget_definitions[INVENTORY_SORT_TOGGLE_ID] = UIWidget.create_definition(inventory_sort_toggle_passes(), INVENTORY_SORT_TOGGLE_ID, {
		checked = mod:get("prioritize_equipped_favorites") ~= false,
		label = mod:localize("prioritize_equipped_favorites_inventory_label"),
	})

	if mod:get("enable_experimental_quick_discard") == true then
		scenegraph[INVENTORY_QUICK_DISCARD_ID] = {
			horizontal_alignment = "left",
			parent = is_curio and "weapon_stats_pivot" or "weapon_compare_stats_pivot",
			vertical_alignment = "top",
			size = {
				is_curio and 530 or 420,
				32,
			},
			position = {
				is_curio and 0 or 20,
				is_curio and 542 or 362,
				20,
			},
		}
		widget_definitions[INVENTORY_QUICK_DISCARD_ID] = UIWidget.create_definition(quick_discard_passes(), INVENTORY_QUICK_DISCARD_ID, {
			discard_label = mod:localize("quick_discard_inventory_action"),
			prefix = mod:localize("quick_discard_inventory_prefix"),
			rarity_hotspot = {},
			discard_hotspot = {},
			rarity_label = mod:localize("quick_discard_rarity_1") .. "  ›",
			suffix = mod:localize("quick_discard_inventory_suffix"),
			visible = true,
		})

		scenegraph[INVENTORY_DISCARD_PROTECTION_ID] = {
			horizontal_alignment = "left",
			parent = is_curio and "weapon_stats_pivot" or "weapon_compare_stats_pivot",
			vertical_alignment = "top",
			size = {
				is_curio and 530 or 420,
				32,
			},
			position = {
				is_curio and 0 or 20,
				is_curio and 584 or 404,
				20,
			},
		}
		local protection_enabled = is_curio and mod:get("quick_discard_protect_high_level_curios") ~= false or not is_curio and mod:get("quick_discard_protect_perfect_weapons") ~= false

		widget_definitions[INVENTORY_DISCARD_PROTECTION_ID] = UIWidget.create_definition(inventory_sort_toggle_passes(), INVENTORY_DISCARD_PROTECTION_ID, {
			checked = protection_enabled,
			label = is_curio and mod:localize("quick_discard_inventory_protect_curios") .. " " .. math.floor(tonumber(mod:get("quick_discard_curio_protection_level")) or 410) or mod:localize("quick_discard_inventory_protect_weapons"),
		})
	end

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

local function item_level(item)
	local expertise = Items.expertise_level(item, true)

	return tonumber(expertise)
end

local function item_type_is_enabled(mod, item_type)
	if item_type == "WEAPON_MELEE" then
		return mod:get("quick_discard_include_melee") ~= false
	elseif item_type == "WEAPON_RANGED" then
		return mod:get("quick_discard_include_ranged") ~= false
	elseif item_type == "GADGET" then
		return mod:get("quick_discard_include_curios") ~= false
	end

	return false
end

Features.is_perfect_roll_weapon = function(item)
	if not item or not Items.is_weapon(item.item_type) then
		return false
	end

	local base_stats = item.base_stats

	if type(base_stats) ~= "table" or #base_stats ~= 5 then
		return false
	end

	local total = Items.total_stats_value(item)

	-- A current five-attribute weapon cannot exceed a 380 base-stat roll. Err on
	-- the side of preserving every maximum-total distribution rather than risk
	-- deleting one because its backend values were rounded differently.
	return type(total) == "number" and total >= 380
end

local function eligible_for_quick_discard(mod, view, item)
	if not item or not item.gear_id or not item_type_is_enabled(mod, item.item_type) then
		return false
	end

	local rarity = tonumber(item.rarity)
	local rarity_threshold = math.clamp(math.floor(tonumber(mod:get("quick_discard_rarity")) or 1), 1, 5)

	if not rarity or rarity < 1 or rarity > rarity_threshold then
		return false
	end

	if Items.is_item_id_favorited(item.gear_id) then
		return false
	end

	local slots = item.slots

	if slots and type(view.is_item_equipped_in_any_slot) == "function" and view:is_item_equipped_in_any_slot(item, slots) then
		return false
	end

	local level = item_level(item)
	local maximum_level = math.clamp(math.floor(tonumber(mod:get("quick_discard_max_item_level")) or 500), 0, 500)

	if not level or level > maximum_level then
		return false
	end

	if Items.is_weapon(item.item_type) and mod:get("quick_discard_protect_perfect_weapons") ~= false and Features.is_perfect_roll_weapon(item) then
		return false
	end

	if item.item_type == "GADGET" and mod:get("quick_discard_protect_high_level_curios") ~= false then
		local protected_level = math.clamp(math.floor(tonumber(mod:get("quick_discard_curio_protection_level")) or 410), 0, 500)

		if level >= protected_level then
			return false
		end
	end

	return true
end

Features.quick_discard_candidates = function(mod, layout, view, allowed_gear_ids)
	if not is_inventory_view(layout, view) or view._destroyed then
		return {}
	end

	local candidates = {}
	local seen = {}
	local offer_layout = view._offer_items_layout or {}

	for index = 1, #offer_layout do
		local entry = offer_layout[index]
		local item = entry and (entry.real_item or entry.item)
		local gear_id = item and item.gear_id

		if gear_id and not seen[gear_id] and (not allowed_gear_ids or allowed_gear_ids[gear_id]) and eligible_for_quick_discard(mod, view, item) then
			seen[gear_id] = true
			candidates[#candidates + 1] = item
		end
	end

	return candidates
end

local function rarity_summary(candidates)
	local counts = {}
	local lines = {}

	for index = 1, #candidates do
		local rarity = tonumber(candidates[index].rarity)

		if rarity then
			counts[rarity] = (counts[rarity] or 0) + 1
		end
	end

	for rarity = 1, 5 do
		local count = counts[rarity]

		if count then
			local settings = RaritySettings[rarity]
			local color = settings and settings.color or Color.white(255, true)
			local name = settings and Localize(settings.display_name) or tostring(rarity)

			lines[#lines + 1] = string.format("{#color(%d,%d,%d)}%d %s{#reset()}", color[2], color[3], color[4], count, name)
		end
	end

	return table.concat(lines, "\n")
end

local function show_popup(context)
	if Managers and Managers.event then
		Managers.event:trigger("event_show_ui_popup", context)
	end
end

Features.request_quick_discard = function(mod, layout, view)
	if view._better_inventory_discard_pending then
		return
	end

	local candidates = Features.quick_discard_candidates(mod, layout, view)

	if #candidates == 0 then
		show_popup({
			description_text_unlocalized = mod:localize("quick_discard_nothing_description"),
			options = {
				{
					close_on_pressed = true,
					no_localization = true,
					text = mod:localize("quick_discard_close"),
				},
			},
			title_text_unlocalized = mod:localize("quick_discard_nothing_title"),
		})

		return
	end

	local captured_ids = {}

	for index = 1, #candidates do
		captured_ids[candidates[index].gear_id] = true
	end

	view._better_inventory_discard_pending = true

	local function clear_pending()
		view._better_inventory_discard_pending = false
	end

	local function confirm_discard()
		clear_pending()

		local revalidated = Features.quick_discard_candidates(mod, layout, view, captured_ids)
		local gear_ids = {}

		for index = 1, #revalidated do
			gear_ids[#gear_ids + 1] = revalidated[index].gear_id
		end

		if #gear_ids > 0 and Managers and Managers.event then
			Managers.event:trigger("event_discard_items", gear_ids)
		end
	end

	show_popup({
		description_text_unlocalized = tostring(#candidates) .. " " .. mod:localize("quick_discard_confirmation_description") .. "\n\n" .. rarity_summary(candidates) .. "\n\n" .. mod:localize("quick_discard_confirmation_warning"),
		options = {
			{
				callback = confirm_discard,
				close_on_pressed = true,
				no_localization = true,
				text = mod:localize("quick_discard_confirmation_yes"),
			},
			{
				callback = clear_pending,
				close_on_pressed = true,
				hotkey = "back",
				no_localization = true,
				template_type = "terminal_button_small",
				text = mod:localize("quick_discard_confirmation_no"),
			},
		},
		title_text_unlocalized = mod:localize("quick_discard_confirmation_title"),
	})
end

local function rendered_weapon_stats_height(weapon_stats)
	local scenegraph = weapon_stats and weapon_stats._ui_scenegraph
	local background_pivot = scenegraph and scenegraph.grid_background_pivot
	local background = scenegraph and scenegraph.grid_background
	local divider = scenegraph and scenegraph.grid_divider_bottom
	local weapon_divider = scenegraph and scenegraph.grid_divider_bottom_weapon

	if not background_pivot or not background or not divider then
		return
	end

	local background_pivot_y = background_pivot.position and background_pivot.position[2]
	local background_y = background.position and background.position[2]
	local background_height = background.size and background.size[2]
	local divider_y = divider.position and divider.position[2]
	local divider_height = divider.size and divider.size[2]

	if type(background_pivot_y) ~= "number" or type(background_y) ~= "number" or type(background_height) ~= "number" or type(divider_y) ~= "number" or type(divider_height) ~= "number" then
		return
	end

	local rendered_height = background_pivot_y + background_y + background_height - divider_height + divider_y

	if weapon_divider then
		local weapon_divider_y = weapon_divider.position and weapon_divider.position[2] or 0
		local weapon_divider_height = weapon_divider.size and weapon_divider.size[2]

		if type(weapon_divider_height) == "number" then
			rendered_height = rendered_height + (divider_height - weapon_divider_height) * 0.5 + weapon_divider_y + weapon_divider_height
		else
			rendered_height = rendered_height + divider_height
		end
	else
		rendered_height = rendered_height + divider_height
	end

	if rendered_height > 0 then
		return rendered_height
	end
end

local function set_inventory_sort_toggle_position(view, position, x, y)
	if position[1] == x and position[2] == y then
		return
	end

	if type(view._set_scenegraph_position) == "function" then
		view:_set_scenegraph_position(INVENTORY_SORT_TOGGLE_ID, x, y)
	else
		position[1] = x
		position[2] = y
		view._update_scenegraph = true
	end
end

local function set_inventory_control_position(view, scenegraph_id, x, y)
	local scenegraph = view._ui_scenegraph
	local node = scenegraph and scenegraph[scenegraph_id]
	local position = node and node.position

	if not position or position[1] == x and position[2] == y then
		return
	end

	if type(view._set_scenegraph_position) == "function" then
		view:_set_scenegraph_position(scenegraph_id, x, y)
	else
		position[1] = x
		position[2] = y
		view._update_scenegraph = true
	end
end

local function update_quick_discard_content(mod, slot_kind, view, base_y)
	local widgets = view._widgets_by_name
	local discard_widget = widgets and widgets[INVENTORY_QUICK_DISCARD_ID]
	local protection_widget = widgets and widgets[INVENTORY_DISCARD_PROTECTION_ID]

	if not discard_widget or not protection_widget then
		return
	end

	local rarity = math.clamp(math.floor(tonumber(mod:get("quick_discard_rarity")) or 1), 1, 5)
	local rarity_settings = RaritySettings[rarity]
	local rarity_color = rarity_settings and rarity_settings.color or Color.terminal_text_body(255, true)
	local discard_content = discard_widget.content

	discard_content.rarity_label = mod:localize("quick_discard_rarity_" .. rarity) .. "  ›"
	discard_widget.style.rarity_label.text_color = table.clone(rarity_color)

	local is_curio = slot_kind == "curio"
	local protection_content = protection_widget.content

	protection_content.checked = is_curio and mod:get("quick_discard_protect_high_level_curios") ~= false or not is_curio and mod:get("quick_discard_protect_perfect_weapons") ~= false
	protection_content.label = is_curio and mod:localize("quick_discard_inventory_protect_curios") .. " " .. math.floor(tonumber(mod:get("quick_discard_curio_protection_level")) or 410) or mod:localize("quick_discard_inventory_protect_weapons")

	local x = is_curio and 0 or 20

	set_inventory_control_position(view, INVENTORY_QUICK_DISCARD_ID, x, base_y + 42)
	set_inventory_control_position(view, INVENTORY_DISCARD_PROTECTION_ID, x, base_y + 84)
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
		local content_height = rendered_weapon_stats_height(weapon_stats)

		if not content_height and weapon_stats and type(weapon_stats.grid_length) == "function" then
			local grid_length = weapon_stats:grid_length()

			if type(grid_length) == "number" and grid_length > 0 then
				content_height = grid_length + 35
			end
		end

		local y = (content_height or grid_size and grid_size[2] or 480) + 15

		set_inventory_sort_toggle_position(view, position, 0, y)
		update_quick_discard_content(mod, slot_kind, view, y)
	else
		local menu_settings = view._weapon_options_element and view._weapon_options_element._menu_settings
		local grid_size = menu_settings and menu_settings.grid_size

		local y = (grid_size and grid_size[2] or 300) + 15

		set_inventory_sort_toggle_position(view, position, 20, y)
		update_quick_discard_content(mod, slot_kind, view, y)
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

	local discard_widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_QUICK_DISCARD_ID]
	local discard_content = discard_widget and discard_widget.content
	local rarity_hotspot = discard_content and discard_content.rarity_hotspot
	local discard_hotspot = discard_content and discard_content.discard_hotspot
	local protection_widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_DISCARD_PROTECTION_ID]
	local protection_content = protection_widget and protection_widget.content
	local protection_hotspot = protection_content and protection_content.hotspot

	if rarity_hotspot then
		rarity_hotspot.pressed_callback = function()
			local rarity = math.clamp(math.floor(tonumber(mod:get("quick_discard_rarity")) or 1), 1, 5)

			mod:set("quick_discard_rarity", rarity % 5 + 1, false)
			Features.update_inventory_sort_toggle(mod, layout, view)
		end
	end

	if discard_hotspot then
		discard_hotspot.pressed_callback = function()
			Features.request_quick_discard(mod, layout, view)
		end
	end

	if protection_hotspot then
		protection_hotspot.pressed_callback = function()
			local setting_id = inventory_slot_kind(layout, view) == "curio" and "quick_discard_protect_high_level_curios" or "quick_discard_protect_perfect_weapons"

			mod:set(setting_id, not protection_content.checked, false)
			Features.update_inventory_sort_toggle(mod, layout, view)
		end
	end
end

Features.unregister_inventory_view = function(view)
	registered_inventory_views[view] = nil
end

return Features
