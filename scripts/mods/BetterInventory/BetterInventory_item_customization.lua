local ItemCustomization = {}
local Items = require("scripts/utilities/items")

local STORAGE_SETTING_ID = "custom_item_name_and_colors"
local NAME_IT_OWNS_NAMES_SETTING_ID = "_custom_item_name_it_owns_names"
local INPUT_WIDGET_ID = "better_inventory_name_input"
local NAME_EDITOR_DESCRIPTION = "Enter a custom name. Leave it blank to restore the default name."
local MAX_NAME_LENGTH = 80
local DEFAULT_NAME_COLOR = { 255, 220, 230, 210 }
local DEFAULT_BACKGROUND_COLOR = { 255, 45, 55, 45 }
local cached_records = {}
local pending_action
local input_widget
local show_input_field = false
local installed = false
local persistence_pending = false
local pending_deleted_gear_ids = {}

local function normalize_name(value)
	if type(value) ~= "string" then
		return
	end

	-- Keep names single-line and prevent invisible whitespace-only records.
	value = string.gsub(value, "[%c]", " ")
	value = string.gsub(value, "%s+", " ")
	value = string.gsub(value, "^%s+", "")
	value = string.gsub(value, "%s+$", "")

	if value == "" then
		return
	end

	local utf8 = rawget(_G, "Utf8")

	if utf8 and type(utf8.string_length) == "function" and type(utf8.sub_string) == "function" then
		if utf8.string_length(value) > MAX_NAME_LENGTH then
			value = utf8.sub_string(value, 1, MAX_NAME_LENGTH)
		end
	elseif #value > MAX_NAME_LENGTH then
		value = string.sub(value, 1, MAX_NAME_LENGTH)
	end

	return value
end

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
	persistence_pending = true
end

local function flush_persistence()
	if not persistence_pending then
		return false
	end

	local resolver = rawget(_G, "get_mod")

	if type(resolver) ~= "function" then
		return false
	end

	local ok, dmf = pcall(resolver, "DMF")

	if not ok or type(dmf) ~= "table" or type(dmf.save_unsaved_settings_to_file) ~= "function" then
		return false
	end

	-- One deferred flush batches all edits/deletions performed in the same
	-- frame while reducing the hard-crash loss window from an entire game state
	-- to, normally, a single frame.
	persistence_pending = false

	return pcall(dmf.save_unsaved_settings_to_file)
end

local function name_it_mod()
	local resolver = rawget(_G, "get_mod")

	if type(resolver) ~= "function" then
		return
	end

	local ok, other_mod = pcall(resolver, "name_it")

	if not ok or type(other_mod) ~= "table" then
		return
	end

	if type(other_mod.is_enabled) == "function" then
		local enabled_ok, enabled = pcall(other_mod.is_enabled, other_mod)

		if enabled_ok and enabled == false then
			return
		end
	end

	return other_mod
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
		record.name = normalize_name(changes.name)
		-- name_target only describes names imported from Name It's optional
		-- pattern-name mode. Names entered through BetterInventory always replace
		-- the primary card name and must not inherit stale imported metadata.
		record.name_target = nil
		sync_name_to_name_it(gear_id, record.name)
	end

	if type(changes.character_id) == "string" and changes.character_id ~= "" then
		record.character_id = changes.character_id
	end

	if changes.name_color ~= nil then
		record.name_color = changes.name_color ~= false and clone_color(changes.name_color, DEFAULT_NAME_COLOR) or nil
	end

	if changes.background_color ~= nil then
		record.background_color = changes.background_color ~= false and clone_color(changes.background_color, DEFAULT_BACKGROUND_COLOR) or nil

		if changes.background_color == false then
			record.background_preserve_shading = nil
		end
	end

	if changes.background_preserve_shading ~= nil and record.background_color ~= nil then
		record.background_preserve_shading = changes.background_preserve_shading == true
	end

	if record.name == nil and record.name_color == nil and record.background_color == nil and record.background_preserve_shading == nil then
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

local function remove_records(mod, gear_ids)
	if type(gear_ids) ~= "table" then
		return 0
	end

	local records = customization_records(mod)
	local other_mod, names = name_it_names()
	local removed = 0
	local names_changed = false

	for gear_id in pairs(gear_ids) do
		if records[gear_id] ~= nil then
			records[gear_id] = nil
			removed = removed + 1
		end

		if names and names[gear_id] ~= nil then
			names[gear_id] = nil
			names_changed = true
		end
	end

	if removed > 0 then
		save_records(mod, records)
	end

	if names_changed and other_mod and type(other_mod.set) == "function" then
		pcall(other_mod.set, other_mod, "name_list", names, false)
		persistence_pending = true
	end

	return removed
end

local function drain_deleted_records(mod)
	if next(pending_deleted_gear_ids) == nil then
		return 0
	end

	local gear_ids = pending_deleted_gear_ids

	pending_deleted_gear_ids = {}

	return remove_records(mod, gear_ids)
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
		local raw_external_name = external_name

		external_name = normalize_name(external_name)

		if external_name ~= raw_external_name then
			names[gear_id] = external_name
			names_changed = true
		end

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
		persistence_pending = true
	end

	return imported
end

-- When BetterInventory's editor is disabled, Name It becomes the active name
-- editor. On handoff back to BetterInventory, its complete name table is
-- authoritative: changed/added names are imported and missing names are
-- treated as resets. Color data remains owned solely by BetterInventory.
ItemCustomization.reconcile_from_name_it = function(mod)
	local other_mod, names = name_it_names()

	if not other_mod then
		return false
	end

	local records = customization_records(mod)
	local replace_pattern_name = type(other_mod.get) == "function" and other_mod:get("replace_pattern_name") == true
	local names_changed = false

	for gear_id, record in pairs(records) do
		if type(record) == "table" and type(record.name) == "string" then
			local external_name = names[gear_id]

			if type(external_name) ~= "string" or external_name == "" then
				record.name = nil
				record.name_target = nil

				if record.name_color == nil and record.background_color == nil and record.background_preserve_shading == nil then
					records[gear_id] = nil
				end
			end
		end
	end

	for gear_id, external_name in pairs(names) do
		local raw_external_name = external_name

		external_name = normalize_name(external_name)

		if external_name ~= raw_external_name then
			names[gear_id] = external_name
			names_changed = true
		end

		if type(gear_id) == "string" and type(external_name) == "string" and external_name ~= "" then
			local record = type(records[gear_id]) == "table" and records[gear_id] or {}

			record.name = external_name
			record.name_target = replace_pattern_name and "sub" or "primary"
			records[gear_id] = record
		end
	end

	save_records(mod, records)

	if names_changed and type(other_mod.set) == "function" then
		pcall(other_mod.set, other_mod, "name_list", names, false)
	end

	mod:set(NAME_IT_OWNS_NAMES_SETTING_ID, false, false)
	persistence_pending = true

	return true
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

	local record = ItemCustomization.get(mod, context.gear_id)
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
		ItemCustomization.update(mod, context.gear_id, { [field] = false, character_id = context.character_id })
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
					style = { color = clone_color(picker.draft, picker.default), offset = { half_width + gutter + 4, 4, 3 }, size = { half_width - 8, header_height - 8 } },
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
	local record = context and ItemCustomization.get(mod, context.gear_id)
	local preserve_shading = mod:get("custom_item_preserve_card_shading") ~= false

	if is_background and record and type(record.background_preserve_shading) == "boolean" then
		preserve_shading = record.background_preserve_shading
	end

	local picker = {
		default = clone_color(default_color, default_color),
		draft = clone_color(record and record[field], default_color),
		preserve_shading = is_background and preserve_shading or false,
		revision = 0,
	}
	local settings_ok, popup_settings = pcall(require, "scripts/ui/constant_elements/elements/popup_handler/constant_element_popup_handler_settings")
	local width = settings_ok and popup_settings.text_max_width or 800
	local item_name = context and context.name or "Item"
	local title = string.format(is_background and "Change item background color(%s)" or "Change item name color(%s)", item_name)
	local function confirm()
		if context then
			local changes = { [field] = clone_color(picker.draft, default_color), character_id = context.character_id }

			if is_background then
				changes.background_preserve_shading = picker.preserve_shading
				mod:set("custom_item_preserve_card_shading", picker.preserve_shading, false)
			end

			ItemCustomization.update(mod, context.gear_id, changes)
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

local function close_input()
	if input_widget and input_widget.content then
		input_widget.content.is_writing = false
		input_widget.content.visible = false
	end

	show_input_field = false
end

local function show_name_editor(mod, context, layout)
	if not input_widget or not input_widget.content then
		return false
	end

	local record = ItemCustomization.get(mod, context.gear_id)
	input_widget.content.input_text = record and record.name or context.name or ""
	input_widget.content.visible = true
	input_widget.content.is_writing = true
	show_input_field = true

	return popup({
		title_text_unlocalized = string.format("Change item name (%s)", context.name),
		description_text_unlocalized = NAME_EDITOR_DESCRIPTION,
		options = {
			literal_button("Confirm", function()
				local value = input_widget and input_widget.content and input_widget.content.input_text or ""
				close_input()
				ItemCustomization.update(mod, context.gear_id, { name = value, character_id = context.character_id })
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
	local records = customization_records(mod)
	local records_changed = false

	for gear_id, record in pairs(records) do
		if type(record) == "table" and record.name ~= nil then
			local normalized = normalize_name(record.name)

			if normalized ~= record.name then
				record.name = normalized
				records_changed = true
			end

			if normalized == nil and record.name_color == nil and record.background_color == nil and record.background_preserve_shading == nil then
				records[gear_id] = nil
			end
		end
	end

	cached_records = records

	if type(mod:get(STORAGE_SETTING_ID)) ~= "table" or records_changed then
		save_records(mod, records)
	end

	-- on_all_mods_loaded is not guaranteed to run when a user re-enables the
	-- whole mod from Toggle Mods. Complete an ownership handoff here as well.
	if mod:get("enable_custom_item_name_and_colors") ~= false and mod:get(NAME_IT_OWNS_NAMES_SETTING_ID) == true then
		if not ItemCustomization.reconcile_from_name_it(mod) then
			mod:set(NAME_IT_OWNS_NAMES_SETTING_ID, false, false)
			persistence_pending = true
		end
	end
end

ItemCustomization.on_disabled = function(mod)
	if name_it_mod() then
		mod:set(NAME_IT_OWNS_NAMES_SETTING_ID, true, false)
		persistence_pending = true
	end

	drain_deleted_records(mod)
	flush_persistence()

	-- DMF disables every hook before calling on_disabled. Keep only storage
	-- cleanup alive so discarded gear cannot become orphaned while the visual
	-- mod is toggled off.
	if type(mod.hook_enable) == "function" then
		mod:hook_enable("GearService", "on_gear_deleted")
		mod:hook_enable("GearService", "on_character_deleted")
	end
end

ItemCustomization.on_all_mods_loaded = function(mod)
	if mod:get("enable_custom_item_name_and_colors") == false then
		if name_it_mod() then
			mod:set(NAME_IT_OWNS_NAMES_SETTING_ID, true, false)
			persistence_pending = true
		end

		return false
	end

	if mod:get(NAME_IT_OWNS_NAMES_SETTING_ID) == true then
		if ItemCustomization.reconcile_from_name_it(mod) then
			return true
		end

		-- Name It was removed or disabled before the handoff completed. Resume
		-- BetterInventory ownership without leaving a stale future migration armed.
		mod:set(NAME_IT_OWNS_NAMES_SETTING_ID, false, false)
		persistence_pending = true
	end

	return ItemCustomization.import_name_it_names(mod)
end

ItemCustomization.on_setting_changed = function(mod, setting_id)
	if setting_id == "enable_custom_item_name_and_colors" then
		if mod:get(setting_id) == false then
			if name_it_mod() then
				mod:set(NAME_IT_OWNS_NAMES_SETTING_ID, true, false)
				persistence_pending = true
			end

			return false
		end

		if mod:get(NAME_IT_OWNS_NAMES_SETTING_ID) == true then
			if ItemCustomization.reconcile_from_name_it(mod) then
				return true
			end

			mod:set(NAME_IT_OWNS_NAMES_SETTING_ID, false, false)
			persistence_pending = true
		end

		return ItemCustomization.import_name_it_names(mod)
	end

	return false
end

ItemCustomization.update_runtime = function(mod)
	if pending_action then
		local action = pending_action
		pending_action = nil
		action()
	end

	drain_deleted_records(mod)
	flush_persistence()
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
		definitions.widget_definitions[INPUT_WIDGET_ID].content.max_length = MAX_NAME_LENGTH
	end)

	mod:hook_safe("ConstantElementPopupHandler", "update", function(handler)
		-- Name It reinitializes the shared popup handler during on_all_mods_loaded,
		-- replacing every widget instance. Never retain the detached pre-init
		-- widget: always follow the instance the handler currently draws.
		input_widget = handler._widgets_by_name and handler._widgets_by_name[INPUT_WIDGET_ID] or nil
		if input_widget and input_widget.content then input_widget.content.visible = show_input_field end
	end)

	mod:hook("ConstantElementPopupHandler", "_update_popup_text_height", function(func, handler, ...)
		local total_height = func(handler, ...)
		local widgets = handler._widgets_by_name
		local description = widgets and widgets.description_text
		local title = widgets and widgets.title_text

		if show_input_field and description and description.content and description.content.text == NAME_EDITOR_DESCRIPTION and title and not handler._better_inventory_name_input_layout_adjusted then
			local title_offset = handler:scenegraph_position(title.scenegraph_id)
			local button_offset = handler:scenegraph_position("button_pivot")

			handler:set_scenegraph_position(title.scenegraph_id, nil, title_offset[2] - 30)
			handler:set_scenegraph_position("button_pivot", nil, button_offset[2] + 30)
			handler._better_inventory_name_input_layout_adjusted = true

			return total_height + 60
		end

		if not show_input_field then
			handler._better_inventory_name_input_layout_adjusted = false
		end

		return total_height
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
		if type(mod.is_enabled) == "function" and not mod:is_enabled() then
			remove_records(mod, { [gear_id] = true })
			flush_persistence()
		else
			pending_deleted_gear_ids[gear_id] = true
		end
	end)

	mod:hook("GearService", "on_character_deleted", function(func, gear_service, character_id, ...)
		local gear_ids = {}
		local records = customization_records(mod)

		for gear_id, record in pairs(records) do
			if type(record) == "table" and record.character_id == character_id then
				gear_ids[gear_id] = true
			end
		end

		-- Backfill coverage for records created before character ownership was
		-- stored, whenever Darktide still has the deleted character's gear cached.
		for gear_id, gear in pairs(gear_service._cached_gear_list or {}) do
			if gear and (gear.characterId == character_id or gear.character_id == character_id) then
				gear_ids[gear_id] = true
			end
		end

		local result = func(gear_service, character_id, ...)

		remove_records(mod, gear_ids)

		if type(mod.is_enabled) == "function" and not mod:is_enabled() then
			flush_persistence()
		end

		return result
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
		if layout and type(layout.apply_weapon_information_customization) == "function" then
			layout.apply_weapon_information_customization(mod, weapon_stats, weapon_stats._item)
		end
	end)

	return true
end

ItemCustomization.show_color_picker = show_color_picker
ItemCustomization.show_name_editor = show_name_editor

return ItemCustomization
