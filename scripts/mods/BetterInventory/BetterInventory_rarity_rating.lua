local Items = require("scripts/utilities/items")

local RarityRating = {}
local custom_tier_provider

local MODE_OFF = "off"
local MODE_COMPACT = "compact_horizontal"
local MODE_FULL = "full_horizontal"
local MODE_VERTICAL = "vertical"
local VERTICAL_RAIL_WIDTH = 28
local HORIZONTAL_ROW_HEIGHT = 20
local HORIZONTAL_TOP = 27
local STAR = "★"
local STAR_RUNS = { [0] = "", STAR, STAR .. STAR, STAR .. STAR .. STAR, STAR .. STAR .. STAR .. STAR, STAR .. STAR .. STAR .. STAR .. STAR, STAR .. STAR .. STAR .. STAR .. STAR .. STAR }
local VERTICAL_STAR_RUNS = { [0] = "", STAR, STAR .. "\n" .. STAR, STAR .. "\n" .. STAR .. "\n" .. STAR, STAR .. "\n" .. STAR .. "\n" .. STAR .. "\n" .. STAR, STAR .. "\n" .. STAR .. "\n" .. STAR .. "\n" .. STAR .. "\n" .. STAR, STAR .. "\n" .. STAR .. "\n" .. STAR .. "\n" .. STAR .. "\n" .. STAR .. "\n" .. STAR }
local DEFAULT_COLOR = { 255, 255, 255, 255 }
local CARD_BACKGROUND_STYLE_IDS = {
	"background_gradient",
	"rarity_tag",
	"background",
}
local OWNED_STYLE_IDS = {
	better_inventory_weapon_rarity_rating = true,
	better_inventory_curio_rarity_rating = true,
	better_inventory_rarity_rating_compact = true,
	better_inventory_rarity_rating_full_name = true,
	better_inventory_rarity_rating_stars = true,
	better_inventory_rarity_rating_vertical = true,
}

local function setting(mod, setting_id, fallback)
	if not mod or type(mod.get) ~= "function" then
		return fallback
	end

	local ok, value = pcall(mod.get, mod, setting_id)

	if not ok or value == nil then
		return fallback
	end

	return value
end

local function valid_mode(value)
	if value == MODE_COMPACT or value == MODE_FULL or value == MODE_VERTICAL then
		return value
	end

	return MODE_OFF
end

local function slot_item_kind(slot_kind)
	if slot_kind == "curio" or type(slot_kind) == "string" and string.match(slot_kind, "^slot_attachment_") then
		return "curio"
	end

	if slot_kind == "weapon" or slot_kind == "melee" or slot_kind == "ranged" or slot_kind == "slot_primary" or slot_kind == "slot_secondary" then
		return "weapon"
	end
end

local function configuration_allows_rating(configuration)
	configuration = configuration or {}

	if configuration.native_single_column == true
		or configuration.character_overview == true then
		return false
	end

	return true
end

local function item_mode(mod, item_kind, configuration)
	if not configuration_allows_rating(configuration) then
		return MODE_OFF
	end

	local configured_kind = slot_item_kind(configuration and configuration.slot_kind)

	if item_kind and configured_kind and item_kind ~= configured_kind then
		return MODE_OFF
	end

	item_kind = item_kind or configured_kind or "weapon"

	return valid_mode(setting(mod, item_kind == "curio" and "curio_rarity_rating_mode" or "weapon_rarity_rating_mode", MODE_OFF))
end

local function mode(mod, configuration, explicit_item_kind)
	return item_mode(mod, explicit_item_kind or slot_item_kind(configuration and configuration.slot_kind), configuration)
end

local function layout_modes(mod, configuration, slot_kind)
	configuration = configuration or {}

	if not configuration_allows_rating(configuration) then
		return MODE_OFF, MODE_OFF
	end

	local resolved_kind = slot_item_kind(slot_kind ~= nil and slot_kind or configuration.slot_kind)

	if resolved_kind == "weapon" then
		return item_mode(mod, "weapon", configuration), MODE_OFF
	elseif resolved_kind == "curio" then
		return MODE_OFF, item_mode(mod, "curio", configuration)
	end

	-- Mixed vendor grids can contain both kinds. Reserve only the maximum layout
	-- requirement, while each card populates the pass belonging to its own kind.
	return item_mode(mod, "weapon", configuration), item_mode(mod, "curio", configuration)
end

local function vertical_applies(mod, slot_kind, configuration)
	local weapon_mode, curio_mode = layout_modes(mod, configuration, slot_kind)

	return weapon_mode == MODE_VERTICAL or curio_mode == MODE_VERTICAL
end

local function first_utf8_character(value)
	if type(value) ~= "string" or value == "" then
		return "?"
	end

	local first = string.byte(value, 1) or 0
	local length = first < 128 and 1 or first < 224 and 2 or first < 240 and 3 or first < 248 and 4 or 1

	return string.sub(value, 1, length)
end

local function effective_rarity(item)
	local rarity = math.floor(tonumber(item and item.rarity) or 0)

	if rarity == 5 and type(custom_tier_provider) == "table" and type(custom_tier_provider.matches) == "function" then
		local ok, matches = pcall(custom_tier_provider.matches, item)

		if ok and matches == true then
			rarity = 6
		end
	end

	return math.max(0, math.min(6, rarity))
end

local function plain_rarity_name(value)
	if type(value) ~= "string" then
		return ""
	end

	-- Other rarity/name integrations may return Darktide rich-text markup.
	-- Strip every formatting directive before deriving the visible initial or
	-- placing the full label in our independently coloured text pass.
	value = string.gsub(value, "{#[^}]*}", "")

	return string.gsub(string.gsub(value, "^%s+", ""), "%s+$", "")
end

local function rarity_name(item)
	local ok, value = pcall(Items.rarity_display_name, item)

	value = plain_rarity_name(ok and value or "")

	return value ~= "" and value or plain_rarity_name(tostring(item and item.rarity_name or ""))
end

local function rarity_color(item)
	local ok, value = pcall(Items.rarity_color, item)

	if not ok or type(value) ~= "table" then
		return DEFAULT_COLOR
	end

	return value
end

local function copy_color(target, source)
	if type(target) ~= "table" then
		return
	end

	for channel = 1, 4 do
		target[channel] = tonumber(source and source[channel]) or DEFAULT_COLOR[channel]
	end
end

local function set_style_color(widget, style_id, color, alpha)
	local style = widget and widget.style and widget.style[style_id]

	if not style then
		return
	end

	style.text_color = style.text_color or table.clone(DEFAULT_COLOR)
	style.default_color = style.default_color or table.clone(DEFAULT_COLOR)
	style.hover_color = style.hover_color or table.clone(DEFAULT_COLOR)
	copy_color(style.text_color, color)
	copy_color(style.default_color, color)
	copy_color(style.hover_color, color)

	if alpha then
		style.text_color[1] = alpha
		style.default_color[1] = alpha
		style.hover_color[1] = alpha
	end
end

local function rating_alpha(mod, item_kind)
	local setting_id = item_kind == "curio"
		and "curio_rarity_rating_opacity"
		or "weapon_rarity_rating_opacity"
	local opacity = tonumber(setting(mod, setting_id, 100)) or 100

	return math.floor(math.max(0, math.min(100, opacity)) * 255 / 100 + 0.5)
end

local function resolved_rating_color(mod, widget, item, item_kind)
	local setting_id = item_kind == "curio"
		and "curio_rarity_rating_use_card_background_color"
		or "weapon_rarity_rating_use_card_background_color"

	if setting(mod, setting_id, false) == true then
		local style = widget and widget.style

		for index = 1, #CARD_BACKGROUND_STYLE_IDS do
			local card_style = style and style[CARD_BACKGROUND_STYLE_IDS[index]]
			local color = card_style and card_style.color

			if type(color) == "table" then
				return color
			end
		end
	end

	return rarity_color(item)
end

local function clear_content(content)
	content.better_inventory_weapon_rarity_rating = ""
	content.better_inventory_curio_rarity_rating = ""
	content.better_inventory_rarity_rating_compact = ""
	content.better_inventory_rarity_rating_full_name = ""
	content.better_inventory_rarity_rating_stars = ""
	content.better_inventory_rarity_rating_vertical = ""
	content.better_inventory_rarity_rating_visible = false
end

RarityRating.set_custom_tier_provider = function(provider)
	custom_tier_provider = type(provider) == "table" and provider or nil
end

RarityRating.mode = mode
RarityRating.item_mode = item_mode
RarityRating.is_vertical = function(mod, configuration)
	return mode(mod, configuration) == MODE_VERTICAL
end
RarityRating.vertical_applies = vertical_applies
RarityRating.vertical_rail_width = function(mod, slot_kind, configuration)
	return vertical_applies(mod, slot_kind, configuration) and VERTICAL_RAIL_WIDTH or 0
end
RarityRating.horizontal_rows = function(mod, configuration, explicit_item_kind)
	if explicit_item_kind then
		local resolved_mode = item_mode(mod, explicit_item_kind, configuration)

		return (resolved_mode == MODE_COMPACT or resolved_mode == MODE_FULL) and 1 or 0
	end

	local weapon_mode, curio_mode = layout_modes(mod, configuration)

	return (weapon_mode == MODE_COMPACT or weapon_mode == MODE_FULL or curio_mode == MODE_COMPACT or curio_mode == MODE_FULL) and 1 or 0
end

RarityRating.populate = function(mod, widget, item, item_kind)
	local content = widget and widget.content

	if not content then
		return
	end

	clear_content(content)

	item_kind = item_kind == true and "weapon" or item_kind == false and nil or item_kind
	local resolved_mode = item_kind and item_mode(mod, item_kind) or MODE_OFF
	local rarity = effective_rarity(item)

	if resolved_mode == MODE_OFF or rarity < 1 or not item_kind then
		return
	end

	local name = rarity_name(item)
	local first = first_utf8_character(name)
	local stars = STAR_RUNS[rarity] or ""
	local color = resolved_rating_color(mod, widget, item, item_kind)
	local alpha = rating_alpha(mod, item_kind)
	local horizontal = (resolved_mode == MODE_FULL and name or first) .. " " .. stars

	content.better_inventory_rarity_rating_visible = true
	content[item_kind == "curio" and "better_inventory_curio_rarity_rating" or "better_inventory_weapon_rarity_rating"] = horizontal
	content.better_inventory_rarity_rating_compact = first .. " " .. stars
	content.better_inventory_rarity_rating_full_name = name .. " " .. stars
	content.better_inventory_rarity_rating_stars = stars
	content.better_inventory_rarity_rating_vertical = first .. "\n" .. (VERTICAL_STAR_RUNS[rarity] or "")

	for style_id in pairs(OWNED_STYLE_IDS) do
		set_style_color(widget, style_id, color, alpha)
	end
end

local function remove_owned_passes(pass_template)
	for index = #(pass_template or {}), 1, -1 do
		local pass = pass_template[index]

		if pass and OWNED_STYLE_IDS[pass.style_id] then
			table.remove(pass_template, index)
		end
	end
end

local function add_text_pass(pass_template, content_id, base_style, options)
	local style = table.clone(base_style or {})

	style.font_size = options.font_size
	style.horizontal_alignment = "left"
	style.vertical_alignment = "top"
	style.text_horizontal_alignment = options.text_horizontal_alignment or "left"
	style.text_vertical_alignment = options.text_vertical_alignment or "top"
	style.word_wrap = false
	style.text_fit_with = false
	style.drop_shadow = true
	style.offset = options.offset
	style.size = options.size
	style.text_color = table.clone(DEFAULT_COLOR)
	style.default_color = table.clone(DEFAULT_COLOR)
	style.hover_color = table.clone(DEFAULT_COLOR)

	pass_template[#pass_template + 1] = {
		pass_type = "text",
		style_id = content_id,
		value = "",
		value_id = content_id,
		style = style,
		visibility_function = function(content)
			return content and content.better_inventory_rarity_rating_visible == true and content[content_id] ~= ""
		end,
	}
end

RarityRating.add_passes = function(mod, pass_template, card_width, card_height, text_left, base_style, configuration)
	remove_owned_passes(pass_template)

	local weapon_mode, curio_mode = layout_modes(mod, configuration)

	if weapon_mode == MODE_OFF and curio_mode == MODE_OFF then
		return
	end

	local font_size = math.max(8, math.min(18, tonumber(setting(mod, "secondary_text_font_size", 13)) or 13))
	local pattern_rows = setting(mod, "show_pattern_mark", false) == true and 1 or 0
	local top = HORIZONTAL_TOP + pattern_rows * HORIZONTAL_ROW_HEIGHT

	if weapon_mode == MODE_COMPACT or weapon_mode == MODE_FULL then
		add_text_pass(pass_template, "better_inventory_weapon_rarity_rating", base_style, {
			font_size = font_size,
			offset = { text_left, top, 11 },
			size = { math.max(40, card_width - text_left - 8), HORIZONTAL_ROW_HEIGHT },
		})
	end

	if curio_mode == MODE_COMPACT or curio_mode == MODE_FULL then
		add_text_pass(pass_template, "better_inventory_curio_rarity_rating", base_style, {
			font_size = font_size,
			offset = { text_left, tonumber(configuration and configuration.curio_rating_top) or 31, 11 },
			size = { math.max(40, card_width - text_left - 8), HORIZONTAL_ROW_HEIGHT },
		})
	end

	if weapon_mode == MODE_VERTICAL or curio_mode == MODE_VERTICAL then
		add_text_pass(pass_template, "better_inventory_rarity_rating_vertical", base_style, {
			font_size = math.min(13, font_size),
			text_horizontal_alignment = "center",
			text_vertical_alignment = "center",
			offset = { 5, 4, 11 },
			size = { VERTICAL_RAIL_WIDTH - 5, math.max(40, card_height - 8) },
		})
	end
end

RarityRating.MODE_OFF = MODE_OFF
RarityRating.MODE_COMPACT = MODE_COMPACT
RarityRating.MODE_FULL = MODE_FULL
RarityRating.MODE_VERTICAL = MODE_VERTICAL
RarityRating.HORIZONTAL_ROW_HEIGHT = HORIZONTAL_ROW_HEIGHT
RarityRating.VERTICAL_RAIL_WIDTH = VERTICAL_RAIL_WIDTH
RarityRating._test = {
	effective_rarity = effective_rarity,
	first_utf8_character = first_utf8_character,
	plain_rarity_name = plain_rarity_name,
	rarity_name = rarity_name,
	rating_alpha = rating_alpha,
	resolved_rating_color = resolved_rating_color,
}

return RarityRating
