local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

local Panel = {}

local PANEL_REFERENCE = "auto_crafter_diagnostic_panel"
local PANEL_WIDTH = 445
local PANEL_HEIGHT = 520
local PANEL_X = 1380
local PANEL_Y = 110
local ROW_HEIGHT = 32
local COMPACT_ROW_HEIGHT = 26
local STATUS_ROW_HEIGHT = 42
local SECTION_ROW_HEIGHT = 40
local ROW_SPACING = 8
local CONTENT_HORIZONTAL_PADDING = 12
local CONTENT_VERTICAL_PADDING = 10
local STEPPER_CONTROLS_WIDTH = 182
local STEPPER_VALUE_WIDTH = 114
local MAX_OFFER_ROWS = 10
local MAX_SELECTION_ATTEMPTS = 240
local SECTION_PLANNER = "planner"
local SECTION_WORKFLOW = "workflow"
local SECTION_TRAITS = "traits"
local SECTION_OUTPUT = "output"
local SECTION_ADVANCED = "advanced"
local SECTION_MELEE = "melee"
local SECTION_RANGED = "ranged"

local function safe_call(fn, ...)
	if type(fn) ~= "function" then
		return false, "method unavailable"
	end

	return pcall(fn, ...)
end

local function safe_member(object, key)
	if type(object) ~= "table" and type(object) ~= "userdata" then
		return nil
	end

	local ok, value = pcall(function()
		return object[key]
	end)

	return ok and value or nil
end

local function value_text(value, fallback)
	if value == nil or value == "" then
		return fallback or "?"
	end

	return tostring(value)
end

local function integer_text(value, fallback)
	local number = tonumber(value)

	if not number then
		return fallback or "?"
	end

	local text = tostring(math.floor(number))
	local changed

	repeat
		text, changed = string.gsub(text, "^(%-?%d+)(%d%d%d)", "%1,%2")
	until changed == 0

	return text
end

local function display_stat_name(stat_name)
	local text = tostring(stat_name or "?")
	text = string.gsub(text, "_", " ")

	return string.upper(string.sub(text, 1, 1)) .. string.sub(text, 2)
end

local function wallet_amount(snapshot, currency)
	local wallets = snapshot and snapshot.wallets
	local currencies = wallets and wallets.currencies
	local entry = currencies and currencies[currency]

	return entry and entry.amount
end

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
		{ pass_type = "text", value_id = "detail", style = { font_size = 13, font_type = "proxima_nova_medium", text_horizontal_alignment = "left", text_vertical_alignment = "top", text_color = Color.terminal_text_body_sub_header(255, true), size = { width, 22 }, offset = { 0, 18, 1 } } },
	}
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

local function compact_checkbox_passes(width)
	local function enabled(content) return content.enabled == true end
	local function disabled(content) return content.enabled ~= true end
	return {
		{ content_id = "hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click } },
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { 22, 22 }, offset = { 0, 2, 1 } } },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { 22, 22 }, offset = { 0, 2, 2 } } },
		{ pass_type = "text", style_id = "selected_mark", value = "✓", style = { font_size = 17, font_type = "proxima_nova_bold", text_horizontal_alignment = "center", text_vertical_alignment = "center", text_color = Color.terminal_corner_selected(255, true), size = { 22, 22 }, offset = { 0, 2, 3 } }, visibility_function = function(content) return content.checked == true end },
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body(255, true), size = { width - 28, COMPACT_ROW_HEIGHT }, offset = { 28, 0, 3 } }, visibility_function = enabled },
		{ pass_type = "text", value_id = "label", style = { font_size = 15, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_body_sub_header(150, true), size = { width - 28, COMPACT_ROW_HEIGHT }, offset = { 28, 0, 3 } }, visibility_function = disabled },
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

local function enum_stepper_passes(width)
	local controls_width = 270
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

local function action_button_passes(width)
	local function enabled(content) return content.enabled == true end
	local function disabled(content) return content.enabled ~= true end
	return {
		{ content_id = "hotspot", pass_type = "hotspot", content = { on_hover_sound = UISoundEvents.default_mouse_hover, on_pressed_sound = UISoundEvents.default_click } },
		{ pass_type = "rect", style = { color = Color.terminal_corner_selected(110, true), size = { width, ROW_HEIGHT }, offset = { 0, 0, 1 } }, visibility_function = enabled },
		{ pass_type = "rect", style = { color = Color.terminal_background(220, true), size = { width, ROW_HEIGHT }, offset = { 0, 0, 1 } }, visibility_function = disabled },
		{ pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_frame(255, true), size = { width, ROW_HEIGHT }, offset = { 0, 0, 2 } } },
		{ pass_type = "text", value_id = "label", style = { font_size = 16, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.terminal_text_header(255, true), size = { width - 185, ROW_HEIGHT }, offset = { 10, 0, 3 } } },
		{ pass_type = "text", value_id = "detail", style = { font_size = 13, font_type = "proxima_nova_medium", text_horizontal_alignment = "right", text_vertical_alignment = "center", text_color = Color.terminal_text_body_sub_header(255, true), size = { 165, ROW_HEIGHT }, offset = { width - 175, 0, 3 } } },
	}
end

local BLUEPRINTS = {
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
			elseif variant == "section" then
				return section_header_passes(width)
			elseif variant == "selector" then
				return compact_selector_passes(width)
			elseif variant == "checkbox" then
				return compact_checkbox_passes(width)
			elseif variant == "stepper" then
				return compact_stepper_passes(width)
			elseif variant == "enum_stepper" then
				return enum_stepper_passes(width)
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

local function offer_label(offer, index)
	return value_text(offer and offer.display_name, value_text(offer and offer.master_id, "Offer " .. tostring(index)))
end

local function offer_selection_key(offer)
	if not offer then
		return nil
	end

	if offer.offer_id ~= nil then
		return "offer:" .. tostring(offer.offer_id)
	end

	if offer.master_id ~= nil then
		return "master:" .. tostring(offer.master_id)
	end

	if offer.display_name ~= nil then
		return "name:" .. tostring(offer.display_name)
	end

	return nil
end

local function offer_detail(offer)
	local price = offer and offer.price_amount
	local price_text = price and tostring(price) or "price ?"
	local pattern = offer and offer.parent_pattern

	return price_text .. " | " .. value_text(pattern, "pattern ?")
end

function Panel.new(dependencies)
	dependencies = dependencies or {}

	local self = {
		_get_selected_offer = dependencies.get_selected_offer,
		_select_offer = dependencies.select_offer,
		_preview_plan = dependencies.preview_plan,
		_start_purchase_search = dependencies.start_purchase_search,
		_start_mastery_operation = dependencies.start_mastery_operation,
		_settings = dependencies.settings or {},
		_localize = dependencies.localize,
		_logger = dependencies.logger,
		_ViewElementGrid = dependencies.ViewElementGrid,
		_panel = nil,
		_view = nil,
		_snapshot = nil,
		_controller_state = nil,
		_plan = nil,
		_phase = "idle",
		_selected_offer_id = nil,
		_selected_offer_key = nil,
		_selected_offer = nil,
		_selected_offer_master_id = nil,
		_section_collapsed = {
			[SECTION_PLANNER] = false,
			[SECTION_WORKFLOW] = false,
			[SECTION_TRAITS] = true,
			[SECTION_OUTPUT] = true,
			[SECTION_ADVANCED] = true,
			[SECTION_MELEE] = true,
			[SECTION_RANGED] = true,
		},
		_pending_offer = nil,
		_pending_offer_attempts = 0,
		_layout_pending = false,
	}

	local function localize(setting_id, fallback)
		if type(self._localize) ~= "function" then
			return fallback or setting_id
		end

		local ok, text = pcall(self._localize, setting_id)

		return ok and text or fallback or setting_id
	end

	local function log(level, message)
		local logger = self._logger and self._logger[level]

		if type(logger) == "function" then
			pcall(logger, self._logger, message)
		end
	end

	function self:_entry(label, detail, options)
		options = options or {}
		local variant = options.variant or "summary"
		local height = COMPACT_ROW_HEIGHT

		if variant == "title" or variant == "section" then
			height = SECTION_ROW_HEIGHT
		elseif variant == "status" then
			height = STATUS_ROW_HEIGHT
		elseif variant == "offer" or variant == "action" then
			height = ROW_HEIGHT
		end

		local entry = {
			initial_content = {
				checked = options.checked == true,
				detail = detail or "",
				enabled = options.enabled ~= false,
				hotspot = {
					disabled = options.selectable ~= true or variant == "action" and options.enabled == false,
				},
				label = label or "",
				selectable = options.selectable == true,
				section_header = options.section_header == true,
				section_id = options.section_id,
				selected = false,
				chevron = "",
			},
			pass_template = nil,
			size = {
				PANEL_WIDTH - CONTENT_HORIZONTAL_PADDING * 2,
				height,
			},
			variant = variant,
			widget_type = "auto_crafter_row",
		}

		if options.section_header then
			entry.bind = function(widget)
				local function toggle_section()
					local section_id = options.section_id

					if not section_id then
						return
					end

					self._section_collapsed[section_id] = not self._section_collapsed[section_id]
					self._layout_pending = true
				end

				widget.content.hotspot.pressed_callback = toggle_section
			end
			entry.refresh = function(widget)
				local collapsed = self._section_collapsed[options.section_id] == true

				widget.content.chevron = collapsed and ">" or "v"
			end
		elseif options.offer then
			entry.offer = options.offer
			entry.refresh = function(widget)
				widget.content.selected = self._selected_offer_key ~= nil and self._selected_offer_key == offer_selection_key(options.offer)
			end
		end

		if options.action then
			entry.bind = function(widget)
				widget.content.hotspot.pressed_callback = function()
					options.action()
				end
			end
		end

		if options.decrease or options.increase then
			entry.bind = function(widget)
				if widget.content.decrease_hotspot then
					widget.content.decrease_hotspot.pressed_callback = options.decrease
				end
				if widget.content.increase_hotspot then
					widget.content.increase_hotspot.pressed_callback = options.increase
				end
			end
		end

		if options.refresh then
			entry.refresh = options.refresh
		end

		return entry
	end

	function self:_selected_offers(snapshot)
		local store = snapshot and snapshot.store or {}
		local offers = store.offers or {}
		local selected_offer = self._selected_offer

		local selected_display_name

		if selected_offer then
			for _, offer in ipairs(offers) do
				local offer_matches = selected_offer.offer_id and offer.offer_id == selected_offer.offer_id or selected_offer.master_id and offer.master_id == selected_offer.master_id

				if offer_matches then
					selected_display_name = offer.display_name

					break
				end
			end
		end

		if selected_display_name then
			return offers, selected_display_name
		end

		return offers, selected_offer and localize("auto_crafter_panel_selected_weapon", "Selected weapon") or localize("auto_crafter_panel_no_target", "no weapon selected")
	end

	function self:_setting(setting_id, default_value)
		local get = self._settings and self._settings.get

		if type(get) ~= "function" then
			return default_value
		end

		local ok, value = pcall(get, self._settings, setting_id)

		return ok and value ~= nil and value or default_value
	end

	function self:_set_setting(setting_id, value)
		local set = self._settings and self._settings.set

		if type(set) ~= "function" then
			return false
		end

		local ok, result = pcall(set, self._settings, setting_id, value)

		return ok and result ~= false
	end

	function self:_cycle_setting(setting_id, values, default_value)
		local current = self:_setting(setting_id, default_value)
		local next_index = 1

		for index, value in ipairs(values) do
			if value == current then
				next_index = index % #values + 1

				break
			end
		end

		self:_set_setting(setting_id, values[next_index])
	end

	function self:_adjust_numeric_setting(setting_id, default_value, minimum, maximum, step)
		local current = tonumber(self:_setting(setting_id, default_value)) or default_value
		self:_set_setting(setting_id, math.max(minimum, math.min(maximum, current + step)))
	end

	function self:_step_enum_setting(setting_id, values, default_value, direction)
		local current = self:_setting(setting_id, default_value)
		local current_index = 1

		for index, value in ipairs(values) do
			if value == current then
				current_index = index
				break
			end
		end

		local next_index = (current_index - 1 + direction) % #values + 1
		self:_set_setting(setting_id, values[next_index])
	end

	function self:_planner_target_text()
		local _, current_weapon = self:_selected_offers(self._snapshot)

		return current_weapon or localize("auto_crafter_panel_no_target", "no weapon selected")
	end

	function self:_planner_dump_stat_text()
		local value = self:_setting("auto_crafter_target_dump_stat", "auto")

		if value == "auto" then
			local resolved = self._plan and self._plan.resolved_dump_stat

			if resolved then
				return string.format("%s: %s", localize("auto_crafter_dump_stat_auto", "Auto-discover"), display_stat_name(resolved))
			end

			return localize("auto_crafter_dump_stat_auto_pending", "Auto-discover (waiting for weapon preview)")
		end

		return localize("auto_crafter_dump_stat_damage", "Damage")
	end

	function self:_planner_request_mode_text()
		local value = self:_setting("auto_crafter_request_mode", "sequential")

		if value == "parallel_reads" then
			return localize("auto_crafter_request_mode_parallel_reads", "Parallel reads")
		elseif value == "experimental_parallel_mutations" then
			return localize("auto_crafter_request_mode_experimental", "Experimental parallel mutations")
		end

		return localize("auto_crafter_request_mode_sequential", "Sequential (recommended)")
	end

	function self:_planner_fallback_text()
		return self:_setting("auto_crafter_best_candidate_fallback", false) == true and localize("auto_crafter_value_on", "On") or localize("auto_crafter_value_off", "Off")
	end

	function self:_target_policy_text(setting_id)
		return self:_setting(setting_id, "keep") == "auto" and localize("auto_crafter_target_auto", "Auto-select (planned)") or localize("auto_crafter_target_keep", "Keep current")
	end

	function self:_mutation_gate_text()
		return self:_setting("auto_crafter_allow_mutations", false) == true and localize("auto_crafter_panel_mutations_on", "SERIAL MUTATIONS ON") or localize("auto_crafter_panel_mutations_off", "MUTATIONS OFF")
	end

	function self:_last_candidate_text()
		local candidate = self._controller_state and self._controller_state.last_purchased

		if not candidate then
			return localize("auto_crafter_panel_phase_2_waiting", "No purchased candidate")
		end

		return string.format("%s | %s", value_text(candidate.display_name, candidate.mastery_id or "weapon"), value_text(candidate.gear_id, "gear ?"))
	end

	function self:_split_offers(offers)
		local grouped = {
			[SECTION_MELEE] = {},
			[SECTION_RANGED] = {},
		}

		for _, offer in ipairs(offers or {}) do
			if offer then
				local section_id = offer.weapon_category == SECTION_RANGED and SECTION_RANGED or SECTION_MELEE

				grouped[section_id][#grouped[section_id] + 1] = offer
			end
		end

		return grouped
	end

	function self:_select_offer_from_row(offer)
		if not offer then
			return false
		end

		self._selected_offer = offer
		self._selected_offer_key = offer_selection_key(offer)
		self._selected_offer_id = offer.offer_id
		self._selected_offer_master_id = offer.master_id
		if self._pending_offer ~= offer then
			self._pending_offer_attempts = 0
		end

		self._pending_offer = offer
		self._pending_offer_attempts = self._pending_offer_attempts + 1

		if self._pending_offer_attempts > MAX_SELECTION_ATTEMPTS then
			log("error", "Auto Crafter native offer selection timed out; leaving native selection unchanged.")
			self._pending_offer = nil
			self._pending_offer_attempts = 0

			return false
		end
		if type(self._select_offer) ~= "function" then
			return false
		end

		local ok, selected = pcall(self._select_offer, self._view, offer)

		if not ok then
			log("error", "Auto Crafter native offer selection failed: " .. tostring(selected))

			return false
		end

		if selected == true then
			self._pending_offer = nil
			self._pending_offer_attempts = 0
		end

		return selected == true
	end

	function self:_entries(snapshot)
		local store = snapshot and snapshot.store or {}
		local offers, selected_weapon = self:_selected_offers(snapshot)
		local grouped_offers = self:_split_offers(offers)
		local selected = selected_weapon or localize("auto_crafter_panel_no_target", "no weapon selected")
		local plan = self._plan or snapshot and snapshot.plan
		local entries = {
			self:_entry(localize("auto_crafter_panel_title", "Auto Crafter Helper"), self:_setting("auto_crafter_allow_mutations", false) == true and localize("auto_crafter_panel_mutations_on", "SERIAL MUTATIONS ON") or localize("auto_crafter_panel_mutations_off", "MUTATIONS OFF"), {
				variant = "title",
				refresh = function(widget)
					widget.content.detail = self:_mutation_gate_text()
				end,
			}),
			self:_entry(localize("auto_crafter_panel_status", "Status"), self._phase or value_text(snapshot and snapshot.phase, "idle"), {
				refresh = function(widget)
					widget.content.detail = self._phase or value_text(self._controller_state and self._controller_state.phase, "idle")
				end,
			}),
			self:_entry(localize("auto_crafter_panel_wallet", "Resources"), string.format("%s  |  %s  |  %s", integer_text(wallet_amount(snapshot, "credits")), integer_text(wallet_amount(snapshot, "plasteel")), integer_text(wallet_amount(snapshot, "diamantine")))),
			self:_entry(localize("auto_crafter_panel_inventory", "Inventory"), string.format("%s: %s  |  %s: %s", localize("auto_crafter_panel_offers", "Offers"), value_text(store.offer_count, "?"), localize("auto_crafter_panel_gear", "Gear"), value_text(snapshot and snapshot.gear and snapshot.gear.item_count, "?"))),
			self:_entry(localize("auto_crafter_panel_target", "Target"), selected, {
				refresh = function(widget)
					local _, current_weapon = self:_selected_offers(self._snapshot)

					widget.content.detail = current_weapon or localize("auto_crafter_panel_no_target", "no weapon selected")
				end,
			}),
			self:_entry(localize("auto_crafter_panel_planner", "Planner configuration"), "", {
				selectable = true,
				section_header = true,
				section_id = SECTION_PLANNER,
				variant = "section",
			}),
		}
		local function add_checkbox(setting_id, label_id, fallback, default_value, enabled, reflow)
			local function is_enabled()
				if type(enabled) == "function" then
					return enabled() == true
				end

				return enabled ~= false
			end
			local initial_enabled = is_enabled()
			table.insert(entries, self:_entry(localize(label_id, fallback), "", {
				checked = self:_setting(setting_id, default_value) == true,
				enabled = initial_enabled,
				selectable = initial_enabled,
				variant = "checkbox",
				action = function()
					self:_set_setting(setting_id, not (self:_setting(setting_id, default_value) == true))
					if reflow then
						self._layout_pending = true
					end
				end,
				refresh = function(widget)
					local current_enabled = is_enabled()
					widget.content.checked = self:_setting(setting_id, default_value) == true
					widget.content.enabled = current_enabled
					widget.content.hotspot.disabled = not current_enabled
				end,
			}))
		end
		local function add_target_selector(setting_id, label_id, fallback, enabled, unavailable_text)
			local function is_enabled()
				if type(enabled) == "function" then
					return enabled() == true
				end

				return enabled ~= false
			end
			local initial_enabled = is_enabled()
			table.insert(entries, self:_entry(localize(label_id, fallback), initial_enabled and self:_target_policy_text(setting_id) or unavailable_text, {
				enabled = initial_enabled,
				selectable = initial_enabled,
				variant = "selector",
				action = function()
					self:_cycle_setting(setting_id, { "keep", "auto" }, "keep")
				end,
				refresh = function(widget)
					local current_enabled = is_enabled()
					widget.content.enabled = current_enabled
					widget.content.detail = current_enabled and self:_target_policy_text(setting_id) or unavailable_text
					widget.content.hotspot.disabled = not current_enabled
				end,
			}))
		end

		if not self._section_collapsed[SECTION_PLANNER] then
			table.insert(entries, self:_entry(localize("auto_crafter_panel_planner_target", "Planner target"), self:_planner_target_text(), {
				refresh = function(widget)
					widget.content.detail = self:_planner_target_text()
				end,
			}))
			table.insert(entries, self:_entry(localize("auto_crafter_panel_dump_stat", "Dump stat"), self:_planner_dump_stat_text(), {
				selectable = true,
				variant = "enum_stepper",
				decrease = function()
					self:_step_enum_setting("auto_crafter_target_dump_stat", { "damage", "auto" }, "auto", -1)
				end,
				increase = function()
					self:_step_enum_setting("auto_crafter_target_dump_stat", { "damage", "auto" }, "auto", 1)
				end,
				refresh = function(widget)
					widget.content.detail = self:_planner_dump_stat_text()
				end,
			}))
			table.insert(entries, self:_entry(localize("auto_crafter_panel_dump_target", "Dump target"), integer_text(self:_setting("auto_crafter_dump_stat_target", 60)), {
				selectable = true,
				variant = "stepper",
				decrease = function()
					self:_adjust_numeric_setting("auto_crafter_dump_stat_target", 60, 1, 100, -1)
				end,
				increase = function()
					self:_adjust_numeric_setting("auto_crafter_dump_stat_target", 60, 1, 100, 1)
				end,
				refresh = function(widget)
					widget.content.detail = integer_text(self:_setting("auto_crafter_dump_stat_target", 60))
				end,
			}))
			add_checkbox("auto_crafter_cap_by_dockets", "auto_crafter_cap_by_dockets", "Cap perfect-roll weapon acquisition by Ordo dockets", false, nil, true)
			if self:_setting("auto_crafter_cap_by_dockets", false) == true then
				table.insert(entries, self:_entry(localize("auto_crafter_panel_docket_cap", "Ordo dockets cap"), integer_text(self:_setting("auto_crafter_docket_cap", 1000000)), {
					selectable = true,
					variant = "stepper",
					decrease = function()
						self:_adjust_numeric_setting("auto_crafter_docket_cap", 1000000, 0, 10000000, -100000)
					end,
					increase = function()
						self:_adjust_numeric_setting("auto_crafter_docket_cap", 1000000, 0, 10000000, 100000)
					end,
					refresh = function(widget)
						widget.content.detail = integer_text(self:_setting("auto_crafter_docket_cap", 1000000))
					end,
				}))
			end
			add_checkbox("auto_crafter_cap_by_max_purchases", "auto_crafter_cap_by_max_purchases", "Cap perfect-roll weapon acquisition by max purchases", false, nil, true)
			if self:_setting("auto_crafter_cap_by_max_purchases", false) == true then
				table.insert(entries, self:_entry(localize("auto_crafter_panel_max_purchases", "Max purchases"), integer_text(self:_setting("auto_crafter_max_purchases", 100)), {
					selectable = true,
					variant = "stepper",
					decrease = function()
						self:_adjust_numeric_setting("auto_crafter_max_purchases", 100, 1, 10000, -1)
					end,
					increase = function()
						self:_adjust_numeric_setting("auto_crafter_max_purchases", 100, 1, 10000, 1)
					end,
					refresh = function(widget)
						widget.content.detail = integer_text(self:_setting("auto_crafter_max_purchases", 100))
					end,
				}))
			end
			table.insert(entries, self:_entry(localize("auto_crafter_panel_best_fallback", "Best-candidate fallback"), self:_planner_fallback_text(), {
				checked = self:_setting("auto_crafter_best_candidate_fallback", false) == true,
				selectable = true,
				variant = "checkbox",
				action = function()
					self:_set_setting("auto_crafter_best_candidate_fallback", not (self:_setting("auto_crafter_best_candidate_fallback", false) == true))
				end,
				refresh = function(widget)
					widget.content.checked = self:_setting("auto_crafter_best_candidate_fallback", false) == true
				end,
			}))
			table.insert(entries, self:_entry(localize("auto_crafter_panel_estimate", "Estimate"), plan and plan.estimate and plan.estimate.summary or localize("auto_crafter_panel_waiting", "waiting for probe"), {
				variant = "status",
				refresh = function(widget)
					local current_plan = self._plan

					widget.content.detail = current_plan and current_plan.estimate and current_plan.estimate.summary or localize("auto_crafter_panel_waiting", "waiting for probe")
				end,
			}))
			table.insert(entries, self:_entry(localize("auto_crafter_panel_preflight", "Preflight"), plan and plan.preflight and plan.preflight.summary or localize("auto_crafter_panel_waiting", "waiting for probe"), {
				variant = "status",
				refresh = function(widget)
					local current_plan = self._plan

					widget.content.detail = current_plan and current_plan.preflight and current_plan.preflight.summary or localize("auto_crafter_panel_waiting", "waiting for probe")
				end,
			}))
		end

		table.insert(entries, self:_entry(localize("auto_crafter_panel_workflow", "Crafting workflow"), localize("auto_crafter_panel_ui_plan", "UI PLAN"), {
			selectable = true,
			section_header = true,
			section_id = SECTION_WORKFLOW,
			variant = "section",
		}))

		if not self._section_collapsed[SECTION_WORKFLOW] then
			table.insert(entries, self:_entry(localize("auto_crafter_panel_saved_only", "Saved configuration"), localize("auto_crafter_panel_not_connected", "Later phases will connect these options."), {
				variant = "status",
			}))
			add_checkbox("auto_crafter_buy_until_target", "auto_crafter_buy_until_target", "Buy until dump-stat target", true)
			add_checkbox("auto_crafter_level_mastery_20", "auto_crafter_level_mastery_20", "Level weapon mastery to 20", false)
			add_checkbox("auto_crafter_allocate_mastery_points", "auto_crafter_allocate_mastery_points", "Allocate mastery points", false, function()
				return self:_setting("auto_crafter_level_mastery_20", false) == true
			end)
			add_checkbox("auto_crafter_consecrate_transcendent", "auto_crafter_consecrate_transcendent", "Consecrate to Transcendent", true)
			add_checkbox("auto_crafter_upgrade_expertise_500", "auto_crafter_upgrade_expertise_500", "Upgrade expertise to 500", true)
			add_checkbox("auto_crafter_change_perks", "auto_crafter_change_perks", "Change perks", false)
			add_checkbox("auto_crafter_change_blessings", "auto_crafter_change_blessings", "Change blessings", false, function()
				return self:_setting("auto_crafter_level_mastery_20", false) == true
			end)
		end

		table.insert(entries, self:_entry(localize("auto_crafter_panel_trait_targets", "Perk and blessing targets"), localize("auto_crafter_panel_ui_plan", "UI PLAN"), {
			selectable = true,
			section_header = true,
			section_id = SECTION_TRAITS,
			variant = "section",
		}))

		if not self._section_collapsed[SECTION_TRAITS] then
			local unavailable = localize("auto_crafter_panel_option_unavailable", "Enable prerequisite options")
			add_target_selector("auto_crafter_perk_1_target", "auto_crafter_perk_1_target", "Perk target 1", function()
				return self:_setting("auto_crafter_change_perks", false) == true
			end, unavailable)
			add_target_selector("auto_crafter_perk_2_target", "auto_crafter_perk_2_target", "Perk target 2", function()
				return self:_setting("auto_crafter_change_perks", false) == true
			end, unavailable)
			local function blessing_targets_enabled()
				return self:_setting("auto_crafter_level_mastery_20", false) == true and self:_setting("auto_crafter_allocate_mastery_points", false) == true and self:_setting("auto_crafter_change_blessings", false) == true
			end
			add_target_selector("auto_crafter_blessing_1_target", "auto_crafter_blessing_1_target", "Blessing target 1", blessing_targets_enabled, unavailable)
			add_target_selector("auto_crafter_blessing_2_target", "auto_crafter_blessing_2_target", "Blessing target 2", blessing_targets_enabled, unavailable)
		end

		table.insert(entries, self:_entry(localize("auto_crafter_panel_output", "Final item handling"), localize("auto_crafter_panel_ui_plan", "UI PLAN"), {
			selectable = true,
			section_header = true,
			section_id = SECTION_OUTPUT,
			variant = "section",
		}))

		if not self._section_collapsed[SECTION_OUTPUT] then
			add_checkbox("auto_crafter_favorite_result", "auto_crafter_favorite_result", "Favorite final weapon", true)
			add_checkbox("auto_crafter_rename_result", "auto_crafter_rename_result", "Rename final weapon", false)
			table.insert(entries, self:_entry(localize("auto_crafter_panel_result_name", "Result name"), localize("auto_crafter_panel_name_provider_later", "Naming provider connection planned")))
		end

		table.insert(entries, self:_entry(localize("auto_crafter_panel_advanced", "Advanced and safety"), "", {
			selectable = true,
			section_header = true,
			section_id = SECTION_ADVANCED,
			variant = "section",
		}))

		if not self._section_collapsed[SECTION_ADVANCED] then
			local request_modes = { "sequential", "parallel_reads", "experimental_parallel_mutations" }
			table.insert(entries, self:_entry(localize("auto_crafter_panel_request_mode", "Request mode"), self:_planner_request_mode_text(), {
				selectable = true,
				variant = "enum_stepper",
				decrease = function()
					self:_step_enum_setting("auto_crafter_request_mode", request_modes, "sequential", -1)
				end,
				increase = function()
					self:_step_enum_setting("auto_crafter_request_mode", request_modes, "sequential", 1)
				end,
				refresh = function(widget)
					widget.content.detail = self:_planner_request_mode_text()
				end,
			}))
			add_checkbox("auto_crafter_allow_mutations", "auto_crafter_panel_mutation_gate", "Mutation gate", false)
		end

		table.insert(entries, self:_entry(localize("auto_crafter_panel_preview", "Craft / purchase search"), self:_setting("auto_crafter_allow_mutations", false) == true and localize("auto_crafter_panel_serial_start", "SERIAL; click to start") or localize("auto_crafter_panel_read_only_preview", "Read-only preview"), {
			enabled = true,
			selectable = true,
			variant = "action",
			action = function()
				if self:_setting("auto_crafter_allow_mutations", false) == true and type(self._start_purchase_search) == "function" then
					self._start_purchase_search()
				elseif type(self._preview_plan) == "function" then
					self._preview_plan()
				end
			end,
			refresh = function(widget)
				local enabled = self:_setting("auto_crafter_allow_mutations", false) == true
				widget.content.enabled = true
				widget.content.hotspot.disabled = false
				widget.content.detail = enabled and localize("auto_crafter_panel_serial_start", "SERIAL; click to start") or localize("auto_crafter_panel_read_only_preview", "Read-only preview")
			end,
		}))
		table.insert(entries, self:_entry(localize("auto_crafter_panel_phase_2", "Redeem + sacrifice one"), self:_last_candidate_text(), {
			enabled = self._controller_state and self._controller_state.last_purchased ~= nil and self:_setting("auto_crafter_allow_mutations", false) == true,
			selectable = true,
			variant = "action",
			action = function()
				if type(self._start_mastery_operation) == "function" then
					self._start_mastery_operation()
				end
			end,
			refresh = function(widget)
				local enabled = self._controller_state and self._controller_state.last_purchased ~= nil and self:_setting("auto_crafter_allow_mutations", false) == true
				widget.content.enabled = enabled
				widget.content.hotspot.disabled = not enabled
				widget.content.detail = self:_last_candidate_text()
			end,
		}))

		table.insert(entries, self:_entry(localize("auto_crafter_panel_offer_list", "Weapon selection"), tostring(#offers)))

		for _, section_id in ipairs({ SECTION_MELEE, SECTION_RANGED }) do
			local section_offers = grouped_offers[section_id]
			local section_label = section_id == SECTION_RANGED and localize("auto_crafter_panel_ranged_weapons", "Ranged Weapons") or localize("auto_crafter_panel_melee_weapons", "Melee Weapons")

			table.insert(entries, self:_entry(section_label, tostring(#section_offers), {
				selectable = true,
				section_header = true,
				section_id = section_id,
				variant = "section",
			}))

			if not self._section_collapsed[section_id] then
				local shown = 0

				for index, offer in ipairs(section_offers) do
					if shown >= MAX_OFFER_ROWS then
						break
					end

					shown = shown + 1
					table.insert(entries, self:_entry(offer_label(offer, index), offer_detail(offer), {
						offer = offer,
						selectable = true,
						variant = "offer",
					}))
				end

				if shown == 0 then
					table.insert(entries, self:_entry(localize("auto_crafter_panel_no_offers", "No weapon offers exposed yet."), ""))
				elseif #section_offers > shown then
					table.insert(entries, self:_entry(localize("auto_crafter_panel_more", "More offers available"), tostring(#section_offers - shown) .. " not shown"))
				end
			end
		end

		return entries
	end

	function self:render(snapshot)
		self._snapshot = snapshot or self._snapshot

		if not self._panel or type(self._panel.present_grid_layout) ~= "function" then
			return false
		end

		local entries = self:_entries(self._snapshot)

		local height_ok = safe_call(self._panel.update_grid_height, self._panel, PANEL_HEIGHT, PANEL_HEIGHT)

		if not height_ok then
			log("error", "Auto Crafter diagnostic panel could not set its grid height.")
		end

		local function on_row_clicked(_, entry)
			if entry and entry.offer then
				self:_select_offer_from_row(entry.offer)
			end
		end

		local present_ok, present_error = safe_call(self._panel.present_grid_layout, self._panel, entries, BLUEPRINTS, on_row_clicked)

		if not present_ok then
			log("error", "Auto Crafter diagnostic panel could not present layout: " .. tostring(present_error))
		end

		return present_ok
	end

	function self:set_phase(phase, snapshot)
		self._phase = phase or self._phase

		return self:render(snapshot)
	end

	function self:sync_controller_snapshot(state)
		if type(state) ~= "table" then
			return false
		end

		self._controller_state = state
		self._phase = state.phase or self._phase
		self._snapshot = state.data or self._snapshot
		self._plan = state.plan

		return true
	end

	function self:update()
		if not self._view or self._view._destroyed or type(self._get_selected_offer) ~= "function" then
			return
		end

		local ok, raw_offer = pcall(self._get_selected_offer, self._view)
		local selected_offer

		if ok and raw_offer then
			selected_offer = {
				offer_id = safe_member(raw_offer, "offerId") or safe_member(raw_offer, "offer_id"),
				master_id = safe_member(raw_offer, "masterId") or safe_member(raw_offer, "master_id"),
			}

			local description = safe_member(raw_offer, "description")
			local choices = safe_member(description, "lootChoices") or safe_member(description, "loot_choices")
			local choice = type(choices) == "table" and choices[1] or nil

			if selected_offer.master_id == nil then
				if type(choice) == "table" then
					selected_offer.master_id = choice.masterId or choice.master_id or choice.id or choice.name
				else
					selected_offer.master_id = choice
				end
			end

			if selected_offer.offer_id == nil and selected_offer.master_id == nil then
				selected_offer = nil
			end
		end

		local selected_key = offer_selection_key(selected_offer)

		if self._pending_offer then
			local native_selected_key = selected_key

			if native_selected_key == offer_selection_key(self._pending_offer) then
				self._pending_offer = nil
				self._pending_offer_attempts = 0
			else
				self:_select_offer_from_row(self._pending_offer)

				return
			end
		end

		if selected_key ~= self._selected_offer_key then
			self._selected_offer = selected_offer
			self._selected_offer_key = selected_key
			self._selected_offer_id = selected_offer and selected_offer.offer_id
			self._selected_offer_master_id = selected_offer and selected_offer.master_id
		end

		if self._layout_pending then
			self._layout_pending = false
			self:render()
		end
	end

	function self:attach(view)
		if not view or view._destroyed or type(view._add_element) ~= "function" or type(self._ViewElementGrid) ~= "table" then
			return false
		end

		if self._view == view and self._panel then
			self._panel:set_visibility(true)
			return self:render()
		end

		self:detach()

		local menu_settings = {
			bottom_chin = CONTENT_VERTICAL_PADDING,
			edge_padding = CONTENT_HORIZONTAL_PADDING * 2,
			enable_gamepad_scrolling = true,
			grid_size = {
				PANEL_WIDTH - CONTENT_HORIZONTAL_PADDING * 2,
				PANEL_HEIGHT,
			},
			grid_spacing = {
				0,
				ROW_SPACING,
			},
			ignore_blur = true,
			mask_size = {
				PANEL_WIDTH,
				PANEL_HEIGHT,
			},
			reference_name = PANEL_REFERENCE,
			reset_selection_on_navigation_change = false,
			scrollbar_width = 7,
			title_height = 0,
			top_padding = CONTENT_VERTICAL_PADDING,
			use_is_focused_for_navigation = false,
			use_select_on_focused = true,
			use_terminal_background = true,
		}

		local ok, panel = safe_call(view._add_element, view, self._ViewElementGrid, PANEL_REFERENCE, 30, menu_settings)

		if not ok or not panel then
			log("error", "Auto Crafter diagnostic panel could not initialize: " .. tostring(panel))

			return false
		end

		self._view = view
		self._panel = panel
		self._snapshot = nil
		self._controller_state = nil
		self._plan = nil
		self._phase = "view_ready"
		self._selected_offer_id = nil
		self._selected_offer_key = nil
		self._selected_offer = nil
		self._selected_offer_master_id = nil
		self._section_collapsed = {
			[SECTION_PLANNER] = false,
			[SECTION_WORKFLOW] = false,
			[SECTION_TRAITS] = true,
			[SECTION_OUTPUT] = true,
			[SECTION_ADVANCED] = true,
			[SECTION_MELEE] = true,
			[SECTION_RANGED] = true,
		}
		self._pending_offer = nil
		self._pending_offer_attempts = 0
		self._layout_pending = false

		if type(panel.set_pivot_offset) == "function" then
			panel:set_pivot_offset(PANEL_X, PANEL_Y)
		end

		if type(panel.disable_input) == "function" then
			panel:disable_input(false)
		end

		if type(panel.set_visibility) == "function" then
			panel:set_visibility(true)
		end

		return self:render()
	end

	function self:detach()
		local view = self._view

		if view and not view._destroyed and type(view._remove_element) == "function" then
			pcall(view._remove_element, view, PANEL_REFERENCE)
		end

		self._view = nil
		self._panel = nil
		self._snapshot = nil
		self._controller_state = nil
		self._plan = nil
		self._phase = "idle"
		self._selected_offer_id = nil
		self._selected_offer_key = nil
		self._selected_offer = nil
		self._selected_offer_master_id = nil
		self._section_collapsed = {
			[SECTION_PLANNER] = false,
			[SECTION_MELEE] = true,
			[SECTION_RANGED] = true,
		}
		self._pending_offer = nil
		self._pending_offer_attempts = 0
		self._layout_pending = false
	end

	return self
end

Panel.PANEL_REFERENCE = PANEL_REFERENCE

return Panel
