local SearchQuery = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_search_query")
local SearchIndex = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_search_index")
local SearchRuntime = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_search_runtime")
local DiscardPolicy = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_discard_policy")
local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")
local ProfileUtils = require("scripts/utilities/profile_utils")
local RaritySettings = require("scripts/settings/item/rarity_settings")

local Integration = {}

Integration.view_family = function(view, global_store_service)
	if type(view) ~= "table" or view._destroyed then
		return nil
	end

	local class_name = view.__class_name

	if class_name == "InventoryWeaponsView" then
		return "inventory"
	elseif class_name == "CraftingMechanicusModifyView" then
		return "hadron"
	elseif class_name == "MarksVendorView" or class_name == "MarksGoodsVendorView" then
		return "melk"
	elseif class_name == "CreditsVendorView" or class_name == "CreditsGoodsVendorView" then
		if class_name == "CreditsVendorView" and (view._optional_store_service == nil or view._optional_store_service == global_store_service) then
			return "armoury"
		end

		return "vendor"
	end
end

local function search_player(view)
	local player = view and view._preview_player

	if player and not player.__deleted then
		return player
	end

	if view and type(view._player) == "function" then
		local ok, resolved = pcall(view._player, view)

		if ok and resolved and not resolved.__deleted then
			return resolved
		end
	end
end

local function search_profile(view)
	local player = search_player(view)

	if player and type(player.profile) == "function" then
		local ok, profile = pcall(player.profile, player)

		if ok then
			return profile
		end
	end
end

Integration.new = function(mod, dependencies)
	dependencies = type(dependencies) == "table" and dependencies or {}

	if type(SearchQuery) ~= "table" or type(SearchIndex) ~= "table" or type(SearchRuntime) ~= "table" or type(SearchRuntime.new) ~= "function" then
		return nil
	end

	local DiscardPolicy = dependencies.DiscardPolicy
	local ItemCustomization = dependencies.ItemCustomization
	local ProfileUtils = dependencies.ProfileUtils
	local function new_index(view)
		local profile = search_profile(view)
		local presets_ok, profile_presets = pcall(ProfileUtils.get_profile_presets)
		local loadout_gear_ids = DiscardPolicy.equipped_gear_ids(profile, presets_ok and profile_presets or nil)

		return SearchIndex.new({
			custom_tier = dependencies.CustomTier,
			customization_get = function(gear_id)
				if ItemCustomization and type(ItemCustomization.get) == "function" then
					return ItemCustomization.get(mod, gear_id)
				end
			end,
			is_equipped = function(item, context)
				local context_view = context and context.view
				local slots = item and item.slots

				if not context_view or not slots or type(context_view.is_item_equipped_in_any_slot) ~= "function" then
					return false
				end

				local ok, equipped = pcall(context_view.is_item_equipped_in_any_slot, context_view, item, slots)

				return ok and equipped == true
			end,
			is_loadout = function(item)
				return item and item.gear_id and loadout_gear_ids[item.gear_id] == true
			end,
			is_new = function(_, context)
				return context and context.entry and context.entry.new_item_marker == true
			end,
			is_perfect = dependencies.is_perfect,
			items = dependencies.Items,
			localize = rawget(_G, "Localize"),
			master_items = dependencies.MasterItems,
			normalize = SearchQuery.normalize,
			rarity_settings = dependencies.RaritySettings,
		})
	end

	local runtime = SearchRuntime.new({
		character_id = function(view)
			local player = search_player(view)

			if player and type(player.character_id) == "function" then
				local ok, character_id = pcall(player.character_id, player)

				if ok then
					return character_id
				end
			end

			local profile = search_profile(view)

			return profile and (profile.character_id or profile.id)
		end,
		invalidate = SearchIndex.invalidate,
		invalidate_all = SearchIndex.invalidate_all,
		mode = function()
			return mod:get("inventory_search_non_match_behavior")
		end,
		new_index = new_index,
		present = function(view, slot_filter, item_type_filter, display_name)
			if not view or view._destroyed or type(view._present_layout_by_slot_filter) ~= "function" then
				return false
			end

			view:_present_layout_by_slot_filter(slot_filter, item_type_filter, display_name)

			return true
		end,
		project = SearchIndex.project,
		query = SearchQuery,
		rarity_aliases = SearchIndex.rarity_aliases,
		release_index = SearchIndex.release,
		remember_query = function()
			return mod:get("inventory_search_remember_query") == true
		end,
		time = function()
			return Managers and Managers.time and Managers.time:time("main") or 0
		end,
		view_family = function(view)
			if mod:get("enable_inventory_search") == false then
				return nil
			end

			return dependencies.view_family(view)
		end,
	})
	local function release(view)
		return SearchRuntime.release(runtime, view)
	end

	return {
		apply_widget_alpha = function(view)
			return SearchRuntime.apply_widget_alpha(runtime, view)
		end,
		capture_presentation = function(view, slot_filter, item_type_filter, display_name)
			if not SearchRuntime.capture_presentation(runtime, view, slot_filter, item_type_filter, display_name) then
				return false
			end

			dependencies.begin_view_session(view, "search")
			dependencies.register_cleanup(view, "inventory_search", function(session_view)
				release(session_view)
			end)
			dependencies.configure_sort(view)

			return true
		end,
		clear_memory = function()
			return SearchRuntime.clear_memory(runtime)
		end,
		counts = function(view)
			return SearchRuntime.counts(runtime, view)
		end,
		filter_result = function(view, entry, native_result)
			return SearchRuntime.native_filter(runtime, view, entry, native_result)
		end,
		invalidate_all = function(view, time)
			return SearchRuntime.invalidate_all(runtime, view, time)
		end,
		is_active = function(view)
			return SearchRuntime.is_active(runtime, view)
		end,
		query = function(view)
			return SearchRuntime.query(runtime, view)
		end,
		rank = function(view, entry)
			return SearchRuntime.rank(runtime, view, entry)
		end,
		release = release,
		release_all = function()
			return SearchRuntime.release_all(runtime)
		end,
		set_query = function(view, query, chips, time)
			local valid, error_code = SearchRuntime.set_query(runtime, view, query, chips, time)

			if valid then
				dependencies.request_resort(view)
			end

			return valid, error_code
		end,
		states = runtime.states,
		update = function(view, time)
			return SearchRuntime.update(runtime, view, time)
		end,
	}
end

Integration.install = function(facade, mod, providers, configure_sort, global_store_service)
	providers = type(providers) == "table" and providers or {}
	local integration = Integration.new(mod, {
		CustomTier = providers.CustomTier,
		DiscardPolicy = DiscardPolicy,
		ItemCustomization = providers.ItemCustomization,
		Items = Items,
		MasterItems = MasterItems,
		ProfileUtils = ProfileUtils,
		RaritySettings = RaritySettings,
		begin_view_session = facade.begin_view_session,
		configure_sort = configure_sort,
		is_perfect = DiscardPolicy.is_perfect_roll_weapon,
		register_cleanup = facade.register_view_session_cleanup,
		request_resort = facade.request_inventory_resort,
		view_family = function(view)
			return Integration.view_family(view, global_store_service)
		end,
	})

	if not integration then
		return false
	end

	facade.search_apply_widget_alpha = integration.apply_widget_alpha
	facade.search_counts = integration.counts
	facade.search_filter_result = integration.filter_result
	facade.search_invalidate_all = integration.invalidate_all
	facade.search_is_active = integration.is_active
	facade.search_query = integration.query
	facade.search_rank = integration.rank
	facade.search_release = integration.release
	facade.search_set_query = integration.set_query
	facade.search_update = integration.update
	facade.search_capture_presentation = function(_, view, slot_filter, item_type_filter, display_name)
		return integration.capture_presentation(view, slot_filter, item_type_filter, display_name)
	end
	facade.search_shutdown = function(clear_memory)
		local released = integration.release_all()

		if clear_memory ~= false then
			integration.clear_memory()
		end

		return released
	end

	return true
end

return Integration
