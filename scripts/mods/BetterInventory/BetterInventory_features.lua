local Items = require("scripts/utilities/items")
local RaritySettings = require("scripts/settings/item/rarity_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

local Features = {}
local INVENTORY_SORT_TOGGLE_ID = "better_inventory_sort_priority"
local INVENTORY_SORT_LABEL_ID = "better_inventory_sort_label"
local INVENTORY_DISCARD_LABEL_ID = "better_inventory_discard_label"
local INVENTORY_DISCARD_MODE_ID = "better_inventory_discard_mode"
local INVENTORY_DISCARD_SKIP_CONFIRMATION_ID = "better_inventory_discard_skip_confirmation"
local INVENTORY_QUICK_DISCARD_ID = "better_inventory_quick_discard"
local INVENTORY_DISCARD_MAX_LEVEL_ID = "better_inventory_discard_max_level"
local INVENTORY_DISCARD_MELEE_ID = "better_inventory_discard_melee"
local INVENTORY_DISCARD_RANGED_ID = "better_inventory_discard_ranged"
local INVENTORY_DISCARD_CURIO_ID = "better_inventory_discard_curio"
local INVENTORY_DISCARD_PROTECTION_ID = "better_inventory_discard_protection"
local INVENTORY_DISCARD_CURIO_PROTECTION_ID = "better_inventory_discard_curio_protection"
local INVENTORY_DISCARD_CURIO_LEVEL_ID = "better_inventory_discard_curio_level"
local INVENTORY_DISCARD_WIDGET_IDS = {
	INVENTORY_DISCARD_LABEL_ID,
	INVENTORY_DISCARD_MODE_ID,
	INVENTORY_DISCARD_SKIP_CONFIRMATION_ID,
	INVENTORY_QUICK_DISCARD_ID,
	INVENTORY_DISCARD_MAX_LEVEL_ID,
	INVENTORY_DISCARD_MELEE_ID,
	INVENTORY_DISCARD_RANGED_ID,
	INVENTORY_DISCARD_CURIO_ID,
	INVENTORY_DISCARD_PROTECTION_ID,
	INVENTORY_DISCARD_CURIO_PROTECTION_ID,
	INVENTORY_DISCARD_CURIO_LEVEL_ID,
}
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
		return content.visible or content.parent and content.parent.visible
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
					70,
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
					70,
					0,
					5,
				},
				size = {
					110,
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
					70,
					0,
					1,
				},
				size = {
					110,
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
					70,
					0,
					2,
				},
				size = {
					110,
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
					70,
					0,
					3,
				},
				size = {
					110,
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
					184,
					0,
					3,
				},
				size = {
					70,
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

local function section_label_passes()
	return {
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			style = {
				font_size = 19,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "left",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				vertical_alignment = "center",
				text_color = Color.terminal_text_header(255, true),
				offset = {
					0,
					0,
					3,
				},
			},
		},
	}
end

local function compact_selector_passes(width)
	local selector_x = 64
	local selector_width = width - selector_x

	return {
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				size = {
					selector_x - 6,
					26,
				},
			},
		},
		{
			content_id = "hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
			style = {
				offset = {
					selector_x,
					0,
					5,
				},
				size = {
					selector_width,
					26,
				},
			},
		},
		{
			pass_type = "rect",
			style_id = "background",
			style = {
				color = Color.terminal_background(220, true),
				offset = {
					selector_x,
					0,
					1,
				},
				size = {
					selector_width,
					26,
				},
			},
		},
		{
			pass_type = "texture",
			style_id = "frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				color = Color.terminal_frame(255, true),
				offset = {
					selector_x,
					0,
					2,
				},
				size = {
					selector_width,
					26,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "value",
			value_id = "value",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					selector_x,
					0,
					3,
				},
				size = {
					selector_width,
					26,
				},
			},
		},
	}
end

local function compact_checkbox_passes()
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
				color = Color.terminal_background(220, true),
				offset = {
					0,
					2,
					1,
				},
				size = {
					22,
					22,
				},
			},
		},
		{
			pass_type = "texture",
			style_id = "checkbox_frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				color = Color.terminal_frame(255, true),
				offset = {
					0,
					2,
					2,
				},
				size = {
					22,
					22,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "checkmark",
			value = "",
			style = {
				font_size = 17,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_corner_selected(255, true),
				offset = {
					0,
					2,
					3,
				},
				size = {
					22,
					22,
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
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					28,
					0,
					3,
				},
				size_addition = {
					-28,
					0,
				},
			},
		},
	}
end

local function compact_stepper_passes(width)
	local controls_x = width - 138

	return {
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				size = {
					controls_x - 8,
					26,
				},
			},
		},
		{
			content_id = "decrease_hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
			style = {
				offset = {
					controls_x,
					0,
					5,
				},
				size = {
					32,
					26,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "decrease_label",
			value = "<",
			style = {
				font_size = 16,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_header(255, true),
				offset = {
					controls_x,
					0,
					3,
				},
				size = {
					32,
					26,
				},
			},
		},
		{
			pass_type = "rect",
			style_id = "value_background",
			style = {
				color = Color.terminal_background(220, true),
				offset = {
					controls_x + 34,
					0,
					1,
				},
				size = {
					70,
					26,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "value",
			value_id = "value",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					controls_x + 34,
					0,
					3,
				},
				size = {
					70,
					26,
				},
			},
		},
		{
			content_id = "increase_hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
			style = {
				offset = {
					controls_x + 106,
					0,
					5,
				},
				size = {
					32,
					26,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "increase_label",
			value = ">",
			style = {
				font_size = 16,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_header(255, true),
				offset = {
					controls_x + 106,
					0,
					3,
				},
				size = {
					32,
					26,
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
	local parent = is_curio and "weapon_stats_pivot" or "weapon_compare_stats_pivot"
	local width = is_curio and 530 or 420
	local initial_x = is_curio and 0 or 20
	local initial_y = is_curio and 500 or 320

	scenegraph[INVENTORY_SORT_LABEL_ID] = {
		horizontal_alignment = "left",
		parent = parent,
		vertical_alignment = "top",
		size = {
			width,
			26,
		},
		position = {
			initial_x,
			initial_y,
			20,
		},
	}
	widget_definitions[INVENTORY_SORT_LABEL_ID] = UIWidget.create_definition(section_label_passes(), INVENTORY_SORT_LABEL_ID, {
		label = mod:localize("inventory_sorting_inventory_label"),
	})

	scenegraph[INVENTORY_SORT_TOGGLE_ID] = {
		horizontal_alignment = "left",
		parent = parent,
		vertical_alignment = "top",
		size = {
			width - 15,
			32,
		},
		position = {
			initial_x + 15,
			initial_y + 28,
			20,
		},
	}
	widget_definitions[INVENTORY_SORT_TOGGLE_ID] = UIWidget.create_definition(inventory_sort_toggle_passes(), INVENTORY_SORT_TOGGLE_ID, {
		checked = mod:get("prioritize_equipped_favorites") ~= false,
		label = mod:localize("prioritize_equipped_favorites_inventory_label"),
	})

	if mod:get("enable_experimental_quick_discard") == true then
		local compact_x = initial_x + 15
		-- Curio details use a wider panel than weapons, but stretching the controls
		-- across all 530 pixels leaves the action and steppers visually detached.
		-- Keep the already-good weapon geometry and give Curios the same footprint.
		local control_width = is_curio and 420 or width
		local compact_width = control_width - 15
		local type_gap = 8
		local type_width = math.floor((compact_width - type_gap * 2) / 3)
		local mode_width = 190
		local function add_compact_checkbox(scenegraph_id, x, y, checkbox_width, label, checked)
			scenegraph[scenegraph_id] = {
				horizontal_alignment = "left",
				parent = parent,
				vertical_alignment = "top",
				size = {
					checkbox_width,
					26,
				},
				position = {
					x,
					y,
					20,
				},
			}
			widget_definitions[scenegraph_id] = UIWidget.create_definition(compact_checkbox_passes(), scenegraph_id, {
				checked = checked,
				hotspot = {},
				label = label,
			})
		end
		local function add_compact_stepper(scenegraph_id, y, label, value)
			scenegraph[scenegraph_id] = {
				horizontal_alignment = "left",
				parent = parent,
				vertical_alignment = "top",
				size = {
					compact_width,
					26,
				},
				position = {
					compact_x,
					y,
					20,
				},
			}
			widget_definitions[scenegraph_id] = UIWidget.create_definition(compact_stepper_passes(compact_width), scenegraph_id, {
				decrease_hotspot = {},
				increase_hotspot = {},
				label = label,
				value = tostring(value),
			})
		end

		scenegraph[INVENTORY_DISCARD_LABEL_ID] = {
			horizontal_alignment = "left",
			parent = parent,
			vertical_alignment = "top",
			size = {
				width,
				26,
			},
			position = {
				initial_x,
				initial_y + 70,
				20,
			},
		}
		local discard_mode = mod:get("quick_discard_mode") == "automatic" and "automated" or "manual"

		widget_definitions[INVENTORY_DISCARD_LABEL_ID] = UIWidget.create_definition(section_label_passes(), INVENTORY_DISCARD_LABEL_ID, {
			label = mod:localize("inventory_" .. discard_mode .. "_discard_management_inventory_label"),
		})

		scenegraph[INVENTORY_DISCARD_MODE_ID] = {
			horizontal_alignment = "left",
			parent = parent,
			vertical_alignment = "top",
			size = {
				mode_width,
				26,
			},
			position = {
				compact_x,
				initial_y + 100,
				20,
			},
		}
		widget_definitions[INVENTORY_DISCARD_MODE_ID] = UIWidget.create_definition(compact_selector_passes(mode_width), INVENTORY_DISCARD_MODE_ID, {
			hotspot = {},
			label = mod:localize("quick_discard_inventory_mode"),
			value = mod:localize("quick_discard_mode_" .. (mod:get("quick_discard_mode") or "manual")) .. "  ›",
		})

		add_compact_checkbox(INVENTORY_DISCARD_SKIP_CONFIRMATION_ID, compact_x + mode_width + 10, initial_y + 100, compact_width - mode_width - 10, mod:localize("quick_discard_skip_automatic_confirmation"), mod:get("quick_discard_skip_automatic_confirmation") == true)

		scenegraph[INVENTORY_QUICK_DISCARD_ID] = {
			horizontal_alignment = "left",
			parent = parent,
			vertical_alignment = "top",
			size = {
				compact_width,
				32,
			},
			position = {
				compact_x,
				initial_y + 136,
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

		add_compact_stepper(INVENTORY_DISCARD_MAX_LEVEL_ID, initial_y + 172, mod:localize("quick_discard_inventory_max_level"), math.floor(tonumber(mod:get("quick_discard_max_item_level")) or 500))
		add_compact_checkbox(INVENTORY_DISCARD_MELEE_ID, compact_x, initial_y + 206, type_width, mod:localize("quick_discard_inventory_melee"), mod:get("quick_discard_include_melee") ~= false)
		add_compact_checkbox(INVENTORY_DISCARD_RANGED_ID, compact_x + type_width + type_gap, initial_y + 206, type_width, mod:localize("quick_discard_inventory_ranged"), mod:get("quick_discard_include_ranged") ~= false)
		add_compact_checkbox(INVENTORY_DISCARD_CURIO_ID, compact_x + (type_width + type_gap) * 2, initial_y + 206, type_width, mod:localize("quick_discard_inventory_curios"), mod:get("quick_discard_include_curios") ~= false)

		add_compact_checkbox(INVENTORY_DISCARD_PROTECTION_ID, compact_x, initial_y + 240, compact_width, mod:localize("quick_discard_inventory_protect_weapons"), mod:get("quick_discard_protect_perfect_weapons") ~= false)
		add_compact_checkbox(INVENTORY_DISCARD_CURIO_PROTECTION_ID, compact_x, initial_y + 274, compact_width, mod:localize("quick_discard_inventory_protect_curios"), mod:get("quick_discard_protect_high_level_curios") ~= false)
		add_compact_stepper(INVENTORY_DISCARD_CURIO_LEVEL_ID, initial_y + 308, mod:localize("quick_discard_inventory_curio_level"), math.floor(tonumber(mod:get("quick_discard_curio_protection_level")) or 410))
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

	-- The native discard view temporarily presents a filtered copy of the inventory.
	-- Re-presenting that copy here can leave stale layout/spacing entries when ESC
	-- restores the full inventory. Darktide sorts the full offer layout itself while
	-- closing discard mode, using the current wrapped comparator.
	if view._discard_items_element then
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

local function displayed_base_stat_values(item)
	local base_stats = item and item.base_stats

	if type(base_stats) ~= "table" or #base_stats ~= 5 then
		return
	end

	local values = {}

	for index = 1, #base_stats do
		local stat = base_stats[index]
		local raw_value = type(stat) == "table" and tonumber(stat.value)

		if not raw_value then
			return
		end

		values[index] = math.floor(raw_value * 100 + 0.5)
	end

	return values
end

local function projected_max_base_stat_values(item)
	local base_stats = item and item.base_stats

	if type(base_stats) ~= "table" or #base_stats ~= 5 or type(Items.preview_stats_change) ~= "function" or type(Items.max_expertise_level) ~= "function" then
		return
	end

	-- expertise_level also returns a boolean indicating whether baseItemLevel was
	-- present. Passing the call directly to tonumber forwards that boolean as
	-- tonumber's optional numeric base and raises for virtually every weapon.
	local current_expertise = Items.expertise_level(item, true)

	current_expertise = tonumber(current_expertise)
	local maximum_expertise = tonumber(Items.max_expertise_level())

	if not current_expertise or not maximum_expertise or current_expertise >= maximum_expertise then
		return
	end

	local preview_stats = {}
	local preview_keys = {}

	for index = 1, #base_stats do
		local stat = base_stats[index]
		local raw_value = type(stat) == "table" and tonumber(stat.value)

		if not raw_value then
			return
		end

		local preview_key = "better_inventory_stat_" .. index

		preview_keys[index] = preview_key
		preview_stats[index] = {
			display_name = preview_key,
			fraction = raw_value,
			name = stat.name or preview_key,
		}
	end

	local projected_stats = Items.preview_stats_change(item, maximum_expertise - current_expertise, preview_stats)

	if type(projected_stats) ~= "table" then
		return
	end

	local values = {}

	for index = 1, #preview_keys do
		local projected_stat = projected_stats[preview_keys[index]]
		local projected_value = tonumber(projected_stat and projected_stat.value)

		if not projected_value then
			return
		end

		values[index] = math.floor(projected_value + 0.5)
	end

	return values
end

local function values_are_perfect_roll(values)
	if type(values) ~= "table" or #values ~= 5 then
		return false
	end

	local maximum_stats = 0
	local remaining_stats = 0

	for index = 1, #values do
		local displayed_value = values[index]

		if displayed_value == 80 then
			maximum_stats = maximum_stats + 1
		elseif displayed_value >= 60 then
			remaining_stats = remaining_stats + 1
		else
			return false
		end
	end

	return maximum_stats == 4 and remaining_stats == 1
end

Features.is_perfect_roll_weapon = function(item)
	if not item or not Items.is_weapon(item.item_type) then
		return false
	end

	local total = Items.total_stats_value(item)

	if not total or total > 380 then
		return false
	end

	-- Total power is calculated from unrounded backend values, while each visible
	-- attribute is rounded independently. Consequently the fifth visible stat can
	-- legitimately show 61 or 62 on an otherwise perfect 380 roll.
	if total == 380 and values_are_perfect_roll(displayed_base_stat_values(item)) then
		return true
	end

	-- Rarity upgrades do not change base attributes, but expertise upgrades do.
	-- Protect an underpowered weapon when Darktide's own maximum-expertise preview
	-- resolves to the same four-at-80, fifth-at-least-60 distribution.
	return values_are_perfect_roll(projected_max_base_stat_values(item))
end

local function eligible_for_quick_discard(mod, item, is_equipped)
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

	if is_equipped and is_equipped(item) then
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

local function collect_quick_discard_candidates(mod, source_items, is_equipped, allowed_gear_ids)
	local candidates = {}
	local excluded_errors = 0
	local first_error
	local seen = {}

	for _, entry in pairs(source_items or {}) do
		local item = entry and (entry.real_item or entry.item or entry)
		local gear_id = item and item.gear_id

		if gear_id and not seen[gear_id] and (not allowed_gear_ids or allowed_gear_ids[gear_id]) then
			local success, eligible = pcall(eligible_for_quick_discard, mod, item, is_equipped)

			if success and eligible then
				seen[gear_id] = true
				candidates[#candidates + 1] = item
			elseif not success then
				-- Account inventories can contain legacy or partially materialized gear
				-- that current item utilities cannot evaluate. Automatic discard must
				-- fail closed for those entries instead of aborting the entire scan.
				excluded_errors = excluded_errors + 1
				first_error = first_error or eligible
			end
		end
	end

	return candidates, excluded_errors, first_error
end

Features.quick_discard_candidates = function(mod, layout, view, allowed_gear_ids)
	if not is_inventory_view(layout, view) or view._destroyed then
		return {}
	end

	local parent_inventory = view._parent and view._parent._inventory_items
	local source_items = type(parent_inventory) == "table" and next(parent_inventory) and parent_inventory or view._offer_items_layout or {}
	local function is_equipped(item)
		local slots = item.slots

		return slots and type(view.is_item_equipped_in_any_slot) == "function" and view:is_item_equipped_in_any_slot(item, slots) or false
	end

	local candidates = collect_quick_discard_candidates(mod, source_items, is_equipped, allowed_gear_ids)

	return candidates
end

local function quick_discard_candidates_from_items_detailed(mod, source_items, equipped_gear_ids, allowed_gear_ids)
	local function is_equipped(item)
		return equipped_gear_ids and equipped_gear_ids[item.gear_id] == true
	end

	return collect_quick_discard_candidates(mod, source_items, is_equipped, allowed_gear_ids)
end

Features.quick_discard_candidates_from_items = function(mod, source_items, equipped_gear_ids, allowed_gear_ids)
	local candidates = quick_discard_candidates_from_items_detailed(mod, source_items, equipped_gear_ids, allowed_gear_ids)

	return candidates
end

local function summary_type_name(mod, count, singular_id, plural_id)
	return mod:localize(count == 1 and singular_id or plural_id)
end

local function rarity_summary(mod, candidates)
	local counts = {}
	local lines = {}

	for index = 1, #candidates do
		local item = candidates[index]
		local rarity = tonumber(item.rarity)

		if rarity then
			local rarity_counts = counts[rarity] or {
				curios = 0,
				melee = 0,
				ranged = 0,
				total = 0,
			}

			rarity_counts.total = rarity_counts.total + 1

			if item.item_type == "WEAPON_MELEE" then
				rarity_counts.melee = rarity_counts.melee + 1
			elseif item.item_type == "WEAPON_RANGED" then
				rarity_counts.ranged = rarity_counts.ranged + 1
			elseif item.item_type == "GADGET" then
				rarity_counts.curios = rarity_counts.curios + 1
			end

			counts[rarity] = rarity_counts
		end
	end

	for rarity = 1, 5 do
		local rarity_counts = counts[rarity]

		if rarity_counts then
			local settings = RaritySettings[rarity]
			local color = settings and settings.color or Color.white(255, true)
			local name = settings and Localize(settings.display_name) or tostring(rarity)
			local breakdown = ""

			if mod:get("quick_discard_show_type_breakdown") ~= false then
				breakdown = string.format(" (%d %s, %d %s %s %d %s)", rarity_counts.melee, summary_type_name(mod, rarity_counts.melee, "quick_discard_summary_melee_singular", "quick_discard_summary_melee_plural"), rarity_counts.ranged, summary_type_name(mod, rarity_counts.ranged, "quick_discard_summary_ranged_singular", "quick_discard_summary_ranged_plural"), mod:localize("quick_discard_summary_and"), rarity_counts.curios, summary_type_name(mod, rarity_counts.curios, "quick_discard_summary_curio_singular", "quick_discard_summary_curio_plural"))
			end

			lines[#lines + 1] = string.format("{#color(%d,%d,%d)}%d %s%s{#reset()}", color[2], color[3], color[4], rarity_counts.total, name, breakdown)
		end
	end

	return table.concat(lines, "\n")
end

local function discarded_rarity_summary(candidates)
	local counts = {}
	local lines = {}

	for index = 1, #(candidates or {}) do
		local rarity = tonumber(candidates[index] and candidates[index].rarity)

		if rarity then
			counts[rarity] = (counts[rarity] or 0) + 1
		end
	end

	for rarity = 1, 5 do
		local count = counts[rarity]

		if count and count > 0 then
			local settings = RaritySettings[rarity]
			local color = settings and settings.color or Color.white(255, true)
			local name = settings and Localize(settings.display_name) or tostring(rarity)

			lines[#lines + 1] = string.format("{#color(%d,%d,%d)}- %d %s{#reset()}", color[2], color[3], color[4], count, name)
		end
	end

	return table.concat(lines, "\n")
end

local function show_discard_summary_notification(mod, candidates)
	if mod:get("quick_discard_show_summary_notification") == false or #(candidates or {}) == 0 then
		return
	end

	local event_manager = Managers and Managers.event

	if not event_manager or type(event_manager.trigger) ~= "function" then
		return
	end

	pcall(event_manager.trigger, event_manager, "event_add_notification_message", "custom", {
		line_1 = mod:localize("quick_discard_notification_title"),
		line_1_color = Color.terminal_text_header(255, true),
		line_2 = discarded_rarity_summary(candidates),
		line_2_color = Color.white(255, true),
	})
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
			show_discard_summary_notification(mod, revalidated)
		end
	end

	show_popup({
		description_text_unlocalized = tostring(#candidates) .. " " .. mod:localize("quick_discard_confirmation_description") .. "\n\n" .. rarity_summary(mod, candidates) .. "\n\n" .. mod:localize("quick_discard_confirmation_warning"),
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

local AUTOMATIC_DISCARD_DELAY = 5
local AUTOMATIC_DISCARD_MAX_FETCH_ATTEMPTS = 3
local automatic_discard_state = {
	elapsed = 0,
	fetch_attempts = 0,
	hub_character_id = nil,
	scheduled = false,
	started = false,
	token = 0,
}

local function automatic_discard_enabled(mod)
	return mod:get("enable_experimental_quick_discard") == true and mod:get("quick_discard_mode") == "automatic"
end

local function current_game_mode_name()
	local state = Managers and Managers.state
	local game_mode = state and state.game_mode

	return game_mode and type(game_mode.game_mode_name) == "function" and game_mode:game_mode_name() or nil
end

local function is_morningstar()
	local game_mode_name = current_game_mode_name()

	return game_mode_name == "hub" or game_mode_name == "hub_singleplay"
end

local function automatic_discard_info(mod, message)
	if mod and type(mod.info) == "function" then
		mod:info("[Automatic discard] " .. message)
	end
end

local function automatic_discard_error(error_value)
	if type(error_value) == "table" then
		local message = error_value.message or error_value.error or error_value[1]

		if message then
			return tostring(message)
		elseif type(table.tostring) == "function" then
			return table.tostring(error_value, 2)
		end
	end

	return tostring(error_value)
end

local function equipped_gear_ids(profile)
	local equipped = {}

	for _, loadout in ipairs({
		profile and profile.loadout,
		profile and profile.loadout_item_ids,
	}) do
		for _, item in pairs(loadout or {}) do
			local gear_id = type(item) == "table" and item.gear_id or type(item) == "string" and item or nil

			if gear_id then
				equipped[gear_id] = true
			end
		end
	end

	return equipped
end

local function current_player_and_character()
	local player_manager = Managers and Managers.player
	local player = player_manager and type(player_manager.local_player) == "function" and player_manager:local_player(1)
	local character_id = player and not player.__deleted and type(player.character_id) == "function" and player:character_id()

	return player, character_id
end

local function automatic_context_is_current(mod, token, character_id)
	if automatic_discard_state.token ~= token or not automatic_discard_enabled(mod) or not is_morningstar() then
		return false
	end

	local _, current_character_id = current_player_and_character()

	return current_character_id == character_id
end

local function notify_discard_result(mod, candidates, result)
	local total_rewards = {}
	local deleted_ids = {}

	for index = 1, #(result or {}) do
		local operation = result[index]
		local gear_id = operation and operation.gearId

		if gear_id then
			deleted_ids[gear_id] = true
		end

		for reward_index = 1, #(operation and operation.rewards or {}) do
			local reward = operation.rewards[reward_index]
			local reward_type = reward and reward.type
			local amount = tonumber(reward and reward.amount)

			if reward_type and amount then
				total_rewards[reward_type] = (total_rewards[reward_type] or 0) + amount
			end
		end
	end

	local event_manager = Managers and Managers.event

	if event_manager then
		event_manager:trigger("event_force_wallet_update")
		event_manager:trigger("event_force_refresh_inventory")

		for reward_type, reward_amount in pairs(total_rewards) do
			event_manager:trigger("event_add_notification_message", "currency", {
				amount = reward_amount,
				currency = reward_type,
			})
		end
	end

	local discarded_candidates = {}

	for index = 1, #(candidates or {}) do
		local candidate = candidates[index]

		if candidate and deleted_ids[candidate.gear_id] then
			discarded_candidates[#discarded_candidates + 1] = candidate
		end
	end

	show_discard_summary_notification(mod, discarded_candidates)
end

local function delete_automatic_candidates(mod, token, character_id, captured_ids)
	if not automatic_context_is_current(mod, token, character_id) then
		return
	end

	local gear_service = Managers and Managers.data_service and Managers.data_service.gear
	local player = current_player_and_character()

	if not gear_service or type(gear_service.fetch_inventory) ~= "function" or type(gear_service.delete_gear_batch) ~= "function" or not player then
		return
	end

	gear_service:fetch_inventory(character_id):next(function(items)
		if not automatic_context_is_current(mod, token, character_id) or type(items) ~= "table" then
			return
		end

		local current_player = current_player_and_character()
		local profile = current_player and type(current_player.profile) == "function" and current_player:profile()
		local candidates = Features.quick_discard_candidates_from_items(mod, items, equipped_gear_ids(profile), captured_ids)
		local gear_ids = {}

		for index = 1, #candidates do
			gear_ids[index] = candidates[index].gear_id
		end

		automatic_discard_info(mod, string.format("Revalidated %d candidate(s) immediately before deletion.", #gear_ids))

		if #gear_ids == 0 then
			return
		end

		return gear_service:delete_gear_batch(gear_ids):next(function(result)
			notify_discard_result(mod, candidates, result)

			return result
		end)
	end):catch(function(error_value)
		-- GearService already reports backend failures. Keep the one-shot
		-- Morningstar pass from surfacing an unhandled promise rejection.
		automatic_discard_info(mod, "Final revalidation failed: " .. automatic_discard_error(error_value))
	end)
end

local function present_automatic_discard(mod, token, character_id, candidates)
	local captured_ids = {}

	for index = 1, #candidates do
		captured_ids[candidates[index].gear_id] = true
	end

	if mod:get("quick_discard_skip_automatic_confirmation") == true then
		automatic_discard_info(mod, "Confirmation skipping is enabled; starting final safety revalidation.")
		delete_automatic_candidates(mod, token, character_id, captured_ids)

		return
	end

	show_popup({
		description_text_unlocalized = tostring(#candidates) .. " " .. mod:localize("quick_discard_confirmation_description") .. "\n\n" .. rarity_summary(mod, candidates) .. "\n\n" .. mod:localize("quick_discard_confirmation_warning"),
		options = {
			{
				callback = function()
					delete_automatic_candidates(mod, token, character_id, captured_ids)
				end,
				close_on_pressed = true,
				no_localization = true,
				text = mod:localize("quick_discard_confirmation_yes"),
			},
			{
				close_on_pressed = true,
				hotkey = "back",
				no_localization = true,
				template_type = "terminal_button_small",
				text = mod:localize("quick_discard_confirmation_no"),
			},
		},
		title_text_unlocalized = mod:localize("quick_discard_automatic_confirmation_title"),
	})
	automatic_discard_info(mod, "Displayed the automatic discard confirmation preview.")
end

Features.begin_morningstar_auto_discard = function(mod)
	automatic_discard_state.token = automatic_discard_state.token + 1
	automatic_discard_state.elapsed = 0
	automatic_discard_state.fetch_attempts = 0
	automatic_discard_state.hub_character_id = nil
	automatic_discard_state.scheduled = automatic_discard_enabled(mod)
	automatic_discard_state.started = false
end

Features.cancel_morningstar_auto_discard = function()
	automatic_discard_state.token = automatic_discard_state.token + 1
	automatic_discard_state.elapsed = 0
	automatic_discard_state.fetch_attempts = 0
	automatic_discard_state.hub_character_id = nil
	automatic_discard_state.scheduled = false
	automatic_discard_state.started = false
end

Features.update_morningstar_auto_discard = function(mod, dt)
	if not automatic_discard_enabled(mod) then
		if automatic_discard_state.scheduled or automatic_discard_state.started or automatic_discard_state.hub_character_id then
			Features.cancel_morningstar_auto_discard()
		end

		return
	end

	local game_mode_name = current_game_mode_name()

	if not game_mode_name then
		return
	end

	if not is_morningstar() then
		if automatic_discard_state.scheduled or automatic_discard_state.started or automatic_discard_state.hub_character_id then
			Features.cancel_morningstar_auto_discard()
		end

		return
	end

	local player, character_id = current_player_and_character()

	if not player or not character_id then
		return
	end

	-- DMF normally arms the pass through GameplayStateRun. Also observe the live
	-- hub and character identity so hot reloads and unusual state transition
	-- orders cannot silently leave Automatic mode dormant.
	if automatic_discard_state.hub_character_id ~= character_id then
		automatic_discard_state.token = automatic_discard_state.token + 1
		automatic_discard_state.elapsed = 0
		automatic_discard_state.fetch_attempts = 0
		automatic_discard_state.hub_character_id = character_id
		automatic_discard_state.scheduled = true
		automatic_discard_state.started = false
		automatic_discard_info(mod, "Scheduled one pass after detecting a ready Morningstar character.")
	end

	if not automatic_discard_state.scheduled or automatic_discard_state.started then
		return
	end

	automatic_discard_state.elapsed = automatic_discard_state.elapsed + (tonumber(dt) or 0)

	if automatic_discard_state.elapsed < AUTOMATIC_DISCARD_DELAY then
		return
	end

	local gear_service = Managers and Managers.data_service and Managers.data_service.gear

	if not gear_service or type(gear_service.fetch_inventory) ~= "function" then
		return
	end

	local token = automatic_discard_state.token

	automatic_discard_state.started = true
	automatic_discard_state.fetch_attempts = automatic_discard_state.fetch_attempts + 1
	automatic_discard_info(mod, string.format("Starting inventory scan attempt %d.", automatic_discard_state.fetch_attempts))
	gear_service:fetch_inventory(character_id):next(function(items)
		if not automatic_context_is_current(mod, token, character_id) then
			return
		end

		if type(items) ~= "table" then
			automatic_discard_info(mod, "Inventory scan returned no item table; scheduling a bounded retry.")
			automatic_discard_state.started = false
			automatic_discard_state.elapsed = 0
			automatic_discard_state.scheduled = automatic_discard_state.fetch_attempts < AUTOMATIC_DISCARD_MAX_FETCH_ATTEMPTS

			return
		end

		automatic_discard_state.scheduled = false
		local profile = type(player.profile) == "function" and player:profile()
		local candidates, excluded_errors, first_error = quick_discard_candidates_from_items_detailed(mod, items, equipped_gear_ids(profile))

		if excluded_errors > 0 then
			automatic_discard_info(mod, string.format("Safety-excluded %d unreadable item(s). First error: %s", excluded_errors, automatic_discard_error(first_error)))
		end

		automatic_discard_info(mod, string.format("Inventory scan found %d eligible candidate(s).", #candidates))

		if #candidates > 0 then
			present_automatic_discard(mod, token, character_id, candidates)
		elseif mod:get("quick_discard_skip_automatic_confirmation") ~= true then
			show_popup({
				description_text_unlocalized = mod:localize("quick_discard_automatic_nothing_description"),
				options = {
					{
						close_on_pressed = true,
						no_localization = true,
						text = mod:localize("quick_discard_close"),
					},
				},
				title_text_unlocalized = mod:localize("quick_discard_nothing_title"),
			})
			automatic_discard_info(mod, "Displayed the no-eligible-items result.")
		end
	end):catch(function(error_value)
		automatic_discard_info(mod, "Inventory scan failed; scheduling a bounded retry. Reason: " .. automatic_discard_error(error_value))
		if automatic_discard_state.token == token then
			automatic_discard_state.started = false
			automatic_discard_state.elapsed = 0
			automatic_discard_state.scheduled = automatic_discard_state.fetch_attempts < AUTOMATIC_DISCARD_MAX_FETCH_ATTEMPTS
		end
	end)
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

local function weapon_stats_content_height(view, fallback_height)
	local weapon_stats = view and view._weapon_stats
	local menu_settings = weapon_stats and weapon_stats._menu_settings
	local grid_size = menu_settings and menu_settings.grid_size
	local content_height = rendered_weapon_stats_height(weapon_stats)

	if not content_height and weapon_stats and type(weapon_stats.grid_length) == "function" then
		local grid_length = weapon_stats:grid_length()

		if type(grid_length) == "number" and grid_length > 0 then
			content_height = grid_length + 35
		end
	end

	return content_height or grid_size and grid_size[2] or fallback_height
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

local function set_inventory_widget_visible(view, scenegraph_id, visible)
	local widget = view._widgets_by_name and view._widgets_by_name[scenegraph_id]
	local content = widget and widget.content

	if content then
		content.visible = visible
	end
end

local function set_quick_discard_widgets_visible(view, visible)
	for index = 1, #INVENTORY_DISCARD_WIDGET_IDS do
		set_inventory_widget_visible(view, INVENTORY_DISCARD_WIDGET_IDS[index], visible)
	end
end

local function update_quick_discard_content(mod, slot_kind, view, base_y)
	local widgets = view._widgets_by_name
	local label_widget = widgets and widgets[INVENTORY_DISCARD_LABEL_ID]
	local mode_widget = widgets and widgets[INVENTORY_DISCARD_MODE_ID]
	local skip_confirmation_widget = widgets and widgets[INVENTORY_DISCARD_SKIP_CONFIRMATION_ID]
	local discard_widget = widgets and widgets[INVENTORY_QUICK_DISCARD_ID]
	local max_level_widget = widgets and widgets[INVENTORY_DISCARD_MAX_LEVEL_ID]
	local melee_widget = widgets and widgets[INVENTORY_DISCARD_MELEE_ID]
	local ranged_widget = widgets and widgets[INVENTORY_DISCARD_RANGED_ID]
	local curio_widget = widgets and widgets[INVENTORY_DISCARD_CURIO_ID]
	local protection_widget = widgets and widgets[INVENTORY_DISCARD_PROTECTION_ID]
	local curio_protection_widget = widgets and widgets[INVENTORY_DISCARD_CURIO_PROTECTION_ID]
	local curio_level_widget = widgets and widgets[INVENTORY_DISCARD_CURIO_LEVEL_ID]

	if not discard_widget then
		return
	end

	local discard_mode = mod:get("quick_discard_mode") == "automatic" and "automatic" or "manual"
	local discard_heading_mode = discard_mode == "automatic" and "automated" or "manual"

	if label_widget then
		label_widget.content.label = mod:localize("inventory_" .. discard_heading_mode .. "_discard_management_inventory_label")
	end

	if mode_widget then
		mode_widget.content.value = mod:localize("quick_discard_mode_" .. discard_mode) .. "  ›"
	end

	if skip_confirmation_widget then
		skip_confirmation_widget.content.checked = mod:get("quick_discard_skip_automatic_confirmation") == true
		skip_confirmation_widget.content.visible = discard_mode == "automatic"
	end

	local rarity = math.clamp(math.floor(tonumber(mod:get("quick_discard_rarity")) or 1), 1, 5)
	local rarity_settings = RaritySettings[rarity]
	local rarity_color = rarity_settings and rarity_settings.color or Color.terminal_text_body(255, true)
	local discard_content = discard_widget.content

	discard_content.rarity_label = mod:localize("quick_discard_rarity_" .. rarity) .. "  ›"
	if discard_widget.style and discard_widget.style.rarity_label then
		discard_widget.style.rarity_label.text_color = table.clone(rarity_color)
	end

	if max_level_widget then
		max_level_widget.content.value = tostring(math.clamp(math.floor(tonumber(mod:get("quick_discard_max_item_level")) or 500), 0, 500))
	end

	if melee_widget then
		melee_widget.content.checked = mod:get("quick_discard_include_melee") ~= false
	end

	if ranged_widget then
		ranged_widget.content.checked = mod:get("quick_discard_include_ranged") ~= false
	end

	if curio_widget then
		curio_widget.content.checked = mod:get("quick_discard_include_curios") ~= false
	end

	local protection_content = protection_widget and protection_widget.content
	local curio_protection_content = curio_protection_widget and curio_protection_widget.content

	if protection_content then
		protection_content.checked = mod:get("quick_discard_protect_perfect_weapons") ~= false
	end

	if curio_protection_content then
		curio_protection_content.checked = mod:get("quick_discard_protect_high_level_curios") ~= false
	end

	if curio_level_widget then
		curio_level_widget.content.value = tostring(math.clamp(math.floor(tonumber(mod:get("quick_discard_curio_protection_level")) or 410), 0, 500))
	end

	local is_curio_view = slot_kind == "curio"
	local x = is_curio_view and 0 or 20
	local width = is_curio_view and 530 or 420
	local compact_x = x + 15
	local control_width = is_curio_view and 420 or width
	local compact_width = control_width - 15
	local type_gap = 8
	local type_width = math.floor((compact_width - type_gap * 2) / 3)
	local mode_width = 190

	set_inventory_control_position(view, INVENTORY_DISCARD_LABEL_ID, x, base_y + 70)
	set_inventory_control_position(view, INVENTORY_DISCARD_MODE_ID, compact_x, base_y + 100)
	set_inventory_control_position(view, INVENTORY_DISCARD_SKIP_CONFIRMATION_ID, compact_x + mode_width + 10, base_y + 100)
	set_inventory_control_position(view, INVENTORY_QUICK_DISCARD_ID, compact_x, base_y + 136)
	set_inventory_control_position(view, INVENTORY_DISCARD_MAX_LEVEL_ID, compact_x, base_y + 172)
	set_inventory_control_position(view, INVENTORY_DISCARD_MELEE_ID, compact_x, base_y + 206)
	set_inventory_control_position(view, INVENTORY_DISCARD_RANGED_ID, compact_x + type_width + type_gap, base_y + 206)
	set_inventory_control_position(view, INVENTORY_DISCARD_CURIO_ID, compact_x + (type_width + type_gap) * 2, base_y + 206)
	set_inventory_control_position(view, INVENTORY_DISCARD_PROTECTION_ID, compact_x, base_y + 240)
	set_inventory_control_position(view, INVENTORY_DISCARD_CURIO_PROTECTION_ID, compact_x, base_y + 274)
	set_inventory_control_position(view, INVENTORY_DISCARD_CURIO_LEVEL_ID, compact_x, base_y + 308)
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

	local native_discard_active = view._discard_items_element ~= nil

	set_inventory_widget_visible(view, INVENTORY_SORT_LABEL_ID, true)
	set_inventory_widget_visible(view, INVENTORY_SORT_TOGGLE_ID, true)
	set_quick_discard_widgets_visible(view, not native_discard_active)

	local scenegraph = view._ui_scenegraph
	local node = scenegraph and scenegraph[INVENTORY_SORT_TOGGLE_ID]
	local position = node and node.position

	if not position then
		return
	end

	if native_discard_active then
		local expansion = tonumber(view._better_inventory_grid_expansion) or 0
		local sort_x = slot_kind == "curio" and 0 or -566 - expansion
		local sort_y = weapon_stats_content_height(view, 660) + 15

		set_inventory_control_position(view, INVENTORY_SORT_LABEL_ID, sort_x, sort_y)
		set_inventory_sort_toggle_position(view, position, sort_x + 15, sort_y + 28)

		return
	end

	if slot_kind == "curio" then
		local y = weapon_stats_content_height(view, 480) + 15

		set_inventory_control_position(view, INVENTORY_SORT_LABEL_ID, 0, y)
		set_inventory_sort_toggle_position(view, position, 15, y + 28)
		update_quick_discard_content(mod, slot_kind, view, y)
	else
		local menu_settings = view._weapon_options_element and view._weapon_options_element._menu_settings
		local grid_size = menu_settings and menu_settings.grid_size

		local y = (grid_size and grid_size[2] or 300) + 15

		set_inventory_control_position(view, INVENTORY_SORT_LABEL_ID, 20, y)
		set_inventory_sort_toggle_position(view, position, 35, y + 28)
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

Features.sync_quick_discard_settings = function(mod, layout)
	for view in pairs(registered_inventory_views) do
		if not view._destroyed then
			Features.update_inventory_sort_toggle(mod, layout, view)
		end
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
	local mode_widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_DISCARD_MODE_ID]
	local mode_hotspot = mode_widget and mode_widget.content and mode_widget.content.hotspot
	local skip_confirmation_widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_DISCARD_SKIP_CONFIRMATION_ID]
	local skip_confirmation_content = skip_confirmation_widget and skip_confirmation_widget.content
	local skip_confirmation_hotspot = skip_confirmation_content and skip_confirmation_content.hotspot
	local discard_content = discard_widget and discard_widget.content
	local rarity_hotspot = discard_content and discard_content.rarity_hotspot
	local discard_hotspot = discard_content and discard_content.discard_hotspot

	if rarity_hotspot then
		rarity_hotspot.pressed_callback = function()
			local rarity = math.clamp(math.floor(tonumber(mod:get("quick_discard_rarity")) or 1), 1, 5)

			mod:set("quick_discard_rarity", rarity % 5 + 1, false)
			Features.sync_quick_discard_settings(mod, layout)
		end
	end

	if mode_hotspot then
		mode_hotspot.pressed_callback = function()
			local mode = mod:get("quick_discard_mode") == "automatic" and "manual" or "automatic"

			mod:set("quick_discard_mode", mode, false)
			Features.sync_quick_discard_settings(mod, layout)
		end
	end

	if skip_confirmation_hotspot then
		skip_confirmation_hotspot.pressed_callback = function()
			if mod:get("quick_discard_mode") == "automatic" then
				mod:set("quick_discard_skip_automatic_confirmation", not skip_confirmation_content.checked, false)
				Features.sync_quick_discard_settings(mod, layout)
			end
		end
	end

	if discard_hotspot then
		discard_hotspot.pressed_callback = function()
			Features.request_quick_discard(mod, layout, view)
		end
	end

	local function bind_checkbox(scenegraph_id, setting_id)
		local setting_widget = view._widgets_by_name and view._widgets_by_name[scenegraph_id]
		local setting_content = setting_widget and setting_widget.content
		local setting_hotspot = setting_content and setting_content.hotspot

		if setting_hotspot then
			setting_hotspot.pressed_callback = function()
				mod:set(setting_id, not setting_content.checked, false)
				Features.sync_quick_discard_settings(mod, layout)
			end
		end
	end

	local function bind_stepper(scenegraph_id, setting_id)
		local setting_widget = view._widgets_by_name and view._widgets_by_name[scenegraph_id]
		local setting_content = setting_widget and setting_widget.content
		local decrease_hotspot = setting_content and setting_content.decrease_hotspot
		local increase_hotspot = setting_content and setting_content.increase_hotspot
		local function change_value(delta)
			local value = math.clamp(math.floor(tonumber(mod:get(setting_id)) or 0) + delta, 0, 500)

			mod:set(setting_id, value, false)
			Features.sync_quick_discard_settings(mod, layout)
		end

		if decrease_hotspot then
			decrease_hotspot.pressed_callback = function()
				change_value(-10)
			end
		end

		if increase_hotspot then
			increase_hotspot.pressed_callback = function()
				change_value(10)
			end
		end
	end

	bind_stepper(INVENTORY_DISCARD_MAX_LEVEL_ID, "quick_discard_max_item_level")
	bind_checkbox(INVENTORY_DISCARD_MELEE_ID, "quick_discard_include_melee")
	bind_checkbox(INVENTORY_DISCARD_RANGED_ID, "quick_discard_include_ranged")
	bind_checkbox(INVENTORY_DISCARD_CURIO_ID, "quick_discard_include_curios")
	bind_checkbox(INVENTORY_DISCARD_PROTECTION_ID, "quick_discard_protect_perfect_weapons")
	bind_checkbox(INVENTORY_DISCARD_CURIO_PROTECTION_ID, "quick_discard_protect_high_level_curios")
	bind_stepper(INVENTORY_DISCARD_CURIO_LEVEL_ID, "quick_discard_curio_protection_level")
end

Features.unregister_inventory_view = function(view)
	registered_inventory_views[view] = nil
end

return Features
