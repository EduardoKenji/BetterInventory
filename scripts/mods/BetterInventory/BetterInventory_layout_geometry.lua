local Text = require("scripts/utilities/ui/text")
local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")
local LayoutContent = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_content")
local Geometry = {}
local Cards = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_cards")
local content = LayoutContent

local global_store_character_photo_size = content.global_store_character_photo_size
local global_store_price_row_padding = content.global_store_price_row_padding
local global_store_character_info_gap = content.global_store_character_info_gap
local global_store_character_class_icon_size = content.global_store_character_class_icon_size
local global_store_character_name_font_size = content.global_store_character_name_font_size
local global_store_extra_height = content.global_store_extra_height
local setting = content.setting
local name_it_curio_title_enabled = content.name_it_curio_title_enabled
local curio_name_font_size = content.curio_name_font_size
local curio_name_title_height = content.curio_name_title_height
local numeric_setting = content.numeric_setting
local curio_primary_font_size = content.curio_primary_font_size
local curio_secondary_font_size = content.curio_secondary_font_size
local curio_primary_secondary_spacing = content.curio_primary_secondary_spacing
local blessing_icon_size = content.blessing_icon_size
local weapon_blessing_display_mode = content.weapon_blessing_display_mode
local separate_blessing_text_and_item_level = content.separate_blessing_text_and_item_level
local blessing_rank_name = content.blessing_rank_name
local weapon_perk_rank_icon_size = content.weapon_perk_rank_icon_size
local item_from_element = content.item_from_element
local item_from_content = content.item_from_content
local is_curio = content.is_curio
local is_weapon = content.is_weapon
local curio_primary_color = content.curio_primary_color
local compact_curio_description = content.compact_curio_description
local configured_text_color = content.configured_text_color
local single_line_text = content.single_line_text
local compact_weapon_perk_description = content.compact_weapon_perk_description
local leading_plus_sign_description = content.leading_plus_sign_description
local simplified_curio_description = content.simplified_curio_description
local pass_by_style_id = content.pass_by_style_id
local is_quick_look_card_pass = content.is_quick_look_card_pass
local has_quick_look_card_passes = content.has_quick_look_card_passes
local weapon_modifier_pass_kind_and_index = content.weapon_modifier_pass_kind_and_index
local populate_weapon_modifier_content = content.populate_weapon_modifier_content
local quick_look_card_grid_position = content.quick_look_card_grid_position
local add_quick_look_card_grid_pass = content.add_quick_look_card_grid_pass
local grid_ui_renderer = content.grid_ui_renderer
local format_item_name = content.format_item_name
local restore_item_customization_style = content.restore_item_customization_style
local apply_item_customization_style = content.apply_item_customization_style
local synchronize_rarity_tag_color = content.synchronize_rarity_tag_color
local WEAPON_PERK_COUNT = content.WEAPON_PERK_COUNT
local WEAPON_BLESSING_COUNT = content.WEAPON_BLESSING_COUNT
local BLESSING_TEXT_WIDTH_SAFETY_MARGIN = content.BLESSING_TEXT_WIDTH_SAFETY_MARGIN
local MINIMUM_AUTO_FIT_BLESSING_FONT_SIZE = content.MINIMUM_AUTO_FIT_BLESSING_FONT_SIZE
local WEAPON_MODIFIER_TITLE_PREFIX = content.WEAPON_MODIFIER_TITLE_PREFIX
local WEAPON_MODIFIER_VALUE_PREFIX = content.WEAPON_MODIFIER_VALUE_PREFIX
local QUICK_LOOK_CARD_HIGHLIGHT_COLOR = content.QUICK_LOOK_CARD_HIGHLIGHT_COLOR
local WEAPON_MODIFIER_TITLE_COLOR = content.WEAPON_MODIFIER_TITLE_COLOR
local WEAPON_MODIFIER_VALUE_COLOR = content.WEAPON_MODIFIER_VALUE_COLOR
local DEFAULT_CURIO_PRIMARY_COLOR = content.DEFAULT_CURIO_PRIMARY_COLOR
local DEFAULT_CURIO_SECONDARY_COLOR = content.DEFAULT_CURIO_SECONDARY_COLOR
local DEFAULT_WEAPON_PERK_COLOR = content.DEFAULT_WEAPON_PERK_COLOR
local DEFAULT_WEAPON_BLESSING_TEXT_COLOR = content.DEFAULT_WEAPON_BLESSING_TEXT_COLOR
local DEFAULT_ARMOURY_ITEM_LEVEL_COLOR = content.DEFAULT_ARMOURY_ITEM_LEVEL_COLOR
local SLOT_SETTING_BY_NAME = content.SLOT_SETTING_BY_NAME
local NATIVE_SINGLE_COLUMN_CONTENT_GAP = content.NATIVE_SINGLE_COLUMN_CONTENT_GAP
local COLUMN_SETTING_BY_SLOT = content.COLUMN_SETTING_BY_SLOT
local GLOBAL_STORE_CHARACTER_ROW_HEIGHT = content.GLOBAL_STORE_CHARACTER_ROW_HEIGHT
local GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_DEFAULT = content.GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_DEFAULT
local GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_DEFAULT = content.GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_DEFAULT
local GLOBAL_STORE_CHARACTER_NAME_FIT_SAFETY_MARGIN = content.GLOBAL_STORE_CHARACTER_NAME_FIT_SAFETY_MARGIN

Geometry.set_item_customization_provider = function(provider)
	content.set_item_customization_provider(provider)
	Cards.set_item_customization_provider(provider)
end

local configure_native_quick_look_card_passes = Cards.configure_native_quick_look_card_passes
local disable_quick_look_card_passes = Cards.disable_quick_look_card_passes
local preserve_visibility = Cards.preserve_visibility
local set_visibility = Cards.set_visibility
local set_height = Cards.set_height
local configure_native_card_geometry = Cards.configure_native_card_geometry
local configure_text_pass = Cards.configure_text_pass
local configure_favorite_marker = Cards.configure_favorite_marker
local configure_equipped_highlight = Cards.configure_equipped_highlight
local add_custom_content_passes = Cards.add_custom_content_passes
local grid_weapon_name_font_size = Cards.grid_weapon_name_font_size
local configure_card_content = Cards.configure_card_content

local INVENTORY_CANVAS_WIDTH = 1920
local INVENTORY_EDGE_MARGIN = 16
local WEAPON_ACTIONS_PANEL_WIDTH = 420
local WEAPON_STATS_PANEL_WIDTH = 530
local MINIMUM_CARD_WIDTH = 120
local MAXIMUM_WEAPON_EXTRA_WIDTH = 120
local ARMOURY_MINIMUM_CARD_WIDTH = 190
local ARMOURY_MAXIMUM_CARD_WIDTH = 230
local BLESSING_MATERIAL = "content/ui/materials/icons/traits/traits_container"
local DEFAULT_PERK_RANK_MATERIAL = "content/ui/materials/icons/perks/perk_level_01"
local DEFAULT_PERK_RANK_SIZE = 17
local DEFAULT_BLESSING_ICON_SIZE = 36
local PERK_RANK_GAP = 3
local STORE_FOOTER_HEIGHT = 34
-- Armoury-only native card geometry keeps modifier rows above the price footer.
local ARMOURY_NATIVE_CARD_HEIGHT_EXTRA = 16
local ARMOURY_NATIVE_FOOTER_GAP = 8
local ARMOURY_NATIVE_MODIFIER_HORIZONTAL_PERCENT = 62
local function slot_kind_from_slot_types(slot_types)
	if type(slot_types) ~= "table" then
		return
	end

	for _, slot_name in ipairs(slot_types) do
		if SLOT_SETTING_BY_NAME[slot_name] then
			return slot_name
		end

		if type(slot_name) == "string" and string.match(slot_name, "^slot_attachment_") then
			return "curio"
		end
	end
end

local function slot_kind_from_layout(layout)
	if type(layout) ~= "table" then
		return
	end

	for _, entry in ipairs(layout) do
		if type(entry) == "table" and not entry.is_external then
			local slots = entry.filter_slots or entry.item and entry.item.slots
			local slot_kind = slot_kind_from_slot_types(slots)

			if slot_kind then
				return slot_kind
			end
		end
	end
end

Geometry.slot_kind = function(view)
	local selected_slot = view and view._selected_slot
	local slot_name = selected_slot and selected_slot.name

	if SLOT_SETTING_BY_NAME[slot_name] then
		return slot_name
	end

	if type(slot_name) == "string" and string.match(slot_name, "^slot_attachment_") then
		return "curio"
	end
end

-- Tabbed item views may not expose `_selected_slot`; their category tabs carry
-- the native slot filter instead. Prefer the filtered layout (which is
-- available during both initial presentation and tab switches), then fall
-- back to the selected tab for empty categories.
Geometry.store_slot_kind = function(view, layout)
	local slot_kind = slot_kind_from_layout(layout)

	if slot_kind then
		return slot_kind
	end

	local tab_menu = view and view._tab_menu_element
	local definitions = view and view._definitions
	local tabs_content = view and view._tabs_content or definitions and definitions.item_category_tabs_content
	local selected_index = view and view._next_tab_index

	if not selected_index and tab_menu and type(tab_menu.selected_index) == "function" then
		selected_index = tab_menu:selected_index()
	end

	selected_index = selected_index or 1

	local tab_content = selected_index and tabs_content and tabs_content[selected_index]

	return slot_kind_from_slot_types(tab_content and tab_content.slot_types) or Geometry.slot_kind(view)
end

Geometry.is_enabled_for_view = function(mod, view)
	local slot_kind = Geometry.slot_kind(view)

	if slot_kind == "curio" then
		return setting(mod, "enable_curio_inventory", true)
	end

	local setting_id = SLOT_SETTING_BY_NAME[slot_kind]

	return setting_id and setting(mod, setting_id, true) or false
end

Geometry.columns = content.columns

Geometry.is_compound_shield_weapon = content.is_compound_shield_weapon

Geometry.equipped_compound_shield_requires_cap = function(mod, view, context)
	local selected_slot = view and view._selected_slot
	local slot_name = selected_slot and selected_slot.name
	local preview_items = context and context.preview_profile_equipped_items or view and view._preview_profile_equipped_items
	local equipped_item = slot_name and preview_items and preview_items[slot_name]

	equipped_item = equipped_item and (equipped_item.real_item or equipped_item.item or equipped_item)

	return Geometry.columns(mod, nil, slot_name) >= 4 and content.is_compound_shield_weapon(equipped_item)
end

Geometry.layout_contains_compound_shield = function(layout)
	if type(layout) ~= "table" then
		return false
	end

	for _, entry in pairs(layout) do
		if type(entry) == "table" and entry.is_external ~= true and content.is_compound_shield_weapon(content.item_from_element(entry)) then
			return true
		end
	end

	return false
end

Geometry.safe_inventory_maximum_columns = function(mod, maximum_columns, slot_kind, layout, guard_already_armed)
	local requested_columns = Geometry.columns(mod, maximum_columns, slot_kind)

	if requested_columns < 4 then
		return maximum_columns, false
	end

	if guard_already_armed == true or Geometry.layout_contains_compound_shield(layout) then
		-- The selected equipped item is consulted before ItemGridViewBase.init,
		-- while the fetched layout supplies a second check for unequipped shields.
		-- Capping here alone is too late for an equipped compound weapon because
		-- Darktide constructs preview state before presenting the fetched grid.
		return 3, true
	end

	return maximum_columns, false
end

local function weapon_extra_width_applies(mod, columns)
	local threshold = setting(mod, "weapon_extra_width_column_threshold", "four_plus")

	return columns >= (threshold == "five_only" and 5 or 4)
end

Geometry.grid_expansion = function(mod, current_grid_width, slot_kind)
	current_grid_width = tonumber(current_grid_width)

	if not current_grid_width or current_grid_width <= 0 then
		return 0
	end

	if not setting(mod, "enable_grid_layout", true) or not setting(mod, "expand_inventory_window", true) then
		return 0
	end

	local columns = Geometry.columns(mod, nil, slot_kind)
	local spacing = numeric_setting(mod, "grid_spacing", 10, 0, 40)
	local target_card_width = MINIMUM_CARD_WIDTH

	if slot_kind == "curio" and setting(mod, "expand_curio_inventory_window", true) then
		target_card_width = numeric_setting(mod, "curio_target_card_width", 190, MINIMUM_CARD_WIDTH, 220)
	end

	local required_grid_width = target_card_width * columns + spacing * (columns - 1)
	local required_expansion = math.max(0, required_grid_width - current_grid_width)

	if slot_kind ~= "curio" and weapon_extra_width_applies(mod, columns) then
		local extra_width = numeric_setting(mod, "five_column_weapon_extra_width", 80, 0, MAXIMUM_WEAPON_EXTRA_WIDTH)

		required_expansion = required_expansion + extra_width
	end

	return required_expansion
end

Geometry.armoury_grid_expansion = function(mod, current_grid_width, grid_setting_id, slot_kind)
	current_grid_width = tonumber(current_grid_width)
	grid_setting_id = grid_setting_id or "enable_armoury_requisition_grid"

	if not current_grid_width or current_grid_width <= 0 then
		return 0
	end

	if not setting(mod, "enable_grid_layout", true) or not setting(mod, grid_setting_id, true) or not setting(mod, "expand_armoury_requisition_window", true) then
		return 0
	end

	local columns = Geometry.columns(mod, 3, slot_kind)
	local spacing = numeric_setting(mod, "grid_spacing", 10, 0, 40)
	local target_card_width = numeric_setting(mod, "armoury_requisition_target_card_width", 230, ARMOURY_MINIMUM_CARD_WIDTH, ARMOURY_MAXIMUM_CARD_WIDTH)
	local required_grid_width = target_card_width * columns + spacing * (columns - 1)

	return math.max(0, required_grid_width - current_grid_width)
end

local function maximum_safe_inventory_expansion(definitions, slot_kind)
	local scenegraph = definitions and definitions.scenegraph_definition
	local canvas = scenegraph and scenegraph.canvas
	local canvas_size = canvas and canvas.size
	local canvas_width = canvas_size and canvas_size[1] or INVENTORY_CANVAS_WIDTH
	local panel_id = slot_kind == "curio" and "weapon_stats_pivot" or "weapon_actions_pivot"
	local panel_width = slot_kind == "curio" and WEAPON_STATS_PANEL_WIDTH or WEAPON_ACTIONS_PANEL_WIDTH
	local panel = scenegraph and scenegraph[panel_id]
	local panel_position = panel and panel.position
	local panel_x = panel_position and panel_position[1]

	if type(canvas_width) ~= "number" or type(panel_x) ~= "number" then
		-- A changed scenegraph contract means there is no trustworthy screen-edge
		-- clamp. Preserve native width instead of risking an off-screen panel.
		return 0
	end

	local panel_anchor_x

	if panel.horizontal_alignment == "right" then
		panel_anchor_x = canvas_width + panel_x
	else
		panel_anchor_x = panel_x
	end

	local available_expansion = canvas_width - INVENTORY_EDGE_MARGIN - (panel_anchor_x + panel_width)

	return math.max(0, available_expansion)
end

local function debug_width_adjustment(mod, current_width, resolved_expansion, enabled_setting_id, percent_setting_id)
	if not setting(mod, enabled_setting_id, false) then
		return resolved_expansion
	end

	local percent = math.max(-50, math.min(100, tonumber(setting(mod, percent_setting_id, 30)) or 30))
	local resolved_width = current_width + resolved_expansion
	local adjusted_width = math.max(1, math.floor(resolved_width * (1 + percent * 0.01) + 0.5))

	return adjusted_width - current_width
end

Geometry.expanded_armoury_view_definitions = function(mod, definitions, base_definitions, grid_setting_id, slot_kind)
	local grid_settings = definitions and definitions.grid_settings
	local grid_size = grid_settings and grid_settings.grid_size
	local current_grid_width = grid_size and grid_size[1]

	if type(current_grid_width) ~= "number" or current_grid_width <= 0 then
		return definitions, 0
	end

	local native_armoury = grid_setting_id == nil
	local expansion = Geometry.armoury_grid_expansion(mod, current_grid_width, grid_setting_id, slot_kind)

	if native_armoury and setting(mod, "debug_expand_armoury_requisition_window_30_percent", false) then
		local resolved_grid_width = current_grid_width + expansion
		local debug_percent = math.max(10, math.min(100, tonumber(setting(mod, "debug_armoury_requisition_window_increase_percent", 30)) or 30))
		local debug_grid_width = math.floor(resolved_grid_width * (1 + debug_percent * 0.01) + 0.5)

		expansion = math.max(expansion, debug_grid_width - current_grid_width)
	elseif grid_setting_id == "enable_global_store_grid" then
		expansion = debug_width_adjustment(mod, current_grid_width, expansion, "debug_adjust_global_store_window_width", "debug_global_store_window_width_adjustment_percent")
	end

	if expansion == 0 then
		return definitions, 0
	end

	local adjusted_definitions = table.clone(definitions)
	local adjusted_grid_settings = adjusted_definitions.grid_settings

	adjusted_grid_settings.grid_size[1] = adjusted_grid_settings.grid_size[1] + expansion

	if adjusted_grid_settings.mask_size and adjusted_grid_settings.mask_size[1] then
		adjusted_grid_settings.mask_size[1] = adjusted_grid_settings.mask_size[1] + expansion
	end

	local scenegraph = adjusted_definitions.scenegraph_definition
	local base_scenegraph = base_definitions and base_definitions.scenegraph_definition

	if scenegraph then
		local item_grid_pivot = scenegraph.item_grid_pivot
		local pivot_size = item_grid_pivot and item_grid_pivot.size

		if pivot_size and pivot_size[1] then
			pivot_size[1] = pivot_size[1] + expansion
		end

		for _, scenegraph_id in ipairs({
			"weapon_stats_pivot",
			"weapon_compare_stats_pivot",
			"purchase_button",
		}) do
			local node = scenegraph[scenegraph_id]

			if not node and base_scenegraph and base_scenegraph[scenegraph_id] then
				node = table.clone(base_scenegraph[scenegraph_id])
				scenegraph[scenegraph_id] = node
			end

			local position = node and node.position

			if position and position[1] then
				position[1] = position[1] + expansion
			end
		end
	end

	return adjusted_definitions, expansion
end

Geometry.expanded_global_store_view_definitions = function(mod, definitions, base_definitions, slot_kind)
	return Geometry.expanded_armoury_view_definitions(mod, definitions, base_definitions, "enable_global_store_grid", slot_kind)
end

Geometry.expanded_view_definitions = function(mod, definitions, view)
	local grid_settings = definitions and definitions.grid_settings
	local grid_size = grid_settings and grid_settings.grid_size
	local current_grid_width = grid_size and grid_size[1]

	if type(current_grid_width) ~= "number" or current_grid_width <= 0 then
		return definitions, 0
	end

	if view and view._better_inventory_compound_shield_column_cap == true then
		-- Keep every scenegraph node on native three-column geometry when the
		-- equipped shield armed the guard before ItemGridViewBase.init.
		return definitions, 0
	end

	local slot_kind = Geometry.slot_kind(view)
	local requested_expansion = Geometry.grid_expansion(mod, current_grid_width, slot_kind)
	local safe_expansion = maximum_safe_inventory_expansion(definitions, slot_kind)
	local expansion = math.min(requested_expansion, safe_expansion)

	expansion = debug_width_adjustment(mod, current_grid_width, expansion, "debug_adjust_inventory_window_width", "debug_inventory_window_width_adjustment_percent")

	if expansion == 0 then
		return definitions, 0
	end

	local adjusted_definitions = table.clone(definitions)
	local adjusted_grid_settings = adjusted_definitions.grid_settings

	adjusted_grid_settings.grid_size[1] = adjusted_grid_settings.grid_size[1] + expansion

	if adjusted_grid_settings.mask_size and adjusted_grid_settings.mask_size[1] then
		adjusted_grid_settings.mask_size[1] = adjusted_grid_settings.mask_size[1] + expansion
	end

	local scenegraph = adjusted_definitions.scenegraph_definition

	if scenegraph then
		for _, scenegraph_id in ipairs({
			"weapon_stats_pivot",
			"weapon_compare_stats_pivot",
			"weapon_actions_pivot",
			"equip_button",
			"weapon_discard_pivot",
		}) do
			local node = scenegraph[scenegraph_id]
			local position = node and node.position

			if position and position[1] then
				position[1] = position[1] + expansion
			end
		end
	end

	return adjusted_definitions, expansion
end

Geometry.card_height = function(mod, configuration)
	configuration = configuration or {}

	local manual_height = numeric_setting(mod, "card_height", 110, 110, 240)
	local global_store_extra = global_store_extra_height(mod, configuration)
	local force_name_it_curio_title = setting(mod, "curio_display_profile", "detailed") == "detailed" and name_it_curio_title_enabled(mod, configuration)

	if not setting(mod, "automatic_card_height", true) and not configuration.native_single_column and global_store_extra <= 0 and not force_name_it_curio_title then
		return manual_height
	end

	local item_name_font_size = configuration.native_single_column and numeric_setting(mod, "single_column_weapon_name_font_size", 20, 10, 24) or grid_weapon_name_font_size(mod, configuration)
	local secondary_font_size = numeric_setting(mod, "secondary_text_font_size", 13, 8, 20)
	local expertise_font_size = numeric_setting(mod, "expertise_font_size", 20, 10, 28)
	local name_row_height = configuration.native_single_column and 25 + math.max(0, item_name_font_size - 16) or math.max(25, item_name_font_size + 5)
	local secondary_row_height = math.max(22, secondary_font_size + 5)
	local bottom_region_height = math.max(expertise_font_size + 10, secondary_font_size + 15)
	local required_height = global_store_extra > 0 and manual_height or 110
	local store_footer_height = configuration.store_item and STORE_FOOTER_HEIGHT + global_store_extra_height(mod, configuration) or 0

	local blessing_display_mode = weapon_blessing_display_mode(mod)
	local blessing_text_mode = blessing_display_mode == "text" or blessing_display_mode == "ranked_text"

	if blessing_display_mode == "icons" then
		local configured_blessing_size = blessing_icon_size(mod)

		if configuration.store_item then
			bottom_region_height = store_footer_height + configured_blessing_size + 6
		else
			bottom_region_height = math.max(bottom_region_height, configured_blessing_size + 6)
		end
	elseif blessing_text_mode then
		local blessing_font_size = math.max(9, math.min(16, secondary_font_size))
		local blessing_line_height = blessing_display_mode == "ranked_text" and math.max(blessing_font_size + 4, weapon_perk_rank_icon_size(mod) + 1) or blessing_font_size + 4
		local blessing_vertical_spacing = numeric_setting(mod, "weapon_blessing_text_vertical_spacing", 2, 0, 20)
		local blessing_bottom_padding = numeric_setting(mod, "weapon_blessing_text_bottom_padding", 4, 0, 20)
		local blessing_text_height = WEAPON_BLESSING_COUNT * blessing_line_height + (WEAPON_BLESSING_COUNT - 1) * blessing_vertical_spacing + blessing_bottom_padding + 3

		if configuration.native_single_column and setting(mod, "single_column_blessing_icons_on_right", true) then
			blessing_text_height = math.max(blessing_text_height, blessing_icon_size(mod) + blessing_bottom_padding + 3)
		end

		if configuration.store_item then
			bottom_region_height = store_footer_height + blessing_text_height
		elseif separate_blessing_text_and_item_level(mod, configuration) then
			bottom_region_height = bottom_region_height + blessing_text_height
		else
			bottom_region_height = math.max(bottom_region_height, blessing_text_height)
		end
	elseif configuration.store_item then
		bottom_region_height = math.max(bottom_region_height, store_footer_height)
	end

	if setting(mod, "show_weapon_perks", true) then
		local perk_font_size = math.max(9, math.min(16, secondary_font_size))
		local perk_line_height = setting(mod, "show_weapon_perk_rank_symbols", true) and math.max(perk_font_size + 4, weapon_perk_rank_icon_size(mod) + 1) or perk_font_size + 4
		local perk_vertical_spacing = numeric_setting(mod, "weapon_perk_vertical_spacing", 2, 0, 20)
		local section_spacing = blessing_display_mode ~= "off" and numeric_setting(mod, "weapon_perk_blessing_spacing", 5, 0, 20) or 2

		bottom_region_height = bottom_region_height + WEAPON_PERK_COUNT * perk_line_height + (WEAPON_PERK_COUNT - 1) * perk_vertical_spacing + math.max(0, section_spacing - 2)
	end

	local optional_rows = 0

	if setting(mod, "show_pattern_mark", false) then
		optional_rows = optional_rows + 1
	end

	if setting(mod, "show_rarity_name", false) then
		optional_rows = optional_rows + 1
	end

	local native_content_gap = configuration.native_single_column and NATIVE_SINGLE_COLUMN_CONTENT_GAP or 0

	required_height = math.max(required_height, 7 + name_row_height + optional_rows * secondary_row_height + bottom_region_height + 8 + native_content_gap)

	if configuration.native_single_column and configuration.store_item and not configuration.global_store then
		required_height = required_height + ARMOURY_NATIVE_CARD_HEIGHT_EXTRA
	end

	if setting(mod, "curio_display_profile", "detailed") == "detailed" then
		local primary_line_height = curio_primary_font_size(mod) + 5
		local secondary_line_height = curio_secondary_font_size(mod) + 5
		local primary_secondary_spacing = curio_primary_secondary_spacing(mod)
		local curio_title_height = force_name_it_curio_title and curio_name_title_height(mod, configuration) or 0

		required_height = math.max(required_height, 7 + curio_title_height + primary_line_height + primary_secondary_spacing + 3 * secondary_line_height + 12 + store_footer_height)
	else
		local primary_line_height = math.max(20, curio_primary_font_size(mod) + 5)
		local quality_row_height = setting(mod, "show_curio_quality", false) and secondary_row_height or 0

		required_height = math.max(required_height, 7 + name_row_height + quality_row_height + primary_line_height + 12 + store_footer_height)
	end

	return math.max(110, math.min(240, math.ceil(required_height)))
end

Geometry.item_size = function(mod, grid_width, maximum_columns, configuration)
	grid_width = tonumber(grid_width)
	local slot_kind = configuration and configuration.slot_kind

	if not grid_width or grid_width <= 0 then
		grid_width = MINIMUM_CARD_WIDTH * Geometry.columns(mod, maximum_columns, slot_kind)
	end

	local columns = Geometry.columns(mod, maximum_columns, slot_kind)
	local spacing = numeric_setting(mod, "grid_spacing", 10, 0, 40)
	local wkc_padding = Cards.weapon_kill_counter_card_height_padding(mod, configuration, columns)
	local height = math.min(240, Geometry.card_height(mod, configuration) + wkc_padding)
	local width = math.floor((grid_width - spacing * (columns - 1)) / columns)

	return {
		math.max(60, width),
		height,
	}
end

Geometry.configure_grid = function(mod, item_grid)
	if not setting(mod, "enable_grid_layout", true) then
		return
	end

	local spacing = numeric_setting(mod, "grid_spacing", 10, 0, 40)
	local menu_settings = item_grid and item_grid._menu_settings

	if menu_settings then
		menu_settings.grid_spacing = {
			spacing,
			spacing,
		}
	end
end
return Geometry
