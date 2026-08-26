local Integration = {}
local Items = require("scripts/utilities/items")

local OWNER_CUSTOM_TIER = "custom_tier"
local OWNER_GOD_STAT_CHECKER = "god_stat_checker"
local PRIMARY_OWNER_SETTING = "god_stat_checker_background_owner"
local MIRROR_OWNER_SETTING = "custom_tier_god_stat_checker_background_owner"
local SAVED_STYLE_SETTING = "_god_stat_checker_saved_card_style_v1"
local FORCED_STYLE_SETTING = "_god_stat_checker_card_style_forced_v1"
local GSC_STYLE_SETTING = "opt_card_style"
local GSC_DISPLAY_SETTING = "opt_display_enabled"
local TEXT_ONLY_STYLE = "verdict_text_only"
local DEFAULT_BACKGROUND_STYLE = "verdict_bg_tier_text"
local VALID_STYLES = {
	verdict_bg_tier_text = true,
	verdict_all = true,
	verdict_text_only = true,
	none = true,
}
local BACKGROUND_STYLES = {
	verdict_bg_tier_text = true,
	verdict_all = true,
}

local mod
local custom_tier
local god_stat_checker
local framework_enabled = true
local applying_gsc_style = false
local background_owner = OWNER_CUSTOM_TIER
local custom_tier_feature_enabled = true
local gsc_ownership_available = false

local function read_setting(target, setting_id, default)
	if type(target) == "table" and type(target.get) == "function" then
		local ok, value = pcall(target.get, target, setting_id)

		if ok and value ~= nil then
			return value
		end
	end

	return default
end

local function write_setting(target, setting_id, value, notify)
	if type(target) ~= "table" or type(target.set) ~= "function" then
		return false
	end

	local ok, accepted = pcall(target.set, target, setting_id, value, notify == true)

	return ok and accepted ~= false
end

local function normalize_owner(value)
	return value == OWNER_GOD_STAT_CHECKER and OWNER_GOD_STAT_CHECKER or OWNER_CUSTOM_TIER
end

local function selected_owner()
	return background_owner
end

local function sync_owner_settings(source_setting_id)
	local owner

	if source_setting_id == MIRROR_OWNER_SETTING then
		owner = normalize_owner(read_setting(mod, MIRROR_OWNER_SETTING, OWNER_CUSTOM_TIER))
	else
		owner = normalize_owner(read_setting(mod, PRIMARY_OWNER_SETTING, OWNER_CUSTOM_TIER))
	end

	write_setting(mod, PRIMARY_OWNER_SETTING, owner, false)
	write_setting(mod, MIRROR_OWNER_SETTING, owner, false)
	background_owner = owner

	return owner
end

local function resolve_god_stat_checker()
	-- DMF exposes get_mod through the mod script environment. It is not
	-- guaranteed to be a raw field on _G (notably after Ctrl+Shift+R).
	local resolver = get_mod

	if type(resolver) ~= "function" then
		return
	end

	local ok, resolved = pcall(resolver, "god_stat_checker")

	if not ok or type(resolved) ~= "table" or type(resolved.get) ~= "function" or type(resolved.set) ~= "function" then
		return
	end

	return resolved
end

local function external_mod_enabled(external_mod)
	if type(external_mod) ~= "table" then
		return false
	end

	if type(external_mod.is_enabled) == "function" then
		local ok, enabled = pcall(external_mod.is_enabled, external_mod)

		if not ok or enabled == false then
			return false
		end
	end

	local display_enabled = read_setting(external_mod, GSC_DISPLAY_SETTING)

	if display_enabled == nil and type(external_mod.settings) == "table" then
		display_enabled = external_mod.settings.display_enabled
	end

	return display_enabled ~= false
end

local function custom_tier_enabled()
	return custom_tier_feature_enabled
end

local function gsc_can_own_background()
	return gsc_ownership_available
end

local function current_gsc_style()
	local style = read_setting(god_stat_checker, GSC_STYLE_SETTING)

	if style == nil and type(god_stat_checker) == "table" and type(god_stat_checker.settings) == "table" then
		style = god_stat_checker.settings.card_style
	end

	return VALID_STYLES[style] and style or DEFAULT_BACKGROUND_STYLE
end

local function set_hidden_setting(setting_id, value)
	return write_setting(mod, setting_id, value, false)
end

local function force_gsc_text_only()
	if not external_mod_enabled(god_stat_checker) then
		return false
	end

	local current_style = current_gsc_style()
	local was_forced = read_setting(mod, FORCED_STYLE_SETTING, false) == true

	if current_style == TEXT_ONLY_STYLE and was_forced then
		return true
	end

	if not BACKGROUND_STYLES[current_style] then
		set_hidden_setting(SAVED_STYLE_SETTING, current_style)
		set_hidden_setting(FORCED_STYLE_SETTING, false)

		return true
	end

	set_hidden_setting(SAVED_STYLE_SETTING, current_style)
	set_hidden_setting(FORCED_STYLE_SETTING, true)
	applying_gsc_style = true
	local changed = write_setting(god_stat_checker, GSC_STYLE_SETTING, TEXT_ONLY_STYLE, true)
	applying_gsc_style = false

	if not changed then
		set_hidden_setting(FORCED_STYLE_SETTING, false)
	end

	return changed
end

local function restore_gsc_style()
	if type(god_stat_checker) ~= "table" or read_setting(mod, FORCED_STYLE_SETTING, false) ~= true then
		return false
	end

	local saved_style = read_setting(mod, SAVED_STYLE_SETTING, DEFAULT_BACKGROUND_STYLE)

	if not VALID_STYLES[saved_style] then
		saved_style = DEFAULT_BACKGROUND_STYLE
	end

	set_hidden_setting(FORCED_STYLE_SETTING, false)
	applying_gsc_style = true
	local restored = write_setting(god_stat_checker, GSC_STYLE_SETTING, saved_style, true)
	applying_gsc_style = false

	if not restored then
		set_hidden_setting(FORCED_STYLE_SETTING, true)
	end

	return restored
end

local function custom_tier_background(item)
	if type(custom_tier) ~= "table" or type(custom_tier.background_color) ~= "function" then
		return
	end

	local ok, primary, dark = pcall(custom_tier.background_color, item)

	if ok then
		return primary, dark
	end
end

local function patch_gsc_original_rarity_color()
	if type(Items.gsc_original_rarity_color) ~= "function" then
		return false
	end

	local state = Items._better_inventory_god_stat_checker_compatibility

	if type(state) ~= "table" then
		state = {}
		Items._better_inventory_god_stat_checker_compatibility = state
	end

	if Items.gsc_original_rarity_color ~= state.wrapper then
		state.fallback = Items.gsc_original_rarity_color
	end

	if type(state.fallback) ~= "function" then
		return false
	end

	state.custom_tier_background = custom_tier_background
	state.custom_tier_owns_background = function()
		return custom_tier_enabled() and (selected_owner() == OWNER_CUSTOM_TIER or not gsc_can_own_background())
	end
	state.wrapper = state.wrapper or function(item)
		if state.custom_tier_owns_background() then
			local primary, dark = state.custom_tier_background(item)

			if primary ~= nil then
				return primary, dark
			end
		end

		return state.fallback(item)
	end
	Items.gsc_original_rarity_color = state.wrapper

	return true
end

local function reconcile()
	god_stat_checker = resolve_god_stat_checker()
	custom_tier_feature_enabled = framework_enabled and read_setting(mod, "custom_tier_enabled", true) ~= false
	gsc_ownership_available = framework_enabled and external_mod_enabled(god_stat_checker)

	patch_gsc_original_rarity_color()

	local reconciled

	if custom_tier_enabled() and selected_owner() == OWNER_CUSTOM_TIER and gsc_can_own_background() then
		reconciled = force_gsc_text_only()
	else
		reconciled = restore_gsc_style()
	end

	return reconciled
end

local function observe_gsc_setting_change(setting_id)
	if applying_gsc_style then
		return
	end

	if setting_id ~= GSC_STYLE_SETTING then
		reconcile()

		return
	end

	if custom_tier_enabled() and selected_owner() == OWNER_CUSTOM_TIER and gsc_can_own_background() then
		local selected_style = current_gsc_style()

		if BACKGROUND_STYLES[selected_style] then
			set_hidden_setting(SAVED_STYLE_SETTING, selected_style)
			force_gsc_text_only()
		else
			set_hidden_setting(SAVED_STYLE_SETTING, selected_style)
			set_hidden_setting(FORCED_STYLE_SETTING, false)
		end
	else
		set_hidden_setting(SAVED_STYLE_SETTING, current_gsc_style())
		set_hidden_setting(FORCED_STYLE_SETTING, false)
	end
end

local function install_gsc_lifecycle_hooks()
	if type(god_stat_checker) ~= "table" or type(mod) ~= "table" or type(mod.hook_safe) ~= "function" then
		return false
	end

	local state = god_stat_checker._better_inventory_background_ownership

	if type(state) ~= "table" then
		state = {}
		god_stat_checker._better_inventory_background_ownership = state
	end

	state.on_setting_changed = observe_gsc_setting_change
	state.on_lifecycle_changed = reconcile

	if state.hooks_installed then
		return true
	end

	if type(god_stat_checker.on_setting_changed) == "function" then
		mod:hook_safe(god_stat_checker, "on_setting_changed", function(setting_id)
			state.on_setting_changed(setting_id)
		end)
	end
	if type(god_stat_checker.on_enabled) == "function" then
		mod:hook_safe(god_stat_checker, "on_enabled", function()
			state.on_lifecycle_changed()
		end)
	end
	if type(god_stat_checker.on_disabled) == "function" then
		mod:hook_safe(god_stat_checker, "on_disabled", function()
			state.on_lifecycle_changed()
		end)
	end

	state.hooks_installed = true

	return true
end

Integration.install = function(configured_mod, custom_tier_module)
	mod = configured_mod or mod
	custom_tier = custom_tier_module or custom_tier
	framework_enabled = true
	sync_owner_settings()
	god_stat_checker = resolve_god_stat_checker()
	install_gsc_lifecycle_hooks()

	return reconcile()
end

Integration.on_enabled = function(configured_mod, custom_tier_module)
	framework_enabled = true

	return Integration.install(configured_mod, custom_tier_module)
end

Integration.on_disabled = function()
	framework_enabled = false
	custom_tier_feature_enabled = false
	gsc_ownership_available = false

	return restore_gsc_style()
end

Integration.on_setting_changed = function(configured_mod, setting_id)
	mod = configured_mod or mod

	if setting_id == PRIMARY_OWNER_SETTING or setting_id == MIRROR_OWNER_SETTING then
		sync_owner_settings(setting_id)
		reconcile()

		return true
	end

	if setting_id == "custom_tier_enabled" then
		reconcile()

		return true
	end

	return false
end

Integration.on_settings_reset = function(configured_mod)
	mod = configured_mod or mod
	sync_owner_settings(PRIMARY_OWNER_SETTING)

	return reconcile()
end

Integration.god_stat_checker_owns_background = function()
	return selected_owner() == OWNER_GOD_STAT_CHECKER and gsc_can_own_background()
end

Integration._test = {
	background_styles = BACKGROUND_STYLES,
	current_gsc_style = current_gsc_style,
	force_gsc_text_only = force_gsc_text_only,
	normalize_owner = normalize_owner,
	observe_gsc_setting_change = observe_gsc_setting_change,
	patch_gsc_original_rarity_color = patch_gsc_original_rarity_color,
	reconcile = reconcile,
	restore_gsc_style = restore_gsc_style,
	setting_ids = {
		forced_style = FORCED_STYLE_SETTING,
		mirror_owner = MIRROR_OWNER_SETTING,
		primary_owner = PRIMARY_OWNER_SETTING,
		saved_style = SAVED_STYLE_SETTING,
	},
}

return Integration
