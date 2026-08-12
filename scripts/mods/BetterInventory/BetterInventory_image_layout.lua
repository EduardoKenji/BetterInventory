local ImageLayout = {}

local PROFILE_KEY_BY_COLUMNS = {
	[1] = "single",
	[2] = "2",
	[3] = "3",
	[4] = "4",
	[5] = "5",
}

local VALID_CONTEXTS = {
	inventory = true,
	armoury = true,
	global_store = true,
	character_overview = true,
}

local function rounded(value)
	if value < 0 then
		return math.ceil(value - 0.5)
	end

	return math.floor(value + 0.5)
end

local function finite_number(value, fallback, minimum, maximum)
	value = tonumber(value)

	if not value or value ~= value or value == math.huge or value == -math.huge then
		value = fallback
	end

	return math.max(minimum, math.min(maximum, value))
end

local function setting(mod, setting_id, fallback, minimum, maximum)
	if not mod or type(mod.get) ~= "function" then
		return fallback
	end

	local ok, value = pcall(mod.get, mod, setting_id)

	if not ok then
		return fallback
	end

	return finite_number(value, fallback, minimum, maximum)
end

local function item_kind(slot_kind)
	if slot_kind == "curio" or type(slot_kind) == "string" and string.match(slot_kind, "^slot_attachment_") then
		return "curio"
	end

	if slot_kind == "weapon" or slot_kind == "melee" or slot_kind == "ranged" or slot_kind == "slot_primary" or slot_kind == "slot_secondary" then
		return "weapon"
	end
end

local function profile_prefix(configuration, columns, explicit_item_kind)
	configuration = configuration or {}
	local resolved_item_kind = explicit_item_kind or item_kind(configuration.slot_kind)
	local context = configuration.image_layout_context

	if resolved_item_kind ~= "weapon" and resolved_item_kind ~= "curio" then
		return
	end

	if context == "character_overview" or configuration.character_overview == true then
		return resolved_item_kind .. "_image_character_overview", resolved_item_kind, "character_overview", 1
	end

	if not VALID_CONTEXTS[context] then
		return
	end

	columns = math.max(1, math.min(5, math.floor(finite_number(columns, 1, 1, 5))))

	return resolved_item_kind .. "_image_" .. context .. "_" .. PROFILE_KEY_BY_COLUMNS[columns], resolved_item_kind, context, columns
end

ImageLayout.resolve = function(mod, configuration, columns, explicit_item_kind)
	local prefix, resolved_item_kind, context, resolved_columns = profile_prefix(configuration, columns, explicit_item_kind)

	if not prefix then
		return
	end

	return {
		columns = resolved_columns,
		context = context,
		height_offset_percent = setting(mod, prefix .. "_height_offset_percent", 0, -90, 200),
		item_kind = resolved_item_kind,
		prefix = prefix,
		width_offset_percent = setting(mod, prefix .. "_width_offset_percent", 0, -90, 200),
		x_offset_percent = setting(mod, prefix .. "_x_offset_percent", 0, -100, 100),
		y_offset_percent = setting(mod, prefix .. "_y_offset_percent", 0, -100, 100),
	}
end

ImageLayout.apply_style = function(style, card_size, profile)
	if type(style) ~= "table" or type(card_size) ~= "table" or type(profile) ~= "table" then
		return false
	end

	local card_width = finite_number(card_size[1], 0, 0, 100000)
	local card_height = finite_number(card_size[2], 0, 0, 100000)
	local x_percent = finite_number(profile.x_offset_percent, 0, -100, 100)
	local y_percent = finite_number(profile.y_offset_percent, 0, -100, 100)
	local width_percent = finite_number(profile.width_offset_percent, 0, -90, 200)
	local height_percent = finite_number(profile.height_offset_percent, 0, -90, 200)

	if x_percent == 0 and y_percent == 0 and width_percent == 0 and height_percent == 0 then
		return false
	end

	if x_percent ~= 0 or y_percent ~= 0 then
		style.offset = style.offset or { 0, 0, 0 }
		style.offset[1] = (tonumber(style.offset[1]) or 0) + rounded(card_width * x_percent * 0.01)
		style.offset[2] = (tonumber(style.offset[2]) or 0) + rounded(card_height * y_percent * 0.01)
	end

	if width_percent ~= 0 or height_percent ~= 0 then
		style.size = style.size or { card_width, card_height }
		local base_width = finite_number(style.size[1], card_width, 1, 100000)
		local base_height = finite_number(style.size[2], card_height, 1, 100000)

		style.size[1] = math.max(1, rounded(base_width * (1 + width_percent * 0.01)))
		style.size[2] = math.max(1, rounded(base_height * (1 + height_percent * 0.01)))
	end

	return true
end

ImageLayout.apply_blueprint = function(mod, blueprint, configuration, columns, explicit_item_kind)
	if type(blueprint) ~= "table" or type(blueprint.pass_template) ~= "table" then
		return false
	end

	local profile = ImageLayout.resolve(mod, configuration, columns, explicit_item_kind)

	if not profile then
		return false
	end

	for _, pass in ipairs(blueprint.pass_template) do
		if pass.style_id == "icon" and type(pass.style) == "table" then
			return ImageLayout.apply_style(pass.style, blueprint.size or {}, profile)
		end
	end

	return false
end

ImageLayout.item_kind = item_kind
ImageLayout.profile_prefix = profile_prefix

return ImageLayout
