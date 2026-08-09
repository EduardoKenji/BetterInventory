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
local ItemCustomization = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_item_customization"), "BetterInventory_item_customization.lua")
local EquipmentPersistence = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_equipment_persistence"), "BetterInventory_equipment_persistence.lua")
local SettingsRegistry = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_settings"), "BetterInventory_settings.lua", {
	should_refresh_dependencies = function() return true end,
})
local Diagnostics = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_diagnostics"), "BetterInventory_diagnostics.lua")
local AutoCrafter = mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_auto_crafter")

if type(AutoCrafter) ~= "table" then
	AutoCrafter = {}
end

mod.auto_crafter_hud_lines = function()
	return type(AutoCrafter.hud_lines) == "function" and AutoCrafter.hud_lines() or {}
end

rawset(_G, "AutoCrafterHelperHudState", {
	enabled = function()
		return mod:get("auto_crafter_enable") == true and mod:get("auto_crafter_show_status_hud") ~= false
	end,
	lines = function()
		return mod:auto_crafter_hud_lines()
	end,
	visible_context = function()
		local managers = rawget(_G, "Managers")
		local state = managers and managers.state
		local game_mode = state and state.game_mode
		local ok, mode = pcall(game_mode and game_mode.game_mode_name or function () end, game_mode)

		if not ok or mode ~= "hub" and mode ~= "hub_singleplay" then
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
		BaseView,
		ItemGridViewBase,
		InventoryView,
		VendorInteractionViewBase,
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

local function auto_crafter_read(object, key)
	if type(object) ~= "table" and type(object) ~= "userdata" then
		return nil
	end

	local ok, value = pcall(function()
		return object[key]
	end)

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

local function auto_crafter_select_offer(view, selected_offer)
	if not view or not selected_offer then
		return false
	end

	local native_offer
	local offers = auto_crafter_read(view, "_offers")

	if type(offers) == "table" then
		for _, offer in ipairs(offers) do
			local offer_id = auto_crafter_read(offer, "offerId") or auto_crafter_read(offer, "offer_id")
			local master_id = auto_crafter_master_id(offer)
			local id_matches = auto_crafter_same_id(selected_offer.offer_id, offer_id)
			local master_matches = auto_crafter_same_id(selected_offer.master_id, master_id)

			if id_matches or selected_offer.offer_id == nil and master_matches then
				native_offer = offer

				break
			end
		end
	end

	if not native_offer or type(view.focus_on_offer) ~= "function" then
		return false
	end

	local tabs = auto_crafter_read(view, "_tabs_content")
	local target_tab_index

	if selected_offer.slot_type and type(tabs) == "table" then
		for tab_index, tab in ipairs(tabs) do
			local slot_types = auto_crafter_read(tab, "slot_types")

			if type(slot_types) == "table" then
				for _, slot_type in ipairs(slot_types) do
					if slot_type == selected_offer.slot_type then
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
			pcall(view.cb_switch_tab, view, target_tab_index, true)
		end

		return false
	end

	local focused_ok = pcall(view.focus_on_offer, view, native_offer)

	if not focused_ok then
		return false
	end

	local previewed_offer = auto_crafter_read(view, "_previewed_offer")
	local previewed_id = auto_crafter_read(previewed_offer, "offerId") or auto_crafter_read(previewed_offer, "offer_id")

	return auto_crafter_same_id(selected_offer.offer_id, previewed_id) or selected_offer.offer_id == nil and auto_crafter_same_id(selected_offer.master_id, auto_crafter_master_id(previewed_offer))
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
AutoCrafter.shutdown = type(AutoCrafter.shutdown) == "function" and AutoCrafter.shutdown or function()
end

local CharacterOverviewUI = no_op_module(mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_character_overview_ui"), "BetterInventory_character_overview_ui.lua", {
	configure = function()
		return nil
	end,
	install_hooks = function()
		return nil
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
})

if type(Features.set_curio_acquisition_provider) == "function" then
	Features.set_curio_acquisition_provider(CurioAcquisition)
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

AutoCrafter.configure({
	mod = mod,
	get_selected_offer = function(view)
		return view and view._previewed_offer
	end,
	select_offer = auto_crafter_select_offer,
	ViewElementGrid = ViewElementGrid,
})

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
	CraftingMechanicusModifyView = CraftingMechanicusModifyView,
	CreditsVendorView = CreditsVendorView,
	MainMenuView = MainMenuView,
	InventoryBackgroundView = InventoryBackgroundView,
	ItemGridViewBase = ItemGridViewBase,
	ItemGridViewBaseDefinitions = ItemGridViewBaseDefinitions,
	InventoryWeaponsView = InventoryWeaponsView,
	ViewElementGrid = ViewElementGrid,
})
Runtime.install()
