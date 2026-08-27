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
            update = function() end,
        })
        base_view = klass("base", {init = function() end})
        crafting = klass("crafting", {_handle_input = function() end})
        barter = klass("barter", {
            _handle_input = function() end,
            _cb_fetch_inventory_items = function() end,
            _sort_grid_layout = function() end,
            update = function() end,
            on_exit = function() end,
        })
        vendor = klass("vendor", {_handle_input = function() end})
        legend = klass("legend", {_handle_input = function() end})
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
            search_update = function(view, time) calls.search_update = {view, time} end,
            search_compose_layout = function(view, layout)
                calls.compose = {view, layout}
                return layout
            end,
            search_release = function(view) calls.release = view end,
        }
        search_ui = {
            sync_query = function(_, view) calls.sync = view end,
            update = function(_, _, view, time, input) calls.ui_update = {view, time, input} end,
            handle_view_input = function(_, view) return view.block_search == true end,
            handle_grid_input = function(view) return view and view.block_grid == true end,
            is_writing = function(view) return view and view.writing == true end,
            defocus = function(view) calls.defocus = view end,
            decorate_definitions = function(definitions, view)
                calls.decorate = view
                definitions.decorated = true
                return definitions
            end,
            release = function(view) calls.ui_release = view end,
        }
        function require(path)
            if path == "scripts/ui/views/crafting_mechanicus_barter_items_view/crafting_mechanicus_barter_items_view" then
                return barter
            end
            error(path)
        end
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
            "BaseView": lua.globals().base_view,
            "CraftingMechanicusModifyView": lua.globals().crafting,
            "CraftingMechanicusBarterItemsView": lua.globals().barter,
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
        writing_parent = {
            writing = true,
            _widgets_by_name = {better_inventory_search_input = {}},
        }
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
        native_grid_updates = 0
        grid_parent = {
            block_grid = true,
            _widgets_by_name = {better_inventory_search_input = {}},
        }
        grid_element_instance = {_parent = grid_parent}
        grid_parent._item_grid = grid_element_instance
        grid_input = {
            null_service = function()
                calls.null_service = true
                return "null_input"
            end,
        }
        hooks["element:update"](
            function(_, _, _, input)
                native_grid_updates = native_grid_updates + 1
                calls.grid_input = input
            end,
            grid_element_instance, 0.1, 20, grid_input
        )

        sacrifice_view = {
            __class_name = "CraftingMechanicusBarterItemsView",
            _item_grid = {
                set_pivot_offset = function(_, x, y)
                    calls.pivot = {x, y}
                end,
            },
            _scenegraph_world_position = function() return {100, 50} end,
        }
        hooks["base:init"](
            function(_, definitions) calls.base_definitions = definitions end,
            sacrifice_view, {}, "settings", "context"
        )
        safe_hooks["barter:_cb_fetch_inventory_items"](sacrifice_view)
        native_layout = {{item = {gear_id = "one"}}}
        sacrifice_view._current_present_grid_layout_callback = function(_, layout)
            calls.presented_layout = layout
        end
        hooks["barter:_sort_grid_layout"](
            function(target)
                target._current_present_grid_layout_callback(target, native_layout)
            end,
            sacrifice_view, "sort"
        )
        safe_hooks["barter:update"](sacrifice_view, 0.1, 30, "sacrifice_input")
        safe_hooks["barter:on_exit"](sacrifice_view)
        ''',
    )
    g = lua.globals()
    assert g.native_present == 1
    assert g.calls.capture[2] == "slot"
    assert lua.execute("return calls.sync == sacrifice_view") is True
    assert g.native_filter == 1 and g.filter_result is False
    assert g.calls.ui_update[2] == 30
    assert g.calls.search_update[2] == 30
    assert g.native_input == 1
    assert g.legend_native == 1
    assert g.legend_parent._better_inventory_search_block_legend_once is None
    assert lua.execute("return calls.defocus == view") is True
    assert g.native_grid_updates == 1
    assert g.calls.null_service is True
    assert g.calls.grid_input == "null_input"
    assert g.calls.base_definitions.decorated is True
    assert g.calls.pivot[1] == 100 and g.calls.pivot[2] == 150
    assert lua.execute("return calls.compose[2] == native_layout") is True
    assert lua.execute("return calls.presented_layout == native_layout") is True
    assert lua.execute("return calls.ui_release == sacrifice_view") is True
    assert lua.execute("return calls.release == sacrifice_view") is True

    print("BetterInventory search hook tests passed.")


if __name__ == "__main__":
    main()
