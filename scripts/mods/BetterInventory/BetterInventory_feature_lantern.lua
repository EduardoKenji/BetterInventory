-- Optional Lantern integration domain. Owns only Lantern adapter state;
-- panel composition invalidation is injected from the feature facade.
local Lantern = {}
local ProfileUtils = require("scripts/utilities/profile_utils")
local lantern_mod
local lantern_overlay
local invalidate_view_composition

Lantern.configure = function(options)
	if type(options) == "function" then
		invalidate_view_composition = options
	elseif type(options) == "table" then
		invalidate_view_composition = options.invalidate_view_composition
	end
end

local function lantern_is_enabled()
	if not lantern_mod then
		return false
	end

	if type(lantern_mod.is_enabled) ~= "function" then
		return true
	end

	local success, enabled = pcall(lantern_mod.is_enabled, lantern_mod)

	return success and enabled == true
end

local function lantern_recommendations_enabled()
	if not lantern_is_enabled() or type(lantern_mod.get) ~= "function" then
		return false
	end

	local success, enabled = pcall(lantern_mod.get, lantern_mod, "show_recommendations")

	return success and enabled == true
end

Lantern.lantern_recommendations_active = lantern_recommendations_enabled

local function lantern_weapon_signature(view)
	local slot = view and view._selected_slot

	if not slot or not slot.name or type(ProfileUtils.get_active_profile_preset_id) ~= "function" then
		return
	end

	local success, active_id = pcall(ProfileUtils.get_active_profile_preset_id)

	if not success then
		return
	end

	return tostring(active_id) .. "|" .. tostring(slot.name)
end

local function lantern_preview_is_active(view)
	if not view or type(view.is_previewing_item) ~= "function" then
		return false
	end

	local success, is_previewing = pcall(view.is_previewing_item, view)

	return success and is_previewing == true
end

local function restore_lantern_weapon_panel(view)
	if view then
		local changed = view._better_inventory_lantern_panel_available == true or view._better_inventory_lantern_panel_height ~= nil or view._better_inventory_lantern_panel_signature ~= nil or view._better_inventory_lantern_panel_hosted == true

		view._better_inventory_lantern_panel_available = false
		view._better_inventory_lantern_panel_height = nil
		view._better_inventory_lantern_panel_signature = nil
		view._better_inventory_lantern_panel_hosted = false

		if changed then
			invalidate_view_composition(view)
			view._better_inventory_lantern_panel_last_hosted = false
			view._better_inventory_lantern_panel_last_signature = nil
		end
	end
end

Lantern.should_host_lantern_panel = function(view)
	return view and view._better_inventory_lantern_panel_hosted == true
end

Lantern.set_lantern_integration = function(_, integration_mod)
	lantern_mod = type(integration_mod) == "table" and integration_mod or nil
	lantern_overlay = lantern_mod and lantern_mod._modules and lantern_mod._modules.equipment_overlay or nil

	if not lantern_overlay or type(lantern_overlay.draw_weapon_select) ~= "function" then
		return false
	end

	if type(lantern_overlay._better_inventory_original_draw_weapon_select) ~= "function" then
		lantern_overlay._better_inventory_original_draw_weapon_select = lantern_overlay.draw_weapon_select
		lantern_overlay.draw_weapon_select = function(view, ...)
			local should_host = lantern_overlay._better_inventory_should_host_panel

			if type(should_host) == "function" and should_host(view) then
				return
			end

			return lantern_overlay._better_inventory_original_draw_weapon_select(view, ...)
		end
	end

	lantern_overlay._better_inventory_should_host_panel = Lantern.should_host_lantern_panel

	return true
end

Lantern.release_lantern_inventory_section = function(view)
	restore_lantern_weapon_panel(view)
end

Lantern.update_lantern_inventory_section = function(mod, view)
	local selected_slot_name = view and view._selected_slot and view._selected_slot.name
	local separate_curio_panel = mod:get("keep_lantern_curio_panel_separate") ~= false and type(selected_slot_name) == "string" and string.match(selected_slot_name, "^slot_attachment_") ~= nil
	local blocked_by_native_view_state = view and (view._discard_items_element ~= nil or view._item_compare_toggled == true)

	if not lantern_mod or not lantern_overlay or separate_curio_panel or blocked_by_native_view_state or mod:get("enable_lantern_inventory_section") ~= true or mod:get("enable_inventory_options_panel_prototype") ~= true or mod:get("show_inventory_options_widget") == false or not view or not view._better_inventory_options_panel or view._better_inventory_options_panel_visible ~= true or view._better_inventory_options_panel._visible == false or view._filter_panel_element and view._show_filter_panel == true or not lantern_recommendations_enabled() or not lantern_preview_is_active(view) then
		restore_lantern_weapon_panel(view)

		return false
	end

	local state = view._lantern_weapon_panel
	local widget = state and state.widget
	local expected_signature = lantern_weapon_signature(view)
	local background_style = widget and widget.style and widget.style.background
	local panel_height = background_style and tonumber(background_style.size and background_style.size[2])

	if not state or not widget or not state.entry or not expected_signature or state.sig ~= expected_signature or not panel_height or panel_height <= 0 then
		restore_lantern_weapon_panel(view)

		return false
	end

	view._better_inventory_lantern_panel_available = true
	view._better_inventory_lantern_panel_height = math.max(120, panel_height)
	view._better_inventory_lantern_panel_signature = tostring(state.sig) .. "|" .. tostring(view._better_inventory_lantern_panel_height)
	view._better_inventory_lantern_panel_hosted = view._better_inventory_lantern_section_widget ~= nil

	if view._better_inventory_lantern_panel_hosted ~= view._better_inventory_lantern_panel_last_hosted or view._better_inventory_lantern_panel_signature ~= view._better_inventory_lantern_panel_last_signature then
		invalidate_view_composition(view)
		view._better_inventory_lantern_panel_last_hosted = view._better_inventory_lantern_panel_hosted
		view._better_inventory_lantern_panel_last_signature = view._better_inventory_lantern_panel_signature
	end

	return view._better_inventory_lantern_panel_hosted
end
return Lantern
