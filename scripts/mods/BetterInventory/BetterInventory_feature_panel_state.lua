-- Small panel-state helpers extracted from the feature facade.
-- View caches remain view-owned; this module retains no UI state.
local PanelState = {}
local dependencies = {}

PanelState.configure = function(options)
	dependencies = type(options) == "table" and options or {}
end

local function curio_buyer_profile_revision()
	local fn = dependencies.curio_buyer_profile_revision

	return type(fn) == "function" and fn() or 0
end

local function item_sorting_is_enabled()
	local fn = dependencies.item_sorting_is_enabled

	return type(fn) == "function" and fn() or false
end

local function item_sorting_options_signature(view)
	local fn = dependencies.item_sorting_options_signature

	return type(fn) == "function" and fn(view) or ""
end

local function composite_key(...)
	local fn = dependencies.composite_key

	return type(fn) == "function" and fn(...) or table.concat({...}, ":")
end

local function shallow_copy(source)
	local copy = {}

	for key, value in pairs(source or {}) do
		copy[key] = value
	end

	return copy
end

local function panel_structure_key(mod, view)
	local collapsed = view._better_inventory_options_panel_collapsed or {}
	local key = 0

	key = key + (view._discard_items_element and 1 or 0)
	key = key + (mod:get("enable_experimental_quick_discard") == true and 2 or 0)
	key = key + (mod:get("quick_discard_mode") == "automatic" and 4 or 0)
	key = key + (mod:get("quick_discard_protect_high_level_curios") ~= false and 8 or 0)
	key = key + (collapsed.sorting and 16 or 0)
	key = key + (collapsed.discard and 32 or 0)
	key = key + (mod:get("enable_automatic_curio_acquisition") == true and 64 or 0)
	key = key + (collapsed.curio_buyer and 128 or 0)
	key = key + (mod:get("automatic_curio_scan_operative_selection") == true and 256 or 0)
	key = key + (mod:get("automatic_curio_once_per_store_rotation") ~= false and 512 or 0)
	key = key + (mod:get("automatic_curio_rescan_on_store_refresh") == true and 1024 or 0)
	key = key + (mod:get("automatic_curio_buy_health") ~= false and 2048 or 0)
	key = key + (mod:get("automatic_curio_buy_toughness") ~= false and 4096 or 0)
	key = key + (mod:get("automatic_curio_target_mode") == "characters" and 8192 or 0)
	key = key + curio_buyer_profile_revision() * 16384
	key = key + (item_sorting_is_enabled() and 4194304 or 0)
	key = key + (collapsed.item_sorting and 8388608 or 0)
	key = key + (collapsed.native_sorting and 16777216 or 0)
	key = key + (mod:get("quick_discard_protect_health_roll_curios") == true and 33554432 or 0)
	key = key + (mod:get("quick_discard_protect_toughness_roll_curios") == true and 67108864 or 0)

	return composite_key(key, view._better_inventory_lantern_panel_signature, item_sorting_options_signature(view))
end
PanelState.shallow_copy = shallow_copy
PanelState.panel_structure_key = panel_structure_key

return PanelState
