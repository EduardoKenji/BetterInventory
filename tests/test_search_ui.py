from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_search_ui.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        function clone_table(source)
            local copy = {}
            for key, value in pairs(source or {}) do
                copy[key] = type(value) == "table" and clone_table(value) or value
            end
            return copy
        end
        table.clone = clone_table
        Utf8 = {string_length = function(value) return #value end}
        ui_widget = {
            create_definition = function(passes, scenegraph_id, initial)
                local content = clone_table(initial or {})
                content.hotspot = content.hotspot or {}
                return {content = content, passes = passes, scenegraph_id = scenegraph_id, style = {}}
            end,
        }
        input_templates = {simple_input_field = {}}
        function require(path)
            if path == "scripts/managers/ui/ui_widget" then return ui_widget end
            if path == "scripts/ui/pass_templates/text_input_pass_templates" then return input_templates end
            error(path)
        end
        settings = {
            enable_inventory_search = true,
            inventory_search_focus_keybind = "off",
        }
        test_mod = {
            get = function(_, id) return settings[id] end,
            localize = function(_, id) return "loc:" .. id end,
        }
        last_query = nil
        last_time = nil
        set_calls = 0
        features = {
            search_query = function() return "remembered" end,
            search_set_query = function(_, query, time)
                set_calls = set_calls + 1
                last_query = query
                last_time = time
                return query ~= "invalid", query == "invalid" and "bad" or nil
            end,
        }
        input_service = {
            actions = {back = false, focus_action = false},
            has = function(self, action) return self.actions[action] ~= nil end,
            get = function(self, action)
                assert(self:has(action), "attempted to read an unavailable input action: " .. tostring(action))
                return self.actions[action] == true
            end,
        }
        ''',
    )
    search_ui = lua.execute(MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH))

    definitions = lua.table_from(
        {
            "grid_settings": lua.table_from({"title_height": 108}),
            "scenegraph_definition": lua.table_from(
                {
                    "native": lua.table_from({}),
                    "item_grid_pivot": lua.table_from({}),
                }
            ),
            "widget_definitions": lua.table_from({"native": lua.table_from({})}),
        }
    )
    view = lua.table_from({"__class_name": "InventoryWeaponsView"})
    decorated = search_ui.decorate_definitions(definitions, view)
    assert decorated is not definitions
    assert definitions.grid_settings.title_height == 108
    assert definitions.grid_settings.top_padding is None
    assert decorated.grid_settings.title_height == 108
    assert decorated.grid_settings.top_padding == 48
    assert decorated.scenegraph_definition.better_inventory_search_input.position[2] == 112
    assert decorated.scenegraph_definition.better_inventory_search_input.size[1] == 568
    assert decorated.scenegraph_definition.better_inventory_search_filters is None
    assert decorated.widget_definitions.better_inventory_search_clear is None
    lua.globals().decorated_once = decorated
    lua.globals().decorated_twice = search_ui.decorate_definitions(decorated, view)
    assert lua.execute("return decorated_once == decorated_twice") is True

    # A single search row extends native content padding without moving native
    # title geometry. Vendor tab padding is preserved and extended.
    crafting_definitions = lua.table_from(
        {
            "grid_settings": lua.table_from({"title_height": 80}),
            "scenegraph_definition": lua.table_from({"item_grid_pivot": lua.table_from({})}),
            "widget_definitions": lua.table_from({}),
        }
    )
    crafting = search_ui.decorate_definitions(
        crafting_definitions,
        lua.table_from({"__class_name": "CraftingMechanicusModifyView"}),
    )
    assert crafting.grid_settings.title_height == 80
    assert crafting.grid_settings.top_padding == 48
    assert crafting.scenegraph_definition.better_inventory_search_input.position[2] == 84

    vendor_definitions = lua.table_from(
        {
            "grid_settings": lua.table_from({"title_height": 0, "top_padding": 80}),
            "scenegraph_definition": lua.table_from({"item_grid_pivot": lua.table_from({})}),
            "widget_definitions": lua.table_from({}),
        }
    )
    vendor = search_ui.decorate_definitions(
        vendor_definitions,
        lua.table_from({"__class_name": "CreditsVendorView"}),
    )
    assert vendor.grid_settings.title_height == 0
    assert vendor.grid_settings.top_padding == 128
    assert vendor.scenegraph_definition.better_inventory_search_input.position[2] == 84

    sacrifice_view = lua.table_from({"__class_name": "CraftingMechanicusBarterItemsView"})
    sacrifice = search_ui.decorate_definitions(definitions, sacrifice_view)
    assert sacrifice.scenegraph_definition.better_inventory_search_input.position[2] == 58
    assert sacrifice.scenegraph_definition.better_inventory_search_input.size[1] == 486
    assert search_ui.barter_grid_offset() == 100

    missing_geometry = lua.table_from(
        {
            "grid_settings": lua.table_from({}),
            "scenegraph_definition": lua.table_from({}),
            "widget_definitions": lua.table_from({}),
        }
    )
    missing_view = lua.table_from({"__class_name": "InventoryWeaponsView"})
    lua.globals().missing_geometry = missing_geometry
    lua.globals().missing_result = search_ui.decorate_definitions(missing_geometry, missing_view)
    assert lua.execute("return missing_geometry == missing_result") is True
    assert missing_view._better_inventory_search_ui_unavailable is True

    unsupported = lua.table_from({"__class_name": "InventoryCosmeticsView"})
    same = search_ui.decorate_definitions(definitions, unsupported)
    lua.globals().original_definitions = definitions
    lua.globals().same_definitions = same
    assert lua.execute("return original_definitions == same_definitions") is True

    lua.globals().decorated_defs = decorated
    lua.execute(
        r'''
        function make_widget(name)
            return clone_table(decorated_defs.widget_definitions[name])
        end
        ''',
    )
    widgets = lua.table_from(
        {
            "better_inventory_search_input": lua.globals().make_widget(
                "better_inventory_search_input"
            )
        }
    )
    view._widgets_by_name = widgets

    assert search_ui.sync_query(lua.globals().features, view) is True
    input_widget = widgets.better_inventory_search_input
    assert input_widget.content.input_text == "remembered"
    search_ui.update(lua.globals().test_mod, lua.globals().features, view, 1)
    assert input_widget.content.placeholder_text.startswith("loc:")
    assert lua.globals().set_calls == 0

    input_widget.content.input_text = "sword"
    search_ui.update(lua.globals().test_mod, lua.globals().features, view, 2)
    assert lua.globals().last_query == "sword"
    assert lua.globals().last_time == 2
    assert lua.globals().set_calls == 1

    input_widget.content.input_text = "invalid"
    search_ui.update(lua.globals().test_mod, lua.globals().features, view, 3)
    assert lua.globals().last_query == "invalid"
    input_widget.content.input_text = ""
    search_ui.update(lua.globals().test_mod, lua.globals().features, view, 4)
    assert lua.globals().last_query == ""

    input_widget.content.input_text = "sword"
    assert search_ui.focus(view) is True
    assert search_ui.is_writing(view) is True
    assert search_ui.defocus(view) is True
    assert input_widget.content.input_text == "sword"

    # Missing actions must never be passed to InputService:get: Darktide crashes
    # instead of returning false when its action rule does not exist.
    lua.globals().settings.inventory_search_focus_keybind = "missing_action"
    assert search_ui.handle_view_input(
        lua.globals().test_mod, view, lua.globals().input_service
    ) is False
    lua.globals().settings.inventory_search_focus_keybind = "focus_action"
    lua.globals().input_service.actions.focus_action = True
    assert search_ui.handle_view_input(
        lua.globals().test_mod, view, lua.globals().input_service
    ) is True
    assert search_ui.is_writing(view) is True
    lua.globals().input_service.actions.focus_action = False
    assert search_ui.handle_view_input(
        lua.globals().test_mod, view, lua.globals().input_service
    ) is True
    assert search_ui.is_writing(view) is True
    lua.globals().input_service.actions.back = True
    assert search_ui.handle_view_input(
        lua.globals().test_mod, view, lua.globals().input_service
    ) is True
    assert search_ui.is_writing(view) is False
    assert view._better_inventory_search_block_legend_once is True
    assert input_widget.content.input_text == "sword"

    search_ui.release(view)
    assert view._better_inventory_search_widget_initialized is None
    assert view._better_inventory_search_last_text is None

    print("BetterInventory search UI tests passed.")


if __name__ == "__main__":
    main()
