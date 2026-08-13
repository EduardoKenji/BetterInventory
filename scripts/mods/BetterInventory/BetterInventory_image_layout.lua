local ImageLayout = {}

local PROFILE_KEY_BY_COLUMNS = {
	[1] = "single",
	[2] = "2",
	[3] = "3",
	[4] = "4",
	[5] = "5",
}

local EDITABLE_ITEM_KINDS = { "weapon", "curio" }
local EDITABLE_CONTEXTS = { "inventory", "armoury", "global_store" }
local EDITABLE_SUFFIXES = {
	{ key = "x_offset_percent", minimum = -100, maximum = 100 },
	{ key = "y_offset_percent", minimum = -100, maximum = 100 },
	{ key = "width_offset_percent", minimum = -90, maximum = 200 },
	{ key = "height_offset_percent", minimum = -90, maximum = 200 },
}
local PROFILE_DEFAULTS = {
	weapon = {
		inventory = {
			[3] = { x_offset_percent = -10, y_offset_percent = -1, width_offset_percent = 21, height_offset_percent = 0 },
		},
		armoury = {
			[3] = { x_offset_percent = -10, y_offset_percent = -1, width_offset_percent = 23, height_offset_percent = -10 },
		},
		global_store = {
			[3] = { x_offset_percent = -13, y_offset_percent = 5, width_offset_percent = 29, height_offset_percent = -8 },
		},
	},
	curio = {
		inventory = {
			[3] = { x_offset_percent = -20, y_offset_percent = 7, width_offset_percent = 38, height_offset_percent = 0 },
		},
		armoury = {
			[3] = { x_offset_percent = -20, y_offset_percent = 3, width_offset_percent = 36, height_offset_percent = -6 },
		},
		global_store = {
			[3] = { x_offset_percent = -19, y_offset_percent = 7, width_offset_percent = 35, height_offset_percent = -6 },
		},
	},
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

local function set_setting(mod, setting_id, value)
	if not mod or type(mod.set) ~= "function" then
		return false
	end

	return pcall(mod.set, mod, setting_id, value, false)
end

local function selected_profile_key(mod, prefix)
	local selected = math.floor(setting(mod, prefix .. "_profile_selector", 3, 1, 5))

	return PROFILE_KEY_BY_COLUMNS[selected] or PROFILE_KEY_BY_COLUMNS[1]
end

local function profile_default(item_kind_value, context, columns, suffix)
	local item_defaults = PROFILE_DEFAULTS[item_kind_value]
	local context_defaults = item_defaults and item_defaults[context]
	local profile_defaults = context_defaults and context_defaults[columns]

	return profile_defaults and profile_defaults[suffix] or 0
end

local function sync_editor(mod, prefix)
	local profile_prefix = prefix .. "_" .. selected_profile_key(mod, prefix)
	local changed = false

	for _, suffix in ipairs(EDITABLE_SUFFIXES) do
		local value = setting(mod, profile_prefix .. "_" .. suffix.key, 0, suffix.minimum, suffix.maximum)

		if setting(mod, prefix .. "_editor_" .. suffix.key, 0, suffix.minimum, suffix.maximum) ~= value then
			changed = set_setting(mod, prefix .. "_editor_" .. suffix.key, value) or changed
		end
	end

	return changed
end


-- DMF cannot reliably hide nested groups selected by a dropdown in every
-- options renderer. Keep the five profiles as private persisted settings and
-- expose one four-slider editor which proxies the profile selected above it.
ImageLayout.initialize_settings = function(mod)
	if not mod or type(mod.get) ~= "function" or type(mod.set) ~= "function" then
		return false
	end

	local changed = false

	for _, editable_item_kind in ipairs(EDITABLE_ITEM_KINDS) do
		for _, context in ipairs(EDITABLE_CONTEXTS) do
			local prefix = editable_item_kind .. "_image_" .. context

			for columns = 1, 5 do
				local profile_prefix = prefix .. "_" .. PROFILE_KEY_BY_COLUMNS[columns]

				for _, suffix in ipairs(EDITABLE_SUFFIXES) do
					local setting_id = profile_prefix .. "_" .. suffix.key
					local ok, value = pcall(mod.get, mod, setting_id)

					if ok and value == nil then
						local default = profile_default(editable_item_kind, context, columns, suffix.key)

						changed = set_setting(mod, setting_id, default) or changed
					end
				end
			end

			changed = sync_editor(mod, prefix) or changed
		end
	end

	return changed
end

ImageLayout.sync_editors = function(mod)
	local changed = false

	for _, editable_item_kind in ipairs(EDITABLE_ITEM_KINDS) do
		for _, context in ipairs(EDITABLE_CONTEXTS) do
			changed = sync_editor(mod, editable_item_kind .. "_image_" .. context) or changed
		end
	end

	return changed
end


ImageLayout.on_setting_changed = function(mod, setting_id)
	if type(setting_id) ~= "string" then
		return false
	end

	for _, editable_item_kind in ipairs(EDITABLE_ITEM_KINDS) do
		for _, context in ipairs(EDITABLE_CONTEXTS) do
			local prefix = editable_item_kind .. "_image_" .. context

			if setting_id == prefix .. "_profile_selector" then
				sync_editor(mod, prefix)

				return true
			end

			for _, suffix in ipairs(EDITABLE_SUFFIXES) do
				local editor_id = prefix .. "_editor_" .. suffix.key

				if setting_id == editor_id then
					local profile_id = prefix .. "_" .. selected_profile_key(mod, prefix) .. "_" .. suffix.key
					local value = setting(mod, editor_id, 0, suffix.minimum, suffix.maximum)

					set_setting(mod, profile_id, value)

					return true
				end
			end
		end
	end

	return false
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
