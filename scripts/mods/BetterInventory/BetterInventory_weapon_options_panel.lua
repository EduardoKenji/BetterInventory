local WeaponOptionsPanel = {}

local DEFAULT_MAX_HEIGHT = 360
local MINIMUM_MAX_HEIGHT = 220
local MAXIMUM_MAX_HEIGHT = 600
local DEFAULT_BUTTON_HEIGHT = 60
local DEFAULT_ROW_SPACING = 10
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
	local height = tonumber(menu_settings and menu_settings.top_padding) or 0

	-- Darktide's native weapon-options geometry budgets one spacing unit on both
	-- sides of every action row: (button_height + 20) * count at spacing 10.
	for index = 1, #layout do
		height = height + entry_height(layout[index], blueprints) + row_spacing * 2
	end

	return math.floor(height + 0.5)
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
	local maximum_height = rounded_setting(mod, "weapon_options_panel_max_height", DEFAULT_MAX_HEIGHT, MINIMUM_MAX_HEIGHT, MAXIMUM_MAX_HEIGHT)
	local visible_height = math.min(required_height, maximum_height)
	local mask_extra = item_grid._better_inventory_weapon_options_mask_extra

	if type(mask_extra) ~= "number" then
		mask_extra = math.max((tonumber(menu_settings.mask_size[2]) or visible_height) - (tonumber(menu_settings.grid_size[2]) or visible_height), 0)
		item_grid._better_inventory_weapon_options_mask_extra = mask_extra
	end

	menu_settings.enable_gamepad_scrolling = true

	if type(item_grid.update_grid_height) == "function" then
		item_grid:update_grid_height(visible_height, visible_height + mask_extra)
	else
		menu_settings.grid_size[2] = visible_height
		menu_settings.mask_size[2] = visible_height + mask_extra
	end

	item_grid._better_inventory_weapon_options_content_height = required_height
	item_grid._better_inventory_weapon_options_overflow = required_height > visible_height

	return prepared_layout, true
end

WeaponOptionsPanel.DEBUG_MARKER = DEBUG_MARKER

return WeaponOptionsPanel
