local Runtime = {}

local mod
local Layout
local Features
local CurioAcquisition
local ItemCustomization
local EquipmentPersistence
local SettingsRegistry
local Diagnostics
local AutoCrafter
local Capabilities
local CharacterOverviewUI
local FeatureDomains
local FavoriteIntegration
local GodStatCheckerIntegration
local CraftingMechanicusModifyView
local CreditsVendorView
local MainMenuView
local InventoryBackgroundView
local ItemGridViewBase
local ItemGridViewBaseDefinitions
local InventoryWeaponsView
local ViewElementGrid
local WeaponOptionsPanel
local SearchUI
local RuntimeLifecycle
local OptionDependencies
local dmf_mod
local active_grid_view
local active_grid_configuration
local active_highlight_views
local highlight_animation_enabled = false

local function pulsing_highlight_selected()
	return mod:get("highlight_equipped_items") == "pulsing_dashes" or (mod:get("new_item_highlight_mode") or "pulsing_dashes") == "pulsing_dashes"
end
local synchronize_myfavorites_grid = function()
	return 0
end
local CreditsGoodsVendorView = require("scripts/ui/views/credits_goods_vendor_view/credits_goods_vendor_view")
local function optional_require(path)
	local success, module = pcall(require, path)

	return success and module or nil
end
local MarksVendorView = optional_require("scripts/ui/views/marks_vendor_view/marks_vendor_view")
local MarksGoodsVendorView = optional_require("scripts/ui/views/marks_goods_vendor_view/marks_goods_vendor_view")

local function update_search_view(view, time, input_service)
	SearchUI.update_view(mod, Features, view, time, input_service)
end

local function configure_dependencies(dependencies)
	mod = dependencies.mod
	OptionDependencies = dependencies.OptionDependencies
	active_highlight_views = mod._better_inventory_active_highlight_views

	if type(active_highlight_views) ~= "table" then
		active_highlight_views = setmetatable({}, {
			__mode = "k",
		})
		mod._better_inventory_active_highlight_views = active_highlight_views
	end
	Layout = dependencies.Layout
	Features = dependencies.Features
	CurioAcquisition = dependencies.CurioAcquisition
	ItemCustomization = dependencies.ItemCustomization
	EquipmentPersistence = dependencies.EquipmentPersistence
	SettingsRegistry = dependencies.SettingsRegistry
	Diagnostics = dependencies.Diagnostics
	AutoCrafter = dependencies.AutoCrafter
	Capabilities = dependencies.Capabilities
	CharacterOverviewUI = dependencies.CharacterOverviewUI
	FeatureDomains = dependencies.FeatureDomains
	FavoriteIntegration = dependencies.FavoriteIntegration
	GodStatCheckerIntegration = dependencies.GodStatCheckerIntegration
	CraftingMechanicusModifyView = dependencies.CraftingMechanicusModifyView
	CreditsVendorView = dependencies.CreditsVendorView
	MainMenuView = dependencies.MainMenuView
	InventoryBackgroundView = dependencies.InventoryBackgroundView
	ItemGridViewBase = dependencies.ItemGridViewBase
	ItemGridViewBaseDefinitions = dependencies.ItemGridViewBaseDefinitions
	InventoryWeaponsView = dependencies.InventoryWeaponsView
	ViewElementGrid = dependencies.ViewElementGrid
	WeaponOptionsPanel = dependencies.WeaponOptionsPanel
	SearchUI = dependencies.SearchUI
	RuntimeLifecycle = dependencies.RuntimeLifecycle
end

Runtime.configure = configure_dependencies

local function release_transient_item_caches()
	if Layout and type(Layout.clear_runtime_caches) == "function" then
		Layout.clear_runtime_caches()
	end

	if Features and type(Features.clear_runtime_caches) == "function" then
		Features.clear_runtime_caches()
	end
end

local function invalidate_item_customization_tracking()
	if Layout and type(Layout.invalidate_item_customization_tracking) == "function" then
		Layout.invalidate_item_customization_tracking()
	end
end

function Runtime.install()
	if Layout and Layout.ImageLayout and type(Layout.ImageLayout.initialize_settings) == "function" then
		Layout.ImageLayout.initialize_settings(mod)
	end
	if Layout and type(Layout.install_brunt_wkc_listing_hook) == "function" then
		Layout.install_brunt_wkc_listing_hook(mod)
	end

	if FavoriteIntegration and type(FavoriteIntegration.install_manual_purchase_hooks) == "function" then
		FavoriteIntegration.install_manual_purchase_hooks(mod, {
			armoury = CreditsVendorView,
			melk_limited = MarksVendorView,
			melk_mystery = MarksGoodsVendorView,
		})
	end

	local unpack_values = table.unpack or unpack
	local INVENTORY_GRID_CONFIGURATION = {
		blueprint_key = "item",
		image_layout_context = "inventory",
	}
	local HADRON_GRID_CONFIGURATION = {
		blueprint_key = "item",
		image_layout_context = "inventory",
		maximum_columns = 3,
	}
	local ARMOURY_GRID_CONFIGURATION = {
		blueprint_key = "store_item",
		image_layout_context = "armoury",
		maximum_columns = 3,
		store_item = true,
	}
	local GLOBAL_STORE_GRID_CONFIGURATION = {
		blueprint_key = "store_item",
		global_store = true,
		image_layout_context = "global_store",
		maximum_columns = 3,
		store_item = true,
	}
	local GLOBAL_STORE_NATIVE_CONFIGURATION = {
		blueprint_key = "store_item",
		global_store = true,
		image_layout_context = "global_store",
		native_single_column = true,
		store_item = true,
	}

	local pack_values = CharacterOverviewUI.pack_values
	local shallow_copy = CharacterOverviewUI.shallow_copy
	local is_armoury_requisition_view = CharacterOverviewUI.is_armoury_requisition_view
	local is_global_store_view = CharacterOverviewUI.is_global_store_view
	local melk_grid_route = CharacterOverviewUI.melk_grid_route
	local expanded_vendor_view_definitions = CharacterOverviewUI.expanded_vendor_view_definitions
	local melk_grid_configuration = CharacterOverviewUI.melk_grid_configuration
	local update_expanded_vendor_dividers = CharacterOverviewUI.update_expanded_vendor_dividers
	local is_hadron_view = CharacterOverviewUI.is_hadron_view
	local attach_runtime_marker_styles = CharacterOverviewUI.attach_runtime_marker_styles
	local invalidate_myfavorites_grid = CharacterOverviewUI.invalidate_myfavorites_grid

local function is_armoury_sort_view(view)
	return is_armoury_requisition_view(view) or is_global_store_view(view)
end

local grid_scope = FeatureDomains and FeatureDomains.grid_scope
local resolve_grid_scope = grid_scope and grid_scope.resolve or function() end

local function align_quick_level_mastery_buttons(view)
	local alignment = FeatureDomains and FeatureDomains.quick_level_alignment
	local god_stat_checker_active = GodStatCheckerIntegration
		and type(GodStatCheckerIntegration.is_active) == "function"
		and GodStatCheckerIntegration.is_active() == true or false

	if alignment and type(alignment.update) == "function" then
		return alignment.update(view, Diagnostics and Diagnostics.count, god_stat_checker_active)
	end

	return false
end

	local runtime_test = mod and rawget(mod, "_better_inventory_test")

	if type(runtime_test) == "table" then
		runtime_test.align_quick_level_mastery_buttons = align_quick_level_mastery_buttons
	end

local function ensure_class_method(class, method)
	if type(class) ~= "table" then
		return false
	end

	local super = rawget(class, "super") or class.super
	local inherited_method = super and super[method]
	local own_method = rawget(class, method)

	if type(own_method) == "function" and own_method ~= inherited_method then
		return true
	end

	if type(inherited_method) ~= "function" then
		return false
	end

	local owner = class
	local fallback = inherited_method

	rawset(owner, method, function(self, ...)
		local parent = rawget(owner, "super") or owner.super
		local parent_method = parent and parent[method] or fallback

		return parent_method(self, ...)
	end)

	return true
end

local OptionDeps = OptionDependencies.create({
	mod = mod,
	Layout = Layout,
	FavoriteIntegration = FavoriteIntegration,
})
local COLOR_TARGETS = OptionDeps.COLOR_TARGETS
local color_target_by_setting_id = OptionDeps.color_target_by_setting_id
local equipped_highlight_color_target = OptionDeps.equipped_highlight_color_target
local new_item_highlight_color_target = OptionDeps.new_item_highlight_color_target
local apply_color_preset = OptionDeps.apply_color_preset
local refresh_option_dependencies = OptionDeps.refresh_option_dependencies
local bind_option_dependencies = OptionDeps.bind_option_dependencies

if type(CurioAcquisition.set_character_options_refresh_callback) == "function" then CurioAcquisition.set_character_options_refresh_callback(refresh_option_dependencies) end

local function migrate_grid_column_settings()
	if mod:get("_grid_columns_v1_migrated") then
		return
	end

	local legacy_columns = tonumber(mod:get("columns"))
	local dedicated_setting_ids = {
		"melee_columns",
		"ranged_columns",
		"curio_columns",
	}

	if legacy_columns then
		legacy_columns = math.max(2, math.min(5, math.floor(legacy_columns)))
		local has_dedicated_customization = false

		for _, setting_id in ipairs(dedicated_setting_ids) do
			local configured_columns = tonumber(mod:get(setting_id))

			if configured_columns and configured_columns ~= 3 then
				has_dedicated_customization = true

				break
			end
		end

		if not has_dedicated_customization then
			for _, setting_id in ipairs(dedicated_setting_ids) do
				mod:set(setting_id, legacy_columns, false)
			end
		end
	end

	mod:set("_grid_columns_v1_migrated", true, false)
end

function mod.on_enabled()
	ItemCustomization.on_enabled(mod)
	if AutoCrafter and type(AutoCrafter.ensure_configured) == "function" then
		AutoCrafter.ensure_configured()
	end
	if Features and type(Features.set_lantern_integration) == "function" then
		Features.set_lantern_integration(mod, get_mod("Lantern of the Omnissiah"))
	end
	if type(Diagnostics.configure) == "function" then
		Diagnostics.configure(mod)
	end

	local name_it_curio_name_value = mod:get("name_it_force_curio_name_in_detailed_mode")

	if name_it_curio_name_value == nil then
		name_it_curio_name_value = true
	end

	if mod:get("curio_content_name_it_curio_name") ~= name_it_curio_name_value then
		mod:set("curio_content_name_it_curio_name", name_it_curio_name_value, false)
	end

	if not mod:get("_compact_card_defaults_v1_migrated") then
		mod:set("append_mark_to_name", true)
		mod:set("show_pattern_mark", false)
		mod:set("_compact_card_defaults_v1_migrated", true)
	end

	migrate_grid_column_settings()

	if mod:get("_auto_crafter_acquisition_mode_v1_migrated") ~= true then
		local legacy_acquisition = mod:get("auto_crafter_buy_until_target")

		if legacy_acquisition == true then
			mod:set("auto_crafter_buy_until_target", "target_search", false)
		elseif legacy_acquisition == false then
			mod:set("auto_crafter_buy_until_target", "disabled", false)
		end

		mod:set("_auto_crafter_acquisition_mode_v1_migrated", true, false)
	end

	if not mod:get("_character_overview_curio_name_mode_v1_migrated") then
		if mod:get("character_overview_show_curio_names") == true then
			mod:set("character_overview_curio_name_mode", "one_line")
		end

		mod:set("_character_overview_curio_name_mode_v1_migrated", true)
	end

	if not mod:get("_curio_compression_mode_v1_migrated") then
		local previous_compact_setting = mod:get("compact_curio_stat_text")

		if previous_compact_setting == false then
			mod:set("curio_stat_compression", "none")
		elseif previous_compact_setting == true then
			mod:set("curio_stat_compression", "compression")
		end

		mod:set("_curio_compression_mode_v1_migrated", true)
	end

	if not mod:get("_curio_heavy_default_v1_migrated") then
		local compression_mode = mod:get("curio_stat_compression")

		if compression_mode == nil or compression_mode == "compression" then
			mod:set("curio_stat_compression", "heavy")
		end

		mod:set("_curio_heavy_default_v1_migrated", true)
	end

	if not mod:get("_inventory_icon_size_defaults_v2_migrated") then
		local blessing_size = mod:get("blessing_icon_size")
		local perk_rank_size = mod:get("weapon_perk_rank_icon_size")

		if blessing_size == nil or blessing_size == 34 then
			mod:set("blessing_icon_size", 36)
		end

		if perk_rank_size == nil or perk_rank_size == 18 then
			mod:set("weapon_perk_rank_icon_size", 17)
		end

		mod:set("_inventory_icon_size_defaults_v2_migrated", true)
	end

	if not mod:get("_weapon_blessing_display_mode_v1_migrated") then
		local previous_show_blessings = mod:get("show_weapon_blessings")

		if previous_show_blessings ~= nil then
			mod:set("weapon_blessing_display_mode", previous_show_blessings == false and "off" or "icons")
		end

		mod:set("_weapon_blessing_display_mode_v1_migrated", true)
	end

	if not mod:get("_equipped_highlight_mode_v1_migrated") then
		local previous_highlight = mod:get("highlight_equipped_items")

		if previous_highlight == true then
			mod:set("highlight_equipped_items", "animated_dashes")
		elseif previous_highlight == false then
			mod:set("highlight_equipped_items", "off")
		end

		mod:set("_equipped_highlight_mode_v1_migrated", true)
	end

	if SettingsRegistry and type(SettingsRegistry.migrate_curio_palette) == "function" then SettingsRegistry.migrate_curio_palette(mod) end

	for i = 1, #COLOR_TARGETS do
		apply_color_preset(COLOR_TARGETS[i])
	end

	highlight_animation_enabled = pulsing_highlight_selected()

	-- Refresh static operative rows before Mod Options can open.
	if type(CurioAcquisition.refresh_character_options) == "function" then
		CurioAcquisition.refresh_character_options(mod)
	end

	-- Arm discovery independently of GameplayStateRun event ordering.
	if type(CurioAcquisition.request_profile_discovery) == "function" then
		CurioAcquisition.request_profile_discovery(true)
	end

	Features.rebind_sort_options(mod, Layout)
	refresh_option_dependencies()
end

function mod.on_all_mods_loaded()
	if mod:get("custom_item_background_color_keybind") == "group_finder_refresh_groups" then
		mod:set("custom_item_background_color_keybind", "navigate_secondary_left_pressed", true)
	end

	if mod:get("_custom_item_name_keybind_v2_migrated") ~= true then
		if mod:get("custom_item_name_keybind") == "hotkey_menu_special_2" then
			mod:set("custom_item_name_keybind", "lobby_open_inventory", false)
		end

		mod:set("_custom_item_name_keybind_v2_migrated", true, true)
	end

	ItemCustomization.on_all_mods_loaded(mod)
	Features.set_lantern_integration(mod, get_mod("Lantern of the Omnissiah"))
	Features.set_item_sorting_integration(get_mod("ItemSorting"))
end

function mod.on_setting_changed(setting_id)
	local color_change = color_target_by_setting_id[setting_id]
	local automatic_curio_setting = type(setting_id) == "string" and string.sub(setting_id, 1, 16) == "automatic_curio_"

	if Layout and Layout.ImageLayout and type(Layout.ImageLayout.on_setting_changed) == "function" then
		Layout.ImageLayout.on_setting_changed(mod, setting_id)
	end

	if type(Features.invalidate_all_view_composition) == "function" then
		Features.invalidate_all_view_composition()
	end

	if CharacterOverviewUI.is_visual_setting(setting_id) then
		CharacterOverviewUI.bump_visual_settings_generation()
	end

	ItemCustomization.on_setting_changed(mod, setting_id)
	if setting_id == "enable_custom_item_name_and_colors" or setting_id == "custom_item_preserve_card_shading" then
		invalidate_item_customization_tracking()
	end
	if type(Features.search_settings_changed) == "function" then
		Features.search_settings_changed(setting_id)
	end

	if setting_id == "highlight_equipped_items" or setting_id == "new_item_highlight_mode" then
		highlight_animation_enabled = pulsing_highlight_selected()
	end

	if type(setting_id) == "string" and string.sub(setting_id, 1, #"auto_crafter_") == "auto_crafter_" and AutoCrafter and type(AutoCrafter.on_setting_changed) == "function" then
		AutoCrafter.on_setting_changed(setting_id)
	end

	if setting_id == "name_it_force_curio_name_in_detailed_mode" then
		mod:set("curio_content_name_it_curio_name", mod:get(setting_id), false)
	elseif setting_id == "curio_content_name_it_curio_name" then
		mod:set("name_it_force_curio_name_in_detailed_mode", mod:get(setting_id), false)
	end

	if color_change then
		if color_change.is_preset then
			apply_color_preset(color_change.target)
		else
			mod:set(color_change.target.preset_id, "custom", false)
		end
	end

	if setting_id == "highlight_equipped_items" and equipped_highlight_color_target and mod:get(equipped_highlight_color_target.preset_id) == "mode_default" then
		apply_color_preset(equipped_highlight_color_target)
	elseif setting_id == "new_item_highlight_mode" and new_item_highlight_color_target and mod:get(new_item_highlight_color_target.preset_id) == "mode_default" then
		apply_color_preset(new_item_highlight_color_target)
	end

	local should_refresh_dependencies = Capabilities.registry_refresh_required(SettingsRegistry, "should_refresh_dependencies", setting_id)

	if should_refresh_dependencies then
		refresh_option_dependencies()
	end

	if setting_id == "prioritize_equipped_favorites" or setting_id == "prioritize_perfect_roll_weapons" then
		Features.sync_inventory_sort_setting(mod, Layout)
	end
	Features.sync_sort_option_visibility(setting_id)

	if setting_id == "debug_enable_hot_path_diagnostics" and type(Diagnostics.configure) == "function" then
		Diagnostics.configure(mod)
	end

	if type(setting_id) == "string" and string.sub(setting_id, 1, 14) == "quick_discard_" then
		Features.sync_quick_discard_settings(mod, Layout)
	end

	if setting_id == "enable_automatic_curio_acquisition" or automatic_curio_setting then
		CurioAcquisition.on_setting_changed(mod, setting_id)
		Features.sync_curio_acquisition_settings(mod, Layout)
	end
end

function mod.on_settings_reset()
	Features.sync_sort_option_visibility()
	highlight_animation_enabled = pulsing_highlight_selected()
	invalidate_item_customization_tracking()

	for index = 1, #COLOR_TARGETS do
		local target = COLOR_TARGETS[index]
		mod:set(target.preset_id, target.default_preset, false)
		apply_color_preset(target)
	end

	if type(Diagnostics.configure) == "function" then
		Diagnostics.configure(mod)
	end

	refresh_option_dependencies()
	if type(Features.search_settings_changed) == "function" then
		Features.search_settings_changed("inventory_search_remember_query")
		Features.search_settings_changed("inventory_search_non_match_behavior")
	end
end

function mod.on_game_state_changed(status, state_name)
	if state_name ~= "GameplayStateRun" then
		return
	end

	if status == "enter" then
		Features.begin_morningstar_auto_discard(mod)
		CurioAcquisition.begin_morningstar_pass(mod)
	elseif status == "exit" then
		if AutoCrafter and type(AutoCrafter.on_context_exit) == "function" then
			AutoCrafter.on_context_exit("GameplayStateRun_exit")
		end

		Features.cancel_morningstar_auto_discard()
		if type(CurioAcquisition.leave_morningstar) == "function" then
			CurioAcquisition.leave_morningstar()
		else
			CurioAcquisition.cancel()
		end
	end
end

-- Operative Selection lifecycle stays separate from gameplay scheduling.
mod:hook_safe(MainMenuView, "on_enter", function()
	if AutoCrafter and type(AutoCrafter.on_context_exit) == "function" then
		AutoCrafter.on_context_exit("operative_selection_entered")
	end

	if type(CurioAcquisition.enter_operative_selection) == "function" then
		CurioAcquisition.enter_operative_selection(mod)
	end
end)

mod:hook_safe(MainMenuView, "on_exit", function()
	if AutoCrafter and type(AutoCrafter.on_context_exit) == "function" then
		AutoCrafter.on_context_exit("operative_selection_exited")
	end

	if type(CurioAcquisition.leave_operative_selection) == "function" then
		CurioAcquisition.leave_operative_selection()
	end
end)

function mod.update(dt)
	local overview_highlights_active = type(CharacterOverviewUI.needs_update) == "function" and CharacterOverviewUI.needs_update()

	if highlight_animation_enabled and (next(active_highlight_views) ~= nil or overview_highlights_active) and Layout and type(Layout.update_highlight_animation) == "function" then
		Layout.update_highlight_animation(mod)
	end

	local auto_crafter_needs_update = AutoCrafter and type(AutoCrafter.update) == "function" and (type(AutoCrafter.needs_update) ~= "function" or AutoCrafter.needs_update())

	if auto_crafter_needs_update then
		AutoCrafter.update(dt)
	end
	local auto_crafter_busy = auto_crafter_needs_update and type(AutoCrafter.is_busy) == "function" and AutoCrafter.is_busy() or false

	if type(CharacterOverviewUI.update_registered_views) == "function" and (type(CharacterOverviewUI.needs_update) ~= "function" or overview_highlights_active) then
		CharacterOverviewUI.update_registered_views(dt)
	end
	if FeatureDomains and FeatureDomains.markers and type(FeatureDomains.markers.update) == "function" and (type(FeatureDomains.markers.needs_update) ~= "function" or FeatureDomains.markers.needs_update()) then
		FeatureDomains.markers.update(dt, synchronize_myfavorites_grid)
	end
	if type(ItemCustomization.needs_update) ~= "function" or ItemCustomization.needs_update() then
		ItemCustomization.update_runtime(mod, dt)
	end
	if type(EquipmentPersistence.has_pending) ~= "function" or EquipmentPersistence.has_pending() then
		EquipmentPersistence.update(mod, dt)
	end
	if Features.discard_owner() then
		Features.reconcile_discard_transaction()
	end
	if Features.morningstar_auto_discard_needs_update(mod) then
		Features.update_morningstar_auto_discard(mod, dt, auto_crafter_busy)
	end
	if CurioAcquisition.needs_update(mod) then
		CurioAcquisition.update(mod, dt, Features.morningstar_auto_discard_is_busy(mod) or auto_crafter_busy)
	end
	if type(Diagnostics.update) == "function" and type(Diagnostics.enabled) == "function" and Diagnostics.enabled() then
		Diagnostics.update(mod, dt, CurioAcquisition, Features)
	end
end

local function shutdown(unloading)
	local reason = unloading and "mod_reload" or "mod_disable"
	local function cleanup(label, callback, ...)
		local ok, err = pcall(callback, ...)
		if not ok and type(mod.error) == "function" then
			pcall(mod.error, mod, "%s", "Cleanup " .. label .. " failed: " .. tostring(err))
		end
	end

	if AutoCrafter and type(AutoCrafter.shutdown) == "function" then
		cleanup("auto crafter", AutoCrafter.shutdown)
	end
	if Features and type(Features.shutdown_lantern_integration) == "function" then
		cleanup("Lantern", Features.shutdown_lantern_integration)
	end

	if unloading and type(ItemCustomization.on_unload) == "function" then
		cleanup("customization", ItemCustomization.on_unload, mod)
	else
		cleanup("customization", ItemCustomization.on_disabled, mod)
	end
	if EquipmentPersistence and type(EquipmentPersistence.reset) == "function" then
		cleanup("equipment", EquipmentPersistence.reset)
	end
	cleanup("automatic discard", Features.cancel_morningstar_auto_discard)
	cleanup("manual discard", Features.cancel_manual_discard)
	cleanup("curio buyer", CurioAcquisition.cancel, unloading)
	if RuntimeLifecycle and type(RuntimeLifecycle.release_all) == "function" then
		cleanup("view lifecycle", RuntimeLifecycle.release_all, reason)
	end
	cleanup("inventory views", Features.disable_inventory_views)
	cleanup("view sessions", Features.close_all_view_sessions, reason)
	if type(Features.search_shutdown) == "function" then
		cleanup("search", Features.search_shutdown, true)
	end
	if CharacterOverviewUI and type(CharacterOverviewUI.release_all_views) == "function" then
		cleanup("overview", CharacterOverviewUI.release_all_views)
	end
	if FeatureDomains and FeatureDomains.markers and type(FeatureDomains.markers.release_all) == "function" then
		cleanup("markers", FeatureDomains.markers.release_all)
	end
	if type(Diagnostics.reset) == "function" then
		cleanup("diagnostics", Diagnostics.reset)
	end
	cleanup("transient caches", release_transient_item_caches)
end

function mod.on_disabled(_initial_call)
	shutdown(false)
end

function mod.on_unload(_exit_game)
	shutdown(true)
end

dmf_mod = get_mod("DMF")

if dmf_mod and type(dmf_mod.create_mod_options_settings) == "function" then
	mod:hook_safe(dmf_mod, "create_mod_options_settings", function(_, options_templates)
		if Layout and Layout.ImageLayout and type(Layout.ImageLayout.sync_editors) == "function" then
			Layout.ImageLayout.sync_editors(mod)
		end

		if type(CurioAcquisition.inject_character_options) == "function" then
			CurioAcquisition.inject_character_options(mod, options_templates)
		end

		bind_option_dependencies(options_templates)
	end)
end

local function arm_equipped_compound_shield_guard(view, context)
	if not Layout.equipped_compound_shield_requires_cap(mod, view, context) then
		return false
	end

	view._better_inventory_compound_shield_column_cap = true

	if type(mod.info) == "function" then
		mod:info("Compound shield detected before inventory initialization; using the safe three-column view.")
	end

	return true
end

mod:hook(ItemGridViewBase, "init", function(func, view, definitions, settings, context)
	active_highlight_views[view] = true
	local function initialize(adjusted_definitions)
		if mod:get("enable_inventory_search") ~= false and SearchUI and type(SearchUI.decorate_definitions) == "function" then
			adjusted_definitions = SearchUI.decorate_definitions(adjusted_definitions, view, mod, context, ItemGridViewBaseDefinitions)
		end

		return func(view, adjusted_definitions, settings, context)
	end

	if view.__class_name == "InventoryWeaponsView" then
		-- Guard the assigned slot/loadout before expanding inventory geometry.
		arm_equipped_compound_shield_guard(view, context)

		local adjusted_definitions = Features.add_inventory_sort_toggle_definition(mod, Layout, definitions, view)
		local expansion = 0

		if Layout.is_enabled_for_view(mod, view) then
			adjusted_definitions, expansion = Layout.expanded_view_definitions(mod, adjusted_definitions, view)
		end

		view._better_inventory_grid_expansion = expansion

		return initialize(adjusted_definitions)
	end

	local adjusted_vendor_definitions, vendor_expansion = expanded_vendor_view_definitions(mod, view, context, definitions, ItemGridViewBaseDefinitions, Layout)

	if adjusted_vendor_definitions then
		view._better_inventory_armoury_grid_expansion = vendor_expansion

		return initialize(adjusted_vendor_definitions)
	end

	return initialize(definitions)
end)

Features.install_sort_option_visibility(mod, ViewElementGrid, resolve_grid_scope)

if ensure_class_method(InventoryWeaponsView, "_setup_sort_options") then
	mod:hook(InventoryWeaponsView, "_setup_sort_options", function(func, view, ...)
		local selected_option = view._selected_sort_option or view._sort_options and view._sort_options[view._selected_sort_option_index or 1]
		local selected_display_name = selected_option and selected_option.display_name
		local result = func(view, ...)

		Features.preserve_item_sorting_native_options(view, selected_display_name)
		RuntimeLifecycle.adopt_inventory(view, true)

		return result
	end)
end

if ensure_class_method(CreditsVendorView, "_setup_sort_options") then
	mod:hook(CreditsVendorView, "_setup_sort_options", function(func, view, ...)
		local selected_option = view._selected_sort_option or view._sort_options and view._sort_options[view._selected_sort_option_index or 1]
		local selected_display_name = selected_option and selected_option.display_name
		local result = func(view, ...)

		Features.preserve_item_sorting_native_options(view, selected_display_name)
		local family = is_armoury_requisition_view(view) and "armoury" or is_global_store_view(view) and "global_store"
		RuntimeLifecycle.adopt_armoury(view, family, true)

		return result
	end)
end

if ensure_class_method(InventoryWeaponsView, "update") then
	mod:hook_safe(InventoryWeaponsView, "update", function(view, dt, t, input_service)
		RuntimeLifecycle.adopt_inventory(view)
		Features.update_inventory_sort_toggle(mod, Layout, view)
		Features.update_inventory_options_panel_controller_selection(view, input_service)
		Features.flush_inventory_resort(mod, Layout, view)
		update_search_view(view, t, input_service)
	end)
end

if ensure_class_method(InventoryWeaponsView, "_handle_input") then
	mod:hook(InventoryWeaponsView, "_handle_input", function(func, view, input_service, ...)
		if SearchUI and type(SearchUI.handle_view_input) == "function" and SearchUI.handle_view_input(mod, view, input_service) then
			return
		end

		-- Capture before native input to preserve same-frame controller behavior.
		Features.capture_inventory_options_panel_controller_focus(mod, Layout, view, input_service)
		Features.capture_inventory_controller_navigation(view, input_service)

		if Features.inventory_options_panel_controller_focused(view) or Features.consume_inventory_controller_grid_navigation(view) then
			-- Bypass only the obsolete single-column focus transfer.
			return ItemGridViewBase._handle_input(view, input_service, ...)
		end

		return func(view, input_service, ...)
	end)
end

if ensure_class_method(InventoryWeaponsView, "cb_on_favorite_pressed") then
	mod:hook_safe(InventoryWeaponsView, "cb_on_favorite_pressed", function(view)
		local item_grid = view and view._item_grid

		invalidate_myfavorites_grid(item_grid)
		if type(Features.search_invalidate_all) == "function" then
			Features.search_invalidate_all(view)
		end

		if mod:get("prioritize_equipped_favorites") ~= false then
			Features.request_inventory_resort(view)
		end
	end)
end

if ensure_class_method(InventoryBackgroundView, "_equip_local_changes") then
	mod:hook(InventoryBackgroundView, "_equip_local_changes", function(func, view, ...)
		return EquipmentPersistence.persist_local_changes(mod, func, view, ...)
	end)
end

if ensure_class_method(InventoryBackgroundView, "event_player_profile_updated") then
	mod:hook_safe(InventoryBackgroundView, "event_player_profile_updated", function(view, peer_id, local_player_id, event_profile)
		EquipmentPersistence.refresh_from_authoritative_profile(view, peer_id, local_player_id, event_profile)
		invalidate_myfavorites_grid(view and view._item_grid)
	end)
end


if ensure_class_method(InventoryBackgroundView, "on_exit") then
	mod:hook_safe(InventoryBackgroundView, "on_exit", function(view)
		if EquipmentPersistence and type(EquipmentPersistence.on_view_closed) == "function" then
			EquipmentPersistence.on_view_closed(view)
		end
	end)
end

if ensure_class_method(InventoryBackgroundView, "destroy") then
	mod:hook_safe(InventoryBackgroundView, "destroy", function(view)
		if EquipmentPersistence and type(EquipmentPersistence.on_view_closed) == "function" then
			EquipmentPersistence.on_view_closed(view)
		end
	end)
end

-- Hold manual discard ownership until the native deletion promise settles.
mod:hook("GearService", "delete_gear_batch", function(func, gear_service, gear_ids, ...)
		local result = func(gear_service, gear_ids, ...)
		Features.observe_manual_discard_settlement(result)

		return result
	end)

if ensure_class_method(InventoryWeaponsView, "_equip_item") then
	mod:hook_safe(InventoryWeaponsView, "_equip_item", function(view)
		if type(Features.invalidate_view_composition) == "function" then
			Features.invalidate_view_composition(view)
		end

		local item_grid = view and view._item_grid

		invalidate_myfavorites_grid(item_grid)
		if type(Features.search_invalidate_all) == "function" then
			Features.search_invalidate_all(view)
		end

		if mod:get("prioritize_equipped_favorites") ~= false then
			Features.request_inventory_resort(view)
		end
	end)
end

if ensure_class_method(InventoryWeaponsView, "on_exit") then
	mod:hook_safe(InventoryWeaponsView, "on_exit", function(view)
		Features.release_lantern_inventory_section(view)
		Features.unregister_inventory_view(view)
		if ItemCustomization and type(ItemCustomization.on_view_closed) == "function" then
			ItemCustomization.on_view_closed(mod)
		end
	end)
end

if ensure_class_method(InventoryWeaponsView, "destroy") then
	mod:hook_safe(InventoryWeaponsView, "destroy", function(view)
		Features.release_lantern_inventory_section(view)
		Features.unregister_inventory_view(view)
	end)
end

local function release_item_grid_view_runtime(view)
	if not view or view._better_inventory_item_grid_runtime_released == true then
		return false
	end

	view._better_inventory_item_grid_runtime_released = true
	local item_grid = view and view._item_grid

	active_highlight_views[view] = nil

	if FeatureDomains and FeatureDomains.markers and type(FeatureDomains.markers.release_grid) == "function" then
		FeatureDomains.markers.release_grid(item_grid)
	end

	view._auto_crafter_status_overlay = nil
	if SearchUI and type(SearchUI.release) == "function" then
		SearchUI.release(view)
	end
	RuntimeLifecycle.release_compact_curio_stats_blueprints(view)
	local session_closed = Features.end_view_session(view, "item_grid_exit")

	-- A live view session owns search release; otherwise use the direct fallback.
	if not session_closed and type(Features.search_release) == "function" then
		Features.search_release(view)
	end

	release_transient_item_caches()

	return true
end

Runtime.release_item_grid_view_runtime = release_item_grid_view_runtime

if ensure_class_method(ItemGridViewBase, "on_exit") then
	mod:hook_safe(ItemGridViewBase, "on_exit", release_item_grid_view_runtime)
end

if ensure_class_method(ItemGridViewBase, "destroy") then
	mod:hook_safe(ItemGridViewBase, "destroy", release_item_grid_view_runtime)
end

if ensure_class_method(CreditsVendorView, "update") then
	mod:hook_safe(CreditsVendorView, "update", function(view, dt, t, input_service)
		if is_armoury_sort_view(view) then
			RuntimeLifecycle.adopt_armoury(view, is_armoury_requisition_view(view) and "armoury" or "global_store")
			Features.update_armoury_native_sort_panel(view)
			align_quick_level_mastery_buttons(view)
			Features.flush_inventory_resort(mod, Layout, view)
		end
		update_search_view(view, t, input_service)
	end)
end

if ensure_class_method(CreditsVendorView, "_handle_input") then
	mod:hook(CreditsVendorView, "_handle_input", function(func, view, input_service, ...)
		if is_armoury_sort_view(view) then
			Features.capture_armoury_sort_panel_controller_focus(mod, view, input_service)
		end

		if Features.armoury_sort_panel_controller_focused(view) then
			-- The panel's ViewElementGrid already processed navigation this frame.
			-- Skip VendorViewBase's A-to-purchase path while widget focus is active.
			return ItemGridViewBase._handle_input(view, input_service, ...)
		end

		return func(view, input_service, ...)
	end)
end

if ensure_class_method(CreditsVendorView, "on_exit") then
	mod:hook_safe(CreditsVendorView, "on_exit", function(view)
		Features.unregister_armoury_view(view)
	end)
end

if ensure_class_method(CreditsVendorView, "destroy") then
	mod:hook_safe(CreditsVendorView, "destroy", function(view)
		Features.unregister_armoury_view(view)
	end)
end

-- Brunt's Armoury uses CreditsGoodsVendorView; other vendors use another route.
if ensure_class_method(CreditsGoodsVendorView, "on_enter") then
	mod:hook_safe(CreditsGoodsVendorView, "on_enter", function(view)
		if AutoCrafter and type(AutoCrafter.on_brunt_view_ready) == "function" then
			AutoCrafter.on_brunt_view_ready(view)
		end
	end)
end

if ensure_class_method(CreditsGoodsVendorView, "on_exit") then
	mod:hook_safe(CreditsGoodsVendorView, "on_exit", function(view)
		if AutoCrafter and type(AutoCrafter.on_view_closed) == "function" then
			AutoCrafter.on_view_closed(view)
		end
	end)
end

if ensure_class_method(CreditsGoodsVendorView, "destroy") then
	mod:hook_safe(CreditsGoodsVendorView, "destroy", function(view)
		if AutoCrafter and type(AutoCrafter.on_view_closed) == "function" then
			AutoCrafter.on_view_closed(view)
		end
	end)
end

if ensure_class_method(InventoryWeaponsView, "_setup_item_grid_materials") then
	mod:hook(InventoryWeaponsView, "_setup_item_grid_materials", function(func, view, ...)
		func(view, ...)

		local expansion = view._better_inventory_grid_expansion or 0

		if expansion <= 0 then
			return
		end

		for _, widget_name in ipairs({
			"grid_divider_top",
			"grid_divider_bottom",
		}) do
			local widget = view:_grid_widget_by_name(widget_name)
			local texture_style = widget and widget.style and widget.style.texture
			local texture_size = texture_style and texture_style.size

			if texture_size and texture_size[1] then
				texture_size[1] = texture_size[1] + expansion
			end
		end
	end)
end

local function present_grid_with_configuration(func, view, layout, on_present_callback, configuration)
	local previous_active_view = active_grid_view
	local previous_configuration = active_grid_configuration

	active_grid_view = view
	active_grid_configuration = configuration

	local results = pack_values(pcall(func, view, layout, on_present_callback))
	local success = results[1]
	local result_count = results.n

	if type(Features.invalidate_view_composition) == "function" then
		Features.invalidate_view_composition(view)
	end

	active_grid_view = previous_active_view
	active_grid_configuration = previous_configuration

	if not success then
		error(results[2], 0)
	end

	return unpack_values(results, 2, result_count)
end

if ensure_class_method(InventoryWeaponsView, "present_grid_layout") then
	mod:hook(InventoryWeaponsView, "present_grid_layout", function(func, view, layout, on_present_callback)
		if not Layout.is_enabled_for_view(mod, view) then
			return func(view, layout, on_present_callback)
		end

		-- Mark only this call, then continue through the complete DMF hook chain.
		-- The grid hook below transforms whichever blueprints reach the base view,
		-- including changes made by compatible sorting or information mods.
		local configuration = table.clone(INVENTORY_GRID_CONFIGURATION)
		configuration.slot_kind = Layout.slot_kind(view)
		local safe_maximum_columns, compound_shield_cap = Layout.safe_inventory_maximum_columns(mod, configuration.maximum_columns, configuration.slot_kind, layout, view._better_inventory_compound_shield_column_cap)

		configuration.maximum_columns = safe_maximum_columns
		view._better_inventory_compound_shield_column_cap = compound_shield_cap or nil

		return present_grid_with_configuration(func, view, layout, on_present_callback, configuration)
	end)
end

CharacterOverviewUI.install_hooks(ensure_class_method)

local function present_additional_grid(func, view, layout, on_present_callback, setting_id, configuration)
	if mod:get("enable_grid_layout") == false or mod:get(setting_id) == false then
		return func(view, layout, on_present_callback)
	end

	local active_configuration = table.clone(configuration)
	if setting_id == "enable_melk_limited_grid" then
		active_configuration.melk_limited = true
	end

	if Layout.store_slot_kind then
		-- Vendor cards honor category widths and their column cap.
		active_configuration.slot_kind = Layout.store_slot_kind(view, layout)
	end

	return present_grid_with_configuration(func, view, layout, on_present_callback, active_configuration)
end

-- Entreat Hadron uses this view; sacrifice remains outside the hook.
if ensure_class_method(CraftingMechanicusModifyView, "present_grid_layout") then
	mod:hook(CraftingMechanicusModifyView, "present_grid_layout", function(func, view, layout, on_present_callback)
		return present_additional_grid(func, view, layout, on_present_callback, "enable_hadron_entreat_grid", HADRON_GRID_CONFIGURATION)
	end)
end

-- Native Requisition and GlobalStore share this view.
if ensure_class_method(CreditsVendorView, "present_grid_layout") then
	mod:hook(CreditsVendorView, "present_grid_layout", function(func, view, layout, on_present_callback)
		if is_global_store_view(view) and mod:get("enable_global_store_integration") ~= false then
			return present_additional_grid(func, view, layout, on_present_callback, "enable_global_store_grid", GLOBAL_STORE_GRID_CONFIGURATION)
		end

		if not is_armoury_requisition_view(view) then
			return func(view, layout, on_present_callback)
		end

		return present_additional_grid(func, view, layout, on_present_callback, "enable_armoury_requisition_grid", ARMOURY_GRID_CONFIGURATION)
	end)
end

if ensure_class_method(MarksVendorView, "present_grid_layout") then
	mod:hook(MarksVendorView, "present_grid_layout", function(func, view, layout, on_present_callback)
		local setting_id, global_store = melk_grid_route(view)

		if not setting_id or global_store and mod:get("enable_global_store_integration") == false then
			return func(view, layout, on_present_callback)
		end

		return present_additional_grid(func, view, layout, on_present_callback, setting_id, global_store and GLOBAL_STORE_GRID_CONFIGURATION or ARMOURY_GRID_CONFIGURATION)
	end)
end

mod:hook(CreditsVendorView, "on_enter", function(func, view, ...)
	local result = func(view, ...)

	if not is_armoury_sort_view(view) then
		return result
	end

	update_expanded_vendor_dividers(view)

	align_quick_level_mastery_buttons(view)

	return result
end)

if ensure_class_method(MarksVendorView, "on_enter") then
	mod:hook(MarksVendorView, "on_enter", function(func, view, ...)
		local result = func(view, ...)

		if melk_grid_route(view) then
			update_expanded_vendor_dividers(view)
		end

		return result
	end)
end

local function normalize_global_store_widgets(item_grid)
	local portrait_size = 34

	if Layout.global_store_character_photo_size then
		portrait_size = Layout.global_store_character_photo_size(mod)
	end

	return FeatureDomains.global_store.normalize_widgets(item_grid, portrait_size)
end

if ensure_class_method(ViewElementGrid, "_create_entry_widget_from_config") then
	mod:hook(ViewElementGrid, "_create_entry_widget_from_config", function(func, item_grid, config, suffix, callback_name, secondary_callback_name, double_click_callback_name)
		local widget, alignment_widget = func(item_grid, config, suffix, callback_name, secondary_callback_name, double_click_callback_name)
		local view = resolve_grid_scope(item_grid, active_grid_view, active_grid_configuration)

		if view then
			attach_runtime_marker_styles(widget, item_grid)
			if Layout.MaterialSafety then
				Layout.MaterialSafety.guard_inventory_widget(mod, item_grid, widget)
			end
		end

		return widget, alignment_widget
	end)
end

local function synchronize_myfavorites_marker(widget)
	if type(Diagnostics.count) == "function" then
		Diagnostics.count("marked_grid_scans")
	end
	local content = widget and widget.content
	local styles = widget and widget.style
	local hotspot_style = content and content.better_inventory_myfavorites_hotspot_style
	local favorite_style = styles and styles.favorite_icon

	if not hotspot_style or not hotspot_style.offset or hotspot_style.horizontal_alignment ~= "right" or hotspot_style.vertical_alignment ~= "top" then
		return
	end

	local equipped_visible = content.equipped == true
	local visibility_function = content.better_inventory_equipped_icon_visibility_function

	if not equipped_visible and type(visibility_function) == "function" then
		local ok, visible = pcall(visibility_function, content, styles and styles.equipped_icon)

		equipped_visible = ok and visible == true
	end

	content.better_inventory_equipped_icon_visible = equipped_visible

	local offset_y = equipped_visible and 33 or 7
	local favorite_shift_y = favorite_style and favorite_style.better_inventory_native_curio_favorite_shift_y or 0
	offset_y = offset_y + favorite_shift_y
	local favorite_marker_min_y = favorite_style and favorite_style.better_inventory_native_curio_favorite_min_y

	if favorite_marker_min_y then
		offset_y = math.max(offset_y, favorite_marker_min_y)
	end

	-- Equipped/favorite state can be revisited every frame by the native grid,
	-- but the marker position usually remains unchanged for many frames. Avoid
	-- rewriting shared style tables unless an external update actually moved it.
	local favorite_offset = favorite_style and favorite_style.offset
	if hotspot_style.offset[2] == offset_y and (not favorite_offset or favorite_offset[2] == offset_y) then
		return
	end

	if type(Diagnostics.count) == "function" then
		Diagnostics.count("alignment_writes")
	end
	hotspot_style.offset[2] = offset_y

	if favorite_offset then
		favorite_offset[2] = offset_y
	end
end

local function synchronize_myfavorites_widgets(tracked_widgets)
	for widget in pairs(tracked_widgets or {}) do
		synchronize_myfavorites_marker(widget)
	end
end

synchronize_myfavorites_grid = function(_, tracked_widgets)
	local sync_ok, sync_error = pcall(synchronize_myfavorites_widgets, tracked_widgets)

	if not sync_ok and mod and type(mod.warning) == "function" then
		mod:warning("MyFavorites marker reconciliation skipped after a compatibility error: %s", tostring(sync_error))
	end
end

mod:hook(ViewElementGrid, "present_grid_layout", function(func, item_grid, layout, content_blueprints, ...)
	local view, scoped_configuration = resolve_grid_scope(item_grid, active_grid_view, active_grid_configuration)

	if not view then
		return func(item_grid, layout, content_blueprints, ...)
	end

	invalidate_myfavorites_grid(item_grid)
	content_blueprints = RuntimeLifecycle.compact_curio_stats_blueprints(mod, Features, item_grid, content_blueprints)

	local callback_arguments = pack_values(...)
	local on_present_callback = callback_arguments[5]

	callback_arguments[5] = function(...)
		local callback_results

		if type(on_present_callback) == "function" then
			callback_results = pack_values(on_present_callback(...))
		end

		if type(Features.search_apply_widget_alpha) == "function" then
			Features.search_apply_widget_alpha(view)
		end

		if callback_results then
			return unpack_values(callback_results, 1, callback_results.n)
		end
	end

	if WeaponOptionsPanel and type(WeaponOptionsPanel.prepare_layout) == "function" then
		layout = WeaponOptionsPanel.prepare_layout(mod, item_grid, layout, content_blueprints, view)
	end

	local configuration = scoped_configuration

	if not configuration and is_global_store_view(view) and mod:get("enable_global_store_integration") ~= false then
		configuration = mod:get("enable_grid_layout") ~= false and mod:get("enable_global_store_grid") ~= false and table.clone(GLOBAL_STORE_GRID_CONFIGURATION) or table.clone(GLOBAL_STORE_NATIVE_CONFIGURATION)

		if configuration.store_item and Layout.store_slot_kind then
			configuration.slot_kind = Layout.store_slot_kind(view, layout)
		end
	end

	if not configuration then
		configuration = melk_grid_configuration(mod, view, layout, Layout, ARMOURY_GRID_CONFIGURATION, GLOBAL_STORE_GRID_CONFIGURATION)
	end

	-- Preserve the opt-in detailed single-column Hadron/Requisition mirrors.
	if not configuration and mod:get("enable_grid_layout") == false then
		if is_hadron_view(view) and mod:get("enable_hadron_single_column_mirror") ~= false then
			configuration = {
				blueprint_key = "item",
				image_layout_context = "inventory",
				native_single_column = true,
			}
		elseif is_armoury_requisition_view(view) and mod:get("enable_armoury_single_column_mirror") ~= false then
			configuration = {
				blueprint_key = "store_item",
				image_layout_context = "armoury",
				native_single_column = true,
				store_item = true,
			}
		end
	end

	local definitions = view and view._definitions
	local grid_settings = definitions and definitions.grid_settings
	local grid_size = grid_settings and grid_settings.grid_size
	local blueprint_key = configuration and configuration.blueprint_key
	local item_blueprint = blueprint_key and content_blueprints and content_blueprints[blueprint_key]

	if not view or item_grid ~= view._item_grid or not grid_size or not grid_size[1] or not item_blueprint or not item_blueprint.pass_template then
		return func(item_grid, layout, content_blueprints, unpack_values(callback_arguments, 1, callback_arguments.n))
	end

	local rebuild_cards = RuntimeLifecycle.prepare_grid_generation(item_grid, layout)

	if configuration.global_store then
		FeatureDomains.global_store.retire_grid_generation(item_grid, layout, Managers.ui)
	end

	Layout.configure_grid(mod, item_grid)

	if not rebuild_cards then
		local after_present = configuration.global_store and normalize_global_store_widgets
		local results = RuntimeLifecycle.present_reused_grid(func, item_grid, layout, content_blueprints, callback_arguments, after_present)
		return unpack_values(results, 1, results.n)
	end

	local local_blueprints = shallow_copy(content_blueprints)
	local local_item_blueprint = table.clone(item_blueprint)

	local_blueprints[blueprint_key] = local_item_blueprint

	Layout.configure_item_blueprint(mod, local_item_blueprint, grid_size[1], configuration)
	RuntimeLifecycle.mark_managed_grid(item_grid)

	if configuration.global_store and type(callback_arguments[5]) == "function" then
		local on_present_callback = callback_arguments[5]

		callback_arguments[5] = function(...)
			local callback_results = pack_values(on_present_callback(...))

			normalize_global_store_widgets(item_grid)

			return unpack_values(callback_results, 1, callback_results.n)
		end
	end

	local results = pack_values(func(item_grid, layout, local_blueprints, unpack_values(callback_arguments, 1, callback_arguments.n)))

	if configuration.global_store then
		normalize_global_store_widgets(item_grid)
	end

	return unpack_values(results, 1, results.n)
end)

mod:hook(ViewElementGrid, "_update_window_size", function(func, item_grid, ...)
	local results = pack_values(func(item_grid, ...))
	local view = resolve_grid_scope(item_grid, active_grid_view, active_grid_configuration)

	if view and WeaponOptionsPanel and type(WeaponOptionsPanel.finalize_layout) == "function" then
		WeaponOptionsPanel.finalize_layout(item_grid)
	end
	if view and SearchUI and type(SearchUI.finalize_grid_clip) == "function" then
		SearchUI.finalize_grid_clip(item_grid)
	end

	return unpack_values(results, 1, results.n)
end)
end

return Runtime
