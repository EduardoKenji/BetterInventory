local SearchIndex = {}

local DEFAULT_MAX_PROJECTED_BYTES = 2048
local MAX_COLLECTION_ENTRIES = 16
local NATIVE_RARITY_NAMES = {
	[1] = "profane",
	[2] = "redeemed",
	[3] = "anointed",
	[4] = "exalted",
	[5] = "transcendent",
	[6] = "sainted",
}

local function weak_key_table()
	return setmetatable({}, {
		__mode = "k",
	})
end

local function safe_member(object, key)
	if type(object) ~= "table" then
		return nil
	end

	local ok, value = pcall(function()
		return object[key]
	end)

	return ok and value or nil
end

local function safe_call(callback, ...)
	if type(callback) ~= "function" then
		return nil
	end

	local ok, first, second = pcall(callback, ...)

	if ok then
		return first, second
	end

	return nil
end


local function item_from(value)
	if type(value) ~= "table" then
		return nil
	end

	return safe_member(value, "real_item") or safe_member(value, "item") or value
end

local function collection_count(collection)
	return type(collection) == "table" and math.min(#collection, MAX_COLLECTION_ENTRIES) or 0
end

local function append_fingerprint(parts, value)
	local value_type = type(value)

	if value_type == "string" or value_type == "number" or value_type == "boolean" then
		parts[#parts + 1] = tostring(value)
	else
		parts[#parts + 1] = ""
	end
end

local function append_collection_fingerprint(parts, collection)
	local count = collection_count(collection)
	parts[#parts + 1] = tostring(count)

	for index = 1, count do
		local entry = safe_member(collection, index)
		append_fingerprint(parts, safe_member(entry, "id"))
		append_fingerprint(parts, safe_member(entry, "rarity"))
		append_fingerprint(parts, safe_member(entry, "value"))
		append_fingerprint(parts, safe_member(entry, "name"))
	end
end

local function fingerprint(item, dependencies, context)
	local parts = {}

	for _, key in ipairs({
		"gear_id",
		"id",
		"name",
		"display_name",
		"item_type",
		"rarity",
		"revision",
		"version",
		"baseItemLevel",
		"expertise",
		"item_level",
	}) do
		append_fingerprint(parts, safe_member(item, key))
	end

	for _, key in ipairs({
		"weapon_family_display_name",
		"weapon_pattern_display_name",
		"weapon_mark_display_name",
	}) do
		local definition = safe_member(item, key)
		append_fingerprint(parts, safe_member(definition, "loc_id"))
	end

	append_collection_fingerprint(parts, safe_member(item, "base_stats"))
	append_collection_fingerprint(parts, safe_member(item, "perks"))
	append_collection_fingerprint(parts, safe_member(item, "traits"))
	local customization = safe_call(dependencies and dependencies.customization_get, safe_member(item, "gear_id"))

	append_fingerprint(parts, safe_member(customization, "name"))
	for _, provider_name in ipairs({ "is_favorited", "is_equipped", "is_loadout", "is_new", "is_perfect" }) do
		append_fingerprint(parts, safe_call(dependencies and dependencies[provider_name], item, context) == true and 1 or 0)
	end

	return table.concat(parts, "\31")
end

local function new_record()
	return {
		base = nil,
		blessing = {},
		equipped = false,
		favorite = false,
		loadout = false,
		mark = {},
		name = {},
		native_rarity = {},
		new = false,
		perk = {},
		perfect = false,
		rarity = {},
		rating = nil,
		text = {},
		type = {},
	}
end

local function is_valid_text(value)
	return type(value) == "string" and value ~= "" and value ~= "-" and value ~= "n/a"
end

local function new_builder(normalize, maximum_bytes)
	local builder = {
		bytes = 0,
		maximum_bytes = maximum_bytes,
		normalize = normalize,
		record = new_record(),
		seen = {},
	}

	local function append(field, value, include_in_text)
		if not is_valid_text(value) then
			return false
		end

		local normalized = normalize(value)

		if normalized == "" then
			return false
		end

		local bytes = #normalized

		if builder.bytes + bytes > builder.maximum_bytes then
			return false
		end

		local seen = builder.seen[field]

		if not seen then
			seen = {}
			builder.seen[field] = seen
		end

		if not seen[normalized] then
			local values = builder.record[field]
			values[#values + 1] = normalized
			seen[normalized] = true
			builder.bytes = builder.bytes + bytes
		end

		if include_in_text ~= false and field ~= "text" then
			append("text", normalized, false)
		end

		return true
	end

	builder.append = append

	return builder
end

local function localize(dependencies, key)
	if not is_valid_text(key) then
		return nil
	end

	local value = safe_call(dependencies.localize, key)

	return is_valid_text(value) and value or key
end

local function resolve_master_item(dependencies, id)
	local master_items = dependencies.master_items
	local getter = master_items and master_items.get_item

	return safe_call(getter, id)
end

local function append_localized_definition(builder, dependencies, field, definition, include_in_text)
	local loc_id = safe_member(definition, "loc_id")

	if loc_id then
		builder.append(field, localize(dependencies, loc_id), include_in_text)
		builder.append(field, loc_id, include_in_text)
	end
end

local function append_item_names(builder, dependencies, item)
	local gear_id = safe_member(item, "gear_id")
	local custom_record = safe_call(dependencies.customization_get, gear_id)
	local custom_name = safe_member(custom_record, "name")

	builder.append("name", custom_name)

	local item_display_name = safe_member(item, "display_name")

	if item_display_name then
		builder.append("name", localize(dependencies, item_display_name))
		builder.append("name", item_display_name)
	end

	append_localized_definition(builder, dependencies, "name", safe_member(item, "weapon_family_display_name"))
	append_localized_definition(builder, dependencies, "name", safe_member(item, "weapon_pattern_display_name"))
	append_localized_definition(builder, dependencies, "mark", safe_member(item, "weapon_mark_display_name"))

	for _, key in ipairs({ "id", "name", "__master_item", "master_id" }) do
		builder.append("name", safe_member(item, key))
	end
end

local function append_trait_collection(builder, dependencies, item, collection, field)
	local count = collection_count(collection)

	for index = 1, count do
		local entry = safe_member(collection, index)
		local id = safe_member(entry, "id") or safe_member(entry, "name")

		builder.append(field, id)

		local master_item = resolve_master_item(dependencies, id)
		local display_name = safe_member(master_item, "display_name") or safe_member(entry, "display_name")

		if display_name then
			builder.append(field, localize(dependencies, display_name))
			builder.append(field, display_name)
		end

		local trait_name = safe_member(master_item, "trait") or safe_member(entry, "trait")
		builder.append(field, trait_name)

		local description = safe_call(dependencies.trait_description, master_item or entry, safe_member(entry, "rarity"), safe_member(entry, "value"))

		if is_valid_text(description) then
			builder.append(field, description)
		end
	end
end

local function rarity_name(dependencies, rarity)
	local settings = dependencies.rarity_settings
	local definition = type(settings) == "table" and safe_member(settings, rarity)
	local localization_key = safe_member(definition, "display_name")

	return localize(dependencies, localization_key), NATIVE_RARITY_NAMES[rarity]
end

local function custom_tier_matches(dependencies, item)
	local custom_tier = dependencies.custom_tier
	local matches = custom_tier and custom_tier.matches

	return safe_call(matches, item) == true
end

local function append_rarity(builder, dependencies, item)
	local native_rarity = tonumber(safe_member(item, "rarity"))
	local native_localized, native_canonical = rarity_name(dependencies, native_rarity)
	local sainted = native_rarity == 5 and custom_tier_matches(dependencies, item)
	local effective_rarity = sainted and 6 or native_rarity
	local effective_localized, effective_canonical = rarity_name(dependencies, effective_rarity)

	builder.append("rarity", effective_localized)
	builder.append("rarity", effective_canonical)
	builder.append("native_rarity", native_localized, false)
	builder.append("native_rarity", native_canonical, false)
	builder.append("native_rarity", native_rarity and tostring(native_rarity), false)

	return sainted
end

local function append_type(builder, item)
	local item_type = safe_member(item, "item_type")

	builder.append("type", item_type)

	if item_type == "WEAPON_MELEE" then
		builder.append("type", "weapon")
		builder.append("type", "melee")
	elseif item_type == "WEAPON_RANGED" then
		builder.append("type", "weapon")
		builder.append("type", "ranged")
	elseif item_type == "GADGET" then
		builder.append("type", "curio")
		builder.append("type", "gadget")
	end
end

local function number_from_call(callback, item)
	local value = safe_call(callback, item, true)

	return tonumber(value)
end

local function sum_base_stats(item)
	local base_stats = safe_member(item, "base_stats")
	local count = collection_count(base_stats)
	local total = 0
	local found = false

	for index = 1, count do
		local value = tonumber(safe_member(safe_member(base_stats, index), "value"))

		if value then
			found = true
			total = total + value
		end
	end

	return found and math.floor(total * 100 + 0.5) or nil
end

local function boolean_provider(callback, item, context)
	return safe_call(callback, item, context) == true
end

local function build_record(index, item, context)
	local dependencies = index.dependencies
	local builder = new_builder(dependencies.normalize, index.maximum_projected_bytes)
	local record = builder.record

	append_item_names(builder, dependencies, item)
	append_type(builder, item)
	local sainted = append_rarity(builder, dependencies, item)
	local item_type = safe_member(item, "item_type")
	local traits_field = item_type == "GADGET" and "perk" or "blessing"

	append_trait_collection(builder, dependencies, item, safe_member(item, "traits"), traits_field)
	append_trait_collection(builder, dependencies, item, safe_member(item, "perks"), "perk")

	record.rating = number_from_call(dependencies.expertise_level, item)
		or tonumber(safe_member(item, "expertise"))
		or tonumber(safe_member(item, "item_level"))
	record.base = number_from_call(dependencies.total_stats_value, item) or sum_base_stats(item)
	record.favorite = boolean_provider(dependencies.is_favorited, item, context)
	record.equipped = boolean_provider(dependencies.is_equipped, item, context)
	record.new = boolean_provider(dependencies.is_new, item, context)
	record.loadout = boolean_provider(dependencies.is_loadout, item, context)
	record.perfect = sainted or boolean_provider(dependencies.is_perfect, item, context)
	record.projected_bytes = builder.bytes

	return record
end

SearchIndex.new = function(dependencies)
	dependencies = type(dependencies) == "table" and dependencies or {}
	local normalize = dependencies.normalize

	if type(normalize) ~= "function" then
		normalize = function(value)
			return string.lower(tostring(value or ""))
		end
	end

	dependencies.normalize = normalize
	local items = dependencies.items or {}
	dependencies.expertise_level = dependencies.expertise_level or items.expertise_level
	dependencies.total_stats_value = dependencies.total_stats_value or items.total_stats_value
	dependencies.trait_description = dependencies.trait_description or items.trait_description
	dependencies.is_favorited = dependencies.is_favorited or function(item)
		return safe_call(items.is_item_id_favorited, safe_member(item, "gear_id")) == true
	end
	dependencies.localize = dependencies.localize or rawget(_G, "Localize") or function(key)
		return key
	end

	return {
		cache = weak_key_table(),
		dependencies = dependencies,
		generation = 1,
		maximum_projected_bytes = tonumber(dependencies.max_projected_bytes) or DEFAULT_MAX_PROJECTED_BYTES,
		metrics = {
			builds = 0,
			failures = 0,
			hits = 0,
		},
	}
end

SearchIndex.project = function(index, value, context)
	local item = item_from(value)

	if type(index) ~= "table" or type(item) ~= "table" then
		return nil, false
	end

	local fingerprint_ok, current_fingerprint = pcall(fingerprint, item, index.dependencies, context)

	if not fingerprint_ok then
		index.metrics.failures = index.metrics.failures + 1
		return nil, false
	end

	local cached = index.cache[item]

	if cached and cached.fingerprint == current_fingerprint then
		index.metrics.hits = index.metrics.hits + 1
		return cached.record, true
	end

	local ok, record = pcall(build_record, index, item, context)

	if not ok or type(record) ~= "table" then
		index.metrics.failures = index.metrics.failures + 1
		return nil, false
	end

	index.cache[item] = {
		fingerprint = current_fingerprint,
		record = record,
	}
	index.metrics.builds = index.metrics.builds + 1

	return record, true
end

SearchIndex.invalidate = function(index, value)
	local item = item_from(value)

	if type(index) ~= "table" or type(item) ~= "table" then
		return false
	end

	index.cache[item] = nil

	return true
end

SearchIndex.invalidate_all = function(index)
	if type(index) ~= "table" then
		return false
	end

	index.cache = weak_key_table()
	index.generation = index.generation + 1

	return true
end

SearchIndex.release = function(index)
	if type(index) ~= "table" then
		return false
	end

	index.cache = weak_key_table()
	index.dependencies = {}
	index.generation = index.generation + 1

	return true
end

SearchIndex.rarity_aliases = function(index)
	local aliases = {}
	local dependencies = index and index.dependencies or {}

	for rarity = 1, 6 do
		local localized, canonical = rarity_name(dependencies, rarity)

		if is_valid_text(localized) and canonical then
			aliases[localized] = canonical
		end
	end

	return aliases
end

SearchIndex.fingerprint = fingerprint
SearchIndex.native_rarity_names = NATIVE_RARITY_NAMES

return SearchIndex
