local mod = get_mod("BetterInventory")

local function no_op_module(module, module_name, defaults)
	if type(module) == "table" then
		return module
	end

	mod:error("Failed to load %s; its features are disabled until the next successful reload.", module_name)

	return setmetatable({}, {
		__index = function(fallback, key)
			local default_value = defaults and defaults[key]
			local default_function

			if type(default_value) == "function" then
				default_function = default_value
			else
				default_function = function()
					return default_value
				end
			end

			rawset(fallback, key, default_function)

			return default_function
		end,
	})
end

local CraftingMechanicusModifyView = require("scripts/ui/views/crafting_mechanicus_modify_view/crafting_mechanicus_modify_view")
local CreditsVendorView = require("scripts/ui/views/credits_vendor_view/credits_vendor_view")
local MainMenuView = require("scripts/ui/views/main_menu_view/main_menu_view")
local InventoryView = require("scripts/ui/views/inventory_view/inventory_view")
local InventoryViewContentBlueprints = require("scripts/ui/views/inventory_view/inventory_view_content_blueprints")
local InventoryBackgroundView = require("scripts/ui/views/inventory_background_view/inventory_background_view")
local ItemGridViewBase = require("scripts/ui/views/item_grid_view_base/item_grid_view_base")
local ItemGridViewBaseDefinitions = require("scripts/ui/views/item_grid_view_base/item_grid_view_base_definitions")
local InventoryWeaponsView = require("scripts/ui/views/inventory_weapons_view/inventory_weapons_view")
local ViewElementGrid = require("scripts/ui/view_elements/view_element_grid/view_element_grid")
local ItemBlueprintGenerator = require("scripts/ui/view_content_blueprints/item_blueprints")
local Text = require("scripts/utilities/ui/text")
local BaseView = require("scripts/ui/views/base_view")
local VendorInteractionViewBase = require("scripts/ui/views/vendor_interaction_view_base/vendor_interaction_view_base")
local Layout = mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout")

if type(Layout) ~= "table" then
	mod:error("Failed to load BetterInventory_layout.lua; BetterInventory hooks are disabled until the next successful reload.")

	return
end

local CharacterOverview = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_character_overview"), "BetterInventory_character_overview.lua", {
	content_revision = function()
		return nil, nil, nil, nil, nil, -1, -1, -1, -1
	end,
	identity = function()
		return
	end,
	changed = function(previous_item, current_item)
		return previous_item ~= current_item
	end,
	build_model = function(item, category, options)
		return {
			category = category,
			empty = item == nil,
			selected = options and options.selected == true or false,
			widget_type = options and options.widget_type,
		}
	end,
	clear_derived_content = function()
		return false
	end,
})
local FeatureDomains = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_feature_domains"), "BetterInventory_feature_domains.lua", {
	markers = {
		invalidate_grid = function()
			return false
		end,
		track_grid = function()
			return false
		end,
		update = function()
			return 0
		end,
	},
})

local Capabilities = mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_contracts")

if type(Capabilities) ~= "table" or type(Capabilities.registry_refresh_required) ~= "function" then
	Capabilities = {
		mutation = function()
			return "unavailable", "method unavailable"
		end,
		registry_refresh_required = function()
			return true, "unavailable", "method unavailable"
		end,
	}
end

local Features = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_features"), "BetterInventory_features.lua", {
	quick_discard_candidates = function() return {} end,
	quick_discard_candidates_from_items = function() return {} end,
})
local CurioAcquisition = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_curio_acquisition"), "BetterInventory_curio_acquisition.lua", {
	character_slots = function() return {} end,
	known_profiles = function() return {} end,
})
local FavoriteIntegration = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_favorite_integration"), "BetterInventory_favorite_integration.lua", {
	apply_auto_crafter_color = function() return false end,
	favorite_purchase_items = function() return 0 end,
})
local ItemCustomization = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_item_customization"), "BetterInventory_item_customization.lua")
local EquipmentPersistence = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_equipment_persistence"), "BetterInventory_equipment_persistence.lua")
local SettingsRegistry = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_settings"), "BetterInventory_settings.lua", {
	should_refresh_dependencies = function() return true end,
})
local Diagnostics = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_diagnostics"), "BetterInventory_diagnostics.lua")
local WeaponOptionsPanel = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_weapon_options_panel"), "BetterInventory_weapon_options_panel.lua", {
	prepare_layout = function(_, _, layout)
		return layout, false
	end,
})
local AutoCrafter = mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_auto_crafter")

if type(AutoCrafter) ~= "table" then
	AutoCrafter = {}
end

local AccountMutationGuard = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_account_mutation_guard"), "BetterInventory_account_mutation_guard.lua", {
	configure = function() end,
	install_hooks = function() return false end,
	with_owned_call = function(callback) return callback() end,
})
AccountMutationGuard.configure = type(AccountMutationGuard.configure) == "function" and AccountMutationGuard.configure or function() end
AccountMutationGuard.install_hooks = type(AccountMutationGuard.install_hooks) == "function" and AccountMutationGuard.install_hooks or function() return false end
AccountMutationGuard.with_owned_call = type(AccountMutationGuard.with_owned_call) == "function" and AccountMutationGuard.with_owned_call or function(callback) return callback() end

mod.auto_crafter_hud_lines = function()
	return type(AutoCrafter.hud_lines) == "function" and AutoCrafter.hud_lines() or {}
end

mod.auto_crafter_hud_presentation = function()
	if type(AutoCrafter.hud_presentation) == "function" then
		return AutoCrafter.hud_presentation()
	end

	local lines = mod:auto_crafter_hud_lines()

	return #lines > 0 and table.concat(lines, "\n") or "", #lines, lines
end

local function hud_read_member(object, key)
	return object[key]
end

rawset(_G, "AutoCrafterHelperHudState", {
	enabled = function()
		local mod_enabled = type(mod.is_enabled) ~= "function" or mod:is_enabled()

		return mod_enabled and mod:get("auto_crafter_enable") == true and mod:get("auto_crafter_show_status_hud") ~= false
	end,
	lines = function()
		return mod:auto_crafter_hud_lines()
	end,
	presentation = function()
		return mod:auto_crafter_hud_presentation()
	end,
	visible_context = function(view)
		local managers = rawget(_G, "Managers")
		local state = managers and managers.state
		local game_mode = state and state.game_mode
		local ok, mode = pcall(game_mode and game_mode.game_mode_name or function () end, game_mode)
		local class_ok, class_name = pcall(hud_read_member, view, "__class_name")
		local destroyed_ok, destroyed = pcall(hud_read_member, view, "_destroyed")
		local psych_ward_brunt = ok and mode == nil and class_ok and class_name == "CreditsGoodsVendorView" and (not destroyed_ok or destroyed ~= true)

		if not ok or mode ~= "hub" and mode ~= "hub_singleplay" and not psych_ward_brunt then
			return false
		end

		local party = managers and managers.party_immaterium
		local matchmaking_ok, matchmaking = pcall(party and party.is_in_matchmaking or function () return false end, party)

		return not matchmaking_ok or matchmaking ~= true
	end,
})

local AutoCrafterViewStatusOverlay = mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/auto_crafter/darktide/view_status_overlay")

if type(AutoCrafterViewStatusOverlay) == "table" and type(AutoCrafterViewStatusOverlay.install) == "function" then
	AutoCrafterViewStatusOverlay.install(mod, {
		base = BaseView,
		item_grid = ItemGridViewBase,
		inventory = InventoryView,
		vendor = VendorInteractionViewBase,
	})
end

if type(mod.register_hud_element) == "function" then
	mod:register_hud_element({
		class_name = "HudElementBetterInventoryAutoCrafter",
		filename = "BetterInventory/scripts/mods/BetterInventory/auto_crafter/darktide/hud_element",
		use_hud_scale = true,
		visibility_groups = { "alive", "in_hub_view" },
	})
end

local function read_member(object, key)
	return object[key]
end

local function auto_crafter_read(object, key)
	if type(object) ~= "table" and type(object) ~= "userdata" then
		return nil
	end

	local ok, value = pcall(read_member, object, key)

	return ok and value or nil
end

local function auto_crafter_master_id(offer)
	local description = auto_crafter_read(offer, "description")
	local choices = auto_crafter_read(description, "lootChoices") or auto_crafter_read(description, "loot_choices")
	local choice = type(choices) == "table" and choices[1] or nil

	if type(choice) == "table" then
		return choice.masterId or choice.master_id or choice.id or choice.name
	end

	return choice or auto_crafter_read(description, "masterId") or auto_crafter_read(description, "master_id")
end

local function auto_crafter_same_id(left, right)
	return left ~= nil and right ~= nil and (left == right or tostring(left) == tostring(right))
end

local function auto_crafter_offer_matches(selected_offer, offer)
	local offer_id = auto_crafter_read(offer, "offerId") or auto_crafter_read(offer, "offer_id")
	local master_id = auto_crafter_master_id(offer)

	return auto_crafter_same_id(selected_offer.offer_id, offer_id) or selected_offer.offer_id == nil and auto_crafter_same_id(selected_offer.master_id, master_id)
end

local function auto_crafter_selected_offer_snapshot(view)
	local offer = auto_crafter_read(view, "_previewed_offer")
	if not offer then
		return nil
	end

	local tab_menu = auto_crafter_read(view, "_tab_menu_element")
	local tab_index
	if tab_menu and type(tab_menu.selected_index) == "function" then
		local ok, selected = pcall(tab_menu.selected_index, tab_menu)
		tab_index = ok and tonumber(selected) or nil
	end

	local tabs = auto_crafter_read(view, "_tabs_content")
	local tab = tab_index and type(tabs) == "table" and tabs[tab_index] or nil
	local slot_types = auto_crafter_read(tab, "slot_types")

	return {
		offer_id = auto_crafter_read(offer, "offerId") or auto_crafter_read(offer, "offer_id"),
		master_id = auto_crafter_master_id(offer),
		slot_type = type(slot_types) == "table" and slot_types[1] or nil,
		tab_index = tab_index,
	}
end

local function auto_crafter_select_offer(view, selected_offer)
	if not view or not selected_offer then
		return false, "selection_context_unavailable"
	end

	local native_offer
	local offers = auto_crafter_read(view, "_offers")

	if type(offers) == "table" then
		for _, offer in ipairs(offers) do
			if auto_crafter_offer_matches(selected_offer, offer) then
				native_offer = offer

				break
			end
		end
	end

	if not native_offer or type(view.focus_on_offer) ~= "function" then
		return false, not native_offer and "offer_not_in_native_store" or "focus_on_offer_unavailable", type(offers) == "table" and #offers or 0
	end

	local native_entry
	local layout = auto_crafter_read(view, "_offer_items_layout")

	if type(layout) == "table" then
		for _, entry in ipairs(layout) do
			local entry_offer = auto_crafter_read(entry, "offer")

			if entry_offer and auto_crafter_offer_matches(selected_offer, entry_offer) then
				native_entry = entry

				break
			end
		end
	end

	if not native_entry then
		return false, "offer_not_in_native_layout", type(layout) == "table" and #layout or 0
	end

	local tabs = auto_crafter_read(view, "_tabs_content")
	local target_tab_index = tonumber(selected_offer.tab_index)
	local native_item = auto_crafter_read(native_entry, "item")
	local native_slots = auto_crafter_read(native_item, "slots")

	if (selected_offer.slot_type or type(native_slots) == "table") and type(tabs) == "table" then
		for tab_index, tab in ipairs(tabs) do
			local slot_types = auto_crafter_read(tab, "slot_types")

			if type(slot_types) == "table" then
				for _, slot_type in ipairs(slot_types) do
					local native_slot_matches = false

					if type(native_slots) == "table" then
						for _, native_slot in ipairs(native_slots) do
							if native_slot == slot_type then
								native_slot_matches = true

								break
							end
						end
					end

					if slot_type == selected_offer.slot_type or native_slot_matches then
						target_tab_index = tab_index

						break
					end
				end
			end

			if target_tab_index then
				break
			end
		end
	end

	local tab_menu = auto_crafter_read(view, "_tab_menu_element")
	local selected_tab_index

	if tab_menu and type(tab_menu.selected_index) == "function" then
		local selected_ok, value = pcall(tab_menu.selected_index, tab_menu)

		if selected_ok then
			selected_tab_index = value
		end
	end

	if target_tab_index and selected_tab_index and target_tab_index ~= selected_tab_index then
		if type(view.cb_switch_tab) == "function" then
			local switch_ok = pcall(view.cb_switch_tab, view, target_tab_index, true)

			if not switch_ok then
				return false, "tab_switch_failed", selected_tab_index
			end
		else
			return false, "tab_switch_unavailable", selected_tab_index
		end

		return false, "tab_switch_pending", selected_tab_index
	end

	local focused_ok, focus_error = pcall(view.focus_on_offer, view, native_offer)

	if not focused_ok then
		return false, "focus_on_offer_failed", focus_error
	end

	local previewed_offer = auto_crafter_read(view, "_previewed_offer")
	local previewed_id = auto_crafter_read(previewed_offer, "offerId") or auto_crafter_read(previewed_offer, "offer_id")

	local selected = auto_crafter_same_id(selected_offer.offer_id, previewed_id) or selected_offer.offer_id == nil and auto_crafter_same_id(selected_offer.master_id, auto_crafter_master_id(previewed_offer))
	if not selected and type(view._preview_element) == "function" then
		local preview_ok, preview_error = pcall(view._preview_element, view, native_entry)

		if not preview_ok then
			return false, "preview_element_failed", preview_error
		end

		previewed_offer = auto_crafter_read(view, "_previewed_offer")
		previewed_id = auto_crafter_read(previewed_offer, "offerId") or auto_crafter_read(previewed_offer, "offer_id")
		selected = auto_crafter_same_id(selected_offer.offer_id, previewed_id) or selected_offer.offer_id == nil and auto_crafter_same_id(selected_offer.master_id, auto_crafter_master_id(previewed_offer))
	end

	if selected then
		return true
	end

	return false, "preview_not_confirmed", previewed_id
end

AutoCrafter.configure = type(AutoCrafter.configure) == "function" and AutoCrafter.configure or function()
	return false
end
AutoCrafter.on_brunt_view_ready = type(AutoCrafter.on_brunt_view_ready) == "function" and AutoCrafter.on_brunt_view_ready or function()
	return false
end
AutoCrafter.on_view_closed = type(AutoCrafter.on_view_closed) == "function" and AutoCrafter.on_view_closed or function()
	return false
end
AutoCrafter.on_context_exit = type(AutoCrafter.on_context_exit) == "function" and AutoCrafter.on_context_exit or function()
end
AutoCrafter.on_setting_changed = type(AutoCrafter.on_setting_changed) == "function" and AutoCrafter.on_setting_changed or function()
	return false
end
AutoCrafter.update = type(AutoCrafter.update) == "function" and AutoCrafter.update or function()
end
AutoCrafter.needs_update = type(AutoCrafter.needs_update) == "function" and AutoCrafter.needs_update or function()
	return false
end
AutoCrafter.shutdown = type(AutoCrafter.shutdown) == "function" and AutoCrafter.shutdown or function()
end
AutoCrafter.is_busy = type(AutoCrafter.is_busy) == "function" and AutoCrafter.is_busy or function()
	return false
end
AutoCrafter.snapshot = type(AutoCrafter.snapshot) == "function" and AutoCrafter.snapshot or function()
	return {}
end
AutoCrafter.interrupt_for_external_mutation = type(AutoCrafter.interrupt_for_external_mutation) == "function" and AutoCrafter.interrupt_for_external_mutation or function()
	return false
end

local CharacterOverviewUI = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_character_overview_ui"), "BetterInventory_character_overview_ui.lua", {
	configure = function()
		return nil
	end,
	install_hooks = function()
		return nil
	end,
	update_registered_views = function()
		return 0
	end,
	needs_update = function()
		return false
	end,
	constants = {},
})

CharacterOverviewUI.configure({
	mod = mod,
	Layout = Layout,
	CharacterOverview = CharacterOverview,
	FeatureDomains = FeatureDomains,
	Diagnostics = Diagnostics,
	InventoryView = InventoryView,
	InventoryViewContentBlueprints = InventoryViewContentBlueprints,
	ItemBlueprintGenerator = ItemBlueprintGenerator,
	Text = Text,
	lantern_recommendations_active = function()
		return type(Features.lantern_recommendations_active) == "function" and Features.lantern_recommendations_active()
	end,
	release_runtime_caches = function()
		if type(Layout.clear_runtime_caches) == "function" then
			Layout.clear_runtime_caches()
		end
		if type(Features.clear_runtime_caches) == "function" then
			Features.clear_runtime_caches()
		end
	end,
})

if type(Features.set_curio_acquisition_provider) == "function" then
	Features.set_curio_acquisition_provider(CurioAcquisition)
end

if type(CurioAcquisition.set_favorite_integration) == "function" then
	CurioAcquisition.set_favorite_integration(FavoriteIntegration)
end

if type(Features.set_diagnostics_provider) == "function" then
	Features.set_diagnostics_provider(Diagnostics)
end

if type(Layout.set_item_customization_provider) == "function" then
	Layout.set_item_customization_provider(ItemCustomization)
end

if type(ItemCustomization.install) == "function" then
	ItemCustomization.install(mod, InventoryWeaponsView, Layout)
end

AccountMutationGuard.configure({
	mod = mod,
	auto_crafter = AutoCrafter,
})

AutoCrafter.configure({
	mod = mod,
	mutation_guard = AccountMutationGuard,
	account_operation = {
		acquire = function(owner, view)
			return type(Features.acquire_account_operation) == "function" and Features.acquire_account_operation(owner, view) or nil
		end,
		conflict = function(view)
			-- Only already-dispatched mutations are hard conflicts. Read-only scans,
			-- scheduled passes, and unanswered discard prompts are safely deferred so
			-- stale automation state cannot permanently lock Auto Crafter.
			if type(CurioAcquisition.account_mutation_inflight) == "function" and CurioAcquisition.account_mutation_inflight() then
				return "automatic Curio acquisition has a purchase request in flight"
			elseif type(CurioAcquisition.account_mutation_inflight) ~= "function" and type(CurioAcquisition.is_busy) == "function" and CurioAcquisition.is_busy() then
				return "automatic Curio acquisition is already running"
			end

			if type(CurioAcquisition.defer_for_account_operation) == "function" then
				local ok, deferred, reason = pcall(CurioAcquisition.defer_for_account_operation, mod)

				if not ok or deferred == false then
					return ok and tostring(reason or "automatic Curio acquisition could not be deferred") or "automatic Curio acquisition deferral failed"
				end
			end

			if type(Features.defer_morningstar_auto_discard_for_account_operation) == "function" then
				local ok, deferred, reason = pcall(Features.defer_morningstar_auto_discard_for_account_operation, mod)

				if not ok or deferred == false then
					return ok and tostring(reason or "automatic inventory discard could not be deferred") or "automatic inventory discard deferral failed"
				end
			elseif type(Features.morningstar_auto_discard_has_started) == "function" and Features.morningstar_auto_discard_has_started() then
				return "automatic inventory discard is already running"
			end

			-- Quick Level Mastery and native vendor purchases expose their active
			-- request through this field. Never start over that wallet mutation.
			if auto_crafter_read(view, "_purchase_promise") ~= nil then
				return "another Brunt purchase is already in flight"
			end

			return nil
		end,
		is_current = function(owner, token)
			return type(Features.account_operation_is_current) ~= "function" or Features.account_operation_is_current(owner, token)
		end,
		release = function(owner, token)
			return type(Features.release_account_operation) ~= "function" or Features.release_account_operation(owner, token)
		end,
	},
	get_selected_offer = function(view)
		return view and view._previewed_offer
	end,
	get_selected_offer_snapshot = auto_crafter_selected_offer_snapshot,
	on_item_favorited = function(gear_id)
		return FavoriteIntegration.apply_auto_crafter_color(mod, gear_id)
	end,
	is_myfavorites_available = FavoriteIntegration.is_myfavorites_available,
	myfavorites_color_preview = function(index)
		return FavoriteIntegration.color_preview(mod, index)
	end,
	select_offer = auto_crafter_select_offer,
	ViewElementGrid = ViewElementGrid,
})
AccountMutationGuard.install_hooks(mod)

local Runtime = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_runtime"), "BetterInventory_runtime.lua", {
	configure = function()
		return nil
	end,
	install = function()
		return nil
	end,
})

Runtime.configure({
	mod = mod,
	Layout = Layout,
	Features = Features,
	CurioAcquisition = CurioAcquisition,
	ItemCustomization = ItemCustomization,
	EquipmentPersistence = EquipmentPersistence,
	SettingsRegistry = SettingsRegistry,
	Diagnostics = Diagnostics,
	AutoCrafter = AutoCrafter,
	Capabilities = Capabilities,
	CharacterOverviewUI = CharacterOverviewUI,
	FeatureDomains = FeatureDomains,
	FavoriteIntegration = FavoriteIntegration,
	CraftingMechanicusModifyView = CraftingMechanicusModifyView,
	CreditsVendorView = CreditsVendorView,
	MainMenuView = MainMenuView,
	InventoryBackgroundView = InventoryBackgroundView,
	ItemGridViewBase = ItemGridViewBase,
	ItemGridViewBaseDefinitions = ItemGridViewBaseDefinitions,
	InventoryWeaponsView = InventoryWeaponsView,
	ViewElementGrid = ViewElementGrid,
	WeaponOptionsPanel = WeaponOptionsPanel,
})
Runtime.install()
