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
