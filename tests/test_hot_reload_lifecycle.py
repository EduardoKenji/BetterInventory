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

    # A live grid owns one configured blueprint generation. Reload teardown
    # cancels Darktide's deferred presentation closure, then the replacement
    # module invalidates entry IDs and rebuilds the cards exactly once.
    lua.execute(
        r'''
        managed_grid = {
            _grid_layout = {
                {entry_id = "old_1"},
                {entry_id = "old_2"},
            },
            _widgets_by_entry_id = {
                old_1 = {},
                old_2 = {},
            },
            _present_grid_layout = function() error("retired generation must not run") end,
        }
        Lifecycle.mark_managed_grid(managed_grid)
        old_card_generation = managed_grid._better_inventory_card_runtime_generation
        assert(Lifecycle.release_all("mod_reload") == 0)
        assert(managed_grid._present_grid_layout == nil)
        assert(managed_grid._better_inventory_card_runtime_generation == old_card_generation)
        ''',
    )

    next_lifecycle = lua.execute(
        read_runtime("BetterInventory_runtime_lifecycle.lua"),
        name=str(RUNTIME_ROOT / "BetterInventory_runtime_lifecycle.lua"),
    )
    lua.globals().NextLifecycle = next_lifecycle
    lua.execute(
        r'''
        NextLifecycle.configure({Features = features, Layout = {}, ViewElementGrid = {}, mod = test_mod})
        managed_present_calls = 0
        managed_view = {
            _item_grid = managed_grid,
            present_grid_layout = function(self, layout, callback)
                managed_present_calls = managed_present_calls + 1
                assert(layout[1].entry_id == nil and layout[2].entry_id == nil)
                NextLifecycle.prepare_grid_presentation(self._item_grid, layout)
                NextLifecycle.mark_managed_grid(self._item_grid)
                if callback then callback() end
            end,
        }
        assert(NextLifecycle.adopt_managed_grid(managed_view) == true)
        assert(managed_present_calls == 1)
        assert(managed_grid._better_inventory_card_runtime_generation == NextLifecycle.generation())
        assert(NextLifecycle.adopt_managed_grid(managed_view) == false)
        assert(managed_present_calls == 1)

        -- A grid created by a release that predates generation markers is also
        -- adopted once when v3.5.3 is first loaded through Ctrl+Shift+R.
        legacy_grid = {
            _grid_layout = {{entry_id = "legacy"}},
            _widgets_by_entry_id = {legacy = {}},
        }
        legacy_present_calls = 0
        legacy_view = {
            _item_grid = legacy_grid,
            present_grid_layout = function(self, layout)
                legacy_present_calls = legacy_present_calls + 1
                assert(layout[1].entry_id == nil)
                NextLifecycle.mark_managed_grid(self._item_grid)
            end,
        }
        assert(NextLifecycle.adopt_managed_grid(legacy_view) == true)
        assert(legacy_present_calls == 1)
        assert(NextLifecycle.adopt_managed_grid(legacy_view) == false)

        assert(NextLifecycle.mark_managed_grid(nil) == false)
        assert(NextLifecycle.prepare_grid_presentation(nil, {}) == false)
        assert(NextLifecycle.prepare_grid_presentation({_grid_layout = {}}, {}) == false)
        assert(NextLifecycle.prepare_grid_presentation({_better_inventory_card_runtime_generation = {}}) == false)
        assert(NextLifecycle.adopt_managed_grid(nil) == false)
        assert(NextLifecycle.adopt_managed_grid({_destroyed = true}) == false)
        assert(NextLifecycle.adopt_managed_grid({}) == false)
		assert(NextLifecycle.adopt_managed_grid({_item_grid = {_grid_layout = {}}}) == false)
		assert(NextLifecycle.adopt_managed_grid({
			_item_grid = {_better_inventory_card_runtime_generation = {}},
		}) == false)

		current_grid = {
			_grid_layout = {{entry_id = "current"}},
			_widgets_by_entry_id = {current = {}},
		}
		NextLifecycle.mark_managed_grid(current_grid)
		assert(NextLifecycle.prepare_grid_presentation(current_grid, current_grid._grid_layout) == false)
		assert(NextLifecycle.adopt_managed_grid({_item_grid = current_grid}) == false)

		missing_present_grid = {
			_grid_layout = {{entry_id = "missing-present"}},
			_better_inventory_card_runtime_generation = {},
		}
		assert(NextLifecycle.adopt_managed_grid({_item_grid = missing_present_grid}) == false)
		assert(missing_present_grid._better_inventory_card_rebuild_pending == nil)

        fallback_prepare_grid = {
            _grid_layout = {{entry_id = "fallback"}},
            _better_inventory_card_runtime_generation = {},
        }
        assert(NextLifecycle.prepare_grid_presentation(fallback_prepare_grid) == true)
        assert(fallback_prepare_grid._grid_layout[1].entry_id == nil)
        assert(fallback_prepare_grid._better_inventory_card_rebuild_pending == NextLifecycle.generation())

        failed_grid = {
            _grid_layout = {{entry_id = "failed"}},
            _better_inventory_card_runtime_generation = {},
        }
        failed_view = {
            _item_grid = failed_grid,
            present_grid_layout = function() error("transitional grid") end,
        }
        assert(NextLifecycle.adopt_managed_grid(failed_view) == false)
        assert(failed_grid._better_inventory_card_rebuild_pending == nil)

        callback_grid = {
            _grid_layout = {{entry_id = "callback"}},
            _better_inventory_card_runtime_generation = {},
        }
        callback_present_calls = 0
        callback_completed = 0
        callback_view = {
            _item_grid = callback_grid,
            _cb_on_present = function() callback_completed = callback_completed + 1 end,
            present_grid_layout = function(self, layout, callback)
                callback_present_calls = callback_present_calls + 1
                NextLifecycle.mark_managed_grid(self._item_grid)
                callback()
            end,
        }
        assert(NextLifecycle.adopt_managed_grid(callback_view) == true)
		assert(callback_present_calls == 1 and callback_completed == 1)

		dead_callback_grid = {
			_grid_layout = {{entry_id = "dead-callback"}},
			_better_inventory_card_runtime_generation = {},
		}
		dead_callback_completed = 0
		dead_callback_view = {
			_item_grid = dead_callback_grid,
			_cb_on_present = function() dead_callback_completed = dead_callback_completed + 1 end,
			present_grid_layout = function(self, layout, callback)
				NextLifecycle.mark_managed_grid(self._item_grid)
				self._destroyed = true
				callback()
			end,
		}
		assert(NextLifecycle.adopt_managed_grid(dead_callback_view) == true)
		assert(dead_callback_completed == 0)

		-- Same-generation reorder passes retain the native blueprint identity and
		-- all return values; only membership/generation changes request rebuilding.
		assert(NextLifecycle.prepare_grid_generation(current_grid, current_grid._grid_layout) == false)
		assert(NextLifecycle.prepare_grid_generation({}, {{}}) == true)
		reused_after_calls = 0
		reused_blueprints = {}
		reused_results = NextLifecycle.present_reused_grid(
			function(grid, layout, blueprints, first, second)
				assert(grid == current_grid and layout == current_grid._grid_layout)
				assert(blueprints == reused_blueprints and first == "first" and second == nil)
				return "native", nil, 3
			end,
			current_grid,
			current_grid._grid_layout,
			reused_blueprints,
			{n = 2, [1] = "first"},
			function(grid)
				assert(grid == current_grid)
				reused_after_calls = reused_after_calls + 1
			end
		)
		assert(reused_results.n == 3 and reused_results[1] == "native" and reused_results[2] == nil and reused_results[3] == 3)
		assert(reused_after_calls == 1)

		-- Compact Curio headers are cloned once per source/height tuple, kept on
		-- the owning grid, and dropped deterministically on close or hot reload.
		settings.curio_preview_height_percent = 76
		compact_clone_calls = 0
		compact_features = {
			compact_inventory_curio_stats_blueprints = function(_, _, source)
				compact_clone_calls = compact_clone_calls + 1
				return {gadget_header = {clone = compact_clone_calls}, source = source}
			end,
		}
		compact_source = {gadget_header = {}}
		compact_grid = {}
		compact_first = NextLifecycle.compact_curio_stats_blueprints(test_mod, compact_features, compact_grid, compact_source)
		compact_same = NextLifecycle.compact_curio_stats_blueprints(test_mod, compact_features, compact_grid, compact_source)
		assert(compact_first == compact_same and compact_clone_calls == 1)
		settings.curio_preview_height_percent = 80
		compact_second = NextLifecycle.compact_curio_stats_blueprints(test_mod, compact_features, compact_grid, compact_source)
		assert(compact_second ~= compact_first and compact_clone_calls == 2)
		assert(NextLifecycle.release_compact_curio_stats_blueprints(compact_grid) == true)
		assert(NextLifecycle.release_compact_curio_stats_blueprints(compact_grid) == false)
		passthrough_features = {
			compact_inventory_curio_stats_blueprints = function(_, _, source) return source end,
		}
		assert(NextLifecycle.compact_curio_stats_blueprints(test_mod, passthrough_features, compact_grid, compact_source) == compact_source)
		assert(compact_grid._better_inventory_compact_curio_blueprints == nil)

		NextLifecycle.configure({
			Features = {
				configure_inventory_sort_options = function() end,
				setup_inventory_options_panel = function() end,
				bind_inventory_sort_toggle = function() end,
				unregister_inventory_view = function() end,
			},
			Layout = {},
			ViewElementGrid = {},
			mod = test_mod,
		})
		settings.curio_preview_height_percent = 76
		NextLifecycle.compact_curio_stats_blueprints(test_mod, compact_features, compact_grid, compact_source)
		rootless_view = {_weapon_stats = compact_grid}
		assert(NextLifecycle.adopt_inventory(rootless_view) == true)
		assert(NextLifecycle.release_all("mod_reload") == 1)
		assert(compact_grid._better_inventory_compact_curio_blueprints == nil)
        ''',
    )

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
