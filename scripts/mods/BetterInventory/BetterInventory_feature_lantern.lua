-- Optional Lantern integration domain. Owns only Lantern adapter state;
-- panel composition invalidation is injected from the feature facade.
local Lantern = {}
local ProfileUtils = require("scripts/utilities/profile_utils")
local lantern_mod
local lantern_overlay
local invalidate_view_composition
local installed_overlay
local installed_original_draw
local installed_draw_wrapper
local integration_owner = {}
local RECOMMENDATION_POLL_INTERVAL = 15
local cached_recommendations_enabled = false
local cached_mod_enabled
local recommendation_poll_count = RECOMMENDATION_POLL_INTERVAL

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
	local mod_enabled = lantern_mod and lantern_mod.enabled
	recommendation_poll_count = recommendation_poll_count + 1

	if recommendation_poll_count < RECOMMENDATION_POLL_INTERVAL and mod_enabled == cached_mod_enabled then
		return cached_recommendations_enabled
	end

	recommendation_poll_count = 0
	cached_mod_enabled = mod_enabled

	if not lantern_is_enabled() or type(lantern_mod.get) ~= "function" then
		cached_recommendations_enabled = false

		return false
	end

	local success, enabled = pcall(lantern_mod.get, lantern_mod, "show_recommendations")

	cached_recommendations_enabled = success and enabled == true

	return cached_recommendations_enabled
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

local function restore_lantern_weapon_panel(view, preserve_probe)
	if view then
		local panel_changed = view._better_inventory_lantern_panel_available == true or view._better_inventory_lantern_panel_height ~= nil or view._better_inventory_lantern_panel_signature ~= nil or view._better_inventory_lantern_panel_hosted == true
		local probe_changed = preserve_probe ~= true and view._better_inventory_lantern_probe ~= nil

		if not panel_changed and not probe_changed then
			return
		end

		if panel_changed then
			view._better_inventory_lantern_panel_available = false
			view._better_inventory_lantern_panel_height = nil
			view._better_inventory_lantern_panel_signature = nil
			view._better_inventory_lantern_panel_hosted = false
			invalidate_view_composition(view)
			view._better_inventory_lantern_panel_last_hosted = false
			view._better_inventory_lantern_panel_last_signature = nil
		end

		if probe_changed then
			view._better_inventory_lantern_probe = nil
		end
	end
end

Lantern.should_host_lantern_panel = function(view)
	return view and view._better_inventory_lantern_panel_hosted == true
end

local function detach_lantern_integration()
	local overlay = installed_overlay

	if overlay then
		if overlay.draw_weapon_select == installed_draw_wrapper then
			overlay.draw_weapon_select = installed_original_draw
		end

		if overlay._better_inventory_draw_owner == integration_owner then
			overlay._better_inventory_draw_owner = nil
			overlay._better_inventory_draw_wrapper = nil
			overlay._better_inventory_original_draw = nil
		end
	end

	installed_overlay = nil
	installed_original_draw = nil
	installed_draw_wrapper = nil
	lantern_overlay = nil
	lantern_mod = nil
	cached_recommendations_enabled = false
	cached_mod_enabled = nil
	recommendation_poll_count = RECOMMENDATION_POLL_INTERVAL
end

Lantern.set_lantern_integration = function(_, integration_mod)
	detach_lantern_integration()

	lantern_mod = type(integration_mod) == "table" and integration_mod or nil
	lantern_overlay = lantern_mod and lantern_mod._modules and lantern_mod._modules.equipment_overlay or nil

	if not lantern_overlay or type(lantern_overlay.draw_weapon_select) ~= "function" then
		lantern_overlay = nil
		lantern_mod = nil

		return false
	end

	local overlay = lantern_overlay
	local original_draw = overlay.draw_weapon_select
	local wrapper = function(view, ...)
		if Lantern.should_host_lantern_panel(view) then
			return
		end

		return original_draw(view, ...)
	end

	installed_overlay = overlay
	installed_original_draw = original_draw
	installed_draw_wrapper = wrapper
	overlay._better_inventory_draw_owner = integration_owner
	overlay._better_inventory_draw_wrapper = wrapper
	overlay._better_inventory_original_draw = original_draw
	overlay.draw_weapon_select = wrapper

	return true
end

Lantern.shutdown = detach_lantern_integration

Lantern.release_lantern_inventory_section = function(view)
	restore_lantern_weapon_panel(view)
end

Lantern.update_lantern_inventory_section = function(mod, view)
	if not lantern_mod or not lantern_overlay or not view then
		restore_lantern_weapon_panel(view)

		return false
	end

	local selected_slot = view._selected_slot
	local selected_slot_name = selected_slot and selected_slot.name
	local separate_curio_panel = mod:get("keep_lantern_curio_panel_separate") ~= false and type(selected_slot_name) == "string" and string.match(selected_slot_name, "^slot_attachment_") ~= nil
	local blocked_by_native_view_state = view._discard_items_element ~= nil or view._item_compare_toggled == true

	if separate_curio_panel or blocked_by_native_view_state or mod:get("enable_lantern_inventory_section") ~= true or mod:get("show_inventory_options_widget") == false or not view._better_inventory_options_panel or view._better_inventory_options_panel_visible ~= true or view._better_inventory_options_panel._visible == false or view._filter_panel_element and view._show_filter_panel == true or not lantern_recommendations_enabled() then
		restore_lantern_weapon_panel(view)

		return false
	end

	local state = view._lantern_weapon_panel
	local widget = state and state.widget
	local entry = state and state.entry

	if not state or not widget or not entry then
		restore_lantern_weapon_panel(view)

		return false
	end

	local probe = view._better_inventory_lantern_probe

	if not probe then
		probe = {}
		view._better_inventory_lantern_probe = probe
	end

	local hosted = view._better_inventory_lantern_section_widget ~= nil
	local probe_count = (probe.count or RECOMMENDATION_POLL_INTERVAL) + 1
	local probe_due = probe_count >= RECOMMENDATION_POLL_INTERVAL
	local state_changed = probe.state ~= state or probe.widget ~= widget or probe.entry ~= entry or probe.signature ~= state.sig or probe.slot ~= selected_slot or probe.slot_name ~= selected_slot_name or probe.preview ~= view.is_previewing_item or probe.hosted ~= hosted

	if not probe_due and not state_changed then
		probe.count = probe_count

		return view._better_inventory_lantern_panel_hosted == true
	end

	probe.count = 0
	probe.state = state
	probe.widget = widget
	probe.entry = entry
	probe.signature = state.sig
	probe.slot = selected_slot
	probe.slot_name = selected_slot_name
	probe.preview = view.is_previewing_item
	probe.hosted = hosted

	if not lantern_preview_is_active(view) then
		restore_lantern_weapon_panel(view, true)

		return false
	end

	local expected_signature = lantern_weapon_signature(view)
	local background_style = widget and widget.style and widget.style.background
	local panel_height = background_style and tonumber(background_style.size and background_style.size[2])

	if not expected_signature or state.sig ~= expected_signature or not panel_height or panel_height <= 0 then
		restore_lantern_weapon_panel(view, true)

		return false
	end

	view._better_inventory_lantern_panel_available = true
	view._better_inventory_lantern_panel_height = math.max(120, panel_height)
	view._better_inventory_lantern_panel_signature = tostring(state.sig) .. "|" .. tostring(view._better_inventory_lantern_panel_height)
	view._better_inventory_lantern_panel_hosted = hosted

	if view._better_inventory_lantern_panel_hosted ~= view._better_inventory_lantern_panel_last_hosted or view._better_inventory_lantern_panel_signature ~= view._better_inventory_lantern_panel_last_signature then
		invalidate_view_composition(view)
		view._better_inventory_lantern_panel_last_hosted = view._better_inventory_lantern_panel_hosted
		view._better_inventory_lantern_panel_last_signature = view._better_inventory_lantern_panel_signature
	end

	return view._better_inventory_lantern_panel_hosted
end
return Lantern
