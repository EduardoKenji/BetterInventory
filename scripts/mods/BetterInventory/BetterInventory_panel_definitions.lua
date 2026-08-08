local UIWidget = require("scripts/managers/ui/ui_widget")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

-- Static widget definitions and panel geometry. Runtime view ownership stays in
-- BetterInventory_features so this module can be loaded and rebuilt safely.
local INVENTORY_SORT_TOGGLE_ID = "better_inventory_sort_priority"
local INVENTORY_PERFECT_SORT_TOGGLE_ID = "better_inventory_perfect_sort_priority"
local INVENTORY_SORT_LABEL_ID = "better_inventory_sort_label"
local INVENTORY_DISCARD_LABEL_ID = "better_inventory_discard_label"
local INVENTORY_DISCARD_MODE_ID = "better_inventory_discard_mode"
local INVENTORY_DISCARD_SKIP_CONFIRMATION_ID = "better_inventory_discard_skip_confirmation"
local INVENTORY_QUICK_DISCARD_ID = "better_inventory_quick_discard"
local INVENTORY_DISCARD_MAX_LEVEL_ID = "better_inventory_discard_max_level"
local INVENTORY_DISCARD_EQUIPPED_LEVEL_PROTECTION_ID = "better_inventory_discard_equipped_level_protection"
local INVENTORY_DISCARD_MELEE_ID = "better_inventory_discard_melee"
local INVENTORY_DISCARD_RANGED_ID = "better_inventory_discard_ranged"
local INVENTORY_DISCARD_CURIO_ID = "better_inventory_discard_curio"
local INVENTORY_DISCARD_PROTECTION_ID = "better_inventory_discard_protection"
local INVENTORY_DISCARD_CURIO_PROTECTION_ID = "better_inventory_discard_curio_protection"
local INVENTORY_DISCARD_CURIO_LEVEL_ID = "better_inventory_discard_curio_level"
local INVENTORY_CURIO_BUYER_ENABLE_ID = "better_inventory_curio_buyer_enable"
local INVENTORY_CURIO_BUYER_OPERATIVE_SELECTION_ID = "better_inventory_curio_buyer_operative_selection"
local INVENTORY_CURIO_BUYER_ROTATION_ID = "better_inventory_curio_buyer_rotation"
local INVENTORY_CURIO_BUYER_REFRESH_ID = "better_inventory_curio_buyer_refresh"
local INVENTORY_CURIO_BUYER_TARGET_MODE_ID = "better_inventory_curio_buyer_target_mode"
local INVENTORY_CURIO_BUYER_MIN_LEVEL_ID = "better_inventory_curio_buyer_min_level"
local INVENTORY_CURIO_BUYER_MIN_HEALTH_ID = "better_inventory_curio_buyer_min_health"
local INVENTORY_CURIO_BUYER_MIN_TOUGHNESS_ID = "better_inventory_curio_buyer_min_toughness"
local INVENTORY_OPTIONS_PANEL_REFERENCE = "better_inventory_options_panel"
local INVENTORY_OPTIONS_PANEL_MIN_HEIGHT = 120
local INVENTORY_OPTIONS_PANEL_DEFAULT_WIDTH = 445
local INVENTORY_OPTIONS_PANEL_DEFAULT_MAX_HEIGHT = 360
local INVENTORY_OPTIONS_PANEL_DEFAULT_ROW_SPACING = 8
local INVENTORY_OPTIONS_PANEL_DEFAULT_VERTICAL_PADDING = 10
local INVENTORY_OPTIONS_PANEL_DEFAULT_HORIZONTAL_PADDING = 12
local INVENTORY_OPTIONS_PANEL_WEAPON_GAP = 20
local INVENTORY_OPTIONS_PANEL_BUTTON_GAP = 15
local ARMOURY_NATIVE_SORT_PANEL_REFERENCE = "better_inventory_armoury_native_sort_panel"
local ARMOURY_NATIVE_SORT_PANEL_WIDTH = 350
local ARMOURY_NATIVE_SORT_PANEL_HEIGHT = 520
local ARMOURY_NATIVE_SORT_PANEL_MIN_HEIGHT = 140
local ARMOURY_NATIVE_SORT_PANEL_TOP = 100
local ARMOURY_NATIVE_SORT_PANEL_RIGHT_MARGIN = 120
local ARMOURY_NATIVE_SORT_PANEL_WEAPON_GAP = 24
local ARMOURY_NATIVE_SORT_PANEL_WALLET_GAP = 16
local ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT = 32
local ARMOURY_NATIVE_SORT_PANEL_ROW_SPACING = 4
local ARMOURY_NATIVE_SORT_PANEL_PADDING = 10
local ARMOURY_NATIVE_SORT_CHECKBOX_LEFT_PADDING = 8
local GLOBAL_STORE_SERVICE = "get_all_characters_store_custom"
local INVENTORY_CURIO_NATIVE_WIDTH = 530
local INVENTORY_CURIO_NATIVE_GRID_WIDTH = 518
local INVENTORY_CURIO_NATIVE_HEADER_HEIGHT = 250
local INVENTORY_CURIO_NATIVE_ICON_HEIGHT = 180
local INVENTORY_VIRTUAL_CANVAS_WIDTH = 1920
local INVENTORY_VIRTUAL_EDGE_MARGIN = 16

local function numeric_setting(mod, setting_id, default_value, minimum, maximum)
	local value = tonumber(mod:get(setting_id)) or default_value

	return math.clamp(math.floor(value + 0.5), minimum, maximum)
end

local function inventory_options_panel_geometry(mod)
	local width = numeric_setting(mod, "inventory_options_panel_width", INVENTORY_OPTIONS_PANEL_DEFAULT_WIDTH, 360, 560)
	local left = numeric_setting(mod, "inventory_options_panel_padding_left", INVENTORY_OPTIONS_PANEL_DEFAULT_HORIZONTAL_PADDING, 0, 24)
	local right = numeric_setting(mod, "inventory_options_panel_padding_right", INVENTORY_OPTIONS_PANEL_DEFAULT_HORIZONTAL_PADDING, 0, 24)

	return {
		bottom = numeric_setting(mod, "inventory_options_panel_padding_bottom", INVENTORY_OPTIONS_PANEL_DEFAULT_VERTICAL_PADDING, 0, 24),
		content_width = math.max(width - left - right, 280),
		left = left,
		max_height = numeric_setting(mod, "inventory_options_panel_max_height", INVENTORY_OPTIONS_PANEL_DEFAULT_MAX_HEIGHT, 220, 500),
		right = right,
		row_spacing = numeric_setting(mod, "inventory_options_panel_row_spacing", INVENTORY_OPTIONS_PANEL_DEFAULT_ROW_SPACING, 0, 16),
		top = numeric_setting(mod, "inventory_options_panel_padding_top", INVENTORY_OPTIONS_PANEL_DEFAULT_VERTICAL_PADDING, 0, 24),
		width = width,
	}
end
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

local function compact_selector_passes(width, fixed_selector_width, inline_label)
	local selector_x = inline_label and 0 or 64
	local maximum_selector_width = inline_label and math.max(1, width - 100) or width - selector_x
	local selector_width = math.min(fixed_selector_width or maximum_selector_width, maximum_selector_width)
	local label_x = inline_label and selector_width + 8 or 0
	local label_width = inline_label and math.max(1, width - label_x) or selector_x - 6

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
				offset = inline_label and {
					label_x,
					0,
					3,
				} or nil,
				size = {
					label_width,
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

local function panel_sub_label_passes(width)
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
					width,
					26,
				},
			},
		},
	}
end

local function panel_section_header_passes(width)
	local height = 40

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
			style_id = "background",
			style = {
				color = Color.terminal_background(210, true),
				offset = {
					0,
					0,
					1,
				},
				size = {
					width,
					height,
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
					0,
					0,
					2,
				},
				size = {
					width,
					height,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			style = {
				font_size = 18,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_header(255, true),
				offset = {
					10,
					0,
					3,
				},
				size = {
					width - 50,
					height,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "chevron",
			value_id = "chevron",
			style = {
				font_size = 18,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "right",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_header(255, true),
				offset = {
					0,
					0,
					3,
				},
				size = {
					40,
					height,
				},
			},
		},
	}
end

local function armoury_native_sort_option_passes(width)
	local function selected(content)
		return content.selected == true
	end

	local function not_selected(content)
		return not selected(content)
	end

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
			style_id = "background",
			style = {
				color = Color.terminal_background(220, true),
				offset = {
					0,
					0,
					1,
				},
				size = {
					width,
					ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT,
				},
			},
		},
		{
			pass_type = "rect",
			style_id = "selected_background",
			style = {
				color = Color.terminal_corner_selected(90, true),
				offset = {
					0,
					0,
					2,
				},
				size = {
					width,
					ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT,
				},
			},
			visibility_function = selected,
		},
		{
			pass_type = "texture",
			style_id = "frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				color = Color.terminal_frame(255, true),
				offset = {
					0,
					0,
					3,
				},
				size = {
					width,
					ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT,
				},
			},
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
					12,
					0,
					4,
				},
				size = {
					width - 24,
					ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT,
				},
			},
			visibility_function = not_selected,
		},
		{
			pass_type = "text",
			style_id = "selected_label",
			value_id = "label",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_corner_selected(255, true),
				offset = {
					12,
					0,
					4,
				},
				size = {
					width - 24,
					ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT,
				},
			},
			visibility_function = selected,
		},
		{
			pass_type = "text",
			style_id = "selected_mark",
			value = "✓",
			style = {
				font_size = 16,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "right",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_corner_selected(255, true),
				offset = {
					-4,
					0,
					5,
				},
				size = {
					28,
					ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT,
				},
			},
			visibility_function = selected,
		},
	}
end

local function append_panel_checkbox_passes(target, prefix, x, width, checked_id, label_id, optional_visibility_id)
	local source = compact_checkbox_passes()

	for index = 1, #source do
		local pass = table.clone(source[index])
		local original_style_id = pass.style_id

		if pass.content_id == "hotspot" then
			pass.content_id = prefix .. "_hotspot"
		end

		if original_style_id then
			pass.style_id = prefix .. "_" .. original_style_id
		end

		if pass.value_id == "label" then
			pass.value_id = label_id
		end

		local style = pass.style or {}
		local offset = style.offset or {
			0,
			0,
			0,
		}

		offset[1] = (offset[1] or 0) + x
		-- Embedded controls share a widget with the selector to their left. Keep
		-- their input and draw passes above that selector instead of relying on
		-- equal-z pass ordering, which made this checkbox intermittently inert.
		offset[3] = (offset[3] or 0) + 10
		style.offset = offset

		if pass.content_id == prefix .. "_hotspot" then
			style.size = {
				width,
				26,
			}
		elseif original_style_id == "label" then
			style.size_addition = nil
			style.size = {
				math.max(width - 28, 0),
				26,
			}
		end

		pass.style = style

		if original_style_id == "checkmark" then
			pass.visibility_function = function(content)
				return (not optional_visibility_id or content[optional_visibility_id]) and content[checked_id]
			end
		elseif optional_visibility_id then
			pass.visibility_function = function(content)
				return content[optional_visibility_id]
			end
		end

		target[#target + 1] = pass
	end
end

local function panel_type_checkbox_passes(content_width)
	local passes = {}
	local gap = 8
	local width = math.floor((content_width - gap * 2) / 3)

	append_panel_checkbox_passes(passes, "melee", 0, width, "melee_checked", "melee_label")
	append_panel_checkbox_passes(passes, "ranged", width + gap, width, "ranged_checked", "ranged_label")
	append_panel_checkbox_passes(passes, "curio", (width + gap) * 2, width, "curio_checked", "curio_label")

	return passes
end

local function add_inventory_sort_toggle_definition(mod, layout, definitions, view, slot_kind_provider)
	local slot_kind = type(slot_kind_provider) == "function" and slot_kind_provider(layout, view)

	if not slot_kind or not definitions then
		return definitions
	end

	local adjusted_definitions = table.clone(definitions)
	local scenegraph = adjusted_definitions.scenegraph_definition
	local widget_definitions = adjusted_definitions.widget_definitions
	local focus_action = mod:get("inventory_options_controller_focus_keybind")

	if focus_action and focus_action ~= "off" and type(adjusted_definitions.legend_inputs) == "table" then
		adjusted_definitions.legend_inputs[#adjusted_definitions.legend_inputs + 1] = {
			alignment = "right_alignment",
			display_name = "better_inventory_toggle_panel_focus",
			input_action = focus_action,
			visibility_function = function(parent)
				return parent._using_cursor_navigation == false and parent._better_inventory_options_panel_visible == true
			end,
		}
	end

	if not scenegraph or not widget_definitions then
		return adjusted_definitions
	end

	local is_curio = slot_kind == "curio"

	if is_curio and mod:get("enable_inventory_options_panel_prototype") == true then
		local width_percent = numeric_setting(mod, "curio_information_width_percent", 90, 75, 100)
		local target_width = math.floor(INVENTORY_CURIO_NATIVE_WIDTH * width_percent / 100 + 0.5)
		local source_settings = adjusted_definitions.weapon_stats_grid_settings

		if type(source_settings) == "table" then
			local stats_settings = table.clone(source_settings)
			local edge_padding = tonumber(stats_settings.edge_padding) or 12

			stats_settings.grid_size = table.clone(stats_settings.grid_size or {})
			stats_settings.mask_size = table.clone(stats_settings.mask_size or {})
			stats_settings.grid_size[1] = math.max(target_width - edge_padding, 1)
			stats_settings.mask_size[1] = target_width + 40
			adjusted_definitions.weapon_stats_grid_settings = stats_settings
		end
	end

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

		add_compact_stepper(INVENTORY_DISCARD_MAX_LEVEL_ID, initial_y + 172, mod:localize("quick_discard_inventory_max_level"), math.floor(tonumber(mod:get("quick_discard_max_item_level")) or 490))
		add_compact_checkbox(INVENTORY_DISCARD_MELEE_ID, compact_x, initial_y + 206, type_width, mod:localize("quick_discard_inventory_melee"), mod:get("quick_discard_include_melee") ~= false)
		add_compact_checkbox(INVENTORY_DISCARD_RANGED_ID, compact_x + type_width + type_gap, initial_y + 206, type_width, mod:localize("quick_discard_inventory_ranged"), mod:get("quick_discard_include_ranged") ~= false)
		add_compact_checkbox(INVENTORY_DISCARD_CURIO_ID, compact_x + (type_width + type_gap) * 2, initial_y + 206, type_width, mod:localize("quick_discard_inventory_curios"), mod:get("quick_discard_include_curios") ~= false)

		add_compact_checkbox(INVENTORY_DISCARD_PROTECTION_ID, compact_x, initial_y + 240, compact_width, mod:localize("quick_discard_inventory_protect_weapons"), mod:get("quick_discard_protect_perfect_weapons") ~= false)
		add_compact_checkbox(INVENTORY_DISCARD_CURIO_PROTECTION_ID, compact_x, initial_y + 274, compact_width, mod:localize("quick_discard_inventory_protect_curios"), mod:get("quick_discard_protect_high_level_curios") ~= false)
		add_compact_stepper(INVENTORY_DISCARD_CURIO_LEVEL_ID, initial_y + 308, mod:localize("quick_discard_inventory_curio_level"), math.floor(tonumber(mod:get("quick_discard_curio_protection_level")) or 410))
	end

	return adjusted_definitions
end

local rebuild_inventory_options_panel

local INVENTORY_OPTIONS_PANEL_BLUEPRINTS = {
	better_inventory_control = {
		size_function = function(_, entry)
			return entry.size
		end,
		pass_template_function = function(_, entry)
			return entry.pass_template
		end,
		init = function(_, widget, entry)
			local content = widget.content

			for key, value in pairs(entry.initial_content or {}) do
				content[key] = value
			end

			content.entry = entry

			local view = entry.view

			if view then
				view._better_inventory_options_panel_widgets = view._better_inventory_options_panel_widgets or {}
				view._better_inventory_options_panel_widgets[entry.control_id] = widget
			end

			if entry.bind then
				entry.bind(widget)
			end

			if entry.refresh then
				entry.refresh(widget)
			end
		end,
		update = function(_, widget)
			local entry = widget.content.entry

			if entry and entry.refresh then
				entry.refresh(widget)
			end
		end,
	},
	better_inventory_lantern_section = {
		size_function = function(_, entry)
			return entry.size
		end,
		pass_template_function = function(_, entry)
			return entry.pass_template
		end,
		init = function(_, widget, entry)
			for key, value in pairs(entry.initial_content or {}) do
				widget.content[key] = type(value) == "table" and table.clone(value) or value
			end

			widget.content.entry = entry

			local view = entry.view

			if view then
				view._better_inventory_lantern_section_widget = widget
			end

			if entry.refresh then
				entry.refresh(widget)
			end
		end,
		update = function(_, widget)
			local entry = widget.content.entry

			if entry and entry.refresh then
				entry.refresh(widget)
			end
		end,
	},
}

local ARMOURY_NATIVE_SORT_BLUEPRINTS = {
	better_inventory_armoury_native_sort = {
		size_function = function(_, entry)
			return entry.size
		end,
		pass_template_function = function(_, entry)
			return entry.pass_template
		end,
		init = function(_, widget, entry)
			local content = widget.content

			for key, value in pairs(entry.initial_content or {}) do
				content[key] = value
			end

			content.entry = entry

			local view = entry.view

			if view then
				view._better_inventory_armoury_native_sort_widgets = view._better_inventory_armoury_native_sort_widgets or {}
				view._better_inventory_armoury_native_sort_widgets[entry.option_index] = widget
			end

			if entry.bind then
				entry.bind(widget)
			end

			if entry.refresh then
				entry.refresh(widget)
			end
		end,
		update = function(_, widget)
			local entry = widget.content.entry

			if entry and entry.refresh then
				entry.refresh(widget)
			end
		end,
	},
}
local PanelDefinitions = {
	INVENTORY_SORT_TOGGLE_ID = INVENTORY_SORT_TOGGLE_ID,
	INVENTORY_PERFECT_SORT_TOGGLE_ID = INVENTORY_PERFECT_SORT_TOGGLE_ID,
	INVENTORY_SORT_LABEL_ID = INVENTORY_SORT_LABEL_ID,
	INVENTORY_DISCARD_LABEL_ID = INVENTORY_DISCARD_LABEL_ID,
	INVENTORY_DISCARD_MODE_ID = INVENTORY_DISCARD_MODE_ID,
	INVENTORY_DISCARD_SKIP_CONFIRMATION_ID = INVENTORY_DISCARD_SKIP_CONFIRMATION_ID,
	INVENTORY_QUICK_DISCARD_ID = INVENTORY_QUICK_DISCARD_ID,
	INVENTORY_DISCARD_MAX_LEVEL_ID = INVENTORY_DISCARD_MAX_LEVEL_ID,
	INVENTORY_DISCARD_EQUIPPED_LEVEL_PROTECTION_ID = INVENTORY_DISCARD_EQUIPPED_LEVEL_PROTECTION_ID,
	INVENTORY_DISCARD_MELEE_ID = INVENTORY_DISCARD_MELEE_ID,
	INVENTORY_DISCARD_RANGED_ID = INVENTORY_DISCARD_RANGED_ID,
	INVENTORY_DISCARD_CURIO_ID = INVENTORY_DISCARD_CURIO_ID,
	INVENTORY_DISCARD_PROTECTION_ID = INVENTORY_DISCARD_PROTECTION_ID,
	INVENTORY_DISCARD_CURIO_PROTECTION_ID = INVENTORY_DISCARD_CURIO_PROTECTION_ID,
	INVENTORY_DISCARD_CURIO_LEVEL_ID = INVENTORY_DISCARD_CURIO_LEVEL_ID,
	INVENTORY_CURIO_BUYER_ENABLE_ID = INVENTORY_CURIO_BUYER_ENABLE_ID,
	INVENTORY_CURIO_BUYER_OPERATIVE_SELECTION_ID = INVENTORY_CURIO_BUYER_OPERATIVE_SELECTION_ID,
	INVENTORY_CURIO_BUYER_ROTATION_ID = INVENTORY_CURIO_BUYER_ROTATION_ID,
	INVENTORY_CURIO_BUYER_REFRESH_ID = INVENTORY_CURIO_BUYER_REFRESH_ID,
	INVENTORY_CURIO_BUYER_TARGET_MODE_ID = INVENTORY_CURIO_BUYER_TARGET_MODE_ID,
	INVENTORY_CURIO_BUYER_MIN_LEVEL_ID = INVENTORY_CURIO_BUYER_MIN_LEVEL_ID,
	INVENTORY_CURIO_BUYER_MIN_HEALTH_ID = INVENTORY_CURIO_BUYER_MIN_HEALTH_ID,
	INVENTORY_CURIO_BUYER_MIN_TOUGHNESS_ID = INVENTORY_CURIO_BUYER_MIN_TOUGHNESS_ID,
	INVENTORY_OPTIONS_PANEL_REFERENCE = INVENTORY_OPTIONS_PANEL_REFERENCE,
	INVENTORY_OPTIONS_PANEL_MIN_HEIGHT = INVENTORY_OPTIONS_PANEL_MIN_HEIGHT,
	INVENTORY_OPTIONS_PANEL_DEFAULT_WIDTH = INVENTORY_OPTIONS_PANEL_DEFAULT_WIDTH,
	INVENTORY_OPTIONS_PANEL_DEFAULT_MAX_HEIGHT = INVENTORY_OPTIONS_PANEL_DEFAULT_MAX_HEIGHT,
	INVENTORY_OPTIONS_PANEL_DEFAULT_ROW_SPACING = INVENTORY_OPTIONS_PANEL_DEFAULT_ROW_SPACING,
	INVENTORY_OPTIONS_PANEL_DEFAULT_VERTICAL_PADDING = INVENTORY_OPTIONS_PANEL_DEFAULT_VERTICAL_PADDING,
	INVENTORY_OPTIONS_PANEL_DEFAULT_HORIZONTAL_PADDING = INVENTORY_OPTIONS_PANEL_DEFAULT_HORIZONTAL_PADDING,
	INVENTORY_OPTIONS_PANEL_WEAPON_GAP = INVENTORY_OPTIONS_PANEL_WEAPON_GAP,
	INVENTORY_OPTIONS_PANEL_BUTTON_GAP = INVENTORY_OPTIONS_PANEL_BUTTON_GAP,
	ARMOURY_NATIVE_SORT_PANEL_REFERENCE = ARMOURY_NATIVE_SORT_PANEL_REFERENCE,
	ARMOURY_NATIVE_SORT_PANEL_WIDTH = ARMOURY_NATIVE_SORT_PANEL_WIDTH,
	ARMOURY_NATIVE_SORT_PANEL_HEIGHT = ARMOURY_NATIVE_SORT_PANEL_HEIGHT,
	ARMOURY_NATIVE_SORT_PANEL_MIN_HEIGHT = ARMOURY_NATIVE_SORT_PANEL_MIN_HEIGHT,
	ARMOURY_NATIVE_SORT_PANEL_TOP = ARMOURY_NATIVE_SORT_PANEL_TOP,
	ARMOURY_NATIVE_SORT_PANEL_RIGHT_MARGIN = ARMOURY_NATIVE_SORT_PANEL_RIGHT_MARGIN,
	ARMOURY_NATIVE_SORT_PANEL_WEAPON_GAP = ARMOURY_NATIVE_SORT_PANEL_WEAPON_GAP,
	ARMOURY_NATIVE_SORT_PANEL_WALLET_GAP = ARMOURY_NATIVE_SORT_PANEL_WALLET_GAP,
	ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT = ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT,
	ARMOURY_NATIVE_SORT_PANEL_ROW_SPACING = ARMOURY_NATIVE_SORT_PANEL_ROW_SPACING,
	ARMOURY_NATIVE_SORT_PANEL_PADDING = ARMOURY_NATIVE_SORT_PANEL_PADDING,
	ARMOURY_NATIVE_SORT_CHECKBOX_LEFT_PADDING = ARMOURY_NATIVE_SORT_CHECKBOX_LEFT_PADDING,
	GLOBAL_STORE_SERVICE = GLOBAL_STORE_SERVICE,
	INVENTORY_CURIO_NATIVE_WIDTH = INVENTORY_CURIO_NATIVE_WIDTH,
	INVENTORY_CURIO_NATIVE_GRID_WIDTH = INVENTORY_CURIO_NATIVE_GRID_WIDTH,
	INVENTORY_CURIO_NATIVE_HEADER_HEIGHT = INVENTORY_CURIO_NATIVE_HEADER_HEIGHT,
	INVENTORY_CURIO_NATIVE_ICON_HEIGHT = INVENTORY_CURIO_NATIVE_ICON_HEIGHT,
	INVENTORY_VIRTUAL_CANVAS_WIDTH = INVENTORY_VIRTUAL_CANVAS_WIDTH,
	INVENTORY_VIRTUAL_EDGE_MARGIN = INVENTORY_VIRTUAL_EDGE_MARGIN,
	INVENTORY_DISCARD_WIDGET_IDS = INVENTORY_DISCARD_WIDGET_IDS,
	INVENTORY_OPTIONS_PANEL_BLUEPRINTS = INVENTORY_OPTIONS_PANEL_BLUEPRINTS,
	ARMOURY_NATIVE_SORT_BLUEPRINTS = ARMOURY_NATIVE_SORT_BLUEPRINTS,
	numeric_setting = numeric_setting,
	inventory_options_panel_geometry = inventory_options_panel_geometry,
	inventory_sort_toggle_passes = inventory_sort_toggle_passes,
	quick_discard_passes = quick_discard_passes,
	section_label_passes = section_label_passes,
	compact_selector_passes = compact_selector_passes,
	compact_checkbox_passes = compact_checkbox_passes,
	compact_stepper_passes = compact_stepper_passes,
	panel_sub_label_passes = panel_sub_label_passes,
	panel_section_header_passes = panel_section_header_passes,
	armoury_native_sort_option_passes = armoury_native_sort_option_passes,
	append_panel_checkbox_passes = append_panel_checkbox_passes,
	panel_type_checkbox_passes = panel_type_checkbox_passes,
	add_inventory_sort_toggle_definition = add_inventory_sort_toggle_definition,
}

return PanelDefinitions

