local SearchQuery = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_search_query")
local SearchIndex = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_search_index")
local SearchRuntime = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_search_runtime")
local DiscardPolicy = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_discard_policy")
local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")
local ProfileUtils = require("scripts/utilities/profile_utils")
local RaritySettings = require("scripts/settings/item/rarity_settings")

local Integration = {}
local warned_legacy_searcher = false

Integration.warn_legacy_searcher = function(mod, resolver)
	if warned_legacy_searcher or type(resolver) ~= "function" then
		return false
	end

	local ok, legacy = pcall(resolver, "stuff_searcher")

	if not ok or type(legacy) ~= "table" then
		return false
	end

	if type(legacy.is_enabled) == "function" then
		local enabled_ok, enabled = pcall(legacy.is_enabled, legacy)

		if enabled_ok and enabled == false then
			return false
		end
	end

	warned_legacy_searcher = true

	if mod and type(mod.warning) == "function" then
		mod:warning("Stuff Searcher is enabled. Its obsolete layout hooks can conflict with Better Inventory search; disable or remove Stuff Searcher before reporting filtered-layout issues.")
	end

	return true
end

Integration.view_family = function(view, global_store_service)
	if type(view) ~= "table" or view._destroyed or view._better_inventory_search_ui_unavailable then
		return nil
	end

	local class_name = view.__class_name

	if class_name == "InventoryWeaponsView" then
		return "inventory"
	elseif class_name == "CraftingMechanicusModifyView" then
		return "hadron"
	elseif class_name == "CraftingMechanicusBarterItemsView" then
		return "hadron_sacrifice"
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
			compact_perk_search_terms = function(id, description)
				if type(dependencies.CompactWeaponPerkSearchTerms) == "function" then
					return dependencies.CompactWeaponPerkSearchTerms(mod, id, description)
				end
			end,
			custom_tier = dependencies.CustomTier,
			customization_get = function(gear_id)
				if ItemCustomization and type(ItemCustomization.get) == "function" then
					return ItemCustomization.get(mod, gear_id)
				end
			end,
		is_equipped = function(item, context)
			local context_view = context and context.view
			local slots = item and item.slots

			if not context_view or not slots then
				return false
			end

			if type(context_view.is_item_equipped_in_any_slot) == "function" then
				local ok, equipped = pcall(context_view.is_item_equipped_in_any_slot, context_view, item, slots)

				return ok and equipped == true
			elseif type(context_view.equipped_item_in_slot) == "function" then
				local ok, equipped_item = pcall(context_view.equipped_item_in_slot, context_view, slots[1])

				return ok and equipped_item and equipped_item.gear_id == item.gear_id
			end

			return false
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
	local function log_trace(message, ...)
		if mod and type(mod.info) == "function" then
			mod:info("[SearchTrace] " .. tostring(message), ...)
		end
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
				log_trace("presentation lane=unavailable")
				return false
			end

			-- Dim mode never changes native membership, so inventory and Armoury
			-- views only need the existing comparator lane to run again. This is
			-- both cheaper than rebuilding every widget and, importantly, reuses
			-- the post-update resort path that remains compatible when ItemSorting
			-- replaces Darktide's sort options after Better Inventory loads.
			local family = dependencies.view_family(view)

			if mod:get("inventory_search_non_match_behavior") ~= "hide"
				and (family == "inventory" or family == "armoury")
				and type(dependencies.request_resort) == "function" then
				-- ItemSorting can replace the option table after an earlier capture.
				-- Rebind once per settled query, never from the comparator itself.
				dependencies.configure_sort(view)

				local requested = dependencies.request_resort(view)
				log_trace("presentation lane=deferred-resort family=%s requested=%s selected_index=%s", tostring(family), tostring(requested), tostring(view._selected_sort_option_index))

				if requested ~= false then
					view._better_inventory_search_trace_flush = true
					return true
				end
			end

			log_trace("presentation lane=native family=%s", tostring(family))
			view:_present_layout_by_slot_filter(slot_filter, item_type_filter, display_name)

			return true
		end,
		present_external = function(view)
			if not view or view._destroyed or type(view._sort_grid_layout) ~= "function" then
				return false
			end

			local sort_options = view._sort_options or {}
			local sort_option = sort_options[view._selected_sort_option_index or 1]

			view:_sort_grid_layout(sort_option and sort_option.sort_function)

			return true
		end,
		prioritize_equipped = function()
			return mod:get("prioritize_equipped_favorites") ~= false
		end,
		project = SearchIndex.project,
		query = SearchQuery,
		rarity_aliases = SearchIndex.rarity_aliases,
		release_index = SearchIndex.release,
		remember_query = function()
			return mod:get("inventory_search_remember_query") == true
		end,
		trace = log_trace,
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
	local function settings_changed(setting_id)
		if setting_id == "enable_inventory_search" and mod:get(setting_id) == false then
			local released = SearchRuntime.release_all(runtime)
			SearchRuntime.clear_memory(runtime)

			return released
		elseif setting_id == "inventory_search_remember_query" and mod:get(setting_id) ~= true then
			SearchRuntime.clear_memory(runtime)
		end

		local refresh = setting_id == "inventory_search_non_match_behavior"
			or setting_id == "prioritize_equipped_favorites"
			or setting_id == "enable_custom_item_name_and_colors"
			or setting_id == "customization_changed"
			or type(setting_id) == "string" and string.sub(setting_id, 1, 12) == "custom_tier_"

		if not refresh then
			return 0
		end

		local refreshed = 0

		for view in pairs(runtime.states) do
			if SearchRuntime.invalidate_all(runtime, view) then
				refreshed = refreshed + 1
			end
		end

		return refreshed
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
		compose_layout = function(view, layout)
			local composed = SearchRuntime.compose_layout(runtime, view, layout)

			dependencies.begin_view_session(view, "search")
			dependencies.register_cleanup(view, "inventory_search", function(session_view)
				release(session_view)
			end)

			return composed
		end,
		clear_memory = function()
			return SearchRuntime.clear_memory(runtime)
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
		set_query = function(view, query, time)
			return SearchRuntime.set_query(runtime, view, query, time)
		end,
		settings_changed = settings_changed,
		states = runtime.states,
		update = function(view, time)
			return SearchRuntime.update(runtime, view, time)
		end,
	}
end

Integration.install = function(facade, mod, providers, configure_sort, global_store_service)
	providers = type(providers) == "table" and providers or {}
	local integration = Integration.new(mod, {
		CompactWeaponPerkSearchTerms = providers.CompactWeaponPerkSearchTerms,
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

	Integration.warn_legacy_searcher(mod, rawget(_G, "get_mod"))

	facade.search_apply_widget_alpha = integration.apply_widget_alpha
	facade.search_compose_layout = integration.compose_layout
	facade.search_filter_result = integration.filter_result
	facade.search_invalidate_all = integration.invalidate_all
	facade.search_is_active = integration.is_active
	facade.search_query = integration.query
	facade.search_rank = integration.rank
	facade.search_release = integration.release
	facade.search_set_query = integration.set_query
	facade.search_settings_changed = integration.settings_changed
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
