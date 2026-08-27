local UIWidget = require("scripts/managers/ui/ui_widget")
local TextInputPassTemplates = require("scripts/ui/pass_templates/text_input_pass_templates")

local SearchUI = {}
local INPUT_NAME = "better_inventory_search_input"
local MAX_QUERY_LENGTH = 128
local INPUT_HEIGHT = 34
local CLIP_CLEARANCE = 2
local BOTTOM_DIVIDER_HEIGHT_OFFSET = 16
local SEARCH_ROW_PADDING = 48
local INVENTORY_SEARCH_ROW_PADDING = 46
local ARMOURY_SEARCH_ROW_PADDING = 34
local TITLED_SEARCH_GAP = 14
local ARMOURY_SEARCH_GAP = 22
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

local function controller_navigation_active(view)
	if view and view._using_cursor_navigation ~= nil then
		return view._using_cursor_navigation == false
	end

	local managers = rawget(_G, "Managers")
	local ui_manager = managers and managers.ui

	if ui_manager and type(ui_manager.using_cursor_navigation) == "function" then
		local ok, using_cursor = pcall(ui_manager.using_cursor_navigation, ui_manager)

		if ok then
			return not using_cursor
		end
	end

	return view and view._using_cursor_navigation == false or false
end

local function configured_pixels(mod, setting_id, default_value, maximum)
	if not mod or type(mod.get) ~= "function" then
		return default_value
	end

	local ok, value = pcall(mod.get, mod, setting_id)
	value = ok and tonumber(value) or nil

	if not value then
		return default_value
	end

	return math.max(0, math.min(maximum, math.floor(value + 0.5)))
end

local function search_geometry(definitions, view, mod)
	if view.__class_name == "CraftingMechanicusBarterItemsView" then
		return 16, 58, 486
	end

	local grid_settings = definitions.grid_settings or {}
	local title_height = tonumber(grid_settings.title_height) or 0
	local top_padding = tonumber(grid_settings.top_padding) or 0
	local gap = view.__class_name == "InventoryWeaponsView"
		and configured_pixels(mod, "inventory_search_inventory_top_padding", TITLED_SEARCH_GAP, 64)
		or 4

	-- Requisition Weapons & Curios and GlobalStore's Armoury Multi-Operative
	-- Supply share CreditsVendorView. Its tab/header row extends farther below
	-- item_grid_pivot than the ordinary titled inventory header.
	if view.__class_name == "CreditsVendorView" then
		gap = configured_pixels(mod, "inventory_search_armoury_top_padding", ARMOURY_SEARCH_GAP, 64)
	end

	local y = title_height > 0 and title_height + gap or top_padding + gap

	return 14, math.max(y, 12), 568
end

SearchUI.decorate_definitions = function(definitions, view, mod)
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
	local x, y, width = search_geometry(owned, view, mod)

	-- Keep Darktide's title height intact. ViewElementGrid centers its title in
	-- that height, so expanding it moves labels such as "Primary Weapon".
	if view.__class_name ~= "CraftingMechanicusBarterItemsView" then
		local row_padding = view.__class_name == "CreditsVendorView"
			and configured_pixels(mod, "inventory_search_armoury_bottom_padding", ARMOURY_SEARCH_ROW_PADDING, 96)
			or view.__class_name == "InventoryWeaponsView"
				and configured_pixels(mod, "inventory_search_inventory_bottom_padding", INVENTORY_SEARCH_ROW_PADDING, 96)
			or SEARCH_ROW_PADDING
		owned.grid_settings.top_padding = (tonumber(owned.grid_settings.top_padding) or 0) + row_padding
	end

	owned.scenegraph_definition[INPUT_NAME] = {
		horizontal_alignment = "left",
		parent = "item_grid_pivot",
		vertical_alignment = "top",
		size = { width, INPUT_HEIGHT },
		position = { x, y, 90 },
	}
	-- ViewElementGrid normally clips at its content top padding. The search field
	-- occupies part of that same region, so scrolling could otherwise move card
	-- render targets over the field. Store the desired clip edge relative to the
	-- parent pivot; finalize_grid_clip converts it after native title geometry is
	-- known and preserves the grid's native bottom edge.
	owned.grid_settings.better_inventory_search_clip_pivot_y = y + INPUT_HEIGHT + CLIP_CLEARANCE
	owned.widget_definitions[INPUT_NAME] = UIWidget.create_definition(TextInputPassTemplates.simple_input_field, INPUT_NAME, {
		caret_position = 1,
		input_text = "",
		max_length = MAX_QUERY_LENGTH,
	})

	return owned
end

SearchUI.finalize_grid_clip = function(item_grid)
	local menu_settings = item_grid and item_grid._menu_settings
	local clip_pivot_y = menu_settings and tonumber(menu_settings.better_inventory_search_clip_pivot_y)

	if not clip_pivot_y
		or type(item_grid._scenegraph_size) ~= "function"
		or type(item_grid.scenegraph_position) ~= "function"
		or type(item_grid._set_scenegraph_size) ~= "function"
		or type(item_grid._set_scenegraph_position) ~= "function" then
		return false
	end

	local _, background_height = item_grid:_scenegraph_size("grid_background")
	local mask_width, mask_height = item_grid:_scenegraph_size("grid_mask")
	local mask_position = item_grid:scenegraph_position("grid_mask")

	if type(background_height) ~= "number"
		or type(mask_width) ~= "number"
		or type(mask_height) ~= "number"
		or type(mask_position) ~= "table"
		or type(mask_position[2]) ~= "number" then
		return false
	end

	local title_offset = 0

	if item_grid._display_name_key ~= nil then
		title_offset = math.max((tonumber(menu_settings.title_height) or 0) - BOTTOM_DIVIDER_HEIGHT_OFFSET, 0)
	end

	local current_top = background_height * 0.5 + mask_position[2] - mask_height * 0.5
	local current_bottom = background_height * 0.5 + mask_position[2] + mask_height * 0.5
	local desired_top = math.max(clip_pivot_y - title_offset, current_top)
	local desired_height = math.max(current_bottom - desired_top, 0)
	local desired_position_y = (desired_top + current_bottom) * 0.5 - background_height * 0.5

	item_grid:_set_scenegraph_size("grid_mask", mask_width, desired_height)
	item_grid:_set_scenegraph_position("grid_mask", nil, desired_position_y)
	item_grid:_set_scenegraph_size("grid_interaction", mask_width, desired_height)

	return true
end

local function input_widget(view)
	local by_name = view and view._widgets_by_name

	return by_name and by_name[INPUT_NAME]
end

local function controller_focused(view)
	return view and view._better_inventory_search_controller_focused == true or false
end

local function grid_input_disabled(item_grid)
	if not item_grid then
		return false
	end

	if type(item_grid.input_disabled) == "function" then
		return item_grid:input_disabled() == true
	end

	return item_grid._input_disabled == true
end

local function own_grid_input(view, disabled)
	local item_grid = view and view._item_grid

	if not item_grid or type(item_grid.disable_input) ~= "function" then
		return false
	end

	if disabled then
		if view._better_inventory_search_grid_input_owned then
			return true
		end

		local was_disabled = grid_input_disabled(item_grid)
		view._better_inventory_search_grid_input_owned = true
		view._better_inventory_search_grid_input_was_disabled = was_disabled

		if not was_disabled then
			item_grid:disable_input(true)
		end

		return true
	end

	if not view._better_inventory_search_grid_input_owned then
		return false
	end

	local was_disabled = view._better_inventory_search_grid_input_was_disabled == true
	view._better_inventory_search_grid_input_owned = nil
	view._better_inventory_search_grid_input_was_disabled = nil

	-- Restore only the false state we replaced. A grid that was already disabled
	-- belongs to the native discard/options flow and must remain untouched.
	if not was_disabled and grid_input_disabled(item_grid) then
		item_grid:disable_input(false)
	end

	return true
end

local function restore_first_grid_item(view)
	local item_grid = view and view._item_grid

	if not item_grid or type(item_grid.select_first_index) ~= "function" then
		return false
	end

	return item_grid:select_first_index() ~= nil
end

local function selected_widget_is_top_row(item_grid)
	if not item_grid
		or type(item_grid.selected_grid_index) ~= "function"
		or type(item_grid.first_interactable_grid_index) ~= "function"
		or type(item_grid.widget_by_index) ~= "function" then
		return false
	end

	local selected_index = item_grid:selected_grid_index()
	local first_index = item_grid:first_interactable_grid_index()

	if not selected_index or not first_index then
		return false
	end

	local selected_widget = item_grid:widget_by_index(selected_index)
	local first_widget = item_grid:widget_by_index(first_index)
	local selected_row = selected_widget and selected_widget.content and selected_widget.content.row
	local first_row = first_widget and first_widget.content and first_widget.content.row

	return selected_row ~= nil and first_row ~= nil and selected_row == first_row or selected_index == first_index
end

SearchUI.defocus = function(view)
	local input = input_widget(view)
	local content = input and input.content

	if not content then
		own_grid_input(view, false)
		return false
	end

	content.is_writing = false
	content.selected_text = nil
	view._better_inventory_search_controller_focused = nil
	own_grid_input(view, false)

	if content.hotspot then
		content.hotspot.is_selected = false
		content.hotspot.is_focused = false
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
	own_grid_input(view, true)

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

	if content.input_text == query then
		view._better_inventory_search_last_text = query
		return true
	end

	content.input_text = query
	content.caret_position = text_length(query) + 1
	content.force_caret_update = true
	view._better_inventory_search_last_text = query

	return true
end

SearchUI.update = function(mod, Features, view, time)
	local input = input_widget(view)

	-- Presence of the owned widget is the cheapest and strongest hot-path
	-- capability check; unsupported ItemGridViewBase descendants never receive
	-- it during definition decoration.
	if not input then
		return false
	end

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
	local should_own_grid_input = content.is_writing == true or controller_focused(view)

	if should_own_grid_input or view._better_inventory_search_grid_input_owned then
		own_grid_input(view, should_own_grid_input)
	end

	if not view._better_inventory_search_widget_initialized then
		content.placeholder_text = mod:localize("inventory_search_placeholder")
		content.active_placeholder_text = content.placeholder_text
		view._better_inventory_search_last_text = query
		view._better_inventory_search_widget_initialized = true

		-- An already-open view can survive a DMF hot reload while the search
		-- runtime is recreated. Reconcile the visible field once instead of
		-- treating its current text as if the new runtime had already received it.
		if type(Features.search_query) == "function" then
			local runtime_query = Features.search_query(view)

			if query ~= runtime_query then
				Features.search_set_query(view, query, time)
			end
		end
	end

	if query ~= view._better_inventory_search_last_text then
		view._better_inventory_search_last_text = query
		Features.search_set_query(view, query, time)
	end

	return true
end

SearchUI.handle_view_input = function(mod, view, input_service)
	local input = input_widget(view)
	local content = input and input.content

	if not content or input.visible == false then
		return false
	end

	local writing = content.is_writing == true

	if controller_focused(view) then
		if action_pressed(input_service, "navigate_down_continuous") then
			SearchUI.defocus(view)
			restore_first_grid_item(view)
		elseif action_pressed(input_service, "back") then
			SearchUI.defocus(view)
			restore_first_grid_item(view)
			view._better_inventory_search_block_legend_once = true
		elseif not writing and action_pressed(input_service, "confirm_pressed") then
			local hotspot = content.hotspot

			if hotspot then
				hotspot.force_input_pressed = true
			end
		end

		return true
	end

	local item_grid = view._item_grid

	if not writing
		and controller_navigation_active(view)
		and action_pressed(input_service, "navigate_up_continuous")
		and selected_widget_is_top_row(item_grid) then
		view._better_inventory_search_controller_focused = true
		own_grid_input(view, true)

		if type(item_grid.select_grid_index) == "function" then
			item_grid:select_grid_index(nil)
		end

		local hotspot = content.hotspot

		if hotspot then
			hotspot.is_selected = true
			hotspot.is_focused = true
		end

		return true
	end

	if not writing then
		local focus_action = mod and mod:get("inventory_search_focus_keybind")

		if focus_action ~= nil and focus_action ~= "off" and action_pressed(input_service, focus_action) then
			SearchUI.focus(view)
			return true
		end
	end

	if not writing then
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
		view._better_inventory_search_controller_focused = nil
		view._better_inventory_search_grid_input_owned = nil
		view._better_inventory_search_grid_input_was_disabled = nil
	end
end

return SearchUI
