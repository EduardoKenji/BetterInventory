local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

local PanelBlueprints = {}

local ROW_HEIGHT = 32
local COMPACT_ROW_HEIGHT = 26
local STATUS_ROW_HEIGHT = 50
local CURRENCY_ROW_HEIGHT = 26
local QUEUE_JOB_ROW_HEIGHT = 110
local STAT_GRID_BUTTON_HEIGHT = 30
local STAT_GRID_GAP = 6
local STAT_GRID_HEIGHT = STAT_GRID_BUTTON_HEIGHT * 2 + STAT_GRID_GAP
local CUSTOM_STAT_GRID_CELL_HEIGHT = 58
local CUSTOM_STAT_GRID_HEIGHT = CUSTOM_STAT_GRID_CELL_HEIGHT * 3 + STAT_GRID_GAP * 2
local TRAIT_GRID_GAP = 5
local PERK_GRID_COLUMNS = 4
local PERK_GRID_BUTTON_HEIGHT = 38
local BLESSING_GRID_COLUMNS = 3
local BLESSING_GRID_BUTTON_HEIGHT = 54
local BLESSING_ICON_SIZE = 30
local BLESSING_ICON_MATERIAL = "content/ui/materials/icons/traits/traits_container"
local SECTION_ROW_HEIGHT = 40
local ROW_SPACING = 8
local CONTENT_HORIZONTAL_PADDING = 12
local CONTENT_VERTICAL_PADDING = 10
local STEPPER_CONTROLS_WIDTH = 182
local STEPPER_VALUE_WIDTH = 114
local MAX_OFFER_ROWS = 10
local MAX_SELECTION_ATTEMPTS = 240
local IDLE_POLL_INTERVAL = 0.1
local CURRENCY_ICONS = {
	credits = "content/ui/materials/mission_board/currencies/credits_small_digital",
	diamantine = "content/ui/materials/mission_board/currencies/diamantine_small_digital",
	plasteel = "content/ui/materials/mission_board/currencies/plasteel_small_digital",
}

function PanelBlueprints.dispatch_trait_press(hotspot, left_callback, right_callback)
	if hotspot and hotspot.on_right_pressed and right_callback then
		right_callback()

		return true
	elseif hotspot and hotspot.on_pressed and left_callback then
		left_callback()

		return true
	end

	return false
end

local dispatch_trait_press = PanelBlueprints.dispatch_trait_press

local function offer_row_passes(width, height)
	local label_width = width - 220
	local detail_x = width - 200

	local function selected(content)
		return content.selected == true
	end

	local function not_selected(content)
		return content.selected ~= true
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
			style_id = "selected_background",
			style = {
				color = Color.terminal_corner_selected(90, true),
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
			visibility_function = selected,
		},
		{
			pass_type = "rect",
			style_id = "normal_background",
			style = {
				color = Color.terminal_background(220, true),
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
			visibility_function = not_selected,
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
					height,
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
					label_width,
					height,
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
					label_width,
					height,
				},
			},
			visibility_function = selected,
		},
		{
			pass_type = "text",
			style_id = "detail",
			value_id = "detail",
			style = {
				font_size = 14,
				font_type = "proxima_nova_medium",
				text_horizontal_alignment = "right",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body_sub_header(255, true),
				offset = {
					detail_x,
					0,
					4,
				},
				size = {
					width - detail_x - 34,
					height,
				},
			},
			visibility_function = not_selected,
		},
		{
			pass_type = "text",
			style_id = "selected_detail",
			value_id = "detail",
			style = {
				font_size = 14,
				font_type = "proxima_nova_medium",
				text_horizontal_alignment = "right",
				text_vertical_alignment = "center",
				text_color = Color.terminal_corner_selected(255, true),
				offset = {
					detail_x,
					0,
					4,
				},
				size = {
					width - detail_x - 34,
					height,
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
					height,
				},
			},
			visibility_function = selected,
		},
	}
end

local function title_passes(width)
	return {
		{ pass_type = "rect", style = { color = Color.terminal_background(210, true), size = { width, SECTION_ROW_HEIGHT }, offset = { 0, 0, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { width, SECTION_ROW_HEIGHT }, offset = { 0, 0, 2 } } },
		{ pass_type = "text", value_id = "label", style = { font_size = 18, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { width - 190, SECTION_ROW_HEIGHT }, offset = { 10, 0, 3 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 13, font_type = "proxima_nova_medium", text_horizontal_alignment = "right", text_vertical_alignment = "center", text_color = Color.terminal_text_body_sub_header(255, true), size = { 170, SECTION_ROW_HEIGHT }, offset = { width - 180, 0, 3 } } },
	}
end

local function summary_line_passes(width)
	return {
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { 120, COMPACT_ROW_HEIGHT } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 14, font_type = "proxima_nova_medium", text_horizontal_alignment = "right", text_vertical_alignment = "center", text_color = Color.terminal_text_body_sub_header(255, true), size = { width - 128, COMPACT_ROW_HEIGHT }, offset = { 128, 0, 1 } } },
	}
end

local function status_block_passes(width)
	return {
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "top", text_color = Color.terminal_text_body(255, true), size = { width, 18 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 13, font_type = "proxima_nova_medium", text_horizontal_alignment = "left", text_vertical_alignment = "top", text_color = Color.terminal_text_body_sub_header(255, true), size = { width, 30 }, offset = { 0, 18, 1 } } },
	}
end

local function queue_job_passes(width, height, highlighted, entry)
	height = height or QUEUE_JOB_ROW_HEIGHT
	local border_color = highlighted and Color.terminal_corner_selected(255, true) or Color.terminal_frame(255, true)
	local label_color = highlighted and Color.terminal_corner_selected(255, true) or Color.terminal_text_header(255, true)
	-- Hotspot visibility receives its nested `remove_hotspot` content, while the
	-- visual passes receive the widget's root content. Resolve both shapes so the
	-- button's hit target cannot be hidden while its red X remains visible.
	local function removable(content)
		local parent = content and content.parent

		return content and content.queue_removable == true or parent and parent.queue_removable == true or false
	end
	local button_y = height - 30

	return {
		{ content_id = "hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { width - 40, height } } },
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { width, height }, offset = { 0, 0, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = border_color, size = { width, height }, offset = { 0, 0, 2 } } },
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "top", text_color = label_color, size = { width - 16, 20 }, offset = { 8, 5, 3 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 12, font_type = "proxima_nova_medium", text_horizontal_alignment = "left", text_vertical_alignment = "top", text_color = Color.terminal_text_body(255, true), size = { width - 16, height - 28 }, offset = { 8, 25, 3 } } },
		{ content_id = "remove_hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { 30, 26 }, offset = { width - 34, button_y, 8 } }, visibility_function = removable },
		{ pass_type = "rect", style = { color = Color.ui_red_medium(110, true), size = { 30, 26 }, offset = { width - 34, button_y, 5 } }, visibility_function = removable },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.ui_red_medium(255, true), size = { 30, 26 }, offset = { width - 34, button_y, 6 } }, visibility_function = removable },
		{ pass_type = "text", value = "X", style = { font_size = 17, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.ui_red_medium(255, true), size = { 30, 26 }, offset = { width - 34, button_y, 7 } }, visibility_function = removable },
	}
end

PanelBlueprints.queue_job_passes = queue_job_passes

local function currency_row_passes(width)
	local label_width = 178
	local segment_width = (width - label_width) / 3
	local passes = {
		{ pass_type = "text", value_id = "label", style = { font_size = 13, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { label_width - 4, CURRENCY_ROW_HEIGHT } } },
	}
	local currencies = { "credits", "plasteel", "diamantine" }

	for index, currency in ipairs(currencies) do
		local x = label_width + (index - 1) * segment_width
		local warning_id = currency .. "_warning"
		local function normal(content) return content[warning_id] ~= true end
		local function warning(content) return content[warning_id] == true end

		passes[#passes + 1] = { pass_type = "texture", value = CURRENCY_ICONS[currency], style = { size = { 18, 18 }, offset = { x, 4, 2 } } }
		passes[#passes + 1] = { pass_type = "text", value_id = currency, style = { font_size = 12, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body_sub_header(255, true), size = { segment_width - 21, CURRENCY_ROW_HEIGHT }, offset = { x + 21, 0, 3 } }, visibility_function = normal }
		passes[#passes + 1] = { pass_type = "text", value_id = currency, style = { font_size = 12, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.ui_red_medium(255, true), size = { segment_width - 21, CURRENCY_ROW_HEIGHT }, offset = { x + 21, 0, 3 } }, visibility_function = warning }
	end

	return passes
end

local function section_header_passes(width)
	return {
		{ content_id = "hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click } },
		{ pass_type = "rect", style = { color = Color.terminal_background(210, true), size = { width, SECTION_ROW_HEIGHT }, offset = { 0, 0, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { width, SECTION_ROW_HEIGHT }, offset = { 0, 0, 2 } } },
		{ pass_type = "text", value_id = "label", style = { font_size = 18, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { width - 115, SECTION_ROW_HEIGHT }, offset = { 10, 0, 3 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 14, font_type = "proxima_nova_medium", text_horizontal_alignment = "right", text_vertical_alignment = "center", text_color = Color.terminal_text_body_sub_header(255, true), size = { 50, SECTION_ROW_HEIGHT }, offset = { width - 94, 0, 3 } } },
		{ pass_type = "text", style_id = "chevron", value_id = "chevron", style = { font_size = 18, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 40, SECTION_ROW_HEIGHT }, offset = { width - 40, 0, 4 } } },
	}
end

local function compact_selector_passes(width)
	local selector_width = 235
	local selector_x = width - selector_width
	return {
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { selector_x - 8, COMPACT_ROW_HEIGHT } } },
		{ content_id = "hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { selector_width, COMPACT_ROW_HEIGHT }, offset = { selector_x, 0, 5 } } },
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { selector_width, COMPACT_ROW_HEIGHT }, offset = { selector_x, 0, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { selector_width, COMPACT_ROW_HEIGHT }, offset = { selector_x, 0, 2 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { selector_width, COMPACT_ROW_HEIGHT }, offset = { selector_x, 0, 3 } } },
	}
end

local function compact_checkbox_passes(width, height)
	height = height or COMPACT_ROW_HEIGHT
	local checkbox_y = 2
	local function enabled(content) return content.enabled == true end
	local function disabled(content) return content.enabled ~= true end
	return {
		{ content_id = "hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click } },
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { 22, 22 }, offset = { 0, checkbox_y, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { 22, 22 }, offset = { 0, checkbox_y, 2 } } },
		{ pass_type = "text", style_id = "selected_mark", value = "✓", style = { font_size = 17, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_corner_selected(255, true), size = { 22, 22 }, offset = { 0, 2, 3 } }, visibility_function = function(content) return content.checked == true end },
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { width - 28, height }, offset = { 28, 0, 3 } }, visibility_function = enabled },
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body_sub_header(150, true), size = { width - 28, height }, offset = { 28, 0, 3 } }, visibility_function = disabled },
	}
end

local function compact_stepper_passes(width)
	local controls_x = width - STEPPER_CONTROLS_WIDTH
	return {
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { controls_x - 8, COMPACT_ROW_HEIGHT } } },
		{ content_id = "decrease_hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x, 0, 5 } } },
		{ pass_type = "text", value = "<", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x, 0, 3 } } },
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { STEPPER_VALUE_WIDTH, COMPACT_ROW_HEIGHT }, offset = { controls_x + 34, 0, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { STEPPER_VALUE_WIDTH, COMPACT_ROW_HEIGHT }, offset = { controls_x + 34, 0, 2 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { STEPPER_VALUE_WIDTH, COMPACT_ROW_HEIGHT }, offset = { controls_x + 34, 0, 3 } } },
		{ content_id = "increase_hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x + 150, 0, 5 } } },
		{ pass_type = "text", value = ">", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x + 150, 0, 3 } } },
	}
end

local function dump_target_stepper_passes(width)
	local comparison_x = 92
	local comparison_width = math.max(100, width - STEPPER_CONTROLS_WIDTH - comparison_x - 8)
	local controls_x = width - STEPPER_CONTROLS_WIDTH

	return {
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { comparison_x - 6, COMPACT_ROW_HEIGHT } } },
		{ content_id = "comparison_hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { comparison_width, COMPACT_ROW_HEIGHT }, offset = { comparison_x, 0, 5 } } },
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { comparison_width, COMPACT_ROW_HEIGHT }, offset = { comparison_x, 0, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { comparison_width, COMPACT_ROW_HEIGHT }, offset = { comparison_x, 0, 2 } } },
		{ pass_type = "text", value_id = "comparison_detail", style = { font_size = 11, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { comparison_width - 24, COMPACT_ROW_HEIGHT }, offset = { comparison_x + 3, 0, 3 } } },
		{ pass_type = "text", value = ">", style_id = "comparison_arrow", style = { font_size = 14, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 18, COMPACT_ROW_HEIGHT }, offset = { comparison_x + comparison_width - 20, 0, 4 } } },
		{ content_id = "decrease_hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x, 0, 5 } } },
		{ pass_type = "text", value = "<", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x, 0, 3 } } },
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { STEPPER_VALUE_WIDTH, COMPACT_ROW_HEIGHT }, offset = { controls_x + 34, 0, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { STEPPER_VALUE_WIDTH, COMPACT_ROW_HEIGHT }, offset = { controls_x + 34, 0, 2 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { STEPPER_VALUE_WIDTH, COMPACT_ROW_HEIGHT }, offset = { controls_x + 34, 0, 3 } } },
		{ content_id = "increase_hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x + 150, 0, 5 } } },
		{ pass_type = "text", value = ">", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x + 150, 0, 3 } } },
	}
end

local function acquisition_stepper_passes(width)
	local controls_y = 24
	local controls_width = width
	local value_width = controls_width - 68

	return {
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { width, 22 } } },
		{ content_id = "decrease_hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { 32, COMPACT_ROW_HEIGHT }, offset = { 0, controls_y, 5 } } },
		{ pass_type = "text", value = "<", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 32, COMPACT_ROW_HEIGHT }, offset = { 0, controls_y, 3 } } },
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { value_width, COMPACT_ROW_HEIGHT }, offset = { 34, controls_y, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { value_width, COMPACT_ROW_HEIGHT }, offset = { 34, controls_y, 2 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 13, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { value_width, COMPACT_ROW_HEIGHT }, offset = { 34, controls_y, 3 } } },
		{ content_id = "increase_hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { 32, COMPACT_ROW_HEIGHT }, offset = { width - 32, controls_y, 5 } } },
		{ pass_type = "text", value = ">", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 32, COMPACT_ROW_HEIGHT }, offset = { width - 32, controls_y, 3 } } },
	}
end

local function enum_stepper_passes(width)
	-- Long vanilla perk descriptions need more room than stat/request enums.
	-- Keep one line at common UI scales while retaining a usable label column.
	local controls_width = 320
	local controls_x = width - controls_width
	local value_width = controls_width - 68
	return {
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { controls_x - 8, COMPACT_ROW_HEIGHT } } },
		{ content_id = "decrease_hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x, 0, 5 } } },
		{ pass_type = "text", value = "<", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x, 0, 3 } } },
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { value_width, COMPACT_ROW_HEIGHT }, offset = { controls_x + 34, 0, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { value_width, COMPACT_ROW_HEIGHT }, offset = { controls_x + 34, 0, 2 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 13, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { value_width, COMPACT_ROW_HEIGHT }, offset = { controls_x + 34, 0, 3 } } },
		{ content_id = "increase_hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x + controls_width - 32, 0, 5 } } },
		{ pass_type = "text", value = ">", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 32, COMPACT_ROW_HEIGHT }, offset = { controls_x + controls_width - 32, 0, 3 } } },
	}
end

local function stat_grid_passes(width, entry)
	local count = math.min(#(entry and entry.stat_buttons or {}), 5)
	local passes = {
		{
			pass_type = "logic",
			value = function(_, _, _, content)
				for index = 1, content.stat_count or 0 do
					local hotspot = content["stat_hotspot_" .. tostring(index)]
					local stat_button = entry and entry.stat_buttons and entry.stat_buttons[index]

					if hotspot and hotspot.on_pressed and stat_button and entry.stat_pressed_callback then
						entry.stat_pressed_callback(stat_button.name)

						break
					end
				end
			end,
		},
	}
	local function selected(index)
		return function(content)
			return (content.stat_count or 0) >= index and content.selected_stat_index == index
		end
	end
	local function not_selected(index)
		return function(content)
			return (content.stat_count or 0) >= index and content.selected_stat_index ~= index
		end
	end
	local function hovered(index)
		return function(content)
			local hotspot = content["stat_hotspot_" .. tostring(index)]

			return (content.stat_count or 0) >= index and hotspot and hotspot.is_hover == true and content.selected_stat_index ~= index
		end
	end

	for index = 1, count do
		local columns = index <= 3 and 3 or 2
		local column = index <= 3 and index - 1 or index - 4
		local row = index <= 3 and 0 or 1
		local button_width = (width - STAT_GRID_GAP * (columns - 1)) / columns
		local x = column * (button_width + STAT_GRID_GAP)
		local y = row * (STAT_GRID_BUTTON_HEIGHT + STAT_GRID_GAP)
		local hotspot_id = "stat_hotspot_" .. tostring(index)
		local label_id = "stat_label_" .. tostring(index)

		passes[#passes + 1] = { content_id = hotspot_id, pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { button_width, STAT_GRID_BUTTON_HEIGHT }, offset = { x, y, 6 } } }
		passes[#passes + 1] = { pass_type = "rect", style = { color = Color.terminal_corner_selected(110, true), size = { button_width, STAT_GRID_BUTTON_HEIGHT }, offset = { x, y, 1 } }, visibility_function = selected(index) }
		passes[#passes + 1] = { pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { button_width, STAT_GRID_BUTTON_HEIGHT }, offset = { x, y, 1 } }, visibility_function = not_selected(index) }
		passes[#passes + 1] = { pass_type = "rect", style = { color = Color.terminal_corner_selected(55, true), size = { button_width, STAT_GRID_BUTTON_HEIGHT }, offset = { x, y, 2 } }, visibility_function = hovered(index) }
		passes[#passes + 1] = { pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { button_width, STAT_GRID_BUTTON_HEIGHT }, offset = { x, y, 2 } } }
		passes[#passes + 1] = { pass_type = "text", value_id = label_id, style = { font_size = 13, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_corner_selected(255, true), size = { button_width - 8, STAT_GRID_BUTTON_HEIGHT }, offset = { x + 4, y, 3 } }, visibility_function = selected(index) }
		passes[#passes + 1] = { pass_type = "text", value_id = label_id, style = { font_size = 13, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { button_width - 8, STAT_GRID_BUTTON_HEIGHT }, offset = { x + 4, y, 3 } }, visibility_function = not_selected(index) }
	end

	return passes
end

PanelBlueprints.stat_grid_passes = stat_grid_passes
local function custom_stat_grid_passes(width)
	local cell_width = (width - STAT_GRID_GAP) / 2
	local passes = {
		{
			pass_type = "logic",
			value = function(_, _, _, content)
				for index = 1, 5 do
					local decrease = content["custom_stat_decrease_hotspot_" .. tostring(index)]
					local increase = content["custom_stat_increase_hotspot_" .. tostring(index)]
					local callbacks = content.custom_stat_callbacks or {}

					if decrease and decrease.on_pressed and callbacks[index] then
						callbacks[index](-1)
						break
					elseif increase and increase.on_pressed and callbacks[index] then
						callbacks[index](1)
						break
					end
				end
			end,
		},
	}
	local function total_valid(content)
		return tonumber(content.custom_stat_total_value) == 380
	end
	local function total_invalid(content)
		return not total_valid(content)
	end

	for index = 1, 6 do
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local x = column * (cell_width + STAT_GRID_GAP)
		local y = row * (CUSTOM_STAT_GRID_CELL_HEIGHT + STAT_GRID_GAP)

		passes[#passes + 1] = { pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { cell_width, CUSTOM_STAT_GRID_CELL_HEIGHT }, offset = { x, y, 1 } } }
		passes[#passes + 1] = { pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { cell_width, CUSTOM_STAT_GRID_CELL_HEIGHT }, offset = { x, y, 2 } } }

		if index <= 5 then
			local label_id = "custom_stat_label_" .. tostring(index)
			local value_id = "custom_stat_value_" .. tostring(index)
			local decrease_id = "custom_stat_decrease_hotspot_" .. tostring(index)
			local increase_id = "custom_stat_increase_hotspot_" .. tostring(index)

			passes[#passes + 1] = { pass_type = "text", value_id = label_id, style = { font_size = 13, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { cell_width - 8, 24 }, offset = { x + 4, y + 2, 3 } } }
			passes[#passes + 1] = { content_id = decrease_id, pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { 36, 28 }, offset = { x + 3, y + 27, 6 } } }
			passes[#passes + 1] = { pass_type = "text", value = "<", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 36, 28 }, offset = { x + 3, y + 27, 4 } } }
			passes[#passes + 1] = { pass_type = "text", value_id = value_id, style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_corner_selected(255, true), size = { cell_width - 78, 28 }, offset = { x + 39, y + 27, 4 } } }
			passes[#passes + 1] = { content_id = increase_id, pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { 36, 28 }, offset = { x + cell_width - 39, y + 27, 6 } } }
			passes[#passes + 1] = { pass_type = "text", value = ">", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { 36, 28 }, offset = { x + cell_width - 39, y + 27, 4 } } }
		else
			passes[#passes + 1] = { pass_type = "text", value_id = "custom_stat_total_label", style = { font_size = 13, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { cell_width - 8, 24 }, offset = { x + 4, y + 2, 3 } } }
			passes[#passes + 1] = { pass_type = "text", value_id = "custom_stat_total", style = { font_size = 18, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_corner_selected(255, true), size = { cell_width - 8, 30 }, offset = { x + 4, y + 25, 4 } }, visibility_function = total_valid }
			passes[#passes + 1] = { pass_type = "text", value_id = "custom_stat_total", style = { font_size = 18, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.ui_red_medium(255, true), size = { cell_width - 8, 30 }, offset = { x + 4, y + 25, 4 } }, visibility_function = total_invalid }
		end
	end

	return passes
end

PanelBlueprints.custom_stat_grid_passes = custom_stat_grid_passes
local function trait_grid_passes(width, entry)
	local count = entry.trait_count or 0
	local columns = entry.trait_columns or PERK_GRID_COLUMNS
	local button_height = entry.trait_button_height or PERK_GRID_BUTTON_HEIGHT
	local show_icons = entry.trait_icons == true
	local button_width = (width - TRAIT_GRID_GAP * (columns - 1)) / columns
	local passes = {
		{
			pass_type = "logic",
			value = function(_, _, _, content)
				local left_callbacks = content.trait_left_callbacks or {}
				local right_callbacks = content.trait_right_callbacks or {}

				for index = 1, content.trait_count or 0 do
					local hotspot = content["trait_hotspot_" .. tostring(index)]

					if dispatch_trait_press(hotspot, left_callbacks[index], right_callbacks[index]) then
						break
					end
				end
			end,
		},
	}

	for index = 1, count do
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)
		local x = column * (button_width + TRAIT_GRID_GAP)
		local y = row * (button_height + TRAIT_GRID_GAP)
		local hotspot_id = "trait_hotspot_" .. tostring(index)
		local label_id = "trait_label_" .. tostring(index)
		local icon_id = "trait_icon_" .. tostring(index)
		local function target_one(content)
			return content.trait_target_1_index == index
		end
		local function target_two(content)
			return content.trait_target_2_index == index
		end
		local function unselected(content)
			return content.trait_target_1_index ~= index and content.trait_target_2_index ~= index
		end
		local function has_icon(content)
			return show_icons and type(content[icon_id]) == "string" and content[icon_id] ~= ""
		end
		local text_x = show_icons and BLESSING_ICON_SIZE + 7 or 4
		local text_width = button_width - text_x - 4

		passes[#passes + 1] = { content_id = hotspot_id, pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click }, style = { size = { button_width, button_height }, offset = { x, y, 6 } } }
		passes[#passes + 1] = { pass_type = "rect", style = { color = Color.terminal_corner_selected(120, true), size = { button_width, button_height }, offset = { x, y, 1 } }, visibility_function = target_one }
		passes[#passes + 1] = { pass_type = "rect", style = { color = { 180, 65, 165, 75 }, size = { button_width, button_height }, offset = { x, y, 1 } }, visibility_function = target_two }
		passes[#passes + 1] = { pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { button_width, button_height }, offset = { x, y, 1 } }, visibility_function = unselected }
		passes[#passes + 1] = { pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { button_width, button_height }, offset = { x, y, 2 } } }
		if show_icons then
			passes[#passes + 1] = { pass_type = "texture", style_id = icon_id, value = BLESSING_ICON_MATERIAL, style = { color = Color.white(255, true), material_values = { frame = "", icon = "" }, size = { BLESSING_ICON_SIZE, BLESSING_ICON_SIZE }, offset = { x + 5, y + (button_height - BLESSING_ICON_SIZE) / 2, 3 } }, visibility_function = has_icon }
		end
		passes[#passes + 1] = { pass_type = "text", value_id = label_id, style = { font_size = show_icons and 12 or 11, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { text_width, button_height }, offset = { x + text_x, y, 4 } } }
	end

	return passes
end

local function action_button_passes(width)
	local function enabled(content) return content.enabled == true end
	local function disabled(content) return content.enabled ~= true end
	return {
		{ content_id = "hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click } },
		{ pass_type = "rect", style = { color = Color.terminal_corner_selected(110, true), size = { width, ROW_HEIGHT }, offset = { 0, 0, 1 } }, visibility_function = enabled },
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { width, ROW_HEIGHT }, offset = { 0, 0, 1 } }, visibility_function = disabled },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { width, ROW_HEIGHT }, offset = { 0, 0, 2 } } },
		{ pass_type = "text", value_id = "label", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { width - 20, ROW_HEIGHT }, offset = { 10, 0, 3 } } },
	}
end

PanelBlueprints.definitions = {
	auto_crafter_row = {
		size_function = function(_, entry)
			return entry.size
		end,
		pass_template_function = function(_, entry)
			local width = entry.size[1]
			local variant = entry.variant

			if variant == "title" then
				return title_passes(width)
			elseif variant == "status" then
				return status_block_passes(width)
			elseif variant == "queue_job" then
				return queue_job_passes(width, entry.size[2], entry.initial_content and entry.initial_content.queue_current == true, entry)
			elseif variant == "currency" then
				return currency_row_passes(width)
			elseif variant == "section" then
				return section_header_passes(width)
			elseif variant == "selector" then
				return compact_selector_passes(width)
			elseif variant == "checkbox" then
				return compact_checkbox_passes(width, entry.size[2])
			elseif variant == "stepper" then
				return compact_stepper_passes(width)
			elseif variant == "dump_target_stepper" then
				return dump_target_stepper_passes(width)
			elseif variant == "acquisition_stepper" then
				return acquisition_stepper_passes(width)
			elseif variant == "enum_stepper" then
				return enum_stepper_passes(width)
			elseif variant == "stat_grid" then
				return stat_grid_passes(width, entry)
			elseif variant == "custom_stat_grid" then
				return custom_stat_grid_passes(width)
			elseif variant == "trait_grid" then
				return trait_grid_passes(width, entry)
			elseif variant == "action" then
				return action_button_passes(width)
			elseif variant == "offer" then
				return offer_row_passes(width, entry.size[2])
			end

			return summary_line_passes(width)
		end,
		init = function(parent, widget, entry, callback_name)
			for key, value in pairs(entry.initial_content or {}) do
				widget.content[key] = type(value) == "table" and table.clone(value) or value
			end

			widget.content.entry = entry
			widget.content.element = entry

			if callback_name and widget.content.hotspot and entry.offer then
				widget.content.hotspot.pressed_callback = callback(parent, callback_name, widget, entry)
			end

			if entry.bind then
				entry.bind(widget)
			end

			-- ViewElementGrid invokes hotspot callbacks directly during UIWidget.draw.
			-- Bind after content initialization so this secondary hotspot follows the
			-- same proven path as steppers and other nested panel controls.
			if widget.content.remove_hotspot and entry.remove_callback then
				widget.content.remove_hotspot.pressed_callback = entry.remove_callback
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

return PanelBlueprints
