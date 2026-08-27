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
                local style = {}
                for index = 1, #(passes or {}) do
                    local pass = passes[index]
                    if pass.style_id then style[pass.style_id] = clone_table(pass.style or {}) end
                end
                local content = clone_table(initial or {})
                content.hotspot = content.hotspot or {}
                return {content = content, passes = passes, scenegraph_id = scenegraph_id, style = style}
            end,
        }
        font_settings = {body = {font_size = 18}}
        input_templates = {simple_input_field = {}}
        function require(path)
            if path == "scripts/managers/ui/ui_widget" then return ui_widget end
            if path == "scripts/managers/ui/ui_font_settings" then return font_settings end
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
        last_chips = nil
        set_calls = 0
        features = {
            search_query = function() return "remembered" end,
            search_chips = function()
                return {{field = "favorite", value = true}}
            end,
            search_counts = function() return 2, 10 end,
            search_set_query = function(_, query, chips)
                set_calls = set_calls + 1
                last_query = query
                last_chips = chips
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
    assert decorated.grid_settings.title_height == 170
    assert decorated.scenegraph_definition.better_inventory_search_input is not None
    assert decorated.scenegraph_definition.better_inventory_search_filter_perfect is not None
    assert decorated.scenegraph_definition.better_inventory_search_filter_type_weapon is not None
    assert decorated.scenegraph_definition.better_inventory_search_filter_type_ranged is not None
    assert decorated.widget_definitions.better_inventory_search_clear is not None
    lua.globals().decorated_once = decorated
    lua.globals().decorated_twice = search_ui.decorate_definitions(decorated, view)
    assert lua.execute("return decorated_once == decorated_twice") is True

    sacrifice_view = lua.table_from({"__class_name": "CraftingMechanicusBarterItemsView"})
    sacrifice = search_ui.decorate_definitions(definitions, sacrifice_view)
    assert sacrifice.scenegraph_definition.better_inventory_search_input.position[2] == 58
    assert sacrifice.scenegraph_definition.better_inventory_search_filters.position[2] == 96

    missing_geometry = lua.table_from(
        {
            "grid_settings": lua.table_from({}),
            "scenegraph_definition": lua.table_from({}),
            "widget_definitions": lua.table_from({}),
        }
    )
    missing_view = lua.table_from({"__class_name": "InventoryWeaponsView"})
    lua.globals().missing_geometry = missing_geometry
    lua.globals().missing_result = search_ui.decorate_definitions(
        missing_geometry, missing_view
    )
    assert lua.execute("return missing_geometry == missing_result") is True
    assert missing_view._better_inventory_search_ui_unavailable is True

    unsupported = lua.table_from({"__class_name": "InventoryCosmeticsView"})
    same = search_ui.decorate_definitions(definitions, unsupported)
    lua.globals().original_definitions = definitions
    lua.globals().same_definitions = same
    assert lua.execute("return original_definitions == same_definitions") is True

    # Materialize the per-view widgets exactly as BaseView would after loading
    # the cloned definitions.
    lua.execute(
        r'''
        function make_widget(name)
            local source = decorated_defs.widget_definitions[name]
            return clone_table(source)
        end
        ''',
    )
    lua.globals().decorated_defs = decorated
    names = [
        "better_inventory_search_input",
        "better_inventory_search_clear",
        "better_inventory_search_count",
        "better_inventory_search_help",
        "better_inventory_search_help_text",
        "better_inventory_search_filters",
        "better_inventory_search_filter_equipped",
        "better_inventory_search_filter_favorite",
        "better_inventory_search_filter_new",
        "better_inventory_search_filter_loadout",
        "better_inventory_search_filter_perfect",
        "better_inventory_search_filter_type_weapon",
        "better_inventory_search_filter_type_curio",
        "better_inventory_search_filter_type_melee",
        "better_inventory_search_filter_type_ranged",
    ]
    widgets = lua.table_from({})
    for name in names:
        widgets[name] = lua.globals().make_widget(name)
    view._widgets_by_name = widgets

    assert search_ui.sync_query(lua.globals().features, view) is True
    assert widgets.better_inventory_search_input.content.input_text == "remembered"
    assert view._better_inventory_search_quick_filters["favorite=true"] is True

    search_ui.update(
        lua.globals().test_mod,
        lua.globals().features,
        view,
        1,
        lua.globals().input_service,
    )
    assert widgets.better_inventory_search_input.content.placeholder_text.startswith("loc:")
    assert widgets.better_inventory_search_filter_equipped.visible is False
    assert widgets.better_inventory_search_filter_type_weapon.visible is False

    # Expand quick filters, select Equipped, and verify the next update sends
    # both restored Favorite and new Equipped chips without clearing the text.
    widgets.better_inventory_search_filters.content.hotspot.pressed_callback()
    widgets.better_inventory_search_filter_equipped.content.hotspot.pressed_callback()
    search_ui.update(lua.globals().test_mod, lua.globals().features, view, 2, None)
    assert widgets.better_inventory_search_filter_equipped.visible is True
    assert lua.globals().last_query == "remembered"
    chip_fields = {
        lua.globals().last_chips[index].field
        for index in range(1, len(lua.globals().last_chips) + 1)
    }
    assert chip_fields == {"equipped", "favorite"}
    assert widgets.better_inventory_search_count.content.text == "2 / 10"

    # Type chips share one mutually-exclusive field so Curio replaces Weapon,
    # while text and boolean chips remain intact. Help is an in-view popover.
    widgets.better_inventory_search_filter_type_weapon.content.hotspot.pressed_callback()
    search_ui.update(lua.globals().test_mod, lua.globals().features, view, 2.1, None)
    assert lua.globals().last_chips[3].field == "type"
    assert lua.globals().last_chips[3].value == "weapon"
    widgets.better_inventory_search_filter_type_curio.content.hotspot.pressed_callback()
    search_ui.update(lua.globals().test_mod, lua.globals().features, view, 2.2, None)
    type_values = [
        lua.globals().last_chips[index].value
        for index in range(1, len(lua.globals().last_chips) + 1)
        if lua.globals().last_chips[index].field == "type"
    ]
    assert type_values == ["curio"]
    widgets.better_inventory_search_help.content.hotspot.pressed_callback()
    search_ui.update(lua.globals().test_mod, lua.globals().features, view, 2.3, None)
    assert widgets.better_inventory_search_help_text.visible is True
    assert "loc:inventory_search_help" in widgets.better_inventory_search_help_text.content.text

    widgets.better_inventory_search_input.content.input_text = "invalid"
    search_ui.update(lua.globals().test_mod, lua.globals().features, view, 3, None)
    assert widgets.better_inventory_search_count.content.text == "loc:inventory_search_invalid"

    # Clear owns both the text and chips. Card selection only defocuses and
    # keeps the active query unchanged.
    widgets.better_inventory_search_clear.content.hotspot.pressed_callback()
    search_ui.update(lua.globals().test_mod, lua.globals().features, view, 4, None)
    assert lua.globals().last_query == ""
    assert len(lua.globals().last_chips) == 0

    widgets.better_inventory_search_input.content.input_text = "sword"
    assert search_ui.focus(view) is True
    assert search_ui.is_writing(view) is True
    assert search_ui.defocus(view) is True
    assert widgets.better_inventory_search_input.content.input_text == "sword"

    # Configurable focus blocks the bound native action in that frame. Escape
    # defocuses first and arms one legend suppression without clearing text.
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
    assert widgets.better_inventory_search_input.content.input_text == "sword"

    search_ui.release(view)
    assert view._better_inventory_search_quick_filters is None

    print("BetterInventory search UI tests passed.")


if __name__ == "__main__":
    main()
