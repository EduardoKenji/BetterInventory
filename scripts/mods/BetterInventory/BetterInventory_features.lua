local Items = require("scripts/utilities/items")
local ProfileUtils = require("scripts/utilities/profile_utils")
local RaritySettings = require("scripts/settings/item/rarity_settings")
local PanelDefinitions = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_panel_definitions")
local PanelRuntime = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_panel_runtime")
local ArmouryPanel = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_armoury_panel")
local CurioValues = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_curio_values")
local DiscardPolicy = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_discard_policy")
local Lantern = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_feature_lantern")
local SortOptions = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_feature_sort_options")
local PanelState = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_feature_panel_state")
local DiscardSummary = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_feature_discard_summary")

if type(CurioValues) ~= "table" then
	CurioValues = {
		resolve = function()
			return
		end,
	}
end

local Features = {}
local armoury_panel
local scenegraph_rect
local panel_entry = PanelRuntime.panel_entry
local panel_lantern_entry = PanelRuntime.panel_lantern_entry
local controller_element_state = PanelRuntime.controller_element_state
local clear_controller_element_selection = PanelRuntime.clear_controller_element_selection
local restore_controller_element = PanelRuntime.restore_controller_element
local set_inventory_options_panel_controller_focus = PanelRuntime.set_inventory_options_panel_controller_focus
local update_inventory_options_panel_controller_selection = PanelRuntime.update_inventory_options_panel_controller_selection
local INVENTORY_SORT_TOGGLE_ID = PanelDefinitions.INVENTORY_SORT_TOGGLE_ID
local INVENTORY_PERFECT_SORT_TOGGLE_ID = PanelDefinitions.INVENTORY_PERFECT_SORT_TOGGLE_ID
local INVENTORY_SORT_LABEL_ID = PanelDefinitions.INVENTORY_SORT_LABEL_ID
local INVENTORY_DISCARD_LABEL_ID = PanelDefinitions.INVENTORY_DISCARD_LABEL_ID
local INVENTORY_DISCARD_MODE_ID = PanelDefinitions.INVENTORY_DISCARD_MODE_ID
local INVENTORY_DISCARD_SKIP_CONFIRMATION_ID = PanelDefinitions.INVENTORY_DISCARD_SKIP_CONFIRMATION_ID
local INVENTORY_QUICK_DISCARD_ID = PanelDefinitions.INVENTORY_QUICK_DISCARD_ID
local INVENTORY_DISCARD_MAX_LEVEL_ID = PanelDefinitions.INVENTORY_DISCARD_MAX_LEVEL_ID
local INVENTORY_DISCARD_EQUIPPED_LEVEL_PROTECTION_ID = PanelDefinitions.INVENTORY_DISCARD_EQUIPPED_LEVEL_PROTECTION_ID
local INVENTORY_DISCARD_MELEE_ID = PanelDefinitions.INVENTORY_DISCARD_MELEE_ID
local INVENTORY_DISCARD_RANGED_ID = PanelDefinitions.INVENTORY_DISCARD_RANGED_ID
local INVENTORY_DISCARD_CURIO_ID = PanelDefinitions.INVENTORY_DISCARD_CURIO_ID
local INVENTORY_DISCARD_PROTECTION_ID = PanelDefinitions.INVENTORY_DISCARD_PROTECTION_ID
local INVENTORY_DISCARD_CURIO_PROTECTION_ID = PanelDefinitions.INVENTORY_DISCARD_CURIO_PROTECTION_ID
local INVENTORY_DISCARD_CURIO_LEVEL_ID = PanelDefinitions.INVENTORY_DISCARD_CURIO_LEVEL_ID
local INVENTORY_CURIO_BUYER_ENABLE_ID = PanelDefinitions.INVENTORY_CURIO_BUYER_ENABLE_ID
local INVENTORY_CURIO_BUYER_OPERATIVE_SELECTION_ID = PanelDefinitions.INVENTORY_CURIO_BUYER_OPERATIVE_SELECTION_ID
local INVENTORY_CURIO_BUYER_ROTATION_ID = PanelDefinitions.INVENTORY_CURIO_BUYER_ROTATION_ID
local INVENTORY_CURIO_BUYER_REFRESH_ID = PanelDefinitions.INVENTORY_CURIO_BUYER_REFRESH_ID
local INVENTORY_CURIO_BUYER_TARGET_MODE_ID = PanelDefinitions.INVENTORY_CURIO_BUYER_TARGET_MODE_ID
local INVENTORY_CURIO_BUYER_MIN_LEVEL_ID = PanelDefinitions.INVENTORY_CURIO_BUYER_MIN_LEVEL_ID
local INVENTORY_CURIO_BUYER_MIN_HEALTH_ID = PanelDefinitions.INVENTORY_CURIO_BUYER_MIN_HEALTH_ID
local INVENTORY_CURIO_BUYER_MIN_TOUGHNESS_ID = PanelDefinitions.INVENTORY_CURIO_BUYER_MIN_TOUGHNESS_ID
local INVENTORY_OPTIONS_PANEL_REFERENCE = PanelDefinitions.INVENTORY_OPTIONS_PANEL_REFERENCE
local INVENTORY_OPTIONS_PANEL_MIN_HEIGHT = PanelDefinitions.INVENTORY_OPTIONS_PANEL_MIN_HEIGHT
local INVENTORY_OPTIONS_PANEL_DEFAULT_WIDTH = PanelDefinitions.INVENTORY_OPTIONS_PANEL_DEFAULT_WIDTH
local INVENTORY_OPTIONS_PANEL_DEFAULT_MAX_HEIGHT = PanelDefinitions.INVENTORY_OPTIONS_PANEL_DEFAULT_MAX_HEIGHT
local INVENTORY_OPTIONS_PANEL_DEFAULT_ROW_SPACING = PanelDefinitions.INVENTORY_OPTIONS_PANEL_DEFAULT_ROW_SPACING
local INVENTORY_OPTIONS_PANEL_DEFAULT_VERTICAL_PADDING = PanelDefinitions.INVENTORY_OPTIONS_PANEL_DEFAULT_VERTICAL_PADDING
local INVENTORY_OPTIONS_PANEL_DEFAULT_HORIZONTAL_PADDING = PanelDefinitions.INVENTORY_OPTIONS_PANEL_DEFAULT_HORIZONTAL_PADDING
local INVENTORY_OPTIONS_PANEL_WEAPON_GAP = PanelDefinitions.INVENTORY_OPTIONS_PANEL_WEAPON_GAP
local INVENTORY_OPTIONS_PANEL_BUTTON_GAP = PanelDefinitions.INVENTORY_OPTIONS_PANEL_BUTTON_GAP
local ARMOURY_NATIVE_SORT_PANEL_REFERENCE = PanelDefinitions.ARMOURY_NATIVE_SORT_PANEL_REFERENCE
local ARMOURY_NATIVE_SORT_PANEL_WIDTH = PanelDefinitions.ARMOURY_NATIVE_SORT_PANEL_WIDTH
local ARMOURY_NATIVE_SORT_PANEL_HEIGHT = PanelDefinitions.ARMOURY_NATIVE_SORT_PANEL_HEIGHT
local ARMOURY_NATIVE_SORT_PANEL_MIN_HEIGHT = PanelDefinitions.ARMOURY_NATIVE_SORT_PANEL_MIN_HEIGHT
local ARMOURY_NATIVE_SORT_PANEL_TOP = PanelDefinitions.ARMOURY_NATIVE_SORT_PANEL_TOP
local ARMOURY_NATIVE_SORT_PANEL_RIGHT_MARGIN = PanelDefinitions.ARMOURY_NATIVE_SORT_PANEL_RIGHT_MARGIN
local ARMOURY_NATIVE_SORT_PANEL_WEAPON_GAP = PanelDefinitions.ARMOURY_NATIVE_SORT_PANEL_WEAPON_GAP
local ARMOURY_NATIVE_SORT_PANEL_WALLET_GAP = PanelDefinitions.ARMOURY_NATIVE_SORT_PANEL_WALLET_GAP
local ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT = PanelDefinitions.ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT
local ARMOURY_NATIVE_SORT_PANEL_ROW_SPACING = PanelDefinitions.ARMOURY_NATIVE_SORT_PANEL_ROW_SPACING
local ARMOURY_NATIVE_SORT_PANEL_PADDING = PanelDefinitions.ARMOURY_NATIVE_SORT_PANEL_PADDING
local ARMOURY_NATIVE_SORT_CHECKBOX_LEFT_PADDING = PanelDefinitions.ARMOURY_NATIVE_SORT_CHECKBOX_LEFT_PADDING
local GLOBAL_STORE_SERVICE = PanelDefinitions.GLOBAL_STORE_SERVICE
local INVENTORY_CURIO_NATIVE_WIDTH = PanelDefinitions.INVENTORY_CURIO_NATIVE_WIDTH
local INVENTORY_CURIO_NATIVE_GRID_WIDTH = PanelDefinitions.INVENTORY_CURIO_NATIVE_GRID_WIDTH
local INVENTORY_CURIO_NATIVE_HEADER_HEIGHT = PanelDefinitions.INVENTORY_CURIO_NATIVE_HEADER_HEIGHT
local INVENTORY_CURIO_NATIVE_ICON_HEIGHT = PanelDefinitions.INVENTORY_CURIO_NATIVE_ICON_HEIGHT
local INVENTORY_VIRTUAL_CANVAS_WIDTH = PanelDefinitions.INVENTORY_VIRTUAL_CANVAS_WIDTH
local INVENTORY_VIRTUAL_EDGE_MARGIN = PanelDefinitions.INVENTORY_VIRTUAL_EDGE_MARGIN
local INVENTORY_DISCARD_WIDGET_IDS = PanelDefinitions.INVENTORY_DISCARD_WIDGET_IDS
local INVENTORY_OPTIONS_PANEL_BLUEPRINTS = PanelDefinitions.INVENTORY_OPTIONS_PANEL_BLUEPRINTS
local ARMOURY_NATIVE_SORT_BLUEPRINTS = PanelDefinitions.ARMOURY_NATIVE_SORT_BLUEPRINTS
local numeric_setting = PanelDefinitions.numeric_setting
local inventory_options_panel_geometry = PanelDefinitions.inventory_options_panel_geometry
local inventory_sort_toggle_passes = PanelDefinitions.inventory_sort_toggle_passes
local quick_discard_passes = PanelDefinitions.quick_discard_passes
local section_label_passes = PanelDefinitions.section_label_passes
local compact_selector_passes = PanelDefinitions.compact_selector_passes
local compact_checkbox_passes = PanelDefinitions.compact_checkbox_passes
local compact_stepper_passes = PanelDefinitions.compact_stepper_passes
local panel_sub_label_passes = PanelDefinitions.panel_sub_label_passes
local panel_section_header_passes = PanelDefinitions.panel_section_header_passes
local armoury_native_sort_option_passes = PanelDefinitions.armoury_native_sort_option_passes
local append_panel_checkbox_passes = PanelDefinitions.append_panel_checkbox_passes
local panel_type_checkbox_passes = PanelDefinitions.panel_type_checkbox_passes
Features._diagnostics = nil
Features._discard_policy = DiscardPolicy
Features._domains = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_feature_domains")

if type(Features._domains) ~= "table" or type(Features._domains.sorting) ~= "table" or type(Features._domains.sorting.signature) ~= "function" then
	Features._domains = {
		markers = {
			invalidate_grid = function()
				return false
			end,
		},
		sorting = {
			signature = function(parts)
				return table.concat(parts or {}, "|")
			end,
		},
		panels = {
			composite_key = function(structure_key, lantern_signature, sorting_signature)
				return tostring(structure_key or 0) .. ":" .. tostring(lantern_signature or "") .. ":" .. tostring(sorting_signature or "")
			end,
		},
	}
end

Features._composition = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_feature_composition")

if type(Features._composition) ~= "table" or type(Features._composition.invalidate_view) ~= "function" or type(Features._composition.inputs_changed) ~= "function" then
	Features._composition = {
		invalidate_view = function()
			return false
		end,
		inputs_changed = function()
			return false
		end,
	}
end

Features._sorting = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_feature_sorting")

if type(Features._sorting) ~= "table" or type(Features._sorting.is_enabled) ~= "function" or type(Features._sorting.set_integration) ~= "function" then
	Features._sorting = {
		is_enabled = function()
			return false
		end,
		mod = function()
			return nil
		end,
		definitions = function()
			return nil
		end,
		set_invalidation = function()
		end,
		native_option_start = function(view)
			return #(view and view._sort_options or {}) + 1
		end,
		set_integration = function()
			return false
		end,
		preserve_native_options = function()
			return false
		end,
		new_comparator_manager = function()
			local registered_views = setmetatable({}, {
				__mode = "k",
			})

			return {
				registered_views = registered_views,
				configure = function()
				end,
				configure_inventory = function()
				end,
				configure_armoury = function()
				end,
				configure_global_store = function()
				end,
				rebind = function()
				end,
				restore = function()
				end,
				resort = function()
				end,
			}
		end,
	}
end

Features.set_diagnostics_provider = function(provider)
	Features._diagnostics = provider
end

Features.count_diagnostic = function(name, amount)
	local diagnostics = Features._diagnostics

	if diagnostics and type(diagnostics.count) == "function" then
		diagnostics.count(name, amount)
	end
end

Features.invalidate_view_composition = function(view)
	return Features._composition.invalidate_view(view)
end

Lantern.configure(function(view)
	return Features.invalidate_view_composition(view)
end)

local function restore_lantern_weapon_panel(view)
	return Lantern.release_lantern_inventory_section(view)
end


Features._sorting.set_invalidation(Features.invalidate_view_composition)

Features.composition_inputs_changed = function(view, slot_kind)
	return Features._composition.inputs_changed(view, slot_kind, Features._sorting.mod())
end

Features._contracts = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_contracts")

if type(Features._contracts) ~= "table" or type(Features._contracts.safe_call) ~= "function" or type(Features._contracts.safe_method) ~= "function" then
	Features._contracts = {
			 safe_call = function(method, ...)
			if type(method) ~= "function" then
				return false, "method unavailable"
			end

			return pcall(method, ...)
		end,
		safe_method = function(object, method_name, ...)
			local object_type = type(object)
			if (object_type ~= "table" and object_type ~= "userdata") or type(method_name) ~= "string" then
				return false, "method unavailable"
			end

			local lookup_ok, method = pcall(function()
				return object[method_name]
			end)

			if not lookup_ok or type(method) ~= "function" then
				return false, lookup_ok and "method unavailable" or method
			end

			return pcall(method, object, ...)
		end,
	}
end

Features._view_session = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_view_session")

Features._operation_arbiter = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_operation_arbiter")

Features.begin_view_session = function(view, kind)
	local sessions = Features._view_session

	if sessions and type(sessions.begin) == "function" then
		return sessions.begin(view, kind)
	end
end

Features.end_view_session = function(view, reason)
	local sessions = Features._view_session

	if sessions and type(sessions.close) == "function" then
		return sessions.close(view, reason)
	end

	return false
end

Features.close_all_view_sessions = function(reason)
	return Features._view_session.close_all(reason)
end

Features.register_view_session_cleanup = function(view, cleanup_id, callback)
	local sessions = Features._view_session

	if sessions and type(sessions.register_cleanup) == "function" then
		return sessions.register_cleanup(view, cleanup_id, callback)
	end

	return false
end

-- Keep sort ownership independent from the optional settings panels. A vendor
-- can have a wrapped native comparator even when BetterInventory did not create
-- a visible sorting panel for it.
Features._registered_sort_views = setmetatable({}, {
	__mode = "k",
})

local registered_inventory_views = setmetatable({}, {
	__mode = "k",
})
local registered_armoury_views = setmetatable({}, {
	__mode = "k",
})

Features.invalidate_all_view_composition = function()
	for view in pairs(registered_inventory_views) do
		Features.invalidate_view_composition(view)
	end

	for view in pairs(registered_armoury_views) do
		Features.invalidate_view_composition(view)
	end
end

local perfect_roll_cache = setmetatable({}, {
	__mode = "k",
})
local curio_acquisition_provider

local function item_sorting_is_enabled()
	return Features._sorting.is_enabled()
end

Features.set_curio_acquisition_provider = function(provider)
	curio_acquisition_provider = type(provider) == "table" and provider or nil
end

local function known_curio_buyer_profiles(mod)
	if not curio_acquisition_provider or type(curio_acquisition_provider.known_profiles) ~= "function" then
		return {}
	end

	local profiles = curio_acquisition_provider.known_profiles(mod)

	if type(profiles) ~= "table" then
		return {}
	end

	if type(curio_acquisition_provider.request_profile_discovery) == "function" then
		-- The provider coalesces these requests and refreshes only when its cache is
		-- empty or stale. Keeping this call here lets opening the inventory panel
		-- pick up renamed, created or deleted operatives without frame-by-frame
		-- backend traffic.
		curio_acquisition_provider.request_profile_discovery()
	end

	return profiles
end

local function curio_buyer_profile_revision()
	if curio_acquisition_provider and type(curio_acquisition_provider.profile_revision) == "function" then
		return tonumber(curio_acquisition_provider.profile_revision()) or 0
	end

	return 0
end

local function inventory_slot_kind(layout, view)
	if not view or view.__class_name ~= "InventoryWeaponsView" then
		return
	end

	local slot_kind = layout.slot_kind(view)

	if slot_kind == "slot_primary" or slot_kind == "slot_secondary" or slot_kind == "curio" then
		return slot_kind
	end
end

local function is_inventory_view(layout, view)
	return inventory_slot_kind(layout, view) ~= nil
end

local function inventory_grid_has_right_neighbour(view)
	local item_grid = view and view._item_grid
	local selected_index = item_grid and type(item_grid.selected_grid_index) == "function" and item_grid:selected_grid_index()
	local widgets = item_grid and type(item_grid.widgets) == "function" and item_grid:widgets()
	local selected_widget = selected_index and widgets and widgets[selected_index]
	local selected_row = selected_widget and selected_widget.content and selected_widget.content.row

	if type(selected_index) ~= "number" or type(widgets) ~= "table" or type(selected_row) ~= "number" then
		return false
	end

	for index = selected_index + 1, #widgets do
		local widget = widgets[index]
		local content = widget and widget.content
		local row = content and content.row

		if type(row) == "number" and row > selected_row then
			break
		end

		if row == selected_row and content.hotspot then
			return true
		end
	end

	return false
end

Features.capture_inventory_controller_navigation = function(view, input_service)
	if view then
		view._better_inventory_keep_right_navigation_in_grid = false
	end

	local weapon_options = view and view._weapon_options_element
	local item_grid = view and view._item_grid

	if not view or view._using_cursor_navigation ~= false or view._selected_options == true or not weapon_options or not item_grid or not input_service or type(input_service.get) ~= "function" then
		return false
	end

	local options_visible = type(weapon_options.visible) == "function" and weapon_options:visible()
	local options_input_disabled = type(weapon_options.input_disabled) == "function" and weapon_options:input_disabled()
	local item_grid_input_disabled = type(item_grid.input_disabled) == "function" and item_grid:input_disabled()

	if not options_visible or not options_input_disabled or item_grid_input_disabled or not input_service:get("navigate_right_continuous") or not inventory_grid_has_right_neighbour(view) then
		return false
	end

	view._better_inventory_keep_right_navigation_in_grid = true

	return true
end

Features.consume_inventory_controller_grid_navigation = function(view)
	local keep_in_grid = view and view._better_inventory_keep_right_navigation_in_grid == true

	if view then
		view._better_inventory_keep_right_navigation_in_grid = false
	end

	return keep_in_grid
end

local function is_armoury_requisition_view(view)
	return view and view.__class_name == "CreditsVendorView" and view._optional_store_service == nil
end

local function is_global_store_view(view)
	return view and view.__class_name == "CreditsVendorView" and view._optional_store_service == GLOBAL_STORE_SERVICE
end

local function is_armoury_sort_view(view)
	return is_armoury_requisition_view(view) or is_global_store_view(view)
end

local function is_sortable_view(layout, view)
	return is_inventory_view(layout, view) or is_armoury_sort_view(view)
end

Features.add_inventory_sort_toggle_definition = function(mod, layout, definitions, view)
	return PanelDefinitions.add_inventory_sort_toggle_definition(mod, layout, definitions, view, inventory_slot_kind)
end
local function panel_header_entry(mod, layout, view, control_id, section_id, label_function)
	local geometry = view._better_inventory_options_panel_geometry

	return panel_entry(view, control_id, 40, panel_section_header_passes(geometry.content_width), {
		chevron = "v",
		label = label_function(),
	}, function(widget)
		widget.content.hotspot.pressed_callback = function()
			local collapsed = view._better_inventory_options_panel_collapsed

			collapsed[section_id] = not collapsed[section_id]
			Features.invalidate_view_composition(view)
			-- Hotspot callbacks execute while ViewElementGrid is drawing. Rebuilding
			-- here clears the widget array underneath Darktide's active draw loop.
			-- The changed structure key is detected and rebuilt safely on the next
			-- InventoryWeaponsView update, before the following draw begins.
		end
	end, function(widget)
		local is_collapsed = view._better_inventory_options_panel_collapsed[section_id] == true

		widget.content.chevron = is_collapsed and ">" or "v"
	end, { "hotspot" })
end


local function panel_sort_entry(mod, layout, view)
	return panel_entry(view, INVENTORY_SORT_TOGGLE_ID, 38, inventory_sort_toggle_passes(), {
		checked = mod:get("prioritize_equipped_favorites") ~= false,
		label = mod:localize("prioritize_equipped_favorites_inventory_label"),
	}, function(widget)
		widget.content.hotspot.pressed_callback = function()
			mod:set("prioritize_equipped_favorites", not widget.content.checked, false)
			Features.sync_inventory_sort_setting(mod, layout)
		end
	end, function(widget)
		widget.content.checked = mod:get("prioritize_equipped_favorites") ~= false
	end, { "hotspot" })
end

local function panel_perfect_sort_entry(mod, layout, view)
	return panel_entry(view, INVENTORY_PERFECT_SORT_TOGGLE_ID, 38, inventory_sort_toggle_passes(), {
		checked = mod:get("prioritize_perfect_roll_weapons") == true,
		label = mod:localize("prioritize_perfect_roll_weapons_inventory_label"),
	}, function(widget)
		widget.content.hotspot.pressed_callback = function()
			mod:set("prioritize_perfect_roll_weapons", not widget.content.checked, false)
			Features.sync_inventory_sort_setting(mod, layout)
		end
	end, function(widget)
		widget.content.checked = mod:get("prioritize_perfect_roll_weapons") == true
	end, { "hotspot" })
end

local function panel_mode_entry(mod, layout, view)
	local geometry = view._better_inventory_options_panel_geometry

	return panel_entry(view, INVENTORY_DISCARD_MODE_ID, 34, compact_selector_passes(geometry.content_width, 110), {
		label = mod:localize("quick_discard_inventory_mode"),
		value = "",
	}, function(widget)
		widget.content.hotspot.pressed_callback = function()
			local mode = mod:get("quick_discard_mode") == "automatic" and "manual" or "automatic"

			mod:set("quick_discard_mode", mode, false)
			widget.content.value = mod:localize("quick_discard_mode_" .. mode) .. "  >"
			-- Automatic mode adds its confirmation row. Rebuilding this ViewElementGrid
			-- inside its own pressed callback can invalidate Darktide's active draw
			-- iteration, so this view rebuilds on the next normal update.
			Features.sync_quick_discard_settings(mod, layout, view)
		end
	end, function(widget)
		local mode = mod:get("quick_discard_mode") == "automatic" and "automatic" or "manual"

		if widget.content.better_inventory_mode ~= mode then
			widget.content.better_inventory_mode = mode
			widget.content.value = mod:localize("quick_discard_mode_" .. mode) .. "  >"
		end
	end, { "hotspot" })
end

local function panel_curio_buyer_target_mode_entry(mod, layout, view)
	local geometry = view._better_inventory_options_panel_geometry

	return panel_entry(view, INVENTORY_CURIO_BUYER_TARGET_MODE_ID, 34, compact_selector_passes(geometry.content_width, 120, true), {
		label = mod:localize("automatic_curio_target_mode_inventory_suffix"),
		value = "",
	}, function(widget)
		widget.content.hotspot.pressed_callback = function()
			local mode = mod:get("automatic_curio_target_mode") == "characters" and "classes" or "characters"

			mod:set("automatic_curio_target_mode", mode, false)

			if curio_acquisition_provider and type(curio_acquisition_provider.on_setting_changed) == "function" then
				curio_acquisition_provider.on_setting_changed(mod, "automatic_curio_target_mode")
			end

			if mode == "characters" and curio_acquisition_provider and type(curio_acquisition_provider.request_profile_discovery) == "function" then
				curio_acquisition_provider.request_profile_discovery()
			end

			Features.sync_curio_acquisition_settings(mod, layout, view)
		end
	end, function(widget)
		local mode = mod:get("automatic_curio_target_mode") == "characters" and "characters" or "classes"

		if widget.content.better_inventory_mode ~= mode then
			widget.content.better_inventory_mode = mode
			widget.content.value = mod:localize("automatic_curio_target_mode_" .. mode) .. "  >"
		end
	end, { "hotspot" })
end

local function panel_sub_label_entry(mod, view, control_id, label_id)
	local geometry = view._better_inventory_options_panel_geometry

	return panel_entry(view, control_id, 26, panel_sub_label_passes(geometry.content_width), {
		label = mod:localize(label_id),
	})
end

local function panel_quick_discard_entry(mod, layout, view)
	return panel_entry(view, INVENTORY_QUICK_DISCARD_ID, 40, quick_discard_passes(), {
		discard_label = mod:localize("quick_discard_inventory_action"),
		prefix = mod:localize("quick_discard_inventory_prefix"),
		rarity_label = "",
		suffix = mod:localize("quick_discard_inventory_suffix"),
		visible = true,
	}, function(widget)
		widget.content.rarity_hotspot.pressed_callback = function()
			local rarity = math.clamp(math.floor(tonumber(mod:get("quick_discard_rarity")) or 1), 1, 5)

			mod:set("quick_discard_rarity", rarity % 5 + 1, false)
			Features.sync_quick_discard_settings(mod, layout)
		end
		widget.content.discard_hotspot.pressed_callback = function()
			Features.request_quick_discard(mod, layout, view)
		end
	end, function(widget)
		local rarity = math.clamp(math.floor(tonumber(mod:get("quick_discard_rarity")) or 1), 1, 5)

		if widget.content.better_inventory_rarity ~= rarity then
			local rarity_settings = RaritySettings[rarity]
			local rarity_color = rarity_settings and rarity_settings.color or Color.terminal_text_body(255, true)

			widget.content.better_inventory_rarity = rarity
			widget.content.rarity_label = mod:localize("quick_discard_rarity_" .. rarity) .. "  >"

			if widget.style and widget.style.rarity_label then
				widget.style.rarity_label.text_color = table.clone(rarity_color)
			end
		end
	end, { "rarity_hotspot", "discard_hotspot" })
end

local function panel_stepper_entry(mod, layout, view, control_id, setting_id, label_id, default_value, sync_function, minimum, maximum, step, suffix)
	local geometry = view._better_inventory_options_panel_geometry
	minimum = tonumber(minimum) or 0
	maximum = tonumber(maximum) or 500
	step = tonumber(step) or 10
	suffix = suffix or ""

	local function current_value()
		return math.clamp(math.floor((tonumber(mod:get(setting_id)) or default_value) + 0.5), minimum, maximum)
	end

	return panel_entry(view, control_id, 34, compact_stepper_passes(geometry.content_width), {
		label = mod:localize(label_id),
		value = tostring(current_value()) .. suffix,
	}, function(widget)
		local function change_value(delta)
			local value = math.clamp(current_value() + delta, minimum, maximum)
			local sync = sync_function or Features.sync_quick_discard_settings

			mod:set(setting_id, value, false)
			sync(mod, layout)
		end

		widget.content.decrease_hotspot.pressed_callback = function()
			change_value(-step)
		end
		widget.content.increase_hotspot.pressed_callback = function()
			change_value(step)
		end
	end, function(widget)
		local value = current_value()

		if widget.content.better_inventory_value ~= value then
			widget.content.better_inventory_value = value
			widget.content.value = tostring(value) .. suffix
		end
	end, { "decrease_hotspot", "increase_hotspot" })
end

local function panel_checkbox_entry(mod, layout, view, control_id, setting_id, label_id, default_enabled, defer_panel_rebuild, sync_function)
	local function is_enabled()
		local value = mod:get(setting_id)

		if value == nil then
			return default_enabled ~= false
		end

		return value == true
	end

	return panel_entry(view, control_id, 34, compact_checkbox_passes(), {
		checked = is_enabled(),
		label = mod:localize(label_id),
	}, function(widget)
		widget.content.hotspot.pressed_callback = function()
			local enabled = not is_enabled()
			local sync = sync_function or Features.sync_quick_discard_settings

			widget.content.checked = enabled
			mod:set(setting_id, enabled, false)
			sync(mod, layout, defer_panel_rebuild and view or nil)
		end
	end, function(widget)
		widget.content.checked = is_enabled()
	end, { "hotspot" })
end

SortOptions.configure({
	count_diagnostic = Features.count_diagnostic,
	is_armoury_sort_view = is_armoury_sort_view,
	item_sorting_is_enabled = item_sorting_is_enabled,
	signature = Features._domains.sorting.signature,
	sorting = Features._sorting,
})

local function item_sorting_custom_option_start(view)
	return SortOptions.item_sorting_custom_option_start(view)
end

local function item_sorting_options_signature(view)
	return SortOptions.item_sorting_options_signature(view)
end

armoury_panel = ArmouryPanel.new({
	ARMOURY_NATIVE_SORT_BLUEPRINTS = ARMOURY_NATIVE_SORT_BLUEPRINTS,
	ARMOURY_NATIVE_SORT_CHECKBOX_LEFT_PADDING = ARMOURY_NATIVE_SORT_CHECKBOX_LEFT_PADDING,
	ARMOURY_NATIVE_SORT_PANEL_HEIGHT = ARMOURY_NATIVE_SORT_PANEL_HEIGHT,
	ARMOURY_NATIVE_SORT_PANEL_MIN_HEIGHT = ARMOURY_NATIVE_SORT_PANEL_MIN_HEIGHT,
	ARMOURY_NATIVE_SORT_PANEL_PADDING = ARMOURY_NATIVE_SORT_PANEL_PADDING,
	ARMOURY_NATIVE_SORT_PANEL_REFERENCE = ARMOURY_NATIVE_SORT_PANEL_REFERENCE,
	ARMOURY_NATIVE_SORT_PANEL_RIGHT_MARGIN = ARMOURY_NATIVE_SORT_PANEL_RIGHT_MARGIN,
	ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT = ARMOURY_NATIVE_SORT_PANEL_ROW_HEIGHT,
	ARMOURY_NATIVE_SORT_PANEL_ROW_SPACING = ARMOURY_NATIVE_SORT_PANEL_ROW_SPACING,
	ARMOURY_NATIVE_SORT_PANEL_TOP = ARMOURY_NATIVE_SORT_PANEL_TOP,
	ARMOURY_NATIVE_SORT_PANEL_WALLET_GAP = ARMOURY_NATIVE_SORT_PANEL_WALLET_GAP,
	ARMOURY_NATIVE_SORT_PANEL_WEAPON_GAP = ARMOURY_NATIVE_SORT_PANEL_WEAPON_GAP,
	ARMOURY_NATIVE_SORT_PANEL_WIDTH = ARMOURY_NATIVE_SORT_PANEL_WIDTH,
	INVENTORY_VIRTUAL_CANVAS_WIDTH = INVENTORY_VIRTUAL_CANVAS_WIDTH,
	armoury_native_sort_option_passes = armoury_native_sort_option_passes,
	begin_view_session = Features.begin_view_session,
	clear_controller_element_selection = clear_controller_element_selection,
	controller_element_state = controller_element_state,
	features = Features,
	inventory_sort_toggle_passes = inventory_sort_toggle_passes,
	is_armoury_sort_view = is_armoury_sort_view,
	item_sorting_custom_option_start = item_sorting_custom_option_start,
	item_sorting_is_enabled = item_sorting_is_enabled,
	item_sorting_options_signature = item_sorting_options_signature,
	panel_section_header_passes = panel_section_header_passes,
	registered_views = registered_armoury_views,
	restore_controller_element = restore_controller_element,
	sync_inventory_sort_setting = function(mod, layout)
		return Features.sync_inventory_sort_setting(mod, layout)
	end,
})
scenegraph_rect = armoury_panel.scenegraph_rect

local function panel_item_sorting_option_entry(view, option, option_index)
	local geometry = view._better_inventory_options_panel_geometry

	return panel_entry(view, "better_inventory_item_sorting_option_" .. tostring(option_index), 32, armoury_native_sort_option_passes(geometry.content_width), {
		hotspot = {},
		label = option.display_name or tostring(option_index),
		selected = (view._selected_sort_option_index or 1) == option_index,
	}, function(widget)
		widget.content.hotspot.pressed_callback = function()
			local item_grid = view._item_grid

			if item_grid and type(item_grid.trigger_sort_index) == "function" then
				item_grid:trigger_sort_index(option_index)
			elseif type(view.cb_on_sort_button_pressed) == "function" then
				view:cb_on_sort_button_pressed(option)
			end
		end
	end, function(widget)
		widget.content.selected = (view._selected_sort_option_index or 1) == option_index
	end, { "hotspot" })
end

local function panel_type_entry(mod, layout, view)
	local geometry = view._better_inventory_options_panel_geometry
	local settings = {
		{
			content_id = "melee",
			label_id = "quick_discard_inventory_melee",
			setting_id = "quick_discard_include_melee",
		},
		{
			content_id = "ranged",
			label_id = "quick_discard_inventory_ranged",
			setting_id = "quick_discard_include_ranged",
		},
		{
			content_id = "curio",
			label_id = "quick_discard_inventory_curios",
			setting_id = "quick_discard_include_curios",
		},
	}
	local content = {}

	for index = 1, #settings do
		local config = settings[index]

		content[config.content_id .. "_checked"] = mod:get(config.setting_id) ~= false
		content[config.content_id .. "_label"] = mod:localize(config.label_id)
	end

	return panel_entry(view, "better_inventory_discard_types", 34, panel_type_checkbox_passes(geometry.content_width), content, function(widget)
		for index = 1, #settings do
			local config = settings[index]
			local hotspot = widget.content[config.content_id .. "_hotspot"]
			local checked_id = config.content_id .. "_checked"
			local setting_id = config.setting_id

			hotspot.pressed_callback = function()
				local enabled = not widget.content[checked_id]

				widget.content[checked_id] = enabled
				mod:set(setting_id, enabled, false)
				Features.sync_quick_discard_settings(mod, layout)
			end
		end
	end, function(widget)
		for index = 1, #settings do
			local config = settings[index]

			widget.content[config.content_id .. "_checked"] = mod:get(config.setting_id) ~= false
		end
	end, { "melee_hotspot", "ranged_hotspot", "curio_hotspot" })
end

local function panel_curio_protection_type_entry(mod, layout, view)
	local geometry = view._better_inventory_options_panel_geometry
	local settings = {
		{
			content_id = "health",
			label_id = "quick_discard_inventory_keep_health_curios",
			setting_id = "quick_discard_keep_health_curios",
		},
		{
			content_id = "toughness",
			label_id = "quick_discard_inventory_keep_toughness_curios",
			setting_id = "quick_discard_keep_toughness_curios",
		},
		{
			content_id = "wounds",
			label_id = "quick_discard_inventory_keep_wound_curios",
			setting_id = "quick_discard_keep_wound_curios",
		},
		{
			content_id = "stamina",
			label_id = "quick_discard_inventory_keep_stamina_curios",
			setting_id = "quick_discard_keep_stamina_curios",
		},
	}
	local content = {}
	local passes = {}
	local gap = 6
	local width = math.floor((geometry.content_width - gap * 3) / 4)

	for index = 1, #settings do
		local config = settings[index]
		local x = (width + gap) * (index - 1)

		content[config.content_id .. "_checked"] = mod:get(config.setting_id) ~= false
		content[config.content_id .. "_label"] = mod:localize(config.label_id)
		append_panel_checkbox_passes(passes, config.content_id, x, width, config.content_id .. "_checked", config.content_id .. "_label")
	end

	return panel_entry(view, "better_inventory_discard_curio_types", 34, passes, content, function(widget)
		for index = 1, #settings do
			local config = settings[index]
			local hotspot = widget.content[config.content_id .. "_hotspot"]
			local checked_id = config.content_id .. "_checked"

			hotspot.pressed_callback = function()
				local enabled = not widget.content[checked_id]

				widget.content[checked_id] = enabled
				mod:set(config.setting_id, enabled, false)
				Features.sync_quick_discard_settings(mod, layout)
			end
		end
	end, function(widget)
		for index = 1, #settings do
			local config = settings[index]

			widget.content[config.content_id .. "_checked"] = mod:get(config.setting_id) ~= false
		end
	end, { "health_hotspot", "toughness_hotspot", "wounds_hotspot", "stamina_hotspot" })
end

local function panel_checkbox_group_entry(mod, layout, view, control_id, settings)
	local geometry = view._better_inventory_options_panel_geometry
	local content = {}
	local passes = {}
	local controller_targets = {}
	local gap = 6
	local width = math.floor((geometry.content_width - gap * math.max(#settings - 1, 0)) / math.max(#settings, 1))

	local function is_enabled(config)
		local value = mod:get(config.setting_id)

		if value == nil then
			return config.default_enabled ~= false
		end

		return value == true
	end

	for index = 1, #settings do
		local config = settings[index]
		local x = (width + gap) * (index - 1)

		content[config.content_id .. "_checked"] = is_enabled(config)
		content[config.content_id .. "_label"] = mod:localize(config.label_id)
		controller_targets[#controller_targets + 1] = config.content_id .. "_hotspot"
		append_panel_checkbox_passes(passes, config.content_id, x, width, config.content_id .. "_checked", config.content_id .. "_label")
	end

	return panel_entry(view, control_id, 34, passes, content, function(widget)
		for index = 1, #settings do
			local config = settings[index]
			local hotspot = widget.content[config.content_id .. "_hotspot"]
			local checked_id = config.content_id .. "_checked"

			hotspot.pressed_callback = function()
				local value = not widget.content[checked_id]

				widget.content[checked_id] = value
				mod:set(config.setting_id, value, false)
				Features.sync_curio_acquisition_settings(mod, layout, view)
			end
		end
	end, function(widget)
		for index = 1, #settings do
			local config = settings[index]

			widget.content[config.content_id .. "_checked"] = is_enabled(config)
		end
	end, controller_targets)
end

local function panel_curio_buyer_type_entry(mod, layout, view)
	return panel_checkbox_group_entry(mod, layout, view, "better_inventory_curio_buyer_types", {
		{
			content_id = "health",
			default_enabled = true,
			label_id = "automatic_curio_buy_health",
			setting_id = "automatic_curio_buy_health",
		},
		{
			content_id = "toughness",
			default_enabled = true,
			label_id = "automatic_curio_buy_toughness",
			setting_id = "automatic_curio_buy_toughness",
		},
		{
			content_id = "stamina",
			default_enabled = false,
			label_id = "automatic_curio_buy_stamina",
			setting_id = "automatic_curio_buy_stamina",
		},
		{
			content_id = "wounds",
			default_enabled = false,
			label_id = "automatic_curio_buy_wounds",
			setting_id = "automatic_curio_buy_wounds",
		},
	})
end

local function panel_curio_buyer_class_entry(mod, layout, view, row)
	local settings = row == 1 and {
		{
			content_id = "veteran",
			label_id = "automatic_curio_class_veteran",
			setting_id = "automatic_curio_class_veteran",
		},
		{
			content_id = "zealot",
			label_id = "automatic_curio_class_zealot",
			setting_id = "automatic_curio_class_zealot",
		},
		{
			content_id = "psyker",
			label_id = "automatic_curio_class_psyker",
			setting_id = "automatic_curio_class_psyker",
		},
		{
			content_id = "ogryn",
			label_id = "automatic_curio_class_ogryn",
			setting_id = "automatic_curio_class_ogryn",
		},
	} or {
		{
			content_id = "adamant",
			label_id = "automatic_curio_class_adamant",
			setting_id = "automatic_curio_class_adamant",
		},
		{
			content_id = "broker",
			label_id = "automatic_curio_class_broker",
			setting_id = "automatic_curio_class_broker",
		},
		{
			content_id = "cryptic",
			label_id = "automatic_curio_class_cryptic",
			setting_id = "automatic_curio_class_cryptic",
		},
	}

	return panel_checkbox_group_entry(mod, layout, view, "better_inventory_curio_buyer_classes_" .. row, settings)
end

local function character_profile_label(profile, profiles)
	local label = profile.character_name and string.format("%s(%s)", profile.character_name, profile.class_name) or profile.class_name
	local duplicate_count = 0

	for index = 1, #profiles do
		local other = profiles[index]
		local other_label = other.character_name and string.format("%s(%s)", other.character_name, other.class_name) or other.class_name

		if other_label == label then
			duplicate_count = duplicate_count + 1
		end
	end

	return duplicate_count > 1 and string.format("%s [%s]", label, string.sub(tostring(profile.character_id), -6)) or label
end

local function panel_curio_buyer_character_entry(mod, layout, view, profiles, first_index)
	local geometry = view._better_inventory_options_panel_geometry
	local content = {}
	local passes = {}
	local settings = {}
	local controller_targets = {}
	local last_index = math.min(first_index + 1, #profiles)
	local gap = 6
	local width = math.floor((geometry.content_width - gap * (last_index - first_index)) / (last_index - first_index + 1))

	for profile_index = first_index, last_index do
		local profile = profiles[profile_index]
		local content_id = "character_" .. tostring(profile_index - first_index + 1)
		local x = (width + gap) * (profile_index - first_index)

		settings[#settings + 1] = {
			character_id = profile.character_id,
			content_id = content_id,
		}
		content[content_id .. "_checked"] = curio_acquisition_provider.character_is_enabled(mod, profile.character_id)
		content[content_id .. "_label"] = character_profile_label(profile, profiles)
		controller_targets[#controller_targets + 1] = content_id .. "_hotspot"
		append_panel_checkbox_passes(passes, content_id, x, width, content_id .. "_checked", content_id .. "_label")
	end

	return panel_entry(view, "better_inventory_curio_buyer_characters_" .. tostring(first_index), 34, passes, content, function(widget)
		for index = 1, #settings do
			local config = settings[index]
			local checked_id = config.content_id .. "_checked"

			widget.content[config.content_id .. "_hotspot"].pressed_callback = function()
				local enabled = not curio_acquisition_provider.character_is_enabled(mod, config.character_id)

				widget.content[checked_id] = enabled
				curio_acquisition_provider.set_character_enabled(mod, config.character_id, enabled)
				Features.sync_curio_acquisition_settings(mod, layout, view)
			end
		end
	end, function(widget)
		for index = 1, #settings do
			local config = settings[index]

			widget.content[config.content_id .. "_checked"] = curio_acquisition_provider.character_is_enabled(mod, config.character_id)
		end
	end, controller_targets)
end

PanelState.configure({
	composite_key = Features._domains.panels.composite_key,
	curio_buyer_profile_revision = curio_buyer_profile_revision,
	item_sorting_is_enabled = item_sorting_is_enabled,
	item_sorting_options_signature = item_sorting_options_signature,
})

Features.lantern_recommendations_active = function()
	return Lantern.lantern_recommendations_active()
end

Features.should_host_lantern_panel = function(view)
	return Lantern.should_host_lantern_panel(view)
end

Features.set_lantern_integration = function(_, integration_mod)
	return Lantern.set_lantern_integration(_, integration_mod)
end

Features.set_item_sorting_integration = function(integration_mod)
	return Features._sorting.set_integration(integration_mod, Features.invalidate_all_view_composition)
end

Features.preserve_item_sorting_native_options = function(view, selected_display_name)
	return Features._sorting.preserve_native_options(view, selected_display_name, is_armoury_sort_view, Features.invalidate_view_composition)
end

Features.release_lantern_inventory_section = function(view)
	return Lantern.release_lantern_inventory_section(view)
end

Features.update_lantern_inventory_section = function(mod, view)
	return Lantern.update_lantern_inventory_section(mod, view)
end

rebuild_inventory_options_panel = function(mod, layout, view)
	local panel = view._better_inventory_options_panel

	if not panel or view._destroyed then
		return
	end

	Features.count_diagnostic("panel_rebuilds")

	local collapsed = view._better_inventory_options_panel_collapsed
	local native_discard_active = view._discard_items_element ~= nil
	local quick_discard_enabled = mod:get("enable_experimental_quick_discard") == true
	local entries = {}

	if view._better_inventory_lantern_panel_available == true then
		local lantern_entry = panel_lantern_entry(view)

		if lantern_entry then
			entries[#entries + 1] = lantern_entry
		end
	end

	entries[#entries + 1] = panel_header_entry(mod, layout, view, "better_inventory_sort_header", "sorting", function()
			return mod:localize("inventory_sorting_inventory_label")
		end)

	if not collapsed.sorting then
		entries[#entries + 1] = panel_sort_entry(mod, layout, view)
		entries[#entries + 1] = panel_perfect_sort_entry(mod, layout, view)
	end

	if item_sorting_is_enabled() then
		entries[#entries + 1] = panel_header_entry(mod, layout, view, "better_inventory_item_sorting_header", "item_sorting", function()
			return mod:localize("item_sorting_mod_header")
		end)

		if not collapsed.item_sorting then
			local sort_options = view._sort_options or {}
			local first_custom_option = item_sorting_custom_option_start(view)

			for option_index = first_custom_option, #sort_options do
				entries[#entries + 1] = panel_item_sorting_option_entry(view, sort_options[option_index], option_index)
			end
		end
	end

	if native_discard_active then
		local sort_options = view._sort_options or {}
		local last_native_option = item_sorting_custom_option_start(view) - 1

		if last_native_option > 0 then
			entries[#entries + 1] = panel_header_entry(mod, layout, view, "better_inventory_native_sorting_header", "native_sorting", function()
				return mod:localize("armoury_native_sorting_header")
			end)

			if not collapsed.native_sorting then
				for option_index = 1, math.min(last_native_option, #sort_options) do
					entries[#entries + 1] = panel_item_sorting_option_entry(view, sort_options[option_index], option_index)
				end
			end
		end
	end

	if quick_discard_enabled and not native_discard_active then
		entries[#entries + 1] = panel_header_entry(mod, layout, view, "better_inventory_discard_header", "discard", function()
			local mode = mod:get("quick_discard_mode") == "automatic" and "automated" or "manual"

			return mod:localize("inventory_" .. mode .. "_discard_management_inventory_label")
		end)

		if not collapsed.discard then
			entries[#entries + 1] = panel_mode_entry(mod, layout, view)

			if mod:get("quick_discard_mode") == "automatic" then
				entries[#entries + 1] = panel_checkbox_entry(mod, layout, view, INVENTORY_DISCARD_SKIP_CONFIRMATION_ID, "quick_discard_skip_automatic_confirmation", "quick_discard_skip_automatic_confirmation", false)
			end

			entries[#entries + 1] = panel_quick_discard_entry(mod, layout, view)
			entries[#entries + 1] = panel_sub_label_entry(mod, view, "better_inventory_discard_item_types_label", "quick_discard_inventory_item_types_label")
			entries[#entries + 1] = panel_type_entry(mod, layout, view)
			entries[#entries + 1] = panel_stepper_entry(mod, layout, view, INVENTORY_DISCARD_MAX_LEVEL_ID, "quick_discard_max_item_level", "quick_discard_inventory_max_level", 490)
			entries[#entries + 1] = panel_checkbox_entry(mod, layout, view, INVENTORY_DISCARD_EQUIPPED_LEVEL_PROTECTION_ID, "quick_discard_protect_above_equipped_level", "quick_discard_inventory_protect_above_equipped_level")
			entries[#entries + 1] = panel_checkbox_entry(mod, layout, view, INVENTORY_DISCARD_PROTECTION_ID, "quick_discard_protect_perfect_weapons", "quick_discard_inventory_protect_weapons")
			entries[#entries + 1] = panel_checkbox_entry(mod, layout, view, INVENTORY_DISCARD_CURIO_PROTECTION_ID, "quick_discard_protect_high_level_curios", "quick_discard_inventory_protect_curios", nil, true)

			if mod:get("quick_discard_protect_high_level_curios") ~= false then
				entries[#entries + 1] = panel_stepper_entry(mod, layout, view, INVENTORY_DISCARD_CURIO_LEVEL_ID, "quick_discard_curio_protection_level", "quick_discard_inventory_curio_level", 410)
			end

			entries[#entries + 1] = panel_sub_label_entry(mod, view, "better_inventory_discard_curio_types_label", "quick_discard_inventory_keep_curio_types_label")
			entries[#entries + 1] = panel_curio_protection_type_entry(mod, layout, view)
		end
	end
	if not native_discard_active then
		entries[#entries + 1] = panel_header_entry(mod, layout, view, "better_inventory_curio_buyer_header", "curio_buyer", function()
			return mod:localize("automatic_curio_buyer_inventory_label")
		end)

		if not collapsed.curio_buyer then
			entries[#entries + 1] = panel_checkbox_entry(mod, layout, view, INVENTORY_CURIO_BUYER_ENABLE_ID, "enable_automatic_curio_acquisition", "enable_automatic_curio_acquisition", false, true, Features.sync_curio_acquisition_settings)

			if mod:get("enable_automatic_curio_acquisition") == true then
				entries[#entries + 1] = panel_checkbox_entry(mod, layout, view, INVENTORY_CURIO_BUYER_OPERATIVE_SELECTION_ID, "automatic_curio_scan_operative_selection", "automatic_curio_scan_operative_selection", false, true, Features.sync_curio_acquisition_settings)
				entries[#entries + 1] = panel_checkbox_entry(mod, layout, view, INVENTORY_CURIO_BUYER_ROTATION_ID, "automatic_curio_once_per_store_rotation", "automatic_curio_once_per_store_rotation", false, true, Features.sync_curio_acquisition_settings)
				entries[#entries + 1] = panel_checkbox_entry(mod, layout, view, INVENTORY_CURIO_BUYER_REFRESH_ID, "automatic_curio_rescan_on_store_refresh", "automatic_curio_rescan_on_store_refresh", false, true, Features.sync_curio_acquisition_settings)
				entries[#entries + 1] = panel_stepper_entry(mod, layout, view, INVENTORY_CURIO_BUYER_MIN_LEVEL_ID, "automatic_curio_min_item_level", "automatic_curio_min_item_level", 410, Features.sync_curio_acquisition_settings)
				entries[#entries + 1] = panel_sub_label_entry(mod, view, "better_inventory_curio_buyer_types_label", "automatic_curio_types_inventory_label")
				entries[#entries + 1] = panel_curio_buyer_type_entry(mod, layout, view)

				if mod:get("automatic_curio_buy_health") ~= false then
					entries[#entries + 1] = panel_stepper_entry(mod, layout, view, INVENTORY_CURIO_BUYER_MIN_HEALTH_ID, "automatic_curio_min_health", "automatic_curio_min_health", 21, Features.sync_curio_acquisition_settings, 0, 21, 1, "%")
				end

				if mod:get("automatic_curio_buy_toughness") ~= false then
					entries[#entries + 1] = panel_stepper_entry(mod, layout, view, INVENTORY_CURIO_BUYER_MIN_TOUGHNESS_ID, "automatic_curio_min_toughness", "automatic_curio_min_toughness", 17, Features.sync_curio_acquisition_settings, 0, 17, 1, "%")
				end

				entries[#entries + 1] = panel_curio_buyer_target_mode_entry(mod, layout, view)

				if mod:get("automatic_curio_target_mode") == "characters" then
					local profiles = known_curio_buyer_profiles(mod)

					if #profiles == 0 then
						entries[#entries + 1] = panel_sub_label_entry(mod, view, "better_inventory_curio_buyer_characters_discovering", "automatic_curio_characters_discovering_inventory")
					else
						for first_index = 1, #profiles, 2 do
							entries[#entries + 1] = panel_curio_buyer_character_entry(mod, layout, view, profiles, first_index)
						end
					end
				else
					entries[#entries + 1] = panel_curio_buyer_class_entry(mod, layout, view, 1)
					entries[#entries + 1] = panel_curio_buyer_class_entry(mod, layout, view, 2)
				end
			end
		end
	end

	local geometry = view._better_inventory_options_panel_geometry
	local spacing = geometry.row_spacing
	local content_height = 0

	for index = 1, #entries do
		content_height = content_height + entries[index].size[2]
	end

	content_height = content_height + math.max(#entries - 1, 0) * spacing

	-- ViewElementGrid adds a 31 px terminal-divider/frame overhead around the
	-- content. Account for it explicitly so user padding maps predictably.
	local panel_height = math.clamp(content_height + 31 + geometry.top + geometry.bottom, INVENTORY_OPTIONS_PANEL_MIN_HEIGHT, geometry.max_height)

	view._better_inventory_options_panel_widgets = {}
	view._better_inventory_lantern_section_widget = nil
	view._better_inventory_lantern_panel_hosted = false
	view._better_inventory_options_panel_structure_key = PanelState.panel_structure_key(mod, view)
	view._better_inventory_options_panel_height = panel_height
	panel:update_grid_height(panel_height, panel_height)
	panel:present_grid_layout(entries, INVENTORY_OPTIONS_PANEL_BLUEPRINTS)
end

-- The stock Curio header reserves 250 virtual pixels for one small item image.
-- Scale the whole preview box rather than shortening only its height; changing
-- one axis was the reason Curio art appeared stretched in the prototype.
-- This transforms only the current InventoryWeaponsView's Curio stats blueprint;
-- crafting, vendors and weapon detail cards keep their native geometry.
Features.compact_inventory_curio_stats_blueprints = function(mod, item_grid, content_blueprints)
	if mod:get("enable_inventory_options_panel_prototype") ~= true or type(content_blueprints) ~= "table" then
		return content_blueprints
	end

	local parent = item_grid and item_grid._parent
	local item = item_grid and item_grid._item
	local gadget_header = content_blueprints.gadget_header

	if not parent or parent.__class_name ~= "InventoryWeaponsView" or parent._weapon_stats ~= item_grid or not item or item.item_type ~= "GADGET" or type(gadget_header) ~= "table" or type(gadget_header.size) ~= "table" or type(gadget_header.size[1]) ~= "number" or type(gadget_header.size[2]) ~= "number" then
		return content_blueprints
	end

	local adjusted_blueprints = PanelState.shallow_copy(content_blueprints)
	local adjusted_header = table.clone(gadget_header)

	adjusted_blueprints.gadget_header = adjusted_header
	local height_percent = numeric_setting(mod, "curio_preview_height_percent", 76, 60, 100)
	local scale = height_percent / 100

	adjusted_header.size[2] = math.floor(INVENTORY_CURIO_NATIVE_HEADER_HEIGHT * scale + 0.5)

	for index = 1, #(adjusted_header.pass_template or {}) do
		local pass = adjusted_header.pass_template[index]
		local style = pass and pass.style

		if style and pass.style_id == "icon" and type(style.size) == "table" and type(style.offset) == "table" then
			local native_icon_width = INVENTORY_CURIO_NATIVE_GRID_WIDTH * 0.9
			local available_icon_width = (adjusted_header.size[1] or INVENTORY_CURIO_NATIVE_GRID_WIDTH) * 0.9
			local icon_scale = math.min(scale, available_icon_width / native_icon_width)

			style.size[1] = math.floor(native_icon_width * icon_scale + 0.5)
			style.size[2] = math.floor(INVENTORY_CURIO_NATIVE_ICON_HEIGHT * icon_scale + 0.5)
			style.offset[2] = math.floor((style.offset[2] or 0) * scale + 0.5)
		elseif style and pass.style_id == "loading" and type(style.size) == "table" then
			style.size[1] = math.floor((style.size[1] or 0) * scale + 0.5)
			style.size[2] = math.floor((style.size[2] or 0) * scale + 0.5)
		elseif style and pass.style_id == "gradient_background" and type(style.size) == "table" then
			style.size[2] = math.floor((style.size[2] or 0) * scale + 0.5)
		end
	end

	return adjusted_blueprints
end

Features.release_inventory_options_panel = PanelRuntime.release_inventory_options_panel

Features.setup_inventory_options_panel = function(mod, layout, view, ViewElementGrid)
	if mod:get("enable_inventory_options_panel_prototype") ~= true or not is_inventory_view(layout, view) or view._better_inventory_options_panel then
		return false
	end

	if type(ViewElementGrid) ~= "table" or type(view._add_element) ~= "function" then
		return false
	end

	local geometry = inventory_options_panel_geometry(mod)
	local menu_settings = {
		bottom_chin = geometry.bottom,
		edge_padding = geometry.left + geometry.right,
		enable_gamepad_scrolling = true,
		grid_size = {
			geometry.content_width,
			geometry.max_height,
		},
		grid_spacing = {
			0,
			geometry.row_spacing,
		},
		ignore_blur = true,
		mask_size = {
			geometry.width,
			geometry.max_height,
		},
		reset_selection_on_navigation_change = false,
		scrollbar_width = 7,
		title_height = 0,
		top_padding = geometry.top,
		use_is_focused_for_navigation = false,
		use_select_on_focused = true,
		use_terminal_background = true,
	}
	local success, panel = pcall(view._add_element, view, ViewElementGrid, INVENTORY_OPTIONS_PANEL_REFERENCE, 25, menu_settings)

	if not success or not panel then
		if type(mod.error) == "function" then
			mod:error("BetterInventory options-panel prototype could not initialize: " .. tostring(panel))
		end

		if type(view._remove_element) == "function" then
			pcall(view._remove_element, view, INVENTORY_OPTIONS_PANEL_REFERENCE)
		end

		return false
	end

	view._better_inventory_options_panel = panel
	view._better_inventory_options_panel_geometry = geometry
	view._better_inventory_options_panel_mod = mod
	view._better_inventory_options_panel_collapsed = {
		curio_buyer = false,
		discard = false,
		item_sorting = false,
		native_sorting = false,
		sorting = false,
	}

	local configured, configure_error = pcall(function()
		local content_pivot = panel._ui_scenegraph and panel._ui_scenegraph.grid_content_pivot

		if content_pivot and content_pivot.position then
			content_pivot.position[1] = geometry.left
		end

		panel:disable_input(false)
		panel:set_visibility(true)
		view._better_inventory_options_panel_visible = true
		rebuild_inventory_options_panel(mod, layout, view)
	end)

	if not configured then
		view._better_inventory_options_panel = nil
		view._better_inventory_options_panel_geometry = nil
		view._better_inventory_options_panel_mod = nil
		view._better_inventory_options_panel_widgets = nil
		view._better_inventory_options_panel_collapsed = nil
		view._better_inventory_options_panel_visible = nil

		if type(view._remove_element) == "function" then
			pcall(view._remove_element, view, INVENTORY_OPTIONS_PANEL_REFERENCE)
		end

		if type(mod.error) == "function" then
			mod:error("BetterInventory options-panel prototype could not be configured: " .. tostring(configure_error))
		end

		return false
	end

	return true
end

Features.capture_inventory_options_panel_controller_focus = function(mod, layout, view, input_service)
	if not view or not is_inventory_view(layout, view) then
		return false
	end

	local focused = view._better_inventory_options_panel_controller_focused == true
	local panel_available = mod:get("enable_inventory_options_panel_prototype") == true and mod:get("show_inventory_options_widget") ~= false and view._better_inventory_options_panel_visible == true and view._better_inventory_options_panel and view._better_inventory_options_panel._visible ~= false

	if view._using_cursor_navigation ~= false or not panel_available then
		if focused then
			set_inventory_options_panel_controller_focus(view, false)
		end

		return false
	end

	local focus_action = mod:get("inventory_options_controller_focus_keybind")

	if focus_action and focus_action ~= "off" and input_service and type(input_service.get) == "function" and input_service:get(focus_action) then
		focused = set_inventory_options_panel_controller_focus(view, not focused)
	end

	if focused then
		-- Native inventory code may revisit its own focus state after previews or
		-- discard-mode changes. Keep the custom panel as the sole controller owner.
		for _, element in pairs({ view._item_grid, view._weapon_options_element, view._discard_items_element }) do
			if element and type(element.disable_input) == "function" then
				element:disable_input(true)
			end
		end

		local panel = view._better_inventory_options_panel

		if panel and type(panel.selected_grid_index) == "function" and not panel:selected_grid_index() and type(panel.select_first_index) == "function" then
			panel:select_first_index()
		end
	end

	return focused
end

Features.update_inventory_options_panel_controller_selection = function(view, input_service)
	if not view or view._better_inventory_options_panel_controller_focused ~= true then
		return false
	end

	local panel = view._better_inventory_options_panel
	local selected_widget = panel and type(panel.selected_grid_widget) == "function" and panel:selected_grid_widget()
	local entry = selected_widget and selected_widget.content and selected_widget.content.entry
	local targets = entry and entry.controller_targets

	for _, widget in pairs(view._better_inventory_options_panel_widgets or {}) do
		local widget_entry = widget.content and widget.content.entry

		for _, target_id in ipairs(widget_entry and widget_entry.controller_targets or {}) do
			local hotspot = widget.content[target_id]

			if hotspot and target_id ~= "hotspot" then
				hotspot.is_focused = false
				hotspot.is_selected = false
			end
		end
	end

	if type(targets) ~= "table" or #targets == 0 then
		return false
	end

	local target_state = view._better_inventory_options_panel_controller_target

	if not target_state or target_state.control_id ~= entry.control_id then
		target_state = {
			control_id = entry.control_id,
			index = 1,
		}
		view._better_inventory_options_panel_controller_target = target_state
	end

	if #targets > 1 and input_service and type(input_service.get) == "function" then
		if input_service:get("navigate_left_continuous") then
			target_state.index = math.max(target_state.index - 1, 1)
		elseif input_service:get("navigate_right_continuous") then
			target_state.index = math.min(target_state.index + 1, #targets)
		end
	end

	target_state.index = math.clamp(target_state.index, 1, #targets)
	local target_hotspot = selected_widget.content[targets[target_state.index]]

	if target_hotspot and targets[target_state.index] ~= "hotspot" then
		target_hotspot.is_focused = true
		target_hotspot.is_selected = true
	end

	return true
end

Features.inventory_options_panel_controller_focused = function(view)
	return view and view._better_inventory_options_panel_controller_focused == true
end

local set_armoury_controller_focus = function(view, focused)
	if armoury_panel then
		return armoury_panel.set_focus(view, focused)
	end

	return false
end

Features.capture_armoury_sort_panel_controller_focus = function(mod, view, input_service)
	if armoury_panel then
		return armoury_panel.capture(mod, view, input_service)
	end

	return false
end

Features.armoury_sort_panel_controller_focused = function(view)
	return armoury_panel and armoury_panel.focused(view) or false
end

Features.update_armoury_native_sort_panel = function(view)
	if armoury_panel then
		return armoury_panel.update(view)
	end

	return false
end

Features.setup_armoury_native_sort_panel = function(mod, layout, view, ViewElementGrid)
	if armoury_panel then
		return armoury_panel.setup(mod, layout, view, ViewElementGrid)
	end

	return false
end


local sort_comparator_manager

Features.restore_sort_options = function(view)
	if sort_comparator_manager then
		return sort_comparator_manager.restore(view)
	end
end

Features.configure_inventory_sort_options = function(mod, layout, view)
	if sort_comparator_manager then
		return sort_comparator_manager.configure_inventory(mod, layout, view)
	end
end

Features.configure_armoury_sort_options = function(mod, view)
	if sort_comparator_manager then
		return sort_comparator_manager.configure_armoury(mod, view)
	end
end

Features.configure_global_store_sort_options = function(mod, view)
	if sort_comparator_manager then
		return sort_comparator_manager.configure_global_store(mod, view)
	end
end

Features.rebind_sort_options = function(mod, layout)
	if sort_comparator_manager then
		return sort_comparator_manager.rebind(mod, layout)
	end
end

Features.resort_inventory = function(mod, layout, view)
	if sort_comparator_manager then
		return sort_comparator_manager.resort(mod, layout, view)
	end
end

local function preview_profile_for_discard(view)
	local player = view and view._preview_player

	if player and not player.__deleted and type(player.profile) == "function" then
		local success, profile = pcall(player.profile, player)

		if success then
			return profile
		end
	end
end

Features.is_perfect_roll_weapon = DiscardPolicy.is_perfect_roll_weapon
sort_comparator_manager = Features._sorting.new_comparator_manager({
	begin_view_session = Features.begin_view_session,
	contracts = Features._contracts,
	is_armoury_requisition_view = is_armoury_requisition_view,
	is_armoury_sort_view = is_armoury_sort_view,
	is_global_store_view = is_global_store_view,
	is_inventory_view = is_inventory_view,
	is_perfect_roll_weapon = function(item)
		return Features.is_perfect_roll_weapon(item)
	end,
	is_sortable_view = is_sortable_view,
	register_view_session_cleanup = Features.register_view_session_cleanup,
})
Features._registered_sort_views = sort_comparator_manager.registered_views
Features.automatic_curio_acquisition_protects = DiscardPolicy.automatic_curio_acquisition_protects
Features.quick_discard_candidates_from_items = DiscardPolicy.quick_discard_candidates_from_items
local quick_discard_candidates_from_items_detailed = DiscardPolicy.quick_discard_candidates_from_items_detailed

Features.quick_discard_candidates = function(mod, layout, view, allowed_gear_ids)
	if not is_inventory_view(layout, view) or view._destroyed then
		return {}
	end

	local parent_inventory = view._parent and view._parent._inventory_items
	local source_items = type(parent_inventory) == "table" and next(parent_inventory) and parent_inventory or view._offer_items_layout or {}
	local presets_ok, profile_presets = pcall(ProfileUtils.get_profile_presets)
	local protected_gear_ids = DiscardPolicy.equipped_gear_ids(preview_profile_for_discard(view), presets_ok and profile_presets or nil)
	local function is_equipped(item)
		if item.gear_id and protected_gear_ids[item.gear_id] then
			return true
		end

		local slots = item.slots

		return slots and type(view.is_item_equipped_in_any_slot) == "function" and view:is_item_equipped_in_any_slot(item, slots) or false
	end

	local candidates = DiscardPolicy.quick_discard_candidates_from_source(mod, source_items, is_equipped, protected_gear_ids, allowed_gear_ids)

	return candidates
end

local function summary_type_name(mod, count, singular_id, plural_id)
	return DiscardSummary.summary_type_name(mod, count, singular_id, plural_id)
end

local function rarity_summary(mod, candidates)
	return DiscardSummary.rarity_summary(mod, candidates)
end

local function discarded_rarity_summary(mod, candidates)
	local counts = {}
	local lines = {}

	for index = 1, #(candidates or {}) do
		local rarity = tonumber(candidates[index] and candidates[index].rarity)

		if rarity then
			counts[rarity] = (counts[rarity] or 0) + 1
		end
	end

	for rarity = 1, 5 do
		local count = counts[rarity]

		if count and count > 0 then
			local settings = RaritySettings[rarity]
			local color = settings and settings.color or Color.white(255, true)
			local name = settings and Localize(settings.display_name) or tostring(rarity)

			lines[#lines + 1] = string.format("{#color(%d,%d,%d)}- %d %s %s{#reset()}", color[2], color[3], color[4], count, name, mod:localize("quick_discard_notification_items"))
		end
	end

	return table.concat(lines, "\n")
end

local function show_discard_summary_notification(mod, candidates)
	if mod:get("quick_discard_show_summary_notification") == false or #(candidates or {}) == 0 then
		return
	end

	local event_manager = Managers and Managers.event

	if not event_manager or type(event_manager.trigger) ~= "function" then
		return
	end

	pcall(event_manager.trigger, event_manager, "event_add_notification_message", "custom", {
		line_1 = mod:localize("quick_discard_notification_title"),
		line_1_color = Color.terminal_text_header(255, true),
		line_2 = discarded_rarity_summary(mod, candidates),
		line_2_color = Color.white(255, true),
	})
end

local function show_automatic_no_candidates_notification(mod)
	if mod:get("quick_discard_disable_no_eligible_notification") == true then
		return false
	end

	local event_manager = Managers and Managers.event

	if not event_manager or type(event_manager.trigger) ~= "function" then
		return false
	end

	pcall(event_manager.trigger, event_manager, "event_add_notification_message", "custom", {
		line_1 = mod:localize("quick_discard_automatic_nothing_notification_title"),
		line_1_color = Color.terminal_text_header(255, true),
		line_2 = mod:localize("quick_discard_automatic_nothing_notification_description"),
		line_2_color = Color.white(255, true),
	})

	return true
end

local function show_popup(context, callback)
	local event_manager = Managers and Managers.event

	if not event_manager or type(event_manager.trigger) ~= "function" then
		return false
	end

	return pcall(event_manager.trigger, event_manager, "event_show_ui_popup", context, callback)
end

local DiscardTransaction = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_discard_transaction")
local discard_transaction = DiscardTransaction.new(Features._operation_arbiter, {
	collect_candidates = function(mod, layout, view, allowed_gear_ids)
		return Features.quick_discard_candidates(mod, layout, view, allowed_gear_ids)
	end,
	rarity_summary = rarity_summary,
})

Features.discard_owner = function()
	return discard_transaction:active_owner()
end

Features.discard_view = function()
	return discard_transaction:active_view()
end

Features.discard_token = function()
	return discard_transaction:active_token()
end

local function acquire_discard_transaction(owner, view)
	return discard_transaction:acquire(owner, view)
end

Features.acquire_account_operation = function(owner, view)
	return acquire_discard_transaction(owner, view)
end

Features.remove_discard_popup = function(popup_id)
	return discard_transaction:remove_popup(popup_id)
end

Features.set_discard_popup_id = function(owner, token, popup_id)
	return discard_transaction:set_popup(owner, token, popup_id)
end

Features.clear_discard_popup = function(owner, token)
	return discard_transaction:clear_popup(owner, token)
end

local function release_discard_transaction(owner, token)
	local released = discard_transaction:release(owner, token)

	return released == true
end

Features.release_account_operation = function(owner, token)
	return release_discard_transaction(owner, token)
end

-- GearService settlement is observed by the main-module bridge. This module
-- only owns the promise callback and releases the matching transaction token.
Features.observe_manual_discard_settlement = function(promise)
	return discard_transaction:observe_manual_settlement(promise)
end

Features.manual_discard_settlement_active = function()
	return discard_transaction:manual_settlement_active()
end

local function discard_transaction_is_current(owner, token)
	return discard_transaction:is_current(owner, token)
end

Features.account_operation_is_current = function(owner, token)
	return discard_transaction_is_current(owner, token)
end

Features.discard_popup_is_active = function(popup_id)
	return discard_transaction:popup_is_active(popup_id)
end

Features.reconcile_discard_transaction = function()
	return discard_transaction:reconcile()
end
Features.request_quick_discard = function(mod, layout, view)
	return discard_transaction:request_manual(mod, layout, view)
end

local AutomaticDiscard = get_mod("BetterInventory"):io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_discard_automatic")
local automatic_discard = AutomaticDiscard.new(discard_transaction, {
	candidates_from_items = function(mod, items, equipped_gear_ids, allowed_gear_ids, favorite_gear_ids)
		return Features.quick_discard_candidates_from_items(mod, items, equipped_gear_ids, allowed_gear_ids, favorite_gear_ids)
	end,
	candidates_from_items_detailed = function(mod, items, equipped_gear_ids, allowed_gear_ids, favorite_gear_ids)
		return quick_discard_candidates_from_items_detailed(mod, items, equipped_gear_ids, allowed_gear_ids, favorite_gear_ids)
	end,
	policy = DiscardPolicy,
	rarity_summary = rarity_summary,
	show_discard_summary_notification = show_discard_summary_notification,
	show_no_candidates_notification = show_automatic_no_candidates_notification,
	show_popup = show_popup,
})

Features.clear_automatic_read_promise = function(promise)
	return automatic_discard:clear_read_promise(promise)
end

Features.track_automatic_read_promise = function(promise)
	return automatic_discard:track_read_promise(promise)
end

Features.cancel_automatic_read_promise = function()
	return automatic_discard:cancel_read_promise()
end

Features.morningstar_auto_discard_is_busy = function(mod)
	return automatic_discard:morningstar_auto_discard_is_busy(mod)
end

Features.morningstar_auto_discard_has_started = function()
	return automatic_discard:morningstar_auto_discard_has_started()
end

Features.defer_morningstar_auto_discard_for_account_operation = function(mod) return automatic_discard:defer_for_account_operation(mod) end

Features.automatic_discard_read_request_count = function()
	return automatic_discard:automatic_discard_read_request_count()
end

Features.begin_morningstar_auto_discard = function(mod)
	return automatic_discard:begin(mod)
end

Features.cancel_morningstar_auto_discard = function(preserve_transaction)
	return automatic_discard:cancel(preserve_transaction)
end

Features.cancel_manual_discard = function()
	if Features.discard_owner() == "manual" then
		if Features.manual_discard_settlement_active() then
			return false
		end

		release_discard_transaction("manual", Features.discard_token())
	end

	return true
end

Features.update_morningstar_auto_discard = function(mod, dt, account_operation_busy)
	return automatic_discard:update(mod, dt, account_operation_busy)
end

Features.morningstar_auto_discard_needs_update = function(mod)
	return automatic_discard:needs_update(mod)
end

local function rendered_weapon_stats_height(weapon_stats)
	local scenegraph = weapon_stats and weapon_stats._ui_scenegraph
	local background_pivot = scenegraph and scenegraph.grid_background_pivot
	local background = scenegraph and scenegraph.grid_background
	local divider = scenegraph and scenegraph.grid_divider_bottom
	local weapon_divider = scenegraph and scenegraph.grid_divider_bottom_weapon

	if not background_pivot or not background or not divider then
		return
	end

	local background_pivot_y = background_pivot.position and background_pivot.position[2]
	local background_y = background.position and background.position[2]
	local background_height = background.size and background.size[2]
	local divider_y = divider.position and divider.position[2]
	local divider_height = divider.size and divider.size[2]

	if type(background_pivot_y) ~= "number" or type(background_y) ~= "number" or type(background_height) ~= "number" or type(divider_y) ~= "number" or type(divider_height) ~= "number" then
		return
	end

	local rendered_height = background_pivot_y + background_y + background_height - divider_height + divider_y

	if weapon_divider then
		local weapon_divider_y = weapon_divider.position and weapon_divider.position[2] or 0
		local weapon_divider_height = weapon_divider.size and weapon_divider.size[2]

		if type(weapon_divider_height) == "number" then
			rendered_height = rendered_height + (divider_height - weapon_divider_height) * 0.5 + weapon_divider_y + weapon_divider_height
		else
			rendered_height = rendered_height + divider_height
		end
	else
		rendered_height = rendered_height + divider_height
	end

	if rendered_height > 0 then
		return rendered_height
	end
end

local function set_inventory_sort_toggle_position(view, position, x, y)
	if position[1] == x and position[2] == y then
		return
	end

	if type(view._set_scenegraph_position) == "function" then
		view:_set_scenegraph_position(INVENTORY_SORT_TOGGLE_ID, x, y)
	else
		position[1] = x
		position[2] = y
		view._update_scenegraph = true
	end
end

local function weapon_stats_content_height(view, fallback_height)
	local weapon_stats = view and view._weapon_stats
	local menu_settings = weapon_stats and weapon_stats._menu_settings
	local grid_size = menu_settings and menu_settings.grid_size
	local content_height = rendered_weapon_stats_height(weapon_stats)

	if not content_height and weapon_stats and type(weapon_stats.grid_length) == "function" then
		local grid_length = weapon_stats:grid_length()

		if type(grid_length) == "number" and grid_length > 0 then
			content_height = grid_length + 35
		end
	end

	return content_height or grid_size and grid_size[2] or fallback_height
end

local function set_inventory_control_position(view, scenegraph_id, x, y)
	local scenegraph = view._ui_scenegraph
	local node = scenegraph and scenegraph[scenegraph_id]
	local position = node and node.position

	if not position or position[1] == x and position[2] == y then
		return
	end

	if type(view._set_scenegraph_position) == "function" then
		view:_set_scenegraph_position(scenegraph_id, x, y)
	else
		position[1] = x
		position[2] = y
		view._update_scenegraph = true
	end
end

local function set_inventory_widget_visible(view, scenegraph_id, visible)
	local widget = view._widgets_by_name and view._widgets_by_name[scenegraph_id]
	local content = widget and widget.content

	if content then
		content.visible = visible
	end
end

local function set_quick_discard_widgets_visible(view, visible)
	for index = 1, #INVENTORY_DISCARD_WIDGET_IDS do
		set_inventory_widget_visible(view, INVENTORY_DISCARD_WIDGET_IDS[index], visible)
	end
end

local function set_legacy_inventory_options_visible(view, visible)
	set_inventory_widget_visible(view, INVENTORY_SORT_LABEL_ID, visible)
	set_inventory_widget_visible(view, INVENTORY_SORT_TOGGLE_ID, visible)
	set_quick_discard_widgets_visible(view, visible)
end

local function set_options_panel_visible(view, panel, visible)
	if view._better_inventory_options_panel_visible ~= visible then
		view._better_inventory_options_panel_visible = visible

		if type(panel.disable_input) == "function" then
			panel:disable_input(not visible)
		end

		panel:set_visibility(visible)
	end
end

local function update_inventory_options_panel(mod, layout, view, slot_kind)
	local panel = view._better_inventory_options_panel

	if not panel or mod:get("enable_inventory_options_panel_prototype") ~= true then
		Features.invalidate_view_composition(view)

		if panel then
			set_options_panel_visible(view, panel, false)
		end

		return false
	end

	-- Weapon Filter owns the same right-side interaction region while its panel
	-- is open. Its public implementation hides Darktide's weapon-options element,
	-- but BetterInventory's separately owned grid is not part of that element.
	-- Follow the live view state so both panels never draw or accept input at once;
	-- returning true also keeps the legacy BetterInventory widgets hidden.
	if view._filter_panel_element and view._show_filter_panel == true then
		set_legacy_inventory_options_visible(view, false)
		set_options_panel_visible(view, panel, false)

		return true
	end

	local probe_count = (view._better_inventory_composition_probe_count or 0) + 1
	local probe_due = probe_count >= 15
	local input_changed = Features.composition_inputs_changed(view, slot_kind)

	if not view._better_inventory_composition_dirty and not input_changed and not probe_due then
		view._better_inventory_composition_probe_count = probe_count

		return true
	end

	view._better_inventory_composition_probe_count = 0

	set_legacy_inventory_options_visible(view, false)
	set_options_panel_visible(view, panel, true)

	if view._better_inventory_options_panel_structure_key ~= PanelState.panel_structure_key(mod, view) then
		rebuild_inventory_options_panel(mod, layout, view)
	end

	local native_discard_active = view._discard_items_element ~= nil
	local relative_x
	local relative_y
	local parent_id = slot_kind == "curio" and "weapon_stats_pivot" or "weapon_compare_stats_pivot"
	local absolute_x
	local absolute_y

	if native_discard_active then
		local discard_rect = scenegraph_rect(view._discard_items_element, "window")

		if discard_rect then
			-- The native filter window is the only stable free column in discard
			-- mode. Align with its left edge and follow its live bottom so the
			-- BetterInventory panel cannot cover item details or Discard Items.
			absolute_x = discard_rect.x
			absolute_y = discard_rect.y + discard_rect.height + INVENTORY_OPTIONS_PANEL_BUTTON_GAP
		else
			-- Keep the established fallback for the brief setup frame before the
			-- item-grid scenegraph has resolved.
			local expansion = tonumber(view._better_inventory_grid_expansion) or 0

			parent_id = slot_kind == "curio" and "weapon_stats_pivot" or "weapon_compare_stats_pivot"
			relative_x = slot_kind == "curio" and 0 or -566 - expansion
			relative_y = weapon_stats_content_height(view, 660) + 15
		end
	elseif slot_kind == "curio" then
		relative_x = 0
		relative_y = weapon_stats_content_height(view, 480) + 15
	else
		local weapon_stats = view._weapon_stats
		local weapon_stats_pivot = weapon_stats and weapon_stats._pivot_offset
		local weapon_stats_x = weapon_stats_pivot and tonumber(weapon_stats_pivot[1])
		local weapon_stats_width
		local weapon_options = view._weapon_options_element
		local menu_settings = weapon_options and weapon_options._menu_settings
		local grid_size = menu_settings and menu_settings.grid_size
		local native_pivot = weapon_options and weapon_options._pivot_offset
		local native_y = native_pivot and tonumber(native_pivot[2])
		local native_x = native_pivot and tonumber(native_pivot[1])

		if weapon_stats and type(weapon_stats._scenegraph_size) == "function" then
			local size_success, width = pcall(weapon_stats._scenegraph_size, weapon_stats, "grid_background")

			if size_success then
				weapon_stats_width = tonumber(width)
			end
		end

		if weapon_stats_x and weapon_stats_width and weapon_stats_width > 0 and native_y and native_x and (native_x ~= 0 or native_y ~= 0) then
			-- Horizontal and vertical placement intentionally use different live
			-- siblings: stay to the right of the weapon-information rectangle and
			-- below Darktide's Marks/Cosmetics/Inspect button rectangle.
			absolute_x = weapon_stats_x + weapon_stats_width + INVENTORY_OPTIONS_PANEL_WEAPON_GAP
			absolute_y = native_y + (grid_size and grid_size[2] or 300) + INVENTORY_OPTIONS_PANEL_BUTTON_GAP
		else
			-- Preserve the old pivot contract only during the brief startup window
			-- before both live sibling rectangles are available.
			relative_x = 20
			relative_y = (grid_size and grid_size[2] or 300) + INVENTORY_OPTIONS_PANEL_BUTTON_GAP
		end
	end

	local success = absolute_x ~= nil and absolute_y ~= nil
	local parent_position

	if not success then
		success, parent_position = pcall(view._scenegraph_world_position, view, parent_id)
	end

	if success and (parent_position or absolute_x) then
		local pivot_x = absolute_x or parent_position[1] + relative_x
		local pivot_y = absolute_y or parent_position[2] + relative_y

		if view._better_inventory_options_panel_pivot_x ~= pivot_x or view._better_inventory_options_panel_pivot_y ~= pivot_y then
			view._better_inventory_options_panel_pivot_x = pivot_x
			view._better_inventory_options_panel_pivot_y = pivot_y
			panel:set_pivot_offset(pivot_x, pivot_y)
		end
	else
		-- A future game update can invalidate the pivot contract. Hide the prototype
		-- and restore the proven loose-widget implementation for this view.
		set_options_panel_visible(view, panel, false)
		set_legacy_inventory_options_visible(view, true)

		return false
	end

	view._better_inventory_composition_dirty = false

	return true
end

local function update_quick_discard_content(mod, slot_kind, view, base_y)
	local widgets = view._widgets_by_name
	local label_widget = widgets and widgets[INVENTORY_DISCARD_LABEL_ID]
	local mode_widget = widgets and widgets[INVENTORY_DISCARD_MODE_ID]
	local skip_confirmation_widget = widgets and widgets[INVENTORY_DISCARD_SKIP_CONFIRMATION_ID]
	local discard_widget = widgets and widgets[INVENTORY_QUICK_DISCARD_ID]
	local max_level_widget = widgets and widgets[INVENTORY_DISCARD_MAX_LEVEL_ID]
	local melee_widget = widgets and widgets[INVENTORY_DISCARD_MELEE_ID]
	local ranged_widget = widgets and widgets[INVENTORY_DISCARD_RANGED_ID]
	local curio_widget = widgets and widgets[INVENTORY_DISCARD_CURIO_ID]
	local protection_widget = widgets and widgets[INVENTORY_DISCARD_PROTECTION_ID]
	local curio_protection_widget = widgets and widgets[INVENTORY_DISCARD_CURIO_PROTECTION_ID]
	local curio_level_widget = widgets and widgets[INVENTORY_DISCARD_CURIO_LEVEL_ID]

	if not discard_widget then
		return
	end

	local discard_mode = mod:get("quick_discard_mode") == "automatic" and "automatic" or "manual"
	local discard_heading_mode = discard_mode == "automatic" and "automated" or "manual"
	local mode_changed = view._better_inventory_legacy_discard_mode ~= discard_mode

	if mode_changed and label_widget then
		label_widget.content.label = mod:localize("inventory_" .. discard_heading_mode .. "_discard_management_inventory_label")
	end

	if mode_changed and mode_widget then
		mode_widget.content.value = mod:localize("quick_discard_mode_" .. discard_mode) .. "  ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Âº"
	end

	view._better_inventory_legacy_discard_mode = discard_mode

	if skip_confirmation_widget then
		skip_confirmation_widget.content.checked = mod:get("quick_discard_skip_automatic_confirmation") == true
		skip_confirmation_widget.content.visible = discard_mode == "automatic"
	end

	local rarity = math.clamp(math.floor(tonumber(mod:get("quick_discard_rarity")) or 1), 1, 5)
	local discard_content = discard_widget.content

	if discard_content.better_inventory_rarity ~= rarity then
		local rarity_settings = RaritySettings[rarity]
		local rarity_color = rarity_settings and rarity_settings.color or Color.terminal_text_body(255, true)

		discard_content.better_inventory_rarity = rarity
		discard_content.rarity_label = mod:localize("quick_discard_rarity_" .. rarity) .. "  ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Âº"

		if discard_widget.style and discard_widget.style.rarity_label then
			discard_widget.style.rarity_label.text_color = table.clone(rarity_color)
		end
	end

	if max_level_widget then
		local value = math.clamp(math.floor(tonumber(mod:get("quick_discard_max_item_level")) or 490), 0, 500)

		if max_level_widget.content.better_inventory_value ~= value then
			max_level_widget.content.better_inventory_value = value
			max_level_widget.content.value = tostring(value)
		end
	end

	if melee_widget then
		melee_widget.content.checked = mod:get("quick_discard_include_melee") ~= false
	end

	if ranged_widget then
		ranged_widget.content.checked = mod:get("quick_discard_include_ranged") ~= false
	end

	if curio_widget then
		curio_widget.content.checked = mod:get("quick_discard_include_curios") ~= false
	end

	local protection_content = protection_widget and protection_widget.content
	local curio_protection_content = curio_protection_widget and curio_protection_widget.content

	if protection_content then
		protection_content.checked = mod:get("quick_discard_protect_perfect_weapons") ~= false
	end

	if curio_protection_content then
		curio_protection_content.checked = mod:get("quick_discard_protect_high_level_curios") ~= false
	end

	if curio_level_widget then
		local value = math.clamp(math.floor(tonumber(mod:get("quick_discard_curio_protection_level")) or 410), 0, 500)

		if curio_level_widget.content.better_inventory_value ~= value then
			curio_level_widget.content.better_inventory_value = value
			curio_level_widget.content.value = tostring(value)
		end

		curio_level_widget.content.visible = mod:get("quick_discard_protect_high_level_curios") ~= false
	end

	local is_curio_view = slot_kind == "curio"
	local x = is_curio_view and 0 or 20
	local width = is_curio_view and 530 or 420
	local compact_x = x + 15
	local control_width = is_curio_view and 420 or width
	local compact_width = control_width - 15
	local type_gap = 8
	local type_width = math.floor((compact_width - type_gap * 2) / 3)
	local mode_width = 190

	set_inventory_control_position(view, INVENTORY_DISCARD_LABEL_ID, x, base_y + 70)
	set_inventory_control_position(view, INVENTORY_DISCARD_MODE_ID, compact_x, base_y + 100)
	set_inventory_control_position(view, INVENTORY_DISCARD_SKIP_CONFIRMATION_ID, compact_x + mode_width + 10, base_y + 100)
	set_inventory_control_position(view, INVENTORY_QUICK_DISCARD_ID, compact_x, base_y + 136)
	set_inventory_control_position(view, INVENTORY_DISCARD_MAX_LEVEL_ID, compact_x, base_y + 172)
	set_inventory_control_position(view, INVENTORY_DISCARD_MELEE_ID, compact_x, base_y + 206)
	set_inventory_control_position(view, INVENTORY_DISCARD_RANGED_ID, compact_x + type_width + type_gap, base_y + 206)
	set_inventory_control_position(view, INVENTORY_DISCARD_CURIO_ID, compact_x + (type_width + type_gap) * 2, base_y + 206)
	set_inventory_control_position(view, INVENTORY_DISCARD_PROTECTION_ID, compact_x, base_y + 240)
	set_inventory_control_position(view, INVENTORY_DISCARD_CURIO_PROTECTION_ID, compact_x, base_y + 274)
	set_inventory_control_position(view, INVENTORY_DISCARD_CURIO_LEVEL_ID, compact_x, base_y + 308)
end

Features.update_inventory_sort_toggle = function(mod, layout, view)
	local slot_kind = inventory_slot_kind(layout, view)

	if not slot_kind then
		return
	end

	local sorting_mod = Features._sorting.mod()
	local item_sorting_enabled_flag = sorting_mod and sorting_mod.enabled
	if view._better_inventory_composition_item_sorting_enabled ~= item_sorting_enabled_flag then
		Features.invalidate_view_composition(view)
		view._better_inventory_composition_item_sorting_enabled = item_sorting_enabled_flag
	end

	if mod:get("show_inventory_options_widget") == false then
		Features.invalidate_view_composition(view)
		local panel = view._better_inventory_options_panel

		set_legacy_inventory_options_visible(view, false)

		if panel then
			set_options_panel_visible(view, panel, false)
		end

		Features.release_lantern_inventory_section(view)

		return
	end

	Features.update_lantern_inventory_section(mod, view)

	if update_inventory_options_panel(mod, layout, view, slot_kind) then
		return
	end

	local widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_SORT_TOGGLE_ID]
	local content = widget and widget.content

	if content then
		content.checked = mod:get("prioritize_equipped_favorites") ~= false
	end

	local native_discard_active = view._discard_items_element ~= nil

	set_inventory_widget_visible(view, INVENTORY_SORT_LABEL_ID, true)
	set_inventory_widget_visible(view, INVENTORY_SORT_TOGGLE_ID, true)
	set_quick_discard_widgets_visible(view, not native_discard_active)

	local scenegraph = view._ui_scenegraph
	local node = scenegraph and scenegraph[INVENTORY_SORT_TOGGLE_ID]
	local position = node and node.position

	if not position then
		return
	end

	if native_discard_active then
		local expansion = tonumber(view._better_inventory_grid_expansion) or 0
		local sort_x = slot_kind == "curio" and 0 or -566 - expansion
		local sort_y = weapon_stats_content_height(view, 660) + 15

		set_inventory_control_position(view, INVENTORY_SORT_LABEL_ID, sort_x, sort_y)
		set_inventory_sort_toggle_position(view, position, sort_x + 15, sort_y + 28)

		return
	end

	if slot_kind == "curio" then
		local y = weapon_stats_content_height(view, 480) + 15

		set_inventory_control_position(view, INVENTORY_SORT_LABEL_ID, 0, y)
		set_inventory_sort_toggle_position(view, position, 15, y + 28)
		update_quick_discard_content(mod, slot_kind, view, y)
	else
		local menu_settings = view._weapon_options_element and view._weapon_options_element._menu_settings
		local grid_size = menu_settings and menu_settings.grid_size

		local y = (grid_size and grid_size[2] or 300) + 15

		set_inventory_control_position(view, INVENTORY_SORT_LABEL_ID, 20, y)
		set_inventory_sort_toggle_position(view, position, 35, y + 28)
		update_quick_discard_content(mod, slot_kind, view, y)
	end
end

Features.sync_inventory_sort_setting = function(mod, layout)
	local enabled = mod:get("prioritize_equipped_favorites") ~= false
	local perfect_rolls_enabled = mod:get("prioritize_perfect_roll_weapons") == true

	for view in pairs(registered_inventory_views) do
		Features.invalidate_view_composition(view)
		local widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_SORT_TOGGLE_ID]
		local panel_widget = view._better_inventory_options_panel_widgets and view._better_inventory_options_panel_widgets[INVENTORY_SORT_TOGGLE_ID]
		local perfect_panel_widget = view._better_inventory_options_panel_widgets and view._better_inventory_options_panel_widgets[INVENTORY_PERFECT_SORT_TOGGLE_ID]
		local content = widget and widget.content
		local panel_content = panel_widget and panel_widget.content
		local perfect_panel_content = perfect_panel_widget and perfect_panel_widget.content

		if content then
			content.checked = enabled
		end

		if panel_content then
			panel_content.checked = enabled
		end

		if perfect_panel_content then
			perfect_panel_content.checked = perfect_rolls_enabled
		end

		Features.resort_inventory(mod, layout, view)
	end

	for view in pairs(registered_armoury_views) do
		Features.invalidate_view_composition(view)
		Features.resort_inventory(mod, layout, view)
	end
end

Features.sync_quick_discard_settings = function(mod, layout, deferred_view)
	for view in pairs(registered_inventory_views) do
		if not view._destroyed then
			Features.invalidate_view_composition(view)

			if view ~= deferred_view then
				Features.update_inventory_sort_toggle(mod, layout, view)
			end
		end
	end
end

Features.sync_curio_acquisition_settings = function(mod, layout, deferred_view)
	for view in pairs(registered_inventory_views) do
		if not view._destroyed then
			Features.invalidate_view_composition(view)

			if view ~= deferred_view then
				Features.update_inventory_sort_toggle(mod, layout, view)
			end
		end
	end
end

Features.bind_inventory_sort_toggle = function(mod, layout, view)
	if not is_inventory_view(layout, view) then
		return
	end

	local widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_SORT_TOGGLE_ID]
	local content = widget and widget.content
	local hotspot = content and content.hotspot

	if not hotspot then
		return
	end

	registered_inventory_views[view] = true
	Features.invalidate_view_composition(view)
	Features.update_inventory_sort_toggle(mod, layout, view)
	hotspot.pressed_callback = function()
		local enabled = not content.checked

		mod:set("prioritize_equipped_favorites", enabled, false)
		Features.sync_inventory_sort_setting(mod, layout)
	end

	local discard_widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_QUICK_DISCARD_ID]
	local mode_widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_DISCARD_MODE_ID]
	local mode_hotspot = mode_widget and mode_widget.content and mode_widget.content.hotspot
	local skip_confirmation_widget = view._widgets_by_name and view._widgets_by_name[INVENTORY_DISCARD_SKIP_CONFIRMATION_ID]
	local skip_confirmation_content = skip_confirmation_widget and skip_confirmation_widget.content
	local skip_confirmation_hotspot = skip_confirmation_content and skip_confirmation_content.hotspot
	local discard_content = discard_widget and discard_widget.content
	local rarity_hotspot = discard_content and discard_content.rarity_hotspot
	local discard_hotspot = discard_content and discard_content.discard_hotspot

	if rarity_hotspot then
		rarity_hotspot.pressed_callback = function()
			local rarity = math.clamp(math.floor(tonumber(mod:get("quick_discard_rarity")) or 1), 1, 5)

			mod:set("quick_discard_rarity", rarity % 5 + 1, false)
			Features.sync_quick_discard_settings(mod, layout)
		end
	end

	if mode_hotspot then
		mode_hotspot.pressed_callback = function()
			local mode = mod:get("quick_discard_mode") == "automatic" and "manual" or "automatic"

			mod:set("quick_discard_mode", mode, false)
			Features.sync_quick_discard_settings(mod, layout)
		end
	end

	if skip_confirmation_hotspot then
		skip_confirmation_hotspot.pressed_callback = function()
			if mod:get("quick_discard_mode") == "automatic" then
				mod:set("quick_discard_skip_automatic_confirmation", not skip_confirmation_content.checked, false)
				Features.sync_quick_discard_settings(mod, layout)
			end
		end
	end

	if discard_hotspot then
		discard_hotspot.pressed_callback = function()
			Features.request_quick_discard(mod, layout, view)
		end
	end

	local function bind_checkbox(scenegraph_id, setting_id)
		local setting_widget = view._widgets_by_name and view._widgets_by_name[scenegraph_id]
		local setting_content = setting_widget and setting_widget.content
		local setting_hotspot = setting_content and setting_content.hotspot

		if setting_hotspot then
			setting_hotspot.pressed_callback = function()
				mod:set(setting_id, not setting_content.checked, false)
				Features.sync_quick_discard_settings(mod, layout)
			end
		end
	end

	local function bind_stepper(scenegraph_id, setting_id)
		local setting_widget = view._widgets_by_name and view._widgets_by_name[scenegraph_id]
		local setting_content = setting_widget and setting_widget.content
		local decrease_hotspot = setting_content and setting_content.decrease_hotspot
		local increase_hotspot = setting_content and setting_content.increase_hotspot
		local function change_value(delta)
			local value = math.clamp(math.floor(tonumber(mod:get(setting_id)) or 0) + delta, 0, 500)

			mod:set(setting_id, value, false)
			Features.sync_quick_discard_settings(mod, layout)
		end

		if decrease_hotspot then
			decrease_hotspot.pressed_callback = function()
				change_value(-10)
			end
		end

		if increase_hotspot then
			increase_hotspot.pressed_callback = function()
				change_value(10)
			end
		end
	end

	bind_stepper(INVENTORY_DISCARD_MAX_LEVEL_ID, "quick_discard_max_item_level")
	bind_checkbox(INVENTORY_DISCARD_MELEE_ID, "quick_discard_include_melee")
	bind_checkbox(INVENTORY_DISCARD_RANGED_ID, "quick_discard_include_ranged")
	bind_checkbox(INVENTORY_DISCARD_CURIO_ID, "quick_discard_include_curios")
	bind_checkbox(INVENTORY_DISCARD_PROTECTION_ID, "quick_discard_protect_perfect_weapons")
	bind_checkbox(INVENTORY_DISCARD_CURIO_PROTECTION_ID, "quick_discard_protect_high_level_curios")
	bind_stepper(INVENTORY_DISCARD_CURIO_LEVEL_ID, "quick_discard_curio_protection_level")
end

Features.unregister_inventory_view = function(view)
	local session_closed = Features.end_view_session(view, "view_exit")

	if not session_closed then
		Features.restore_sort_options(view)
	end

	if Features.discard_owner() == "manual" and Features.discard_view() == view then
		Features.cancel_manual_discard()
	end

	Features.release_inventory_options_panel(view)

	Features._registered_sort_views[view] = nil
	registered_inventory_views[view] = nil
end
Features.unregister_armoury_view = function(view)
	local session_closed = Features.end_view_session(view, "view_exit")

	if not session_closed then
		Features.restore_sort_options(view)
	end

	if armoury_panel and type(armoury_panel.release) == "function" then
		armoury_panel.release(view)
	elseif view then
		if view._better_inventory_armoury_controller_focused == true then
			set_armoury_controller_focus(view, false)
		end

		view._better_inventory_armoury_controller_legend = nil
		view._better_inventory_armoury_controller_legend_id = nil
		view._better_inventory_armoury_controller_legend_action = nil
	end

	Features._registered_sort_views[view] = nil
	registered_armoury_views[view] = nil
end

Features.disable_inventory_views = function()
	Features.cancel_manual_discard()

	for view in pairs(Features._registered_sort_views) do
		local session_closed = Features.end_view_session(view, "mod_disable")

		if not session_closed then
			Features.restore_sort_options(view)
		else
			view._better_inventory_session_disable_handled = true
		end
	end

	for view in pairs(registered_inventory_views) do
		restore_lantern_weapon_panel(view)

		if view._better_inventory_options_panel_controller_focused == true then
			set_inventory_options_panel_controller_focus(view, false)
		end

		local panel = view._better_inventory_options_panel

		if panel then
			set_options_panel_visible(view, panel, false)
		end

		set_legacy_inventory_options_visible(view, false)
	end

	for view in pairs(registered_armoury_views) do
		-- The shared session was closed by the registered-sort pass above. A
		-- compatibility restore remains for views that could not open a session.
		if view._better_inventory_session_disable_handled then
			view._better_inventory_session_disable_handled = nil
		else
			Features.restore_sort_options(view)
		end

		if view._better_inventory_armoury_controller_focused == true then
			set_armoury_controller_focus(view, false)
		end

		local legend = view._better_inventory_armoury_controller_legend
		local legend_id = view._better_inventory_armoury_controller_legend_id

		if legend and legend_id and type(legend.remove_entry) == "function" then
			pcall(legend.remove_entry, legend, legend_id)
		end

		view._better_inventory_armoury_controller_legend = nil
		view._better_inventory_armoury_controller_legend_id = nil
		view._better_inventory_armoury_controller_legend_action = nil

		local panel = view._better_inventory_armoury_native_sort_panel

		if panel then
			panel:set_visibility(false)
		end
	end
end

return Features
