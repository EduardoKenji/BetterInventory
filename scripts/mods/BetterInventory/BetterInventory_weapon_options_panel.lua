local WeaponOptionsPanel = {}

local DEFAULT_BUTTON_HEIGHT = 60
local DEFAULT_ROW_SPACING = 10
local NATIVE_TRAILING_FRAME_HEIGHT = 40
local MAXIMUM_VISIBLE_ROWS = 7
local BOTTOM_DIVIDER_HEIGHT_OFFSET = 16
local TITLE_TOP_DIVIDER_HEIGHT_OFFSET = 15
local DEBUG_MARKER = "better_inventory_debug_weapon_option"

local function rounded_setting(mod, setting_id, default_value, minimum, maximum)
	local value = mod and type(mod.get) == "function" and tonumber(mod:get(setting_id)) or default_value

	value = math.floor((value or default_value) + 0.5)

	return math.max(minimum, math.min(value, maximum))
end

local function without_debug_entries(layout)
	local filtered = {}

	for index = 1, #(layout or {}) do
		local entry = layout[index]

		if type(entry) == "table" and entry[DEBUG_MARKER] ~= true then
			filtered[#filtered + 1] = entry
		end
	end

	return filtered
end

local function append_debug_entries(mod, layout)
	local target_count = rounded_setting(mod, "debug_weapon_options_button_count", 0, 0, 20)
	local real_count = #layout

	for index = real_count + 1, target_count do
		layout[#layout + 1] = {
			[DEBUG_MARKER] = true,
			callback = function()
				-- Presentation-only stress row. It must never mutate game state.
			end,
			display_icon = "",
			display_name = string.format("BetterInventory test button %d", index),
			widget_type = "button",
		}
	end

	return layout
end

local function entry_height(entry, blueprints)
	local blueprint = type(entry) == "table" and type(blueprints) == "table" and blueprints[entry.widget_type]
	local size = blueprint and blueprint.size

	return type(size) == "table" and tonumber(size[2]) or DEFAULT_BUTTON_HEIGHT
end

local function content_height(layout, blueprints, menu_settings)
	local spacing = menu_settings and menu_settings.grid_spacing
	local row_spacing = type(spacing) == "table" and tonumber(spacing[2]) or DEFAULT_ROW_SPACING
	local height = (tonumber(menu_settings and menu_settings.top_padding) or 0) + NATIVE_TRAILING_FRAME_HEIGHT

	-- Darktide's original three-row frame is 40 px taller than the content end.
	-- Preserve that trailing allowance as a constant; UIWidgetGrid adds only one
	-- spacing unit between rows, so adding two per row makes the bottom gap grow.
	for index = 1, #layout do
		height = height + entry_height(layout[index], blueprints)

		if index > 1 then
			height = height + row_spacing
		end
	end

	return math.floor(height + 0.5)
end

local function visible_rows_geometry(layout, blueprints, menu_settings)
	local spacing = menu_settings and menu_settings.grid_spacing
	local row_spacing = type(spacing) == "table" and tonumber(spacing[2]) or DEFAULT_ROW_SPACING
	local top_padding = tonumber(menu_settings and menu_settings.top_padding) or 0
	local visible_count = math.min(#layout, MAXIMUM_VISIBLE_ROWS)
	local frame_height = top_padding + NATIVE_TRAILING_FRAME_HEIGHT
	local viewport_height = 0

	for index = 1, visible_count do
		local height = entry_height(layout[index], blueprints)

		frame_height = frame_height + height

		if index > 1 then
			frame_height = frame_height + row_spacing
		end

		viewport_height = viewport_height + height + row_spacing
	end

	return math.floor(frame_height + 0.5), math.floor(viewport_height + 0.5)
end

local function divider_deduction(menu_settings)
	if menu_settings.hide_dividers or menu_settings.ignore_divider_height then
		return 0
	end

	return BOTTOM_DIVIDER_HEIGHT_OFFSET + TITLE_TOP_DIVIDER_HEIGHT_OFFSET
end

local function title_height(item_grid, menu_settings)
	if item_grid._display_name_key == nil then
		return 0
	end

	return (tonumber(menu_settings.title_height) or 0) - BOTTOM_DIVIDER_HEIGHT_OFFSET
end

local function finalize_grid_geometry(item_grid)
	if type(item_grid) ~= "table" or item_grid._better_inventory_weapon_options_managed ~= true then
		return false
	end

	local menu_settings = item_grid._menu_settings
	local grid = item_grid._grid

	if type(grid) == "table" and type(menu_settings) == "table" then
		grid._bottom_chin = menu_settings.bottom_chin or 0

		if type(grid.set_enable_gamepad_scrolling) == "function" then
			grid:set_enable_gamepad_scrolling(true)
		end

		if type(grid.force_update_list_size) == "function" then
			grid:force_update_list_size()
		end
	end

	local mask_offset = item_grid._better_inventory_weapon_options_mask_offset

	if type(mask_offset) == "number" and type(item_grid._set_scenegraph_position) == "function" then
		item_grid:_set_scenegraph_position("grid_mask", nil, mask_offset)
	end

	return true
end

local function update_grid_geometry(item_grid, menu_settings, frame_height, viewport_height, overflow)
	local top_padding = tonumber(menu_settings.top_padding) or 0
	local deduction = divider_deduction(menu_settings)
	local used_title_height = title_height(item_grid, menu_settings)
	local mask_height
	local bottom_chin = item_grid._better_inventory_weapon_options_native_bottom_chin

	if bottom_chin == nil then
		bottom_chin = menu_settings.bottom_chin
		item_grid._better_inventory_weapon_options_native_bottom_chin = bottom_chin or false
	elseif bottom_chin == false then
		bottom_chin = nil
	end

	if overflow then
		-- ViewElementGrid centers its mask inside the framed background. Give the
		-- render target exactly seven rows, move its top edge to the content
		-- padding, and reserve the remaining background space as bottom chin.
		-- This clips row eight completely while retaining enough scroll length to
		-- reveal the final row completely at scrollbar progress 1 with the same
		-- trailing inset used by the non-scrolling seven-row frame.
		local background_height = frame_height - deduction - used_title_height
		local spacing = menu_settings.grid_spacing
		local row_spacing = type(spacing) == "table" and tonumber(spacing[2]) or DEFAULT_ROW_SPACING
		local unscrolled_last_button_bottom = top_padding + viewport_height - row_spacing
		local trailing_inset = math.max(background_height - unscrolled_last_button_bottom, 0)

		bottom_chin = trailing_inset
		mask_height = viewport_height + top_padding + deduction + used_title_height
		menu_settings.bottom_chin = bottom_chin
		item_grid._better_inventory_weapon_options_mask_offset = top_padding - (background_height - viewport_height) * 0.5
	else
		local mask_extra = item_grid._better_inventory_weapon_options_mask_extra

		mask_height = frame_height + mask_extra
		menu_settings.bottom_chin = bottom_chin
		item_grid._better_inventory_weapon_options_mask_offset = nil
	end

	item_grid._better_inventory_weapon_options_managed = true

	if type(item_grid.update_grid_height) == "function" then
		item_grid:update_grid_height(frame_height, mask_height)
	else
		menu_settings.grid_size[2] = frame_height
		menu_settings.mask_size[2] = mask_height
	end

	finalize_grid_geometry(item_grid)
end

WeaponOptionsPanel.prepare_layout = function(mod, item_grid, layout, blueprints, view)
	if type(item_grid) ~= "table" or type(view) ~= "table" or item_grid ~= view._weapon_options_element or type(layout) ~= "table" then
		return layout, false
	end

	local menu_settings = item_grid._menu_settings

	if type(menu_settings) ~= "table" or type(menu_settings.grid_size) ~= "table" or type(menu_settings.mask_size) ~= "table" then
		return layout, false
	end

	local prepared_layout = append_debug_entries(mod, without_debug_entries(layout))
	local required_height = content_height(prepared_layout, blueprints, menu_settings)
	local visible_height, viewport_height = visible_rows_geometry(prepared_layout, blueprints, menu_settings)
	local overflow = #prepared_layout > MAXIMUM_VISIBLE_ROWS
	local mask_extra = item_grid._better_inventory_weapon_options_mask_extra

	if type(mask_extra) ~= "number" then
		mask_extra = math.max((tonumber(menu_settings.mask_size[2]) or visible_height) - (tonumber(menu_settings.grid_size[2]) or visible_height), 0)
		item_grid._better_inventory_weapon_options_mask_extra = mask_extra
	end

	menu_settings.enable_gamepad_scrolling = true
	update_grid_geometry(item_grid, menu_settings, visible_height, viewport_height, overflow)

	item_grid._better_inventory_weapon_options_content_height = required_height
	item_grid._better_inventory_weapon_options_viewport_height = viewport_height
	item_grid._better_inventory_weapon_options_overflow = overflow

	return prepared_layout, true
end

WeaponOptionsPanel.DEBUG_MARKER = DEBUG_MARKER
WeaponOptionsPanel.MAXIMUM_VISIBLE_ROWS = MAXIMUM_VISIBLE_ROWS
WeaponOptionsPanel.finalize_layout = finalize_grid_geometry

return WeaponOptionsPanel
