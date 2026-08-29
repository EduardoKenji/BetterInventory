local UIWidget = require("scripts/managers/ui/ui_widget")
local TextInputPassTemplates = require("scripts/ui/pass_templates/text_input_pass_templates")

local SearchUI = {}
-- A module-local identity changes whenever DMF reloads this source. View fields
-- survive Ctrl+Shift+R, so a plain boolean cannot distinguish an initialized
-- widget from one whose old runtime/cache was just replaced.
local UI_GENERATION = {}
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
local HADRON_SEARCH_GAP = 34
local HADRON_SEARCH_ROW_PADDING = 50
local MELK_LIMITED_SEARCH_GAP = -40
local MELK_LIMITED_SEARCH_ROW_PADDING = 40
local MELK_MULTI_SEARCH_GAP = -40
local MELK_MULTI_SEARCH_ROW_PADDING = 45
local BARTER_GRID_OFFSET = 100
local GLOBAL_STORE_MELK_SERVICE = "get_all_characters_marks_store_custom"

local function supported(view)
	local class_name = view and view.__class_name

	return class_name == "InventoryWeaponsView"
		or class_name == "CraftingMechanicusModifyView"
		or class_name == "CraftingMechanicusBarterItemsView"
		or class_name == "CreditsVendorView"
		or class_name == "CreditsGoodsVendorView"
		or class_name == "MarksVendorView"
end

SearchUI.supported = supported

local function melk_route(view, context)
	if not view or view.__class_name ~= "MarksVendorView" then
		return nil
	end

	local remembered = view._better_inventory_search_melk_route

	if remembered ~= nil then
		return remembered ~= false and remembered or nil
	end

	local service = view._optional_store_service or context and context.optional_store_service
	local route = service == nil and "limited"
		or service == GLOBAL_STORE_MELK_SERVICE and "multi"
		or false

	view._better_inventory_search_melk_route = route

	return route ~= false and route or nil
end

local function enabled_for_view(mod, view, context)
	if not supported(view) then
		return false
	elseif mod and type(mod.get) == "function" and mod:get("enable_inventory_search") == false then
		return false
	elseif view.__class_name == "MarksVendorView" then
		return melk_route(view, context) ~= nil
			and mod and type(mod.get) == "function"
			and mod:get("enable_inventory_search_melk") ~= false
			or false
	elseif view.__class_name == "CreditsGoodsVendorView" then
		return mod and type(mod.get) == "function" and mod:get("enable_inventory_search_brunt") == true or false
	end

	return true
end

SearchUI.enabled = enabled_for_view

local function clone(value)
	return type(value) == "table" and table.clone(value) or {}
end

local function merge_definitions(base_definitions, definitions)
	local merged = clone(base_definitions)

	if type(table.merge_recursive) == "function" then
		table.merge_recursive(merged, definitions or {})

		return merged
	end

	local function merge_into(destination, source)
		for key, value in pairs(source or {}) do
			if type(value) == "table" and type(destination[key]) == "table" then
				merge_into(destination[key], value)
			else
				destination[key] = clone(value)
			end
		end
	end

	merge_into(merged, definitions)

	return merged
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

local ESCAPE_BUTTON_INDEX
local ESCAPE_BUTTON_RESOLVED = false

local function keyboard_escape_pressed()
	local keyboard = rawget(_G, "Keyboard")

	if not keyboard or type(keyboard.pressed) ~= "function" then
		return false
	end

	if not ESCAPE_BUTTON_RESOLVED then
		ESCAPE_BUTTON_RESOLVED = true

		if type(keyboard.button_index) == "function" then
			local ok, button_index = pcall(keyboard.button_index, "esc")

			if ok then
				ESCAPE_BUTTON_INDEX = button_index
			end
		end
	end

	return ESCAPE_BUTTON_INDEX ~= nil and keyboard.pressed(ESCAPE_BUTTON_INDEX) == true
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

local function placeholder_localization_id(view)
	return view and view.item_type == "GADGET"
		and "inventory_search_curio_placeholder"
		or "inventory_search_placeholder"
end

local function configured_pixels(mod, setting_id, default_value, maximum, minimum)
	if not mod or type(mod.get) ~= "function" then
		return default_value
	end

	local ok, value = pcall(mod.get, mod, setting_id)
	value = ok and tonumber(value) or nil

	if not value then
		return default_value
	end

	return math.max(minimum or 0, math.min(maximum, math.floor(value + 0.5)))
end

local function search_geometry(definitions, view, mod)
	if view.__class_name == "CraftingMechanicusBarterItemsView" then
		return 16, 58, 486
	elseif view.__class_name == "CraftingMechanicusModifyView" then
		-- Hadron's native 80px grid title reserve is much taller than its tab
		-- frame. Position the field from the actual pivot instead of stacking it
		-- after that reserve, which otherwise wastes most of a card row.
		return 14, configured_pixels(mod, "inventory_search_hadron_top_padding", HADRON_SEARCH_GAP, 64), 568
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
	elseif melk_route(view) == "limited" then
		gap = configured_pixels(mod, "inventory_search_melk_limited_top_padding", MELK_LIMITED_SEARCH_GAP, 64, -50)
	elseif melk_route(view) == "multi" then
		gap = configured_pixels(mod, "inventory_search_melk_multi_top_padding", MELK_MULTI_SEARCH_GAP, 64, -50)
	end

	local y = title_height > 0 and title_height + gap or top_padding + gap

	return 14, math.max(y, 12), 568
end

SearchUI.decorate_definitions = function(definitions, view, mod, context, base_definitions)
	if not supported(view) then
		return definitions
	elseif not enabled_for_view(mod, view, context) then
		if view then
			view._better_inventory_search_ui_unavailable = true
		end

		return definitions
	elseif type(definitions) == "table" and definitions._better_inventory_search_decorated then
		return definitions
	elseif type(definitions) ~= "table" then
		if view then
			view._better_inventory_search_ui_unavailable = true
		end

		return definitions
	end

	-- MarksVendorView reaches ItemGridViewBase with only its vendor-specific
	-- definitions. Darktide merges the shared item-grid definitions inside the
	-- original base initializer, after this decorator runs. Resolve that same
	-- effective table here so Melk can own a search row without mutating either
	-- shared definition source.
	if (type(definitions.scenegraph_definition) ~= "table" or type(definitions.scenegraph_definition.item_grid_pivot) ~= "table")
		and type(base_definitions) == "table"
	then
		definitions = merge_definitions(base_definitions, definitions)
	end

	if type(definitions.scenegraph_definition) ~= "table" or type(definitions.scenegraph_definition.item_grid_pivot) ~= "table" then
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
			or melk_route(view) == "limited"
				and configured_pixels(mod, "inventory_search_melk_limited_bottom_padding", MELK_LIMITED_SEARCH_ROW_PADDING, 96)
			or melk_route(view) == "multi"
				and configured_pixels(mod, "inventory_search_melk_multi_bottom_padding", MELK_MULTI_SEARCH_ROW_PADDING, 96)
			or view.__class_name == "InventoryWeaponsView"
				and configured_pixels(mod, "inventory_search_inventory_bottom_padding", INVENTORY_SEARCH_ROW_PADDING, 96)
			or view.__class_name == "CraftingMechanicusModifyView"
				and configured_pixels(mod, "inventory_search_hadron_bottom_padding", HADRON_SEARCH_ROW_PADDING, 96)
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

local function search_hidden_legend_visibility()
	return false
end

local function restore_input_legend(view, owned)
	for index = 1, #owned do
		local saved = owned[index]
		local entry = saved and saved.entry

		if type(entry) == "table" then
			if saved.hidden_visibility ~= nil then
				-- Restore only the sentinel we own. Another mod replacing visibility
				-- while search is focused keeps its newer state.
				if entry.visibility_function == saved.hidden_visibility then
					entry.visibility_function = saved.visibility_function
					if entry.is_visible == false then
						entry.is_visible = saved.is_visible
					end
				end
			else
				-- One-time hot-reload migration from the retired action-nilling
				-- implementation. A surviving focused view may still own this shape.
				if entry.input_action == nil then
					entry.input_action = saved.input_action
				end
				if entry.extra_input_actions == nil then
					entry.extra_input_actions = saved.extra_input_actions
				end
			end
		end
	end

	view._better_inventory_search_legend_input_owned = nil
end

local function own_input_legend(view, disabled)
	local owned = view and view._better_inventory_search_legend_input_owned

	if disabled then
		if owned then
			local legacy_ownership = owned[1] and owned[1].hidden_visibility == nil

			if not legacy_ownership then
				return true
			end

			restore_input_legend(view, owned)
		end

		local saved = {}
		local legends = {}
		local direct_legend = view and view._input_legend_element
		local parent = view and (view._parent or view._context and view._context.parent)
		local parent_legend = parent and parent._input_legend_element

		if not parent_legend and parent and type(parent._element) == "function" then
			local success, resolved_legend = pcall(parent._element, parent, "input_legend")

			if success then
				parent_legend = resolved_legend
			end
		end

		if direct_legend then
			legends[#legends + 1] = direct_legend
		end

		if parent_legend and parent_legend ~= direct_legend then
			legends[#legends + 1] = parent_legend
		end
		local visited_entries = {}

		for legend_index = 1, #legends do
			local entries = legends[legend_index] and legends[legend_index]._entries

			if type(entries) == "table" then
				for entry_index = 1, #entries do
					local entry = entries[entry_index]

					if type(entry) == "table" and not visited_entries[entry] then
						visited_entries[entry] = true
						saved[#saved + 1] = {
							entry = entry,
							hidden_visibility = search_hidden_legend_visibility,
							is_visible = entry.is_visible,
							visibility_function = entry.visibility_function,
						}
						-- Store hotkeys such as Inspect and Compare belong to the
						-- background parent rather than CreditsVendorView. Own both
						-- legends while typing, but keep every action identifier valid:
						-- InputLegend's dynamic text builder indexes those identifiers.
						entry.visibility_function = search_hidden_legend_visibility
						entry.is_visible = false
					end
				end
			end
		end

		if #saved == 0 then
			return false
		end

		view._better_inventory_search_legend_input_owned = saved

		return true
	end

	if not owned then
		return false
	end

	restore_input_legend(view, owned)

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

	-- SearchUI.update is a post-update callback. Keep the legend actions owned
	-- until that boundary so the Back press which defocused the field cannot
	-- also close the view during the same native update traversal.

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
	-- Mouse/keyboard text entry must leave the grid's native input service live:
	-- wheel scrolling and card hotspots are handled by ViewElementGrid itself.
	-- Controller focus has no pointer escape, so it keeps exclusive grid input
	-- ownership until Down/Back returns selection to the first result.
	own_grid_input(view, controller_navigation_active(view))
	own_input_legend(view, true)

	if content.hotspot then
		content.hotspot.is_selected = true
	end

	return true
end

SearchUI.is_writing = function(view)
	local input = input_widget(view)

	return input and input.content and input.content.is_writing == true or false
end

SearchUI.sync_query = function(mod, Features, view)
	local input = input_widget(view)
	local content = input and input.content

	if not enabled_for_view(mod, view) or not content or type(Features.search_query) ~= "function" then
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

	local visible = enabled_for_view(mod, view)

	input.visible = visible

	if not visible or not input.content then
		if view and not view._better_inventory_search_view_disabled then
			view._better_inventory_search_view_disabled = true

			if type(Features.search_release) == "function" then
				Features.search_release(view)
			end
		end

		SearchUI.defocus(view)
		own_input_legend(view, false)
		return false
	end

	view._better_inventory_search_view_disabled = nil

	local content = input.content
	local query = type(content.input_text) == "string" and content.input_text or ""
	local focus_active = content.is_writing == true or controller_focused(view)
	local should_own_grid_input = focus_active and controller_navigation_active(view)
	local placeholder_id = placeholder_localization_id(view)

	if should_own_grid_input or view._better_inventory_search_grid_input_owned then
		own_grid_input(view, should_own_grid_input)
	end
	if focus_active then
		own_input_legend(view, true)
	elseif view._better_inventory_search_legend_input_owned then
		own_input_legend(view, false)
	end

	if view._better_inventory_search_placeholder_id ~= placeholder_id then
		content.placeholder_text = mod:localize(placeholder_id)
		content.active_placeholder_text = content.placeholder_text
		view._better_inventory_search_placeholder_id = placeholder_id
	end

	if view._better_inventory_search_widget_generation ~= UI_GENERATION then
		view._better_inventory_search_last_text = query
		view._better_inventory_search_widget_initialized = true
		view._better_inventory_search_widget_generation = UI_GENERATION

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

SearchUI.update_view = function(mod, Features, view, time, input_service)
	SearchUI.update(mod, Features, view, time, input_service)

	if view and view._better_inventory_search_needs_update and type(Features.search_update) == "function" then
		Features.search_update(view, time)
	end
end

SearchUI.handle_view_input = function(mod, view, input_service)
	local input = input_widget(view)
	local content = input and input.content

	if not enabled_for_view(mod, view) or not content or input.visible == false then
		return false
	end

	local writing = content.is_writing == true

	if controller_focused(view) then
		if action_pressed(input_service, "navigate_down_continuous") then
			SearchUI.defocus(view)
			restore_first_grid_item(view)
		elseif action_pressed(input_service, "back") or keyboard_escape_pressed() then
			SearchUI.defocus(view)
			restore_first_grid_item(view)
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

	-- Some vendor input services consume their mapped Back action while the
	-- native text pass owns keyboard input. Raw Escape preserves the intended
	-- two-stage flow: first press defocuses search, the next reaches native Back.
	if action_pressed(input_service, "back") or keyboard_escape_pressed() then
		SearchUI.defocus(view)
	end

	return true
end

SearchUI.barter_grid_offset = function()
	return BARTER_GRID_OFFSET
end

SearchUI.release = function(view)
	SearchUI.defocus(view)
	own_input_legend(view, false)

	if view then
		view._better_inventory_search_last_text = nil
		view._better_inventory_search_placeholder_id = nil
		view._better_inventory_search_widget_initialized = nil
		view._better_inventory_search_widget_generation = nil
		view._better_inventory_search_ui_unavailable = nil
		view._better_inventory_search_controller_focused = nil
		view._better_inventory_search_grid_input_owned = nil
		view._better_inventory_search_grid_input_was_disabled = nil
		view._better_inventory_search_legend_input_owned = nil
		view._better_inventory_search_view_disabled = nil
	end
end

return SearchUI
