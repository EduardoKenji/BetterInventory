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
	elseif class_name == "MarksVendorView" then
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

local function selected_tab_context(view)
	local tabs = view and view._tabs_content
	local tab_menu = view and view._tab_menu_element

	if type(tabs) ~= "table" or type(tab_menu) ~= "table" or type(tab_menu.selected_index) ~= "function" then
		return nil
	end

	local ok, selected_index = pcall(tab_menu.selected_index, tab_menu)
	local tab = ok and tabs[selected_index]

	if type(tab) ~= "table" then
		return nil
	end

	return {
		display_name = not tab.hide_display_name and tab.display_name or nil,
		item_type_filter = nil,
		kind = "native",
		slot_filter = tab.slot_types,
	}
end

local function presentation_context(view)
	if type(view) ~= "table" or view._destroyed then
		return nil
	elseif view.__class_name == "CraftingMechanicusBarterItemsView" then
		return type(view._sort_grid_layout) == "function" and { kind = "external" } or nil
	elseif type(view._present_layout_by_slot_filter) ~= "function" then
		return nil
	end

	-- A view that was already open during Ctrl+Shift+R cannot replay the native
	-- presentation call that preceded the new runtime. Recover its selected tab
	-- contract without retaining or cloning the current item layout.
	return selected_tab_context(view) or {
		display_name = view._grid_display_name,
		item_type_filter = nil,
		kind = "native",
		slot_filter = nil,
	}
end

local function clear_array(values)
	for index = #values, 1, -1 do
		values[index] = nil
	end
end

local function clear_map(values)
	for key in pairs(values) do
		values[key] = nil
	end
end

local function layout_item(entry)
	return type(entry) == "table" and (entry.real_item or entry.item) or nil
end

-- Search presentation reuses current grid membership and widget identities.
-- Replaying `_present_layout_by_slot_filter` is especially costly: native
-- `present_grid_layout` adds a fresh spacing entry without an entry_id, which
-- makes ViewElementGrid destroy and recreate every card. Build the new order
-- from the grid's canonical widgets and commit it through the native in-place
-- reorder API instead. Hide omits unmatched entries only from visible layout;
-- canonical `_grid_layout` stays complete. Two retained buffers ensure grid
-- never observes an array being cleared for next query.
local function reorder_existing_grid(view, configure_sort, runtime, hide_unmatched)
	local item_grid = view and view._item_grid
	local source = item_grid and item_grid._grid_layout
	local alignments = item_grid and item_grid._all_grid_alignment_widgets
	local widgets_by_id = item_grid and item_grid._widgets_by_entry_id

	if not view or view._destroyed or type(source) ~= "table" or type(alignments) ~= "table"
		or type(widgets_by_id) ~= "table" or type(item_grid.update_grid_layout) ~= "function"
		or #source ~= #alignments then
		return false
	end

	if type(configure_sort) ~= "function" then
		return false
	end

	configure_sort(view)

	local buffers = view._better_inventory_search_grid_buffers

	if type(buffers) ~= "table" then
		buffers = {
			active = 0,
			anchors = {{}, {}},
			layouts = {{}, {}},
			positions = {{}, {}},
			source_positions = {},
			source_ranks = {},
		}
		view._better_inventory_search_grid_buffers = buffers
	end

	if type(buffers.source_positions) ~= "table" then
		buffers.source_positions = {}
	end
	if type(buffers.source_ranks) ~= "table" then
		buffers.source_ranks = {}
	end

	-- `_grid_layout` is Darktide's canonical layout and is already ordered by
	-- the selected BetterInventory, ItemSorting, or native comparator. Preserve
	-- that order as the tie-break instead of invoking the comparator again for
	-- every settled query. This is both stable and important for compatibility:
	-- name-decorating mods such as GodRolls can perform a full weapon-stat
	-- projection inside Items.display_name, which native name tie-breakers call
	-- O(n log n) times during an otherwise allocation-free search reorder.
	--
	-- Cache one scalar rank per canonical entry before sorting. Calling
	-- SearchRuntime.rank from the comparator repeated view/state resolution
	-- O(n log n) times even though every entry already has a settled result.
	-- Version the retained closure so Ctrl+Shift+R replaces pre-v3.4.1 closures
	-- that captured the old runtime generation.
	if buffers.rank_sort_version ~= 1 or type(buffers.rank_sort) ~= "function" then
		buffers.rank_sort_version = 1
		buffers.rank_sort = function(left, right)
			local left_rank = buffers.source_ranks[left] or 0
			local right_rank = buffers.source_ranks[right] or 0

			if left_rank ~= right_rank then
				return left_rank > right_rank
			end

			return (buffers.source_positions[left] or math.huge) < (buffers.source_positions[right] or math.huge)
		end
	end

	-- Drop closures left by pre-v3.4.1 hot reloads so an already-open view does
	-- not retain the previous search runtime until it closes.
	buffers.fallback_runtime = nil
	buffers.fallback_sort = nil
	buffers.rank_runtime = nil
	clear_map(buffers.source_positions)
	clear_map(buffers.source_ranks)

	local buffer_index = buffers.active == 1 and 2 or 1
	local target = buffers.layouts[buffer_index]
	local anchors = buffers.anchors[buffer_index]
	local positions = buffers.positions[buffer_index]
	local anchor_count = 0
	local selected_widget = type(item_grid.selected_grid_widget) == "function" and item_grid:selected_grid_widget() or nil
	local selected_entry_id = selected_widget and selected_widget.entry_id

	clear_array(target)

	for index = 1, #source do
		local alignment = alignments[index]
		local entry_id = alignment and alignment.entry_id
		local widget_record = entry_id and widgets_by_id[entry_id]
		local source_entry = source[index]

		if not entry_id or type(widget_record) ~= "table" then
			return false
		end

		local widget = widget_record.widget
		local content = widget and widget.content
		local entry = content and (content.entry or content.element) or source_entry

		if layout_item(entry) then
			if entry.entry_id ~= entry_id then
				return false
			end
			buffers.source_positions[entry] = index
			buffers.source_ranks[entry] = SearchRuntime.rank(runtime, view, entry)

			if hide_unmatched ~= true or SearchRuntime.matches(runtime, view, entry) then
				target[#target + 1] = entry
			end
		else
			anchor_count = anchor_count + 1
			positions[anchor_count] = index

			if source_entry and source_entry.entry_id == entry_id then
				anchors[anchor_count] = source_entry
			else
				local anchor = anchors[anchor_count]

				if type(anchor) ~= "table" or anchor._better_inventory_search_anchor ~= true then
					anchor = {_better_inventory_search_anchor = true}
					anchors[anchor_count] = anchor
				end

				anchor.entry_id = entry_id
				anchor.is_external = true
				anchor.widget_type = source_entry and source_entry.widget_type or "spacing_vertical"
			end
		end
	end

	for index = #anchors, anchor_count + 1, -1 do
		anchors[index] = nil
		positions[index] = nil
	end

	if #target > 1 then
		table.sort(target, buffers.rank_sort)
	end

	for index = 1, anchor_count do
		table.insert(target, math.min(positions[index], #target + 1), anchors[index])
	end

	item_grid:update_grid_layout(target)
	local reordered_widgets = item_grid._grid_widgets

	if selected_entry_id and type(reordered_widgets) == "table" and item_grid._grid then
		for index = 1, #reordered_widgets do
			if reordered_widgets[index].entry_id == selected_entry_id then
				item_grid._grid._selected_grid_index = index
				break
			end
		end
	end

	buffers.active = buffer_index

	return true
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
			compact_curio_perk_search_terms = function(id, description)
				if type(dependencies.CompactCurioPerkSearchTerms) == "function" then
					return dependencies.CompactCurioPerkSearchTerms(mod, id, description)
				end
			end,
			curio_trait_search_terms = function(id)
				if type(dependencies.CurioTraitSearchTerms) == "function" then
					return dependencies.CurioTraitSearchTerms(mod, id)
				end
			end,
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
	local runtime

	runtime = SearchRuntime.new({
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

			-- Hide mode, post-hide restoration, and a drifted in-place grid contract
			-- fall back to Darktide's authoritative filtering/presentation path.
			dependencies.configure_sort(view)
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
		presentation_context = presentation_context,
		prioritize_equipped = function()
			return mod:get("prioritize_equipped_favorites") ~= false
		end,
		project = SearchIndex.project,
		query = SearchQuery,
		rarity_aliases = SearchIndex.rarity_aliases,
		reorder = function(view, hide_unmatched)
			return reorder_existing_grid(view, dependencies.configure_sort, runtime, hide_unmatched)
		end,
		release_grid = function(view)
			if type(view) == "table" then
				view._better_inventory_search_grid_buffers = nil
			end
		end,
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
			elseif view and view.__class_name == "CreditsGoodsVendorView"
				and mod:get("enable_inventory_search_brunt") ~= true then
				return nil
			end

			return dependencies.view_family(view)
		end,
	})
	local function release(view)
		return SearchRuntime.release(runtime, view)
	end
	local function release_view_search(session_view)
		return release(session_view)
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
			dependencies.register_cleanup(view, "inventory_search", release_view_search)
			dependencies.configure_sort(view)

			return true
		end,
		compose_layout = function(view, layout)
			local composed = SearchRuntime.compose_layout(runtime, view, layout)

			dependencies.begin_view_session(view, "search")
			dependencies.register_cleanup(view, "inventory_search", release_view_search)

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
		CompactCurioPerkSearchTerms = providers.CompactCurioPerkSearchTerms,
		CompactWeaponPerkSearchTerms = providers.CompactWeaponPerkSearchTerms,
		CurioTraitSearchTerms = providers.CurioTraitSearchTerms,
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
