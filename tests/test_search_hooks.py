from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_search_hooks.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        hooks = {}
        safe_hooks = {}
        calls = {}
        test_mod = {
            hook = function(_, target, name, callback)
                hooks[target.__name .. ":" .. name] = callback
            end,
            hook_safe = function(_, target, name, callback)
                safe_hooks[target.__name .. ":" .. name] = callback
            end,
        }
        function klass(name, methods)
            methods = methods or {}
            methods.__name = name
            return methods
        end
        item_grid_base = klass("grid", {
            _present_layout_by_slot_filter = function() end,
            _filter_by_filter_option = function() end,
            update = function() end,
        })
        crafting = klass("crafting", {_handle_input = function() end})
        vendor = klass("vendor", {_handle_input = function() end})
        legend = klass("legend", {_handle_input = function() end})
        grid_element = klass("element", {cb_on_grid_entry_left_pressed = function() end})
        features = {
            search_capture_presentation = function(_, view, slot, item_type, name)
                calls.capture = {view, slot, item_type, name}
            end,
            search_filter_result = function(view, entry, native)
                calls.filter = {view, entry, native}
                return native and entry.keep
            end,
            search_update = function(view, time) calls.search_update = {view, time} end,
        }
        search_ui = {
            sync_query = function(_, view) calls.sync = view end,
            update = function(_, _, view, time, input) calls.ui_update = {view, time, input} end,
            handle_view_input = function(_, view) return view.block_search == true end,
            is_writing = function(view) return view and view.writing == true end,
            defocus = function(view) calls.defocus = view end,
        }
        ''',
    )
    module = lua.execute(MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH))
    assert module.install(lua.table_from({})) is False

    dependencies = lua.table_from(
        {
            "mod": lua.globals().test_mod,
            "Features": lua.globals().features,
            "SearchUI": lua.globals().search_ui,
            "ItemGridViewBase": lua.globals().item_grid_base,
            "CraftingMechanicusModifyView": lua.globals().crafting,
            "VendorViewBase": lua.globals().vendor,
            "ViewElementGrid": lua.globals().grid_element,
            "ViewElementInputLegend": lua.globals().legend,
        }
    )
    assert module.install(dependencies) is True

    lua.execute(
        r'''
        view = {keep = true}
        native_present = 0
        native_filter = 0
        hooks["grid:_present_layout_by_slot_filter"](
            function() native_present = native_present + 1 return "presented" end,
            view, "slot", "type", "name"
        )
        filter_result = hooks["grid:_filter_by_filter_option"](
            function() native_filter = native_filter + 1 return true end,
            view, {keep = false}
        )
        safe_hooks["grid:update"](view, 0.1, 12, "input")

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

        legend_native = 0
        legend_parent = {_better_inventory_search_block_legend_once = true}
        hooks["legend:_handle_input"](
            function() legend_native = legend_native + 1 end,
            {_parent = legend_parent}
        )
        writing_parent = {writing = true}
        hooks["legend:_handle_input"](
            function() legend_native = legend_native + 1 end,
            {_parent = writing_parent}
        )
        normal_parent = {}
        hooks["legend:_handle_input"](
            function() legend_native = legend_native + 1 end,
            {_parent = normal_parent}
        )
        safe_hooks["element:cb_on_grid_entry_left_pressed"]({_parent = view})
        ''',
    )
    g = lua.globals()
    assert g.native_present == 1
    assert g.calls.capture[2] == "slot"
    assert lua.execute("return calls.sync == view") is True
    assert g.native_filter == 1 and g.filter_result is False
    assert g.calls.ui_update[2] == 12
    assert g.calls.search_update[2] == 12
    assert g.native_input == 1
    assert g.legend_native == 1
    assert g.legend_parent._better_inventory_search_block_legend_once is None
    assert lua.execute("return calls.defocus == view") is True

    print("BetterInventory search hook tests passed.")


if __name__ == "__main__":
    main()
