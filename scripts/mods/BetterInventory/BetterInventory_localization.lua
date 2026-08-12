local resolver = rawget(_G, "get_mod")
local mod = type(resolver) == "function" and resolver("BetterInventory") or nil
local localization = {}

local function load_shard(file_name)
	if not mod or type(mod.io_dofile) ~= "function" then
		return {}
	end

	local ok, shard = pcall(mod.io_dofile, mod, "BetterInventory/scripts/mods/BetterInventory/" .. file_name)

	return ok and type(shard) == "table" and shard or {}
end

local function merge_base_shard(shard, file_name)
	for localization_id, entry in pairs(shard) do
		if localization[localization_id] ~= nil then
			error("Duplicate BetterInventory localization ID in " .. file_name .. ": " .. tostring(localization_id))
		end

		localization[localization_id] = entry
	end
end

merge_base_shard(load_shard("BetterInventory_localization_core"), "core")
merge_base_shard(load_shard("BetterInventory_localization_features"), "features")

for localization_id, text in pairs(load_shard("BetterInventory_localization_zh_cn")) do
	local entry = localization[localization_id]

	if entry then
		entry["zh-cn"] = text
	end
end

-- Character-slot controls must exist in the static DMF schema so their
-- cardinality is stable for Alf's DMF Extensions and across cold starts. Their
-- initialized titles are replaced with discovered operative names at runtime.
for index = 1, 64 do
	localization["automatic_curio_character_slot_" .. tostring(index)] = {
		en = "Character " .. tostring(index),
		["zh-cn"] = "角色 " .. tostring(index),
	}
end

-- Image-layout controls use generated IDs so weapon/Curio, view context, and
-- each column profile persist independently. DMF's schema still requires a
-- localization record for every generated setting ID even when the visible
-- widget deliberately reuses a concise shared label.
local image_item_kinds = { "weapon", "curio" }
local image_contexts = {
	{ key = "inventory", label = "Inventory and Hadron image layout" },
	{ key = "armoury", label = "Armoury Exchange store image layout" },
	{ key = "global_store", label = "Armoury Exchange GlobalStore image layout" },
}
local image_geometry_labels = {
	height_offset_percent = "Image height offset (%%)",
	width_offset_percent = "Image width offset (%%)",
	x_offset_percent = "Image X offset (%%)",
	y_offset_percent = "Image Y offset (%%)",
}

local function add_generated_image_localization(localization_id, text)
	if localization[localization_id] == nil then
		localization[localization_id] = {
			en = text,
			["zh-cn"] = text,
		}
	end
end

for _, item_kind in ipairs(image_item_kinds) do
	local character_prefix = item_kind .. "_image_character_overview"

	add_generated_image_localization(character_prefix .. "_group", "Character Overview")

	for suffix, label in pairs(image_geometry_labels) do
		add_generated_image_localization(character_prefix .. "_" .. suffix, label)
	end

	for _, context in ipairs(image_contexts) do
		local context_prefix = item_kind .. "_image_" .. context.key

		add_generated_image_localization(context_prefix .. "_group", context.label)
		add_generated_image_localization(context_prefix .. "_profile_selector", "Grid-column profile to edit")

		for suffix, label in pairs(image_geometry_labels) do
			add_generated_image_localization(context_prefix .. "_editor_" .. suffix, label)
		end
	end
end

return localization
