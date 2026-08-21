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

local function gradient_text(text, start_color, end_color)
	local characters = {}

	for character in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
		characters[#characters + 1] = character
	end

	local result = {}
	local denominator = math.max(#characters - 1, 1)

	for index, character in ipairs(characters) do
		local amount = (index - 1) / denominator
		local red = math.floor(start_color[1] + (end_color[1] - start_color[1]) * amount)
		local green = math.floor(start_color[2] + (end_color[2] - start_color[2]) * amount)
		local blue = math.floor(start_color[3] + (end_color[3] - start_color[3]) * amount)

		result[#result + 1] = string.format("{#color(%d,%d,%d)}%s", red, green, blue, character)
	end

	return table.concat(result) .. "{#reset()}"
end

local name_gradient_start = { 184, 239, 110 } -- #B8EF6E
local name_gradient_end = { 195, 57, 120 } -- #C33978

for language, text in pairs(localization.mod_name or {}) do
	localization.mod_name[language] = gradient_text(text, name_gradient_start, name_gradient_end)
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
	{ key = "inventory", label = "Inventory and Hadron image layout", zh_cn = "库存和哈德隆图像布局" },
	{ key = "armoury", label = "Armoury Exchange store image layout", zh_cn = "军械库交易所商店图像布局" },
	{ key = "global_store", label = "Armoury Exchange GlobalStore image layout", zh_cn = "军械库交易所 GlobalStore 图像布局" },
}
local image_geometry_labels = {
	height_offset_percent = { en = "Image height offset (%%)", zh_cn = "图像高度偏移（%%）" },
	width_offset_percent = { en = "Image width offset (%%)", zh_cn = "图像宽度偏移（%%）" },
	x_offset_percent = { en = "Image X offset (%%)", zh_cn = "图像 X 偏移（%%）" },
	y_offset_percent = { en = "Image Y offset (%%)", zh_cn = "图像 Y 偏移（%%）" },
}

local function add_generated_image_localization(localization_id, text, zh_cn)
	if localization[localization_id] == nil then
		localization[localization_id] = {
			en = text,
			["zh-cn"] = zh_cn,
		}
	end
end

for _, item_kind in ipairs(image_item_kinds) do
	local character_prefix = item_kind .. "_image_character_overview"

	add_generated_image_localization(character_prefix .. "_group", "Character Overview", "角色总览")

	for suffix, labels in pairs(image_geometry_labels) do
		add_generated_image_localization(character_prefix .. "_" .. suffix, labels.en, labels.zh_cn)
	end

	for _, context in ipairs(image_contexts) do
		local context_prefix = item_kind .. "_image_" .. context.key

		add_generated_image_localization(context_prefix .. "_group", context.label, context.zh_cn)
		add_generated_image_localization(context_prefix .. "_profile_selector", "Grid-column profile to edit", "要编辑的网格列配置")

		for suffix, labels in pairs(image_geometry_labels) do
			add_generated_image_localization(context_prefix .. "_editor_" .. suffix, labels.en, labels.zh_cn)
		end
	end
end

return localization
