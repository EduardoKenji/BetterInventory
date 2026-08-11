local Text = require("scripts/utilities/ui/text")
local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")
local LayoutContent = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_content")
local Cards = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_cards")
local Geometry = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_geometry")
local Blueprints = {}
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

Blueprints.set_item_customization_provider = function(provider)
	content.set_item_customization_provider(provider)
	Cards.set_item_customization_provider(provider)
	Geometry.set_item_customization_provider(provider)
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

local function content_is_curio(card_content)
	local cached = card_content and card_content.better_inventory_is_curio

	if cached ~= nil then
		return cached == true
	end

	return is_curio(item_from_content(card_content))
end

local function content_is_weapon(card_content)
	local cached = card_content and card_content.better_inventory_is_weapon

	if cached ~= nil then
		return cached == true
	end

	return is_weapon(item_from_content(card_content))
end

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
Blueprints.configure_native_item_blueprint = function(mod, item_blueprint, grid_width, configuration)
	configuration = configuration or {}
	local global_store = configuration.global_store == true
	local store_item = configuration.store_item == true or global_store
	local armoury_native = store_item and not global_store
	local global_store_extra = global_store_extra_height(mod, configuration)
	local global_store_multicolumn = global_store and global_store_extra > 0
	local global_store_photo_size = global_store_multicolumn and global_store_character_photo_size(mod) or 34
	local global_store_info_gap = global_store_multicolumn and global_store_character_info_gap(mod) or 0
	local global_store_class_icon_size = global_store_multicolumn and global_store_character_class_icon_size(mod) or GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_DEFAULT
	local global_store_name_font_size = global_store_multicolumn and global_store_character_name_font_size(mod) or GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_DEFAULT
	local global_store_price_padding = global_store_multicolumn and global_store_price_row_padding(mod) or 0
	local global_store_price_row_offset = global_store_multicolumn and GLOBAL_STORE_CHARACTER_ROW_HEIGHT + global_store_price_padding or 0
	local item_size = table.clone(item_blueprint.size or {
		grid_width,
		110,
	})
	local card_width = item_size[1] or grid_width
	local pass_template = table.clone(item_blueprint.pass_template)
	local detailed_curio_profile = setting(mod, "curio_display_profile", "detailed") == "detailed"
	local show_pattern_mark = setting(mod, "show_pattern_mark", false)
	local show_curio_quality = setting(mod, "show_curio_quality", false)
	local show_curio_item_level = setting(mod, "show_curio_item_level", true)
	local quick_look_card_present = has_quick_look_card_passes(pass_template)
	local weapon_modifier_stats_enabled = setting(mod, "enable_quick_look_card_single_column_integration", true)
	local character_overview_dump_stat_only = configuration.character_overview == true and setting(mod, "character_overview_show_only_dump_stat", false)
	local managed_native_card = not quick_look_card_present or weapon_modifier_stats_enabled

	if global_store and pass_by_style_id(pass_template, "character_info_text") and not pass_by_style_id(pass_template, "character_class_icon_text") then
		local character_info_pass = pass_by_style_id(pass_template, "character_info_text")
		local class_icon_pass = table.clone(character_info_pass)

		class_icon_pass.style_id = "character_class_icon_text"
		class_icon_pass.value_id = "character_class_icon_text"
		class_icon_pass.value = ""
		class_icon_pass.style = table.clone(character_info_pass.style)
		pass_template[#pass_template + 1] = class_icon_pass
	end

	if managed_native_card then
		local native_configuration = table.clone(configuration)
		native_configuration.native_single_column = true

		if not configuration.character_overview then
			item_size[2] = math.max(item_size[2] or 110, Geometry.card_height(mod, native_configuration))
		end
	end

	item_blueprint.size = item_size
	item_blueprint.pass_template = pass_template

	if managed_native_card then
		configure_native_card_geometry(pass_template, item_size[2] or 110)
	end

	if weapon_modifier_stats_enabled then
		if character_overview_dump_stat_only then
			disable_quick_look_card_passes(pass_template)
			add_quick_look_card_grid_pass(mod, pass_template, card_width, 12, "above_power", 0)

			local dump_stat_pass = pass_by_style_id(pass_template, content.QUICK_LOOK_CARD_DUMP_STAT_ID)
			local dump_stat_style = dump_stat_pass and dump_stat_pass.style

			if dump_stat_style then
				local horizontal_offset = numeric_setting(mod, "character_overview_dump_stat_horizontal_offset", -10, -300, 300)
				local font_scale = numeric_setting(mod, "character_overview_dump_stat_font_scale_percent", 130, 50, 200) * 0.01
				local font_size = math.max(6, math.floor((tonumber(dump_stat_style.font_size) or 13) * font_scale + 0.5))
				-- Anchor Character Overview labels by a shared center instead of their
				-- right edge. Different abbreviations (for example MOB and STB) then
				-- remain optically aligned, and the user offset moves that center.
				local label_width = math.max(52, 2 * math.ceil(font_size * 1.625))
				local center_from_card_right = -34 + horizontal_offset

				dump_stat_style.offset[1] = center_from_card_right + label_width * 0.5
				dump_stat_style.font_size = font_size
				dump_stat_style.size[1] = label_width
				dump_stat_style.size[2] = font_size + 4
				dump_stat_style.text_horizontal_alignment = "center"
				dump_stat_style.text_color = configured_text_color(mod, "character_overview_dump_stat_color", QUICK_LOOK_CARD_HIGHLIGHT_COLOR)
			end
		else
			configure_native_quick_look_card_passes(mod, pass_template, card_width, item_size[2] or 110, configuration)
		end
	end

	local display_name = pass_by_style_id(pass_template, "display_name")
	local sub_display_name = pass_by_style_id(pass_template, "sub_display_name")
	local rarity_name = pass_by_style_id(pass_template, "rarity_name")
	local item_level = pass_by_style_id(pass_template, "item_level")
	local native_name_font_size = numeric_setting(mod, "single_column_weapon_name_font_size", 20, 10, 24)

	if display_name and display_name.style then
		display_name.style.font_size = native_name_font_size
		display_name.style.word_wrap = false
		display_name.style.size = display_name.style.size or {}
		display_name.style.size[2] = math.max(display_name.style.size[2] or 0, native_name_font_size + 6)
		if global_store then
			display_name.style.horizontal_alignment = "left"
			display_name.style.vertical_alignment = "top"
			display_name.style.text_horizontal_alignment = "left"
			display_name.style.text_vertical_alignment = "top"
			display_name.style.offset = {
				12,
				7,
				11,
			}
			display_name.style.size[1] = math.max(80, card_width - 120)
		end
	end

	preserve_visibility(display_name, function(content)
		return not detailed_curio_profile or not content_is_curio(content)
	end)

	if sub_display_name then
		sub_display_name.visibility_function = function(content)
			if content_is_curio(content) then
				return show_curio_quality and not detailed_curio_profile
			end

			return content_is_weapon(content) and show_pattern_mark
		end
	end

	if rarity_name then
		local show_weapon_quality = setting(mod, "show_rarity_name", false)

		rarity_name.visibility_function = function(content)
			return show_weapon_quality and content_is_weapon(content)
		end
	end

	if global_store then
		local icon = pass_by_style_id(pass_template, "icon")

		if icon and icon.style then
			local native_icon_size = icon.style.size or {}
			local native_icon_width = tonumber(native_icon_size[1]) or math.min(card_width, math.floor(card_width * 0.55))

			-- Keep Darktide's native landscape icon width/aspect instead of scaling
			-- the weapon texture across the entire GlobalStore card.
			icon.style.horizontal_alignment = "right"
			icon.style.vertical_alignment = "top"
			icon.style.size = {
				math.min(card_width, native_icon_width),
				math.max(1, (item_size[2] or 110) - global_store_extra),
			}
			icon.style.offset = {
				0,
				0,
				4,
			}
		end
	end

	preserve_visibility(item_level, function(content)
		return not content_is_curio(content) or show_curio_item_level
	end)

	if global_store_multicolumn and item_level and item_level.style then
		item_level.style.text_color = table.clone(DEFAULT_ARMOURY_ITEM_LEVEL_COLOR)
		item_level.style.default_color = table.clone(DEFAULT_ARMOURY_ITEM_LEVEL_COLOR)
		item_level.style.hover_color = table.clone(DEFAULT_ARMOURY_ITEM_LEVEL_COLOR)
		item_level.style.horizontal_alignment = "right"
		item_level.style.vertical_alignment = "bottom"
		item_level.style.text_horizontal_alignment = "right"
		item_level.style.text_vertical_alignment = "bottom"
		item_level.style.offset = {
			-8,
			-global_store_price_row_offset,
			12,
		}
		item_level.style.size = {
			card_width - 16,
			28,
		}
	end

	if global_store_multicolumn then
		local wallet_icon = pass_by_style_id(pass_template, "wallet_icon")

		if wallet_icon and wallet_icon.style then
			wallet_icon.style.horizontal_alignment = "left"
			wallet_icon.style.vertical_alignment = "bottom"
			wallet_icon.style.size = {
				22,
				18,
			}
			wallet_icon.style.offset = {
				12,
				-(global_store_price_row_offset + 2),
				12,
			}
		end

		configure_text_pass(pass_by_style_id(pass_template, "price_text"), {
			font_size = 16,
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			text_horizontal_alignment = "left",
			text_vertical_alignment = "bottom",
			offset = {
				39,
				-global_store_price_row_offset,
				12,
			},
			size = {
				math.max(45, card_width - 120),
				24,
			},
		})

		configure_text_pass(pass_by_style_id(pass_template, "owned_text"), {
			font_size = 14,
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			text_horizontal_alignment = "left",
			text_vertical_alignment = "bottom",
			offset = {
				12,
				-global_store_price_row_offset,
				12,
			},
			size = {
				math.max(55, card_width - 80),
				24,
			},
		})
	end

	if global_store then
		local portrait = pass_by_style_id(pass_template, "portrait")

		if portrait and portrait.style then
			portrait.style.horizontal_alignment = "left"
			portrait.style.vertical_alignment = "bottom"
			portrait.style.size = {
				global_store_photo_size,
				global_store_photo_size,
			}
			-- This branch is native single-column GlobalStore only. With bottom
			-- alignment, a smaller Y offset moves the portrait upward; keep these
			-- logical UI-canvas coordinates resolution-independent.
			portrait.style.offset = {
				15,
				-1,
				14,
			}
		end

		local character_info = pass_by_style_id(pass_template, "character_info_text")
		if character_info and character_info.style then
			character_info.style.horizontal_alignment = "left"
			character_info.style.vertical_alignment = "bottom"
			character_info.style.text_horizontal_alignment = "left"
			character_info.style.text_vertical_alignment = "bottom"
			character_info.style.font_size = global_store_name_font_size
			character_info.style.word_wrap = false
			character_info.style.text_fit_with = false
			character_info.style.offset = {
				18 + global_store_photo_size + global_store_info_gap + global_store_class_icon_size + 4,
				-7,
				14,
			}
			character_info.style.size = {
				math.max(40, card_width - 18 - global_store_photo_size - global_store_info_gap - global_store_class_icon_size - 14),
				24,
			}
		end

		local class_icon = pass_by_style_id(pass_template, "character_class_icon_text")
		if class_icon and class_icon.style then
			class_icon.style.horizontal_alignment = "left"
			class_icon.style.vertical_alignment = "bottom"
			class_icon.style.text_horizontal_alignment = "left"
			class_icon.style.text_vertical_alignment = "bottom"
			class_icon.style.font_size = global_store_class_icon_size
			class_icon.style.word_wrap = false
			class_icon.style.offset = {
				18 + global_store_photo_size + global_store_info_gap,
				-7,
				14,
			}
			class_icon.style.size = {
				math.max(12, global_store_class_icon_size + 4),
				24,
			}
		end
	end

	set_visibility(pass_by_style_id(pass_template, "rarity_tag"), setting(mod, "show_rarity_tag", true))
	configure_equipped_highlight(mod, pass_template, card_width, item_size[2] or 110)
	configure_favorite_marker(mod, pass_template, 15)

	if managed_native_card then
		add_custom_content_passes(mod, pass_template, card_width, 15, sub_display_name and sub_display_name.style, {
			content_right = weapon_modifier_stats_enabled and not character_overview_dump_stat_only and 260 or nil,
			native_single_column = true,
			global_store = global_store,
			store_item = store_item,
			character_overview = configuration.character_overview,
		})
	end

	if armoury_native and item_level and item_level.style then
		-- Keep Armoury's item level above its dark price footer, matching the
		-- readable inventory treatment without touching GlobalStore geometry.
		item_level.style.text_color = table.clone(DEFAULT_ARMOURY_ITEM_LEVEL_COLOR)
		item_level.style.default_color = table.clone(DEFAULT_ARMOURY_ITEM_LEVEL_COLOR)
		item_level.style.hover_color = table.clone(DEFAULT_ARMOURY_ITEM_LEVEL_COLOR)
		item_level.style.horizontal_alignment = "right"
		item_level.style.vertical_alignment = "bottom"
		item_level.style.text_horizontal_alignment = "right"
		item_level.style.text_vertical_alignment = "bottom"
		item_level.style.offset = {
			-8,
			-(STORE_FOOTER_HEIGHT + 2),
			12,
		}
		item_level.style.size = {
			card_width - 16,
			28,
		}
	end
	configure_card_content(mod, item_blueprint, {
		native_single_column = true,
		global_store = global_store,
		store_item = store_item,
		weapon_modifier_stats_enabled = weapon_modifier_stats_enabled and not character_overview_dump_stat_only,
	})

	return item_size
end
Blueprints.configure_item_blueprint = function(mod, item_blueprint, grid_width, configuration)
	if not setting(mod, "enable_grid_layout", true) then
		configuration = configuration or {}
		return Blueprints.configure_native_item_blueprint(mod, item_blueprint, grid_width, configuration)
	end

	configuration = configuration or {}
	local global_store = configuration.global_store == true
	local global_store_extra = global_store_extra_height(mod, configuration)
	local global_store_multicolumn = global_store_extra > 0
	local global_store_photo_size = global_store_multicolumn and global_store_character_photo_size(mod) or 34
	local global_store_info_gap = global_store_multicolumn and global_store_character_info_gap(mod) or 0
	local global_store_class_icon_size = global_store_multicolumn and global_store_character_class_icon_size(mod) or GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_DEFAULT
	local global_store_name_font_size = global_store_multicolumn and global_store_character_name_font_size(mod) or GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_DEFAULT
	local global_store_compact_character_names = global_store_multicolumn and setting(mod, "global_store_compact_character_names", true) and Geometry.columns(mod, configuration.maximum_columns, configuration.slot_kind) >= 4 or false
	local global_store_price_padding = global_store_multicolumn and global_store_price_row_padding(mod) or 0
	local global_store_price_row_offset = global_store_multicolumn and GLOBAL_STORE_CHARACTER_ROW_HEIGHT + global_store_price_padding or 0

	local item_size = Geometry.item_size(mod, grid_width, configuration.maximum_columns, configuration)
	local card_width = item_size[1]
	local card_height = item_size[2]
	local pass_template = table.clone(item_blueprint.pass_template)

	if global_store_multicolumn and pass_by_style_id(pass_template, "character_info_text") and not pass_by_style_id(pass_template, "character_class_icon_text") then
		local character_info_pass = pass_by_style_id(pass_template, "character_info_text")
		local class_icon_pass = table.clone(character_info_pass)

		class_icon_pass.style_id = "character_class_icon_text"
		class_icon_pass.value_id = "character_class_icon_text"
		class_icon_pass.value = ""
		class_icon_pass.style = table.clone(character_info_pass.style)
		pass_template[#pass_template + 1] = class_icon_pass
	end

	local show_rarity_tag = setting(mod, "show_rarity_tag", true)
	local text_left = show_rarity_tag and 12 or 8
	local quick_look_card_present = has_quick_look_card_passes(pass_template)
	local quick_look_card_integration = setting(mod, "enable_quick_look_card_grid_integration", true)
	local quick_look_card_position = quick_look_card_grid_position(mod)
	local quick_look_card_label_width = quick_look_card_integration and quick_look_card_position ~= "above_power" and math.max(64, math.floor(numeric_setting(mod, "quick_look_card_grid_font_size", 13, 8, 20) * 6 + 0.5)) or 0

	if quick_look_card_position ~= "above_power" and card_width < text_left + quick_look_card_label_width + 4 + 36 + 50 then
		quick_look_card_position = "above_power"
	end

	local display_name_left = text_left + (quick_look_card_integration and quick_look_card_position == "name_left" and quick_look_card_label_width + 4 or 0)
	local display_name_right_reserve = 36 + (quick_look_card_integration and quick_look_card_position == "name_right" and quick_look_card_label_width + 4 or 0)
	local text_width = math.max(50, card_width - display_name_left - display_name_right_reserve)
	local darkness = numeric_setting(mod, "icon_darkness", 25, 0, 85)
	local icon_brightness = math.floor(255 * (1 - darkness / 100))
	local curio_display_profile = setting(mod, "curio_display_profile", "detailed")
	local detailed_curio_profile = curio_display_profile == "detailed"
	local show_curio_quality = setting(mod, "show_curio_quality", false)
	local show_curio_item_level = setting(mod, "show_curio_item_level", true)

	item_blueprint.size = item_size
	item_blueprint.pass_template = pass_template
	disable_quick_look_card_passes(pass_template)

	if quick_look_card_integration then
		add_quick_look_card_grid_pass(mod, pass_template, card_width, text_left, quick_look_card_position, global_store_price_row_offset)
	end

	local icon = pass_by_style_id(pass_template, "icon")

	if icon and icon.style then
		icon.style.horizontal_alignment = "left"
		icon.style.vertical_alignment = "top"
		icon.style.size = {
			card_width,
			card_height - global_store_extra,
		}
		icon.style.offset = {
			0,
			0,
			4,
		}
		icon.style.uvs = {
			{
				0,
				0,
			},
			{
				1,
				1,
			},
		}
		icon.style.color = {
			255,
			icon_brightness,
			icon_brightness,
			icon_brightness,
		}
	end

	local loading = pass_by_style_id(pass_template, "loading")

	if loading and loading.style then
		loading.style.horizontal_alignment = "center"
		loading.style.vertical_alignment = "center"
		loading.style.size = {
			56,
			56,
		}
		loading.style.offset = {
			0,
			0,
			5,
		}
	end

	local display_name = pass_by_style_id(pass_template, "display_name")

	configure_text_pass(display_name, {
		font_size = grid_weapon_name_font_size(mod, configuration),
		offset = {
			display_name_left,
			7,
			8,
		},
		size = {
			text_width,
			25,
		},
	})

	if display_name and display_name.style then
		display_name.style.word_wrap = false
	end
	preserve_visibility(display_name, function(content)
		return not detailed_curio_profile or not content_is_curio(content)
	end)

	local sub_display_name = pass_by_style_id(pass_template, "sub_display_name")

	configure_text_pass(sub_display_name, {
		font_size = numeric_setting(mod, "secondary_text_font_size", 13, 8, 20),
		offset = {
			text_left,
			31,
			8,
		},
		size = {
			card_width - text_left - 8,
			22,
		},
	})
	local show_pattern_mark = setting(mod, "show_pattern_mark", false)

	if sub_display_name then
		sub_display_name.visibility_function = function(content)
			if content_is_curio(content) then
				return show_curio_quality and not detailed_curio_profile
			end

			return content_is_weapon(content) and show_pattern_mark
		end
	end

	local rarity_name = pass_by_style_id(pass_template, "rarity_name")

	configure_text_pass(rarity_name, {
		font_size = numeric_setting(mod, "secondary_text_font_size", 13, 8, 20),
		offset = {
			text_left,
			51,
			8,
		},
		size = {
			card_width - text_left - 8,
			22,
		},
	})
	if rarity_name then
		local show_weapon_quality = setting(mod, "show_rarity_name", false)

		rarity_name.visibility_function = function(content)
			return show_weapon_quality and content_is_weapon(content)
		end
	end

	local item_level = pass_by_style_id(pass_template, "item_level")

	configure_text_pass(item_level, {
		font_size = numeric_setting(mod, "expertise_font_size", 20, 10, 28),
		horizontal_alignment = "right",
		vertical_alignment = "bottom",
		text_horizontal_alignment = "right",
		text_vertical_alignment = "bottom",
		offset = {
			-8,
			-5,
			9,
		},
		size = {
			card_width - 16,
			28,
		},
	})
	if configuration.store_item and setting(mod, "brighten_armoury_item_levels", true) and item_level and item_level.style then
		item_level.style.text_color = table.clone(DEFAULT_ARMOURY_ITEM_LEVEL_COLOR)
		item_level.style.default_color = table.clone(DEFAULT_ARMOURY_ITEM_LEVEL_COLOR)
		item_level.style.hover_color = table.clone(DEFAULT_ARMOURY_ITEM_LEVEL_COLOR)
		-- Darktide's store blueprint draws a translucent price footer at z=10.
		-- Raise the rating above that footer when the readability option is on.
		item_level.style.offset[3] = 11
	end
	if global_store_multicolumn and item_level and item_level.style then
		-- Keep the rating in the price row; the character row occupies the new
		-- space below it.
		item_level.style.offset[2] = -global_store_price_row_offset
	end
	preserve_visibility(item_level, function(content)
		return not content_is_curio(content) or show_curio_item_level
	end)

	if configuration.store_item then
		local wallet_icon = pass_by_style_id(pass_template, "wallet_icon")

		if wallet_icon and wallet_icon.style then
			wallet_icon.style.horizontal_alignment = global_store_multicolumn and "left" or (global_store and "right" or "left")
			wallet_icon.style.vertical_alignment = "bottom"
			wallet_icon.style.size = {
				22,
				18,
			}
			wallet_icon.style.offset = global_store_multicolumn and {
				text_left,
				-(global_store_price_row_offset + 2),
				12,
			} or global_store and {
				-8,
				-7,
				12,
			} or {
				text_left,
				-7,
				12,
			}
		end

		local price_text = pass_by_style_id(pass_template, "price_text")

		configure_text_pass(price_text, {
			font_size = 16,
			horizontal_alignment = global_store_multicolumn and "left" or (global_store and "right" or "left"),
			vertical_alignment = "bottom",
			text_horizontal_alignment = global_store_multicolumn and "left" or (global_store and "right" or "left"),
			text_vertical_alignment = "bottom",
			offset = global_store_multicolumn and {
				text_left + 27,
				-global_store_price_row_offset,
				12,
			} or global_store and {
				-30,
				-5,
				12,
			} or {
				text_left + 27,
				-5,
				12,
			},
			size = global_store_multicolumn and {
				math.max(45, card_width - text_left - 105),
				24,
			} or global_store and {
				math.max(45, card_width - text_left - 30),
				24,
			} or {
				math.max(45, card_width - text_left - 105),
				24,
			},
		})
		configure_text_pass(pass_by_style_id(pass_template, "owned_text"), {
			font_size = 14,
			horizontal_alignment = global_store_multicolumn and "left" or (global_store and "right" or "left"),
			vertical_alignment = "bottom",
			text_horizontal_alignment = global_store_multicolumn and "left" or (global_store and "right" or "left"),
			text_vertical_alignment = "bottom",
			offset = global_store_multicolumn and {
				text_left,
				-global_store_price_row_offset,
				12,
			} or global_store and {
				-30,
				-5,
				12,
			} or {
				text_left,
				-5,
				12,
			},
			size = global_store_multicolumn and {
				math.max(55, card_width - text_left - 80),
				24,
			} or global_store and {
				math.max(55, card_width - text_left - 30),
				24,
			} or {
				math.max(55, card_width - text_left - 80),
				24,
			},
		})
	end

	if global_store then
		local portrait = pass_by_style_id(pass_template, "portrait")

		if portrait and portrait.style then
			portrait.style.horizontal_alignment = "left"
			portrait.style.vertical_alignment = "bottom"
			portrait.style.size = {
				global_store_photo_size,
				global_store_photo_size,
			}
			portrait.style.offset = {
				text_left,
				-2,
				14,
			}
		end

		local character_info = pass_by_style_id(pass_template, "character_info_text")

		if character_info and character_info.style then
			local character_name_width

			if global_store_multicolumn then
				local compact_name_margin = global_store_compact_character_names and GLOBAL_STORE_CHARACTER_NAME_FIT_SAFETY_MARGIN or 0
				local reserved_name_width = text_left + global_store_photo_size + global_store_info_gap + global_store_class_icon_size + 10 + compact_name_margin

				character_name_width = math.max(global_store_compact_character_names and 20 or 40, card_width - reserved_name_width)
			else
				character_name_width = math.max(40, card_width - text_left - 108)
			end

			character_info.style.horizontal_alignment = "left"
			character_info.style.vertical_alignment = "bottom"
			character_info.style.text_horizontal_alignment = "left"
			character_info.style.text_vertical_alignment = "bottom"
			character_info.style.font_size = global_store_name_font_size
			character_info.style.word_wrap = false
			-- The native text pass scales the name down to the available width.
			-- Limit this behavior to narrow four/five-column cards so two/three
			-- column layouts retain their configured typography.
			character_info.style.text_fit_with = global_store_compact_character_names
			character_info.style.offset = {
				text_left + (global_store_multicolumn and global_store_photo_size + global_store_info_gap + global_store_class_icon_size + 4 or 38),
				-7,
				14,
			}
			character_info.style.size = {
				character_name_width,
				24,
			}
		end

		local class_icon = pass_by_style_id(pass_template, "character_class_icon_text")

		if class_icon and class_icon.style then
			class_icon.style.horizontal_alignment = "left"
			class_icon.style.vertical_alignment = "bottom"
			class_icon.style.text_horizontal_alignment = "left"
			class_icon.style.text_vertical_alignment = "bottom"
			class_icon.style.font_size = global_store_class_icon_size
			class_icon.style.word_wrap = false
			class_icon.style.offset = {
				text_left + (global_store_multicolumn and global_store_photo_size + global_store_info_gap or 38),
				-7,
				14,
			}
			class_icon.style.size = {
				math.max(12, global_store_class_icon_size + 4),
				24,
			}
		end
	end

	local rarity_tag = pass_by_style_id(pass_template, "rarity_tag")

	if rarity_tag and rarity_tag.style then
		rarity_tag.style.size = {
			5,
			card_height,
		}
	end
	set_visibility(rarity_tag, show_rarity_tag)

	local equipped_icon = pass_by_style_id(pass_template, "equipped_icon")

	if equipped_icon and equipped_icon.style then
		equipped_icon.style.size = {
			28,
			28,
		}
		equipped_icon.style.offset = {
			-2,
			2,
			16,
		}
	end

	configure_equipped_highlight(mod, pass_template, card_width, card_height)

	for i = 1, #pass_template do
		local pass = pass_template[i]

		if pass.value == "content/ui/materials/symbols/new_item_indicator" and pass.style then
			pass.style.size = {
				62,
				62,
			}
			pass.style.offset = {
				16,
				-16,
				4,
			}
			break
		end
	end

	configure_favorite_marker(mod, pass_template, text_left)

	local salvage_icon = pass_by_style_id(pass_template, "salvage_icon")
	local salvage_circle = pass_by_style_id(pass_template, "salvage_circle")

	if salvage_icon and salvage_icon.style then
		salvage_icon.style.offset = {
			card_width * 0.5 - 27,
			0,
			14,
		}
	end

	if salvage_circle and salvage_circle.style then
		salvage_circle.style.offset = {
			card_width * 0.5 - 50,
			0,
			15,
		}
	end

	local centered_y = card_height * 0.5 - 19

	for _, style_id in ipairs({
		"required_level_background",
		"required_level",
		"warning_message_background",
		"warning_message",
	}) do
		local pass = pass_by_style_id(pass_template, style_id)

		if pass and pass.style then
			pass.style.offset = pass.style.offset or {}
			pass.style.offset[2] = centered_y
		end
	end

	add_custom_content_passes(mod, pass_template, card_width, text_left, sub_display_name and sub_display_name.style, configuration)

	set_height(pass_by_style_id(pass_template, "inner_shadow"), card_height)
	set_height(pass_by_style_id(pass_template, "inner_highlight"), card_height)

	configure_card_content(mod, item_blueprint, configuration)

	return item_size
end
return Blueprints
