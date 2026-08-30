from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_search_hooks.lua"
)
SEARCH_UI_PATH = (
    PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_search_ui.lua"
)


def main() -> None:
    hooks_source = MODULE_PATH.read_text(encoding="utf-8")
    search_ui_source = SEARCH_UI_PATH.read_text(encoding="utf-8")
    # v3.4.0's superseded parent back-handler interception and invalid `esc`
    # physical-key probe must not return. The exact copied Marks input seam and
    # Stingray's `escape` key are the only confirmed Melk focus path.
    assert "_handle_back_pressed" not in hooks_source
    assert 'keyboard.button_index, "esc"' not in search_ui_source
    assert 'keyboard.button_index, "escape"' in search_ui_source
    assert 'ensure_class_method(MarksVendorView, "on_exit")' in hooks_source
    assert 'mod:hook_safe(MarksVendorView, "on_exit", release_item_grid_view_runtime)' in hooks_source
    assert 'ensure_class_method(MarksVendorView, "destroy")' in hooks_source
    assert 'mod:hook_safe(MarksVendorView, "destroy", release_item_grid_view_runtime)' in hooks_source
    assert "CraftingMechanicusBarterItemsView" not in hooks_source
    assert "search_compose_layout" not in hooks_source

    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        hooks = {}
        safe_hooks = {}
        calls = {}
        search_updates = 0
        test_mod = {
            hook = function(_, target, name, callback)
                hooks[target.__name .. ":" .. name] = callback
            end,
            hook_safe = function(_, target, name, callback)
                safe_hooks[target.__name .. ":" .. name] = callback
            end,
            get = function(_, setting) return true end,
        }
        function klass(name, methods)
            methods = methods or {}
            methods.__name = name
            return methods
        end
        item_grid_base = klass("grid", {
            _present_layout_by_slot_filter = function() end,
            _filter_by_filter_option = function() end,
            _cb_on_present = function() end,
            update = function() end,
        })
        crafting = klass("crafting", {
            _handle_input = function() end,
            update = function() end,
        })
        vendor = klass("vendor", {
            _handle_input = function() end,
            update = function() end,
			on_exit = function() end,
			destroy = function() end,
        })
        credits_goods = klass("credits_goods", {update = function() end})
        -- Darktide class() copies superclass functions at class construction;
        -- it does not dynamically inherit later VendorViewBase hooks.
        marks_vendor = klass("marks_vendor", {
            super = vendor,
            _handle_input = vendor._handle_input,
            update = vendor.update,
			on_exit = vendor.on_exit,
			destroy = vendor.destroy,
        })
        marks_goods = klass("marks_goods", {update = function() end})
        grid_element = klass("element", {
            cb_on_grid_entry_left_pressed = function() end,
            update = function() end,
        })
        features = {
            search_capture_presentation = function(_, view, slot, item_type, name)
                calls.capture = {view, slot, item_type, name}
            end,
            search_filter_result = function(view, entry, native)
                calls.filter = {view, entry, native}
                return native and entry.keep
            end,
            search_apply_widget_alpha = function(view) calls.alpha = view end,
            search_update = function(view, time)
                search_updates = search_updates + 1
                calls.search_update = {view, time}
            end,
            search_release = function(view) calls.release = view end,
        }
        search_ui = {
            supported = function(view) return view.search_unsupported ~= true end,
            enabled = function(_, view) return view.search_disabled ~= true end,
            sync_query = function(_, _, view) calls.sync = view end,
            update = function(_, _, view, time, input) calls.ui_update = {view, time, input} end,
            update_view = function(mod, feature_set, view, time, input)
                ui_updates = (ui_updates or 0) + 1
                calls.ui_update = {view, time, input}
                if view._better_inventory_search_needs_update then
                    feature_set.search_update(view, time)
                end
            end,
            handle_view_input = function(_, view) return view.block_search == true end,
            is_writing = function(view) return view and view.writing == true end,
            defocus = function(view) calls.defocus = view end,
            decorate_definitions = function(definitions, view)
                calls.decorate = view
                definitions.decorated = true
                return definitions
            end,
            release = function(view) calls.ui_release = view end,
        }
        function require(path) error(path) end
        ''',
    )
    module = lua.execute(MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH))
    assert module.install(lua.table_from({})) is False
    assert module.install(
        lua.table_from(
            {
                "mod": lua.globals().test_mod,
                "Features": lua.globals().features,
                "SearchUI": lua.globals().search_ui,
            }
        )
    ) is True

    dependencies = lua.table_from(
        {
            "mod": lua.globals().test_mod,
            "Features": lua.globals().features,
            "SearchUI": lua.globals().search_ui,
            "ItemGridViewBase": lua.globals().item_grid_base,
            "CraftingMechanicusModifyView": lua.globals().crafting,
            "CreditsGoodsVendorView": lua.globals().credits_goods,
            "MarksVendorView": lua.globals().marks_vendor,
            "VendorViewBase": lua.globals().vendor,
            "ViewElementGrid": lua.globals().grid_element,
            "release_item_grid_view_runtime": lua.eval(
                "function(view) calls.grid_runtime_release = (calls.grid_runtime_release or 0) + 1; calls.grid_runtime_view = view end"
            ),
        }
    )
    assert module.install(dependencies) is True

    lua.execute(
        r'''
        view = {
            keep = true,
            _better_inventory_search_filter_active = true,
            _better_inventory_search_needs_update = true,
        }
        native_present = 0
        native_filter = 0
        hooks["grid:_present_layout_by_slot_filter"](
            function() native_present = native_present + 1 return "presented" end,
            view, "slot", "type", "name"
        )
        disabled_search_view = {search_disabled = true}
        hooks["grid:_present_layout_by_slot_filter"](
            function() return "disabled-presented" end,
            disabled_search_view, "disabled-slot", "type", "name"
        )
        disabled_search_released = calls.release == disabled_search_view
        disabled_search_capture_skipped = calls.capture[1] == view
        calls.release = nil
        unsupported_search_view = {search_unsupported = true}
        hooks["grid:_present_layout_by_slot_filter"](
            function() return "unsupported-presented" end,
            unsupported_search_view, "unsupported-slot", "type", "name"
        )
        unsupported_search_ignored = calls.release == nil and calls.capture[1] == view
        filter_result = hooks["grid:_filter_by_filter_option"](
            function() native_filter = native_filter + 1 return true end,
            view, {keep = false}
        )
        view._better_inventory_search_filter_active = nil
        idle_filter_result = hooks["grid:_filter_by_filter_option"](
            function() native_filter = native_filter + 1 return true end,
            view, {keep = false}
        )
        view._better_inventory_search_rank_active = true
        safe_hooks["grid:_cb_on_present"](view)
        view._better_inventory_search_rank_active = nil
        safe_hooks["grid:_cb_on_present"]({})
        assert(safe_hooks["grid:update"] == nil)
        safe_hooks["crafting:update"](view, 0.1, 12, "input")
        safe_hooks["credits_goods:update"](view, 0.1, 13, "credits_input")
        safe_hooks["marks_vendor:update"](view, 0.1, 14, "marks_input")
        assert(safe_hooks["marks_goods:update"] == nil)
        assert(safe_hooks["vendor:update"] == nil)

        native_input = 0
        blocked_view = {block_search = true}
        hooks["crafting:_handle_input"](
            function() native_input = native_input + 1 end,
            blocked_view, "input"
        )
        open_view = {block_search = false}
        hooks["vendor:_handle_input"](
            function() native_input = native_input + 1 return "native" end,
            open_view, "input"
        )
        melk_blocked_view = {block_search = true}
        hooks["marks_vendor:_handle_input"](
            function() native_input = native_input + 1 return "native-melk" end,
            melk_blocked_view, "input"
        )
        melk_open_view = {block_search = false}
        melk_open_result = hooks["marks_vendor:_handle_input"](
            function() native_input = native_input + 1 return "native-melk" end,
            melk_open_view, "input"
        )
		safe_hooks["marks_vendor:on_exit"](melk_open_view)
		safe_hooks["marks_vendor:destroy"](melk_open_view)
		marks_vendor.on_exit(melk_open_view)
		marks_vendor.destroy(melk_open_view)
        safe_hooks["element:cb_on_grid_entry_left_pressed"]({_parent = view})
        ''',
    )
    g = lua.globals()
    assert g.native_present == 1
    assert g.disabled_search_released is True
    assert g.disabled_search_capture_skipped is True
    assert g.unsupported_search_ignored is True
    assert g.calls.capture[2] == "slot"
    assert lua.execute("return calls.sync == view") is True
    assert g.native_filter == 2 and g.filter_result is False
    assert g.idle_filter_result is True
    assert lua.execute("return calls.alpha == view") is True
    assert g.calls.ui_update[2] == 14
    assert g.calls.search_update[2] == 14
    assert g.search_updates == 3
    assert g.ui_updates == 3
    assert g.native_input == 2
    assert g.melk_open_result == "native-melk"
    assert g.calls.grid_runtime_release == 2
    assert lua.execute("return calls.grid_runtime_view == melk_open_view") is True
    assert lua.execute('return hooks["legend:_handle_input"] == nil') is True
    assert lua.execute("return calls.defocus == view") is True
    assert lua.execute('return hooks["element:update"] == nil') is True
    assert lua.execute('return hooks["base:init"] == nil') is True
    assert lua.execute('return hooks["barter:_handle_input"] == nil') is True
    assert lua.execute('return hooks["barter:_sort_grid_layout"] == nil') is True
    assert lua.execute('return safe_hooks["barter:update"] == nil') is True
    assert lua.execute("return calls.ui_release == nil") is True
    assert lua.execute("return calls.release == nil") is True

    print("BetterInventory search hook tests passed.")


if __name__ == "__main__":
    main()
