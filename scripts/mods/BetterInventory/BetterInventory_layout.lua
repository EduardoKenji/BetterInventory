local Text = require("scripts/utilities/ui/text")
local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")
local LayoutContent = require("scripts/mods/BetterInventory/BetterInventory_layout_content")

local Layout = {}
local content = LayoutContent

content.set_columns(function(mod, maximum_columns, slot_kind)
	return Layout.columns(mod, maximum_columns, slot_kind)
end)

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

Layout.set_item_customization_provider = content.set_item_customization_provider
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

local function configure_native_quick_look_card_passes(mod, pass_template, card_width, card_height, configuration)
	local armoury_native = configuration and configuration.store_item == true and configuration.global_store ~= true
	local font_size = numeric_setting(mod, "quick_look_card_single_column_font_size", 14, 8, 20)
	local lowest_modifier_color = configured_text_color(mod, "weapon_modifier_lowest_color", QUICK_LOOK_CARD_HIGHLIGHT_COLOR, "weapon_modifier_lowest_color_opacity", 80)
	local horizontal_setting = configuration and configuration.global_store and "global_store_single_column_modifier_horizontal_position" or "quick_look_card_single_column_horizontal_position"
	local vertical_setting = configuration and configuration.global_store and "global_store_single_column_modifier_vertical_position" or "quick_look_card_single_column_vertical_position"
	local horizontal_default = configuration and configuration.global_store and 55 or 79
	local vertical_default = configuration and configuration.global_store and 100 or 93
	local horizontal_percent = numeric_setting(mod, horizontal_setting, horizontal_default, 0, 100)
	local vertical_percent = numeric_setting(mod, vertical_setting, vertical_default, 0, 100)
	local text_z = configuration and (configuration.global_store or armoury_native) and 12 or 5
	local line_height = font_size + 3
	local row_step = line_height + 2
	local column_step = math.max(80, math.floor(font_size * 5.72 + 0.5))
	local title_width = math.max(42, math.floor(font_size * 3 + 0.5))
	local value_width = math.max(32, math.floor(font_size * 2.3 + 0.5))
	-- Anchor values after the full title box so compact labels cannot overlap.
	local title_value_gap = numeric_setting(mod, "quick_look_card_single_column_label_value_gap", 1, 0, 16)
	local value_offset = title_width + title_value_gap
	local block_width = column_step * 2 + value_offset + value_width
	local block_height = row_step + line_height
	local block_left = math.floor(math.max(0, card_width - block_width) * horizontal_percent * 0.01 + 0.5)
	local block_top = math.floor(math.max(0, card_height - block_height) * vertical_percent * 0.01 + 0.5)

	if armoury_native then
		-- Armoury's native store blueprint draws a translucent footer over the
		-- bottom 34 logical pixels. Keep the detailed stat block above that
		-- footer with a small visual gap and shift it right so it sits naturally
		-- beside the blessing area without colliding with item level or price.
		-- GlobalStore keeps its existing configurable path.
		block_left = math.floor(math.max(0, card_width - block_width) * ARMOURY_NATIVE_MODIFIER_HORIZONTAL_PERCENT * 0.01 + 0.5)
		block_top = math.max(0, card_height - STORE_FOOTER_HEIGHT - ARMOURY_NATIVE_FOOTER_GAP - block_height)
	end
	local positions = {
		{ block_left, block_top },
		{ block_left + column_step, block_top },
		{ block_left + column_step * 2, block_top },
		{ block_left, block_top + row_step },
		{ block_left + column_step, block_top + row_step },
	}
	local existing = {
		title = {},
		value = {},
	}

	for index = 1, #(pass_template or {}) do
		local pass = pass_template[index]
		local kind, stat_index = weapon_modifier_pass_kind_and_index(pass)

		if kind and stat_index then
			existing[kind][stat_index] = pass
		end
	end

	for stat_index = 1, 5 do
		for _, kind in ipairs({ "title", "value" }) do
			if not existing[kind][stat_index] then
				local content_id = (kind == "title" and WEAPON_MODIFIER_TITLE_PREFIX or WEAPON_MODIFIER_VALUE_PREFIX) .. stat_index
				local pass = {
					pass_type = "text",
					style_id = content_id,
					value_id = content_id,
					value = "",
					style = {},
					visibility_function = function(content)
						return content and content[content_id] ~= nil and content[content_id] ~= ""
					end,
				}

				pass_template[#pass_template + 1] = pass
				existing[kind][stat_index] = pass
			end
		end
	end

	for index = 1, #(pass_template or {}) do
		local pass = pass_template[index]
		local quick_look_card_pass = is_quick_look_card_pass(pass)
		local kind, stat_index = weapon_modifier_pass_kind_and_index(pass)

		if kind and stat_index then
			local style = pass.style or {}
			local position = positions[stat_index]
			local content_id = (kind == "title" and WEAPON_MODIFIER_TITLE_PREFIX or WEAPON_MODIFIER_VALUE_PREFIX) .. stat_index
			local original_visibility_function = pass.visibility_function

			pass.style = style
			pass.value_id = content_id
			pass.visibility_function = function(content, current_style)
				if content and content[content_id] ~= nil then
					return content[content_id] ~= ""
				end

				return not original_visibility_function or original_visibility_function(content, current_style)
			end
			style.horizontal_alignment = "left"
			style.vertical_alignment = "top"
			style.text_horizontal_alignment = "left"
			style.text_vertical_alignment = "center"
			style.font_size = font_size
			style.drop_shadow = true
			style.offset = {
				position[1] + (kind == "value" and value_offset or 0),
				position[2],
				text_z,
			}
			style.size = {
				kind == "value" and value_width or title_width,
				line_height,
			}
			style.text_color = table.clone(kind == "value" and WEAPON_MODIFIER_VALUE_COLOR or WEAPON_MODIFIER_TITLE_COLOR)

			if kind == "title" then
				pass.change_function = function(content, current_style)
					local target_color = content and content.better_inventory_weapon_modifier_lowest_index == stat_index and lowest_modifier_color or WEAPON_MODIFIER_TITLE_COLOR
					local text_color = current_style.text_color

					for channel = 1, 4 do
						text_color[channel] = target_color[channel]
					end
				end
			end
		elseif quick_look_card_pass then
			pass.visibility_function = function()
				return false
			end
		end
	end
end

local function disable_quick_look_card_passes(pass_template)
	for index = 1, #(pass_template or {}) do
		local pass = pass_template[index]

		if is_quick_look_card_pass(pass) then
			pass.visibility_function = function()
				return false
			end
		end
	end
end

local function preserve_visibility(pass, predicate)
	if not pass then
		return
	end

	local original_visibility_function = pass.visibility_function

	pass.visibility_function = function(content, style)
		if not predicate(content, style) then
			return false
		end

		return not original_visibility_function or original_visibility_function(content, style)
	end
end

local function set_visibility(pass, visible)
	if pass then
		pass.visibility_function = function()
			return visible
		end
	end
end

local function set_height(pass, height)
	local style = pass and pass.style

	if style then
		style.size = style.size or {}
		style.size[2] = height
	end
end

local function configure_native_card_geometry(pass_template, card_height)
	for _, style_id in ipairs({
		"background",
		"background_gradient",
		"button_gradient",
		"inner_shadow",
		"inner_highlight",
		"item_level",
		"rarity_tag",
	}) do
		set_height(pass_by_style_id(pass_template, style_id), card_height)
	end

	local centered_y = card_height * 0.5 - 19

	for _, style_id in ipairs({
		"required_level_background",
		"required_level",
		"warning_message_background",
		"warning_message",
	}) do
		local pass = pass_by_style_id(pass_template, style_id)

		if pass and pass.style and pass.style.offset then
			pass.style.offset[2] = centered_y
		end
	end
end

local function resolved_trait_data(entry, include_textures, include_perk_rank, include_display_name)
	if type(entry) ~= "table" or type(entry.id) ~= "string" then
		return
	end

	local resolved, trait_item = pcall(MasterItems.get_item, entry.id)

	if not resolved or not trait_item then
		return
	end

	local description_ok, description = pcall(Items.trait_description, trait_item, entry.rarity, entry.value)
	local data = {
		description = description_ok and type(description) == "string" and single_line_text(description) or "",
		-- Inventory entries use master-item paths. The stable gameplay identifier
		-- used by gadget trait templates lives on the resolved item's `trait`
		-- field (for example, gadget_innate_health_increase).
		id = type(trait_item.trait) == "string" and trait_item.trait or entry.id,
		rarity = entry.rarity,
	}

	if include_display_name then
		local display_name_ok, display_name = pcall(Items.display_name, trait_item)

		data.display_name = display_name_ok and type(display_name) == "string" and single_line_text(display_name) or ""
	end

	if include_textures then
		local textures_ok, icon, frame = pcall(Items.trait_textures, trait_item, entry.rarity)

		if textures_ok then
			data.icon = icon
			data.frame = frame
		end
	end

	if include_perk_rank then
		local texture_ok, rank = pcall(Items.perk_textures, trait_item, entry.rarity)

		if texture_ok and type(rank) == "string" and rank ~= "" then
			data.rank = rank
		end
	end

	return data
end

local function populate_card_content(mod, widget, element, blessing_display_mode, show_weapon_perks, weapon_perk_compression, compression_mode, simplify_curio_stats, show_weapon_modifiers, show_blessing_text_icons)
	local content = widget and widget.content

	if not content then
		return
	end

	for i = 1, WEAPON_BLESSING_COUNT do
		content["better_inventory_blessing_" .. i] = nil
		content["better_inventory_blessing_text_" .. i] = ""
		content["better_inventory_full_blessing_text_" .. i] = nil
		content["better_inventory_blessing_rank_" .. i] = nil
		content["better_inventory_weapon_perk_" .. i] = ""
		content["better_inventory_full_weapon_perk_" .. i] = nil
		content["better_inventory_weapon_perk_rank_" .. i] = nil
	end

	for i = 1, 4 do
		content["better_inventory_curio_stat_" .. i] = ""
		content["better_inventory_full_curio_stat_" .. i] = nil
	end

	for i = 1, 5 do
		content[WEAPON_MODIFIER_TITLE_PREFIX .. i] = ""
		content[WEAPON_MODIFIER_VALUE_PREFIX .. i] = ""
	end

	content.better_inventory_curio_primary_color = nil

	local item = item_from_element(element or content.element)

	if is_weapon(item) then
		if show_weapon_modifiers then
			populate_weapon_modifier_content(mod, content, item)
		end

		if blessing_display_mode ~= "off" then
			local traits = item.traits
			local blessing_text_mode = blessing_display_mode == "text" or blessing_display_mode == "ranked_text"
			local blessing_ranked_text = blessing_display_mode == "ranked_text"
			local include_blessing_textures = blessing_display_mode == "icons" or blessing_text_mode and show_blessing_text_icons

			for i = 1, math.min(WEAPON_BLESSING_COUNT, traits and #traits or 0) do
				local data = resolved_trait_data(traits[i], include_blessing_textures, blessing_ranked_text, blessing_text_mode)

				if include_blessing_textures and data and data.icon and data.frame then
					content["better_inventory_blessing_" .. i] = data
				end

				if blessing_text_mode and data then
					local name = data.display_name

					if name == "" or name == "-" or name == "n/a" then
						name = data.description
					end

					if name and name ~= "" then
						if blessing_ranked_text then
							content["better_inventory_blessing_text_" .. i] = single_line_text(name)
							content["better_inventory_blessing_rank_" .. i] = data.rank
						else
							local rank_name = blessing_rank_name(data.rarity)

							content["better_inventory_blessing_text_" .. i] = single_line_text(rank_name ~= "" and rank_name .. " " .. name or name)
						end
					end
				end
			end
		end

		if show_weapon_perks then
			local perks = item.perks
			local show_perk_rank = setting(mod, "show_weapon_perk_rank_symbols", true)
			local remove_perk_plus_sign = setting(mod, "remove_weapon_perk_plus_signs", false)

			for i = 1, math.min(WEAPON_PERK_COUNT, perks and #perks or 0) do
				local data = resolved_trait_data(perks[i], false, show_perk_rank)

				if data then
					local description = compact_weapon_perk_description(mod, data, weapon_perk_compression)

					content["better_inventory_weapon_perk_" .. i] = single_line_text(leading_plus_sign_description(description, remove_perk_plus_sign))
					content["better_inventory_weapon_perk_rank_" .. i] = data.rank
				end
			end
		end

		return
	end

	if not is_curio(item) then
		return
	end

	local remove_plus_sign = setting(mod, "remove_curio_stat_plus_signs", false)

	local primary_entry = item.traits and item.traits[1]
	local primary_data = resolved_trait_data(primary_entry, false)

	if primary_data then
		local primary_description = simplified_curio_description(primary_data, simplify_curio_stats)

		content.better_inventory_curio_stat_1 = leading_plus_sign_description(primary_description, remove_plus_sign)
		content.better_inventory_curio_primary_color = curio_primary_color(mod, primary_data.id)
	end

	local perks = item.perks

	for i = 1, math.min(3, perks and #perks or 0) do
		local perk_data = resolved_trait_data(perks[i], false)

		if perk_data then
			local perk_description = compact_curio_description(mod, perk_data, compression_mode)
			perk_description = simplified_curio_description(perk_data, simplify_curio_stats, perk_description)

			content["better_inventory_curio_stat_" .. (i + 1)] = leading_plus_sign_description(perk_description, remove_plus_sign)
		end
	end
end

local function configure_text_pass(pass, options)
	if not pass or not pass.style then
		return
	end

	local style = pass.style

	style.horizontal_alignment = options.horizontal_alignment or "left"
	style.vertical_alignment = options.vertical_alignment or "top"
	style.text_horizontal_alignment = options.text_horizontal_alignment or "left"
	style.text_vertical_alignment = options.text_vertical_alignment or "top"
	style.font_size = options.font_size
	style.offset = options.offset
	style.size = options.size
end

local function add_blessing_pass(pass_template, index, size, x_offset, y_offset)
	local content_id = "better_inventory_blessing_" .. index

	pass_template[#pass_template + 1] = {
		pass_type = "texture",
		style_id = content_id,
		value = BLESSING_MATERIAL,
		style = {
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			material_values = {},
			size = {
				size,
				size,
			},
			offset = {
				x_offset,
				y_offset or -3,
				12,
			},
			color = {
				255,
				255,
				255,
				255,
			},
		},
		visibility_function = function(content)
			return content and content[content_id] ~= nil
		end,
		change_function = function(content, style)
			local data = content and content[content_id]
			local material_values = style and style.material_values

			if data and material_values then
				material_values.icon = data.icon
				material_values.frame = data.frame
			end
		end,
	}
end

local function add_blessing_text_pass(pass_template, index, options)
	local content_id = "better_inventory_blessing_text_" .. index
	local style = table.clone(options.base_style or {})

	style.font_size = options.font_size
	style.horizontal_alignment = "left"
	style.vertical_alignment = "bottom"
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment = "bottom"
	style.word_wrap = false
	style.offset = options.offset
	style.size = options.size
	style.better_inventory_max_text_width = options.size[1]
	style.better_inventory_preferred_font_size = options.font_size
	style.better_inventory_auto_fit_long_name = options.auto_fit_long_name == true
	style.better_inventory_truncate_long_name = options.truncate_long_name == true
	style.text_color = table.clone(options.text_color or DEFAULT_WEAPON_PERK_COLOR)

	pass_template[#pass_template + 1] = {
		pass_type = "text",
		style_id = content_id,
		value = "",
		value_id = content_id,
		style = style,
		visibility_function = function(content)
			return content and content[content_id] ~= nil and content[content_id] ~= ""
		end,
	}
end

local function add_weapon_perk_pass(pass_template, index, options)
	local content_id = "better_inventory_weapon_perk_" .. index
	local style = table.clone(options.base_style or {})

	style.font_size = options.font_size
	style.horizontal_alignment = "left"
	style.vertical_alignment = "bottom"
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment = "bottom"
	style.word_wrap = false
	style.offset = options.offset
	style.size = options.size
	style.better_inventory_max_text_width = options.size[1]
	style.better_inventory_preferred_font_size = options.font_size
	style.text_color = table.clone(options.text_color or DEFAULT_WEAPON_PERK_COLOR)
	style.drop_shadow = true

	pass_template[#pass_template + 1] = {
		pass_type = "text",
		style_id = content_id,
		value = "",
		value_id = content_id,
		style = style,
		visibility_function = function(content)
			return content and content[content_id] ~= nil and content[content_id] ~= ""
		end,
	}
end

local function add_weapon_perk_rank_pass(pass_template, index, options)
	local content_id = "better_inventory_weapon_perk_rank_" .. index

	pass_template[#pass_template + 1] = {
		pass_type = "texture",
		style_id = content_id,
		value = DEFAULT_PERK_RANK_MATERIAL,
		value_id = content_id,
		style = {
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			offset = options.offset,
			size = {
				options.size,
				options.size,
			},
			color = {
				255,
				255,
				255,
				255,
			},
		},
		visibility_function = function(content)
			return content and content[content_id] ~= nil and content[content_id] ~= ""
		end,
	}
end

local function add_blessing_rank_pass(pass_template, index, options)
	local content_id = "better_inventory_blessing_rank_" .. index

	pass_template[#pass_template + 1] = {
		pass_type = "texture",
		style_id = content_id,
		value = DEFAULT_PERK_RANK_MATERIAL,
		value_id = content_id,
		style = {
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			offset = options.offset,
			size = {
				options.size,
				options.size,
			},
			color = {
				255,
				255,
				255,
				255,
			},
		},
		visibility_function = function(content)
			return content and content[content_id] ~= nil and content[content_id] ~= ""
		end,
	}
end

local function add_curio_stat_pass(pass_template, index, options)
	local content_id = "better_inventory_curio_stat_" .. index
	local style = table.clone(options.base_style or {})

	style.font_size = options.font_size
	style.horizontal_alignment = "left"
	style.vertical_alignment = options.vertical_alignment
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment = options.text_vertical_alignment
	style.word_wrap = false
	style.offset = options.offset
	style.size = options.size
	style.better_inventory_max_text_width = options.max_text_width or options.size[1]
	style.text_color = table.clone(options.text_color or DEFAULT_CURIO_PRIMARY_COLOR)

	pass_template[#pass_template + 1] = {
		pass_type = "text",
		style_id = content_id,
		value = "",
		value_id = content_id,
		style = style,
		visibility_function = function(content)
			return content and content[content_id] ~= nil and content[content_id] ~= ""
		end,
		change_function = index == 1 and function(content, style)
			local color = content and content.better_inventory_curio_primary_color or DEFAULT_CURIO_PRIMARY_COLOR
			local text_color = style.text_color

			for channel = 1, 4 do
				text_color[channel] = color[channel]
			end
		end or nil,
	}
end

local function add_name_it_curio_title_pass(pass_template, options)
	local style = table.clone(options.base_style or {})

	style.font_size = options.font_size
	style.horizontal_alignment = "left"
	style.vertical_alignment = "top"
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment = "top"
	style.word_wrap = true
	style.text_fit_with = false
	style.offset = options.offset
	style.size = options.size
	style.drop_shadow = true
	style.text_color = table.clone(DEFAULT_CURIO_SECONDARY_COLOR)
	style.default_color = table.clone(DEFAULT_CURIO_SECONDARY_COLOR)
	style.hover_color = table.clone(DEFAULT_CURIO_SECONDARY_COLOR)

	pass_template[#pass_template + 1] = {
		pass_type = "text",
		style_id = "better_inventory_name_it_curio_name",
		value = "",
		value_id = "better_inventory_name_it_curio_name_text",
		style = style,
		visibility_function = function(content)
			return content and content.better_inventory_name_it_curio_title == true
		end,
	}
end

local function configure_favorite_marker(mod, pass_template, text_left)
	local favorite_icon = pass_by_style_id(pass_template, "favorite_icon")

	if not favorite_icon or not favorite_icon.style then
		return
	end

	local favorite_style = favorite_icon.style
	local favorite_marker_position = setting(mod, "favorite_marker_position", "above_rating")
	local equipped_icon = pass_by_style_id(pass_template, "equipped_icon")
	local myfavorites_hotspot = pass_by_style_id(pass_template, "myfav_hotspot")
	local myfavorites_compatibility = myfavorites_hotspot and myfavorites_hotspot.style
	local myfavorites_show_favorite_letter = myfavorites_compatibility and setting(mod, "myfavorites_show_favorite_letter", false)

	local function align_myfavorites_hotspot(horizontal_alignment, vertical_alignment, offset, size)
		if not myfavorites_compatibility then
			return
		end

		local hotspot_style = myfavorites_hotspot.style
		local resolved_size = size or hotspot_style.size or {
			30,
			28,
		}

		hotspot_style.horizontal_alignment = horizontal_alignment
		hotspot_style.vertical_alignment = vertical_alignment
		hotspot_style.offset = {
			offset[1],
			offset[2],
			math.max(offset[3] or 0, 17),
		}
		hotspot_style.size = {
			resolved_size[1] or 30,
			resolved_size[2] or 28,
		}
	end

	-- Equipped Icon+ extends Darktide's equipped-icon visibility function to
	-- include items equipped in inactive loadouts and changes the icon colour.
	-- Keep the favorite marker below that icon whenever the extension reports
	-- it as visible. Calling the pass function (rather than checking only
	-- content.equipped) keeps this compatible with the mod's configurable
	-- active/inactive colours and avoids a hard dependency on its internals.
	local function equipped_icon_is_visible(content)
		if content and content.equipped then
			return true
		end

		local visibility_function = equipped_icon and equipped_icon.visibility_function

		if not content or type(visibility_function) ~= "function" then
			return false
		end

		local ok, visible = pcall(visibility_function, content, equipped_icon.style)

		return ok and visible == true
	end

	if setting(mod, "compact_favorite_marker", true) then
		favorite_icon.value = ""

		if myfavorites_show_favorite_letter then
			favorite_icon.value = favorite_icon.value .. "\nF"
		end

		favorite_style.font_size = 20
		favorite_style.word_wrap = false
		favorite_style.size = {
			30,
			myfavorites_show_favorite_letter and 48 or 28,
		}

		-- MyFavorites replaces the native favorite value every frame with an
		-- icon plus the localized "Favorite" label (or its hovered colour name).
		-- Narrow BetterInventory cards wrap that label into a vertical column.
		-- Run its original visibility callback first so colour-group state and
		-- hover behavior remain intact, then restore the compact glyph only.
		if myfavorites_compatibility then
			local original_visibility_function = favorite_icon.visibility_function
			local compact_favorite_value = favorite_icon.value

			favorite_icon.visibility_function = function(content, style)
				local visible = type(original_visibility_function) ~= "function" or original_visibility_function(content, style)

				if visible and content then
					content.favorite_icon = compact_favorite_value
				end

				return visible
			end
		end
	end

	if favorite_marker_position == "above_rating" then
		favorite_style.horizontal_alignment = "right"
		favorite_style.vertical_alignment = "top"
		favorite_style.text_horizontal_alignment = "right"
		favorite_style.text_vertical_alignment = "top"
		favorite_style.offset = {
			-8,
			7,
			16,
		}
		align_myfavorites_hotspot("right", "top", favorite_style.offset, favorite_style.size)

		local original_change_function = favorite_icon.change_function

		favorite_icon.change_function = function(content, style, animations, dt)
			if original_change_function then
				original_change_function(content, style, animations, dt)
			end

			local offset_y = equipped_icon_is_visible(content) and 33 or 7

			style.offset[2] = offset_y

			-- ViewElementGrid clones pass styles when it creates a widget. The
			-- creation hook in BetterInventory.lua stores that real runtime hotspot
			-- style on shared widget content, allowing this callback (which Darktide
			-- reliably executes) to keep the click target on the visible marker.
			local runtime_hotspot_style = content and content.better_inventory_myfavorites_hotspot_style

			if runtime_hotspot_style and runtime_hotspot_style.offset then
				runtime_hotspot_style.offset[2] = offset_y
			end
		end
	else
		favorite_style.horizontal_alignment = "left"
		favorite_style.vertical_alignment = "bottom"
		favorite_style.text_horizontal_alignment = "left"
		favorite_style.text_vertical_alignment = "bottom"
		favorite_style.offset = {
			text_left,
			-5,
			16,
		}
		align_myfavorites_hotspot("left", "bottom", favorite_style.offset, favorite_style.size)
	end
end

local function configure_equipped_highlight(mod, pass_template, card_width, card_height)
	local highlight = pass_by_style_id(pass_template, "better_inventory_equipped_highlight")

	if not highlight then
		highlight = {
			pass_type = "texture",
			style_id = "better_inventory_equipped_highlight",
			value = "content/ui/materials/frames/dropshadow_medium",
			style = {},
		}
		pass_template[#pass_template + 1] = highlight
	end

	highlight.style = highlight.style or {}
	highlight.style.horizontal_alignment = "center"
	highlight.style.vertical_alignment = "center"
	highlight.style.scale_to_material = true
	highlight.style.size = {
		card_width,
		card_height,
	}
	highlight.style.size_addition = {
		16,
		16,
	}
	highlight.style.color = {
		255,
		255,
		255,
		255,
	}
	highlight.style.offset = {
		0,
		0,
		3,
	}
	highlight.visibility_function = function(content)
		return setting(mod, "highlight_equipped_items", true) and content and content.equipped == true
	end
end

local function add_custom_content_passes(mod, pass_template, card_width, text_left, base_text_style, configuration)
	configuration = configuration or {}

	local blessing_display_mode = weapon_blessing_display_mode(mod)
	local blessing_text_mode = blessing_display_mode == "text" or blessing_display_mode == "ranked_text"
	local blessing_ranked_text = blessing_display_mode == "ranked_text"
	local show_blessing_text_icons = configuration.native_single_column and blessing_text_mode and setting(mod, "single_column_blessing_icons_on_right", true)
	local show_weapon_perks = setting(mod, "show_weapon_perks", true)
	local show_weapon_perk_ranks = show_weapon_perks and setting(mod, "show_weapon_perk_rank_symbols", true)
	local detailed_curio_profile = setting(mod, "curio_display_profile", "detailed") == "detailed"
	local favorite_marker_position = setting(mod, "favorite_marker_position", "above_rating")
	local store_footer_height = configuration.store_item and STORE_FOOTER_HEIGHT + global_store_extra_height(mod, configuration) or 0
	local expertise_font_size = numeric_setting(mod, "expertise_font_size", 20, 10, 28)
	local item_level_row_height = math.max(30, expertise_font_size + 10)
	local bottom_content_height = item_level_row_height
	local blessing_size
	local blessing_text_height
	local perk_rank_size = weapon_perk_rank_icon_size(mod)

	if blessing_display_mode == "icons" then
		blessing_size = blessing_icon_size(mod)
		local blessing_gap = numeric_setting(mod, "blessing_icon_spacing", 3, 0, 20)
		local blessing_spacing = blessing_size + blessing_gap
		local blessing_left = text_left + (favorite_marker_position == "bottom_left" and 24 or 0)
		local blessing_y_offset = -(store_footer_height + 3)

		for i = 1, WEAPON_BLESSING_COUNT do
			add_blessing_pass(pass_template, i, blessing_size, blessing_left + (i - 1) * blessing_spacing, blessing_y_offset)
		end
	elseif blessing_text_mode then
		local blessing_font_size = numeric_setting(mod, "secondary_text_font_size", 13, 9, 16)
		local blessing_line_height = blessing_ranked_text and math.max(blessing_font_size + 4, perk_rank_size + 1) or blessing_font_size + 4
		local blessing_vertical_spacing = numeric_setting(mod, "weapon_blessing_text_vertical_spacing", 2, 0, 20)
		local blessing_bottom_padding = numeric_setting(mod, "weapon_blessing_text_bottom_padding", 4, 0, 20)
		local blessing_line_step = blessing_line_height + blessing_vertical_spacing
		local separate_item_level = separate_blessing_text_and_item_level(mod, configuration)
		local favorite_offset = favorite_marker_position == "bottom_left" and not separate_item_level and 24 or 0
		local blessing_rank_left = text_left + favorite_offset
		local blessing_text_left = blessing_rank_left + (blessing_ranked_text and perk_rank_size + PERK_RANK_GAP or 0)
		local reserved_right = separate_item_level and 8 or 50
		local content_right = configuration.content_right or card_width - reserved_right
		local side_icon_size = show_blessing_text_icons and blessing_icon_size(mod) or 0
		local side_icon_gap = show_blessing_text_icons and numeric_setting(mod, "blessing_icon_spacing", 3, 0, 20) or 0
		local side_icon_pair_width = show_blessing_text_icons and WEAPON_BLESSING_COUNT * side_icon_size + (WEAPON_BLESSING_COUNT - 1) * side_icon_gap or 0
		local side_icon_left = show_blessing_text_icons and math.min(content_right - side_icon_pair_width, blessing_text_left + 110) or content_right
		local blessing_text_right = show_blessing_text_icons and side_icon_left - 8 or content_right
		local blessing_text_width = math.max(40, blessing_text_right - blessing_text_left)
		local blessing_text_color = configured_text_color(mod, "weapon_blessing_text_color", DEFAULT_WEAPON_BLESSING_TEXT_COLOR, "weapon_blessing_text_opacity")
		local auto_fit_long_name = setting(mod, "auto_fit_long_blessing_names", true)
		local truncate_long_name = setting(mod, "truncate_long_blessing_names", false)
		local reserved_bottom_row = separate_item_level and (configuration.store_item and store_footer_height or item_level_row_height) or store_footer_height

		blessing_text_height = WEAPON_BLESSING_COUNT * blessing_line_height + (WEAPON_BLESSING_COUNT - 1) * blessing_vertical_spacing

		if show_blessing_text_icons then
			blessing_text_height = math.max(blessing_text_height, side_icon_size)

			for i = 1, WEAPON_BLESSING_COUNT do
				add_blessing_pass(pass_template, i, side_icon_size, side_icon_left + (i - 1) * (side_icon_size + side_icon_gap), -(reserved_bottom_row + blessing_bottom_padding))
			end
		end

		for i = 1, WEAPON_BLESSING_COUNT do
			local y_offset = -(reserved_bottom_row + blessing_bottom_padding + (WEAPON_BLESSING_COUNT - i) * blessing_line_step)

			if blessing_ranked_text then
				add_blessing_rank_pass(pass_template, i, {
					size = perk_rank_size,
					offset = {
						blessing_rank_left,
						y_offset,
						11,
					},
				})
			end

			add_blessing_text_pass(pass_template, i, {
				base_style = base_text_style,
				font_size = blessing_font_size,
				text_color = blessing_text_color,
				auto_fit_long_name = auto_fit_long_name,
				truncate_long_name = truncate_long_name,
				offset = {
					blessing_text_left,
					y_offset,
					11,
				},
				size = {
					blessing_text_width,
					blessing_line_height,
				},
			})
		end
	end

	if configuration.store_item then
		if blessing_display_mode == "icons" then
			bottom_content_height = store_footer_height + blessing_size + 6
		elseif blessing_text_mode then
			local blessing_bottom_padding = numeric_setting(mod, "weapon_blessing_text_bottom_padding", 4, 0, 20)

			bottom_content_height = store_footer_height + blessing_text_height + blessing_bottom_padding + 3
		else
			bottom_content_height = store_footer_height
		end
	elseif blessing_display_mode == "icons" then
		bottom_content_height = math.max(bottom_content_height, blessing_size + 6)
	elseif blessing_text_mode then
		local blessing_bottom_padding = numeric_setting(mod, "weapon_blessing_text_bottom_padding", 4, 0, 20)

		if separate_blessing_text_and_item_level(mod, configuration) then
			bottom_content_height = bottom_content_height + blessing_text_height + blessing_bottom_padding + 3
		else
			bottom_content_height = math.max(bottom_content_height, blessing_text_height + blessing_bottom_padding + 3)
		end
	end

	-- GlobalStore's native card reserves a character row below the price row.
	-- Lift the perk block slightly into the icon area so the weapon name and
	-- first perk retain the tighter spacing used by the two-column cards.
	if configuration.native_single_column and configuration.global_store then
		bottom_content_height = bottom_content_height + 8
	end

	if show_weapon_perks then
		local perk_font_size = numeric_setting(mod, "secondary_text_font_size", 13, 9, 16)
		local perk_line_height = show_weapon_perk_ranks and math.max(perk_font_size + 4, perk_rank_size + 1) or perk_font_size + 4
		local perk_vertical_spacing = numeric_setting(mod, "weapon_perk_vertical_spacing", 2, 0, 20)
		local perk_line_step = perk_line_height + perk_vertical_spacing
		local section_spacing = blessing_display_mode ~= "off" and numeric_setting(mod, "weapon_perk_blessing_spacing", 5, 0, 20) or 2
		local perk_text_left = text_left + (show_weapon_perk_ranks and perk_rank_size + PERK_RANK_GAP or 0)
		local perk_text_right = configuration.content_right or card_width - 8
		local perk_width = math.max(40, perk_text_right - perk_text_left)
		local perk_text_color = configured_text_color(mod, "weapon_perk_text_color", DEFAULT_WEAPON_PERK_COLOR, "weapon_perk_text_opacity")

		for i = 1, WEAPON_PERK_COUNT do
			local y_offset = -(bottom_content_height + section_spacing + (WEAPON_PERK_COUNT - i) * perk_line_step)

			if show_weapon_perk_ranks then
				add_weapon_perk_rank_pass(pass_template, i, {
					size = perk_rank_size,
					offset = {
						text_left,
						y_offset,
						11,
					},
				})
			end

			add_weapon_perk_pass(pass_template, i, {
				base_style = base_text_style,
				font_size = perk_font_size,
				text_color = perk_text_color,
				offset = {
					perk_text_left,
					y_offset,
					11,
				},
				size = {
					perk_width,
					perk_line_height,
				},
			})
		end
	end

	if detailed_curio_profile then
		local primary_font_size = curio_primary_font_size(mod)
		local secondary_font_size = curio_secondary_font_size(mod)
		local primary_secondary_spacing = curio_primary_secondary_spacing(mod)
		local secondary_text_color = configured_text_color(mod, "curio_secondary_text_color", DEFAULT_CURIO_SECONDARY_COLOR)
		local show_name_it_curio_title = name_it_curio_title_enabled(mod, configuration)
		local title_height = show_name_it_curio_title and curio_name_title_height(mod, configuration) or 0
		local y_offset = 7 + title_height

		if show_name_it_curio_title then
			add_name_it_curio_title_pass(pass_template, {
				base_style = base_text_style,
				font_size = curio_name_font_size(mod, configuration),
				offset = {
					text_left,
					7,
					11,
				},
				size = {
					math.max(40, card_width - text_left - 40),
					title_height,
				},
			})
		end

		for i = 1, 4 do
			if i == 2 then
				y_offset = y_offset + primary_secondary_spacing
			end

			local font_size = i == 1 and primary_font_size or secondary_font_size
			local line_height = font_size + 5
			local reserved_right = i <= 2 and 40 or 8
			local render_width = math.max(40, card_width - text_left - 4)
			local max_text_width = math.max(36, card_width - text_left - reserved_right - 4)

			add_curio_stat_pass(pass_template, i, {
				base_style = base_text_style,
				font_size = font_size,
				text_color = i == 1 and DEFAULT_CURIO_PRIMARY_COLOR or secondary_text_color,
				vertical_alignment = "top",
				text_vertical_alignment = "top",
				offset = {
					text_left,
					y_offset,
					11,
				},
				size = {
					render_width,
					line_height,
				},
				max_text_width = max_text_width,
			})

			y_offset = y_offset + line_height
		end
	else
		local primary_font_size = curio_primary_font_size(mod)
		local primary_line_height = math.max(20, primary_font_size + 5)

		add_curio_stat_pass(pass_template, 1, {
			base_style = base_text_style,
			font_size = primary_font_size,
			vertical_alignment = "bottom",
			text_vertical_alignment = "bottom",
			offset = {
				text_left,
				-(store_footer_height + math.max(31, primary_line_height + 11)),
				11,
			},
			size = {
				math.max(40, card_width - text_left - 40),
				primary_line_height,
			},
		})
	end
end


local function format_item_level(widget, element, show_item_level_icon)
	if show_item_level_icon then
		return
	end

	local content = widget and widget.content
	local item = item_from_element(element or content and content.element)

	if not content or not item then
		return
	end

	local success, item_level, has_item_level = pcall(Items.expertise_level, item, true)

	if success then
		content.item_level = has_item_level and item_level or ""
	end
end

local function fit_display_name(parent, widget, ui_renderer, preferred_font_size, minimum_font_size)
	local content = widget and widget.content
	local style = widget and widget.style and widget.style.display_name
	local display_name = content and content.display_name

	if not style or type(display_name) ~= "string" or display_name == "" then
		return
	end

	if content.better_inventory_name_it_curio_title then
		local title_style = widget.style and widget.style.better_inventory_name_it_curio_name

		if not title_style then
			return
		end

		ui_renderer = ui_renderer or grid_ui_renderer(parent)

		if not ui_renderer then
			return
		end

		local title_text = content.better_inventory_name_it_curio_name_text or display_name

		if title_text ~= content.better_inventory_fitted_name_it_curio_name then
			content.better_inventory_name_it_curio_full_name = string.gsub(title_text, "[\r\n]+", " ")
		end

		local full_name = content.better_inventory_name_it_curio_full_name or title_text
		local maximum_width = title_style.size and title_style.size[1]
		local maximum_lines = 2
		local minimum_title_font_size = math.min(title_style.font_size or 16, 12)

		if type(maximum_width) ~= "number" then
			return
		end

		local wrapped_rows = Text.word_wrap(ui_renderer, full_name, title_style, maximum_width)

		while wrapped_rows and #wrapped_rows > maximum_lines and title_style.font_size > minimum_title_font_size do
			title_style.font_size = title_style.font_size - 1
			wrapped_rows = Text.word_wrap(ui_renderer, full_name, title_style, maximum_width)
		end

		if wrapped_rows and #wrapped_rows > 0 then
			local fitted_rows = {}

			for index = 1, math.min(maximum_lines, #wrapped_rows) do
				fitted_rows[index] = wrapped_rows[index]
			end

			if #wrapped_rows > maximum_lines then
				fitted_rows[maximum_lines] = Text.crop_text_width(ui_renderer, fitted_rows[maximum_lines] .. "...", title_style, maximum_width)
			end

			content.better_inventory_name_it_curio_name_text = table.concat(fitted_rows, "\n")
			content.better_inventory_fitted_name_it_curio_name = content.better_inventory_name_it_curio_name_text
		end

		return
	end

	ui_renderer = ui_renderer or grid_ui_renderer(parent)

	if not ui_renderer then
		return
	end

	local maximum_width = style.size and style.size[1]
	preferred_font_size = preferred_font_size or style.font_size

	if not maximum_width or not preferred_font_size then
		return
	end

	minimum_font_size = math.min(preferred_font_size, minimum_font_size)
	style.word_wrap = false
	style.font_size = preferred_font_size

	local measurement_size = {
		1000000,
		style.size[2] or 30,
	}
	local measured_width = Text.text_width(ui_renderer, display_name, style, measurement_size, true)

	while measured_width > maximum_width and style.font_size > minimum_font_size do
		style.font_size = style.font_size - 1
		measured_width = Text.text_width(ui_renderer, display_name, style, measurement_size, true)
	end

	content.better_inventory_full_display_name = display_name

	if measured_width > maximum_width then
		local base_name = content.better_inventory_display_name_base
		local suffix = content.better_inventory_display_name_suffix

		if base_name and suffix then
			local suffix_width = Text.text_width(ui_renderer, suffix, style, measurement_size, true)
			local maximum_base_width = maximum_width - suffix_width

			if maximum_base_width > 0 then
				local base_width = Text.text_width(ui_renderer, base_name, style, measurement_size, true)
				local fitted_base_name = base_width > maximum_base_width and Text.crop_text_width(ui_renderer, base_name, style, maximum_base_width) or base_name

				content.display_name = fitted_base_name .. suffix

				return
			end
		end

		content.display_name = Text.crop_text_width(ui_renderer, display_name, style, maximum_width)
	end
end

local function fit_curio_stats(parent, widget, ui_renderer)
	local content = widget and widget.content
	local styles = widget and widget.style

	if not content or not styles then
		return
	end

	ui_renderer = ui_renderer or grid_ui_renderer(parent)

	if not ui_renderer then
		return
	end

	local measurement_size = {
		1000000,
		30,
	}

	for i = 1, 4 do
		local content_id = "better_inventory_curio_stat_" .. i
		local style = styles[content_id]
		local value = content[content_id]
		local maximum_width = style and (style.better_inventory_max_text_width or style.size and style.size[1])

		if type(value) == "string" and value ~= "" and maximum_width then
			content["better_inventory_full_curio_stat_" .. i] = value
			measurement_size[2] = style.size[2] or 30

			if Text.text_width(ui_renderer, value, style, measurement_size, true) > maximum_width then
				content[content_id] = Text.crop_text_width(ui_renderer, value, style, maximum_width)
			end
		end
	end
end

local function fit_blessing_text(parent, widget, ui_renderer)
	local content = widget and widget.content
	local styles = widget and widget.style

	if not content or not styles then
		return
	end

	ui_renderer = ui_renderer or grid_ui_renderer(parent)

	if not ui_renderer then
		return
	end

	local measurement_size = {
		1000000,
		30,
	}

	for i = 1, WEAPON_BLESSING_COUNT do
		local content_id = "better_inventory_blessing_text_" .. i
		local style = styles[content_id]
		local value = content[content_id]
		local maximum_width = style and (style.better_inventory_max_text_width or style.size and style.size[1])

		if type(value) == "string" and value ~= "" and maximum_width then
			local preferred_font_size = style.better_inventory_preferred_font_size or style.font_size
			local minimum_font_size = math.min(preferred_font_size, MINIMUM_AUTO_FIT_BLESSING_FONT_SIZE)
			local auto_fit_long_name = style.better_inventory_auto_fit_long_name == true
			local truncate_long_name = style.better_inventory_truncate_long_name == true
			local safe_width = math.max(1, maximum_width - BLESSING_TEXT_WIDTH_SAFETY_MARGIN)
			measurement_size[2] = style.size[2] or 30

			style.font_size = preferred_font_size
			style.word_wrap = true
			content["better_inventory_full_blessing_text_" .. i] = value

			local measured_width = Text.text_width(ui_renderer, value, style, measurement_size, true)

			while auto_fit_long_name and measured_width > safe_width and style.font_size > minimum_font_size do
				style.font_size = style.font_size - 1
				measured_width = Text.text_width(ui_renderer, value, style, measurement_size, true)
			end

			if truncate_long_name and measured_width > safe_width then
				content[content_id] = Text.crop_text_width(ui_renderer, value, style, safe_width)
			end

			if measured_width <= safe_width or truncate_long_name then
				-- Darktide can wrap on glyph-boundary rounding even when the measured
				-- width equals the style width. The small safety margin and explicit
				-- no-wrap state keep the item-level area clear.
				style.word_wrap = false
			end

		end
	end
end

local function fit_weapon_perks(parent, widget, ui_renderer)
	local content = widget and widget.content
	local styles = widget and widget.style

	if not content or not styles then
		return
	end

	ui_renderer = ui_renderer or grid_ui_renderer(parent)

	if not ui_renderer then
		return
	end

	local measurement_size = {
		1000000,
		30,
	}

	for i = 1, WEAPON_PERK_COUNT do
		local content_id = "better_inventory_weapon_perk_" .. i
		local style = styles[content_id]
		local value = content[content_id]
		local maximum_width = style and (style.better_inventory_max_text_width or style.size and style.size[1])

		if type(value) == "string" and value ~= "" and maximum_width then
			local preferred_font_size = style.better_inventory_preferred_font_size or style.font_size
			local minimum_font_size = math.min(preferred_font_size, 9)
			measurement_size[2] = style.size[2] or 30

			style.font_size = preferred_font_size
			content["better_inventory_full_weapon_perk_" .. i] = value

			local measured_width = Text.text_width(ui_renderer, value, style, measurement_size, true)

			while measured_width > maximum_width and style.font_size > minimum_font_size do
				style.font_size = style.font_size - 1
				measured_width = Text.text_width(ui_renderer, value, style, measurement_size, true)
			end

			if measured_width > maximum_width then
				content[content_id] = Text.crop_text_width(ui_renderer, value, style, maximum_width)
			end
		end
	end
end

local function grid_weapon_name_font_size(mod, configuration)
	local default_font_size = numeric_setting(mod, "item_name_font_size", 16, 10, 24)
	local maximum_columns = configuration and configuration.maximum_columns

	-- The temporary compact-name override is intentionally scoped to Armoury
	-- store cards. Inventory and Hadron cards retain the general grid setting.
	if configuration and configuration.store_item == true and Layout.columns(mod, maximum_columns) == 3 then
		return numeric_setting(mod, "three_column_weapon_name_font_size", 14, 10, 20)
	end

	return default_font_size
end

local function configure_card_content(mod, item_blueprint, configuration)
	configuration = configuration or {}
	local original_init = item_blueprint.init
	local original_update = item_blueprint.update
	local original_update_data = item_blueprint.update_data
	local preferred_font_size = configuration.native_single_column and numeric_setting(mod, "single_column_weapon_name_font_size", 20, 10, 24) or grid_weapon_name_font_size(mod, configuration)
	local minimum_font_size = numeric_setting(mod, "minimum_item_name_font_size", 12, 8, 20)
	local append_mark_to_name = setting(mod, "append_mark_to_name", true)
	local blessing_display_mode = weapon_blessing_display_mode(mod)
	local show_weapon_perks = setting(mod, "show_weapon_perks", true)
	local weapon_perk_compression = setting(mod, "weapon_perk_compression", "heavy")
	local show_item_level_icon = setting(mod, "show_item_level_icon", false)
	local compression_mode = setting(mod, "curio_stat_compression", "heavy")
	local show_weapon_modifiers = configuration.weapon_modifier_stats_enabled == true
	local show_blessing_text_icons = configuration.native_single_column and setting(mod, "single_column_blessing_icons_on_right", true)
	-- Keep the original setting ID so existing user configurations migrate
	-- without any reset; its scope now includes supported secondary Curio perks.
	local simplify_curio_stats = setting(mod, "simplify_curio_primary_stat_text", true)

	-- Accept the retired checkbox values during the one-time settings migration
	-- and when hot-reloading from an older options schema.
	if compression_mode == true then
		compression_mode = "compression"
	elseif compression_mode == false then
		compression_mode = "none"
	end

	if original_init then
		item_blueprint.init = function(parent, widget, element, callback_name, secondary_callback_name, ui_renderer, double_click_callback, template)
			original_init(parent, widget, element, callback_name, secondary_callback_name, ui_renderer, double_click_callback, template)
			format_item_name(mod, widget, element, append_mark_to_name)
			synchronize_rarity_tag_color(widget, element)
			apply_item_customization_style(mod, widget, element)
			format_item_level(widget, element, show_item_level_icon)
			populate_card_content(mod, widget, element, blessing_display_mode, show_weapon_perks, weapon_perk_compression, compression_mode, simplify_curio_stats, show_weapon_modifiers, show_blessing_text_icons)
			fit_display_name(parent, widget, ui_renderer, preferred_font_size, math.min(preferred_font_size, minimum_font_size))
			fit_blessing_text(parent, widget, ui_renderer)
			fit_weapon_perks(parent, widget, ui_renderer)
			fit_curio_stats(parent, widget, ui_renderer)
		end
	end

	if original_update_data then
		item_blueprint.update_data = function(parent, widget, element)
			-- A widget can be reused for a different equipped item. Remove the
			-- previous item's overrides before the native/data refresh establishes
			-- the new card's baseline colors.
			restore_item_customization_style(widget)
			original_update_data(parent, widget, element)
			format_item_name(mod, widget, element, append_mark_to_name)
			synchronize_rarity_tag_color(widget, element)
			apply_item_customization_style(mod, widget, element)
			format_item_level(widget, element, show_item_level_icon)
			populate_card_content(mod, widget, element, blessing_display_mode, show_weapon_perks, weapon_perk_compression, compression_mode, simplify_curio_stats, show_weapon_modifiers, show_blessing_text_icons)
			fit_display_name(parent, widget, nil, preferred_font_size, math.min(preferred_font_size, minimum_font_size))
			fit_blessing_text(parent, widget, nil)
			fit_weapon_perks(parent, widget, nil)
			fit_curio_stats(parent, widget, nil)
		end
	end

end

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

Layout.slot_kind = function(view)
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
Layout.store_slot_kind = function(view, layout)
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

	return slot_kind_from_slot_types(tab_content and tab_content.slot_types) or Layout.slot_kind(view)
end

Layout.is_enabled_for_view = function(mod, view)
	local slot_kind = Layout.slot_kind(view)

	if slot_kind == "curio" then
		return setting(mod, "enable_curio_inventory", true)
	end

	local setting_id = SLOT_SETTING_BY_NAME[slot_kind]

	return setting_id and setting(mod, setting_id, true) or false
end

Layout.columns = function(mod, maximum_columns, slot_kind)
	local column_limit = math.floor(math.max(2, math.min(5, tonumber(maximum_columns) or 5)))
	local setting_id = COLUMN_SETTING_BY_SLOT[slot_kind]

	local configured_columns = setting_id and tonumber(mod:get(setting_id))

	if not setting_id or configured_columns == nil then
		setting_id = "columns"
	end

	local requested_columns = math.floor(numeric_setting(mod, setting_id, 3, 2, 5))

	return math.max(2, math.min(column_limit, requested_columns))
end

local function weapon_extra_width_applies(mod, columns)
	local threshold = setting(mod, "weapon_extra_width_column_threshold", "four_plus")

	return columns >= (threshold == "five_only" and 5 or 4)
end

Layout.grid_expansion = function(mod, current_grid_width, slot_kind)
	current_grid_width = tonumber(current_grid_width)

	if not current_grid_width or current_grid_width <= 0 then
		return 0
	end

	if not setting(mod, "enable_grid_layout", true) or not setting(mod, "expand_inventory_window", true) then
		return 0
	end

	local columns = Layout.columns(mod, nil, slot_kind)
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

Layout.armoury_grid_expansion = function(mod, current_grid_width, grid_setting_id, slot_kind)
	current_grid_width = tonumber(current_grid_width)
	grid_setting_id = grid_setting_id or "enable_armoury_requisition_grid"

	if not current_grid_width or current_grid_width <= 0 then
		return 0
	end

	if not setting(mod, "enable_grid_layout", true) or not setting(mod, grid_setting_id, true) or not setting(mod, "expand_armoury_requisition_window", true) then
		return 0
	end

	local columns = Layout.columns(mod, 3, slot_kind)
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

Layout.expanded_armoury_view_definitions = function(mod, definitions, base_definitions, grid_setting_id, slot_kind)
	local grid_settings = definitions and definitions.grid_settings
	local grid_size = grid_settings and grid_settings.grid_size
	local current_grid_width = grid_size and grid_size[1]

	if type(current_grid_width) ~= "number" or current_grid_width <= 0 then
		return definitions, 0
	end

	local native_armoury = grid_setting_id == nil
	local expansion = Layout.armoury_grid_expansion(mod, current_grid_width, grid_setting_id, slot_kind)

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

Layout.expanded_global_store_view_definitions = function(mod, definitions, base_definitions, slot_kind)
	return Layout.expanded_armoury_view_definitions(mod, definitions, base_definitions, "enable_global_store_grid", slot_kind)
end

Layout.expanded_view_definitions = function(mod, definitions, view)
	local grid_settings = definitions and definitions.grid_settings
	local grid_size = grid_settings and grid_settings.grid_size
	local current_grid_width = grid_size and grid_size[1]

	if type(current_grid_width) ~= "number" or current_grid_width <= 0 then
		return definitions, 0
	end

	local slot_kind = Layout.slot_kind(view)
	local requested_expansion = Layout.grid_expansion(mod, current_grid_width, slot_kind)
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

Layout.card_height = function(mod, configuration)
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

Layout.item_size = function(mod, grid_width, maximum_columns, configuration)
	grid_width = tonumber(grid_width)
	local slot_kind = configuration and configuration.slot_kind

	if not grid_width or grid_width <= 0 then
		grid_width = MINIMUM_CARD_WIDTH * Layout.columns(mod, maximum_columns, slot_kind)
	end

	local columns = Layout.columns(mod, maximum_columns, slot_kind)
	local spacing = numeric_setting(mod, "grid_spacing", 10, 0, 40)
	local height = Layout.card_height(mod, configuration)
	local width = math.floor((grid_width - spacing * (columns - 1)) / columns)

	return {
		math.max(60, width),
		height,
	}
end

Layout.configure_grid = function(mod, item_grid)
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

Layout.configure_native_item_blueprint = function(mod, item_blueprint, grid_width, configuration)
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
			item_size[2] = math.max(item_size[2] or 110, Layout.card_height(mod, native_configuration))
		end
	end

	item_blueprint.size = item_size
	item_blueprint.pass_template = pass_template

	if managed_native_card then
		configure_native_card_geometry(pass_template, item_size[2] or 110)
	end

	if weapon_modifier_stats_enabled then
		configure_native_quick_look_card_passes(mod, pass_template, card_width, item_size[2] or 110, configuration)
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
		return not detailed_curio_profile or not is_curio(item_from_content(content))
	end)

	if sub_display_name then
		sub_display_name.visibility_function = function(content)
			local item = item_from_content(content)

			if is_curio(item) then
				return show_curio_quality and not detailed_curio_profile
			end

			return is_weapon(item) and show_pattern_mark
		end
	end

	if rarity_name then
		local show_weapon_quality = setting(mod, "show_rarity_name", false)

		rarity_name.visibility_function = function(content)
			return show_weapon_quality and is_weapon(item_from_content(content))
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
		return not is_curio(item_from_content(content)) or show_curio_item_level
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
			content_right = weapon_modifier_stats_enabled and 260 or nil,
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
		weapon_modifier_stats_enabled = weapon_modifier_stats_enabled,
	})

	return item_size
end


Layout.configure_item_blueprint = function(mod, item_blueprint, grid_width, configuration)
	if not setting(mod, "enable_grid_layout", true) then
		configuration = configuration or {}
		return Layout.configure_native_item_blueprint(mod, item_blueprint, grid_width, configuration)
	end

	configuration = configuration or {}
	local global_store = configuration.global_store == true
	local global_store_extra = global_store_extra_height(mod, configuration)
	local global_store_multicolumn = global_store_extra > 0
	local global_store_photo_size = global_store_multicolumn and global_store_character_photo_size(mod) or 34
	local global_store_info_gap = global_store_multicolumn and global_store_character_info_gap(mod) or 0
	local global_store_class_icon_size = global_store_multicolumn and global_store_character_class_icon_size(mod) or GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_DEFAULT
	local global_store_name_font_size = global_store_multicolumn and global_store_character_name_font_size(mod) or GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_DEFAULT
	local global_store_compact_character_names = global_store_multicolumn and setting(mod, "global_store_compact_character_names", true) and Layout.columns(mod, configuration.maximum_columns, configuration.slot_kind) >= 4 or false
	local global_store_price_padding = global_store_multicolumn and global_store_price_row_padding(mod) or 0
	local global_store_price_row_offset = global_store_multicolumn and GLOBAL_STORE_CHARACTER_ROW_HEIGHT + global_store_price_padding or 0

	local item_size = Layout.item_size(mod, grid_width, configuration.maximum_columns, configuration)
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
		return not detailed_curio_profile or not is_curio(item_from_content(content))
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
			local item = item_from_content(content)

			if is_curio(item) then
				return show_curio_quality and not detailed_curio_profile
			end

			return is_weapon(item) and show_pattern_mark
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
			return show_weapon_quality and is_weapon(item_from_content(content))
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
		return not is_curio(item_from_content(content)) or show_curio_item_level
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

return Layout
