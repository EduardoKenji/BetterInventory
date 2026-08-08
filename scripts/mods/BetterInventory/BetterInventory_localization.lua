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

return localization