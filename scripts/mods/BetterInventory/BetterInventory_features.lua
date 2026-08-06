local Items = require("scripts/utilities/items")
local ProfileUtils = require("scripts/utilities/profile_utils")
local RaritySettings = require("scripts/settings/item/rarity_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local CurioValues = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_curio_values")

if type(CurioValues) ~= "table" then
	CurioValues = {
		resolve = function()
			return
		end,
	}
end

local Features = {}

local function shallow_copy(source)
	local copy = {}

	for key, value in pairs(source or {}) do
		copy[key] = value
	end

	return copy
end
local INVENTORY_SORT_TOGGLE_ID = "better_inventory_sort_priority"
local INVENTORY_PERFECT_SORT_TOGGLE_ID = "better_inventory_perfect_sort_priority"
local INVENTORY_SORT_LABEL_ID = "better_inventory_sort_label"
local INVENTORY_DISCARD_LABEL_ID = "better_inventory_discard_label"
local INVENTORY_DISCARD_MODE_ID = "better_inventory_discard_mode"
local INVENTORY_DISCARD_SKIP_CONFIRMATION_ID = "better_inventory_discard_skip_confirmation"
local INVENTORY_QUICK_DISCARD_ID = "better_inventory_quick_discard"
local INVENTORY_DISCARD_MAX_LEVEL_ID = "better_inventory_discard_max_level"
local INVENTORY_DISCARD_EQUIPPED_LEVEL_PROTECTION_ID = "better_inventory_discard_equipped_level_protection"
local INVENTORY_DISCARD_MELEE_ID = "better_inventory_discard_melee"
local INVENTORY_DISCARD_RANGED_ID = "better_inventory_discard_ranged"
local INVENTORY_DISCARD_CURIO_ID = "better_inventory_discard_curio"
local INVENTORY_DISCARD_PROTECTION_ID = "better_inventory_discard_protection"
local INVENTORY_DISCARD_CURIO_PROTECTION_ID = "better_inventory_discard_curio_protection"
local INVENTORY_DISCARD_CURIO_LEVEL_ID = "better_inventory_discard_curio_level"
local INVENTORY_CURIO_BUYER_ENABLE_ID = "better_inventory_curio_buyer_enable"
local INVENTORY_CURIO_BUYER_TARGET_MODE_ID = "better_inventory_curio_buyer_target_mode"
local INVENTORY_CURIO_BUYER_MIN_LEVEL_ID = "better_inventory_curio_buyer_min_level"
local INVENTORY_CURIO_BUYER_MIN_HEALTH_ID = "better_inventory_curio_buyer_min_health"
local INVENTORY_CURIO_BUYER_MIN_TOUGHNESS_ID = "better_inventory_curio_buyer_min_toughness"
local INVENTORY_OPTIONS_PANEL_REFERENCE = "better_inventory_options_panel"
local INVENTORY_OPTIONS_PANEL_MIN_HEIGHT = 120
local INVENTORY_OPTIONS_PANEL_DEFAULT_WIDTH = 445
local INVENTORY_OPTIONS_PANEL_DEFAULT_MAX_HEIGHT = 360
local INVENTORY_OPTIONS_PANEL_DEFAULT_ROW_SPACING = 8
local INVENTORY_OPTIONS_PANEL_DEFAULT_VERTICAL_PADDING = 10
local INVENTORY_OPTIONS_PANEL_DEFAULT_HORIZONTAL_PADDING = 12
local INVENTORY_OPTIONS_PANEL_WEAPON_GAP = 20
local INVENTORY_OPTIONS_PANEL_BUTTON_GAP = 15
local ARMOURY_NATIVE_SORT_PANEL_REFERENCE = "better_inventory_armoury_native_sort_panel"
local ARMOURY_NATIVE_SORT_PANEL_WIDTH = 350
local ARMOURY_NATIVE_SORT_PANEL_HEIGHT = 520
local ARMOURY_NATIVE_SORT_PANEL_MIN_HEIGHT = 140
local ARMOURY_NATIVE_SORT_PANEL_TOP = 100
local ARMOURY_NATIVE_SORT_PANEL_RIGHT_MARGIN = 120
local ARMOURY_NATIVE_SORT_PANEL_WEAPON_GAP = 24
local ARMOURY_NATIVE_SORT_PANEL_WALLET_GAP = 16
local ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT = 32
local ARMOURY_NATIVE_SORT_PANEL_ROW_SPACING = 4
local ARMOURY_NATIVE_SORT_PANEL_PADDING = 10
local ARMOURY_NATIVE_SORT_CHECKBOX_LEFT_PADDING = 8
local GLOBAL_STORE_SERVICE = "get_all_characters_store_custom"
local INVENTORY_CURIO_NATIVE_WIDTH = 530
local INVENTORY_CURIO_NATIVE_GRID_WIDTH = 518
local INVENTORY_CURIO_NATIVE_HEADER_HEIGHT = 250
local INVENTORY_CURIO_NATIVE_ICON_HEIGHT = 180
local INVENTORY_VIRTUAL_CANVAS_WIDTH = 1920
local INVENTORY_VIRTUAL_EDGE_MARGIN = 16

local function numeric_setting(mod, setting_id, default_value, minimum, maximum)
	local value = tonumber(mod:get(setting_id)) or default_value

	return math.clamp(math.floor(value + 0.5), minimum, maximum)
end

local function inventory_options_panel_geometry(mod)
	local width = numeric_setting(mod, "inventory_options_panel_width", INVENTORY_OPTIONS_PANEL_DEFAULT_WIDTH, 360, 560)
	local left = numeric_setting(mod, "inventory_options_panel_padding_left", INVENTORY_OPTIONS_PANEL_DEFAULT_HORIZONTAL_PADDING, 0, 24)
	local right = numeric_setting(mod, "inventory_options_panel_padding_right", INVENTORY_OPTIONS_PANEL_DEFAULT_HORIZONTAL_PADDING, 0, 24)

	return {
		bottom = numeric_setting(mod, "inventory_options_panel_padding_bottom", INVENTORY_OPTIONS_PANEL_DEFAULT_VERTICAL_PADDING, 0, 24),
		content_width = math.max(width - left - right, 280),
		left = left,
		max_height = numeric_setting(mod, "inventory_options_panel_max_height", INVENTORY_OPTIONS_PANEL_DEFAULT_MAX_HEIGHT, 220, 500),
		right = right,
		row_spacing = numeric_setting(mod, "inventory_options_panel_row_spacing", INVENTORY_OPTIONS_PANEL_DEFAULT_ROW_SPACING, 0, 16),
		top = numeric_setting(mod, "inventory_options_panel_padding_top", INVENTORY_OPTIONS_PANEL_DEFAULT_VERTICAL_PADDING, 0, 24),
		width = width,
	}
end
local INVENTORY_DISCARD_WIDGET_IDS = {
	INVENTORY_DISCARD_LABEL_ID,
	INVENTORY_DISCARD_MODE_ID,
	INVENTORY_DISCARD_SKIP_CONFIRMATION_ID,
	INVENTORY_QUICK_DISCARD_ID,
	INVENTORY_DISCARD_MAX_LEVEL_ID,
	INVENTORY_DISCARD_MELEE_ID,
	INVENTORY_DISCARD_RANGED_ID,
	INVENTORY_DISCARD_CURIO_ID,
	INVENTORY_DISCARD_PROTECTION_ID,
	INVENTORY_DISCARD_CURIO_PROTECTION_ID,
	INVENTORY_DISCARD_CURIO_LEVEL_ID,
}
local registered_inventory_views = setmetatable({}, {
	__mode = "k",
})
local registered_armoury_views = setmetatable({}, {
	__mode = "k",
})
local perfect_roll_cache = setmetatable({}, {
	__mode = "k",
})
local curio_acquisition_provider
local lantern_mod
local lantern_overlay
local item_sorting_mod
local item_sorting_definitions
local ITEM_SORTING_INVENTORY_VANILLA_SETTINGS = {
	"enable_vanilla_level_desc",
	"enable_vanilla_level_asc",
	"enable_vanilla_rarity_desc",
	"enable_vanilla_rarity_asc",
	"enable_vanilla_name_asc",
	"enable_vanilla_name_desc",
}
local ITEM_SORTING_STORE_VANILLA_SETTINGS = {
	"enable_vanilla_level_desc",
	"enable_vanilla_level_asc",
	"enable_vanilla_rarity_desc",
	"enable_vanilla_rarity_asc",
	"enable_vanilla_price_asc",
	"enable_vanilla_price_desc",
	"enable_vanilla_name_asc",
	"enable_vanilla_name_desc",
}

local function item_sorting_is_enabled()
	if not item_sorting_mod then
		return false
	end

	if type(item_sorting_mod.is_enabled) ~= "function" then
		return true
	end

	local success, enabled = pcall(item_sorting_mod.is_enabled, item_sorting_mod)

	return success and enabled == true
end

Features.set_curio_acquisition_provider = function(provider)
	curio_acquisition_provider = type(provider) == "table" and provider or nil
end

local function known_curio_buyer_profiles(mod)
	if not curio_acquisition_provider or type(curio_acquisition_provider.known_profiles) ~= "function" then
		return {}
	end

	local profiles = curio_acquisition_provider.known_profiles(mod)

	if type(profiles) ~= "table" then
		return {}
	end

	if type(curio_acquisition_provider.request_profile_discovery) == "function" then
		-- The provider coalesces these requests and refreshes only when its cache is
		-- empty or stale. Keeping this call here lets opening the inventory panel
		-- pick up renamed, created or deleted operatives without frame-by-frame
		-- backend traffic.
		curio_acquisition_provider.request_profile_discovery()
	end

	return profiles
end

local function curio_buyer_profile_revision()
	if curio_acquisition_provider and type(curio_acquisition_provider.profile_revision) == "function" then
		return tonumber(curio_acquisition_provider.profile_revision()) or 0
	end

	return 0
end

local function inventory_slot_kind(layout, view)
	if not view or view.__class_name ~= "InventoryWeaponsView" then
		return
	end

	local slot_kind = layout.slot_kind(view)

	if slot_kind == "slot_primary" or slot_kind == "slot_secondary" or slot_kind == "curio" then
		return slot_kind
	end
end

local function is_inventory_view(layout, view)
	return inventory_slot_kind(layout, view) ~= nil
end

local function inventory_grid_has_right_neighbour(view)
	local item_grid = view and view._item_grid
	local selected_index = item_grid and type(item_grid.selected_grid_index) == "function" and item_grid:selected_grid_index()
	local widgets = item_grid and type(item_grid.widgets) == "function" and item_grid:widgets()
	local selected_widget = selected_index and widgets and widgets[selected_index]
	local selected_row = selected_widget and selected_widget.content and selected_widget.content.row

	if type(selected_index) ~= "number" or type(widgets) ~= "table" or type(selected_row) ~= "number" then
		return false
	end

	for index = selected_index + 1, #widgets do
		local widget = widgets[index]
		local content = widget and widget.content
		local row = content and content.row

		if type(row) == "number" and row > selected_row then
			break
		end

		if row == selected_row and content.hotspot then
			return true
		end
	end

	return false
end

Features.capture_inventory_controller_navigation = function(view, input_service)
	if view then
		view._better_inventory_keep_right_navigation_in_grid = false
	end

	local weapon_options = view and view._weapon_options_element
	local item_grid = view and view._item_grid

	if not view or view._using_cursor_navigation ~= false or view._selected_options == true or not weapon_options or not item_grid or not input_service or type(input_service.get) ~= "function" then
		return false
	end

	local options_visible = type(weapon_options.visible) == "function" and weapon_options:visible()
	local options_input_disabled = type(weapon_options.input_disabled) == "function" and weapon_options:input_disabled()
	local item_grid_input_disabled = type(item_grid.input_disabled) == "function" and item_grid:input_disabled()

	if not options_visible or not options_input_disabled or item_grid_input_disabled or not input_service:get("navigate_right_continuous") or not inventory_grid_has_right_neighbour(view) then
		return false
	end

	view._better_inventory_keep_right_navigation_in_grid = true

	return true
end

Features.consume_inventory_controller_grid_navigation = function(view)
	local keep_in_grid = view and view._better_inventory_keep_right_navigation_in_grid == true

	if view then
		view._better_inventory_keep_right_navigation_in_grid = false
	end

	return keep_in_grid
end

local function is_armoury_requisition_view(view)
	return view and view.__class_name == "CreditsVendorView" and view._optional_store_service == nil
end

local function is_global_store_view(view)
	return view and view.__class_name == "CreditsVendorView" and view._optional_store_service == GLOBAL_STORE_SERVICE
end

local function is_armoury_sort_view(view)
	return is_armoury_requisition_view(view) or is_global_store_view(view)
end

local function is_sortable_view(layout, view)
	return is_inventory_view(layout, view) or is_armoury_sort_view(view)
end

local function inventory_sort_toggle_passes()
	return {
		{
			content_id = "hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
		},
		{
			pass_type = "rect",
			style_id = "checkbox_background",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				color = Color.terminal_background(220, true),
				size = {
					26,
					26,
				},
				offset = {
					0,
					0,
					1,
				},
			},
		},
		{
			pass_type = "texture",
			style_id = "checkbox_frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				color = Color.terminal_frame(255, true),
				size = {
					26,
					26,
				},
				offset = {
					0,
					0,
					2,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "checkmark",
			value = "",
			style = {
				font_size = 20,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "left",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				vertical_alignment = "center",
				text_color = Color.terminal_corner_selected(255, true),
				size = {
					26,
					26,
				},
				offset = {
					0,
					0,
					3,
				},
			},
			visibility_function = function(content)
				return content.checked
			end,
		},
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			style = {
				font_size = 18,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "left",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					36,
					0,
					3,
				},
				size_addition = {
					-36,
					0,
				},
			},
		},
	}
end

local function quick_discard_passes()
	local function visible(content)
		return content.visible or content.parent and content.parent.visible
	end

	return {
		{
			pass_type = "text",
			style_id = "prefix",
			value_id = "prefix",
			style = {
				font_size = 16,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					0,
					0,
					3,
				},
				size = {
					70,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			content_id = "rarity_hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
			style = {
				offset = {
					70,
					0,
					5,
				},
				size = {
					110,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			pass_type = "rect",
			style_id = "rarity_background",
			style = {
				color = Color.terminal_background(220, true),
				offset = {
					70,
					0,
					1,
				},
				size = {
					110,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			pass_type = "texture",
			style_id = "rarity_frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				color = Color.terminal_frame(255, true),
				offset = {
					70,
					0,
					2,
				},
				size = {
					110,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			pass_type = "text",
			style_id = "rarity_label",
			value_id = "rarity_label",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					70,
					0,
					3,
				},
				size = {
					110,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			pass_type = "text",
			style_id = "suffix",
			value_id = "suffix",
			style = {
				font_size = 14,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					184,
					0,
					3,
				},
				size = {
					70,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			content_id = "discard_hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
			style = {
				horizontal_alignment = "right",
				offset = {
					0,
					0,
					5,
				},
				size = {
					140,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			pass_type = "rect",
			style_id = "discard_background",
			style = {
				horizontal_alignment = "right",
				color = Color.terminal_background_selected(230, true),
				offset = {
					0,
					0,
					1,
				},
				size = {
					140,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			pass_type = "texture",
			style_id = "discard_frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				horizontal_alignment = "right",
				color = Color.terminal_frame_selected(255, true),
				offset = {
					0,
					0,
					2,
				},
				size = {
					140,
					32,
				},
			},
			visibility_function = visible,
		},
		{
			pass_type = "text",
			style_id = "discard_label",
			value_id = "discard_label",
			style = {
				horizontal_alignment = "right",
				font_size = 16,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_header(255, true),
				offset = {
					0,
					0,
					3,
				},
				size = {
					140,
					32,
				},
			},
			visibility_function = visible,
		},
	}
end

local function section_label_passes()
	return {
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			style = {
				font_size = 19,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "left",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				vertical_alignment = "center",
				text_color = Color.terminal_text_header(255, true),
				offset = {
					0,
					0,
					3,
				},
			},
		},
	}
end

local function compact_selector_passes(width, fixed_selector_width, inline_label)
	local selector_x = inline_label and 0 or 64
	local maximum_selector_width = inline_label and math.max(1, width - 100) or width - selector_x
	local selector_width = math.min(fixed_selector_width or maximum_selector_width, maximum_selector_width)
	local label_x = inline_label and selector_width + 8 or 0
	local label_width = inline_label and math.max(1, width - label_x) or selector_x - 6

	return {
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = inline_label and {
					label_x,
					0,
					3,
				} or nil,
				size = {
					label_width,
					26,
				},
			},
		},
		{
			content_id = "hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
			style = {
				offset = {
					selector_x,
					0,
					5,
				},
				size = {
					selector_width,
					26,
				},
			},
		},
		{
			pass_type = "rect",
			style_id = "background",
			style = {
				color = Color.terminal_background(220, true),
				offset = {
					selector_x,
					0,
					1,
				},
				size = {
					selector_width,
					26,
				},
			},
		},
		{
			pass_type = "texture",
			style_id = "frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				color = Color.terminal_frame(255, true),
				offset = {
					selector_x,
					0,
					2,
				},
				size = {
					selector_width,
					26,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "value",
			value_id = "value",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					selector_x,
					0,
					3,
				},
				size = {
					selector_width,
					26,
				},
			},
		},
	}
end

local function compact_checkbox_passes()
	return {
		{
			content_id = "hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
		},
		{
			pass_type = "rect",
			style_id = "checkbox_background",
			style = {
				color = Color.terminal_background(220, true),
				offset = {
					0,
					2,
					1,
				},
				size = {
					22,
					22,
				},
			},
		},
		{
			pass_type = "texture",
			style_id = "checkbox_frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				color = Color.terminal_frame(255, true),
				offset = {
					0,
					2,
					2,
				},
				size = {
					22,
					22,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "checkmark",
			value = "",
			style = {
				font_size = 17,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_corner_selected(255, true),
				offset = {
					0,
					2,
					3,
				},
				size = {
					22,
					22,
				},
			},
			visibility_function = function(content)
				return content.checked
			end,
		},
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					28,
					0,
					3,
				},
				size_addition = {
					-28,
					0,
				},
			},
		},
	}
end

local function compact_stepper_passes(width)
	local controls_x = width - 138

	return {
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				size = {
					controls_x - 8,
					26,
				},
			},
		},
		{
			content_id = "decrease_hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
			style = {
				offset = {
					controls_x,
					0,
					5,
				},
				size = {
					32,
					26,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "decrease_label",
			value = "<",
			style = {
				font_size = 16,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_header(255, true),
				offset = {
					controls_x,
					0,
					3,
				},
				size = {
					32,
					26,
				},
			},
		},
		{
			pass_type = "rect",
			style_id = "value_background",
			style = {
				color = Color.terminal_background(220, true),
				offset = {
					controls_x + 34,
					0,
					1,
				},
				size = {
					70,
					26,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "value",
			value_id = "value",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					controls_x + 34,
					0,
					3,
				},
				size = {
					70,
					26,
				},
			},
		},
		{
			content_id = "increase_hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
			style = {
				offset = {
					controls_x + 106,
					0,
					5,
				},
				size = {
					32,
					26,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "increase_label",
			value = ">",
			style = {
				font_size = 16,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_header(255, true),
				offset = {
					controls_x + 106,
					0,
					3,
				},
				size = {
					32,
					26,
				},
			},
		},
	}
end

local function panel_sub_label_passes(width)
	return {
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				size = {
					width,
					26,
				},
			},
		},
	}
end

local function panel_section_header_passes(width)
	local height = 40

	return {
		{
			content_id = "hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
		},
		{
			pass_type = "rect",
			style_id = "background",
			style = {
				color = Color.terminal_background(210, true),
				offset = {
					0,
					0,
					1,
				},
				size = {
					width,
					height,
				},
			},
		},
		{
			pass_type = "texture",
			style_id = "frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				color = Color.terminal_frame(255, true),
				offset = {
					0,
					0,
					2,
				},
				size = {
					width,
					height,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			style = {
				font_size = 18,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_header(255, true),
				offset = {
					10,
					0,
					3,
				},
				size = {
					width - 50,
					height,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "chevron",
			value_id = "chevron",
			style = {
				font_size = 18,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "right",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_header(255, true),
				offset = {
					0,
					0,
					3,
				},
				size = {
					40,
					height,
				},
			},
		},
	}
end

local function armoury_native_sort_option_passes(width)
	local function selected(content)
		return content.selected == true
	end

	local function not_selected(content)
		return not selected(content)
	end

	return {
		{
			content_id = "hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = UISoundEvents.default_mouse_hover,
				on_pressed_sound = UISoundEvents.default_click,
			},
		},
		{
			pass_type = "rect",
			style_id = "background",
			style = {
				color = Color.terminal_background(220, true),
				offset = {
					0,
					0,
					1,
				},
				size = {
					width,
					ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT,
				},
			},
		},
		{
			pass_type = "rect",
			style_id = "selected_background",
			style = {
				color = Color.terminal_corner_selected(90, true),
				offset = {
					0,
					0,
					2,
				},
				size = {
					width,
					ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT,
				},
			},
			visibility_function = selected,
		},
		{
			pass_type = "texture",
			style_id = "frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				color = Color.terminal_frame(255, true),
				offset = {
					0,
					0,
					3,
				},
				size = {
					width,
					ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT,
				},
			},
		},
		{
			pass_type = "text",
			style_id = "label",
			value_id = "label",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_text_body(255, true),
				offset = {
					12,
					0,
					4,
				},
				size = {
					width - 24,
					ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT,
				},
			},
			visibility_function = not_selected,
		},
		{
			pass_type = "text",
			style_id = "selected_label",
			value_id = "label",
			style = {
				font_size = 15,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = Color.terminal_corner_selected(255, true),
				offset = {
					12,
					0,
					4,
				},
				size = {
					width - 24,
					ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT,
				},
			},
			visibility_function = selected,
		},
		{
			pass_type = "text",
			style_id = "selected_mark",
			value = "✓",
			style = {
				font_size = 16,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "right",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = Color.terminal_corner_selected(255, true),
				offset = {
					-4,
					0,
					5,
				},
				size = {
					28,
					ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT,
				},
			},
			visibility_function = selected,
		},
	}
end

local function append_panel_checkbox_passes(target, prefix, x, width, checked_id, label_id, optional_visibility_id)
	local source = compact_checkbox_passes()

	for index = 1, #source do
		local pass = table.clone(source[index])
		local original_style_id = pass.style_id

		if pass.content_id == "hotspot" then
			pass.content_id = prefix .. "_hotspot"
		end

		if original_style_id then
			pass.style_id = prefix .. "_" .. original_style_id
		end

		if pass.value_id == "label" then
			pass.value_id = label_id
		end

		local style = pass.style or {}
		local offset = style.offset or {
			0,
			0,
			0,
		}

		offset[1] = (offset[1] or 0) + x
		-- Embedded controls share a widget with the selector to their left. Keep
		-- their input and draw passes above that selector instead of relying on
		-- equal-z pass ordering, which made this checkbox intermittently inert.
		offset[3] = (offset[3] or 0) + 10
		style.offset = offset

		if pass.content_id == prefix .. "_hotspot" then
			style.size = {
				width,
				26,
			}
		elseif original_style_id == "label" then
			style.size_addition = nil
			style.size = {
				math.max(width - 28, 0),
				26,
			}
		end

		pass.style = style

		if original_style_id == "checkmark" then
			pass.visibility_function = function(content)
				return (not optional_visibility_id or content[optional_visibility_id]) and content[checked_id]
			end
		elseif optional_visibility_id then
			pass.visibility_function = function(content)
				return content[optional_visibility_id]
			end
		end

		target[#target + 1] = pass
	end
end

local function panel_type_checkbox_passes(content_width)
	local passes = {}
	local gap = 8
	local width = math.floor((content_width - gap * 2) / 3)

	append_panel_checkbox_passes(passes, "melee", 0, width, "melee_checked", "melee_label")
	append_panel_checkbox_passes(passes, "ranged", width + gap, width, "ranged_checked", "ranged_label")
	append_panel_checkbox_passes(passes, "curio", (width + gap) * 2, width, "curio_checked", "curio_label")

	return passes
end

Features.add_inventory_sort_toggle_definition = function(mod, layout, definitions, view)
	local slot_kind = inventory_slot_kind(layout, view)

	if not slot_kind or not definitions then
		return definitions
	end

	local adjusted_definitions = table.clone(definitions)
	local scenegraph = adjusted_definitions.scenegraph_definition
	local widget_definitions = adjusted_definitions.widget_definitions
	local focus_action = mod:get("inventory_options_controller_focus_keybind")

	if focus_action and focus_action ~= "off" and type(adjusted_definitions.legend_inputs) == "table" then
		adjusted_definitions.legend_inputs[#adjusted_definitions.legend_inputs + 1] = {
			alignment = "right_alignment",
			display_name = "better_inventory_toggle_panel_focus",
			input_action = focus_action,
			visibility_function = function(parent)
				return parent._using_cursor_navigation == false and parent._better_inventory_options_panel_visible == true
			end,
		}
	end

	if not scenegraph or not widget_definitions then
		return adjusted_definitions
	end

	local is_curio = slot_kind == "curio"

	if is_curio and mod:get("enable_inventory_options_panel_prototype") == true then
		local width_percent = numeric_setting(mod, "curio_information_width_percent", 90, 75, 100)
		local target_width = math.floor(INVENTORY_CURIO_NATIVE_WIDTH * width_percent / 100 + 0.5)
		local source_settings = adjusted_definitions.weapon_stats_grid_settings

		if type(source_settings) == "table" then
			local stats_settings = table.clone(source_settings)
			local edge_padding = tonumber(stats_settings.edge_padding) or 12

			stats_settings.grid_size = table.clone(stats_settings.grid_size or {})
			stats_settings.mask_size = table.clone(stats_settings.mask_size or {})
			stats_settings.grid_size[1] = math.max(target_width - edge_padding, 1)
			stats_settings.mask_size[1] = target_width + 40
			adjusted_definitions.weapon_stats_grid_settings = stats_settings
		end
	end

	local parent = is_curio and "weapon_stats_pivot" or "weapon_compare_stats_pivot"
	local width = is_curio and 530 or 420
	local initial_x = is_curio and 0 or 20
	local initial_y = is_curio and 500 or 320

	scenegraph[INVENTORY_SORT_LABEL_ID] = {
		horizontal_alignment = "left",
		parent = parent,
		vertical_alignment = "top",
		size = {
			width,
			26,
		},
		position = {
			initial_x,
			initial_y,
			20,
		},
	}
	widget_definitions[INVENTORY_SORT_LABEL_ID] = UIWidget.create_definition(section_label_passes(), INVENTORY_SORT_LABEL_ID, {
		label = mod:localize("inventory_sorting_inventory_label"),
	})

	scenegraph[INVENTORY_SORT_TOGGLE_ID] = {
		horizontal_alignment = "left",
		parent = parent,
		vertical_alignment = "top",
		size = {
			width - 15,
			32,
		},
		position = {
			initial_x + 15,
			initial_y + 28,
			20,
		},
	}
	widget_definitions[INVENTORY_SORT_TOGGLE_ID] = UIWidget.create_definition(inventory_sort_toggle_passes(), INVENTORY_SORT_TOGGLE_ID, {
		checked = mod:get("prioritize_equipped_favorites") ~= false,
		label = mod:localize("prioritize_equipped_favorites_inventory_label"),
	})

	if mod:get("enable_experimental_quick_discard") == true then
		local compact_x = initial_x + 15
		-- Curio details use a wider panel than weapons, but stretching the controls
		-- across all 530 pixels leaves the action and steppers visually detached.
		-- Keep the already-good weapon geometry and give Curios the same footprint.
		local control_width = is_curio and 420 or width
		local compact_width = control_width - 15
		local type_gap = 8
		local type_width = math.floor((compact_width - type_gap * 2) / 3)
		local mode_width = 190
		local function add_compact_checkbox(scenegraph_id, x, y, checkbox_width, label, checked)
			scenegraph[scenegraph_id] = {
				horizontal_alignment = "left",
				parent = parent,
				vertical_alignment = "top",
				size = {
					checkbox_width,
					26,
				},
				position = {
					x,
					y,
					20,
				},
			}
			widget_definitions[scenegraph_id] = UIWidget.create_definition(compact_checkbox_passes(), scenegraph_id, {
				checked = checked,
				hotspot = {},
				label = label,
			})
		end
		local function add_compact_stepper(scenegraph_id, y, label, value)
			scenegraph[scenegraph_id] = {
				horizontal_alignment = "left",
				parent = parent,
				vertical_alignment = "top",
				size = {
					compact_width,
					26,
				},
				position = {
					compact_x,
					y,
					20,
				},
			}
			widget_definitions[scenegraph_id] = UIWidget.create_definition(compact_stepper_passes(compact_width), scenegraph_id, {
				decrease_hotspot = {},
				increase_hotspot = {},
				label = label,
				value = tostring(value),
			})
		end

		scenegraph[INVENTORY_DISCARD_LABEL_ID] = {
			horizontal_alignment = "left",
			parent = parent,
			vertical_alignment = "top",
			size = {
				width,
				26,
			},
			position = {
				initial_x,
				initial_y + 70,
				20,
			},
		}
		local discard_mode = mod:get("quick_discard_mode") == "automatic" and "automated" or "manual"

		widget_definitions[INVENTORY_DISCARD_LABEL_ID] = UIWidget.create_definition(section_label_passes(), INVENTORY_DISCARD_LABEL_ID, {
			label = mod:localize("inventory_" .. discard_mode .. "_discard_management_inventory_label"),
		})

		scenegraph[INVENTORY_DISCARD_MODE_ID] = {
			horizontal_alignment = "left",
			parent = parent,
			vertical_alignment = "top",
			size = {
				mode_width,
				26,
			},
			position = {
				compact_x,
				initial_y + 100,
				20,
			},
		}
		widget_definitions[INVENTORY_DISCARD_MODE_ID] = UIWidget.create_definition(compact_selector_passes(mode_width), INVENTORY_DISCARD_MODE_ID, {
			hotspot = {},
			label = mod:localize("quick_discard_inventory_mode"),
			value = mod:localize("quick_discard_mode_" .. (mod:get("quick_discard_mode") or "manual")) .. "  ›",
		})

		add_compact_checkbox(INVENTORY_DISCARD_SKIP_CONFIRMATION_ID, compact_x + mode_width + 10, initial_y + 100, compact_width - mode_width - 10, mod:localize("quick_discard_skip_automatic_confirmation"), mod:get("quick_discard_skip_automatic_confirmation") == true)

		scenegraph[INVENTORY_QUICK_DISCARD_ID] = {
			horizontal_alignment = "left",
			parent = parent,
			vertical_alignment = "top",
			size = {
				compact_width,
				32,
			},
			position = {
				compact_x,
				initial_y + 136,
				20,
			},
		}
		widget_definitions[INVENTORY_QUICK_DISCARD_ID] = UIWidget.create_definition(quick_discard_passes(), INVENTORY_QUICK_DISCARD_ID, {
			discard_label = mod:localize("quick_discard_inventory_action"),
			prefix = mod:localize("quick_discard_inventory_prefix"),
			rarity_hotspot = {},
			discard_hotspot = {},
			rarity_label = mod:localize("quick_discard_rarity_1") .. "  ›",
			suffix = mod:localize("quick_discard_inventory_suffix"),
			visible = true,
		})

		add_compact_stepper(INVENTORY_DISCARD_MAX_LEVEL_ID, initial_y + 172, mod:localize("quick_discard_inventory_max_level"), math.floor(tonumber(mod:get("quick_discard_max_item_level")) or 490))
		add_compact_checkbox(INVENTORY_DISCARD_MELEE_ID, compact_x, initial_y + 206, type_width, mod:localize("quick_discard_inventory_melee"), mod:get("quick_discard_include_melee") ~= false)
		add_compact_checkbox(INVENTORY_DISCARD_RANGED_ID, compact_x + type_width + type_gap, initial_y + 206, type_width, mod:localize("quick_discard_inventory_ranged"), mod:get("quick_discard_include_ranged") ~= false)
		add_compact_checkbox(INVENTORY_DISCARD_CURIO_ID, compact_x + (type_width + type_gap) * 2, initial_y + 206, type_width, mod:localize("quick_discard_inventory_curios"), mod:get("quick_discard_include_curios") ~= false)

		add_compact_checkbox(INVENTORY_DISCARD_PROTECTION_ID, compact_x, initial_y + 240, compact_width, mod:localize("quick_discard_inventory_protect_weapons"), mod:get("quick_discard_protect_perfect_weapons") ~= false)
		add_compact_checkbox(INVENTORY_DISCARD_CURIO_PROTECTION_ID, compact_x, initial_y + 274, compact_width, mod:localize("quick_discard_inventory_protect_curios"), mod:get("quick_discard_protect_high_level_curios") ~= false)
		add_compact_stepper(INVENTORY_DISCARD_CURIO_LEVEL_ID, initial_y + 308, mod:localize("quick_discard_inventory_curio_level"), math.floor(tonumber(mod:get("quick_discard_curio_protection_level")) or 410))
	end

	return adjusted_definitions
end

local rebuild_inventory_options_panel

local INVENTORY_OPTIONS_PANEL_BLUEPRINTS = {
	better_inventory_control = {
		size_function = function(_, entry)
			return entry.size
		end,
		pass_template_function = function(_, entry)
			return entry.pass_template
		end,
		init = function(_, widget, entry)
			local content = widget.content

			for key, value in pairs(entry.initial_content or {}) do
				content[key] = value
			end

			content.entry = entry

			local view = entry.view

			if view then
				view._better_inventory_options_panel_widgets = view._better_inventory_options_panel_widgets or {}
				view._better_inventory_options_panel_widgets[entry.control_id] = widget
			end

			if entry.bind then
				entry.bind(widget)
			end

			if entry.refresh then
				entry.refresh(widget)
			end
		end,
		update = function(_, widget)
			local entry = widget.content.entry

			if entry and entry.refresh then
				entry.refresh(widget)
			end
		end,
	},
	better_inventory_lantern_section = {
		size_function = function(_, entry)
			return entry.size
		end,
		pass_template_function = function(_, entry)
			return entry.pass_template
		end,
		init = function(_, widget, entry)
			for key, value in pairs(entry.initial_content or {}) do
				widget.content[key] = type(value) == "table" and table.clone(value) or value
			end

			widget.content.entry = entry

			local view = entry.view

			if view then
				view._better_inventory_lantern_section_widget = widget
			end

			if entry.refresh then
				entry.refresh(widget)
			end
		end,
		update = function(_, widget)
			local entry = widget.content.entry

			if entry and entry.refresh then
				entry.refresh(widget)
			end
		end,
	},
}

local ARMOURY_NATIVE_SORT_BLUEPRINTS = {
	better_inventory_armoury_native_sort = {
		size_function = function(_, entry)
			return entry.size
		end,
		pass_template_function = function(_, entry)
			return entry.pass_template
		end,
		init = function(_, widget, entry)
			local content = widget.content

			for key, value in pairs(entry.initial_content or {}) do
				content[key] = value
			end

			content.entry = entry

			local view = entry.view

			if view then
				view._better_inventory_armoury_native_sort_widgets = view._better_inventory_armoury_native_sort_widgets or {}
				view._better_inventory_armoury_native_sort_widgets[entry.option_index] = widget
			end

			if entry.bind then
				entry.bind(widget)
			end

			if entry.refresh then
				entry.refresh(widget)
			end
		end,
		update = function(_, widget)
			local entry = widget.content.entry

			if entry and entry.refresh then
				entry.refresh(widget)
			end
		end,
	},
}

local function armoury_native_sort_entry(view, option, option_index)
	local selected_sort_index = view._selected_sort_option_index or 1

	return {
		initial_content = {
			hotspot = {},
			label = option.display_name or tostring(option_index),
			selected = selected_sort_index == option_index,
		},
		option_index = option_index,
		option = option,
		pass_template = armoury_native_sort_option_passes(ARMOURY_NATIVE_SORT_PANEL_WIDTH),
		size = {
			ARMOURY_NATIVE_SORT_PANEL_WIDTH,
			ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT,
		},
		view = view,
		widget_type = "better_inventory_armoury_native_sort",
		bind = function(widget)
			widget.content.hotspot.pressed_callback = function()
				local item_grid = view._item_grid

				if item_grid and type(item_grid.trigger_sort_index) == "function" then
					item_grid:trigger_sort_index(option_index)
				elseif type(view.cb_on_sort_button_pressed) == "function" then
					view:cb_on_sort_button_pressed(option)
				end
			end
		end,
		refresh = function(widget)
			widget.content.selected = (view._selected_sort_option_index or 1) == option_index
		end,
	}
end

local function armoury_native_sort_toggle_passes()
	local passes = inventory_sort_toggle_passes()
	local checkbox_style_ids = {
		checkbox_background = true,
		checkbox_frame = true,
		checkmark = true,
	}

	for index = 1, #passes do
		local pass = passes[index]

		if checkbox_style_ids[pass.style_id] then
			local style = pass.style or {}
			local offset = style.offset or {
				0,
				0,
				0,
			}

			offset[1] = (offset[1] or 0) + ARMOURY_NATIVE_SORT_CHECKBOX_LEFT_PADDING
			style.offset = offset
			pass.style = style
		end
	end

	return passes
end

local function armoury_native_sort_header_entry(mod, layout, view, section_id, label)
	return {
		initial_content = {
			chevron = view._better_inventory_armoury_native_sort_collapsed[section_id] and ">" or "v",
			hotspot = {},
			label = label,
		},
		option_index = "header_" .. section_id,
		pass_template = panel_section_header_passes(ARMOURY_NATIVE_SORT_PANEL_WIDTH),
		size = {
			ARMOURY_NATIVE_SORT_PANEL_WIDTH,
			40,
		},
		view = view,
		widget_type = "better_inventory_armoury_native_sort",
		bind = function(widget)
			widget.content.hotspot.pressed_callback = function()
				local collapsed = view._better_inventory_armoury_native_sort_collapsed

				collapsed[section_id] = not collapsed[section_id]
				view._better_inventory_armoury_native_sort_rebuild_pending = true
			end
		end,
		refresh = function(widget)
			widget.content.chevron = view._better_inventory_armoury_native_sort_collapsed[section_id] and ">" or "v"
		end,
	}
end

local function armoury_native_sort_priority_entry(mod, layout, view, setting_id, label)
	return {
		initial_content = {
			checked = setting_id == "prioritize_equipped_favorites" and mod:get(setting_id) ~= false or mod:get(setting_id) == true,
			hotspot = {},
			label = label,
		},
		option_index = "priority_" .. setting_id,
		pass_template = armoury_native_sort_toggle_passes(),
		size = {
			ARMOURY_NATIVE_SORT_PANEL_WIDTH,
			38,
		},
		view = view,
		widget_type = "better_inventory_armoury_native_sort",
		bind = function(widget)
			widget.content.hotspot.pressed_callback = function()
				mod:set(setting_id, not widget.content.checked, false)
				Features.sync_inventory_sort_setting(mod, layout)
			end
		end,
		refresh = function(widget)
			widget.content.checked = setting_id == "prioritize_equipped_favorites" and mod:get(setting_id) ~= false or mod:get(setting_id) == true
		end,
	}
end

local function panel_entry(view, control_id, height, pass_template, initial_content, bind, refresh, controller_targets)
	local geometry = view._better_inventory_options_panel_geometry

	if type(controller_targets) == "table" and #controller_targets > 0 then
		initial_content = initial_content or {}
		initial_content.hotspot = initial_content.hotspot or {}

		if #controller_targets == 1 then
			pass_template[#pass_template + 1] = {
				pass_type = "rect",
				style_id = "better_inventory_controller_focus",
				style = {
					color = Color.terminal_corner_selected(55, true),
					offset = {
						0,
						0,
						2,
					},
					size = {
						geometry.content_width,
						height,
					},
				},
				visibility_function = function(content)
					local hotspot = content.hotspot

					return hotspot and (hotspot.is_selected or hotspot.is_focused) or false
				end,
			}
		else
			-- The grid selects a full-row proxy hotspot so vertical navigation and
			-- scrolling continue to work. Multi-control rows must visualize only
			-- the embedded hotspot selected with left/right, not that proxy row.
			for target_index = 1, #controller_targets do
				local target_id = controller_targets[target_index]
				local target_style

				for pass_index = 1, #pass_template do
					local pass = pass_template[pass_index]

					if pass.content_id == target_id then
						target_style = pass.style
						break
					end
				end

				if target_style then
					local target_offset = table.clone(target_style.offset or { 0, 0, 0 })
					local focus_style = table.clone(target_style)

					target_offset[3] = math.max(2, (tonumber(target_offset[3]) or 0) - 3)
					focus_style.color = Color.terminal_corner_selected(75, true)
					focus_style.offset = target_offset
					focus_style.size = table.clone(target_style.size or { geometry.content_width, height })
					pass_template[#pass_template + 1] = {
						pass_type = "rect",
						style_id = "better_inventory_controller_focus_" .. tostring(target_index),
						style = focus_style,
						visibility_function = function(content)
							local hotspot = content[target_id]

							return hotspot and (hotspot.is_selected or hotspot.is_focused) or false
						end,
					}
				end
			end
		end
	end

	return {
		controller_targets = controller_targets,
		control_id = control_id,
		initial_content = initial_content,
		pass_template = pass_template,
		bind = bind,
		refresh = refresh,
		size = {
			geometry.content_width,
			height,
		},
		view = view,
		widget_type = "better_inventory_control",
	}
end

local function clone_lantern_value(value, seen, depth)
	if type(value) ~= "table" then
		return value
	end

	seen = seen or {}
	depth = depth or 0

	-- Initialized UI styles can contain engine-added parent/back references.
	-- table.clone follows those references until DMF hits its duplicate-depth
	-- guard. The hosted row needs only plain style/content data, so omit cycles
	-- and unexpectedly deep runtime branches instead of cloning widget internals.
	if seen[value] or depth >= 8 then
		return
	end

	seen[value] = true

	local copy = {}

	for key, child in pairs(value) do
		if type(key) ~= "table" then
			local cloned_child = clone_lantern_value(child, seen, depth + 1)

			if cloned_child ~= nil then
				copy[key] = cloned_child
			end
		end
	end

	seen[value] = nil

	return copy
end

local function lantern_proxy_definition(view)
	local state = view._lantern_weapon_panel
	local source_widget = state and state.widget
	local source_passes = source_widget and source_widget.passes
	local source_content = source_widget and source_widget.content
	local source_styles = source_widget and source_widget.style
	local geometry = view._better_inventory_options_panel_geometry
	local background_style = source_styles and source_styles.background
	local source_width = background_style and background_style.size and tonumber(background_style.size[1])

	if type(source_passes) ~= "table" or type(source_content) ~= "table" or type(source_styles) ~= "table" or not geometry or not source_width then
		return
	end

	local background_offset = background_style.offset or {}
	local base_z = tonumber(background_offset[3]) or 0
	local center_x = math.max(0, (geometry.content_width - source_width) * 0.5)
	local pass_template = {}
	local initial_content = {}
	local value_ids = {}

	for index = 1, #source_passes do
		local source_pass = source_passes[index]
		local style_id = source_pass and source_pass.style_id
		local source_style = style_id and source_styles[style_id]

		if source_pass and source_pass.pass_type and style_id and type(source_style) == "table" then
			local style = clone_lantern_value(source_style)
			local offset = style.offset or {
				0,
				0,
				base_z,
			}

			style.offset = offset
			offset[1] = (tonumber(offset[1]) or 0) + center_x
			offset[3] = (tonumber(offset[3]) or base_z) - base_z

			local pass = {
				pass_type = source_pass.pass_type,
				style_id = style_id,
				style = style,
			}
			local value_id = source_pass.value_id

			if value_id then
				local value = clone_lantern_value(source_content[value_id])

				pass.value_id = value_id
				pass.value = clone_lantern_value(value)
				initial_content[value_id] = value
				value_ids[#value_ids + 1] = value_id
			end

			local content_id = source_pass.content_id

			if content_id then
				pass.content_id = content_id
				pass.content = clone_lantern_value(source_content[content_id] or {})
				initial_content[content_id] = clone_lantern_value(source_content[content_id] or {})
			end

			pass_template[#pass_template + 1] = pass
		end
	end

	if #pass_template == 0 then
		return
	end

	return pass_template, initial_content, value_ids
end

local function panel_lantern_entry(view)
	local geometry = view._better_inventory_options_panel_geometry
	local height = math.max(120, tonumber(view._better_inventory_lantern_panel_height) or 120)
	local pass_template, initial_content, value_ids = lantern_proxy_definition(view)

	if not pass_template then
		return
	end

	return {
		control_id = "better_inventory_lantern_section",
		initial_content = initial_content,
		pass_template = pass_template,
		refresh = function(widget)
			local state = view._lantern_weapon_panel
			local source_content = state and state.widget and state.widget.content

			if not source_content then
				return
			end

			for index = 1, #value_ids do
				local value_id = value_ids[index]

				widget.content[value_id] = clone_lantern_value(source_content[value_id])
			end
		end,
		size = {
			geometry.content_width,
			height,
		},
		view = view,
		widget_type = "better_inventory_lantern_section",
	}
end

local function panel_header_entry(mod, layout, view, control_id, section_id, label_function)
	local geometry = view._better_inventory_options_panel_geometry

	return panel_entry(view, control_id, 40, panel_section_header_passes(geometry.content_width), {
		chevron = "v",
		label = label_function(),
	}, function(widget)
		widget.content.hotspot.pressed_callback = function()
			local collapsed = view._better_inventory_options_panel_collapsed

			collapsed[section_id] = not collapsed[section_id]
			-- Hotspot callbacks execute while ViewElementGrid is drawing. Rebuilding
			-- here clears the widget array underneath Darktide's active draw loop.
			-- The changed structure key is detected and rebuilt safely on the next
			-- InventoryWeaponsView update, before the following draw begins.
		end
	end, function(widget)
		local is_collapsed = view._better_inventory_options_panel_collapsed[section_id] == true

		widget.content.chevron = is_collapsed and ">" or "v"
	end, { "hotspot" })
end

local function panel_sort_entry(mod, layout, view)
	return panel_entry(view, INVENTORY_SORT_TOGGLE_ID, 38, inventory_sort_toggle_passes(), {
		checked = mod:get("prioritize_equipped_favorites") ~= false,
		label = mod:localize("prioritize_equipped_favorites_inventory_label"),
	}, function(widget)
		widget.content.hotspot.pressed_callback = function()
			mod:set("prioritize_equipped_favorites", not widget.content.checked, false)
			Features.sync_inventory_sort_setting(mod, layout)
		end
	end, function(widget)
		widget.content.checked = mod:get("prioritize_equipped_favorites") ~= false
	end, { "hotspot" })
end

local function panel_perfect_sort_entry(mod, layout, view)
	return panel_entry(view, INVENTORY_PERFECT_SORT_TOGGLE_ID, 38, inventory_sort_toggle_passes(), {
		checked = mod:get("prioritize_perfect_roll_weapons") == true,
		label = mod:localize("prioritize_perfect_roll_weapons_inventory_label"),
	}, function(widget)
		widget.content.hotspot.pressed_callback = function()
			mod:set("prioritize_perfect_roll_weapons", not widget.content.checked, false)
			Features.sync_inventory_sort_setting(mod, layout)
		end
	end, function(widget)
		widget.content.checked = mod:get("prioritize_perfect_roll_weapons") == true
	end, { "hotspot" })
end

local function panel_mode_entry(mod, layout, view)
	local geometry = view._better_inventory_options_panel_geometry

	return panel_entry(view, INVENTORY_DISCARD_MODE_ID, 34, compact_selector_passes(geometry.content_width, 110), {
		label = mod:localize("quick_discard_inventory_mode"),
		value = "",
	}, function(widget)
		widget.content.hotspot.pressed_callback = function()
			local mode = mod:get("quick_discard_mode") == "automatic" and "manual" or "automatic"

			mod:set("quick_discard_mode", mode, false)
			widget.content.value = mod:localize("quick_discard_mode_" .. mode) .. "  >"
			-- Automatic mode adds its confirmation row. Rebuilding this ViewElementGrid
			-- inside its own pressed callback can invalidate Darktide's active draw
			-- iteration, so this view rebuilds on the next normal update.
			Features.sync_quick_discard_settings(mod, layout, view)
		end
	end, function(widget)
		local mode = mod:get("quick_discard_mode") == "automatic" and "automatic" or "manual"

		if widget.content.better_inventory_mode ~= mode then
			widget.content.better_inventory_mode = mode
			widget.content.value = mod:localize("quick_discard_mode_" .. mode) .. "  >"
		end
	end, { "hotspot" })
end

local function panel_curio_buyer_target_mode_entry(mod, layout, view)
	local geometry = view._better_inventory_options_panel_geometry

	return panel_entry(view, INVENTORY_CURIO_BUYER_TARGET_MODE_ID, 34, compact_selector_passes(geometry.content_width, 120, true), {
		label = mod:localize("automatic_curio_target_mode_inventory_suffix"),
		value = "",
	}, function(widget)
		widget.content.hotspot.pressed_callback = function()
			local mode = mod:get("automatic_curio_target_mode") == "characters" and "classes" or "characters"

			mod:set("automatic_curio_target_mode", mode, false)

			if curio_acquisition_provider and type(curio_acquisition_provider.on_setting_changed) == "function" then
				curio_acquisition_provider.on_setting_changed(mod, "automatic_curio_target_mode")
			end

			if mode == "characters" and curio_acquisition_provider and type(curio_acquisition_provider.request_profile_discovery) == "function" then
				curio_acquisition_provider.request_profile_discovery()
			end

			Features.sync_curio_acquisition_settings(mod, layout, view)
		end
	end, function(widget)
		local mode = mod:get("automatic_curio_target_mode") == "characters" and "characters" or "classes"

		if widget.content.better_inventory_mode ~= mode then
			widget.content.better_inventory_mode = mode
			widget.content.value = mod:localize("automatic_curio_target_mode_" .. mode) .. "  >"
		end
	end, { "hotspot" })
end

local function panel_sub_label_entry(mod, view, control_id, label_id)
	local geometry = view._better_inventory_options_panel_geometry

	return panel_entry(view, control_id, 26, panel_sub_label_passes(geometry.content_width), {
		label = mod:localize(label_id),
	})
end

local function panel_quick_discard_entry(mod, layout, view)
	return panel_entry(view, INVENTORY_QUICK_DISCARD_ID, 40, quick_discard_passes(), {
		discard_label = mod:localize("quick_discard_inventory_action"),
		prefix = mod:localize("quick_discard_inventory_prefix"),
		rarity_label = "",
		suffix = mod:localize("quick_discard_inventory_suffix"),
		visible = true,
	}, function(widget)
		widget.content.rarity_hotspot.pressed_callback = function()
			local rarity = math.clamp(math.floor(tonumber(mod:get("quick_discard_rarity")) or 1), 1, 5)

			mod:set("quick_discard_rarity", rarity % 5 + 1, false)
			Features.sync_quick_discard_settings(mod, layout)
		end
		widget.content.discard_hotspot.pressed_callback = function()
			Features.request_quick_discard(mod, layout, view)
		end
	end, function(widget)
		local rarity = math.clamp(math.floor(tonumber(mod:get("quick_discard_rarity")) or 1), 1, 5)

		if widget.content.better_inventory_rarity ~= rarity then
			local rarity_settings = RaritySettings[rarity]
			local rarity_color = rarity_settings and rarity_settings.color or Color.terminal_text_body(255, true)

			widget.content.better_inventory_rarity = rarity
			widget.content.rarity_label = mod:localize("quick_discard_rarity_" .. rarity) .. "  >"

			if widget.style and widget.style.rarity_label then
				widget.style.rarity_label.text_color = table.clone(rarity_color)
			end
		end
	end, { "rarity_hotspot", "discard_hotspot" })
end

local function panel_stepper_entry(mod, layout, view, control_id, setting_id, label_id, default_value, sync_function, minimum, maximum, step, suffix)
	local geometry = view._better_inventory_options_panel_geometry
	minimum = tonumber(minimum) or 0
	maximum = tonumber(maximum) or 500
	step = tonumber(step) or 10
	suffix = suffix or ""

	local function current_value()
		return math.clamp(math.floor((tonumber(mod:get(setting_id)) or default_value) + 0.5), minimum, maximum)
	end

	return panel_entry(view, control_id, 34, compact_stepper_passes(geometry.content_width), {
		label = mod:localize(label_id),
		value = tostring(current_value()) .. suffix,
	}, function(widget)
		local function change_value(delta)
			local value = math.clamp(current_value() + delta, minimum, maximum)
			local sync = sync_function or Features.sync_quick_discard_settings

			mod:set(setting_id, value, false)
			sync(mod, layout)
		end

		widget.content.decrease_hotspot.pressed_callback = function()
			change_value(-step)
		end
		widget.content.increase_hotspot.pressed_callback = function()
			change_value(step)
		end
	end, function(widget)
		local value = current_value()

		if widget.content.better_inventory_value ~= value then
			widget.content.better_inventory_value = value
			widget.content.value = tostring(value) .. suffix
		end
	end, { "decrease_hotspot", "increase_hotspot" })
end

local function panel_checkbox_entry(mod, layout, view, control_id, setting_id, label_id, default_enabled, defer_panel_rebuild, sync_function)
	local function is_enabled()
		local value = mod:get(setting_id)

		if value == nil then
			return default_enabled ~= false
		end

		return value == true
	end

	return panel_entry(view, control_id, 34, compact_checkbox_passes(), {
		checked = is_enabled(),
		label = mod:localize(label_id),
	}, function(widget)
		widget.content.hotspot.pressed_callback = function()
			local enabled = not is_enabled()
			local sync = sync_function or Features.sync_quick_discard_settings

			widget.content.checked = enabled
			mod:set(setting_id, enabled, false)
			sync(mod, layout, defer_panel_rebuild and view or nil)
		end
	end, function(widget)
		widget.content.checked = is_enabled()
	end, { "hotspot" })
end

local function item_sorting_custom_option_start(view)
	local sort_options = view and view._sort_options or {}

	if not item_sorting_is_enabled() or type(item_sorting_mod.get) ~= "function" then
		return #sort_options + 1
	end

	local view_type = is_armoury_sort_view(view) and "store" or "inventory"
	local definition_group = item_sorting_definitions and item_sorting_definitions.customized_vanilla_methods
	local vanilla_definitions = definition_group and definition_group[view_type]

	if type(vanilla_definitions) == "table" then
		return math.min(#vanilla_definitions + 1, #sort_options + 1)
	end

	local setting_ids = view_type == "store" and ITEM_SORTING_STORE_VANILLA_SETTINGS or ITEM_SORTING_INVENTORY_VANILLA_SETTINGS
	local native_count = 0

	for index = 1, #setting_ids do
		local success, enabled = pcall(item_sorting_mod.get, item_sorting_mod, setting_ids[index])

		if success and enabled == true then
			native_count = native_count + 1
		end
	end

	return math.min(native_count + 1, #sort_options + 1)
end

local function item_sorting_options_signature(view)
	if not item_sorting_is_enabled() then
		return ""
	end

	local sort_options = view and view._sort_options or {}
	local parts = {
		tostring(item_sorting_custom_option_start(view)),
		tostring(#sort_options),
	}

	for index = 1, #sort_options do
		parts[#parts + 1] = tostring(sort_options[index].display_name or index)
	end

	return table.concat(parts, "|")
end

local function panel_item_sorting_option_entry(view, option, option_index)
	local geometry = view._better_inventory_options_panel_geometry

	return panel_entry(view, "better_inventory_item_sorting_option_" .. tostring(option_index), 32, armoury_native_sort_option_passes(geometry.content_width), {
		hotspot = {},
		label = option.display_name or tostring(option_index),
		selected = (view._selected_sort_option_index or 1) == option_index,
	}, function(widget)
		widget.content.hotspot.pressed_callback = function()
			local item_grid = view._item_grid

			if item_grid and type(item_grid.trigger_sort_index) == "function" then
				item_grid:trigger_sort_index(option_index)
			elseif type(view.cb_on_sort_button_pressed) == "function" then
				view:cb_on_sort_button_pressed(option)
			end
		end
	end, function(widget)
		widget.content.selected = (view._selected_sort_option_index or 1) == option_index
	end, { "hotspot" })
end

local function panel_type_entry(mod, layout, view)
	local geometry = view._better_inventory_options_panel_geometry
	local settings = {
		{
			content_id = "melee",
			label_id = "quick_discard_inventory_melee",
			setting_id = "quick_discard_include_melee",
		},
		{
			content_id = "ranged",
			label_id = "quick_discard_inventory_ranged",
			setting_id = "quick_discard_include_ranged",
		},
		{
			content_id = "curio",
			label_id = "quick_discard_inventory_curios",
			setting_id = "quick_discard_include_curios",
		},
	}
	local content = {}

	for index = 1, #settings do
		local config = settings[index]

		content[config.content_id .. "_checked"] = mod:get(config.setting_id) ~= false
		content[config.content_id .. "_label"] = mod:localize(config.label_id)
	end

	return panel_entry(view, "better_inventory_discard_types", 34, panel_type_checkbox_passes(geometry.content_width), content, function(widget)
		for index = 1, #settings do
			local config = settings[index]
			local hotspot = widget.content[config.content_id .. "_hotspot"]
			local checked_id = config.content_id .. "_checked"
			local setting_id = config.setting_id

			hotspot.pressed_callback = function()
				local enabled = not widget.content[checked_id]

				widget.content[checked_id] = enabled
				mod:set(setting_id, enabled, false)
				Features.sync_quick_discard_settings(mod, layout)
			end
		end
	end, function(widget)
		for index = 1, #settings do
			local config = settings[index]

			widget.content[config.content_id .. "_checked"] = mod:get(config.setting_id) ~= false
		end
	end, { "melee_hotspot", "ranged_hotspot", "curio_hotspot" })
end

local function panel_curio_protection_type_entry(mod, layout, view)
	local geometry = view._better_inventory_options_panel_geometry
	local settings = {
		{
			content_id = "health",
			label_id = "quick_discard_inventory_keep_health_curios",
			setting_id = "quick_discard_keep_health_curios",
		},
		{
			content_id = "toughness",
			label_id = "quick_discard_inventory_keep_toughness_curios",
			setting_id = "quick_discard_keep_toughness_curios",
		},
		{
			content_id = "wounds",
			label_id = "quick_discard_inventory_keep_wound_curios",
			setting_id = "quick_discard_keep_wound_curios",
		},
		{
			content_id = "stamina",
			label_id = "quick_discard_inventory_keep_stamina_curios",
			setting_id = "quick_discard_keep_stamina_curios",
		},
	}
	local content = {}
	local passes = {}
	local gap = 6
	local width = math.floor((geometry.content_width - gap * 3) / 4)

	for index = 1, #settings do
		local config = settings[index]
		local x = (width + gap) * (index - 1)

		content[config.content_id .. "_checked"] = mod:get(config.setting_id) ~= false
		content[config.content_id .. "_label"] = mod:localize(config.label_id)
		append_panel_checkbox_passes(passes, config.content_id, x, width, config.content_id .. "_checked", config.content_id .. "_label")
	end

	return panel_entry(view, "better_inventory_discard_curio_types", 34, passes, content, function(widget)
		for index = 1, #settings do
			local config = settings[index]
			local hotspot = widget.content[config.content_id .. "_hotspot"]
			local checked_id = config.content_id .. "_checked"

			hotspot.pressed_callback = function()
				local enabled = not widget.content[checked_id]

				widget.content[checked_id] = enabled
				mod:set(config.setting_id, enabled, false)
				Features.sync_quick_discard_settings(mod, layout)
			end
		end
	end, function(widget)
		for index = 1, #settings do
			local config = settings[index]

			widget.content[config.content_id .. "_checked"] = mod:get(config.setting_id) ~= false
		end
	end, { "health_hotspot", "toughness_hotspot", "wounds_hotspot", "stamina_hotspot" })
end

local function panel_checkbox_group_entry(mod, layout, view, control_id, settings)
	local geometry = view._better_inventory_options_panel_geometry
	local content = {}
	local passes = {}
	local controller_targets = {}
	local gap = 6
	local width = math.floor((geometry.content_width - gap * math.max(#settings - 1, 0)) / math.max(#settings, 1))

	local function is_enabled(config)
		local value = mod:get(config.setting_id)

		if value == nil then
			return config.default_enabled ~= false
		end

		return value == true
	end

	for index = 1, #settings do
		local config = settings[index]
		local x = (width + gap) * (index - 1)

		content[config.content_id .. "_checked"] = is_enabled(config)
		content[config.content_id .. "_label"] = mod:localize(config.label_id)
		controller_targets[#controller_targets + 1] = config.content_id .. "_hotspot"
		append_panel_checkbox_passes(passes, config.content_id, x, width, config.content_id .. "_checked", config.content_id .. "_label")
	end

	return panel_entry(view, control_id, 34, passes, content, function(widget)
		for index = 1, #settings do
			local config = settings[index]
			local hotspot = widget.content[config.content_id .. "_hotspot"]
			local checked_id = config.content_id .. "_checked"

			hotspot.pressed_callback = function()
				local value = not widget.content[checked_id]

				widget.content[checked_id] = value
				mod:set(config.setting_id, value, false)
				Features.sync_curio_acquisition_settings(mod, layout, view)
			end
		end
	end, function(widget)
		for index = 1, #settings do
			local config = settings[index]

			widget.content[config.content_id .. "_checked"] = is_enabled(config)
		end
	end, controller_targets)
end

local function panel_curio_buyer_type_entry(mod, layout, view)
	return panel_checkbox_group_entry(mod, layout, view, "better_inventory_curio_buyer_types", {
		{
			content_id = "health",
			default_enabled = true,
			label_id = "automatic_curio_buy_health",
			setting_id = "automatic_curio_buy_health",
		},
		{
			content_id = "toughness",
			default_enabled = true,
			label_id = "automatic_curio_buy_toughness",
			setting_id = "automatic_curio_buy_toughness",
		},
		{
			content_id = "stamina",
			default_enabled = false,
			label_id = "automatic_curio_buy_stamina",
			setting_id = "automatic_curio_buy_stamina",
		},
		{
			content_id = "wounds",
			default_enabled = false,
			label_id = "automatic_curio_buy_wounds",
			setting_id = "automatic_curio_buy_wounds",
		},
	})
end

local function panel_curio_buyer_class_entry(mod, layout, view, row)
	local settings = row == 1 and {
		{
			content_id = "veteran",
			label_id = "automatic_curio_class_veteran",
			setting_id = "automatic_curio_class_veteran",
		},
		{
			content_id = "zealot",
			label_id = "automatic_curio_class_zealot",
			setting_id = "automatic_curio_class_zealot",
		},
		{
			content_id = "psyker",
			label_id = "automatic_curio_class_psyker",
			setting_id = "automatic_curio_class_psyker",
		},
		{
			content_id = "ogryn",
			label_id = "automatic_curio_class_ogryn",
			setting_id = "automatic_curio_class_ogryn",
		},
	} or {
		{
			content_id = "adamant",
			label_id = "automatic_curio_class_adamant",
			setting_id = "automatic_curio_class_adamant",
		},
		{
			content_id = "broker",
			label_id = "automatic_curio_class_broker",
			setting_id = "automatic_curio_class_broker",
		},
		{
			content_id = "cryptic",
			label_id = "automatic_curio_class_cryptic",
			setting_id = "automatic_curio_class_cryptic",
		},
	}

	return panel_checkbox_group_entry(mod, layout, view, "better_inventory_curio_buyer_classes_" .. row, settings)
end

local function character_profile_label(profile, profiles)
	local label = profile.character_name and string.format("%s(%s)", profile.character_name, profile.class_name) or profile.class_name
	local duplicate_count = 0

	for index = 1, #profiles do
		local other = profiles[index]
		local other_label = other.character_name and string.format("%s(%s)", other.character_name, other.class_name) or other.class_name

		if other_label == label then
			duplicate_count = duplicate_count + 1
		end
	end

	return duplicate_count > 1 and string.format("%s [%s]", label, string.sub(tostring(profile.character_id), -6)) or label
end

local function panel_curio_buyer_character_entry(mod, layout, view, profiles, first_index)
	local geometry = view._better_inventory_options_panel_geometry
	local content = {}
	local passes = {}
	local settings = {}
	local controller_targets = {}
	local last_index = math.min(first_index + 1, #profiles)
	local gap = 6
	local width = math.floor((geometry.content_width - gap * (last_index - first_index)) / (last_index - first_index + 1))

	for profile_index = first_index, last_index do
		local profile = profiles[profile_index]
		local content_id = "character_" .. tostring(profile_index - first_index + 1)
		local x = (width + gap) * (profile_index - first_index)

		settings[#settings + 1] = {
			character_id = profile.character_id,
			content_id = content_id,
		}
		content[content_id .. "_checked"] = curio_acquisition_provider.character_is_enabled(mod, profile.character_id)
		content[content_id .. "_label"] = character_profile_label(profile, profiles)
		controller_targets[#controller_targets + 1] = content_id .. "_hotspot"
		append_panel_checkbox_passes(passes, content_id, x, width, content_id .. "_checked", content_id .. "_label")
	end

	return panel_entry(view, "better_inventory_curio_buyer_characters_" .. tostring(first_index), 34, passes, content, function(widget)
		for index = 1, #settings do
			local config = settings[index]
			local checked_id = config.content_id .. "_checked"

			widget.content[config.content_id .. "_hotspot"].pressed_callback = function()
				local enabled = not curio_acquisition_provider.character_is_enabled(mod, config.character_id)

				widget.content[checked_id] = enabled
				curio_acquisition_provider.set_character_enabled(mod, config.character_id, enabled)
				Features.sync_curio_acquisition_settings(mod, layout, view)
			end
		end
	end, function(widget)
		for index = 1, #settings do
			local config = settings[index]

			widget.content[config.content_id .. "_checked"] = curio_acquisition_provider.character_is_enabled(mod, config.character_id)
		end
	end, controller_targets)
end

local function panel_structure_key(mod, view)
	local collapsed = view._better_inventory_options_panel_collapsed or {}
	local key = 0

	key = key + (view._discard_items_element and 1 or 0)
	key = key + (mod:get("enable_experimental_quick_discard") == true and 2 or 0)
	key = key + (mod:get("quick_discard_mode") == "automatic" and 4 or 0)
	key = key + (mod:get("quick_discard_protect_high_level_curios") ~= false and 8 or 0)
	key = key + (collapsed.sorting and 16 or 0)
	key = key + (collapsed.discard and 32 or 0)
	key = key + (mod:get("enable_automatic_curio_acquisition") == true and 64 or 0)
	key = key + (collapsed.curio_buyer and 128 or 0)
	key = key + (mod:get("automatic_curio_buy_health") ~= false and 256 or 0)
	key = key + (mod:get("automatic_curio_buy_toughness") ~= false and 512 or 0)
	key = key + (mod:get("automatic_curio_target_mode") == "characters" and 1024 or 0)
	key = key + curio_buyer_profile_revision() * 2048
	key = key + (item_sorting_is_enabled() and 4194304 or 0)
	key = key + (collapsed.item_sorting and 8388608 or 0)
	key = key + (collapsed.native_sorting and 16777216 or 0)

	return tostring(key) .. ":" .. tostring(view._better_inventory_lantern_panel_signature or "") .. ":" .. item_sorting_options_signature(view)
end

local function lantern_is_enabled()
	if not lantern_mod then
		return false
	end

	if type(lantern_mod.is_enabled) ~= "function" then
		return true
	end

	local success, enabled = pcall(lantern_mod.is_enabled, lantern_mod)

	return success and enabled == true
end

local function lantern_recommendations_enabled()
	if not lantern_is_enabled() or type(lantern_mod.get) ~= "function" then
		return false
	end

	local success, enabled = pcall(lantern_mod.get, lantern_mod, "show_recommendations")

	return success and enabled == true
end

Features.lantern_recommendations_active = lantern_recommendations_enabled

local function lantern_weapon_signature(view)
	local slot = view and view._selected_slot

	if not slot or not slot.name or type(ProfileUtils.get_active_profile_preset_id) ~= "function" then
		return
	end

	local success, active_id = pcall(ProfileUtils.get_active_profile_preset_id)

	if not success then
		return
	end

	return tostring(active_id) .. "|" .. tostring(slot.name)
end

local function lantern_preview_is_active(view)
	if not view or type(view.is_previewing_item) ~= "function" then
		return false
	end

	local success, is_previewing = pcall(view.is_previewing_item, view)

	return success and is_previewing == true
end

local function restore_lantern_weapon_panel(view)
	if view then
		view._better_inventory_lantern_panel_available = false
		view._better_inventory_lantern_panel_height = nil
		view._better_inventory_lantern_panel_signature = nil
		view._better_inventory_lantern_panel_hosted = false
	end
end

Features.should_host_lantern_panel = function(view)
	return view and view._better_inventory_lantern_panel_hosted == true
end

Features.set_lantern_integration = function(_, integration_mod)
	lantern_mod = type(integration_mod) == "table" and integration_mod or nil
	lantern_overlay = lantern_mod and lantern_mod._modules and lantern_mod._modules.equipment_overlay or nil

	if not lantern_overlay or type(lantern_overlay.draw_weapon_select) ~= "function" then
		return false
	end

	if type(lantern_overlay._better_inventory_original_draw_weapon_select) ~= "function" then
		lantern_overlay._better_inventory_original_draw_weapon_select = lantern_overlay.draw_weapon_select
		lantern_overlay.draw_weapon_select = function(view, ...)
			local should_host = lantern_overlay._better_inventory_should_host_panel

			if type(should_host) == "function" and should_host(view) then
				return
			end

			return lantern_overlay._better_inventory_original_draw_weapon_select(view, ...)
		end
	end

	lantern_overlay._better_inventory_should_host_panel = Features.should_host_lantern_panel

	return true
end

Features.set_item_sorting_integration = function(integration_mod)
	item_sorting_mod = type(integration_mod) == "table" and integration_mod or nil
	item_sorting_definitions = nil

	if item_sorting_mod and type(item_sorting_mod.io_dofile) == "function" then
		local success, definitions = pcall(item_sorting_mod.io_dofile, item_sorting_mod, "ItemSorting/scripts/mods/ItemSorting/ItemSorting_definitions")

		if success and type(definitions) == "table" then
			item_sorting_definitions = definitions
		end
	end

	return item_sorting_is_enabled()
end

Features.preserve_item_sorting_native_options = function(view, selected_display_name)
	if not item_sorting_is_enabled() or type(item_sorting_definitions) ~= "table" or not view then
		return false
	end

	local view_type = is_armoury_sort_view(view) and "store" or view.__class_name == "InventoryWeaponsView" and "inventory" or nil
	local vanilla_group = item_sorting_definitions.customized_vanilla_methods
	local custom_group = item_sorting_definitions.modded_methods
	local vanilla_definitions = view_type and vanilla_group and vanilla_group[view_type]
	local custom_definitions = view_type and custom_group and custom_group[view_type]

	if type(vanilla_definitions) ~= "table" or type(custom_definitions) ~= "table" then
		return false
	end

	local options = {}
	local function append_option(definition)
		if type(definition) == "table" and type(definition.sort_function) == "function" then
			options[#options + 1] = {
				display_name = definition.display_name,
				sort_function = definition.sort_function,
			}
		end
	end

	for index = 1, #vanilla_definitions do
		append_option(vanilla_definitions[index])
	end

	for index = 1, #custom_definitions do
		append_option(custom_definitions[index])
	end

	view._sort_options = options
	local selected_index = 1

	if selected_display_name ~= nil then
		for index = 1, #options do
			if options[index].display_name == selected_display_name then
				selected_index = index
				break
			end
		end
	end

	view._selected_sort_option_index = selected_index
	view._selected_sort_option = options[selected_index]

	local item_grid = view._item_grid

	if item_grid and type(item_grid.setup_sort_button) == "function" and type(view.cb_on_sort_button_pressed) == "function" then
		item_grid:setup_sort_button(options, function(...)
			return view:cb_on_sort_button_pressed(...)
		end)
	end

	return true
end

Features.release_lantern_inventory_section = function(view)
	restore_lantern_weapon_panel(view)
end

Features.update_lantern_inventory_section = function(mod, view)
	local selected_slot_name = view and view._selected_slot and view._selected_slot.name
	local separate_curio_panel = mod:get("keep_lantern_curio_panel_separate") ~= false and type(selected_slot_name) == "string" and string.match(selected_slot_name, "^slot_attachment_") ~= nil
	local blocked_by_native_view_state = view and (view._discard_items_element ~= nil or view._item_compare_toggled == true)

	if not lantern_mod or not lantern_overlay or separate_curio_panel or blocked_by_native_view_state or mod:get("enable_lantern_inventory_section") ~= true or mod:get("enable_inventory_options_panel_prototype") ~= true or mod:get("show_inventory_options_widget") == false or not view or not view._better_inventory_options_panel or view._better_inventory_options_panel_visible ~= true or view._better_inventory_options_panel._visible == false or view._filter_panel_element and view._show_filter_panel == true or not lantern_recommendations_enabled() or not lantern_preview_is_active(view) then
		restore_lantern_weapon_panel(view)

		return false
	end

	local state = view._lantern_weapon_panel
	local widget = state and state.widget
	local expected_signature = lantern_weapon_signature(view)
	local background_style = widget and widget.style and widget.style.background
	local panel_height = background_style and tonumber(background_style.size and background_style.size[2])

	if not state or not widget or not state.entry or not expected_signature or state.sig ~= expected_signature or not panel_height or panel_height <= 0 then
		restore_lantern_weapon_panel(view)

		return false
	end

	view._better_inventory_lantern_panel_available = true
	view._better_inventory_lantern_panel_height = math.max(120, panel_height)
	view._better_inventory_lantern_panel_signature = tostring(state.sig) .. "|" .. tostring(view._better_inventory_lantern_panel_height)
	view._better_inventory_lantern_panel_hosted = view._better_inventory_lantern_section_widget ~= nil

	return view._better_inventory_lantern_panel_hosted
end

rebuild_inventory_options_panel = function(mod, layout, view)
	local panel = view._better_inventory_options_panel

	if not panel or view._destroyed then
		return
	end

	local collapsed = view._better_inventory_options_panel_collapsed
	local native_discard_active = view._discard_items_element ~= nil
	local quick_discard_enabled = mod:get("enable_experimental_quick_discard") == true
	local entries = {}

	if view._better_inventory_lantern_panel_available == true then
		local lantern_entry = panel_lantern_entry(view)

		if lantern_entry then
			entries[#entries + 1] = lantern_entry
		end
	end

	entries[#entries + 1] = panel_header_entry(mod, layout, view, "better_inventory_sort_header", "sorting", function()
			return mod:localize("inventory_sorting_inventory_label")
		end)

	if not collapsed.sorting then
		entries[#entries + 1] = panel_sort_entry(mod, layout, view)
		entries[#entries + 1] = panel_perfect_sort_entry(mod, layout, view)
	end

	if item_sorting_is_enabled() then
		entries[#entries + 1] = panel_header_entry(mod, layout, view, "better_inventory_item_sorting_header", "item_sorting", function()
			return mod:localize("item_sorting_mod_header")
		end)

		if not collapsed.item_sorting then
			local sort_options = view._sort_options or {}
			local first_custom_option = item_sorting_custom_option_start(view)

			for option_index = first_custom_option, #sort_options do
				entries[#entries + 1] = panel_item_sorting_option_entry(view, sort_options[option_index], option_index)
			end
		end
	end

	if native_discard_active then
		local sort_options = view._sort_options or {}
		local last_native_option = item_sorting_custom_option_start(view) - 1

		if last_native_option > 0 then
			entries[#entries + 1] = panel_header_entry(mod, layout, view, "better_inventory_native_sorting_header", "native_sorting", function()
				return mod:localize("armoury_native_sorting_header")
			end)

			if not collapsed.native_sorting then
				for option_index = 1, math.min(last_native_option, #sort_options) do
					entries[#entries + 1] = panel_item_sorting_option_entry(view, sort_options[option_index], option_index)
				end
			end
		end
	end

	if quick_discard_enabled and not native_discard_active then
		entries[#entries + 1] = panel_header_entry(mod, layout, view, "better_inventory_discard_header", "discard", function()
			local mode = mod:get("quick_discard_mode") == "automatic" and "automated" or "manual"

			return mod:localize("inventory_" .. mode .. "_discard_management_inventory_label")
		end)

		if not collapsed.discard then
			entries[#entries + 1] = panel_mode_entry(mod, layout, view)

			if mod:get("quick_discard_mode") == "automatic" then
				entries[#entries + 1] = panel_checkbox_entry(mod, layout, view, INVENTORY_DISCARD_SKIP_CONFIRMATION_ID, "quick_discard_skip_automatic_confirmation", "quick_discard_skip_automatic_confirmation", false)
			end

			entries[#entries + 1] = panel_quick_discard_entry(mod, layout, view)
			entries[#entries + 1] = panel_sub_label_entry(mod, view, "better_inventory_discard_item_types_label", "quick_discard_inventory_item_types_label")
			entries[#entries + 1] = panel_type_entry(mod, layout, view)
			entries[#entries + 1] = panel_stepper_entry(mod, layout, view, INVENTORY_DISCARD_MAX_LEVEL_ID, "quick_discard_max_item_level", "quick_discard_inventory_max_level", 490)
			entries[#entries + 1] = panel_checkbox_entry(mod, layout, view, INVENTORY_DISCARD_EQUIPPED_LEVEL_PROTECTION_ID, "quick_discard_protect_above_equipped_level", "quick_discard_inventory_protect_above_equipped_level")
			entries[#entries + 1] = panel_checkbox_entry(mod, layout, view, INVENTORY_DISCARD_PROTECTION_ID, "quick_discard_protect_perfect_weapons", "quick_discard_inventory_protect_weapons")
			entries[#entries + 1] = panel_checkbox_entry(mod, layout, view, INVENTORY_DISCARD_CURIO_PROTECTION_ID, "quick_discard_protect_high_level_curios", "quick_discard_inventory_protect_curios", nil, true)

			if mod:get("quick_discard_protect_high_level_curios") ~= false then
				entries[#entries + 1] = panel_stepper_entry(mod, layout, view, INVENTORY_DISCARD_CURIO_LEVEL_ID, "quick_discard_curio_protection_level", "quick_discard_inventory_curio_level", 410)
			end

			entries[#entries + 1] = panel_sub_label_entry(mod, view, "better_inventory_discard_curio_types_label", "quick_discard_inventory_keep_curio_types_label")
			entries[#entries + 1] = panel_curio_protection_type_entry(mod, layout, view)
		end
	end

	if not native_discard_active then
		entries[#entries + 1] = panel_header_entry(mod, layout, view, "better_inventory_curio_buyer_header", "curio_buyer", function()
			return mod:localize("automatic_curio_buyer_inventory_label")
		end)

		if not collapsed.curio_buyer then
			entries[#entries + 1] = panel_checkbox_entry(mod, layout, view, INVENTORY_CURIO_BUYER_ENABLE_ID, "enable_automatic_curio_acquisition", "enable_automatic_curio_acquisition", false, true, Features.sync_curio_acquisition_settings)

			if mod:get("enable_automatic_curio_acquisition") == true then
				entries[#entries + 1] = panel_stepper_entry(mod, layout, view, INVENTORY_CURIO_BUYER_MIN_LEVEL_ID, "automatic_curio_min_item_level", "automatic_curio_min_item_level", 410, Features.sync_curio_acquisition_settings)
				entries[#entries + 1] = panel_sub_label_entry(mod, view, "better_inventory_curio_buyer_types_label", "automatic_curio_types_inventory_label")
				entries[#entries + 1] = panel_curio_buyer_type_entry(mod, layout, view)

				if mod:get("automatic_curio_buy_health") ~= false then
					entries[#entries + 1] = panel_stepper_entry(mod, layout, view, INVENTORY_CURIO_BUYER_MIN_HEALTH_ID, "automatic_curio_min_health", "automatic_curio_min_health", 21, Features.sync_curio_acquisition_settings, 0, 21, 1, "%")
				end

				if mod:get("automatic_curio_buy_toughness") ~= false then
					entries[#entries + 1] = panel_stepper_entry(mod, layout, view, INVENTORY_CURIO_BUYER_MIN_TOUGHNESS_ID, "automatic_curio_min_toughness", "automatic_curio_min_toughness", 17, Features.sync_curio_acquisition_settings, 0, 17, 1, "%")
				end

				entries[#entries + 1] = panel_curio_buyer_target_mode_entry(mod, layout, view)

				if mod:get("automatic_curio_target_mode") == "characters" then
					local profiles = known_curio_buyer_profiles(mod)

					if #profiles == 0 then
						entries[#entries + 1] = panel_sub_label_entry(mod, view, "better_inventory_curio_buyer_characters_discovering", "automatic_curio_characters_discovering_inventory")
					else
						for first_index = 1, #profiles, 2 do
							entries[#entries + 1] = panel_curio_buyer_character_entry(mod, layout, view, profiles, first_index)
						end
					end
				else
					entries[#entries + 1] = panel_curio_buyer_class_entry(mod, layout, view, 1)
					entries[#entries + 1] = panel_curio_buyer_class_entry(mod, layout, view, 2)
				end
			end
		end
	end

	local geometry = view._better_inventory_options_panel_geometry
	local spacing = geometry.row_spacing
	local content_height = 0

	for index = 1, #entries do
		content_height = content_height + entries[index].size[2]
	end

	content_height = content_height + math.max(#entries - 1, 0) * spacing

	-- ViewElementGrid adds a 31 px terminal-divider/frame overhead around the
	-- content. Account for it explicitly so user padding maps predictably.
	local panel_height = math.clamp(content_height + 31 + geometry.top + geometry.bottom, INVENTORY_OPTIONS_PANEL_MIN_HEIGHT, geometry.max_height)

	view._better_inventory_options_panel_widgets = {}
	view._better_inventory_lantern_section_widget = nil
	view._better_inventory_lantern_panel_hosted = false
	view._better_inventory_options_panel_structure_key = panel_structure_key(mod, view)
	view._better_inventory_options_panel_height = panel_height
	panel:update_grid_height(panel_height, panel_height)
	panel:present_grid_layout(entries, INVENTORY_OPTIONS_PANEL_BLUEPRINTS)
end

-- The stock Curio header reserves 250 virtual pixels for one small item image.
-- Scale the whole preview box rather than shortening only its height; changing
-- one axis was the reason Curio art appeared stretched in the prototype.
-- This transforms only the current InventoryWeaponsView's Curio stats blueprint;
-- crafting, vendors and weapon detail cards keep their native geometry.
Features.compact_inventory_curio_stats_blueprints = function(mod, item_grid, content_blueprints)
	if mod:get("enable_inventory_options_panel_prototype") ~= true or type(content_blueprints) ~= "table" then
		return content_blueprints
	end

	local parent = item_grid and item_grid._parent
	local item = item_grid and item_grid._item
	local gadget_header = content_blueprints.gadget_header

	if not parent or parent.__class_name ~= "InventoryWeaponsView" or parent._weapon_stats ~= item_grid or not item or item.item_type ~= "GADGET" or type(gadget_header) ~= "table" or type(gadget_header.size) ~= "table" or type(gadget_header.size[1]) ~= "number" or type(gadget_header.size[2]) ~= "number" then
		return content_blueprints
	end

	local adjusted_blueprints = shallow_copy(content_blueprints)
	local adjusted_header = table.clone(gadget_header)

	adjusted_blueprints.gadget_header = adjusted_header
	local height_percent = numeric_setting(mod, "curio_preview_height_percent", 76, 60, 100)
	local scale = height_percent / 100

	adjusted_header.size[2] = math.floor(INVENTORY_CURIO_NATIVE_HEADER_HEIGHT * scale + 0.5)

	for index = 1, #(adjusted_header.pass_template or {}) do
		local pass = adjusted_header.pass_template[index]
		local style = pass and pass.style

		if style and pass.style_id == "icon" and type(style.size) == "table" and type(style.offset) == "table" then
			local native_icon_width = INVENTORY_CURIO_NATIVE_GRID_WIDTH * 0.9
			local available_icon_width = (adjusted_header.size[1] or INVENTORY_CURIO_NATIVE_GRID_WIDTH) * 0.9
			local icon_scale = math.min(scale, available_icon_width / native_icon_width)

			style.size[1] = math.floor(native_icon_width * icon_scale + 0.5)
			style.size[2] = math.floor(INVENTORY_CURIO_NATIVE_ICON_HEIGHT * icon_scale + 0.5)
			style.offset[2] = math.floor((style.offset[2] or 0) * scale + 0.5)
		elseif style and pass.style_id == "loading" and type(style.size) == "table" then
			style.size[1] = math.floor((style.size[1] or 0) * scale + 0.5)
			style.size[2] = math.floor((style.size[2] or 0) * scale + 0.5)
		elseif style and pass.style_id == "gradient_background" and type(style.size) == "table" then
			style.size[2] = math.floor((style.size[2] or 0) * scale + 0.5)
		end
	end

	return adjusted_blueprints
end

Features.setup_inventory_options_panel = function(mod, layout, view, ViewElementGrid)
	if mod:get("enable_inventory_options_panel_prototype") ~= true or not is_inventory_view(layout, view) or view._better_inventory_options_panel then
		return false
	end

	if type(ViewElementGrid) ~= "table" or type(view._add_element) ~= "function" then
		return false
	end

	local geometry = inventory_options_panel_geometry(mod)
	local menu_settings = {
		bottom_chin = geometry.bottom,
		edge_padding = geometry.left + geometry.right,
		enable_gamepad_scrolling = true,
		grid_size = {
			geometry.content_width,
			geometry.max_height,
		},
		grid_spacing = {
			0,
			geometry.row_spacing,
		},
		ignore_blur = true,
		mask_size = {
			geometry.width,
			geometry.max_height,
		},
		reset_selection_on_navigation_change = false,
		scrollbar_width = 7,
		title_height = 0,
		top_padding = geometry.top,
		use_is_focused_for_navigation = false,
		use_select_on_focused = true,
		use_terminal_background = true,
	}
	local success, panel = pcall(view._add_element, view, ViewElementGrid, INVENTORY_OPTIONS_PANEL_REFERENCE, 25, menu_settings)

	if not success or not panel then
		if type(mod.error) == "function" then
			mod:error("BetterInventory options-panel prototype could not initialize: " .. tostring(panel))
		end

		if type(view._remove_element) == "function" then
			pcall(view._remove_element, view, INVENTORY_OPTIONS_PANEL_REFERENCE)
		end

		return false
	end

	view._better_inventory_options_panel = panel
	view._better_inventory_options_panel_geometry = geometry
	view._better_inventory_options_panel_mod = mod
	view._better_inventory_options_panel_collapsed = {
		curio_buyer = false,
		discard = false,
		item_sorting = false,
		native_sorting = false,
		sorting = false,
	}

	local configured, configure_error = pcall(function()
		local content_pivot = panel._ui_scenegraph and panel._ui_scenegraph.grid_content_pivot

		if content_pivot and content_pivot.position then
			content_pivot.position[1] = geometry.left
		end

		panel:disable_input(false)
		panel:set_visibility(true)
		view._better_inventory_options_panel_visible = true
		rebuild_inventory_options_panel(mod, layout, view)
	end)

	if not configured then
		view._better_inventory_options_panel = nil
		view._better_inventory_options_panel_geometry = nil
		view._better_inventory_options_panel_mod = nil
		view._better_inventory_options_panel_widgets = nil
		view._better_inventory_options_panel_collapsed = nil
		view._better_inventory_options_panel_visible = nil

		if type(view._remove_element) == "function" then
			pcall(view._remove_element, view, INVENTORY_OPTIONS_PANEL_REFERENCE)
		end

		if type(mod.error) == "function" then
			mod:error("BetterInventory options-panel prototype could not be configured: " .. tostring(configure_error))
		end

		return false
	end

	return true
end

local function controller_element_state(element)
	if not element then
		return
	end

	local state = {}

	if type(element.input_disabled) == "function" then
		state.input_disabled = element:input_disabled()
	end

	if type(element.selected_grid_index) == "function" then
		state.selected_index = element:selected_grid_index()
	end

	return state
end

local function clear_controller_element_selection(element)
	if element and type(element.select_grid_index) == "function" then
		element:select_grid_index()
	end
end

local function restore_controller_element(element, state)
	if not element or not state then
		return
	end

	if type(element.disable_input) == "function" and state.input_disabled ~= nil then
		element:disable_input(state.input_disabled)
	end

	if type(element.select_grid_index) == "function" then
		element:select_grid_index(state.selected_index)
	end
end

local function set_inventory_options_panel_controller_focus(view, focused)
	local panel = view and view._better_inventory_options_panel
	local item_grid = view and view._item_grid

	if not panel or not item_grid then
		return false
	end

	if focused then
		if view._better_inventory_options_panel_controller_focused == true then
			return true
		end

		view._better_inventory_options_panel_controller_restore = {
			discard = controller_element_state(view._discard_items_element),
			item_grid = controller_element_state(item_grid),
			weapon_options = controller_element_state(view._weapon_options_element),
		}
		view._better_inventory_options_panel_controller_focused = true

		for _, element in pairs({ item_grid, view._weapon_options_element, view._discard_items_element }) do
			if element then
				if type(element.disable_input) == "function" then
					element:disable_input(true)
				end

				clear_controller_element_selection(element)
			end
		end

		if type(panel.disable_input) == "function" then
			panel:disable_input(false)
		end

		if type(panel.select_first_index) == "function" then
			panel:select_first_index()
		end

		return true
	end

	local restore = view._better_inventory_options_panel_controller_restore or {}

	view._better_inventory_options_panel_controller_focused = false
	view._better_inventory_options_panel_controller_restore = nil
	view._better_inventory_options_panel_controller_target = nil
	clear_controller_element_selection(panel)
	restore_controller_element(item_grid, restore.item_grid)
	restore_controller_element(view._weapon_options_element, restore.weapon_options)
	restore_controller_element(view._discard_items_element, restore.discard)

	return false
end

Features.capture_inventory_options_panel_controller_focus = function(mod, layout, view, input_service)
	if not view or not is_inventory_view(layout, view) then
		return false
	end

	local focused = view._better_inventory_options_panel_controller_focused == true
	local panel_available = mod:get("enable_inventory_options_panel_prototype") == true and mod:get("show_inventory_options_widget") ~= false and view._better_inventory_options_panel_visible == true and view._better_inventory_options_panel and view._better_inventory_options_panel._visible ~= false

	if view._using_cursor_navigation ~= false or not panel_available then
		if focused then
			set_inventory_options_panel_controller_focus(view, false)
		end

		return false
	end

	local focus_action = mod:get("inventory_options_controller_focus_keybind")

	if focus_action and focus_action ~= "off" and input_service and type(input_service.get) == "function" and input_service:get(focus_action) then
		focused = set_inventory_options_panel_controller_focus(view, not focused)
	end

	if focused then
		-- Native inventory code may revisit its own focus state after previews or
		-- discard-mode changes. Keep the custom panel as the sole controller owner.
		for _, element in pairs({ view._item_grid, view._weapon_options_element, view._discard_items_element }) do
			if element and type(element.disable_input) == "function" then
				element:disable_input(true)
			end
		end

		local panel = view._better_inventory_options_panel

		if panel and type(panel.selected_grid_index) == "function" and not panel:selected_grid_index() and type(panel.select_first_index) == "function" then
			panel:select_first_index()
		end
	end

	return focused
end

Features.update_inventory_options_panel_controller_selection = function(view, input_service)
	if not view or view._better_inventory_options_panel_controller_focused ~= true then
		return false
	end

	local panel = view._better_inventory_options_panel
	local selected_widget = panel and type(panel.selected_grid_widget) == "function" and panel:selected_grid_widget()
	local entry = selected_widget and selected_widget.content and selected_widget.content.entry
	local targets = entry and entry.controller_targets

	for _, widget in pairs(view._better_inventory_options_panel_widgets or {}) do
		local widget_entry = widget.content and widget.content.entry

		for _, target_id in ipairs(widget_entry and widget_entry.controller_targets or {}) do
			local hotspot = widget.content[target_id]

			if hotspot and target_id ~= "hotspot" then
				hotspot.is_focused = false
				hotspot.is_selected = false
			end
		end
	end

	if type(targets) ~= "table" or #targets == 0 then
		return false
	end

	local target_state = view._better_inventory_options_panel_controller_target

	if not target_state or target_state.control_id ~= entry.control_id then
		target_state = {
			control_id = entry.control_id,
			index = 1,
		}
		view._better_inventory_options_panel_controller_target = target_state
	end

	if #targets > 1 and input_service and type(input_service.get) == "function" then
		if input_service:get("navigate_left_continuous") then
			target_state.index = math.max(target_state.index - 1, 1)
		elseif input_service:get("navigate_right_continuous") then
			target_state.index = math.min(target_state.index + 1, #targets)
		end
	end

	target_state.index = math.clamp(target_state.index, 1, #targets)
	local target_hotspot = selected_widget.content[targets[target_state.index]]

	if target_hotspot and targets[target_state.index] ~= "hotspot" then
		target_hotspot.is_focused = true
		target_hotspot.is_selected = true
	end

	return true
end

Features.inventory_options_panel_controller_focused = function(view)
	return view and view._better_inventory_options_panel_controller_focused == true
end

local function scenegraph_rect(owner, scenegraph_id)
	if type(owner) ~= "table" or type(owner._scenegraph_size) ~= "function" then
		return nil
	end

	local world_position = owner.scenegraph_world_position or owner._scenegraph_world_position

	if type(world_position) ~= "function" then
		return nil
	end

	if type(owner._force_update_scenegraph) == "function" then
		pcall(owner._force_update_scenegraph, owner)
	end

	local position_success, position = pcall(world_position, owner, scenegraph_id)
	local size_success, width, height = pcall(owner._scenegraph_size, owner, scenegraph_id)

	if not position_success or not size_success or type(position) ~= "table" or type(position[1]) ~= "number" or type(position[2]) ~= "number" or type(width) ~= "number" or type(height) ~= "number" then
		return nil
	end

	return {
		x = position[1],
		y = position[2],
		width = width,
		height = height,
	}
end

local function armoury_native_sort_panel_position(view)
	local canvas_width = INVENTORY_VIRTUAL_CANVAS_WIDTH
	local canvas_position = {
		0,
		0,
	}
	local scenegraph = view and view._ui_scenegraph
	local canvas = scenegraph and scenegraph.canvas

	if canvas and type(canvas.size) == "table" and type(canvas.size[1]) == "number" then
		canvas_width = canvas.size[1]
	end

	if view and type(view._scenegraph_world_position) == "function" then
		local success, position = pcall(view._scenegraph_world_position, view, "canvas")

		if success and type(position) == "table" then
			canvas_position = position
		end
	end

	local fallback_x = canvas_position[1] + canvas_width - ARMOURY_NATIVE_SORT_PANEL_RIGHT_MARGIN - ARMOURY_NATIVE_SORT_PANEL_WIDTH
	local fallback_y = canvas_position[2] + ARMOURY_NATIVE_SORT_PANEL_TOP
	local weapon_rect = scenegraph_rect(view and view._weapon_stats, "grid_background")

	if not weapon_rect then
		return fallback_x, fallback_y
	end

	local x = weapon_rect.x + weapon_rect.width + ARMOURY_NATIVE_SORT_PANEL_WEAPON_GAP
	local y = weapon_rect.y
	local parent = view and view._context and view._context.parent
	local wallet_frame = scenegraph_rect(parent, "corner_top_right")

	if wallet_frame then
		y = math.max(y, wallet_frame.y + wallet_frame.height + ARMOURY_NATIVE_SORT_PANEL_WALLET_GAP)
	end

	return x, y
end

local function armoury_native_sort_entries(mod, layout, view)
	local collapsed = view._better_inventory_armoury_native_sort_collapsed
	local sort_options = view._sort_options or {}
	local first_item_sorting_option = item_sorting_custom_option_start(view)
	local entries = {
		armoury_native_sort_header_entry(mod, layout, view, "sorting", mod:localize("inventory_sorting_inventory_label")),
	}

	if not collapsed.sorting then
		entries[#entries + 1] = armoury_native_sort_priority_entry(mod, layout, view, "prioritize_equipped_favorites", mod:localize("prioritize_equipped_favorites_inventory_label"))
		entries[#entries + 1] = armoury_native_sort_priority_entry(mod, layout, view, "prioritize_perfect_roll_weapons", mod:localize("prioritize_perfect_roll_weapons_inventory_label"))
	end

	if item_sorting_is_enabled() then
		entries[#entries + 1] = armoury_native_sort_header_entry(mod, layout, view, "item_sorting", mod:localize("item_sorting_mod_header"))

		if not collapsed.item_sorting then
			for option_index = first_item_sorting_option, #sort_options do
				entries[#entries + 1] = armoury_native_sort_entry(view, sort_options[option_index], option_index)
			end
		end
	end

	-- Native sorting is a sibling section, not part of the custom-priority
	-- section. Keep its header (and its own collapsed state) visible when the
	-- Sorting section is collapsed.
	entries[#entries + 1] = armoury_native_sort_header_entry(mod, layout, view, "native_sorting", mod:localize("armoury_native_sorting_header"))

	if not collapsed.native_sorting then
		for option_index = 1, first_item_sorting_option - 1 do
			entries[#entries + 1] = armoury_native_sort_entry(view, sort_options[option_index], option_index)
		end
	end

	return entries
end

local function armoury_native_sort_panel_height(entries)
	local content_height = 0

	for index = 1, #entries do
		content_height = content_height + entries[index].size[2]
	end

	content_height = content_height + math.max(#entries - 1, 0) * ARMOURY_NATIVE_SORT_PANEL_ROW_SPACING

	return math.max(ARMOURY_NATIVE_SORT_PANEL_MIN_HEIGHT, content_height + ARMOURY_NATIVE_SORT_PANEL_PADDING * 2 + 31)
end

local function rebuild_armoury_native_sort_panel(view)
	local panel = view and view._better_inventory_armoury_native_sort_panel

	if not panel or view._destroyed then
		return false
	end

	local entries = armoury_native_sort_entries(view._better_inventory_armoury_sort_mod, view._better_inventory_armoury_sort_layout, view)
	local panel_height = math.min(ARMOURY_NATIVE_SORT_PANEL_HEIGHT, armoury_native_sort_panel_height(entries))

	panel:update_grid_height(panel_height, panel_height)
	panel:present_grid_layout(entries, ARMOURY_NATIVE_SORT_BLUEPRINTS)

	return true
end

Features.update_armoury_native_sort_panel = function(view)
	local panel = view and view._better_inventory_armoury_native_sort_panel

	if not panel or view._destroyed then
		return false
	end

	local item_sorting_active = item_sorting_is_enabled()
	local item_sorting_signature = item_sorting_options_signature(view)

	if view._better_inventory_item_sorting_active ~= item_sorting_active or view._better_inventory_item_sorting_signature ~= item_sorting_signature then
		view._better_inventory_item_sorting_active = item_sorting_active
		view._better_inventory_item_sorting_signature = item_sorting_signature
		view._better_inventory_armoury_native_sort_rebuild_pending = true
	end

	if view._better_inventory_armoury_native_sort_rebuild_pending then
		view._better_inventory_armoury_native_sort_rebuild_pending = false
		rebuild_armoury_native_sort_panel(view)
	end

	local x, y = armoury_native_sort_panel_position(view)

	if type(panel.set_pivot_offset) == "function" then
		panel:set_pivot_offset(x, y)
	end

	return true
end

Features.setup_armoury_native_sort_panel = function(mod, layout, view, ViewElementGrid)
	if not is_armoury_sort_view(view) or view._better_inventory_armoury_native_sort_panel then
		return false
	end

	local sort_options = view._sort_options

	if type(sort_options) ~= "table" or (#sort_options == 0 and not item_sorting_is_enabled()) or type(ViewElementGrid) ~= "table" or type(view._add_element) ~= "function" then
		return false
	end

	local menu_settings = {
		bottom_chin = ARMOURY_NATIVE_SORT_PANEL_PADDING,
		edge_padding = 0,
		enable_gamepad_scrolling = false,
		grid_size = {
			ARMOURY_NATIVE_SORT_PANEL_WIDTH,
			ARMOURY_NATIVE_SORT_PANEL_HEIGHT,
		},
		grid_spacing = {
			0,
			ARMOURY_NATIVE_SORT_PANEL_ROW_SPACING,
		},
		ignore_blur = true,
		mask_size = {
			ARMOURY_NATIVE_SORT_PANEL_WIDTH,
			ARMOURY_NATIVE_SORT_PANEL_HEIGHT,
		},
		reset_selection_on_navigation_change = false,
		scrollbar_width = 7,
		title_height = 0,
		top_padding = ARMOURY_NATIVE_SORT_PANEL_PADDING,
		use_is_focused_for_navigation = false,
		use_select_on_focused = false,
		use_terminal_background = true,
	}
	local success, panel = pcall(view._add_element, view, ViewElementGrid, ARMOURY_NATIVE_SORT_PANEL_REFERENCE, 25, menu_settings)

	if not success or not panel then
		if type(mod.error) == "function" then
			mod:error("BetterInventory Armoury native-sort panel could not initialize: " .. tostring(panel))
		end

		if type(view._remove_element) == "function" then
			pcall(view._remove_element, view, ARMOURY_NATIVE_SORT_PANEL_REFERENCE)
		end

		return false
	end

	view._better_inventory_armoury_native_sort_panel = panel
	view._better_inventory_armoury_native_sort_widgets = {}
	view._better_inventory_armoury_native_sort_collapsed = {
		item_sorting = false,
		native_sorting = false,
		sorting = false,
	}
	view._better_inventory_item_sorting_active = item_sorting_is_enabled()
	view._better_inventory_item_sorting_signature = item_sorting_options_signature(view)
	view._better_inventory_armoury_native_sort_rebuild_pending = false
	view._better_inventory_armoury_sort_layout = layout
	view._better_inventory_armoury_sort_mod = mod
	registered_armoury_views[view] = true
	if type(panel.disable_input) == "function" then
		panel:disable_input(false)
	end

	if type(panel.set_visibility) == "function" then
		panel:set_visibility(true)
	end

	local entries = armoury_native_sort_entries(mod, layout, view)

	panel:update_grid_height(ARMOURY_NATIVE_SORT_PANEL_HEIGHT, ARMOURY_NATIVE_SORT_PANEL_HEIGHT)
	panel:present_grid_layout(entries, ARMOURY_NATIVE_SORT_BLUEPRINTS)
	Features.update_armoury_native_sort_panel(view)

	return true
end

local function item_priority(view, layout_entry)
	local item = layout_entry and (layout_entry.real_item or layout_entry.item)

	if not item then
		return 0
	end

	local slots = item.slots
	local equipped = slots and type(view.is_item_equipped_in_any_slot) == "function" and view:is_item_equipped_in_any_slot(item, slots)

	if equipped then
		return 2
	end

	if item.gear_id and Items.is_item_id_favorited(item.gear_id) then
		return 1
	end

	return 0
end

local function inventory_sort_priority(mod, view, layout_entry)
	local item = layout_entry and (layout_entry.real_item or layout_entry.item)

	if not item then
		return 0
	end

	if mod:get("prioritize_equipped_favorites") ~= false then
		local equipped_favorite_priority = item_priority(view, layout_entry)

		if equipped_favorite_priority > 0 then
			return equipped_favorite_priority + 2
		end
	end

	if mod:get("prioritize_perfect_roll_weapons") == true and Features.is_perfect_roll_weapon(item) then
		return 1
	end

	return 0
end

local function configure_sort_options(mod, view)
	local sort_options = view._sort_options

	if type(sort_options) ~= "table" then
		return
	end

	for index = 1, #sort_options do
		local option = sort_options[index]
		local original_sort = option and option.sort_function

		if type(original_sort) == "function" and not option._better_inventory_original_sort then
			option._better_inventory_original_sort = original_sort
			option.sort_function = function(left, right)
				local left_priority = inventory_sort_priority(mod, view, left)
				local right_priority = inventory_sort_priority(mod, view, right)

				if left_priority ~= right_priority then
					return left_priority > right_priority
				end

				return original_sort(left, right)
			end
		end
	end
end

Features.configure_inventory_sort_options = function(mod, layout, view)
	if not is_inventory_view(layout, view) then
		return
	end

	configure_sort_options(mod, view)
end

Features.configure_armoury_sort_options = function(mod, view)
	if not is_armoury_requisition_view(view) then
		return
	end

	configure_sort_options(mod, view)
end

Features.configure_global_store_sort_options = function(mod, view)
	if not is_global_store_view(view) then
		return
	end

	configure_sort_options(mod, view)
end

Features.resort_inventory = function(mod, layout, view)
	if not is_sortable_view(layout, view) or view._destroyed or type(view._sort_grid_layout) ~= "function" then
		return
	end

	-- The native discard view temporarily presents a filtered copy of the inventory.
	-- Re-presenting that copy here can leave stale layout/spacing entries when ESC
	-- restores the full inventory. Darktide sorts the full offer layout itself while
	-- closing discard mode, using the current wrapped comparator.
	if view._discard_items_element then
		return
	end

	local sort_options = view._sort_options
	local option = sort_options and (view._selected_sort_option or sort_options[view._selected_sort_option_index or 1])
	local sort_function = option and option.sort_function

	if sort_function then
		view:_sort_grid_layout(sort_function)
	end
end

local function item_level(item)
	local expertise = Items.expertise_level(item, true)

	return tonumber(expertise)
end

local function item_type_is_enabled(mod, item_type)
	if item_type == "WEAPON_MELEE" then
		return mod:get("quick_discard_include_melee") ~= false
	elseif item_type == "WEAPON_RANGED" then
		return mod:get("quick_discard_include_ranged") ~= false
	elseif item_type == "GADGET" then
		return mod:get("quick_discard_include_curios") ~= false
	end

	return false
end

local function displayed_base_stat_values(item)
	local base_stats = item and item.base_stats

	if type(base_stats) ~= "table" or #base_stats ~= 5 then
		return
	end

	local values = {}

	for index = 1, #base_stats do
		local stat = base_stats[index]
		local raw_value = type(stat) == "table" and tonumber(stat.value)

		if not raw_value then
			return
		end

		values[index] = math.floor(raw_value * 100 + 0.5)
	end

	return values
end

local function projected_max_base_stat_values(item)
	local base_stats = item and item.base_stats

	if type(base_stats) ~= "table" or #base_stats ~= 5 or type(Items.preview_stats_change) ~= "function" or type(Items.max_expertise_level) ~= "function" then
		return
	end

	-- expertise_level also returns a boolean indicating whether baseItemLevel was
	-- present. Passing the call directly to tonumber forwards that boolean as
	-- tonumber's optional numeric base and raises for virtually every weapon.
	local current_expertise = Items.expertise_level(item, true)

	current_expertise = tonumber(current_expertise)
	local maximum_expertise = tonumber(Items.max_expertise_level())

	if not current_expertise or not maximum_expertise or current_expertise >= maximum_expertise then
		return
	end

	local preview_stats = {}
	local preview_keys = {}

	for index = 1, #base_stats do
		local stat = base_stats[index]
		local raw_value = type(stat) == "table" and tonumber(stat.value)

		if not raw_value then
			return
		end

		local preview_key = "better_inventory_stat_" .. index

		preview_keys[index] = preview_key
		preview_stats[index] = {
			display_name = preview_key,
			fraction = raw_value,
			name = stat.name or preview_key,
		}
	end

	local projected_stats = Items.preview_stats_change(item, maximum_expertise - current_expertise, preview_stats)

	if type(projected_stats) ~= "table" then
		return
	end

	local values = {}

	for index = 1, #preview_keys do
		local projected_stat = projected_stats[preview_keys[index]]
		local projected_value = tonumber(projected_stat and projected_stat.value)

		if not projected_value then
			return
		end

		values[index] = math.floor(projected_value + 0.5)
	end

	return values
end

local function values_are_perfect_roll(values)
	if type(values) ~= "table" or #values ~= 5 then
		return false
	end

	local maximum_stats = 0
	local remaining_stats = 0

	for index = 1, #values do
		local displayed_value = values[index]

		if displayed_value == 80 then
			maximum_stats = maximum_stats + 1
		elseif displayed_value >= 60 then
			remaining_stats = remaining_stats + 1
		else
			return false
		end
	end

	return maximum_stats == 4 and remaining_stats == 1
end

local function calculate_is_perfect_roll_weapon(item)
	if not item or not Items.is_weapon(item.item_type) then
		return false
	end

	local total = Items.total_stats_value(item)

	if not total or total > 380 then
		return false
	end

	local base_stats = item.base_stats
	local current_expertise

	if total ~= 380 then
		local expertise = Items.expertise_level(item, true)

		current_expertise = tonumber(expertise)
	end
	local cached = perfect_roll_cache[item]
	local cache_matches = cached and cached.total == total and cached.current_expertise == current_expertise and type(base_stats) == "table" and #base_stats == 5

	if cache_matches then
		for index = 1, 5 do
			local raw_value = type(base_stats[index]) == "table" and tonumber(base_stats[index].value)

			if raw_value ~= cached.raw_values[index] then
				cache_matches = false
				break
			end
		end
	end

	if cache_matches then
		return cached.result
	end

	-- Total power is calculated from unrounded backend values, while each visible
	-- attribute is rounded independently. Consequently the fifth visible stat can
	-- legitimately show 61 or 62 on an otherwise perfect 380 roll.
	local result = total == 380 and values_are_perfect_roll(displayed_base_stat_values(item)) or values_are_perfect_roll(projected_max_base_stat_values(item))

	if type(base_stats) == "table" and #base_stats == 5 then
		local raw_values = {}

		for index = 1, 5 do
			raw_values[index] = type(base_stats[index]) == "table" and tonumber(base_stats[index].value) or false
		end

		perfect_roll_cache[item] = {
			current_expertise = current_expertise,
			raw_values = raw_values,
			result = result,
			total = total,
		}
	end

	-- Rarity upgrades do not change base attributes, but expertise upgrades do.
	-- Protect an underpowered weapon when Darktide's own maximum-expertise preview
	-- resolves to the same four-at-80, fifth-at-least-60 distribution.
	return result
end

Features.is_perfect_roll_weapon = function(item)
	-- Sorting invokes this from a native comparator. A legacy or partially
	-- materialized item must sort as ordinary instead of taking down the view.
	local success, result = pcall(calculate_is_perfect_roll_weapon, item)

	return success and result == true
end

local CURIO_PRIMARY_TRAIT_SETTINGS = {
	gadget_innate_health_increase = "quick_discard_keep_health_curios",
	gadget_innate_toughness_increase = "quick_discard_keep_toughness_curios",
	gadget_innate_max_wounds_increase = "quick_discard_keep_wound_curios",
	gadget_stamina_increase = "quick_discard_keep_stamina_curios",
}
local CURIO_BUYER_PRIMARY_TRAIT_SETTINGS = {
	gadget_innate_health_increase = "automatic_curio_buy_health",
	gadget_innate_toughness_increase = "automatic_curio_buy_toughness",
	gadget_innate_max_wounds_increase = "automatic_curio_buy_wounds",
	gadget_stamina_increase = "automatic_curio_buy_stamina",
}
local CURIO_BUYER_PRIMARY_ROLL_SETTINGS = {
	gadget_innate_health_increase = {
		default = 21,
		setting_id = "automatic_curio_min_health",
	},
	gadget_innate_toughness_increase = {
		default = 17,
		setting_id = "automatic_curio_min_toughness",
	},
}

local function curio_primary_trait_name(item)
	local primary_trait = item and item.traits and item.traits[1]
	local trait_name, value = CurioValues.resolve(primary_trait)

	if type(trait_name) ~= "string" then
		return
	end

	for known_trait_name in pairs(CURIO_PRIMARY_TRAIT_SETTINGS) do
		if trait_name == known_trait_name or string.find(trait_name, known_trait_name, 1, true) then
			return known_trait_name, value
		end
	end
end

local function high_level_curio_is_protected(mod, item, level, protected_level)
	if level < protected_level then
		return false
	end

	local primary_trait_name = curio_primary_trait_name(item)
	local setting_id = primary_trait_name and CURIO_PRIMARY_TRAIT_SETTINGS[primary_trait_name]

	-- Unknown or future primary blessings fail closed. A game update must not turn
	-- an unrecognized high-level Curio into an automatic-discard candidate.
	return not setting_id or mod:get(setting_id) ~= false
end

local function automatic_curio_acquisition_protects(mod, item, level)
	if mod:get("enable_automatic_curio_acquisition") ~= true then
		return false
	end

	local minimum_level = math.clamp(math.floor(tonumber(mod:get("automatic_curio_min_item_level")) or 410), 0, 500)

	if level < minimum_level then
		return false
	end

	local primary_trait_name, primary_value = curio_primary_trait_name(item)
	local setting_id = primary_trait_name and CURIO_BUYER_PRIMARY_TRAIT_SETTINGS[primary_trait_name]

	if not setting_id or mod:get(setting_id) == false then
		return false
	end

	local roll_config = CURIO_BUYER_PRIMARY_ROLL_SETTINGS[primary_trait_name]

	if roll_config then
		-- Missing inventory roll data fails safe. It must never make an acquired or
		-- partially materialized Curio eligible for destructive automatic discard.
		if primary_value then
			local minimum_roll = math.clamp(tonumber(mod:get(roll_config.setting_id)) or roll_config.default, 0, 100)

			if primary_value + 0.0001 < minimum_roll then
				return false
			end
		end
	end

	return true
end

local function eligible_for_quick_discard(mod, item, is_equipped, maximum_equipped_levels, favorite_gear_ids)
	if not item or not item.gear_id or not item_type_is_enabled(mod, item.item_type) then
		return false
	end

	local rarity = tonumber(item.rarity)
	local rarity_threshold = math.clamp(math.floor(tonumber(mod:get("quick_discard_rarity")) or 1), 1, 5)

	if not rarity or rarity < 1 or rarity > rarity_threshold then
		return false
	end

	local favorited = favorite_gear_ids and favorite_gear_ids[item.gear_id] or not favorite_gear_ids and Items.is_item_id_favorited(item.gear_id)

	if favorited then
		return false
	end

	if is_equipped and is_equipped(item) then
		return false
	end

	local level = item_level(item)
	local maximum_level = math.clamp(math.floor(tonumber(mod:get("quick_discard_max_item_level")) or 490), 0, 500)

	if not level or level > maximum_level then
		return false
	end

	if mod:get("quick_discard_protect_above_equipped_level") ~= false then
		local maximum_equipped_level = maximum_equipped_levels and maximum_equipped_levels[item.item_type]

		if maximum_equipped_level and level > maximum_equipped_level then
			return false
		end
	end

	if Items.is_weapon(item.item_type) and mod:get("quick_discard_protect_perfect_weapons") ~= false and Features.is_perfect_roll_weapon(item) then
		return false
	end

	-- Buying and automatically discarding the same Curio on a later hub entry is
	-- incoherent and wastes currency. Acquisition-filter matches remain protected
	-- even when the general high-level Curio protection is configured differently.
	if item.item_type == "GADGET" and automatic_curio_acquisition_protects(mod, item, level) then
		return false
	end

	if item.item_type == "GADGET" and mod:get("quick_discard_protect_high_level_curios") ~= false then
		local protected_level = math.clamp(math.floor(tonumber(mod:get("quick_discard_curio_protection_level")) or 410), 0, 500)

		if high_level_curio_is_protected(mod, item, level, protected_level) then
			return false
		end
	end

	return true
end

local function collect_quick_discard_candidates(mod, source_items, is_equipped, allowed_gear_ids, maximum_equipped_levels, favorite_gear_ids)
	local candidates = {}
	local excluded_errors = 0
	local first_error
	local seen = {}

	for _, entry in pairs(source_items or {}) do
		local item = entry and (entry.real_item or entry.item or entry)
		local gear_id = item and item.gear_id

		if gear_id and not seen[gear_id] and (not allowed_gear_ids or allowed_gear_ids[gear_id]) then
			local success, eligible = pcall(eligible_for_quick_discard, mod, item, is_equipped, maximum_equipped_levels, favorite_gear_ids)

			if success and eligible then
				seen[gear_id] = true
				candidates[#candidates + 1] = item
			elseif not success then
				-- Account inventories can contain legacy or partially materialized gear
				-- that current item utilities cannot evaluate. Automatic discard must
				-- fail closed for those entries instead of aborting the entire scan.
				excluded_errors = excluded_errors + 1
				first_error = first_error or eligible
			end
		end
	end

	return candidates, excluded_errors, first_error
end

local function add_loadout_gear_ids(target, loadout)
	for _, item in pairs(loadout or {}) do
		local gear_id = type(item) == "table" and item.gear_id or type(item) == "string" and item or nil

		if gear_id then
			target[gear_id] = true
		end
	end
end

local function equipped_gear_ids(profile, profile_presets)
	local equipped = {}

	add_loadout_gear_ids(equipped, profile and profile.loadout)
	add_loadout_gear_ids(equipped, profile and profile.loadout_item_ids)

	-- Profile presets are saved independently from the currently active profile.
	-- Treat every item referenced by every preset as equipped: an unfavorited item
	-- used only by an inactive loadout must never enter any discard candidate set.
	if type(profile_presets) == "table" then
		for _, preset in pairs(profile_presets) do
			if type(preset) == "table" then
				add_loadout_gear_ids(equipped, preset.loadout)
				add_loadout_gear_ids(equipped, preset.loadout_item_ids)
			end
		end
	end

	return equipped
end

local function maximum_equipped_levels(source_items, protected_gear_ids)
	local maximums = {}
	local unreadable_level = -1

	for _, entry in pairs(source_items or {}) do
		local item = entry and (entry.real_item or entry.item or entry)
		local gear_id = item and item.gear_id
		local item_type = item and item.item_type

		-- Item level 500 is the absolute ceiling. Once a category reaches it,
		-- subsequent equipped items of that category cannot improve its maximum.
		-- An unreadable equipped/loadout item is more important than any readable
		-- maximum: use a sentinel below every valid level so the later
		-- `level > maximum` check protects the entire category. This keeps both
		-- manual and automatic discard fail-closed for legacy account gear.
		if gear_id and protected_gear_ids[gear_id] and item_type and maximums[item_type] ~= 500 and maximums[item_type] ~= unreadable_level then
			local level_ok, level = pcall(item_level, item)

			if level_ok and level then
				maximums[item_type] = math.min(math.max(maximums[item_type] or 0, level), 500)
			else
				maximums[item_type] = unreadable_level
			end
		end
	end

	return maximums
end

local function preview_profile(view)
	local player = view and view._preview_player

	if player and not player.__deleted and type(player.profile) == "function" then
		local success, profile = pcall(player.profile, player)

		if success then
			return profile
		end
	end
end

Features.quick_discard_candidates = function(mod, layout, view, allowed_gear_ids)
	if not is_inventory_view(layout, view) or view._destroyed then
		return {}
	end

	local parent_inventory = view._parent and view._parent._inventory_items
	local source_items = type(parent_inventory) == "table" and next(parent_inventory) and parent_inventory or view._offer_items_layout or {}
	local presets_ok, profile_presets = pcall(ProfileUtils.get_profile_presets)
	local protected_gear_ids = equipped_gear_ids(preview_profile(view), presets_ok and profile_presets or nil)
	local equipped_levels = maximum_equipped_levels(source_items, protected_gear_ids)
	local function is_equipped(item)
		if item.gear_id and protected_gear_ids[item.gear_id] then
			return true
		end

		local slots = item.slots

		return slots and type(view.is_item_equipped_in_any_slot) == "function" and view:is_item_equipped_in_any_slot(item, slots) or false
	end

	local candidates = collect_quick_discard_candidates(mod, source_items, is_equipped, allowed_gear_ids, equipped_levels)

	return candidates
end

local function quick_discard_candidates_from_items_detailed(mod, source_items, equipped_gear_ids, allowed_gear_ids, favorite_gear_ids)
	local equipped_levels = maximum_equipped_levels(source_items, equipped_gear_ids or {})
	local function is_equipped(item)
		return equipped_gear_ids and equipped_gear_ids[item.gear_id] == true
	end

	return collect_quick_discard_candidates(mod, source_items, is_equipped, allowed_gear_ids, equipped_levels, favorite_gear_ids)
end

Features.quick_discard_candidates_from_items = function(mod, source_items, equipped_gear_ids, allowed_gear_ids, favorite_gear_ids)
	local candidates = quick_discard_candidates_from_items_detailed(mod, source_items, equipped_gear_ids, allowed_gear_ids, favorite_gear_ids)

	return candidates
end

local function summary_type_name(mod, count, singular_id, plural_id)
	return mod:localize(count == 1 and singular_id or plural_id)
end

local function rarity_summary(mod, candidates)
	local counts = {}
	local lines = {}

	for index = 1, #candidates do
		local item = candidates[index]
		local rarity = tonumber(item.rarity)

		if rarity then
			local rarity_counts = counts[rarity] or {
				curios = 0,
				melee = 0,
				ranged = 0,
				total = 0,
			}

			rarity_counts.total = rarity_counts.total + 1

			if item.item_type == "WEAPON_MELEE" then
				rarity_counts.melee = rarity_counts.melee + 1
			elseif item.item_type == "WEAPON_RANGED" then
				rarity_counts.ranged = rarity_counts.ranged + 1
			elseif item.item_type == "GADGET" then
				rarity_counts.curios = rarity_counts.curios + 1
			end

			counts[rarity] = rarity_counts
		end
	end

	for rarity = 1, 5 do
		local rarity_counts = counts[rarity]

		if rarity_counts then
			local settings = RaritySettings[rarity]
			local color = settings and settings.color or Color.white(255, true)
			local name = settings and Localize(settings.display_name) or tostring(rarity)
			local breakdown = ""

			if mod:get("quick_discard_show_type_breakdown") ~= false then
				breakdown = string.format(" (%d %s, %d %s %s %d %s)", rarity_counts.melee, summary_type_name(mod, rarity_counts.melee, "quick_discard_summary_melee_singular", "quick_discard_summary_melee_plural"), rarity_counts.ranged, summary_type_name(mod, rarity_counts.ranged, "quick_discard_summary_ranged_singular", "quick_discard_summary_ranged_plural"), mod:localize("quick_discard_summary_and"), rarity_counts.curios, summary_type_name(mod, rarity_counts.curios, "quick_discard_summary_curio_singular", "quick_discard_summary_curio_plural"))
			end

			lines[#lines + 1] = string.format("{#color(%d,%d,%d)}%d %s%s{#reset()}", color[2], color[3], color[4], rarity_counts.total, name, breakdown)
		end
	end

	return table.concat(lines, "\n")
end

local function discarded_rarity_summary(mod, candidates)
	local counts = {}
	local lines = {}

	for index = 1, #(candidates or {}) do
		local rarity = tonumber(candidates[index] and candidates[index].rarity)

		if rarity then
			counts[rarity] = (counts[rarity] or 0) + 1
		end
	end

	for rarity = 1, 5 do
		local count = counts[rarity]

		if count and count > 0 then
			local settings = RaritySettings[rarity]
			local color = settings and settings.color or Color.white(255, true)
			local name = settings and Localize(settings.display_name) or tostring(rarity)

			lines[#lines + 1] = string.format("{#color(%d,%d,%d)}- %d %s %s{#reset()}", color[2], color[3], color[4], count, name, mod:localize("quick_discard_notification_items"))
		end
	end

	return table.concat(lines, "\n")
end

local function show_discard_summary_notification(mod, candidates)
	if mod:get("quick_discard_show_summary_notification") == false or #(candidates or {}) == 0 then
		return
	end

	local event_manager = Managers and Managers.event

	if not event_manager or type(event_manager.trigger) ~= "function" then
		return
	end

	pcall(event_manager.trigger, event_manager, "event_add_notification_message", "custom", {
		line_1 = mod:localize("quick_discard_notification_title"),
		line_1_color = Color.terminal_text_header(255, true),
		line_2 = discarded_rarity_summary(mod, candidates),
		line_2_color = Color.white(255, true),
	})
end

local function show_automatic_no_candidates_notification(mod)
	if mod:get("quick_discard_disable_no_eligible_notification") == true then
		return false
	end

	local event_manager = Managers and Managers.event

	if not event_manager or type(event_manager.trigger) ~= "function" then
		return false
	end

	pcall(event_manager.trigger, event_manager, "event_add_notification_message", "custom", {
		line_1 = mod:localize("quick_discard_automatic_nothing_notification_title"),
		line_1_color = Color.terminal_text_header(255, true),
		line_2 = mod:localize("quick_discard_automatic_nothing_notification_description"),
		line_2_color = Color.white(255, true),
	})

	return true
end

local function show_popup(context)
	local event_manager = Managers and Managers.event

	if not event_manager or type(event_manager.trigger) ~= "function" then
		return false
	end

	return pcall(event_manager.trigger, event_manager, "event_show_ui_popup", context)
end

local discard_transaction = {
	owner = nil,
	view = nil,
}

local function acquire_discard_transaction(owner, view)
	if discard_transaction.owner then
		return false
	end

	discard_transaction.owner = owner
	discard_transaction.view = view

	if view then
		view._better_inventory_discard_pending = true
	end

	return true
end

local function release_discard_transaction(owner)
	if discard_transaction.owner ~= owner then
		return false
	end

	local view = discard_transaction.view

	discard_transaction.owner = nil
	discard_transaction.view = nil

	if view then
		view._better_inventory_discard_pending = false
	end

	return true
end

Features.request_quick_discard = function(mod, layout, view)
	if view._better_inventory_discard_pending or discard_transaction.owner then
		return
	end

	local candidates = Features.quick_discard_candidates(mod, layout, view)

	if #candidates == 0 then
		show_popup({
			description_text_unlocalized = mod:localize("quick_discard_nothing_description"),
			options = {
				{
					close_on_pressed = true,
					no_localization = true,
					text = mod:localize("quick_discard_close"),
				},
			},
			title_text_unlocalized = mod:localize("quick_discard_nothing_title"),
		})

		return
	end

	local captured_ids = {}

	for index = 1, #candidates do
		captured_ids[candidates[index].gear_id] = true
	end

	if not acquire_discard_transaction("manual", view) then
		return
	end

	local resolved = false

	local function clear_pending()
		if resolved then
			return
		end

		resolved = true
		release_discard_transaction("manual")
	end

	local function confirm_discard()
		if resolved then
			return
		end

		local revalidated = Features.quick_discard_candidates(mod, layout, view, captured_ids)
		local gear_ids = {}

		for index = 1, #revalidated do
			gear_ids[#gear_ids + 1] = revalidated[index].gear_id
		end

		local event_manager = Managers and Managers.event

		if #gear_ids > 0 and event_manager and type(event_manager.trigger) == "function" then
			pcall(event_manager.trigger, event_manager, "event_discard_items", gear_ids)
		end

		-- The native event owns its asynchronous backend request and does not
		-- expose a completion result. Do not claim success before it completes.
		clear_pending()
	end

	local popup_shown = show_popup({
		description_text_unlocalized = tostring(#candidates) .. " " .. mod:localize("quick_discard_confirmation_description") .. "\n\n" .. rarity_summary(mod, candidates) .. "\n\n" .. mod:localize("quick_discard_confirmation_warning"),
		options = {
			{
				callback = confirm_discard,
				close_on_pressed = true,
				no_localization = true,
				text = mod:localize("quick_discard_confirmation_yes"),
			},
			{
				callback = clear_pending,
				close_on_pressed = true,
				hotkey = "back",
				no_localization = true,
				template_type = "terminal_button_small",
				text = mod:localize("quick_discard_confirmation_no"),
			},
		},
		title_text_unlocalized = mod:localize("quick_discard_confirmation_title"),
	})

	if not popup_shown then
		clear_pending()
	end
end

local AUTOMATIC_DISCARD_DELAY = 5
local AUTOMATIC_DISCARD_MAX_FETCH_ATTEMPTS = 3
local automatic_discard_state = {
	elapsed = 0,
	fetch_attempts = 0,
	hub_character_id = nil,
	scheduled = false,
	started = false,
	token = 0,
}

local function automatic_discard_enabled(mod)
	return mod:get("enable_experimental_quick_discard") == true and mod:get("quick_discard_mode") == "automatic"
end

Features.morningstar_auto_discard_is_busy = function(mod)
	-- The scanner leaves `scheduled` set while its read-only fetch is in flight,
	-- then the transaction owner remains authoritative through confirmation and
	-- deletion. Once both clear, a Curio purchase can no longer enter this pass.
	return automatic_discard_enabled(mod) and (automatic_discard_state.scheduled or discard_transaction.owner == "automatic")
end

local function current_game_mode_name()
	local state = Managers and Managers.state
	local game_mode = state and state.game_mode

	if not game_mode or type(game_mode.game_mode_name) ~= "function" then
		return
	end

	local success, name = pcall(game_mode.game_mode_name, game_mode)

	return success and name or nil
end

local function is_morningstar()
	local game_mode_name = current_game_mode_name()

	return game_mode_name == "hub" or game_mode_name == "hub_singleplay"
end

local function automatic_discard_info(mod, message)
	if mod and type(mod.info) == "function" then
		mod:info("[Automatic discard] " .. message)
	end
end

local function automatic_discard_error(error_value)
	if type(error_value) == "table" then
		local message = error_value.message or error_value.error or error_value[1]

		if message then
			return tostring(message)
		elseif type(table.tostring) == "function" then
			return table.tostring(error_value, 2)
		end
	end

	return tostring(error_value)
end

local function current_player_and_character()
	local player_manager = Managers and Managers.player
	local player
	local character_id

	if player_manager and type(player_manager.local_player) == "function" then
		local success, value = pcall(player_manager.local_player, player_manager, 1)

		player = success and value or nil
	end

	if player and not player.__deleted and type(player.character_id) == "function" then
		local success, value = pcall(player.character_id, player)

		character_id = success and value or nil
	end

	return player, character_id
end

local function player_profile(player)
	if not player or player.__deleted or type(player.profile) ~= "function" then
		return
	end

	local success, profile = pcall(player.profile, player)

	return success and profile or nil
end

local function automatic_protection_snapshot(character_id)
	local player, current_character_id = current_player_and_character()

	if not player or current_character_id ~= character_id then
		return nil, "the current player or character changed"
	end

	local profile = player_profile(player)

	if type(profile) ~= "table" then
		return nil, "the current profile is unavailable"
	end

	local save_manager = Managers and Managers.save

	if not save_manager or type(save_manager.character_data) ~= "function" then
		return nil, "character save data is unavailable"
	end

	local save_ok, character_data = pcall(save_manager.character_data, save_manager, character_id)

	if not save_ok or type(character_data) ~= "table" or type(character_data.favorite_items) ~= "table" then
		return nil, "favorite-item save data is unavailable"
	end

	local presets_ok, profile_presets = pcall(ProfileUtils.get_profile_presets)

	if not presets_ok or type(profile_presets) ~= "table" then
		return nil, "saved loadout presets are unavailable"
	end

	return {
		equipped_gear_ids = equipped_gear_ids(profile, profile_presets),
		favorite_gear_ids = character_data.favorite_items,
	}
end

local function fetch_inventory_promise(gear_service, character_id)
	if not gear_service or type(gear_service.fetch_inventory) ~= "function" then
		return nil, "GearService.fetch_inventory is unavailable"
	end

	local success, promise = pcall(gear_service.fetch_inventory, gear_service, character_id)

	if not success then
		return nil, promise
	end

	if not promise or type(promise.next) ~= "function" or type(promise.catch) ~= "function" then
		return nil, "GearService.fetch_inventory returned no compatible promise"
	end

	return promise
end

local function automatic_context_is_current(mod, token, character_id)
	if automatic_discard_state.token ~= token or not automatic_discard_enabled(mod) or not is_morningstar() then
		return false
	end

	local _, current_character_id = current_player_and_character()

	return current_character_id == character_id
end

local function notify_discard_result(mod, candidates, result)
	local total_rewards = {}
	local deleted_ids = {}

	for index = 1, #(result or {}) do
		local operation = result[index]
		local gear_id = operation and operation.gearId

		if gear_id then
			deleted_ids[gear_id] = true
		end

		for reward_index = 1, #(operation and operation.rewards or {}) do
			local reward = operation.rewards[reward_index]
			local reward_type = reward and reward.type
			local amount = tonumber(reward and reward.amount)

			if reward_type and amount then
				total_rewards[reward_type] = (total_rewards[reward_type] or 0) + amount
			end
		end
	end

	local event_manager = Managers and Managers.event

	if event_manager and type(event_manager.trigger) == "function" then
		pcall(event_manager.trigger, event_manager, "event_force_wallet_update")
		pcall(event_manager.trigger, event_manager, "event_force_refresh_inventory")

		for reward_type, reward_amount in pairs(total_rewards) do
			pcall(event_manager.trigger, event_manager, "event_add_notification_message", "currency", {
				amount = reward_amount,
				currency = reward_type,
			})
		end
	end

	local discarded_candidates = {}

	for index = 1, #(candidates or {}) do
		local candidate = candidates[index]

		if candidate and deleted_ids[candidate.gear_id] then
			discarded_candidates[#discarded_candidates + 1] = candidate
		end
	end

	show_discard_summary_notification(mod, discarded_candidates)
end

local function delete_automatic_candidates(mod, token, character_id, captured_ids)
	if not automatic_context_is_current(mod, token, character_id) then
		release_discard_transaction("automatic")
		return
	end

	local gear_service = Managers and Managers.data_service and Managers.data_service.gear

	if not gear_service or type(gear_service.fetch_inventory) ~= "function" or type(gear_service.delete_gear_batch) ~= "function" then
		release_discard_transaction("automatic")
		return
	end

	local fetch_promise, fetch_error = fetch_inventory_promise(gear_service, character_id)

	if not fetch_promise then
		automatic_discard_info(mod, "Final revalidation could not start: " .. automatic_discard_error(fetch_error))
		release_discard_transaction("automatic")
		return
	end

	fetch_promise:next(function(items)
		if not automatic_context_is_current(mod, token, character_id) or type(items) ~= "table" then
			release_discard_transaction("automatic")
			return
		end

		local protection, protection_error = automatic_protection_snapshot(character_id)

		if not protection then
			automatic_discard_info(mod, "Final revalidation stopped safely because " .. automatic_discard_error(protection_error) .. ".")
			release_discard_transaction("automatic")

			return
		end

		local candidates = Features.quick_discard_candidates_from_items(mod, items, protection.equipped_gear_ids, captured_ids, protection.favorite_gear_ids)
		local gear_ids = {}

		for index = 1, #candidates do
			gear_ids[index] = candidates[index].gear_id
		end

		automatic_discard_info(mod, string.format("Revalidated %d candidate(s) immediately before deletion.", #gear_ids))

		if #gear_ids == 0 then
			release_discard_transaction("automatic")
			return
		end

		local delete_ok, delete_promise = pcall(gear_service.delete_gear_batch, gear_service, gear_ids)

		if not delete_ok or not delete_promise or type(delete_promise.next) ~= "function" or type(delete_promise.catch) ~= "function" then
			release_discard_transaction("automatic")
			error(delete_ok and "GearService.delete_gear_batch returned no compatible promise" or delete_promise)
		end

		return delete_promise:next(function(result)
			notify_discard_result(mod, candidates, result)
			release_discard_transaction("automatic")

			return result
		end)
	end):catch(function(error_value)
		-- GearService already reports backend failures. Keep the one-shot
		-- Morningstar pass from surfacing an unhandled promise rejection.
		automatic_discard_info(mod, "Final revalidation failed: " .. automatic_discard_error(error_value))
		release_discard_transaction("automatic")
	end)
end

local function present_automatic_discard(mod, token, character_id, candidates)
	if not acquire_discard_transaction("automatic") then
		automatic_discard_info(mod, "Suppressed a duplicate automatic discard confirmation preview.")

		return
	end

	local captured_ids = {}

	for index = 1, #candidates do
		captured_ids[candidates[index].gear_id] = true
	end

	if mod:get("quick_discard_skip_automatic_confirmation") == true then
		automatic_discard_info(mod, "Confirmation skipping is enabled; starting final safety revalidation.")
		delete_automatic_candidates(mod, token, character_id, captured_ids)

		return
	end

	local confirmation_resolved = false

	local function clear_confirmation()
		if confirmation_resolved then
			return
		end

		confirmation_resolved = true
		release_discard_transaction("automatic")
	end

	local popup_shown = show_popup({
		description_text_unlocalized = tostring(#candidates) .. " " .. mod:localize("quick_discard_confirmation_description") .. "\n\n" .. rarity_summary(mod, candidates) .. "\n\n" .. mod:localize("quick_discard_confirmation_warning"),
		options = {
			{
				callback = function()
					if not confirmation_resolved and discard_transaction.owner == "automatic" then
						confirmation_resolved = true
						delete_automatic_candidates(mod, token, character_id, captured_ids)
					end
				end,
				close_on_pressed = true,
				no_localization = true,
				text = mod:localize("quick_discard_confirmation_yes"),
			},
			{
				callback = clear_confirmation,
				close_on_pressed = true,
				hotkey = "back",
				no_localization = true,
				template_type = "terminal_button_small",
				text = mod:localize("quick_discard_confirmation_no"),
			},
		},
		title_text_unlocalized = mod:localize("quick_discard_automatic_confirmation_title"),
	})

	if not popup_shown then
		clear_confirmation()
	end

	automatic_discard_info(mod, popup_shown and "Displayed the automatic discard confirmation preview." or "Could not display the automatic discard confirmation preview; no items were deleted.")
end

Features.begin_morningstar_auto_discard = function(mod)
	-- Some startup/state-transition orders can report GameplayStateRun enter
	-- again after the one-shot transaction has presented its confirmation or
	-- started deletion. Keep that transaction authoritative until it finishes.
	if discard_transaction.owner == "automatic" then
		automatic_discard_info(mod, "Ignored a duplicate automatic discard re-arm while a transaction is active.")

		return
	end

	automatic_discard_state.token = automatic_discard_state.token + 1
	automatic_discard_state.elapsed = 0
	automatic_discard_state.fetch_attempts = 0
	automatic_discard_state.hub_character_id = nil
	automatic_discard_state.scheduled = automatic_discard_enabled(mod)
	automatic_discard_state.started = false
end

Features.cancel_morningstar_auto_discard = function(preserve_transaction)
	-- A momentary unavailable/non-hub game-mode observation must not unlock an
	-- active transaction. A real GameplayStateRun exit or mod disable calls this
	-- without preservation because its UI and backend context are going away.
	if preserve_transaction and discard_transaction.owner == "automatic" then
		automatic_discard_state.scheduled = false
		automatic_discard_state.started = true

		return
	end

	automatic_discard_state.token = automatic_discard_state.token + 1
	release_discard_transaction("automatic")
	automatic_discard_state.elapsed = 0
	automatic_discard_state.fetch_attempts = 0
	automatic_discard_state.hub_character_id = nil
	automatic_discard_state.scheduled = false
	automatic_discard_state.started = false
end

Features.update_morningstar_auto_discard = function(mod, dt)
	if not automatic_discard_enabled(mod) then
		if automatic_discard_state.scheduled or automatic_discard_state.started or automatic_discard_state.hub_character_id or discard_transaction.owner == "automatic" then
			Features.cancel_morningstar_auto_discard()
		end

		return
	end

	local game_mode_name = current_game_mode_name()

	if not game_mode_name then
		return
	end

	if not is_morningstar() then
		if automatic_discard_state.scheduled or automatic_discard_state.started or automatic_discard_state.hub_character_id then
			Features.cancel_morningstar_auto_discard(true)
		end

		return
	end

	local player, character_id = current_player_and_character()

	if not player or not character_id then
		return
	end

	-- DMF normally arms the pass through GameplayStateRun. Also observe the live
	-- hub and character identity so hot reloads and unusual state transition
	-- orders cannot silently leave Automatic mode dormant.
	if automatic_discard_state.hub_character_id ~= character_id then
		automatic_discard_state.token = automatic_discard_state.token + 1
		automatic_discard_state.elapsed = 0
		automatic_discard_state.fetch_attempts = 0
		automatic_discard_state.hub_character_id = character_id
		automatic_discard_state.scheduled = true
		automatic_discard_state.started = false
		automatic_discard_info(mod, "Scheduled one pass after detecting a ready Morningstar character.")
	end

	if not automatic_discard_state.scheduled or automatic_discard_state.started then
		return
	end

	automatic_discard_state.elapsed = automatic_discard_state.elapsed + (tonumber(dt) or 0)

	if automatic_discard_state.elapsed < AUTOMATIC_DISCARD_DELAY then
		return
	end

	local progression_manager = Managers and Managers.progression

	if progression_manager and type(progression_manager.is_fetching_session_report) == "function" and progression_manager:is_fetching_session_report() then
		-- Mission rewards are added while Darktide parses the end-of-round report.
		-- Do not take the one-shot inventory snapshot until that transaction has
		-- completed and the game's reward path has invalidated its gear cache.
		automatic_discard_state.elapsed = 0
		automatic_discard_info(mod, "Waiting for the mission reward report before scanning inventory.")

		return
	end

	local gear_service = Managers and Managers.data_service and Managers.data_service.gear

	if not gear_service or type(gear_service.fetch_inventory) ~= "function" then
		return
	end

	local token = automatic_discard_state.token

	automatic_discard_state.started = true
	automatic_discard_state.fetch_attempts = automatic_discard_state.fetch_attempts + 1

	-- Force the first automatic scan to use the current backend gear list. This
	-- includes an item awarded by the mission that just returned the player to
	-- the Morningstar, even if another system populated the cache beforehand.
	if type(gear_service.invalidate_gear_cache) == "function" then
		gear_service:invalidate_gear_cache()
	end

	automatic_discard_info(mod, string.format("Starting inventory scan attempt %d.", automatic_discard_state.fetch_attempts))
	local fetch_promise, fetch_error = fetch_inventory_promise(gear_service, character_id)

	if not fetch_promise then
		automatic_discard_state.started = false
		automatic_discard_state.elapsed = 0
		automatic_discard_state.scheduled = automatic_discard_state.fetch_attempts < AUTOMATIC_DISCARD_MAX_FETCH_ATTEMPTS
		automatic_discard_info(mod, "Inventory scan could not start; scheduling a bounded retry. Reason: " .. automatic_discard_error(fetch_error))
		return
	end

	fetch_promise:next(function(items)
		if not automatic_context_is_current(mod, token, character_id) then
			return
		end

		if type(items) ~= "table" then
			automatic_discard_info(mod, "Inventory scan returned no item table; scheduling a bounded retry.")
			automatic_discard_state.started = false
			automatic_discard_state.elapsed = 0
			automatic_discard_state.scheduled = automatic_discard_state.fetch_attempts < AUTOMATIC_DISCARD_MAX_FETCH_ATTEMPTS

			return
		end

		automatic_discard_state.scheduled = false
		local protection, protection_error = automatic_protection_snapshot(character_id)

		if not protection then
			automatic_discard_info(mod, "Inventory scan stopped safely because " .. automatic_discard_error(protection_error) .. "; scheduling a bounded retry.")
			automatic_discard_state.started = false
			automatic_discard_state.elapsed = 0
			automatic_discard_state.scheduled = automatic_discard_state.fetch_attempts < AUTOMATIC_DISCARD_MAX_FETCH_ATTEMPTS

			return
		end

		local candidates, excluded_errors, first_error = quick_discard_candidates_from_items_detailed(mod, items, protection.equipped_gear_ids, nil, protection.favorite_gear_ids)

		if excluded_errors > 0 then
			automatic_discard_info(mod, string.format("Safety-excluded %d unreadable item(s). First error: %s", excluded_errors, automatic_discard_error(first_error)))
		end

		automatic_discard_info(mod, string.format("Inventory scan found %d eligible candidate(s).", #candidates))

		if #candidates > 0 then
			present_automatic_discard(mod, token, character_id, candidates)
		else
			local displayed = show_automatic_no_candidates_notification(mod)
			automatic_discard_info(mod, displayed and "Displayed the no-eligible-items notification." or "Suppressed the no-eligible-items notification.")
		end
	end):catch(function(error_value)
		automatic_discard_info(mod, "Inventory scan failed; scheduling a bounded retry. Reason: " .. automatic_discard_error(error_value))
		if automatic_discard_state.token == token then
			automatic_discard_state.started = false
			automatic_discard_state.elapsed = 0
			automatic_discard_state.scheduled = automatic_discard_state.fetch_attempts < AUTOMATIC_DISCARD_MAX_FETCH_ATTEMPTS
		end
	end)
end

local function rendered_weapon_stats_height(weapon_stats)
	local scenegraph = weapon_stats and weapon_stats._ui_scenegraph
	local background_pivot = scenegraph and scenegraph.grid_background_pivot
	local background = scenegraph and scenegraph.grid_background
	local divider = scenegraph and scenegraph.grid_divider_bottom
	local weapon_divider = scenegraph and scenegraph.grid_divider_bottom_weapon

	if not background_pivot or not background or not divider then
		return
	end

	local background_pivot_y = background_pivot.position and background_pivot.position[2]
	local background_y = background.position and background.position[2]
	local background_height = background.size and background.size[2]
	local divider_y = divider.position and divider.position[2]
	local divider_height = divider.size and divider.size[2]

	if type(background_pivot_y) ~= "number" or type(background_y) ~= "number" or type(background_height) ~= "number" or type(divider_y) ~= "number" or type(divider_height) ~= "number" then
		return
	end

	local rendered_height = background_pivot_y + background_y + background_height - divider_height + divider_y

	if weapon_divider then
		local weapon_divider_y = weapon_divider.position and weapon_divider.position[2] or 0
		local weapon_divider_height = weapon_divider.size and weapon_divider.size[2]

		if type(weapon_divider_height) == "number" then
			rendered_height = rendered_height + (divider_height - weapon_divider_height) * 0.5 + weapon_divider_y + weapon_divider_height
		else
			rendered_height = rendered_height + divider_height
		end
	else
		rendered_height = rendered_height + divider_height
	end

	if rendered_height > 0 then
		return rendered_height
	end
end

local function set_inventory_sort_toggle_position(view, position, x, y)
	if position[1] == x and position[2] == y then
		return
	end

	if type(view._set_scenegraph_position) == "function" then
		view:_set_scenegraph_position(INVENTORY_SORT_TOGGLE_ID, x, y)
	else
		position[1] = x
		position[2] = y
		view._update_scenegraph = true
	end
end

local function weapon_stats_content_height(view, fallback_height)
	local weapon_stats = view and view._weapon_stats
	local menu_settings = weapon_stats and weapon_stats._menu_settings
	local grid_size = menu_settings and menu_settings.grid_size
	local content_height = rendered_weapon_stats_height(weapon_stats)

	if not content_height and weapon_stats and type(weapon_stats.grid_length) == "function" then
		local grid_length = weapon_stats:grid_length()

		if type(grid_length) == "number" and grid_length > 0 then
			content_height = grid_length + 35
		end
	end

	return content_height or grid_size and grid_size[2] or fallback_height
end

local function set_inventory_control_position(view, scenegraph_id, x, y)
	local scenegraph = view._ui_scenegraph
	local node = scenegraph and scenegraph[scenegraph_id]
	local position = node and node.position

	if not position or position[1] == x and position[2] == y then
		return
	end

	if type(view._set_scenegraph_position) == "function" then
		view:_set_scenegraph_position(scenegraph_id, x, y)
	else
		position[1] = x
		position[2] = y
		view._update_scenegraph = true
	end
end

local function set_inventory_widget_visible(view, scenegraph_id, visible)
	local widget = view._widgets_by_name and view._widgets_by_name[scenegraph_id]
	local content = widget and widget.content

	if content then
		content.visible = visible
	end
end

local function set_quick_discard_widgets_visible(view, visible)
	for index = 1, #INVENTORY_DISCARD_WIDGET_IDS do
		set_inventory_widget_visible(view, INVENTORY_DISCARD_WIDGET_IDS[index], visible)
	end
end

local function set_legacy_inventory_options_visible(view, visible)
	set_inventory_widget_visible(view, INVENTORY_SORT_LABEL_ID, visible)
	set_inventory_widget_visible(view, INVENTORY_SORT_TOGGLE_ID, visible)
	set_quick_discard_widgets_visible(view, visible)
end

local function set_options_panel_visible(view, panel, visible)
	if view._better_inventory_options_panel_visible ~= visible then
		view._better_inventory_options_panel_visible = visible

		if type(panel.disable_input) == "function" then
			panel:disable_input(not visible)
		end

		panel:set_visibility(visible)
	end
end

local function update_inventory_options_panel(mod, layout, view, slot_kind)
	local panel = view._better_inventory_options_panel

	if not panel or mod:get("enable_inventory_options_panel_prototype") ~= true then
		if panel then
			set_options_panel_visible(view, panel, false)
		end

		return false
	end

	-- Weapon Filter owns the same right-side interaction region while its panel
	-- is open. Its public implementation hides Darktide's weapon-options element,
	-- but BetterInventory's separately owned grid is not part of that element.
	-- Follow the live view state so both panels never draw or accept input at once;
	-- returning true also keeps the legacy BetterInventory widgets hidden.
	if view._filter_panel_element and view._show_filter_panel == true then
		set_legacy_inventory_options_visible(view, false)
		set_options_panel_visible(view, panel, false)

		return true
	end

	set_legacy_inventory_options_visible(view, false)
	set_options_panel_visible(view, panel, true)

	if view._better_inventory_options_panel_structure_key ~= panel_structure_key(mod, view) then
		rebuild_inventory_options_panel(mod, layout, view)
	end

	local native_discard_active = view._discard_items_element ~= nil
	local relative_x
	local relative_y
	local parent_id = slot_kind == "curio" and "weapon_stats_pivot" or "weapon_compare_stats_pivot"
	local absolute_x
	local absolute_y

	if native_discard_active then
		local discard_rect = scenegraph_rect(view._discard_items_element, "window")

		if discard_rect then
			-- The native filter window is the only stable free column in discard
			-- mode. Align with its left edge and follow its live bottom so the
			-- BetterInventory panel cannot cover item details or Discard Items.
			absolute_x = discard_rect.x
			absolute_y = discard_rect.y + discard_rect.height + INVENTORY_OPTIONS_PANEL_BUTTON_GAP
		else
			-- Keep the established fallback for the brief setup frame before the
			-- item-grid scenegraph has resolved.
			local expansion = tonumber(view._better_inventory_grid_expansion) or 0

			parent_id = slot_kind == "curio" and "weapon_stats_pivot" or "weapon_compare_stats_pivot"
			relative_x = slot_kind == "curio" and 0 or -566 - expansion
			relative_y = weapon_stats_content_height(view, 660) + 15
		end
	elseif slot_kind == "curio" then
		relative_x = 0
		relative_y = weapon_stats_content_height(view, 480) + 15
	else
		local weapon_stats = view._weapon_stats
		local weapon_stats_pivot = weapon_stats and weapon_stats._pivot_offset
		local weapon_stats_x = weapon_stats_pivot and tonumber(weapon_stats_pivot[1])
		local weapon_stats_width
		local weapon_options = view._weapon_options_element
		local menu_settings = weapon_options and weapon_options._menu_settings
		local grid_size = menu_settings and menu_settings.grid_size
		local native_pivot = weapon_options and weapon_options._pivot_offset
		local native_y = native_pivot and tonumber(native_pivot[2])
		local native_x = native_pivot and tonumber(native_pivot[1])

		if weapon_stats and type(weapon_stats._scenegraph_size) == "function" then
			local size_success, width = pcall(weapon_stats._scenegraph_size, weapon_stats, "grid_background")

			if size_success then
				weapon_stats_width = tonumber(width)
			end
		end

		if weapon_stats_x and weapon_stats_width and weapon_stats_width > 0 and native_y and native_x and (native_x ~= 0 or native_y ~= 0) then
			-- Horizontal and vertical placement intentionally use different live
			-- siblings: stay to the right of the weapon-information rectangle and
			-- below Darktide's Marks/Cosmetics/Inspect button rectangle.
			absolute_x = weapon_stats_x + weapon_stats_width + INVENTORY_OPTIONS_PANEL_WEAPON_GAP
			absolute_y = native_y + (grid_size and grid_size[2] or 300) + INVENTORY_OPTIONS_PANEL_BUTTON_GAP
		else
			-- Preserve the old pivot contract only during the brief startup window
			-- before both live sibling rectangles are available.
			relative_x = 20
			relative_y = (grid_size and grid_size[2] or 300) + INVENTORY_OPTIONS_PANEL_BUTTON_GAP
		end
	end

	local success = absolute_x ~= nil and absolute_y ~= nil
	local parent_position

	if not success then
		success, parent_position = pcall(view._scenegraph_world_position, view, parent_id)
	end

	if success and (parent_position or absolute_x) then
		local pivot_x = absolute_x or parent_position[1] + relative_x
		local pivot_y = absolute_y or parent_position[2] + relative_y

		if view._better_inventory_options_panel_pivot_x ~= pivot_x or view._better_inventory_options_panel_pivot_y ~= pivot_y then
			view._better_inventory_options_panel_pivot_x = pivot_x
			view._better_inventory_options_panel_pivot_y = pivot_y
			panel:set_pivot_offset(pivot_x, pivot_y)
		end
	else
		-- A future game update can invalidate the pivot contract. Hide the prototype
		-- and restore the proven loose-widget implementation for this view.
		set_options_panel_visible(view, panel, false)
		set_legacy_inventory_options_visible(view, true)

		return false
	end

	return true
end

local function update_quick_discard_content(mod, slot_kind, view, base_y)
	local widgets = view._widgets_by_name
	local label_widget = widgets and widgets[INVENTORY_DISCARD_LABEL_ID]
	local mode_widget = widgets and widgets[INVENTORY_DISCARD_MODE_ID]
	local skip_confirmation_widget = widgets and widgets[INVENTORY_DISCARD_SKIP_CONFIRMATION_ID]
	local discard_widget = widgets and widgets[INVENTORY_QUICK_DISCARD_ID]
	local max_level_widget = widgets and widgets[INVENTORY_DISCARD_MAX_LEVEL_ID]
	local melee_widget = widgets and widgets[INVENTORY_DISCARD_MELEE_ID]
	local ranged_widget = widgets and widgets[INVENTORY_DISCARD_RANGED_ID]
	local curio_widget = widgets and widgets[INVENTORY_DISCARD_CURIO_ID]
	local protection_widget = widgets and widgets[INVENTORY_DISCARD_PROTECTION_ID]
	local curio_protection_widget = widgets and widgets[INVENTORY_DISCARD_CURIO_PROTECTION_ID]
	local curio_level_widget = widgets and widgets[INVENTORY_DISCARD_CURIO_LEVEL_ID]

	if not discard_widget then
		return
	end

	local discard_mode = mod:get("quick_discard_mode") == "automatic" and "automatic" or "manual"
	local discard_heading_mode = discard_mode == "automatic" and "automated" or "manual"
	local mode_changed = view._better_inventory_legacy_discard_mode ~= discard_mode

	if mode_changed and label_widget then
		label_widget.content.label = mod:localize("inventory_" .. discard_heading_mode .. "_discard_management_inventory_label")
	end

	if mode_changed and mode_widget then
		mode_widget.content.value = mod:localize("quick_discard_mode_" .. discard_mode) .. "  ›"
	end

	view._better_inventory_legacy_discard_mode = discard_mode

	if skip_confirmation_widget then
		skip_confirmation_widget.content.checked = mod:get("quick_discard_skip_automatic_confirmation") == true
		skip_confirmation_widget.content.visible = discard_mode == "automatic"
	end

	local rarity = math.clamp(math.floor(tonumber(mod:get("quick_discard_rarity")) or 1), 1, 5)
	local discard_content = discard_widget.content

	if discard_content.better_inventory_rarity ~= rarity then
		local rarity_settings = RaritySettings[rarity]
		local rarity_color = rarity_settings and rarity_settings.color or Color.terminal_text_body(255, true)

		discard_content.better_inventory_rarity = rarity
		discard_content.rarity_label = mod:localize("quick_discard_rarity_" .. rarity) .. "  ›"

		if discard_widget.style and discard_widget.style.rarity_label then
			discard_widget.style.rarity_label.text_color = table.clone(rarity_color)
		end
	end

	if max_level_widget then
		local value = math.clamp(math.floor(tonumber(mod:get("quick_discard_max_item_level")) or 490), 0, 500)

		if max_level_widget.content.better_inventory_value ~= value then
			max_level_widget.content.better_inventory_value = value
			max_level_widget.content.value = tostring(value)
		end
	end

	if melee_widget then
		melee_widget.content.checked = mod:get("quick_discard_include_melee") ~= false
	end

	if ranged_widget then
		ranged_widget.content.checked = mod:get("quick_discard_include_ranged") ~= false
	end

	if curio_widget then
		curio_widget.content.checked = mod:get("quick_discard_include_curios") ~= false
	end

	local protection_content = protection_widget and protection_widget.content
	local curio_protection_content = curio_protection_widget and curio_protection_widget.content

	if protection_content then
		protection_content.checked = mod:get("quick_discard_protect_perfect_weapons") ~= false
	end

	if curio_protection_content then
		curio_protection_content.checked = mod:get("quick_discard_protect_high_level_curios") ~= false
	end

	if curio_level_widget then
		local value = math.clamp(math.floor(tonumber(mod:get("quick_discard_curio_protection_level")) or 410), 0, 500)

		if curio_level_widget.content.better_inventory_value ~= value then
			curio_level_widget.content.better_inventory_value = value
			curio_level_widget.content.value = tostring(value)
		end

		curio_level_widget.content.visible = mod:get("quick_discard_protect_high_level_curios") ~= false
	end

	local is_curio_view = slot_kind == "curio"
	local x = is_curio_view and 0 or 20
	local width = is_curio_view and 530 or 420
	local compact_x = x + 15
	local control_width = is_curio_view and 420 or width
	local compact_width = control_width - 15
	local type_gap = 8
	local type_width = math.floor((compact_width - type_gap * 2) / 3)
	local mode_width = 190

	set_inventory_control_position(view, INVENTORY_DISCARD_LABEL_ID, x, base_y + 70)
	set_inventory_control_position(view, INVENTORY_DISCARD_MODE_ID, compact_x, base_y + 100)
	set_inventory_control_position(view, INVENTORY_DISCARD_SKIP_CONFIRMATION_ID, compact_x + mode_width + 10, base_y + 100)
	set_inventory_control_position(view, INVENTORY_QUICK_DISCARD_ID, compact_x, base_y + 136)
	set_inventory_control_position(view, INVENTORY_DISCARD_MAX_LEVEL_ID, compact_x, base_y + 172)
	set_inventory_control_position(view, INVENTORY_DISCARD_MELEE_ID, compact_x, base_y + 206)
	set_inventory_control_position(view, INVENTORY_DISCARD_RANGED_ID, compact_x + type_width + type_gap, base_y + 206)
	set_inventory_control_position(view, INVENTORY_DISCARD_CURIO_ID, compact_x + (type_width + type_gap) * 2, base_y + 206)
	set_inventory_control_position(view, INVENTORY_DISCARD_PROTECTION_ID, compact_x, base_y + 240)
	set_inventory_control_position(view, INVENTORY_DISCARD_CURIO_PROTECTION_ID, compact_x, base_y + 274)
	set_inventory_control_position(view, INVENTORY_DISCARD_CURIO_LEVEL_ID, compact_x, base_y + 308)
end

Features.update_inventory_sort_toggle = function(mod, layout, view)
	local slot_kind = inventory_slot_kind(layout, view)

	if not slot_kind then
		return
	end

	if mod:get("show_inventory_options_widget") == false then
		local panel = view._better_inventory_options_panel

		set_legacy_inventory_options_visible(view, false)

		if panel then
			set_options_panel_visible(view, panel, false)
		end

		Features.release_lantern_inventory_section(view)

		return
	end

	Features.update_lantern_inventory_section(mod, view)

	if update_inventory_options_panel(mod, layout, view, slot_kind) then
		return
	end

	local widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_SORT_TOGGLE_ID]
	local content = widget and widget.content

	if content then
		content.checked = mod:get("prioritize_equipped_favorites") ~= false
	end

	local native_discard_active = view._discard_items_element ~= nil

	set_inventory_widget_visible(view, INVENTORY_SORT_LABEL_ID, true)
	set_inventory_widget_visible(view, INVENTORY_SORT_TOGGLE_ID, true)
	set_quick_discard_widgets_visible(view, not native_discard_active)

	local scenegraph = view._ui_scenegraph
	local node = scenegraph and scenegraph[INVENTORY_SORT_TOGGLE_ID]
	local position = node and node.position

	if not position then
		return
	end

	if native_discard_active then
		local expansion = tonumber(view._better_inventory_grid_expansion) or 0
		local sort_x = slot_kind == "curio" and 0 or -566 - expansion
		local sort_y = weapon_stats_content_height(view, 660) + 15

		set_inventory_control_position(view, INVENTORY_SORT_LABEL_ID, sort_x, sort_y)
		set_inventory_sort_toggle_position(view, position, sort_x + 15, sort_y + 28)

		return
	end

	if slot_kind == "curio" then
		local y = weapon_stats_content_height(view, 480) + 15

		set_inventory_control_position(view, INVENTORY_SORT_LABEL_ID, 0, y)
		set_inventory_sort_toggle_position(view, position, 15, y + 28)
		update_quick_discard_content(mod, slot_kind, view, y)
	else
		local menu_settings = view._weapon_options_element and view._weapon_options_element._menu_settings
		local grid_size = menu_settings and menu_settings.grid_size

		local y = (grid_size and grid_size[2] or 300) + 15

		set_inventory_control_position(view, INVENTORY_SORT_LABEL_ID, 20, y)
		set_inventory_sort_toggle_position(view, position, 35, y + 28)
		update_quick_discard_content(mod, slot_kind, view, y)
	end
end

Features.sync_inventory_sort_setting = function(mod, layout)
	local enabled = mod:get("prioritize_equipped_favorites") ~= false
	local perfect_rolls_enabled = mod:get("prioritize_perfect_roll_weapons") == true

	for view in pairs(registered_inventory_views) do
		local widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_SORT_TOGGLE_ID]
		local panel_widget = view._better_inventory_options_panel_widgets and view._better_inventory_options_panel_widgets[INVENTORY_SORT_TOGGLE_ID]
		local perfect_panel_widget = view._better_inventory_options_panel_widgets and view._better_inventory_options_panel_widgets[INVENTORY_PERFECT_SORT_TOGGLE_ID]
		local content = widget and widget.content
		local panel_content = panel_widget and panel_widget.content
		local perfect_panel_content = perfect_panel_widget and perfect_panel_widget.content

		if content then
			content.checked = enabled
		end

		if panel_content then
			panel_content.checked = enabled
		end

		if perfect_panel_content then
			perfect_panel_content.checked = perfect_rolls_enabled
		end

		Features.resort_inventory(mod, layout, view)
	end

	for view in pairs(registered_armoury_views) do
		Features.resort_inventory(mod, layout, view)
	end
end

Features.sync_quick_discard_settings = function(mod, layout, deferred_view)
	for view in pairs(registered_inventory_views) do
		if not view._destroyed and view ~= deferred_view then
			Features.update_inventory_sort_toggle(mod, layout, view)
		end
	end
end

Features.sync_curio_acquisition_settings = function(mod, layout, deferred_view)
	for view in pairs(registered_inventory_views) do
		if not view._destroyed and view ~= deferred_view then
			Features.update_inventory_sort_toggle(mod, layout, view)
		end
	end
end

Features.bind_inventory_sort_toggle = function(mod, layout, view)
	if not is_inventory_view(layout, view) then
		return
	end

	local widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_SORT_TOGGLE_ID]
	local content = widget and widget.content
	local hotspot = content and content.hotspot

	if not hotspot then
		return
	end

	registered_inventory_views[view] = true
	Features.update_inventory_sort_toggle(mod, layout, view)
	hotspot.pressed_callback = function()
		local enabled = not content.checked

		mod:set("prioritize_equipped_favorites", enabled, false)
		Features.sync_inventory_sort_setting(mod, layout)
	end

	local discard_widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_QUICK_DISCARD_ID]
	local mode_widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_DISCARD_MODE_ID]
	local mode_hotspot = mode_widget and mode_widget.content and mode_widget.content.hotspot
	local skip_confirmation_widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_DISCARD_SKIP_CONFIRMATION_ID]
	local skip_confirmation_content = skip_confirmation_widget and skip_confirmation_widget.content
	local skip_confirmation_hotspot = skip_confirmation_content and skip_confirmation_content.hotspot
	local discard_content = discard_widget and discard_widget.content
	local rarity_hotspot = discard_content and discard_content.rarity_hotspot
	local discard_hotspot = discard_content and discard_content.discard_hotspot

	if rarity_hotspot then
		rarity_hotspot.pressed_callback = function()
			local rarity = math.clamp(math.floor(tonumber(mod:get("quick_discard_rarity")) or 1), 1, 5)

			mod:set("quick_discard_rarity", rarity % 5 + 1, false)
			Features.sync_quick_discard_settings(mod, layout)
		end
	end

	if mode_hotspot then
		mode_hotspot.pressed_callback = function()
			local mode = mod:get("quick_discard_mode") == "automatic" and "manual" or "automatic"

			mod:set("quick_discard_mode", mode, false)
			Features.sync_quick_discard_settings(mod, layout)
		end
	end

	if skip_confirmation_hotspot then
		skip_confirmation_hotspot.pressed_callback = function()
			if mod:get("quick_discard_mode") == "automatic" then
				mod:set("quick_discard_skip_automatic_confirmation", not skip_confirmation_content.checked, false)
				Features.sync_quick_discard_settings(mod, layout)
			end
		end
	end

	if discard_hotspot then
		discard_hotspot.pressed_callback = function()
			Features.request_quick_discard(mod, layout, view)
		end
	end

	local function bind_checkbox(scenegraph_id, setting_id)
		local setting_widget = view._widgets_by_name and view._widgets_by_name[scenegraph_id]
		local setting_content = setting_widget and setting_widget.content
		local setting_hotspot = setting_content and setting_content.hotspot

		if setting_hotspot then
			setting_hotspot.pressed_callback = function()
				mod:set(setting_id, not setting_content.checked, false)
				Features.sync_quick_discard_settings(mod, layout)
			end
		end
	end

	local function bind_stepper(scenegraph_id, setting_id)
		local setting_widget = view._widgets_by_name and view._widgets_by_name[scenegraph_id]
		local setting_content = setting_widget and setting_widget.content
		local decrease_hotspot = setting_content and setting_content.decrease_hotspot
		local increase_hotspot = setting_content and setting_content.increase_hotspot
		local function change_value(delta)
			local value = math.clamp(math.floor(tonumber(mod:get(setting_id)) or 0) + delta, 0, 500)

			mod:set(setting_id, value, false)
			Features.sync_quick_discard_settings(mod, layout)
		end

		if decrease_hotspot then
			decrease_hotspot.pressed_callback = function()
				change_value(-10)
			end
		end

		if increase_hotspot then
			increase_hotspot.pressed_callback = function()
				change_value(10)
			end
		end
	end

	bind_stepper(INVENTORY_DISCARD_MAX_LEVEL_ID, "quick_discard_max_item_level")
	bind_checkbox(INVENTORY_DISCARD_MELEE_ID, "quick_discard_include_melee")
	bind_checkbox(INVENTORY_DISCARD_RANGED_ID, "quick_discard_include_ranged")
	bind_checkbox(INVENTORY_DISCARD_CURIO_ID, "quick_discard_include_curios")
	bind_checkbox(INVENTORY_DISCARD_PROTECTION_ID, "quick_discard_protect_perfect_weapons")
	bind_checkbox(INVENTORY_DISCARD_CURIO_PROTECTION_ID, "quick_discard_protect_high_level_curios")
	bind_stepper(INVENTORY_DISCARD_CURIO_LEVEL_ID, "quick_discard_curio_protection_level")
end

Features.unregister_inventory_view = function(view)
	registered_inventory_views[view] = nil
end

Features.unregister_armoury_view = function(view)
	registered_armoury_views[view] = nil
end

Features.disable_inventory_views = function()
	for view in pairs(registered_inventory_views) do
		restore_lantern_weapon_panel(view)
		local panel = view._better_inventory_options_panel

		if panel then
			set_options_panel_visible(view, panel, false)
		end

		set_legacy_inventory_options_visible(view, false)
	end

	for view in pairs(registered_armoury_views) do
		local panel = view._better_inventory_armoury_native_sort_panel

		if panel then
			panel:set_visibility(false)
		end
	end
end

return Features
