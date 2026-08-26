from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_god_stat_checker_integration.lua"
)


def color_channels(color):
    return [color[index] for index in range(1, 5)]


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        better_inventory_settings = {
            custom_tier_enabled = true,
            god_stat_checker_background_owner = "custom_tier",
            custom_tier_god_stat_checker_background_owner = "custom_tier",
        }
        god_stat_checker_saved_settings = {
            opt_card_style = "verdict_bg_tier_text",
            opt_display_enabled = true,
        }
        god_stat_checker_repaints = 0
        god_stat_checker_enabled = true
        better_inventory_get_calls = 0

        test_items = {
            rarity_color = function()
                return {255, 145, 70, 40}, {255, 87, 42, 24}
            end,
        }
        package.preload["scripts/utilities/items"] = function() return test_items end

        god_stat_checker_mod = {
            settings = {
                card_style = "verdict_bg_tier_text",
                display_enabled = true,
            },
            get = function(_, setting_id)
                return god_stat_checker_saved_settings[setting_id]
            end,
            set = function(self, setting_id, value, notify)
                god_stat_checker_saved_settings[setting_id] = value
                if notify and type(self.on_setting_changed) == "function" then
                    self.on_setting_changed(setting_id)
                end
                return true
            end,
            is_enabled = function()
                return god_stat_checker_enabled
            end,
            on_setting_changed = function(setting_id)
                god_stat_checker_mod.settings.card_style = god_stat_checker_saved_settings.opt_card_style
                god_stat_checker_mod.settings.display_enabled = god_stat_checker_saved_settings.opt_display_enabled
                god_stat_checker_repaints = god_stat_checker_repaints + 1
            end,
            on_enabled = function() end,
            on_disabled = function() end,
        }

        -- Reproduce God Stat Checker 1.1.2's Items wrapper and its captured
        -- native fallback. Grade-background modes paint gold; text-only/none
        -- delegate background selection through gsc_original_rarity_color.
        test_items.gsc_original_rarity_color = test_items.rarity_color
        test_items.rarity_color = function(item)
            local style = god_stat_checker_mod.settings.card_style
            local paints_background = style == "verdict_bg_tier_text" or style == "verdict_all"
            if god_stat_checker_mod.settings.display_enabled and paints_background and item and item.god_roll then
                return {255, 210, 160, 40}, {255, 126, 96, 24}
            end
            return test_items.gsc_original_rarity_color(item)
        end

        custom_tier_module = {
            background_color = function(item)
                if item and item.custom_tier then
                    return {255, 210, 30, 40}, {255, 126, 18, 24}
                end
            end,
        }

        better_inventory_mod = {
            get = function(_, setting_id)
                better_inventory_get_calls = better_inventory_get_calls + 1
                return better_inventory_settings[setting_id]
            end,
            set = function(_, setting_id, value)
                better_inventory_settings[setting_id] = value
                return true
            end,
            hook_safe = function(_, target, method_name, callback)
                local original = target[method_name]
                target[method_name] = function(...)
                    local results = {original(...)}
                    callback(...)
                    return table.unpack(results)
                end
            end,
        }

        god_stat_checker_installed = true
        function get_mod(name)
            if name == "god_stat_checker" and god_stat_checker_installed then
                return god_stat_checker_mod
            end
        end

        qualifying_item = {custom_tier = true, god_roll = true}
        ordinary_item = {custom_tier = false, god_roll = false}
        '''
    )

    # Darktide's mod environment can expose get_mod through _ENV without
    # placing it directly on _G. Reproduce that lookup contract so a rawget
    # regression makes GSC appear absent after Ctrl+Shift+R.
    lua.globals().integration_source = MODULE_PATH.read_text(encoding="utf-8")
    integration = lua.execute(
        r'''
        local injected_get_mod = get_mod
        get_mod = nil
        local environment = setmetatable({}, {
            __index = function(_, key)
                if key == "get_mod" then
                    return injected_get_mod
                end
                return _G[key]
            end,
        })
        local chunk = assert(load(integration_source, "god-stat-checker-integration", "t", environment))
        return chunk()
        '''
    )
    lua.globals().integration = integration
    mod = lua.globals().better_inventory_mod
    settings = lua.globals().better_inventory_settings
    gsc_settings = lua.globals().god_stat_checker_saved_settings
    gsc = lua.globals().god_stat_checker_mod
    items = lua.globals().test_items
    qualifying = lua.globals().qualifying_item
    ordinary = lua.globals().ordinary_item

    # Better Inventory is the default exclusive owner. GSC keeps grading text,
    # saves its preferred background style, and repaints current cards once.
    assert integration.install(
        mod,
        lua.globals().custom_tier_module,
    ) is True
    assert settings.god_stat_checker_background_owner == "custom_tier"
    assert settings.custom_tier_god_stat_checker_background_owner == "custom_tier"
    assert settings._god_stat_checker_saved_card_style_v1 == "verdict_bg_tier_text"
    assert settings._god_stat_checker_card_style_forced_v1 is True
    assert gsc_settings.opt_card_style == "verdict_text_only"
    assert gsc.settings.card_style == "verdict_text_only"
    assert lua.globals().god_stat_checker_repaints == 1
    custom_color, custom_dark = items.rarity_color(qualifying)
    assert color_channels(custom_color) == [255, 210, 30, 40]
    assert color_channels(custom_dark) == [255, 126, 18, 24]
    ordinary_color, _ = items.rarity_color(ordinary)
    assert color_channels(ordinary_color) == [255, 145, 70, 40]
    assert integration.god_stat_checker_owns_background() is False

    # Ownership is cached at lifecycle/setting boundaries. Card lookups never
    # query DMF settings or perform a framework enabled-state call.
    get_calls_before_cards = lua.globals().better_inventory_get_calls
    for _ in range(100):
        items.gsc_original_rarity_color(qualifying)
        integration.god_stat_checker_owns_background()
    assert lua.globals().better_inventory_get_calls == get_calls_before_cards

    # The mirrored Custom Tier control is fully bidirectional. Selecting GSC
    # restores its exact saved style, so list cards and the right detail panel
    # resolve through the same grade-color owner.
    settings.custom_tier_god_stat_checker_background_owner = "god_stat_checker"
    assert integration.on_setting_changed(
        mod, "custom_tier_god_stat_checker_background_owner"
    ) is True
    assert settings.god_stat_checker_background_owner == "god_stat_checker"
    assert settings._god_stat_checker_card_style_forced_v1 is False
    assert gsc_settings.opt_card_style == "verdict_bg_tier_text"
    assert integration.god_stat_checker_owns_background() is True
    grade_color, _ = items.rarity_color(qualifying)
    assert color_channels(grade_color) == [255, 210, 160, 40]

    settings.god_stat_checker_background_owner = "custom_tier"
    assert integration.on_setting_changed(mod, "god_stat_checker_background_owner") is True
    assert settings.custom_tier_god_stat_checker_background_owner == "custom_tier"
    assert gsc_settings.opt_card_style == "verdict_text_only"

    # A GSC card-style change made while Custom Tier owns backgrounds is not
    # lost: the preference is remembered, then GSC is returned to text-only.
    gsc.set(gsc, "opt_card_style", "verdict_all", True)
    assert settings._god_stat_checker_saved_card_style_v1 == "verdict_all"
    assert settings._god_stat_checker_card_style_forced_v1 is True
    assert gsc_settings.opt_card_style == "verdict_text_only"
    assert gsc.settings.card_style == "verdict_text_only"

    # A genuinely background-free GSC preference already satisfies exclusive
    # ownership and therefore needs no forced marker or later restoration.
    gsc.set(gsc, "opt_card_style", "none", True)
    assert settings._god_stat_checker_saved_card_style_v1 == "none"
    assert settings._god_stat_checker_card_style_forced_v1 is False
    none_mode_color, _ = items.rarity_color(qualifying)
    assert color_channels(none_mode_color) == [255, 210, 30, 40]

    # Restore a background preference, then prove BI disable/enable restores and
    # re-applies it without relying on a per-frame scan.
    gsc.set(gsc, "opt_card_style", "verdict_all", True)
    assert gsc_settings.opt_card_style == "verdict_text_only"
    assert integration.on_disabled() is True
    assert gsc_settings.opt_card_style == "verdict_all"
    assert settings._god_stat_checker_card_style_forced_v1 is False
    assert integration.on_enabled(mod, lua.globals().custom_tier_module) is True
    assert gsc_settings.opt_card_style == "verdict_text_only"

    # If the selected external owner is disabled, Custom Tier safely owns both
    # surfaces until GSC returns. Reinstallation is idempotent and does not wrap
    # either the GSC lifecycle or captured rarity function recursively.
    settings.god_stat_checker_background_owner = "god_stat_checker"
    integration.on_setting_changed(mod, "god_stat_checker_background_owner")
    lua.globals().god_stat_checker_enabled = False
    integration._test.reconcile()
    assert integration.god_stat_checker_owns_background() is False
    fallback_color, _ = items.gsc_original_rarity_color(qualifying)
    assert color_channels(fallback_color) == [255, 210, 30, 40]
    integration.install(mod, lua.globals().custom_tier_module)
    integration.install(mod, lua.globals().custom_tier_module)
    repeated_color, _ = items.gsc_original_rarity_color(ordinary)
    assert color_channels(repeated_color) == [255, 145, 70, 40]

    # GSC's own display and mod lifecycle callbacks reconcile ownership. A
    # display-disabled or mod-disabled GSC restores its preference and leaves
    # Custom Tier effective; returning GSC is constrained again in custom mode.
    lua.globals().god_stat_checker_enabled = True
    settings.god_stat_checker_background_owner = "custom_tier"
    integration.on_setting_changed(mod, "god_stat_checker_background_owner")
    gsc.set(gsc, "opt_display_enabled", False, True)
    assert integration.god_stat_checker_owns_background() is False
    display_off_color, _ = items.gsc_original_rarity_color(qualifying)
    assert color_channels(display_off_color) == [255, 210, 30, 40]
    gsc.set(gsc, "opt_display_enabled", True, True)
    assert gsc_settings.opt_card_style == "verdict_text_only"

    lua.globals().god_stat_checker_enabled = False
    gsc.on_disabled()
    assert gsc_settings.opt_card_style == "verdict_all"
    lua.globals().god_stat_checker_enabled = True
    gsc.on_enabled()
    assert gsc_settings.opt_card_style == "verdict_text_only"

    settings.custom_tier_enabled = False
    assert integration.on_setting_changed(mod, "custom_tier_enabled") is True
    assert gsc_settings.opt_card_style == "verdict_all"
    settings.custom_tier_enabled = True
    integration.on_setting_changed(mod, "custom_tier_enabled")
    assert gsc_settings.opt_card_style == "verdict_text_only"

    # Invalid persisted owner values normalize to the safe default. Settings
    # reset uses the same primary-to-mirror synchronization contract.
    settings.god_stat_checker_background_owner = "future_unknown_owner"
    integration.on_setting_changed(mod, "god_stat_checker_background_owner")
    assert settings.god_stat_checker_background_owner == "custom_tier"
    assert settings.custom_tier_god_stat_checker_background_owner == "custom_tier"
    assert integration.on_settings_reset(mod) is True

    # Optional seams fail closed: an exception in Custom Tier's color provider
    # returns the native pair, and a temporarily missing GSC capture is ignored.
    lua.execute(
        '''
        saved_custom_tier_background_color = custom_tier_module.background_color
        custom_tier_module.background_color = function() error("provider failure") end
        '''
    )
    provider_failure_color, _ = items.gsc_original_rarity_color(qualifying)
    assert color_channels(provider_failure_color) == [255, 145, 70, 40]
    lua.execute(
        "custom_tier_module.background_color = saved_custom_tier_background_color"
    )
    saved_gsc_original = items.gsc_original_rarity_color
    items.gsc_original_rarity_color = None
    assert integration._test.patch_gsc_original_rarity_color() is False
    items.gsc_original_rarity_color = saved_gsc_original
    assert integration._test.patch_gsc_original_rarity_color() is True

    # If GSC disappears after installation, no stale cached mod object may keep
    # ownership. The captured fallback still resolves Custom Tier safely.
    lua.globals().god_stat_checker_installed = False
    assert integration._test.reconcile() is False
    absent_color, _ = items.gsc_original_rarity_color(qualifying)
    assert color_channels(absent_color) == [255, 210, 30, 40]
    assert integration.god_stat_checker_owns_background() is False

    assert integration.on_setting_changed(mod, "unrelated_setting") is False
    print("BetterInventory God Stat Checker integration tests passed.")


if __name__ == "__main__":
    main()
