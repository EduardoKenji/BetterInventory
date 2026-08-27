local UIWidget = require("scripts/managers/ui/ui_widget")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local TextInputPassTemplates = require("scripts/ui/pass_templates/text_input_pass_templates")

local SearchUI = {}
local INPUT_NAME = "better_inventory_search_input"
local CLEAR_NAME = "better_inventory_search_clear"
local COUNT_NAME = "better_inventory_search_count"
local HELP_NAME = "better_inventory_search_help"
local HELP_TEXT_NAME = "better_inventory_search_help_text"
local FILTER_TOGGLE_NAME = "better_inventory_search_filters"
local MAX_QUERY_LENGTH = 128
local QUICK_FILTERS = {
	{ field = "equipped", label = "inventory_search_filter_equipped", row = 1 },
	{ field = "favorite", label = "inventory_search_filter_favorite", row = 1 },
	{ field = "new", label = "inventory_search_filter_new", row = 1 },
	{ field = "loadout", label = "inventory_search_filter_loadout", row = 1 },
	{ field = "perfect", label = "inventory_search_filter_perfect", row = 1 },
	{ field = "type", label = "inventory_search_filter_weapon", row = 2, value = "weapon" },
	{ field = "type", label = "inventory_search_filter_curio", row = 2, value = "curio" },
	{ field = "type", label = "inventory_search_filter_melee", row = 2, value = "melee" },
	{ field = "type", label = "inventory_search_filter_ranged", row = 2, value = "ranged" },
}

local function supported(view)
	local class_name = view and view.__class_name

	return class_name == "InventoryWeaponsView"
		or class_name == "CraftingMechanicusModifyView"
		or class_name == "CraftingMechanicusBarterItemsView"
		or class_name == "CreditsVendorView"
		or class_name == "CreditsGoodsVendorView"
		or class_name == "MarksVendorView"
		or class_name == "MarksGoodsVendorView"
end

local function clone(value)
	return type(value) == "table" and table.clone(value) or {}
end

local function text_length(value)
	local utf8 = rawget(_G, "Utf8")

	if utf8 and type(utf8.string_length) == "function" then
		local ok, length = pcall(utf8.string_length, value or "")

		if ok then
			return length
		end
	end

	return #(value or "")
end

local function search_y(definitions, view)
	local grid_settings = definitions.grid_settings or {}
	local title_height = tonumber(grid_settings.title_height) or 0

	if view.__class_name == "InventoryWeaponsView" then
		return math.max(title_height - 38, 62)
	elseif view.__class_name == "CraftingMechanicusModifyView" then
		return math.max(title_height - 38, 30)
	elseif view.__class_name == "CraftingMechanicusBarterItemsView" then
		return 58
	end

	return math.max(title_height - 38, 12)
end

local function clear_passes()
	local text_style = clone(UIFontSettings.body)
	text_style.font_size = 24
	text_style.text_horizontal_alignment = "center"
	text_style.text_vertical_alignment = "center"

	return {
		{
			content_id = "hotspot",
			pass_type = "hotspot",
		},
		{
			pass_type = "rect",
			style = {
				color = { 210, 20, 20, 20 },
			},
		},
		{
			pass_type = "text",
			style = text_style,
			value = "X",
		},
	}
end

local function count_passes()
	local text_style = clone(UIFontSettings.body)
	text_style.font_size = 16
	text_style.text_horizontal_alignment = "right"
	text_style.text_vertical_alignment = "center"

	return {
		{
			pass_type = "text",
			style = text_style,
			value = "",
			value_id = "text",
		},
	}
end

local function help_text_passes()
	local text_style = clone(UIFontSettings.body)
	text_style.font_size = 15
	text_style.text_horizontal_alignment = "left"
	text_style.text_vertical_alignment = "top"
	text_style.offset = { 8, 6, 2 }
	text_style.size_addition = { -16, -12 }

	return {
		{
			pass_type = "rect",
			style = {
				color = { 245, 10, 20, 16 },
			},
		},
		{
			pass_type = "text",
			style = text_style,
			value = "",
			value_id = "text",
		},
	}
end

local function compact_button_passes(font_size)
	local text_style = clone(UIFontSettings.body)
	text_style.font_size = font_size or 14
	text_style.text_horizontal_alignment = "center"
	text_style.text_vertical_alignment = "center"

	return {
		{ content_id = "hotspot", pass_type = "hotspot" },
		{
			pass_type = "rect",
			style_id = "background",
			style = { color = { 210, 20, 20, 20 } },
		},
		{
			pass_type = "text",
			style = text_style,
			value = "",
			value_id = "text",
		},
	}
end

local function filter_key(filter)
	return filter.field .. "=" .. tostring(filter.value == nil and true or filter.value)
end

local function filter_widget_name(filter)
	local suffix = filter.value == nil and filter.field or filter.field .. "_" .. tostring(filter.value)

	return "better_inventory_search_filter_" .. suffix
end

SearchUI.decorate_definitions = function(definitions, view)
	if not supported(view) then
		return definitions
	elseif type(definitions) == "table" and definitions._better_inventory_search_decorated then
		return definitions
	elseif type(definitions) ~= "table" or type(definitions.scenegraph_definition) ~= "table" or type(definitions.scenegraph_definition.item_grid_pivot) ~= "table" then
		if view then
			view._better_inventory_search_ui_unavailable = true
		end

		return definitions
	end

	view._better_inventory_search_ui_unavailable = nil
	local owned = clone(definitions)
	owned._better_inventory_search_decorated = true
	owned.grid_settings = clone(owned.grid_settings)
	owned.scenegraph_definition = clone(owned.scenegraph_definition)
	owned.widget_definitions = clone(owned.widget_definitions)
	local y = search_y(owned, view)

	if tonumber(owned.grid_settings.title_height) and owned.grid_settings.title_height > 0 then
		owned.grid_settings.title_height = owned.grid_settings.title_height + 62
	else
		owned.grid_settings.top_padding = (tonumber(owned.grid_settings.top_padding) or 80) + 62
	end

	owned.scenegraph_definition[INPUT_NAME] = {
		horizontal_alignment = "left",
		parent = "item_grid_pivot",
		vertical_alignment = "top",
		size = { 394, 34 },
		position = { 18, y, 80 },
	}
	owned.scenegraph_definition[CLEAR_NAME] = {
		horizontal_alignment = "left",
		parent = "item_grid_pivot",
		vertical_alignment = "top",
		size = { 34, 34 },
		position = { 416, y, 81 },
	}
	owned.scenegraph_definition[HELP_NAME] = {
		horizontal_alignment = "left",
		parent = "item_grid_pivot",
		vertical_alignment = "top",
		size = { 34, 34 },
		position = { 454, y, 81 },
	}
	owned.scenegraph_definition[COUNT_NAME] = {
		horizontal_alignment = "left",
		parent = "item_grid_pivot",
		vertical_alignment = "top",
		size = { 92, 34 },
		position = { 494, y, 80 },
	}
	owned.scenegraph_definition[HELP_TEXT_NAME] = {
		horizontal_alignment = "left",
		parent = "item_grid_pivot",
		vertical_alignment = "top",
		size = { 568, 84 },
		position = { 18, y + 98, 100 },
	}
	owned.scenegraph_definition[FILTER_TOGGLE_NAME] = {
		horizontal_alignment = "left",
		parent = "item_grid_pivot",
		vertical_alignment = "top",
		size = { 76, 26 },
		position = { 18, y + 38, 80 },
	}

	local row_positions = { 0, 0 }

	for index = 1, #QUICK_FILTERS do
		local filter = QUICK_FILTERS[index]
		local name = filter_widget_name(filter)
		local row = filter.row or 1
		local row_index = row_positions[row]
		local width = row == 1 and 94 or 118

		row_positions[row] = row_index + 1

		owned.scenegraph_definition[name] = {
			horizontal_alignment = "left",
			parent = "item_grid_pivot",
			vertical_alignment = "top",
			size = { width, 26 },
			position = { 98 + row_index * (width + 3), y + 38 + (row - 1) * 30, 80 },
		}
		owned.widget_definitions[name] = UIWidget.create_definition(compact_button_passes(), name, {
			text = "",
		})
	end
	owned.widget_definitions[INPUT_NAME] = UIWidget.create_definition(TextInputPassTemplates.simple_input_field, INPUT_NAME, {
		caret_position = 1,
		input_text = "",
		max_length = MAX_QUERY_LENGTH,
	})
	owned.widget_definitions[CLEAR_NAME] = UIWidget.create_definition(clear_passes(), CLEAR_NAME)
	owned.widget_definitions[HELP_NAME] = UIWidget.create_definition(compact_button_passes(18), HELP_NAME, {
		text = "?",
	})
	owned.widget_definitions[HELP_TEXT_NAME] = UIWidget.create_definition(help_text_passes(), HELP_TEXT_NAME, {
		text = "",
	})
	owned.widget_definitions[COUNT_NAME] = UIWidget.create_definition(count_passes(), COUNT_NAME, {
		text = "",
	})
	owned.widget_definitions[FILTER_TOGGLE_NAME] = UIWidget.create_definition(compact_button_passes(13), FILTER_TOGGLE_NAME, {
		text = "",
	})

	return owned
end

local function chips_for(view)
	local chips = {}
	local active = view and view._better_inventory_search_quick_filters or {}

	for index = 1, #QUICK_FILTERS do
		local filter = QUICK_FILTERS[index]
		local key = filter_key(filter)

		if active[key] then
			chips[#chips + 1] = {
				field = filter.field,
				value = filter.value == nil and true or filter.value,
			}
		end
	end

	return chips
end

local function has_quick_filter(view)
	local active = view and view._better_inventory_search_quick_filters or {}

	for index = 1, #QUICK_FILTERS do
		if active[filter_key(QUICK_FILTERS[index])] then
			return true
		end
	end

	return false
end


local function widgets(view)
	local by_name = view and view._widgets_by_name

	return by_name and by_name[INPUT_NAME], by_name and by_name[CLEAR_NAME], by_name and by_name[COUNT_NAME]
end


local function set_visible(widget, visible)
	if widget then
		widget.visible = visible
	end
end


SearchUI.defocus = function(view)
	local input = widgets(view)
	local content = input and input.content

	if not content then
		return false
	end

	content.is_writing = false
	content.selected_text = nil

	if content.hotspot then
		content.hotspot.is_selected = false
	end

	return true
end


SearchUI.focus = function(view)
	local input = widgets(view)
	local content = input and input.content

	if not content then
		return false
	end

	content.is_writing = true
	content.caret_position = text_length(content.input_text) + 1
	content.force_caret_update = true

	if content.hotspot then
		content.hotspot.is_selected = true
	end

	return true
end


SearchUI.is_writing = function(view)
	local input = widgets(view)

	return input and input.content and input.content.is_writing == true or false
end


SearchUI.sync_query = function(Features, view)
	local input = widgets(view)
	local content = input and input.content

	if not content or type(Features.search_query) ~= "function" then
		return false
	end

	local query = Features.search_query(view)
	content.input_text = query
	content.caret_position = text_length(query) + 1
	content.force_caret_update = true
	view._better_inventory_search_last_text = query
	view._better_inventory_search_quick_filters = {}

	if type(Features.search_chips) == "function" then
		local chips = Features.search_chips(view)

		for index = 1, #chips do
			local chip = chips[index]

			if chip then
				view._better_inventory_search_quick_filters[chip.field .. "=" .. tostring(chip.value)] = true
			end
		end
	end

	return true
end


SearchUI.update = function(mod, Features, view, time, input_service)
	if not supported(view) then
		return false
	end

	local input, clear, count = widgets(view)
	local by_name = view._widgets_by_name or {}
	local filter_toggle = by_name[FILTER_TOGGLE_NAME]
	local help = by_name[HELP_NAME]
	local help_text = by_name[HELP_TEXT_NAME]
	local visible = mod:get("enable_inventory_search") ~= false

	set_visible(input, visible)
	set_visible(clear, visible)
	set_visible(count, visible)
	set_visible(filter_toggle, visible)
	set_visible(help, visible)
	set_visible(help_text, visible and view._better_inventory_search_help_visible == true)

	for index = 1, #QUICK_FILTERS do
		set_visible(by_name[filter_widget_name(QUICK_FILTERS[index])], visible and view._better_inventory_search_filters_expanded == true)
	end

	if not visible or not input or not input.content then
		SearchUI.defocus(view)
		return false
	end

	local content = input.content
	local query = type(content.input_text) == "string" and content.input_text or ""

	if not view._better_inventory_search_widget_initialized then
		content.placeholder_text = mod:localize("inventory_search_placeholder")
		content.active_placeholder_text = content.placeholder_text
		view._better_inventory_search_last_text = query
		view._better_inventory_search_quick_filters = view._better_inventory_search_quick_filters or {}
		view._better_inventory_search_widget_initialized = true

		if clear and clear.content and clear.content.hotspot then
			clear.content.hotspot.pressed_callback = function()
				content.input_text = ""
				content.caret_position = 1
				content.force_caret_update = true
				view._better_inventory_search_quick_filters = {}
				view._better_inventory_search_filters_dirty = true
			end
		end

		if filter_toggle and filter_toggle.content and filter_toggle.content.hotspot then
			filter_toggle.content.text = mod:localize("inventory_search_filters")
			filter_toggle.content.hotspot.pressed_callback = function()
				view._better_inventory_search_filters_expanded = not view._better_inventory_search_filters_expanded
			end
		end
		if help and help.content and help.content.hotspot then
			help.content.hotspot.pressed_callback = function()
				view._better_inventory_search_help_visible = not view._better_inventory_search_help_visible
			end
		end
		if help_text and help_text.content then
			help_text.content.text = mod:localize("inventory_search_help")
		end

		for index = 1, #QUICK_FILTERS do
			local filter = QUICK_FILTERS[index]
			local widget = by_name[filter_widget_name(filter)]

			if widget and widget.content then
				widget.content.text = mod:localize(filter.label)

				if widget.content.hotspot then
					widget.content.hotspot.pressed_callback = function()
						local active = view._better_inventory_search_quick_filters
						local key = filter_key(filter)
						local enable = not active[key]

						if filter.field == "type" then
							for filter_index = 1, #QUICK_FILTERS do
								local other = QUICK_FILTERS[filter_index]

								if other.field == "type" then
									active[filter_key(other)] = nil
								end
							end
						end

						active[key] = enable and true or nil
						view._better_inventory_search_filters_dirty = true
					end
				end
			end
		end
	end

	if query ~= view._better_inventory_search_last_text or view._better_inventory_search_filters_dirty then
		view._better_inventory_search_last_text = query
		view._better_inventory_search_filters_dirty = nil
		local valid, error_code = Features.search_set_query(view, query, chips_for(view), time)
		view._better_inventory_search_error = valid and nil or error_code
	end

	for index = 1, #QUICK_FILTERS do
		local filter = QUICK_FILTERS[index]
		local widget = by_name[filter_widget_name(filter)]
		local background = widget and widget.style and widget.style.background
		local active = view._better_inventory_search_quick_filters[filter_key(filter)]

		if background and background.color then
			background.color[2] = active and 70 or 20
			background.color[3] = active and 110 or 20
			background.color[4] = active and 70 or 20
		end
	end

	if count and count.content then
		if view._better_inventory_search_error then
			count.content.text = mod:localize("inventory_search_invalid")
		elseif (query ~= "" or has_quick_filter(view)) and type(Features.search_counts) == "function" then
			local matched, total = Features.search_counts(view)
			count.content.text = matched == 0 and string.format("%s (0 / %d)", mod:localize("inventory_search_no_matches"), total or 0) or string.format("%d / %d", matched or 0, total or 0)
		else
			count.content.text = ""
		end
	end

	return true
end


SearchUI.handle_view_input = function(mod, view, input_service)
	if not SearchUI.is_writing(view) then
		local focus_action = mod and mod:get("inventory_search_focus_keybind")

		if focus_action ~= nil and focus_action ~= "off" and input_service and type(input_service.get) == "function" and input_service:get(focus_action) then
			SearchUI.focus(view)
			return true
		end
	end

	if not SearchUI.is_writing(view) then
		return false
	end

	if input_service and type(input_service.get) == "function" and (input_service:get("back") or input_service:get("cancel_pressed")) then
		SearchUI.defocus(view)
		view._better_inventory_search_block_legend_once = true
	end

	return true
end


SearchUI.release = function(view)
	SearchUI.defocus(view)

	if view then
		view._better_inventory_search_error = nil
		view._better_inventory_search_last_text = nil
		view._better_inventory_search_widget_initialized = nil
		view._better_inventory_search_block_legend_once = nil
		view._better_inventory_search_quick_filters = nil
		view._better_inventory_search_filters_dirty = nil
		view._better_inventory_search_filters_expanded = nil
		view._better_inventory_search_help_visible = nil
		view._better_inventory_search_ui_unavailable = nil
	end
end

return SearchUI
