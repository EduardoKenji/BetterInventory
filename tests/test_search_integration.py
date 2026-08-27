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
            apply_widget_alpha = function() return true end,
            clear_memory = function() clear_memory_calls = clear_memory_calls + 1 end,
            counts = function() return 4, 9 end,
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
        test_mod = {
            get = function(_, setting)
                if setting == "enable_inventory_search" then return true end
                if setting == "inventory_search_non_match_behavior" then return "dim" end
                return false
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

    def family(class_name: str, service=None):
        view = lua.table_from({"__class_name": class_name})
        if service is not None:
            view._optional_store_service = service
        return integration.view_family(view, "global")

    assert family("InventoryWeaponsView") == "inventory"
    assert family("CraftingMechanicusModifyView") == "hadron"
    assert family("MarksVendorView") == "melk"
    assert family("MarksGoodsVendorView") == "melk"
    assert family("CreditsVendorView") == "armoury"
    assert family("CreditsVendorView", "global") == "armoury"
    assert family("CreditsVendorView", "other") == "vendor"
    assert family("CreditsGoodsVendorView") == "vendor"
    assert family("CosmeticsVendorView") is None

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

    assert facade.search_counts(view) == (4, 9)
    assert facade.search_query(view) == "sword"
    assert facade.search_rank(view, lua.table_from({"match": True})) == 1
    assert facade.search_filter_result(view, {}, True) is True
    assert facade.search_set_query(view, "axe", None, 1) == (True, None)
    assert lua.globals().requested_resorts == 1
    assert facade.search_set_query(view, "bad", None, 1) == (False, "invalid")
    assert lua.globals().requested_resorts == 1

    lua.globals().registered_cleanup(view)
    assert facade.search_shutdown(True) == 3
    assert lua.globals().release_all_calls == 1
    assert lua.globals().clear_memory_calls == 1

    print("BetterInventory search integration tests passed.")


if __name__ == "__main__":
    main()
