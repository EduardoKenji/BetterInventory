from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
DMF_LOADER = (
    PROJECT_ROOT.parents[1]
    / "mods"
    / "dmf"
    / "scripts"
    / "mods"
    / "dmf"
    / "dmf_loader.lua"
)


def read_runtime(name: str) -> str:
    return (RUNTIME_ROOT / name).read_text(encoding="utf-8")


def main() -> None:
    runtime = read_runtime("BetterInventory_runtime.lua")
    bootstrap = read_runtime("BetterInventory.lua")
    customization = read_runtime("BetterInventory_item_customization.lua")
    curio_acquisition = read_runtime("BetterInventory_curio_acquisition.lua")
    search_ui = read_runtime("BetterInventory_search_ui.lua")
    dmf_loader = DMF_LOADER.read_text(encoding="utf-8")

    # DMF calls on_unload before it removes hooks and recreates live views.
    # Better Inventory must therefore relinquish every view/global callback at
    # this boundary, while ordinary disable retains its Name It handoff.
    assert dmf_loader.index("dmf.mods_unload_event(false)") < dmf_loader.index(
        "dmf.hooks_unload()"
    )
    assert "local function shutdown(unloading)" in runtime
    assert "function mod.on_disabled(_initial_call)" in runtime
    assert "shutdown(false)" in runtime
    assert "function mod.on_unload(_exit_game)" in runtime
    assert "shutdown(true)" in runtime
    assert "RuntimeLifecycle.release_all(reason)" in runtime
    assert "Features.close_all_view_sessions(reason)" in runtime
    assert "ItemCustomization.on_unload(mod)" in runtime
    assert "ItemCustomization.on_unload = function(mod)" in customization
    assert "Store.release_runtime()" in customization
    assert "SearchUI.release_all = function()" in search_ui
    assert "CurioAcquisition.cancel(unloading)" in runtime
    assert "CurioAcquisition.cancel = function(unloading)" in curio_acquisition
    assert "reopen == false and nil or new_read_promise_container()" in curio_acquisition
    assert 'rawget(_G, "AutoCrafterHelperHudState") == auto_crafter_hud_bridge' in bootstrap
    assert 'rawset(_G, "AutoCrafterHelperHudState", nil)' in bootstrap

    # Normal Darktide sort-option rebuilding remains force-adopted; the update
    # path only repairs a surviving view once per newly loaded module generation.
    assert "RuntimeLifecycle.adopt_inventory(view, true)" in runtime
    assert "RuntimeLifecycle.adopt_inventory(view)" in runtime
    assert "RuntimeLifecycle.adopt_armoury(view, family, true)" in runtime

    lua = LuaRuntime(unpack_returned_tuples=True)
    lifecycle = lua.execute(
        read_runtime("BetterInventory_runtime_lifecycle.lua"),
        name=str(RUNTIME_ROOT / "BetterInventory_runtime_lifecycle.lua"),
    )
    lua.globals().Lifecycle = lifecycle
    lua.execute(
        r'''
        calls = {
            inventory_config = 0,
            inventory_setup = 0,
            inventory_bind = 0,
            inventory_release = 0,
            armoury_config = 0,
            global_config = 0,
            armoury_setup = 0,
            armoury_release = 0,
            search_release = 0,
            search_release_all = 0,
        }
        settings = {
            enable_armoury_requisition_grid = true,
            enable_armoury_requisition_sorting_panel = true,
            enable_global_store_integration = true,
            enable_global_store_grid = true,
            enable_global_store_sorting_panel = true,
        }
        test_mod = {get = function(_, id) return settings[id] end}
        features = {
            configure_inventory_sort_options = function() calls.inventory_config = calls.inventory_config + 1 end,
            setup_inventory_options_panel = function() calls.inventory_setup = calls.inventory_setup + 1 end,
            bind_inventory_sort_toggle = function() calls.inventory_bind = calls.inventory_bind + 1 end,
            unregister_inventory_view = function(view)
                local panel = view._widgets_by_name.better_inventory_panel
                if panel then
                    assert(panel.content.pressed_callback == nil)
                    assert(panel.content.hotspot.pressed_callback == nil)
                end
                calls.inventory_release = calls.inventory_release + 1
            end,
            configure_armoury_sort_options = function() calls.armoury_config = calls.armoury_config + 1 end,
            configure_global_store_sort_options = function() calls.global_config = calls.global_config + 1 end,
            setup_armoury_native_sort_panel = function() calls.armoury_setup = calls.armoury_setup + 1 end,
            unregister_armoury_view = function() calls.armoury_release = calls.armoury_release + 1 end,
        }
        search_ui = {
            release = function() calls.search_release = calls.search_release + 1 end,
            release_all = function() calls.search_release_all = calls.search_release_all + 1 end,
        }
        Lifecycle.configure({
            Features = features,
            Layout = {},
            SearchUI = search_ui,
            ViewElementGrid = {},
            mod = test_mod,
        })
        inventory_view = {
            _widgets_by_name = {
                better_inventory_panel = {
                    content = {
                        pressed_callback = function() end,
                        hotspot = {pressed_callback = function() end},
                    },
                },
            },
        }
        assert(Lifecycle.adopt_inventory(inventory_view) == true)
        assert(Lifecycle.adopt_inventory(inventory_view) == false)
        assert(calls.inventory_config == 1 and calls.inventory_setup == 1 and calls.inventory_bind == 1)
        assert(Lifecycle.adopt_inventory(inventory_view, true) == true)
        assert(calls.inventory_config == 2 and calls.inventory_setup == 2 and calls.inventory_bind == 2)

        global_view = {_widgets_by_name = {}}
        settings.enable_global_store_integration = false
        assert(Lifecycle.adopt_armoury(global_view, "global_store") == false)
        assert(global_view._better_inventory_runtime_generation == nil)
        settings.enable_global_store_integration = true
        assert(Lifecycle.adopt_armoury(global_view, "global_store") == true)
        assert(calls.global_config == 1 and calls.armoury_setup == 1)

        armoury_view = {_widgets_by_name = {unrelated_widget = {content = {}}}}
        assert(Lifecycle.adopt_armoury(armoury_view, "armoury") == true)
        assert(Lifecycle.adopt_armoury(armoury_view, "unsupported") == false)
        assert(calls.armoury_config == 1 and calls.armoury_setup == 2)
        assert(Lifecycle.adopt_inventory({_destroyed = true}) == false)
        assert(type(Lifecycle.generation()) == "table")

        assert(Lifecycle.release_all("mod_reload") == 3)
        assert(calls.inventory_release == 1 and calls.armoury_release == 2)
        assert(calls.search_release == 3 and calls.search_release_all == 1)
        assert(inventory_view._better_inventory_runtime_generation == nil)
        assert(global_view._better_inventory_runtime_generation == nil)
        assert(Lifecycle.release_all("mod_reload") == 0)
        assert(calls.inventory_release == 1 and calls.armoury_release == 2)
        assert(calls.search_release_all == 2)
        assert(Lifecycle.adopt_inventory(inventory_view) == true)
        assert(calls.inventory_config == 3)
        assert(Lifecycle.release_all("mod_reload") == 1)

        Lifecycle.configure(nil)
        assert(Lifecycle.adopt_inventory({}) == false)
        Lifecycle.configure({Features = features, Layout = {}, ViewElementGrid = {}, mod = test_mod})
        local no_search_view = {_widgets_by_name = {}}
        assert(Lifecycle.adopt_inventory(no_search_view) == true)
        assert(Lifecycle.release_all("mod_reload") == 1)
        ''',
    )
    assert lua.execute("return calls.inventory_release") == 3
    assert lua.execute("return calls.search_release_all") == 3

    store = lua.execute(
        read_runtime("BetterInventory_item_customization_store.lua"),
        name=str(RUNTIME_ROOT / "BetterInventory_item_customization_store.lua"),
    )
    lua.globals().Store = store
    lua.execute(
        r'''
        Store.cache_records({gear = {name = "owned"}})
        Store.queue_deleted_gear("deleted")
        Store.mark_persistence_pending()
        assert(Store.get(nil, "gear").name == "owned")
        assert(Store.has_pending_deleted_gear() == true)
        Store.release_runtime()
        local outcome, pending = Store.persistence_status()
        assert(Store.get(nil, "gear") == nil)
        assert(Store.has_pending_deleted_gear() == false)
        assert(outcome == "idle" and pending == false)
        ''',
    )

    print("BetterInventory hot-reload lifecycle checks passed.")


if __name__ == "__main__":
    main()
