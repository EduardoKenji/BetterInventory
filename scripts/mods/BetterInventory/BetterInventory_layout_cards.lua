local Text = require("scripts/utilities/ui/text")
local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")
local LayoutContent = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_content")

local Cards = {}
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
local SINGLE_LINE_WEAPON_NAME_MINIMUM_SAFETY_MARGIN = 8
local NON_BREAKING_SPACE = string.char(194, 160)

local function non_wrapping_title(value)
	return string.gsub(value, " ", NON_BREAKING_SPACE)
end

local function rendered_title_width(ui_renderer, value, style, measurement_size, force_single_line)
	value = force_single_line and non_wrapping_title(value) or value

	return Text.text_width(ui_renderer, value, style, measurement_size, true)
end

local function strictly_crop_title(ui_renderer, value, style, measurement_size, maximum_width, force_single_line)
	local crop_width = maximum_width
	local cropped = Text.crop_text_width(ui_renderer, value, style, crop_width)
	local cropped_width = rendered_title_width(ui_renderer, cropped, style, measurement_size, force_single_line)
	local attempts = 0

	-- Darktide's crop helper estimates room for its ellipsis. Re-measure the
	-- actual result because font extents can exceed that estimate by a glyph.
	while cropped_width > maximum_width and crop_width > 1 and attempts < 16 do
		local overrun = math.max(1, math.ceil(cropped_width - maximum_width))
		crop_width = math.max(1, crop_width - overrun - 1)
		cropped = Text.crop_text_width(ui_renderer, value, style, crop_width)
		cropped_width = rendered_title_width(ui_renderer, cropped, style, measurement_size, force_single_line)
		attempts = attempts + 1
	end

	return cropped
end

local NATIVE_SINGLE_COLUMN_CONTENT_GAP = content.NATIVE_SINGLE_COLUMN_CONTENT_GAP
local COLUMN_SETTING_BY_SLOT = content.COLUMN_SETTING_BY_SLOT
local GLOBAL_STORE_CHARACTER_ROW_HEIGHT = content.GLOBAL_STORE_CHARACTER_ROW_HEIGHT
local GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_DEFAULT = content.GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_DEFAULT
local GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_DEFAULT = content.GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_DEFAULT
local GLOBAL_STORE_CHARACTER_NAME_FIT_SAFETY_MARGIN = content.GLOBAL_STORE_CHARACTER_NAME_FIT_SAFETY_MARGIN

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

Cards.set_item_customization_provider = function(provider)
	content.set_item_customization_provider(provider)
end

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

					if text_color[1] ~= target_color[1] or text_color[2] ~= target_color[2] or text_color[3] ~= target_color[3] or text_color[4] ~= target_color[4] then
						for channel = 1, 4 do
							text_color[channel] = target_color[channel]
						end
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
	content.better_inventory_quick_look_card_dump_stat_visibility_resolved = nil
	content.better_inventory_quick_look_card_dump_stat_parenthesized = nil

	local item = item_from_element(element or content.element)
	local weapon = is_weapon(item)
	local curio = not weapon and is_curio(item)
	content.better_inventory_is_weapon = weapon
	content.better_inventory_is_curio = curio

	if weapon then
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

	if not curio then
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
				if material_values.icon ~= data.icon then
					material_values.icon = data.icon
				end

				if material_values.frame ~= data.frame then
					material_values.frame = data.frame
				end
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

			if text_color[1] ~= color[1] or text_color[2] ~= color[2] or text_color[3] ~= color[3] or text_color[4] ~= color[4] then
				for channel = 1, 4 do
					text_color[channel] = color[channel]
				end
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

			-- The runtime grid synchronizer performs the integration callback only
			-- when equipped/favorite generations change. Draw-time callbacks use
			-- that cached result instead of issuing one protected call per card per
			-- frame (which scales badly on large inventories).
			local equipped_visible = content and (content.equipped == true or content.better_inventory_equipped_icon_visible == true)
			local offset_y = equipped_visible and 33 or 7

			if style.offset[2] ~= offset_y then
				style.offset[2] = offset_y
			end

			-- ViewElementGrid clones pass styles when it creates a widget. The
			-- creation hook in BetterInventory.lua stores that real runtime hotspot
			-- style on shared widget content, allowing this callback (which Darktide
			-- reliably executes) to keep the click target on the visible marker.
			local runtime_hotspot_style = content and content.better_inventory_myfavorites_hotspot_style

			if runtime_hotspot_style and runtime_hotspot_style.offset and runtime_hotspot_style.offset[2] ~= offset_y then
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

local EQUIPPED_HIGHLIGHT_STYLE_PREFIX = "better_inventory_equipped_highlight"
local PULSING_DASH_ANGULAR_SPEED = math.pi * 0.5
local PULSING_DASH_MIN_ALPHA = math.floor(255 * 0.15 + 0.5)
local cached_pulsing_dash_time
local cached_pulsing_dash_alpha = PULSING_DASH_MIN_ALPHA

-- One complete 15% -> 100% -> 15% opacity cycle every four seconds. Darktide uses
-- this same global clock pattern for its native new-item marker, so no timer or
-- mutable animation state is retained by a card or view. A bounded two-scalar
-- module cache avoids repeating cosine work for every visible layer in a frame.
local function update_pulsing_dash_alpha(_, style)
	local time = Application.time_since_launch()

	if time ~= cached_pulsing_dash_time then
		local pulse = (1 - math.cos(time * PULSING_DASH_ANGULAR_SPEED)) * 0.5

		cached_pulsing_dash_time = time
		cached_pulsing_dash_alpha = math.floor(PULSING_DASH_MIN_ALPHA + (255 - PULSING_DASH_MIN_ALPHA) * pulse + 0.5)
	end

	style.color[1] = cached_pulsing_dash_alpha
end

local function clear_equipped_highlight_passes(pass_template)
	for index = #pass_template, 1, -1 do
		local style_id = pass_template[index] and pass_template[index].style_id

		if style_id == EQUIPPED_HIGHLIGHT_STYLE_PREFIX or type(style_id) == "string" and string.sub(style_id, 1, #EQUIPPED_HIGHLIGHT_STYLE_PREFIX + 1) == EQUIPPED_HIGHLIGHT_STYLE_PREFIX .. "_" then
			table.remove(pass_template, index)
		end
	end
end

local function configure_equipped_highlight(mod, pass_template, card_width, card_height)
	local mode = setting(mod, "highlight_equipped_items", "animated_dashes")

	-- Accept saved checkbox values until the v2.2.1 migration runs. Unknown
	-- future/corrupt values fail closed instead of creating an invalid pass.
	if mode == true then
		mode = "animated_dashes"
	elseif mode == false then
		mode = "off"
	elseif mode ~= "soft_glow" and mode ~= "animated_dashes" and mode ~= "pulsing_dashes" and mode ~= "solid_border" then
		mode = "off"
	end

	-- Blueprints can be presented more than once by chained integrations. Remove
	-- only our owned passes before rebuilding the bounded mode-specific set.
	clear_equipped_highlight_passes(pass_template)

	if mode == "off" then
		return
	end

	local alpha = 255
	local material = "content/ui/materials/frames/dropshadow_medium"
	local pass_count = 1
	local base_size_addition = 16
	local layer_size_step = 0
	local z_offset = 3

	if mode == "animated_dashes" or mode == "pulsing_dashes" then
		-- Native material owns its GPU animation. No Lua timer, widget state, or
		-- per-frame allocation is needed. Concentric static passes thicken its
		-- fixed one-pixel stroke without retaining animation data on reused cards.
		material = "content/ui/materials/frames/line_thin_dashed_animated"
		pass_count = math.floor(numeric_setting(mod, "equipped_highlight_animated_border_width", 3, 1, 5) + 0.5)
		base_size_addition = 4
		layer_size_step = 2
		z_offset = 8
	elseif mode == "solid_border" then
		local border_width = math.floor(numeric_setting(mod, "equipped_highlight_solid_border_width", 2, 1, 5) + 0.5)

		material = border_width == 1 and "content/ui/materials/frames/frame_tile_1px" or "content/ui/materials/frames/frame_tile_2px"
		pass_count = border_width == 1 and 1 or border_width - 1
		base_size_addition = 4
		layer_size_step = 2
		z_offset = 8
	else
		local intensity = numeric_setting(mod, "equipped_highlight_glow_intensity", 100, 0, 100)

		alpha = math.floor(intensity * 2.55 + 0.5)
	end

	local default_red = mode == "soft_glow" and 255 or 250
	local default_green = mode == "soft_glow" and 255 or 189
	local default_blue = mode == "soft_glow" and 255 or 73
	local red = math.floor(numeric_setting(mod, "equipped_highlight_color_r", default_red, 0, 255) + 0.5)
	local green = math.floor(numeric_setting(mod, "equipped_highlight_color_g", default_green, 0, 255) + 0.5)
	local blue = math.floor(numeric_setting(mod, "equipped_highlight_color_b", default_blue, 0, 255) + 0.5)
	local function equipped_visible(content)
		return content and content.equipped == true
	end

	for layer = 1, pass_count do
		local size_addition = base_size_addition + (layer - 1) * layer_size_step

		pass_template[#pass_template + 1] = {
			pass_type = "texture",
			style_id = layer == 1 and EQUIPPED_HIGHLIGHT_STYLE_PREFIX or EQUIPPED_HIGHLIGHT_STYLE_PREFIX .. "_layer_" .. tostring(layer),
			value = material,
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				scale_to_material = true,
				color = {
					alpha,
					red,
					green,
					blue,
				},
				size = {
					card_width,
					card_height,
				},
				size_addition = {
					size_addition,
					size_addition,
				},
				offset = {
					0,
					0,
					z_offset,
				},
			},
			visibility_function = equipped_visible,
			change_function = mode == "pulsing_dashes" and update_pulsing_dash_alpha or nil,
		}
	end

	-- Static modes have no change callback. The pulsing mode reads only
	-- Darktide's global clock and mutates the pass alpha in place.
end

local NATIVE_NEW_ITEM_INDICATOR = "content/ui/materials/symbols/new_item_indicator"
local NEW_ITEM_HIGHLIGHT_STYLE_PREFIX = "better_inventory_new_item_highlight"

local function new_item_marker_visible(content)
	local element = content and content.element

	return element and element.new_item_marker and true or false
end

local function never_visible()
	return false
end

local function clear_new_item_highlight_passes(pass_template)
	for index = #pass_template, 1, -1 do
		local style_id = pass_template[index] and pass_template[index].style_id

		if style_id == NEW_ITEM_HIGHLIGHT_STYLE_PREFIX or type(style_id) == "string" and string.sub(style_id, 1, #NEW_ITEM_HIGHLIGHT_STYLE_PREFIX + 1) == NEW_ITEM_HIGHLIGHT_STYLE_PREFIX .. "_" then
			table.remove(pass_template, index)
		end
	end
end

local function configure_new_item_highlight(mod, pass_template, card_width, card_height)
	local mode = setting(mod, "new_item_highlight_mode", "animated_dashes")

	if mode ~= "native" and mode ~= "soft_glow" and mode ~= "animated_dashes" and mode ~= "pulsing_dashes" and mode ~= "solid_border" then
		mode = "native"
	end

	local acknowledge_mode = setting(mod, "new_item_acknowledge_mode", "select")

	if acknowledge_mode ~= "hover" then
		acknowledge_mode = "select"
	end

	-- Darktide owns acquisition tracking and persistence. This callback only
	-- chooses when to invoke the element's native removal callback, then clears
	-- the live element marker so every highlight pass disappears immediately.
	local function acknowledge_new_item(content)
		local element = content and content.element
		local hotspot = content and content.hotspot

		if not element or not element.new_item_marker or not hotspot then
			return
		end

		local acknowledged = hotspot.is_selected == true

		if acknowledge_mode == "hover" then
			acknowledged = acknowledged or hotspot.is_hover == true
		end

		if not acknowledged then
			return
		end

		element.new_item_marker = nil

		local item = element.real_item or element.item
		local remove_callback = element.remove_new_marker_callback

		if type(remove_callback) == "function" and item then
			-- A third-party callback failure must not escape through a UI draw pass.
			pcall(remove_callback, item)
		end
	end

	local function pulse_and_acknowledge_new_item(content, style)
		update_pulsing_dash_alpha(content, style)
		acknowledge_new_item(content)
	end

	clear_new_item_highlight_passes(pass_template)

	-- Enhanced modes replace the conflicting native corner dot. Native mode
	-- keeps the compact dot but still uses the configured acknowledgement rule.
	for index = 1, #pass_template do
		local pass = pass_template[index]

		if pass and pass.value == NATIVE_NEW_ITEM_INDICATOR then
			pass.visibility_function = mode == "native" and new_item_marker_visible or never_visible
			pass.change_function = mode == "native" and acknowledge_new_item or nil

			if mode == "native" and pass.style then
				pass.style.size = {
					62,
					62,
				}
				pass.style.offset = {
					16,
					-16,
					4,
				}
			end
		end
	end

	if mode == "native" then
		return
	end

	local alpha = 255
	local material = "content/ui/materials/frames/dropshadow_medium"
	local pass_count = 1
	local base_size_addition = 16
	local layer_size_step = 0
	local z_offset = 9

	if mode == "animated_dashes" or mode == "pulsing_dashes" then
		material = "content/ui/materials/frames/line_thin_dashed_animated"
		pass_count = math.floor(numeric_setting(mod, "new_item_highlight_animated_border_width", 3, 1, 5) + 0.5)
		base_size_addition = 4
		layer_size_step = 2
	elseif mode == "solid_border" then
		local border_width = math.floor(numeric_setting(mod, "new_item_highlight_solid_border_width", 2, 1, 5) + 0.5)

		material = border_width == 1 and "content/ui/materials/frames/frame_tile_1px" or "content/ui/materials/frames/frame_tile_2px"
		pass_count = border_width == 1 and 1 or border_width - 1
		base_size_addition = 4
		layer_size_step = 2
	else
		local intensity = numeric_setting(mod, "new_item_highlight_glow_intensity", 100, 0, 100)

		alpha = math.floor(intensity * 2.55 + 0.5)
		z_offset = 4
	end

	local default_red = mode == "soft_glow" and 255 or 250
	local default_green = mode == "soft_glow" and 255 or 189
	local default_blue = mode == "soft_glow" and 255 or 73
	local red = math.floor(numeric_setting(mod, "new_item_highlight_color_r", default_red, 0, 255) + 0.5)
	local green = math.floor(numeric_setting(mod, "new_item_highlight_color_g", default_green, 0, 255) + 0.5)
	local blue = math.floor(numeric_setting(mod, "new_item_highlight_color_b", default_blue, 0, 255) + 0.5)

	for layer = 1, pass_count do
		local size_addition = base_size_addition + (layer - 1) * layer_size_step
		local change_function

		if mode == "pulsing_dashes" then
			change_function = layer == 1 and pulse_and_acknowledge_new_item or update_pulsing_dash_alpha
		elseif layer == 1 then
			change_function = acknowledge_new_item
		end

		pass_template[#pass_template + 1] = {
			pass_type = "texture",
			style_id = layer == 1 and NEW_ITEM_HIGHLIGHT_STYLE_PREFIX or NEW_ITEM_HIGHLIGHT_STYLE_PREFIX .. "_layer_" .. tostring(layer),
			value = material,
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				scale_to_material = true,
				color = {
					alpha,
					red,
					green,
					blue,
				},
				size = {
					card_width,
					card_height,
				},
				size_addition = {
					size_addition,
					size_addition,
				},
				offset = {
					0,
					0,
					z_offset,
				},
			},
			visibility_function = new_item_marker_visible,
			change_function = change_function,
		}
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

local function fit_display_name(parent, widget, ui_renderer, preferred_font_size, minimum_font_size, force_weapon_name_single_line)
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

	local force_single_line = force_weapon_name_single_line and is_weapon(item_from_content(content))

	if force_single_line then
		local base_name = content.better_inventory_display_name_base
		local suffix = content.better_inventory_display_name_suffix

		if base_name and suffix then
			base_name = single_line_text(base_name)
			suffix = single_line_text(suffix)
			suffix = suffix ~= "" and " " .. suffix or ""
			content.better_inventory_display_name_base = base_name
			content.better_inventory_display_name_suffix = suffix
			display_name = base_name .. suffix
		else
			display_name = single_line_text(display_name)
		end

		content.display_name = display_name
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

	if force_single_line then
		-- Keep one rendered glyph of clearance. Slug can otherwise character-wrap
		-- the final mark glyph when font extents land exactly on the style edge.
		local safety_margin = math.max(SINGLE_LINE_WEAPON_NAME_MINIMUM_SAFETY_MARGIN, preferred_font_size)
		maximum_width = math.max(1, maximum_width - safety_margin)
		style.size[2] = math.min(style.size[2] or preferred_font_size + 6, preferred_font_size + 6)
	end

	local measurement_size = {
		1000000,
		style.size[2] or 30,
	}
	local measured_width = rendered_title_width(ui_renderer, display_name, style, measurement_size, force_single_line)

	while measured_width > maximum_width and style.font_size > minimum_font_size do
		style.font_size = style.font_size - 1
		measured_width = rendered_title_width(ui_renderer, display_name, style, measurement_size, force_single_line)
	end

	content.better_inventory_full_display_name = display_name

	if measured_width > maximum_width then
		local base_name = content.better_inventory_display_name_base
		local suffix = content.better_inventory_display_name_suffix

		if base_name and suffix then
			local suffix_width = rendered_title_width(ui_renderer, suffix, style, measurement_size, force_single_line)
			local maximum_base_width = maximum_width - suffix_width

			if maximum_base_width > 0 then
				local base_width = rendered_title_width(ui_renderer, base_name, style, measurement_size, force_single_line)
				local fitted_base_name = base_width > maximum_base_width and strictly_crop_title(ui_renderer, base_name, style, measurement_size, maximum_base_width, force_single_line) or base_name
				local fitted_width = rendered_title_width(ui_renderer, fitted_base_name .. suffix, style, measurement_size, force_single_line)
				local attempts = 0

				while fitted_width > maximum_width and maximum_base_width > 1 and attempts < 8 do
					maximum_base_width = math.max(1, maximum_base_width - math.ceil(fitted_width - maximum_width) - 1)
					fitted_base_name = strictly_crop_title(ui_renderer, base_name, style, measurement_size, maximum_base_width, force_single_line)
					fitted_width = rendered_title_width(ui_renderer, fitted_base_name .. suffix, style, measurement_size, force_single_line)
					attempts = attempts + 1
				end

				content.display_name = fitted_base_name .. suffix

				if force_single_line then
					content.display_name = non_wrapping_title(content.display_name)
				end

				return
			end
		end

		content.display_name = force_single_line and strictly_crop_title(ui_renderer, display_name, style, measurement_size, maximum_width, true) or Text.crop_text_width(ui_renderer, display_name, style, maximum_width)
	end

	if force_single_line then
		content.display_name = non_wrapping_title(content.display_name)
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
	if configuration and configuration.store_item == true and content.columns(mod, maximum_columns, configuration.slot_kind) == 3 then
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
	local force_weapon_name_single_line = setting(mod, "force_weapon_name_single_line", true)
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
			format_item_name(mod, widget, element, append_mark_to_name, force_weapon_name_single_line)
			synchronize_rarity_tag_color(widget, element)
			apply_item_customization_style(mod, widget, element)
			format_item_level(widget, element, show_item_level_icon)
			populate_card_content(mod, widget, element, blessing_display_mode, show_weapon_perks, weapon_perk_compression, compression_mode, simplify_curio_stats, show_weapon_modifiers, show_blessing_text_icons)
			fit_display_name(parent, widget, ui_renderer, preferred_font_size, math.min(preferred_font_size, minimum_font_size), force_weapon_name_single_line)
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
			format_item_name(mod, widget, element, append_mark_to_name, force_weapon_name_single_line)
			synchronize_rarity_tag_color(widget, element)
			apply_item_customization_style(mod, widget, element)
			format_item_level(widget, element, show_item_level_icon)
			populate_card_content(mod, widget, element, blessing_display_mode, show_weapon_perks, weapon_perk_compression, compression_mode, simplify_curio_stats, show_weapon_modifiers, show_blessing_text_icons)
			fit_display_name(parent, widget, nil, preferred_font_size, math.min(preferred_font_size, minimum_font_size), force_weapon_name_single_line)
			fit_blessing_text(parent, widget, nil)
			fit_weapon_perks(parent, widget, nil)
			fit_curio_stats(parent, widget, nil)
		end
	end

end

Cards.configure_native_quick_look_card_passes = configure_native_quick_look_card_passes
Cards.disable_quick_look_card_passes = disable_quick_look_card_passes
Cards.preserve_visibility = preserve_visibility
Cards.set_visibility = set_visibility
Cards.set_height = set_height
Cards.configure_native_card_geometry = configure_native_card_geometry
Cards.configure_text_pass = configure_text_pass
Cards.configure_favorite_marker = configure_favorite_marker
Cards.configure_equipped_highlight = configure_equipped_highlight
Cards.configure_new_item_highlight = configure_new_item_highlight
Cards.add_custom_content_passes = add_custom_content_passes
Cards.grid_weapon_name_font_size = grid_weapon_name_font_size
Cards.configure_card_content = configure_card_content

return Cards
