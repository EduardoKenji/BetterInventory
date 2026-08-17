local Integration = {}

local TEXT_STYLE_ID = "wkc_kills"
local ICON_STYLE_ID = "wkc_kills_icon"
local DEFAULT_ICON = "content/ui/materials/hud/interactions/icons/enemy_priority"
local DEFAULT_COLOR = {
	255,
	255,
	255,
	255,
}
local DEFAULT_NATIVE_ICON_SIZE = 34
local DEFAULT_NATIVE_FONT_SIZE = 24
local DEFAULT_NATIVE_TEXT_WIDTH = 58
local DEFAULT_NATIVE_TEXT_HEIGHT = 30
local COMPACT_ICON_SIZE = 19
local COMPACT_FONT_SIZE = 18
local COMPACT_CARD_HEIGHT_PADDING = 7
local COMPACT_X_ADJUSTMENT = -3
local SINGLE_COLUMN_X_ADJUSTMENT = -1
local SINGLE_COLUMN_Y_ADJUSTMENT = -4

local function optional_wkc()
	if type(get_mod) ~= "function" then
		return nil
	end

	local success, wkc = pcall(get_mod, "wkc")

	return success and type(wkc) == "table" and wkc or nil
end

local function setting(mod, setting_id, fallback)
	if not mod or type(mod.get) ~= "function" then
		return fallback
	end

	local success, value = pcall(mod.get, mod, setting_id)

	return success and value ~= nil and value or fallback
end

local function card_configuration(wkc)
	if not wkc or type(wkc._layout_geom) ~= "function" then
		return nil
	end

	local success, geometry = pcall(wkc._layout_geom)

	return success and type(geometry) == "table" and type(geometry.card) == "table" and geometry.card or nil
end

local function integration_enabled(wkc)
	local configuration = card_configuration(wkc)

	if configuration and configuration.on == false then
		return false
	end

	if type(wkc.get) == "function" then
		local success, enabled = pcall(wkc.get, wkc, "wkc_card_kills")

		if success and enabled == false then
			return false
		end
	end

	return true
end

local function compact_card_height_padding(mod, configuration, columns)
	configuration = configuration or {}
	columns = math.max(1, math.floor(tonumber(columns) or 1))

	if columns ~= 3 or configuration.native_single_column == true or configuration.character_overview == true then
		return 0
	end

	local wkc = optional_wkc()

	return wkc and integration_enabled(wkc) and COMPACT_CARD_HEIGHT_PADDING or 0
end

local function item_from_content(content)
	if type(content) ~= "table" then
		return nil
	end

	if type(content.item) == "table" then
		return content.item
	end

	local element = content.element

	if type(element) ~= "table" then
		return nil
	end

	return type(element.real_item) == "table" and element.real_item or type(element.item) == "table" and element.item or nil
end

local function weapon_content(content)
	if type(content) ~= "table" then
		return false
	end

	if content.better_inventory_is_weapon ~= nil then
		return content.better_inventory_is_weapon == true
	end

	-- Before BetterInventory's item initializer has run, ask WKC itself. Its
	-- lookup is authoritative for whether this item has a weapon template.
	local wkc = optional_wkc()
	local item = item_from_content(content)

	if not wkc or not item or type(wkc._overlay_kills_for_item) ~= "function" then
		return false
	end

	local success, kills = pcall(wkc._overlay_kills_for_item, item)

	return success and kills ~= nil
end

local function resolved_kills(mod, content)
	local wkc = optional_wkc()

	if not wkc or not integration_enabled(wkc) or not weapon_content(content) then
		return nil
	end

	local debug_kills = math.floor(tonumber(setting(mod, "debug_weapon_kill_counter_kills", 0)) or 0)

	if debug_kills > 0 then
		return debug_kills
	end

	local item = item_from_content(content)

	if not item or type(wkc._overlay_kills_for_item) ~= "function" then
		return nil
	end

	local success, kills = pcall(wkc._overlay_kills_for_item, item)

	if not success or type(kills) ~= "number" or kills <= 0 then
		return nil
	end

	return kills
end

local function abbreviated_kills(wkc, kills)
	if wkc and type(wkc._abbrev_num) == "function" then
		local success, value = pcall(wkc._abbrev_num, kills)

		if success and value ~= nil then
			return tostring(value)
		end
	end

	return tostring(kills)
end

local function color_from_configuration(source, fallback)
	if type(source) ~= "table" then
		return {
			fallback[1],
			fallback[2],
			fallback[3],
			fallback[4],
		}
	end

	return {
		tonumber(source.a) or fallback[1],
		tonumber(source.r) or fallback[2],
		tonumber(source.g) or fallback[3],
		tonumber(source.b) or fallback[4],
	}
end

local function native_card_offsets(wkc, configuration, card_width, card_height)
	local x = tonumber(configuration.x) or 0
	local y = tonumber(configuration.y) or 0

	if wkc and type(wkc._card_offsets) == "function" then
		local success, resolved_x, resolved_y = pcall(wkc._card_offsets, configuration, card_width, card_height)

		if success then
			x = tonumber(resolved_x) or x
			y = tonumber(resolved_y) or y
		end
	end

	return x, y
end

local function profile(mod, card_width, text_left, configuration, columns, wkc, wkc_configuration)
	configuration = configuration or {}
	columns = math.max(1, math.floor(tonumber(columns) or (configuration.native_single_column and 1 or 3)))
	wkc = wkc or optional_wkc()
	wkc_configuration = wkc_configuration or card_configuration(wkc) or {}

	local character_overview = configuration.character_overview == true
	local native = configuration.native_single_column == true or character_overview
	local compact = columns >= 3 and not native
	local icon_size = compact and COMPACT_ICON_SIZE or native and math.max(0, tonumber(wkc_configuration.icon_size) or DEFAULT_NATIVE_ICON_SIZE) or 18
	local font_size = compact and COMPACT_FONT_SIZE or native and math.max(6, tonumber(wkc_configuration.font_size) or DEFAULT_NATIVE_FONT_SIZE) or 16
	local gap = compact and 3 or native and math.max(0, tonumber(wkc_configuration.gap) or 0) or 4
	local layer = native and math.max(0, tonumber(wkc_configuration.layer) or 12) or 16
	local row_height = math.max(icon_size, font_size + 3)
	local top = 34
	local left = math.max(0, tonumber(text_left) or 12)
	local text_width
	local text_offset
	local icon_offset
	local horizontal_alignment = "left"
	local vertical_alignment = "top"
	local text_height = row_height

	if native then
		local x, y = native_card_offsets(wkc, wkc_configuration, tonumber(card_width), tonumber(configuration.card_height))
		local single_column_inventory = configuration.native_single_column == true and not character_overview

		if single_column_inventory then
			x = x + SINGLE_COLUMN_X_ADJUSTMENT
			y = y + SINGLE_COLUMN_Y_ADJUSTMENT
		end

		text_width = math.max(0, tonumber(wkc_configuration.text_w) or DEFAULT_NATIVE_TEXT_WIDTH)
		text_offset = x
		icon_offset = x - text_width - gap
		top = y
		horizontal_alignment = "right"
		vertical_alignment = "center"
		text_height = DEFAULT_NATIVE_TEXT_HEIGHT
	else
		if compact then
			left = math.max(0, left + COMPACT_X_ADJUSTMENT)
		end

		text_width = math.max(28, (tonumber(card_width) or 160) - left - icon_size - gap - 8)
		text_offset = left + icon_size + gap
		icon_offset = left
	end

	if not native and setting(mod, "show_pattern_mark", false) == true then
		top = 54
	end

	if not native and setting(mod, "show_rarity_name", false) == true then
		top = 74
	end

	return {
		columns = columns,
		native = native,
		compact = compact,
		font_size = font_size,
		icon_size = icon_size,
		gap = gap,
		left = icon_offset,
		top = top,
		row_height = row_height,
		text_left = text_offset,
		text_width = text_width,
		text_height = text_height,
		horizontal_alignment = horizontal_alignment,
		vertical_alignment = vertical_alignment,
		layer = layer,
	}
end

local function remove_owned_passes(pass_template)
	for index = #(pass_template or {}), 1, -1 do
		local pass = pass_template[index]
		local style_id = pass and pass.style_id

		if style_id == TEXT_STYLE_ID or style_id == ICON_STYLE_ID then
			table.remove(pass_template, index)
		end
	end
end

local function configure_passes(mod, pass_template, card_width, text_left, configuration, columns)
	if type(pass_template) ~= "table" then
		return false
	end

	-- WKC appends these IDs to native templates. Replace every inherited copy
	-- so either mod load order produces one responsive pair and never duplicates.
	remove_owned_passes(pass_template)

	local wkc = optional_wkc()
	local wkc_configuration = card_configuration(wkc) or {}
	local geometry = profile(mod, card_width, text_left, configuration, columns, wkc, wkc_configuration)
	local text_color = color_from_configuration(wkc_configuration.color, DEFAULT_COLOR)
	local icon_color = color_from_configuration(wkc_configuration.icon_color, DEFAULT_COLOR)
	local font_type = type(wkc_configuration.font_type) == "string" and wkc_configuration.font_type ~= "" and wkc_configuration.font_type or "proxima_nova_bold"
	local icon_material = DEFAULT_ICON

	if wkc and type(wkc._overlay_icon_material) == "function" then
		local success, material = pcall(wkc._overlay_icon_material, wkc_configuration)

		if success and type(material) == "string" and material ~= "" then
			icon_material = material
		end
	end

	pass_template[#pass_template + 1] = {
		pass_type = "texture",
		style_id = ICON_STYLE_ID,
		value_id = ICON_STYLE_ID,
		value = icon_material,
		style = {
			horizontal_alignment = geometry.horizontal_alignment,
			vertical_alignment = geometry.vertical_alignment,
			offset = {
				geometry.left,
				geometry.top,
				geometry.layer,
			},
			size = {
				geometry.icon_size,
				geometry.icon_size,
			},
			color = icon_color,
		},
		visibility_function = function(content)
			local current_wkc = optional_wkc()
			local current_configuration = card_configuration(current_wkc)

			return (not current_configuration or current_configuration.icon_on ~= false) and resolved_kills(mod, content) ~= nil
		end,
		change_function = function(content)
			local current_wkc = optional_wkc()
			local current_configuration = card_configuration(current_wkc) or {}
			local material = DEFAULT_ICON

			if current_wkc and type(current_wkc._overlay_icon_material) == "function" then
				local success, resolved_material = pcall(current_wkc._overlay_icon_material, current_configuration)

				if success and type(resolved_material) == "string" and resolved_material ~= "" then
					material = resolved_material
				end
			end

			content[ICON_STYLE_ID] = material
		end,
	}

	pass_template[#pass_template + 1] = {
		pass_type = "text",
		style_id = TEXT_STYLE_ID,
		value_id = TEXT_STYLE_ID,
		value = "",
		style = {
			horizontal_alignment = geometry.horizontal_alignment,
			vertical_alignment = geometry.vertical_alignment,
			text_horizontal_alignment = "left",
			text_vertical_alignment = "center",
			font_size = geometry.font_size,
			font_type = font_type,
			drop_shadow = true,
			word_wrap = false,
			offset = {
				geometry.text_left,
				geometry.top,
				geometry.layer,
			},
			size = {
				geometry.text_width,
				geometry.text_height,
			},
			text_color = text_color,
		},
		visibility_function = function(content)
			return resolved_kills(mod, content) ~= nil
		end,
		change_function = function(content)
			local kills = resolved_kills(mod, content)
			local current_wkc = optional_wkc()

			content[TEXT_STYLE_ID] = kills and abbreviated_kills(current_wkc, kills) or ""
		end,
	}

	return true
end

Integration.resolve_kills = resolved_kills
Integration.profile = profile
Integration.configure_passes = configure_passes
Integration.compact_card_height_padding = compact_card_height_padding
Integration.TEXT_STYLE_ID = TEXT_STYLE_ID
Integration.ICON_STYLE_ID = ICON_STYLE_ID

return Integration
