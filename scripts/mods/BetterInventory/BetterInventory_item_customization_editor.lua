local Editor = {}
local Items = require("scripts/utilities/items")

local INPUT_WIDGET_ID = "better_inventory_name_input"
local POPUP_HANDLER_NAME = "ConstantElementPopupHandler"
local POPUP_DEFINITIONS_PATH = "scripts/ui/constant_elements/elements/popup_handler/constant_element_popup_handler_definitions"
local NAME_EDITOR_DESCRIPTION = "Enter a custom name. Leave it blank to restore the default name."
local MAX_INPUT_WIDGET_CREATION_ATTEMPTS = 3
local DEFAULT_NAME_COLOR = { 255, 220, 230, 210 }
local DEFAULT_BACKGROUND_COLOR = { 255, 45, 55, 45 }
local MAX_NAME_LENGTH = 80

local Customization = {}
local NameIt = {}
local Store = {}
local pending_action
local input_widget
local input_widget_definition
local show_input_field = false
local installed = false
local name_it_legend_entries = setmetatable({}, { __mode = "k" })

Editor.configure = function(customization, name_it, store)
	Customization = type(customization) == "table" and customization or {}
	NameIt = type(name_it) == "table" and name_it or {}
	Store = type(store) == "table" and store or {}
	DEFAULT_NAME_COLOR = Store.default_name_color or DEFAULT_NAME_COLOR
	DEFAULT_BACKGROUND_COLOR = Store.default_background_color or DEFAULT_BACKGROUND_COLOR
	MAX_NAME_LENGTH = Store.max_name_length or MAX_NAME_LENGTH
end
local function popup(context)
	local event_manager = Managers and Managers.event

	return event_manager and type(event_manager.trigger) == "function" and pcall(event_manager.trigger, event_manager, "event_show_ui_popup", context) or false
end

local function literal_button(text, callback, small, close_on_pressed)
	local button = {
		text = text,
		no_localization = true,
		template_type = small and "terminal_button_small" or nil,
		close_on_pressed = close_on_pressed ~= false,
		callback = callback,
	}

	if text == "Cancel" then
		button.hotkey = "back"
	end

	return button
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
		character_id = item.characterId or item.character_id,
		name = widget.content.display_name or "Item",
		default_name = default_name or widget.content.display_name or "Item",
	}
end

local function refresh_item(mod, layout, context, refresh_name)
	if not context then
		return
	end

	local record = Customization.get(mod, context.gear_id)
	local content = context.widget and context.widget.content

	if content and refresh_name then
		local display_name = record and record.name or context.default_name

		content.display_name = display_name
		content.better_inventory_name_it_curio_name_text = display_name
	end

	if layout and type(layout.refresh_item_customization) == "function" then
		layout.refresh_item_customization(mod, context.widget, context.widget and context.widget.content and context.widget.content.element)
	elseif layout and type(layout.apply_item_customization_style) == "function" then
		layout.apply_item_customization_style(mod, context.widget, context.widget and context.widget.content and context.widget.content.element)
	end

	-- InventoryWeaponsView is layered over InventoryView. Its selected grid card
	-- is refreshed above, but the already-created character overview loadout
	-- widgets underneath otherwise retain their old name/colors until reopened.
	local ui_manager = Managers and Managers.ui
	local overview = ui_manager and type(ui_manager.view_instance) == "function" and ui_manager:view_instance("inventory_view")
	local overview_widgets = overview and overview._loadout_widgets

	if type(overview_widgets) == "table" and layout then
		for index = 1, #overview_widgets do
			local widget = overview_widgets[index]
			local item = item_from_widget(widget)

			if item and item.gear_id == context.gear_id then
				local element = widget.content and widget.content.element

				if type(layout.refresh_item_customization) == "function" then
					layout.refresh_item_customization(mod, widget, element)
				elseif type(layout.apply_item_customization_style) == "function" then
					layout.apply_item_customization_style(mod, widget, element)
				end
			end
		end
	end

	-- Color edits do not need to rebuild the selected item preview, but its
	-- already-created weapon header must be recolored immediately.
	if layout and type(layout.apply_weapon_information_customization) == "function" and context.view then
		layout.apply_weapon_information_customization(mod, context.view._weapon_stats, context.item)
	end

	if refresh_name and context.view and type(context.view._preview_item) == "function" then
		pcall(context.view._preview_item, context.view, context.item)
	end
end

local function reset_field(mod, context, layout, field, label)
	local function reset()
		Customization.update(mod, context.gear_id, { [field] = false, character_id = context.character_id })
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
	local checkbox_height = 42
	local header_height = 110
	local gutter = 12
	local half_width = math.floor((width - gutter) / 2)
	local preview_text_style = table.clone(UIFontSettings.body)
	local hex_text_style = table.clone(UIFontSettings.body)

	local function color_to_hex(color)
		return string.format("%02X%02X%02X", color[2], color[3], color[4])
	end

	local function parse_hex(value)
		local digits = type(value) == "string" and string.match(value, "^([%x][%x][%x][%x][%x][%x])$")

		if not digits then
			return
		end

		return tonumber(string.sub(digits, 1, 2), 16), tonumber(string.sub(digits, 3, 4), 16), tonumber(string.sub(digits, 5, 6), 16)
	end

	local function apply_hex(value)
		local red, green, blue = parse_hex(value)

		if not red then
			return false
		end

		if picker.draft[2] ~= red or picker.draft[3] ~= green or picker.draft[4] ~= blue then
			picker.draft[2], picker.draft[3], picker.draft[4] = red, green, blue
			picker.revision = picker.revision + 1
		end

		picker.hex = color_to_hex(picker.draft)

		return true
	end

	preview_text_style.font_size = 18
	preview_text_style.text_horizontal_alignment = "center"
	preview_text_style.text_vertical_alignment = "center"
	preview_text_style.text_color = Color.white(255, true)
	preview_text_style.offset = { half_width + gutter, 0, 4 }
	preview_text_style.size = { half_width, header_height }
	hex_text_style.font_size = 22
	hex_text_style.text_horizontal_alignment = "center"
	hex_text_style.text_vertical_alignment = "center"
	hex_text_style.text_color = Color.white(255, true)
	hex_text_style.offset = { 4, 4, 4 }
	hex_text_style.size = { half_width - 8, header_height - 8 }

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

				if picker.draft[element.channel] ~= value then
					picker.draft[element.channel] = value
					picker.hex = color_to_hex(picker.draft)
					picker.hex_editing = false
				end

				content.value_text = string.format("%s: %d", element.label, value)
			end,
		},
		color_header = {
			size = { width, header_height },
			pass_template = {
				{ pass_type = "hotspot", content_id = "hex_hotspot", style_id = "hex_hotspot", style = { offset = { 0, 0, 10 }, size = { half_width, header_height } } },
				{ pass_type = "rect", style_id = "hex_frame", style = { color = Color.terminal_corner_hover(255, true), offset = { 0, 0, 1 }, size = { half_width, header_height } } },
				{ pass_type = "rect", style_id = "hex_background", style = { color = { 220, 15, 20, 15 }, offset = { 4, 4, 2 }, size = { half_width - 8, header_height - 8 } } },
				{ pass_type = "text", style_id = "hex_text", value = "", value_id = "hex_text", style = hex_text_style },
				{ pass_type = "rect", style_id = "preview_frame", style = { color = Color.terminal_corner_hover(255, true), offset = { half_width + gutter, 0, 1 }, size = { half_width, header_height } } },
				{ pass_type = "rect", style_id = "preview_background", style = { color = { 255, 15, 20, 15 }, offset = { half_width + gutter + 4, 4, 2 }, size = { half_width - 8, header_height - 8 } } },
				{
					pass_type = "texture",
					style_id = "preview",
					value = "content/ui/materials/backgrounds/default_square",
					value_id = "preview_material",
					style = { color = Store.clone_color(picker.draft, picker.default), offset = { half_width + gutter + 4, 4, 3 }, size = { half_width - 8, header_height - 8 } },
					change_function = function(_, style)
						style.color[2], style.color[3], style.color[4] = picker.draft[2], picker.draft[3], picker.draft[4]
					end,
				},
				{ pass_type = "text", style_id = "text", value = "", value_id = "text", style = preview_text_style },
			},
			init = function(_, widget)
				picker.hex = picker.hex or color_to_hex(picker.draft)
				widget.content.hex_hotspot = widget.content.hex_hotspot or {}
				widget.content.hex_buffer = picker.hex
				widget.content.hex_text = "Hex: #" .. picker.hex
				widget.content.text = "RGB preview"
				widget.content.preview_material = picker.preserve_shading and "content/ui/materials/gradients/gradient_vertical" or "content/ui/materials/backgrounds/default_square"
				widget.content.better_inventory_picker_revision = picker.revision
			end,
			update = function(_, widget)
				local content = widget.content
				local hotspot = content.hex_hotspot
				content.preview_material = picker.preserve_shading and "content/ui/materials/gradients/gradient_vertical" or "content/ui/materials/backgrounds/default_square"

				if hotspot and hotspot.on_pressed then
					content.hex_editing = true
					picker.hex_editing = true
					content.hex_buffer = picker.hex or color_to_hex(picker.draft)
					content.hex_fresh = true
				end

				if picker.hex_editing == false then
					content.hex_editing = false
				end

				if content.hex_editing then
					local keyboard = rawget(_G, "Keyboard")
					local keystrokes = keyboard and type(keyboard.keystrokes) == "function" and keyboard.keystrokes() or nil
					local buffer = content.hex_buffer or ""

					for index = 1, keystrokes and #keystrokes or 0 do
						local stroke = keystrokes[index]

						if keyboard and stroke == keyboard.BACKSPACE then
							content.hex_fresh = false
							buffer = string.sub(buffer, 1, math.max(0, #buffer - 1))
						elseif type(stroke) == "string" then
							-- The leading # is presentation, not editable data. This also
							-- lets users paste either #RRGGBB or RRGGBB while limiting the
							-- actual input buffer to exactly six hexadecimal characters.
							local accepted = string.gsub(stroke, "[^%x]", "")

							if accepted ~= "" then
								if content.hex_fresh then
									buffer = ""
									content.hex_fresh = false
								end

								buffer = string.sub(buffer .. string.upper(accepted), 1, 6)
							end
						end
					end

					content.hex_buffer = buffer
					apply_hex(buffer)
					content.hex_text = "Hex: #" .. buffer .. " |"

					if keyboard and type(keyboard.pressed) == "function" and type(keyboard.button_index) == "function" then
						if keyboard.pressed(keyboard.button_index("enter")) then
							content.hex_editing = false
							picker.hex_editing = false
							content.hex_text = "Hex: #" .. (picker.hex or color_to_hex(picker.draft))
						elseif keyboard.pressed(keyboard.button_index("escape")) then
							content.hex_editing = false
							picker.hex_editing = false
							content.hex_buffer = picker.hex or color_to_hex(picker.draft)
							content.hex_text = "Hex: #" .. content.hex_buffer
						end
					end
				else
					content.hex_buffer = picker.hex or color_to_hex(picker.draft)
					content.hex_text = "Hex: #" .. content.hex_buffer
				end

				if content.better_inventory_picker_revision ~= picker.revision then
					content.better_inventory_picker_revision = picker.revision
					content.hex_buffer = picker.hex or color_to_hex(picker.draft)
					content.hex_text = "Hex: #" .. content.hex_buffer .. (content.hex_editing and " |" or "")
				end
			end,
		},
		shading_checkbox = {
			size = { width, checkbox_height },
			pass_template = {
				{ pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot" },
				{ pass_type = "rect", style_id = "checkbox_background", style = { color = { 220, 15, 20, 15 }, offset = { 0, 9, 1 }, size = { 24, 24 } } },
				{ pass_type = "texture", style_id = "checkbox_frame", value = "content/ui/materials/frames/frame_tile_2px", style = { color = Color.terminal_corner_hover(255, true), offset = { 0, 9, 2 }, size = { 24, 24 } } },
				{ pass_type = "rect", style_id = "checkmark", style = { color = Color.terminal_corner_hover(255, true), offset = { 5, 14, 3 }, size = { 14, 14 } }, visibility_function = function(content) return content.checked end },
				{ pass_type = "text", style_id = "label", value = "", value_id = "label", style = { font_size = 18, font_type = "proxima_nova_bold", text_horizontal_alignment = "left", text_vertical_alignment = "center", text_color = Color.white(255, true), offset = { 34, 0, 3 }, size = { width - 34, checkbox_height } } },
			},
			init = function(_, widget)
				widget.content.hotspot = widget.content.hotspot or {}
				widget.content.checked = picker.preserve_shading
				widget.content.label = "Preserve Darktide Equipment Card Shading"
			end,
			update = function(_, widget)
				local content = widget.content
				local pressed = content.hotspot and content.hotspot.on_pressed == true

				if pressed and not content.better_inventory_was_pressed then
					picker.preserve_shading = not picker.preserve_shading
					content.checked = picker.preserve_shading
				end

				content.better_inventory_was_pressed = pressed
			end,
		},
	}
end

local function show_color_picker(mod, target, context, layout)
	local is_background = target == "background"
	local field = is_background and "background_color" or "name_color"
	local default_color = is_background and DEFAULT_BACKGROUND_COLOR or DEFAULT_NAME_COLOR
	local record = context and Customization.get(mod, context.gear_id)
	local preserve_shading = mod:get("custom_item_preserve_card_shading") ~= false

	if is_background and record and type(record.background_preserve_shading) == "boolean" then
		preserve_shading = record.background_preserve_shading
	end

	local picker = {
		default = Store.clone_color(default_color, default_color),
		draft = Store.clone_color(record and record[field], default_color),
		preserve_shading = is_background and preserve_shading or false,
		revision = 0,
	}
	local settings_ok, popup_settings = pcall(require, "scripts/ui/constant_elements/elements/popup_handler/constant_element_popup_handler_settings")
	local width = settings_ok and popup_settings.text_max_width or 800
	local item_name = context and context.name or "Item"
	local title = string.format(is_background and "Change item background color(%s)" or "Change item name color(%s)", item_name)
	local function confirm()
		if context then
			local changes = { [field] = Store.clone_color(picker.draft, default_color), character_id = context.character_id }

			if is_background then
				changes.background_preserve_shading = picker.preserve_shading
				mod:set("custom_item_preserve_card_shading", picker.preserve_shading, false)
			end

			Customization.update(mod, context.gear_id, changes)
			refresh_item(mod, layout, context, false)
		end
	end

	return popup({
		title_text_unlocalized = title,
		type = "grid",
		grid_layout = {
			{ widget_type = "color_header" },
			{ widget_type = "color_slider", channel = 2, label = "Red" },
			{ widget_type = "color_slider", channel = 3, label = "Green" },
			{ widget_type = "color_slider", channel = 4, label = "Blue" },
			is_background and { widget_type = "shading_checkbox" } or nil,
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

local function active_popup_handler()
	local ui_manager = Managers and Managers.ui
	local constant_elements

	if ui_manager and type(ui_manager.ui_constant_elements) == "function" then
		local ok, value = pcall(ui_manager.ui_constant_elements, ui_manager)

		constant_elements = ok and value or nil
	end

	if constant_elements and type(constant_elements.element) == "function" then
		local ok, value = pcall(constant_elements.element, constant_elements, POPUP_HANDLER_NAME)

		return ok and value or nil
	end
end

local function ensure_input_widget(mod, popup_handler)
	local widgets_by_name = popup_handler and popup_handler._widgets_by_name
	local existing = widgets_by_name and widgets_by_name[INPUT_WIDGET_ID]

	if existing then
		return existing
	end

	local attempts = popup_handler and popup_handler._better_inventory_name_input_creation_attempts or 0

	if not popup_handler or not widgets_by_name or not input_widget_definition or not popup_handler._definitions or type(popup_handler._create_widget) ~= "function" or attempts >= MAX_INPUT_WIDGET_CREATION_ATTEMPTS then
		return
	end

	local ok, result = pcall(function()
		local UIScenegraph = require("scripts/managers/ui/ui_scenegraph")
		local definitions = popup_handler._definitions

		-- The singleton popup handler can be instantiated before DMF applies
		-- hook_require additions. Rebuild once from the now-patched complete
		-- definition and attach the missing text field at runtime.
		popup_handler._ui_scenegraph = UIScenegraph.init_scenegraph(definitions.scenegraph_definition)

		local widget = popup_handler:_create_widget(INPUT_WIDGET_ID, input_widget_definition)

		popup_handler._widgets = popup_handler._widgets or {}
		popup_handler._widgets[#popup_handler._widgets + 1] = widget
		widgets_by_name[INPUT_WIDGET_ID] = widget

		return widget
	end)

	if ok and result then
		popup_handler._better_inventory_name_input_creation_attempts = nil
		popup_handler._better_inventory_name_input_creation_warning = nil

		return result
	end

	popup_handler._better_inventory_name_input_creation_attempts = attempts + 1

	if mod and not popup_handler._better_inventory_name_input_creation_warning then
		popup_handler._better_inventory_name_input_creation_warning = true
		mod:warning("Unable to create the Change Name text field: %s", tostring(result))
	end
end

local function resolve_input_widget(mod, create_if_missing)
	local popup_handler = active_popup_handler()

	if popup_handler then
		if create_if_missing then
			input_widget = ensure_input_widget(mod, popup_handler)
		else
			input_widget = popup_handler._widgets_by_name and popup_handler._widgets_by_name[INPUT_WIDGET_ID] or nil
		end
	else
		-- ConstantElementPopupHandler instances are recreated independently from
		-- inventory views. Never retain a widget from a handler that is no longer
		-- active.
		input_widget = nil
	end

	return input_widget
end

local function close_input(mod)
	resolve_input_widget(mod, false)

	if input_widget and input_widget.content then
		input_widget.content.is_writing = false
		input_widget.content.visible = false
	end

	show_input_field = false
	input_widget = nil
end

local function show_name_editor(mod, context, layout)
	-- Constant elements can be recreated independently from inventory views.
	-- Resolve the currently active popup handler here instead of relying on its
	-- update hook to have refreshed the cached text widget before Q is pressed.
	resolve_input_widget(mod, true)

	if not input_widget or not input_widget.content then
		return false
	end

	local record = Customization.get(mod, context.gear_id)
	input_widget.content.input_text = record and record.name or context.name or ""
	input_widget.content.visible = true
	input_widget.content.is_writing = true
	show_input_field = true

	local shown = popup({
		title_text_unlocalized = string.format("Change item name (%s)", context.name),
		description_text_unlocalized = NAME_EDITOR_DESCRIPTION,
		options = {
			literal_button("Confirm", function()
				local value = input_widget and input_widget.content and input_widget.content.input_text or ""
				close_input(mod)
				Customization.update(mod, context.gear_id, { name = value, character_id = context.character_id })
				refresh_item(mod, layout, context, true)
			end),
			literal_button("Reset to default", function()
				close_input(mod)
				reset_field(mod, context, layout, "name", "name")
			end),
			literal_button("Cancel", function() close_input(mod) end, true),
		},
	})

	if not shown then
		close_input(mod)
	end

	return shown
end

local function effective_name_keybind(mod)
	-- BetterInventory owns the inventory action while its standalone editor is
	-- enabled. Inheriting Name It's legacy Q/Y default here made Change Name and
	-- Darktide's Add Favorite fire from the same controller button.
	return mod:get("custom_item_name_keybind")
end

local function remove_customization_legend_entries(inputs, remove_name_it)
	for index = #inputs, 1, -1 do
		local callback_name = inputs[index].on_pressed_callback

		if remove_name_it and callback_name == "cb_on_change_name_pressed" then
			name_it_legend_entries[inputs] = name_it_legend_entries[inputs] or table.clone(inputs[index])
			table.remove(inputs, index)
		elseif type(callback_name) == "string" and string.find(callback_name, "cb_on_better_inventory_", 1, true) == 1 then
			table.remove(inputs, index)
		end
	end
end

local function restore_name_it_legend_entry(inputs)
	local saved = name_it_legend_entries[inputs]

	if not saved then
		return false
	end

	for index = 1, #inputs do
		if inputs[index].on_pressed_callback == "cb_on_change_name_pressed" then
			return false
		end
	end

	inputs[#inputs + 1] = table.clone(saved)

	return true
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

Editor.install = function(mod, InventoryWeaponsView, layout)
	if installed or type(InventoryWeaponsView) ~= "table" then
		return false
	end

	installed = true

	if type(mod.add_global_localize_strings) == "function" then
		mod:add_global_localize_strings({
			better_inventory_change_name = { en = "Change Name" },
			better_inventory_name_color = { en = "Name Color" },
			better_inventory_background_color = { en = "Background Color" },
			better_inventory_toggle_panel_focus = { en = "Items / Widget Focus" },
		})
	end

	mod:hook_require(POPUP_DEFINITIONS_PATH, function(definitions)
		local TextInputPassTemplates = require("scripts/ui/pass_templates/text_input_pass_templates")
		local UIWidget = require("scripts/managers/ui/ui_widget")

		definitions.scenegraph_definition[INPUT_WIDGET_ID] = {
			parent = "center_pivot", vertical_alignment = "center", horizontal_alignment = "center",
			size = { 800, 40 }, position = { 0, -25, 3 },
		}
		input_widget_definition = UIWidget.create_definition(table.clone(TextInputPassTemplates.simple_input_field), INPUT_WIDGET_ID)
		input_widget_definition.content.visible = false
		input_widget_definition.content.max_length = MAX_NAME_LENGTH
		definitions.widget_definitions[INPUT_WIDGET_ID] = input_widget_definition
	end)

	mod:hook("ConstantElementPopupHandler", "_update_popup_text_height", function(func, handler, ...)
		local total_height = func(handler, ...)
		local widgets = handler._widgets_by_name
		local description = widgets and widgets.description_text
		local title = widgets and widgets.title_text

		if show_input_field and description and description.content and description.content.text == NAME_EDITOR_DESCRIPTION and title and type(handler.scenegraph_position) == "function" and type(handler.set_scenegraph_position) == "function" and not handler._better_inventory_name_input_layout_adjusted then
			local title_offset = handler:scenegraph_position(title.scenegraph_id)
			local button_offset = handler:scenegraph_position("button_pivot")

			if title_offset and button_offset then
				handler:set_scenegraph_position(title.scenegraph_id, nil, title_offset[2] - 30)
				handler:set_scenegraph_position("button_pivot", nil, button_offset[2] + 30)
				handler._better_inventory_name_input_layout_adjusted = true

				return total_height + 60
			end
		end

		if not show_input_field then
			handler._better_inventory_name_input_layout_adjusted = false
		end

		return total_height
	end)

	mod:hook(InventoryWeaponsView, "init", function(func, view, ...)
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

		-- Native init builds the input legend. Register every callback first so
		-- the legend binds a live function instead of displaying an inert action.
		return func(view, ...)
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
			elseif NameIt.is_available() then
				restore_name_it_legend_entry(inputs)
			end
		end

		return func(view, ...)
	end)

	-- Name It also exposes its editor through Hadron's parent CraftingView. When
	-- BetterInventory owns names, route that existing action into our editor so
	-- an external edit cannot silently diverge and later be overwritten.
	mod:hook_safe("CraftingView", "init", function(crafting_view)
		local name_it_callback = crafting_view.cb_on_change_name_pressed

		if type(name_it_callback) ~= "function" then
			return
		end

		crafting_view.cb_on_change_name_pressed = function(self)
			local mod_enabled = type(mod.is_enabled) ~= "function" or mod:is_enabled()

			if mod_enabled and mod:get("enable_custom_item_name_and_colors") ~= false then
				local ui_manager = Managers and Managers.ui
				local view = ui_manager and type(ui_manager.view_instance) == "function" and ui_manager:view_instance("crafting_mechanicus_modify_view")
				local context = selected_context(mod, view)

				if context then
					show_name_editor(mod, context, layout)
				end

				return
			end

			return name_it_callback(self)
		end
	end)

	-- This fires after ViewElementGrid has created the weapon-header widget,
	-- including when Darktide defers rebuilding the list until the next update.
	mod:hook_safe("ViewElementWeaponStats", "_on_present_grid_layout_changed", function(weapon_stats)
		if layout and type(layout.remove_weapon_stats_wkc_listing_overlays) == "function" then
			layout.remove_weapon_stats_wkc_listing_overlays(weapon_stats)
		end

		if layout and type(layout.apply_weapon_information_customization) == "function" then
			layout.apply_weapon_information_customization(mod, weapon_stats, weapon_stats._item)
		end
	end)

	return true
end

Editor.show_color_picker = show_color_picker
Editor.show_name_editor = show_name_editor
Editor.close_input = close_input
Editor.clear_pending = function()
	pending_action = nil
end
Editor.release_view = function(mod)
	pending_action = nil
	close_input(mod)
end
Editor.run_pending = function()
	if pending_action then
		local action = pending_action
		pending_action = nil
		action()
	end
end
Editor.has_pending = function()
	return pending_action ~= nil
end

return Editor
