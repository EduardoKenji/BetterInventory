local ItemCustomization = {}

local STORAGE_SETTING_ID = "custom_item_name_and_colors"
local NAME_COLOR_SETTING_ID = "custom_item_name_color_picker_value"
local BACKGROUND_COLOR_SETTING_ID = "custom_item_background_color_picker_value"
local DEFAULT_NAME_COLOR = {
	255,
	220,
	230,
	210,
}
local DEFAULT_BACKGROUND_COLOR = {
	255,
	45,
	55,
	45,
}

local function clone_color(color, fallback)
	local source = type(color) == "table" and color or fallback

	return {
		255,
		math.max(0, math.min(255, math.floor(tonumber(source[2]) or fallback[2]))),
		math.max(0, math.min(255, math.floor(tonumber(source[3]) or fallback[3]))),
		math.max(0, math.min(255, math.floor(tonumber(source[4]) or fallback[4]))),
	}
end

local function customization_records(mod)
	local records = mod:get(STORAGE_SETTING_ID)

	return type(records) == "table" and records or {}
end

ItemCustomization.get = function(mod, gear_id)
	local record = gear_id and customization_records(mod)[gear_id]

	return type(record) == "table" and record or nil
end

ItemCustomization.update = function(mod, gear_id, changes)
	if type(gear_id) ~= "string" or gear_id == "" or type(changes) ~= "table" then
		return false
	end

	local records = customization_records(mod)
	local record = type(records[gear_id]) == "table" and records[gear_id] or {}

	if changes.name ~= nil then
		record.name = type(changes.name) == "string" and changes.name ~= "" and changes.name or nil
	end

	if changes.name_color ~= nil then
		record.name_color = changes.name_color ~= false and clone_color(changes.name_color, DEFAULT_NAME_COLOR) or nil
	end

	if changes.background_color ~= nil then
		record.background_color = changes.background_color ~= false and clone_color(changes.background_color, DEFAULT_BACKGROUND_COLOR) or nil
	end

	if record.name == nil and record.name_color == nil and record.background_color == nil then
		records[gear_id] = nil
	else
		records[gear_id] = record
	end

	mod:set(STORAGE_SETTING_ID, records, false)

	return true
end

ItemCustomization.remove = function(mod, gear_id)
	local records = customization_records(mod)

	if gear_id == nil or records[gear_id] == nil then
		return false
	end

	records[gear_id] = nil
	mod:set(STORAGE_SETTING_ID, records, false)

	return true
end

local function color_picker_blueprints(width, picker)
	local SliderPassTemplates = require("scripts/ui/pass_templates/slider_pass_templates")
	local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
	local slider_height = 52
	local slider_passes = SliderPassTemplates.value_slider(width, slider_height, 120, true)
	local preview_text_style = table.clone(UIFontSettings.body)

	preview_text_style.font_size = 18
	preview_text_style.text_horizontal_alignment = "center"
	preview_text_style.text_vertical_alignment = "center"
	preview_text_style.text_color = Color.white(255, true)
	preview_text_style.offset = {
		0,
		0,
		4,
	}

	return {
		color_slider = {
			size = {
				width,
				slider_height,
			},
			pass_template = slider_passes,
			init = function(parent, widget, element)
				local content = widget.content
				local value = picker.draft[element.channel]

				content.element = element
				content.slider_value = value / 255
				content.previous_slider_value = content.slider_value
				content.step_size = 1 / 255
				content.value_text = string.format("%s: %d", element.label, value)
				content.better_inventory_picker_revision = picker.revision
			end,
			update = function(parent, widget)
				local content = widget.content
				local element = content.element

				if content.better_inventory_picker_revision ~= picker.revision then
					content.slider_value = picker.draft[element.channel] / 255
					content.previous_slider_value = content.slider_value
					content.scroll_add = nil
					content.better_inventory_picker_revision = picker.revision
				end

				local value = math.max(0, math.min(255, math.floor((content.slider_value or 0) * 255 + 0.5)))

				picker.draft[element.channel] = value
				content.value_text = string.format("%s: %d", element.label, value)
			end,
		},
		color_preview = {
			size = {
				width,
				110,
			},
			pass_template = {
				{
					pass_type = "rect",
					style_id = "frame",
					style = {
						color = Color.terminal_corner_hover(255, true),
						offset = {
							0,
							0,
							1,
						},
					},
				},
				{
					pass_type = "rect",
					style_id = "preview",
					style = {
						color = clone_color(picker.draft, picker.default),
						offset = {
							4,
							4,
							2,
						},
						size_addition = {
							-8,
							-8,
						},
					},
					change_function = function(content, style)
						style.color[2] = picker.draft[2]
						style.color[3] = picker.draft[3]
						style.color[4] = picker.draft[4]
					end,
				},
				{
					pass_type = "text",
					style_id = "text",
					value = "",
					value_id = "text",
					style = preview_text_style,
				},
			},
			init = function(parent, widget)
				widget.content.text = "RGB preview"
			end,
		},
	}
end

local function show_color_picker(mod, target)
	local is_background = target == "background"
	local setting_id = is_background and BACKGROUND_COLOR_SETTING_ID or NAME_COLOR_SETTING_ID
	local default_color = is_background and DEFAULT_BACKGROUND_COLOR or DEFAULT_NAME_COLOR
	local picker = {
		default = clone_color(default_color, default_color),
		draft = clone_color(mod:get(setting_id), default_color),
		revision = 0,
	}
	local settings_ok, popup_settings = pcall(require, "scripts/ui/constant_elements/elements/popup_handler/constant_element_popup_handler_settings")
	local width = settings_ok and popup_settings.text_max_width or 800
	local grid_layout = {
		{
			widget_type = "color_preview",
		},
		{
			widget_type = "color_slider",
			channel = 2,
			label = "Red",
		},
		{
			widget_type = "color_slider",
			channel = 3,
			label = "Green",
		},
		{
			widget_type = "color_slider",
			channel = 4,
			label = "Blue",
		},
	}
	local context = {
		title_text = is_background and "custom_item_background_color_picker_title" or "custom_item_name_color_picker_title",
		type = "grid",
		grid_layout = grid_layout,
		grid_blueprints = color_picker_blueprints(width, picker),
		description_text_params = {},
		options = {
			{
				text = "custom_item_color_picker_confirm",
				close_on_pressed = true,
				callback = function()
					mod:set(setting_id, clone_color(picker.draft, default_color), false)
				end,
			},
			{
				text = "custom_item_color_picker_restore_default",
				close_on_pressed = false,
				callback = function()
					picker.draft = clone_color(default_color, default_color)
					picker.revision = picker.revision + 1
				end,
			},
			{
				text = "custom_item_color_picker_cancel",
				template_type = "terminal_button_small",
				close_on_pressed = true,
				hotkey = "back",
			},
		},
	}
	local event_manager = Managers and Managers.event

	if not event_manager or type(event_manager.trigger) ~= "function" then
		return false
	end

	local ok = pcall(event_manager.trigger, event_manager, "event_show_ui_popup", context)

	return ok
end

ItemCustomization.on_enabled = function(mod)
	if type(mod:get(STORAGE_SETTING_ID)) ~= "table" then
		mod:set(STORAGE_SETTING_ID, {}, false)
	end
end

ItemCustomization.on_setting_changed = function(mod, setting_id)
	local target

	if setting_id == "custom_item_name_color_picker_spike" and mod:get(setting_id) == true then
		target = "name"
	elseif setting_id == "custom_item_background_color_picker_spike" and mod:get(setting_id) == true then
		target = "background"
	end

	if not target then
		return false
	end

	mod:set(setting_id, false, false)

	return show_color_picker(mod, target)
end

ItemCustomization.show_color_picker = show_color_picker

return ItemCustomization
