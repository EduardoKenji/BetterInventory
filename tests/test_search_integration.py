from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_search_integration.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        begins = 0
        cleanups = 0
        configured_sorts = 0
        requested_resorts = 0
        projected_releases = 0
        release_all_calls = 0
        clear_memory_calls = 0

        stub_query = {
            normalize = function(value) return string.lower(tostring(value or "")) end,
        }
        stub_index = {
            new = function(dependencies)
                last_index_dependencies = dependencies
                return {dependencies = dependencies}
            end,
            project = function() return {text = {"item"}}, true end,
            invalidate = function() return true end,
            invalidate_all = function() return true end,
            rarity_aliases = function() return {} end,
            release = function()
                projected_releases = projected_releases + 1
                return true
            end,
        }
        stub_runtime = {
            new = function(dependencies)
                runtime_instance = {dependencies = dependencies, states = {}}
                return runtime_instance
            end,
            capture_presentation = function(runtime, view, slot, item_type, title)
                runtime.index = runtime.index or runtime.dependencies.new_index(view)
                runtime.capture = {view, slot, item_type, title}
                return true
            end,
            compose_layout = function(runtime, view, layout)
                runtime.composed = {view, layout}
                return layout
            end,
            apply_widget_alpha = function() return true end,
            clear_memory = function() clear_memory_calls = clear_memory_calls + 1 end,
            native_filter = function(_, _, _, native) return native end,
            invalidate_all = function() return true end,
            is_active = function() return true end,
            query = function() return "sword" end,
            rank = function(_, _, entry) return entry and entry.match and 1 or 0 end,
            release = function() return true end,
            release_all = function()
                release_all_calls = release_all_calls + 1
                return 3
            end,
            set_query = function(_, _, query)
                return query ~= "bad", query == "bad" and "invalid" or nil
            end,
            update = function() return true end,
        }
        stub_discard = {
            equipped_gear_ids = function()
                return {loadout_weapon = true}
            end,
            is_perfect_roll_weapon = function(item)
                return item and item.perfect == true
            end,
        }
        stub_items = {
            is_item_id_favorited = function() return false end,
        }
        stub_master_items = {}
        stub_profile_utils = {
            get_profile_presets = function() return {} end,
        }
        stub_rarity_settings = {}
        function require(path)
            if path == "scripts/utilities/items" then return stub_items end
            if path == "scripts/backend/master_items" then return stub_master_items end
            if path == "scripts/utilities/profile_utils" then return stub_profile_utils end
            if path == "scripts/settings/item/rarity_settings" then return stub_rarity_settings end
            error(path)
        end
        test_settings = {
            enable_inventory_search = true,
            inventory_search_non_match_behavior = "dim",
            inventory_search_remember_query = false,
        }
        test_mod = {
            get = function(_, setting)
                return test_settings[setting]
            end,
        }
        function get_mod()
            return {
                io_dofile = function(_, path)
                    if string.find(path, "search_query", 1, true) then return stub_query end
                    if string.find(path, "search_index", 1, true) then return stub_index end
                    if string.find(path, "search_runtime", 1, true) then return stub_runtime end
                    if string.find(path, "discard_policy", 1, true) then return stub_discard end
                    error(path)
                end,
            }
        end
        ''',
    )
    integration = lua.execute(MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH))
    lua.execute(
        r'''
        legacy_warning = nil
        warning_mod = {warning = function(_, message) legacy_warning = message end}
        legacy_mod = {is_enabled = function() return true end}
        legacy_resolver = function(name)
            return name == "stuff_searcher" and legacy_mod or nil
        end
        ''',
    )
    assert integration.warn_legacy_searcher(lua.globals().warning_mod, None) is False
    assert integration.warn_legacy_searcher(
        lua.globals().warning_mod, lua.globals().legacy_resolver
    ) is True
    assert "Stuff Searcher" in lua.globals().legacy_warning
    assert integration.warn_legacy_searcher(
        lua.globals().warning_mod, lua.globals().legacy_resolver
    ) is False

    def family(class_name: str, service=None):
        view = lua.table_from({"__class_name": class_name})
        if service is not None:
            view._optional_store_service = service
        return integration.view_family(view, "global")

    assert family("InventoryWeaponsView") == "inventory"
    assert family("CraftingMechanicusModifyView") == "hadron"
    assert family("CraftingMechanicusBarterItemsView") == "hadron_sacrifice"
    assert family("MarksVendorView") == "melk"
    assert family("MarksGoodsVendorView") == "melk"
    assert family("CreditsVendorView") == "armoury"
    assert family("CreditsVendorView", "global") == "armoury"
    assert family("CreditsVendorView", "other") == "vendor"
    assert family("CreditsGoodsVendorView") == "vendor"
    assert family("CosmeticsVendorView") is None
    unavailable = lua.table_from(
        {
            "__class_name": "InventoryWeaponsView",
            "_better_inventory_search_ui_unavailable": True,
        }
    )
    assert integration.view_family(unavailable, "global") is None

    lua.execute(
        r'''
        facade = {
            begin_view_session = function() begins = begins + 1 end,
            register_view_session_cleanup = function(_, _, callback)
                cleanups = cleanups + 1
                registered_cleanup = callback
            end,
            request_inventory_resort = function() requested_resorts = requested_resorts + 1 end,
        }
        providers = {
            CustomTier = {matches = function() return false end},
            ItemCustomization = {get = function() return nil end},
        }
        ''',
    )
    facade = lua.globals().facade
    installed = integration.install(
        facade,
        lua.globals().test_mod,
        lua.globals().providers,
        lua.eval("function() configured_sorts = configured_sorts + 1 end"),
        "global",
    )
    assert installed is True

    view = lua.table_from({"__class_name": "InventoryWeaponsView"})
    assert facade.search_capture_presentation(None, view, "slot", "weapon", "Weapons") is True
    assert lua.globals().begins == 1
    assert lua.globals().cleanups == 1
    assert lua.globals().configured_sorts == 1
    assert lua.globals().runtime_instance.capture[2] == "slot"
    assert lua.globals().last_index_dependencies.custom_tier is not None
    assert lua.execute("return last_index_dependencies.items == stub_items") is True
    lua.execute(
        r'''
        customization_value = last_index_dependencies.customization_get("item")
        equipped_item = {gear_id = "equipped", slots = {"slot_primary"}}
        direct_equipped_view = {
            is_item_equipped_in_any_slot = function() return true end,
        }
        fallback_equipped_view = {
            equipped_item_in_slot = function() return {gear_id = "equipped"} end,
        }
        direct_equipped = last_index_dependencies.is_equipped(
            equipped_item, {view = direct_equipped_view}
        )
        fallback_equipped = last_index_dependencies.is_equipped(
            equipped_item, {view = fallback_equipped_view}
        )
        missing_equipped = last_index_dependencies.is_equipped({}, {})
        loadout_match = last_index_dependencies.is_loadout({gear_id = "loadout_weapon"})
        new_match = last_index_dependencies.is_new({}, {entry = {new_item_marker = true}})

        normal_present_view = {
            _present_layout_by_slot_filter = function(_, slot, item_type, title)
                normal_present_arguments = {slot, item_type, title}
            end,
        }
        valid_present = runtime_instance.dependencies.present(
            normal_present_view, "slot", "weapon", "Weapons"
        )
        invalid_present = runtime_instance.dependencies.present({}, nil, nil, nil)
        invalid_external_present = runtime_instance.dependencies.present_external({})
        current_mode = runtime_instance.dependencies.mode()
        remember_mode = runtime_instance.dependencies.remember_query()
        ''',
    )
    assert lua.globals().customization_value is None
    assert lua.globals().direct_equipped is True
    assert lua.globals().fallback_equipped is True
    assert lua.globals().missing_equipped is False
    assert lua.globals().loadout_match is True
    assert lua.globals().new_match is True
    assert lua.globals().valid_present is True
    assert lua.globals().invalid_present is False
    assert lua.globals().invalid_external_present is False
    assert lua.globals().normal_present_arguments[1] == "slot"
    assert lua.globals().current_mode == "dim"
    assert lua.globals().remember_mode is False

    assert facade.search_query(view) == "sword"
    assert facade.search_rank(view, lua.table_from({"match": True})) == 1
    assert facade.search_filter_result(view, {}, True) is True
    assert facade.search_apply_widget_alpha(view) is True
    assert facade.search_invalidate_all(view, 1) is True
    assert facade.search_is_active(view) is True
    assert facade.search_update(view, 1) is True
    assert facade.search_set_query(view, "axe", 1) == (True, None)
    assert lua.globals().requested_resorts == 1

    sacrifice = lua.table_from({"__class_name": "CraftingMechanicusBarterItemsView"})
    layout = lua.table_from({1: lua.table_from({"item": lua.table_from({})})})
    lua.globals().sacrifice_layout = layout
    lua.globals().composed_layout = facade.search_compose_layout(sacrifice, layout)
    assert lua.execute("return sacrifice_layout == composed_layout") is True
    assert lua.globals().begins == 2
    assert lua.globals().cleanups == 2
    assert facade.search_set_query(sacrifice, "axe", 1) == (True, None)
    assert lua.globals().requested_resorts == 1
    lua.execute(
        r'''
        external_sort_calls = 0
        external_view = {
            _sort_options = {{sort_function = "sort"}},
            _sort_grid_layout = function(self, sort_function)
                external_sort_calls = external_sort_calls + 1
                external_sort_function = sort_function
            end,
        }
        external_present_result = runtime_instance.dependencies.present_external(external_view)
        ''',
    )
    assert lua.globals().external_present_result is True
    assert lua.globals().external_sort_calls == 1
    assert lua.globals().external_sort_function == "sort"

    lua.execute("runtime_instance.states[facade_state_view or {}] = nil")
    state_view = lua.table_from({"__class_name": "InventoryWeaponsView"})
    lua.globals().state_view = state_view
    lua.execute("runtime_instance.states[state_view] = true")
    assert facade.search_settings_changed("unrelated") == 0
    assert facade.search_settings_changed("customization_changed") == 1
    assert lua.globals().requested_resorts == 2
    lua.globals().test_settings.inventory_search_remember_query = False
    assert facade.search_settings_changed("inventory_search_remember_query") == 0
    assert lua.globals().clear_memory_calls == 1
    lua.globals().test_settings.enable_inventory_search = False
    assert facade.search_settings_changed("enable_inventory_search") == 3
    assert lua.globals().release_all_calls == 1
    assert lua.globals().clear_memory_calls == 2
    lua.globals().test_settings.enable_inventory_search = True
    assert facade.search_set_query(view, "bad", 1) == (False, "invalid")
    assert lua.globals().requested_resorts == 2

    lua.globals().registered_cleanup(view)
    assert facade.search_shutdown(True) == 3
    assert lua.globals().release_all_calls == 2
    assert lua.globals().clear_memory_calls == 3

    print("BetterInventory search integration tests passed.")


if __name__ == "__main__":
    main()
