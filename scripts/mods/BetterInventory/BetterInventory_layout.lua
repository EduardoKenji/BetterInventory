local Text = require("scripts/utilities/ui/text")
local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")
local LayoutContent = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_content")

local Layout = {}
local content = LayoutContent

local Cards = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_cards")

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

local Geometry = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_geometry")
local Blueprints = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_blueprints")

for name, value in pairs(Geometry) do
	Layout[name] = value
end

Layout.configure_native_item_blueprint = Blueprints.configure_native_item_blueprint
Layout.configure_item_blueprint = Blueprints.configure_item_blueprint
Layout.ImageLayout = Blueprints.ImageLayout

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

Layout.set_item_customization_provider = function(provider)
	content.set_item_customization_provider(provider)
	Cards.set_item_customization_provider(provider)
	Geometry.set_item_customization_provider(provider)
	Blueprints.set_item_customization_provider(provider)
end
Layout.clear_runtime_caches = content.clear_runtime_caches
Layout.direct_weapon_comparing_stats = content.direct_weapon_comparing_stats
Layout.projected_weapon_modifier_records = content.projected_weapon_modifier_records
Layout.curio_secondary_color = content.curio_secondary_color
Layout.update_highlight_animation = Cards.update_highlight_animation
Layout.remove_weapon_stats_wkc_listing_overlays = Cards.remove_weapon_stats_wkc_listing_overlays
Layout.cap_brunt_wkc_listing_overlay_sizes = Cards.cap_brunt_wkc_listing_overlay_sizes
Layout.install_brunt_wkc_listing_hook = Cards.install_brunt_wkc_listing_hook
Layout.synchronize_rarity_tag_color = content.synchronize_rarity_tag_color
Layout.apply_item_customization_style = content.apply_item_customization_style
Layout.restore_item_customization_style = content.restore_item_customization_style
Layout.apply_weapon_information_customization = content.apply_weapon_information_customization
Layout.refresh_item_customization = content.refresh_item_customization
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

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.


-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_cards.lua.

-- Extracted to BetterInventory_layout_geometry.lua.

-- Extracted to BetterInventory_layout_blueprints.lua.


-- Extracted to BetterInventory_layout_blueprints.lua.

return Layout
