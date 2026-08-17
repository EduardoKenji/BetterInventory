local Items = require("scripts/utilities/items")

local FavoriteIntegration = {}
local hooked_vendor_classes = setmetatable({}, { __mode = "k" })

local DEFAULT_COLORS = {
	"orange",
	"lawn_green",
	"deep_sky_blue",
	"blue_violet",
	"deep_pink",
}

local GLOBAL_STORE_ARMOURY_SERVICE = "get_all_characters_store_custom"
local GLOBAL_STORE_MELK_SERVICE = "get_all_characters_marks_store_custom"
local GLOBAL_STORE_PROFILE_TABLES = {
	[GLOBAL_STORE_ARMOURY_SERVICE] = "character_avatar_data",
	[GLOBAL_STORE_MELK_SERVICE] = "character_avatar_data_contracts",
}

local function myfavorites_mod()
	local success, integration_mod = pcall(get_mod, "MyFavorites")

	if not success or type(integration_mod) ~= "table" then
		return
	end

	if type(integration_mod.is_enabled) == "function" then
		local enabled_ok, enabled = pcall(integration_mod.is_enabled, integration_mod)

		if enabled_ok and enabled == false then
			return
		end
	end

	return integration_mod
end

local function purchased_item_id(item)
	if type(item) == "string" then
		return item
	end

	if type(item) ~= "table" then
		return
	end

	local nested = item.item or item.gear

	return item.uuid or item.gear_id or item.gearId or item.id or type(nested) == "table" and (nested.uuid or nested.gear_id or nested.gearId or nested.id) or nil
end

FavoriteIntegration.is_myfavorites_available = function()
	return myfavorites_mod() ~= nil
end

FavoriteIntegration.color_preview = function(mod, index)
	index = math.clamp(math.floor(tonumber(index) or 1), 1, 5)

	local label = mod:localize("auto_crafter_myfavorites_color_" .. tostring(index))
	local integration_mod = myfavorites_mod()
	local color_name = integration_mod and integration_mod:get("color_definition_" .. tostring(index)) or DEFAULT_COLORS[index]
	local color_factory = type(Color) == "table" and Color[color_name]

	if type(color_factory) ~= "function" then
		return label
	end

	local color_ok, color = pcall(color_factory, 255, true)

	if not color_ok or type(color) ~= "table" then
		return label
	end

	return string.format("{#color(%d,%d,%d)}%s  ■{#reset()}", color[2] or 255, color[3] or 255, color[4] or 255, label)
end

FavoriteIntegration.apply_auto_crafter_color = function(mod, gear_id)
	if type(gear_id) ~= "string" or gear_id == "" then
		return false
	end

	local integration_mod = myfavorites_mod()

	if not integration_mod then
		return false
	end

	local selected_group = math.clamp(math.floor(tonumber(mod:get("auto_crafter_myfavorites_color")) or 1), 1, 5)
	local favorite_item_list = integration_mod:get("favorite_item_list")

	if type(favorite_item_list) ~= "table" then
		favorite_item_list = {}
	end

	-- MyFavorites represents color 1 by the absence of a custom group entry.
	favorite_item_list[gear_id] = selected_group > 1 and selected_group or nil
	integration_mod:set("favorite_item_list", favorite_item_list)

	return true
end

local function global_store_purchase_character_id(view, store_service)
	local profile_table_name = GLOBAL_STORE_PROFILE_TABLES[store_service]
	local offer = view and view._previewed_offer
	local offer_id = type(offer) == "table" and (offer.offerId or offer.offer_id or offer.id)

	if not profile_table_name or not offer_id then
		return
	end

	local success, global_store_mod = pcall(get_mod, "GlobalStore")
	local profiles = success and type(global_store_mod) == "table" and global_store_mod[profile_table_name]
	local profile = type(profiles) == "table" and profiles[offer_id]
	local character_id = type(profile) == "table" and profile.character_id

	return type(character_id) == "string" and character_id ~= "" and character_id or nil
end

FavoriteIntegration.favorite_purchase_items = function(mod, items, setting_id, target_character_id)
	if mod:get(setting_id) ~= true then
		return 0
	end

	local count = 0
	local seen = {}
	local purchased_items = type(items) == "table" and type(items.items) == "table" and items.items or items
	local character_data
	local save_manager

	if target_character_id ~= nil then
		local managers = rawget(_G, "Managers")

		save_manager = managers and managers.save

		if type(save_manager) ~= "table" or type(save_manager.character_data) ~= "function" then
			return 0
		end

		local data_ok, data = pcall(save_manager.character_data, save_manager, target_character_id)

		if not data_ok or type(data) ~= "table" then
			return 0
		end

		character_data = data
		character_data.favorite_items = type(character_data.favorite_items) == "table" and character_data.favorite_items or {}
	end

	for _, item in pairs(type(purchased_items) == "table" and purchased_items or {}) do
		local gear_id = purchased_item_id(item)

		if gear_id and not seen[gear_id] then
			seen[gear_id] = true
			local success

			if character_data then
				character_data.favorite_items[gear_id] = true
				success = true
			else
				success = pcall(Items.set_item_id_as_favorite, gear_id, true)
			end

			if success then
				count = count + 1
			end
		end
	end

	if character_data and count > 0 and type(save_manager.queue_save) == "function" then
		pcall(save_manager.queue_save, save_manager)
	end

	return count
end

local function matches_purchase_source(view, optional_global_store_service)
	local store_service = view and view._optional_store_service

	return store_service == nil or store_service == optional_global_store_service
end

local function install_vendor_hook(mod, vendor_class, setting_id, optional_global_store_service)
	if type(vendor_class) ~= "table" or hooked_vendor_classes[vendor_class] or type(vendor_class._on_purchase_complete) ~= "function" then
		return false
	end

	hooked_vendor_classes[vendor_class] = true
	mod:hook_safe(vendor_class, "_on_purchase_complete", function(view, items)
		if matches_purchase_source(view, optional_global_store_service) then
			local store_service = view and view._optional_store_service
			local target_character_id

			if store_service ~= nil then
				target_character_id = global_store_purchase_character_id(view, store_service)

				-- Never fall back to the active character for a cross-character store.
				-- Darktide's Items helper would persist the favorite in the wrong save.
				if not target_character_id then
					return
				end
			end

			FavoriteIntegration.favorite_purchase_items(mod, items, setting_id, target_character_id)
		end
	end)

	return true
end

FavoriteIntegration.install_manual_purchase_hooks = function(mod, vendor_classes)
	vendor_classes = type(vendor_classes) == "table" and vendor_classes or {}

	local function install_group(classes, setting_id, optional_global_store_service)
		if type(classes) == "table" and type(classes._on_purchase_complete) == "function" then
			install_vendor_hook(mod, classes, setting_id, optional_global_store_service)

			return
		end

		for _, vendor_class in pairs(type(classes) == "table" and classes or {}) do
			install_vendor_hook(mod, vendor_class, setting_id, optional_global_store_service)
		end
	end

	install_group(vendor_classes.armoury, "armoury_auto_favorite_purchased_items", GLOBAL_STORE_ARMOURY_SERVICE)
	install_group(vendor_classes.melk_limited, "melk_auto_favorite_purchased_items", GLOBAL_STORE_MELK_SERVICE)
	install_group(vendor_classes.melk_mystery, "melk_mystery_auto_favorite_purchased_items")
end

FavoriteIntegration._test = {
	myfavorites_mod = myfavorites_mod,
	purchased_item_id = purchased_item_id,
	global_store_purchase_character_id = global_store_purchase_character_id,
	matches_purchase_source = matches_purchase_source,
}

return FavoriteIntegration
