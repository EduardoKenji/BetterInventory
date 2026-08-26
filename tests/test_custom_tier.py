from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_custom_tier.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        custom_tier_settings = {
            custom_tier_enabled = true,
            custom_tier_color_r = 210,
            custom_tier_color_g = 30,
            custom_tier_color_b = 40,
            custom_tier_color_preview = {255, 210, 30, 40},
            custom_tier_melee_enabled = true,
            custom_tier_melee_min_power = 500,
            custom_tier_melee_min_base_stat_total = 0,
            custom_tier_melee_min_modifier = 0,
            custom_tier_melee_required_high_stats = 0,
            custom_tier_melee_high_stat_threshold = 80,
            custom_tier_ranged_enabled = true,
            custom_tier_ranged_min_power = 500,
            custom_tier_ranged_min_base_stat_total = 0,
            custom_tier_ranged_min_modifier = 0,
            custom_tier_ranged_required_high_stats = 0,
            custom_tier_ranged_high_stat_threshold = 80,
            custom_tier_curio_health_enabled = true,
            custom_tier_curio_health_min_roll = 21,
            custom_tier_curio_health_min_power = 0,
            custom_tier_curio_toughness_enabled = true,
            custom_tier_curio_toughness_min_roll = 17,
            custom_tier_curio_toughness_min_power = 0,
            custom_tier_curio_stamina_enabled = true,
            custom_tier_curio_stamina_min_roll = 3,
            custom_tier_curio_stamina_min_power = 0,
            custom_tier_curio_wounds_enabled = true,
            custom_tier_curio_wounds_min_roll = 1,
            custom_tier_curio_wounds_min_power = 0,
        }
        custom_tier_mod_enabled = true
        custom_tier_is_enabled_calls = 0
        custom_tier_mod = {
            get = function(_, setting_id) return custom_tier_settings[setting_id] end,
            set = function(_, setting_id, value) custom_tier_settings[setting_id] = value end,
            is_enabled = function()
                custom_tier_is_enabled_calls = custom_tier_is_enabled_calls + 1
                return custom_tier_mod_enabled
            end,
            io_dofile = function(_, path)
                if string.find(path, "BetterInventory_curio_values", 1, true) then
                    return {
                        resolve = function(entry)
                            if entry.raise then error("malformed trait") end
                            return entry.trait_name, entry.roll
                        end,
                    }
                end
            end,
        }
        red_weapons_installed = false
        red_weapons_mod_enabled = true
        red_weapons_settings = {
            rarity_color_6_red = 12,
            rarity_color_6_green = 34,
            rarity_color_6_blue = 56,
            gadget_health_required_expertise = 401,
            gadget_toughness_required_expertise = 402,
            gadget_stamina_required_expertise = 403,
            gadget_wound_required_expertise = 404,
        }
        red_weapons_mod = {
            get = function(_, setting_id) return red_weapons_settings[setting_id] end,
            is_sainted_item = function(item) return item and item.red_eligible == true end,
        }
        function get_mod(name)
            if name == "BetterInventory" then return custom_tier_mod end
            if name == "red_weapons_at_home" and red_weapons_installed then return red_weapons_mod end
        end
        function Localize(key)
            if key == "loc_item_weapon_rarity_6" then return "Sainted" end
            return key
        end

        test_items = {
            expertise_level = function(item) return tostring(item and item.expertise or 0), true end,
            total_stats_value = function(item)
                local total = 0
                for index = 1, #(item.base_stats or {}) do
                    total = total + item.base_stats[index].value
                end
                return math.floor(total * 100 + 0.5)
            end,
            rarity_color = function() return {255, 145, 70, 40}, {255, 87, 42, 24} end,
            rarity_display_name = function() return "Transcendent" end,
        }
        package.preload["scripts/utilities/items"] = function() return test_items end

        -- Reproduce Red Weapons At Home wrapping native Items before
        -- BetterInventory loads. The installed flag lets the same fixture prove
        -- both standalone behavior and simultaneous-mod ownership.
        local native_color = test_items.rarity_color
        local native_name = test_items.rarity_display_name
        test_items.rarity_color = function(item)
            if red_weapons_installed and red_weapons_mod_enabled and red_weapons_mod.is_sainted_item(item) then
                return {255, 200, 1, 2}, {255, 120, 1, 1}
            end
            return native_color(item)
        end
        test_items.rarity_display_name = function(item)
            if red_weapons_installed and red_weapons_mod_enabled and red_weapons_mod.is_sainted_item(item) then
                return "Red Weapons tier"
            end
            return native_name(item)
        end

        function weapon(item_type, expertise, values)
            local base_stats = {}
            for index = 1, #(values or {}) do
                base_stats[index] = {name = "stat_" .. tostring(index), value = values[index] / 100}
            end
            return {
                rarity = 5,
                item_type = item_type,
                expertise = expertise,
                base_stats = base_stats,
            }
        end
        function curio(trait_name, roll, expertise)
            return {
                rarity = 5,
                item_type = "GADGET",
                expertise = expertise or 0,
                traits = {{id = "trait-item", trait_name = trait_name, roll = roll}},
            }
        end
        '''
    )
    custom_tier = lua.execute(
        MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH)
    )
    lua.globals().custom_tier = custom_tier
    mod = lua.globals().custom_tier_mod
    settings = lua.globals().custom_tier_settings
    items = lua.globals().test_items
    lua_weapon = lua.globals().weapon

    def weapon(item_type, expertise, values):
        return lua_weapon(item_type, expertise, lua.table_from(values))

    curio = lua.globals().curio

    assert custom_tier.reference_red[1] == 210
    assert custom_tier.reference_red[2] == 30
    assert custom_tier.reference_red[3] == 40
    assert custom_tier.install(mod) is True
    assert settings._custom_tier_red_weapons_at_home_import_v1 is None

    # DMF's native preview is bidirectionally synchronized with the legacy RGB
    # settings so presets, sliders, and direct preview edits share one color.
    settings.custom_tier_color_preview = lua.table_from([255, 12, 34, 56])
    assert custom_tier.on_setting_changed(mod, "custom_tier_color_preview") is True
    assert settings.custom_tier_color_preset == "custom"
    assert [settings[f"custom_tier_color_{channel}"] for channel in ("r", "g", "b")] == [12, 34, 56]
    preview_color, _ = items.rarity_color(weapon("WEAPON_MELEE", 500, []))
    assert [preview_color[index] for index in range(1, 5)] == [255, 12, 34, 56]
    settings.custom_tier_color_b = 78
    custom_tier.on_setting_changed(mod, "custom_tier_color_b")
    assert [settings.custom_tier_color_preview[index] for index in range(1, 5)] == [255, 12, 34, 78]
    settings.custom_tier_color_preview = lua.table_from([255, 210, 30, 40])
    custom_tier.on_setting_changed(mod, "custom_tier_color_preview")

    lua.execute('custom_tier_mod.is_enabled = function() error("disabled-state unavailable") end')
    custom_tier._test.refresh_framework_enabled()
    assert custom_tier._test.feature_active() is False
    lua.execute(
        "custom_tier_mod.is_enabled = function() "
        "custom_tier_is_enabled_calls = custom_tier_is_enabled_calls + 1; "
        "return custom_tier_mod_enabled end"
    )
    custom_tier.refresh(mod)

    perfect_melee = weapon("WEAPON_MELEE", 500, [80, 80, 80, 80, 60])
    perfect_ranged = weapon("WEAPON_RANGED", 500, [80, 80, 80, 80, 60])
    assert custom_tier.matches(perfect_melee) is True
    assert custom_tier.matches(perfect_ranged) is True
    assert custom_tier.matches(weapon("WEAPON_MELEE", 490, [80, 80, 80, 80, 60])) is False
    lower_rarity = weapon("WEAPON_MELEE", 500, [80, 80, 80, 80, 60])
    lower_rarity.rarity = 4
    assert custom_tier.matches(lower_rarity) is False

    custom_color, custom_dark = items.rarity_color(perfect_melee)
    assert [custom_color[index] for index in range(1, 5)] == [255, 210, 30, 40]
    assert [custom_dark[index] for index in range(1, 5)] == [255, 126, 18, 24]
    assert items.rarity_display_name(perfect_melee) == "Sainted"
    assert lua.execute(
        "local left = test_items.rarity_color(...); local right = test_items.rarity_color(...); return left == right",
        perfect_melee,
        perfect_melee,
    ) is True

    # The compatibility provider can hand background ownership to God Stat
    # Checker without surrendering Custom Tier's Sainted classification/name.
    lua.execute(
        '''
        god_stat_checker_owns_background = false
        custom_tier.set_background_owner_provider({
            god_stat_checker_owns_background = function()
                return god_stat_checker_owns_background
            end,
        })
        '''
    )
    lua.globals().god_stat_checker_owns_background = True
    deferred_color, _ = items.rarity_color(perfect_melee)
    assert [deferred_color[index] for index in range(1, 5)] == [255, 145, 70, 40]
    assert items.rarity_display_name(perfect_melee) == "Sainted"
    lua.globals().god_stat_checker_owns_background = False

    # The framework enabled state is refreshed only at lifecycle/settings
    # boundaries. Repeated card colour/name lookups do not call back into DMF.
    enabled_checks_before_cards = lua.globals().custom_tier_is_enabled_calls
    for _ in range(100):
        items.rarity_color(perfect_melee)
        items.rarity_display_name(perfect_melee)
    assert lua.globals().custom_tier_is_enabled_calls == enabled_checks_before_cards
    assert "local values = {}" not in MODULE_PATH.read_text(encoding="utf-8")

    # Reference Curio behavior: all four primary types, maximum default rolls,
    # Transcendent rarity, and no minimum Power requirement.
    curio_cases = [
        ("gadget_innate_health_increase", 21),
        ("gadget_innate_toughness_increase", 17),
        ("gadget_stamina_increase", 3),
        ("gadget_innate_max_wounds_increase", 1),
    ]
    for trait_name, roll in curio_cases:
        assert custom_tier.matches(curio(trait_name, roll, 0)) is True
    assert custom_tier.matches(curio("gadget_innate_health_increase", 20, 500)) is False
    assert custom_tier.matches(curio("future_unknown_primary", 99, 500)) is False
    malformed_curio = curio("gadget_innate_health_increase", 21, 500)
    malformed_curio.traits[1]["raise"] = True
    assert custom_tier.matches(malformed_curio) is False

    # Optional base-stat filters are independent and fail closed when enabled.
    settings.custom_tier_melee_min_power = 450
    settings.custom_tier_melee_min_base_stat_total = 380
    settings.custom_tier_melee_min_modifier = 60
    settings.custom_tier_melee_required_high_stats = 4
    settings.custom_tier_melee_high_stat_threshold = 80
    assert custom_tier.on_setting_changed(mod, "custom_tier_melee_min_power") is True
    assert custom_tier.matches(weapon("WEAPON_MELEE", 450, [80, 80, 80, 80, 60])) is True
    assert custom_tier.matches(weapon("WEAPON_MELEE", 450, [80, 80, 80, 79, 61])) is False
    assert custom_tier.matches(weapon("WEAPON_MELEE", 450, [80, 80, 80, 81, 59])) is False
    missing_stats = weapon("WEAPON_MELEE", 500, [])
    assert custom_tier.matches(missing_stats) is False

    settings.custom_tier_curio_health_min_power = 450
    assert custom_tier.on_setting_changed(mod, "custom_tier_curio_health_min_power") is True
    assert custom_tier.matches(curio("gadget_innate_health_increase", 21, 440)) is False
    assert custom_tier.matches(curio("gadget_innate_health_increase", 21, 450)) is True
    settings.custom_tier_curio_health_enabled = False
    custom_tier.on_setting_changed(mod, "custom_tier_curio_health_enabled")
    assert custom_tier.matches(curio("gadget_innate_health_increase", 21, 500)) is False

    # Detect Red Weapons At Home after its script has loaded. Untouched settings
    # receive a one-time import, while an already-customized BetterInventory field
    # is preserved. BetterInventory then remains the single authoritative owner.
    settings.custom_tier_color_preset = "custom_tier_red"
    settings.custom_tier_color_r = 210
    settings.custom_tier_color_g = 30
    settings.custom_tier_color_b = 40
    settings.custom_tier_color_preview = lua.table_from([255, 210, 30, 40])
    lua.globals().red_weapons_installed = True
    custom_tier.install(mod)
    assert settings._custom_tier_red_weapons_at_home_import_v1 is True
    assert settings.custom_tier_color_preset == "custom"
    assert [settings[f"custom_tier_color_{channel}"] for channel in ("r", "g", "b")] == [12, 34, 56]
    assert [settings.custom_tier_color_preview[index] for index in range(1, 5)] == [255, 12, 34, 56]
    assert settings.custom_tier_curio_health_min_power == 450
    assert settings.custom_tier_curio_toughness_min_power == 402
    assert settings.custom_tier_curio_stamina_min_power == 403
    assert settings.custom_tier_curio_wounds_min_power == 404

    red_only = weapon("WEAPON_MELEE", 100, [20, 20, 20, 20, 20])
    red_only.red_eligible = True
    base_color, _ = items.rarity_color(red_only)
    assert [base_color[index] for index in range(1, 5)] == [255, 145, 70, 40]
    assert items.rarity_display_name(red_only) == "Transcendent"

    red_matching = weapon("WEAPON_RANGED", 500, [80, 80, 80, 80, 60])
    red_matching.red_eligible = True
    imported_color, _ = items.rarity_color(red_matching)
    assert [imported_color[index] for index in range(1, 5)] == [255, 12, 34, 56]
    assert items.rarity_display_name(red_matching) == "Sainted"

    # Disabling BetterInventory's feature still restores Red Weapons At Home.
    settings.custom_tier_enabled = False
    custom_tier.on_setting_changed(mod, "custom_tier_enabled")
    restored_color, _ = items.rarity_color(red_only)
    assert [restored_color[index] for index in range(1, 5)] == [255, 200, 1, 2]
    assert items.rarity_display_name(red_only) == "Red Weapons tier"

    # Reinstallation is idempotent and does not create a recursive wrapper.
    settings.custom_tier_enabled = True
    lua.globals().red_weapons_settings.rarity_color_6_red = 222
    custom_tier.install(mod)
    custom_tier.install(mod)
    repeated_color, _ = items.rarity_color(perfect_ranged)
    assert [repeated_color[index] for index in range(1, 5)] == [255, 12, 34, 56]

    # Exact late-install/hot-reload order from the Armoury crash: GSC loads
    # after BI, captures BI's current wrappers, and installs wrappers which
    # call those captured globals dynamically. BI must detach its old wrappers
    # before reinstalling or the two mods recurse until Lua's stack overflows.
    lua.execute(
        '''
        test_items.gsc_original_rarity_color = test_items.rarity_color
        test_items.gsc_original_rarity_display_name = test_items.rarity_display_name
        test_items.rarity_color = function(item)
            return test_items.gsc_original_rarity_color(item)
        end
        test_items.rarity_display_name = function(item)
            return test_items.gsc_original_rarity_display_name(item)
        end
        '''
    )
    custom_tier.install(mod)
    late_gsc_color, _ = items.rarity_color(perfect_ranged)
    assert [late_gsc_color[index] for index in range(1, 5)] == [255, 12, 34, 56]
    late_gsc_plain_color, _ = items.rarity_color(weapon("WEAPON_MELEE", 100, []))
    assert [late_gsc_plain_color[index] for index in range(1, 5)] == [255, 145, 70, 40]
    assert items.rarity_display_name(perfect_ranged) == "Sainted"
    assert items.rarity_display_name(weapon("WEAPON_MELEE", 100, [])) == "Transcendent"

    custom_tier.on_disabled()
    disabled_color, _ = items.rarity_color(red_only)
    assert [disabled_color[index] for index in range(1, 5)] == [255, 200, 1, 2]
    custom_tier.refresh(mod)
    assert custom_tier.on_setting_changed(mod, "unrelated_setting") is False

    overview_source = (MODULE_PATH.parent / "BetterInventory_character_overview_ui.lua").read_text(encoding="utf-8")
    assert 'string.sub(setting_id, 1, #"custom_tier_") == "custom_tier_"' in overview_source

    print("BetterInventory custom tier tests passed.")


if __name__ == "__main__":
    main()
