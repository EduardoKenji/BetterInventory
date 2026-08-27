local UIWidget = require("scripts/managers/ui/ui_widget")
local TextInputPassTemplates = require("scripts/ui/pass_templates/text_input_pass_templates")

local SearchUI = {}
local INPUT_NAME = "better_inventory_search_input"
local MAX_QUERY_LENGTH = 128
local SEARCH_ROW_PADDING = 48
local BARTER_GRID_OFFSET = 100

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

local function action_pressed(input_service, action_name)
	if type(action_name) ~= "string"
		or action_name == ""
		or not input_service
		or type(input_service.has) ~= "function"
		or type(input_service.get) ~= "function"
		or not input_service:has(action_name)
	then
		return false
	end

	return input_service:get(action_name) and true or false
end

local function search_geometry(definitions, view)
	if view.__class_name == "CraftingMechanicusBarterItemsView" then
		return 16, 58, 486
	end

	local grid_settings = definitions.grid_settings or {}
	local title_height = tonumber(grid_settings.title_height) or 0
	local top_padding = tonumber(grid_settings.top_padding) or 0
	local y = title_height > 0 and title_height - 8 or top_padding + 4

	return 14, math.max(y, 12), 568
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
	local x, y, width = search_geometry(owned, view)

	-- Keep Darktide's title height intact. ViewElementGrid centers its title in
	-- that height, so expanding it moves labels such as "Primary Weapon".
	if view.__class_name ~= "CraftingMechanicusBarterItemsView" then
		owned.grid_settings.top_padding = (tonumber(owned.grid_settings.top_padding) or 0) + SEARCH_ROW_PADDING
	end

	owned.scenegraph_definition[INPUT_NAME] = {
		horizontal_alignment = "left",
		parent = "item_grid_pivot",
		vertical_alignment = "top",
		size = { width, 34 },
		position = { x, y, 90 },
	}
	owned.widget_definitions[INPUT_NAME] = UIWidget.create_definition(TextInputPassTemplates.simple_input_field, INPUT_NAME, {
		caret_position = 1,
		input_text = "",
		max_length = MAX_QUERY_LENGTH,
	})

	return owned
end

local function input_widget(view)
	local by_name = view and view._widgets_by_name

	return by_name and by_name[INPUT_NAME]
end

SearchUI.defocus = function(view)
	local input = input_widget(view)
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
	local input = input_widget(view)
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
	local input = input_widget(view)

	return input and input.content and input.content.is_writing == true or false
end

SearchUI.sync_query = function(Features, view)
	local input = input_widget(view)
	local content = input and input.content

	if not content or type(Features.search_query) ~= "function" then
		return false
	end

	local query = Features.search_query(view)
	content.input_text = query
	content.caret_position = text_length(query) + 1
	content.force_caret_update = true
	view._better_inventory_search_last_text = query

	return true
end

SearchUI.update = function(mod, Features, view, time)
	if not supported(view) then
		return false
	end

	local input = input_widget(view)
	local visible = mod:get("enable_inventory_search") ~= false

	if input then
		input.visible = visible
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
		view._better_inventory_search_widget_initialized = true
	end

	if query ~= view._better_inventory_search_last_text then
		view._better_inventory_search_last_text = query
		Features.search_set_query(view, query, time)
	end

	return true
end

SearchUI.handle_view_input = function(mod, view, input_service)
	if not SearchUI.is_writing(view) then
		local focus_action = mod and mod:get("inventory_search_focus_keybind")

		if focus_action ~= nil and focus_action ~= "off" and action_pressed(input_service, focus_action) then
			SearchUI.focus(view)
			return true
		end
	end

	if not SearchUI.is_writing(view) then
		return false
	end

	if action_pressed(input_service, "back") then
		SearchUI.defocus(view)
		view._better_inventory_search_block_legend_once = true
	end

	return true
end

SearchUI.barter_grid_offset = function()
	return BARTER_GRID_OFFSET
end

SearchUI.release = function(view)
	SearchUI.defocus(view)

	if view then
		view._better_inventory_search_last_text = nil
		view._better_inventory_search_widget_initialized = nil
		view._better_inventory_search_block_legend_once = nil
		view._better_inventory_search_ui_unavailable = nil
	end
end

return SearchUI
