local ItemCustomization = {}
local Items = require("scripts/utilities/items")

local STORAGE_SETTING_ID = "custom_item_name_and_colors"
local INPUT_WIDGET_ID = "better_inventory_name_input"
local DEFAULT_NAME_COLOR = { 255, 220, 230, 210 }
local DEFAULT_BACKGROUND_COLOR = { 255, 45, 55, 45 }
local cached_records = {}
local pending_action
local input_widget
local show_input_field = false
local installed = false

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

local function save_records(mod, records)
	cached_records = records
	mod:set(STORAGE_SETTING_ID, records, false)
end

local function name_it_mod()
	local resolver = rawget(_G, "get_mod")

	if type(resolver) ~= "function" then
		return
	end

	local ok, other_mod = pcall(resolver, "name_it")

	return ok and type(other_mod) == "table" and other_mod or nil
end

local function name_it_names()
	local other_mod = name_it_mod()

	if not other_mod then
		return
	end

	local ok, names

	if type(other_mod.get_custom_name_list) == "function" then
		ok, names = pcall(other_mod.get_custom_name_list)
	elseif type(other_mod.get) == "function" then
		ok, names = pcall(other_mod.get, other_mod, "name_list")
	end

	return other_mod, ok and type(names) == "table" and names or {}
end

local function sync_name_to_name_it(gear_id, name)
	local other_mod, names = name_it_names()

	if not other_mod or type(other_mod.set) ~= "function" then
		return false
	end

	names[gear_id] = type(name) == "string" and name ~= "" and name or nil
	pcall(other_mod.set, other_mod, "name_list", names, false)

	return true
end

ItemCustomization.get = function(mod, gear_id)
	local record = gear_id and cached_records[gear_id]

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
		sync_name_to_name_it(gear_id, record.name)
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

	save_records(mod, records)

	return true
end

ItemCustomization.remove = function(mod, gear_id)
	local records = customization_records(mod)

	if gear_id == nil or records[gear_id] == nil then
		return false
	end

	records[gear_id] = nil
	save_records(mod, records)
	sync_name_to_name_it(gear_id, nil)

	return true
end

ItemCustomization.import_name_it_names = function(mod)
	if mod:get("enable_custom_item_name_and_colors") == false then
		return 0
	end

	local other_mod, names = name_it_names()

	if not other_mod then
		return 0
	end

	local records = customization_records(mod)
	local imported = 0
	local records_changed = false
	local names_changed = false
	local replace_pattern_name = type(other_mod.get) == "function" and other_mod:get("replace_pattern_name") == true

	for gear_id, external_name in pairs(names) do
		if type(gear_id) == "string" and type(external_name) == "string" and external_name ~= "" then
			local record = type(records[gear_id]) == "table" and records[gear_id] or {}

			if type(record.name) ~= "string" or record.name == "" then
				record.name = external_name
				record.name_target = replace_pattern_name and "sub" or "primary"
				records[gear_id] = record
				imported = imported + 1
				records_changed = true
			elseif record.name ~= external_name then
				names[gear_id] = record.name
				names_changed = true
			end
		end
	end

	for gear_id, record in pairs(records) do
		local internal_name = type(record) == "table" and record.name

		if type(internal_name) == "string" and internal_name ~= "" and names[gear_id] ~= internal_name then
			names[gear_id] = internal_name
			names_changed = true
		end
	end

	if records_changed then
		save_records(mod, records)
	else
		cached_records = records
	end

	if names_changed and type(other_mod.set) == "function" then
		pcall(other_mod.set, other_mod, "name_list", names, false)
	end

	return imported
end

local function popup(context)
	local event_manager = Managers and Managers.event

	return event_manager and type(event_manager.trigger) == "function" and pcall(event_manager.trigger, event_manager, "event_show_ui_popup", context) or false
end

local function literal_button(text, callback, small, close_on_pressed)
	return {
		text = text,
		no_localization = true,
		template_type = small and "terminal_button_small" or nil,
		close_on_pressed = close_on_pressed ~= false,
		callback = callback,
	}
end

local function item_from_widget(widget)
	local element = widget and widget.content and widget.content.element

	return element and (element.real_item or element.item)
end

local function selected_context(mod, view)
	local widget = view and type(view.selected_grid_widget) == "function" and view:selected_grid_widget() or nil
	local item = item_from_widget(widget)

	if not item or type(item.gear_id) ~= "string" or item.gear_id == "" then
		return
	end

	local default_name
	local localize = rawget(_G, "Localize")

	if type(Items.is_weapon) == "function" and Items.is_weapon(item.item_type) and type(Items.weapon_lore_family_name) == "function" then
		local ok, value = pcall(Items.weapon_lore_family_name, item)
		default_name = ok and value or nil

		if default_name and mod:get("append_mark_to_name") ~= false and type(Items.weapon_lore_mark_name) == "function" then
			local mark_ok, mark_name = pcall(Items.weapon_lore_mark_name, item)

			if mark_ok and type(mark_name) == "string" and mark_name ~= "" and mark_name ~= "n/a" then
				default_name = default_name .. " " .. mark_name
			end
		end
	elseif type(item.display_name) == "string" and type(localize) == "function" then
		local ok, value = pcall(localize, item.display_name)
		default_name = ok and value or nil
	end

	return {
		view = view,
		widget = widget,
		item = item,
		gear_id = item.gear_id,
		name = widget.content.display_name or "Item",
		default_name = default_name or widget.content.display_name or "Item",
	}
end

local function refresh_item(mod, layout, context, refresh_name)
	if not context then
		return
	end

	local record = ItemCustomization.get(mod, context.gear_id)
	local content = context.widget and context.widget.content

	if content and refresh_name then
		local display_name = record and record.name or context.default_name

		content.display_name = display_name
		content.better_inventory_name_it_curio_name_text = display_name
	end

	if layout and type(layout.apply_item_customization_style) == "function" then
		layout.apply_item_customization_style(mod, context.widget, context.widget and context.widget.content and context.widget.content.element)
	end

	if refresh_name and context.view and type(context.view._preview_item) == "function" then
		pcall(context.view._preview_item, context.view, context.item)
	end
end

local function reset_field(mod, context, layout, field, label)
	local function reset()
		ItemCustomization.update(mod, context.gear_id, { [field] = false })
		refresh_item(mod, layout, context, field == "name")
	end

	if mod:get("custom_item_skip_confirmation_prompts") ~= false then
		reset()
		return
	end

	pending_action = function()
		popup({
			title_text_unlocalized = string.format("Reset %s (%s)?", label, context.name),
			description_text_unlocalized = "This restores the default value for this item.",
			options = {
				literal_button("Confirm", reset),
				literal_button("Cancel", nil, true),
			},
		})
	end
end

local function color_picker_blueprints(width, picker)
	local SliderPassTemplates = require("scripts/ui/pass_templates/slider_pass_templates")
	local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
	local slider_height = 52
	local preview_text_style = table.clone(UIFontSettings.body)

	preview_text_style.font_size = 18
	preview_text_style.text_horizontal_alignment = "center"
	preview_text_style.text_vertical_alignment = "center"
	preview_text_style.text_color = Color.white(255, true)
	preview_text_style.offset = { 0, 0, 4 }

	return {
		color_slider = {
			size = { width, slider_height },
			pass_template = SliderPassTemplates.value_slider(width, slider_height, 120, true),
			init = function(_, widget, element)
				local content = widget.content
				local value = picker.draft[element.channel]

				content.element = element
				content.slider_value = value / 255
				content.previous_slider_value = content.slider_value
				content.step_size = 1 / 255
				content.value_text = string.format("%s: %d", element.label, value)
				content.better_inventory_picker_revision = picker.revision
			end,
			update = function(_, widget)
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
			size = { width, 110 },
			pass_template = {
				{ pass_type = "rect", style_id = "frame", style = { color = Color.terminal_corner_hover(255, true), offset = { 0, 0, 1 } } },
				{
					pass_type = "rect",
					style_id = "preview",
					style = { color = clone_color(picker.draft, picker.default), offset = { 4, 4, 2 }, size_addition = { -8, -8 } },
					change_function = function(_, style)
						style.color[2], style.color[3], style.color[4] = picker.draft[2], picker.draft[3], picker.draft[4]
					end,
				},
				{ pass_type = "text", style_id = "text", value = "", value_id = "text", style = preview_text_style },
			},
			init = function(_, widget) widget.content.text = "RGB preview" end,
		},
	}
end

local function show_color_picker(mod, target, context, layout)
	local is_background = target == "background"
	local field = is_background and "background_color" or "name_color"
	local default_color = is_background and DEFAULT_BACKGROUND_COLOR or DEFAULT_NAME_COLOR
	local record = context and ItemCustomization.get(mod, context.gear_id)
	local picker = {
		default = clone_color(default_color, default_color),
		draft = clone_color(record and record[field], default_color),
		revision = 0,
	}
	local settings_ok, popup_settings = pcall(require, "scripts/ui/constant_elements/elements/popup_handler/constant_element_popup_handler_settings")
	local width = settings_ok and popup_settings.text_max_width or 800
	local item_name = context and context.name or "Item"
	local title = string.format(is_background and "Change item background color(%s)" or "Change item name color(%s)", item_name)
	local function confirm()
		if context then
			ItemCustomization.update(mod, context.gear_id, { [field] = clone_color(picker.draft, default_color) })
			refresh_item(mod, layout, context, false)
		end
	end

	return popup({
		title_text_unlocalized = title,
		type = "grid",
		grid_layout = {
			{ widget_type = "color_preview" },
			{ widget_type = "color_slider", channel = 2, label = "Red" },
			{ widget_type = "color_slider", channel = 3, label = "Green" },
			{ widget_type = "color_slider", channel = 4, label = "Blue" },
		},
		grid_blueprints = color_picker_blueprints(width, picker),
		description_text_params = {},
		options = {
			literal_button("Confirm", confirm),
			literal_button("Reset to default", function()
				if context then reset_field(mod, context, layout, field, is_background and "background color" or "name color") end
			end),
			literal_button("Cancel", nil, true),
		},
	})
end

local function close_input()
	if input_widget and input_widget.content then
		input_widget.content.is_writing = false
	end

	show_input_field = false
end

local function show_name_editor(mod, context, layout)
	if not input_widget or not input_widget.content then
		return false
	end

	local record = ItemCustomization.get(mod, context.gear_id)
	input_widget.content.input_text = record and record.name or context.name or ""
	show_input_field = true

	return popup({
		title_text_unlocalized = string.format("Change item name (%s)", context.name),
		description_text_unlocalized = "Enter a custom name. Leave it blank to restore the default name.",
		options = {
			literal_button("Confirm", function()
				local value = input_widget and input_widget.content and input_widget.content.input_text or ""
				close_input()
				ItemCustomization.update(mod, context.gear_id, { name = value })
				refresh_item(mod, layout, context, true)
			end),
			literal_button("Reset to default", function()
				close_input()
				reset_field(mod, context, layout, "name", "name")
			end),
			literal_button("Cancel", close_input, true),
		},
	})
end

ItemCustomization.on_enabled = function(mod)
	cached_records = customization_records(mod)

	if type(mod:get(STORAGE_SETTING_ID)) ~= "table" then
		save_records(mod, {})
	end
end

ItemCustomization.on_setting_changed = function(mod, setting_id)
	if setting_id == "enable_custom_item_name_and_colors" and mod:get(setting_id) ~= false then
		return ItemCustomization.import_name_it_names(mod)
	end

	return false
end

ItemCustomization.update_runtime = function()
	if pending_action then
		local action = pending_action
		pending_action = nil
		action()
	end
end

local function effective_name_keybind(mod)
	local other_mod = name_it_mod()
	local configured = other_mod and type(other_mod.get) == "function" and other_mod:get("keybind_change_name") or nil

	if type(configured) == "string" then
		return configured
	end

	return mod:get("custom_item_name_keybind")
end

local function remove_customization_legend_entries(inputs, remove_name_it)
	for index = #inputs, 1, -1 do
		local callback_name = inputs[index].on_pressed_callback

		if (remove_name_it and callback_name == "cb_on_change_name_pressed") or (type(callback_name) == "string" and string.find(callback_name, "cb_on_better_inventory_", 1, true) == 1) then
			table.remove(inputs, index)
		end
	end
end

local function add_legend_entry(inputs, keybind, localization_id, callback_name)
	if type(keybind) ~= "string" or keybind == "off" then
		return
	end

	inputs[#inputs + 1] = {
		input_action = keybind,
		display_name = localization_id,
		alignment = "right_alignment",
		on_pressed_callback = callback_name,
		visibility_function = function(parent) return parent:selected_grid_widget() ~= nil end,
	}
end

ItemCustomization.install = function(mod, InventoryWeaponsView, layout)
	if installed or type(InventoryWeaponsView) ~= "table" then
		return false
	end

	installed = true

	if type(mod.add_global_localize_strings) == "function" then
		mod:add_global_localize_strings({
			better_inventory_change_name = { en = "Change Name" },
			better_inventory_name_color = { en = "Name Color" },
			better_inventory_background_color = { en = "Background Color" },
		})
	end

	mod:hook_require("scripts/ui/constant_elements/elements/popup_handler/constant_element_popup_handler_definitions", function(definitions)
		local TextInputPassTemplates = require("scripts/ui/pass_templates/text_input_pass_templates")
		local UIWidget = require("scripts/managers/ui/ui_widget")

		definitions.scenegraph_definition[INPUT_WIDGET_ID] = {
			parent = "center_pivot", vertical_alignment = "center", horizontal_alignment = "center",
			size = { 800, 40 }, position = { 0, -25, 3 },
		}
		definitions.widget_definitions[INPUT_WIDGET_ID] = UIWidget.create_definition(table.clone(TextInputPassTemplates.simple_input_field), INPUT_WIDGET_ID)
		definitions.widget_definitions[INPUT_WIDGET_ID].content.visible = false
	end)

	mod:hook_safe("ConstantElementPopupHandler", "update", function(handler)
		input_widget = input_widget or handler._widgets_by_name and handler._widgets_by_name[INPUT_WIDGET_ID]
		if input_widget and input_widget.content then input_widget.content.visible = show_input_field end
	end)

	mod:hook(InventoryWeaponsView, "init", function(func, view, ...)
		func(view, ...)
		view.cb_on_better_inventory_change_name_pressed = function(self)
			local context = selected_context(mod, self)
			if context then show_name_editor(mod, context, layout) end
		end
		view.cb_on_better_inventory_name_color_pressed = function(self)
			local context = selected_context(mod, self)
			if context then show_color_picker(mod, "name", context, layout) end
		end
		view.cb_on_better_inventory_background_color_pressed = function(self)
			local context = selected_context(mod, self)
			if context then show_color_picker(mod, "background", context, layout) end
		end
	end)

	mod:hook(InventoryWeaponsView, "_setup_input_legend", function(func, view, ...)
		local inputs = view._definitions and view._definitions.legend_inputs

		if type(inputs) == "table" then
			local enabled = mod:get("enable_custom_item_name_and_colors") ~= false

			remove_customization_legend_entries(inputs, enabled)

			if enabled then
				add_legend_entry(inputs, effective_name_keybind(mod), "better_inventory_change_name", "cb_on_better_inventory_change_name_pressed")
				add_legend_entry(inputs, mod:get("custom_item_name_color_keybind"), "better_inventory_name_color", "cb_on_better_inventory_name_color_pressed")
				add_legend_entry(inputs, mod:get("custom_item_background_color_keybind"), "better_inventory_background_color", "cb_on_better_inventory_background_color_pressed")
			end
		end

		return func(view, ...)
	end)

	mod:hook_safe("GearService", "on_gear_deleted", function(_, gear_id)
		ItemCustomization.remove(mod, gear_id)
	end)

	return true
end

ItemCustomization.show_color_picker = show_color_picker
ItemCustomization.show_name_editor = show_name_editor

return ItemCustomization
