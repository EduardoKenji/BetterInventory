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
        Utf8 = {
            string_length = function(value)
                local _, length = string.gsub(value or "", "[^\128-\193]", "")
                return length
            end,
        }
        Managers = {
            ui = {using_cursor_navigation = function() return not controller_active end},
        }
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
            inventory_search_inventory_top_padding = 14,
            inventory_search_inventory_bottom_padding = 46,
            inventory_search_armoury_top_padding = 22,
            inventory_search_armoury_bottom_padding = 34,
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
            actions = {
                back = false,
                confirm_pressed = false,
                focus_action = false,
                navigate_down_continuous = false,
                navigate_up_continuous = false,
            },
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
    decorated = search_ui.decorate_definitions(definitions, view, lua.globals().test_mod)
    assert decorated is not definitions
    assert definitions.grid_settings.title_height == 108
    assert definitions.grid_settings.top_padding is None
    assert decorated.grid_settings.title_height == 108
    assert decorated.grid_settings.top_padding == 46
    assert decorated.grid_settings.better_inventory_search_clip_pivot_y == 158
    assert decorated.scenegraph_definition.better_inventory_search_input.position[2] == 122
    assert decorated.scenegraph_definition.better_inventory_search_input.size[1] == 568
    assert decorated.scenegraph_definition.better_inventory_search_filters is None
    assert decorated.widget_definitions.better_inventory_search_clear is None
    lua.globals().decorated_once = decorated
    lua.globals().decorated_twice = search_ui.decorate_definitions(
        decorated, view, lua.globals().test_mod
    )
    assert lua.execute("return decorated_once == decorated_twice") is True

    # A single search row extends native content padding without moving native
    # title geometry. Armoury Requisition and Multi-Operative Supply share the
    # CreditsVendorView route and receive additional tab/header clearance.
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
        lua.globals().test_mod,
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
        lua.globals().test_mod,
    )
    assert vendor.grid_settings.title_height == 0
    assert vendor.grid_settings.top_padding == 114
    assert vendor.grid_settings.better_inventory_search_clip_pivot_y == 138
    assert vendor.scenegraph_definition.better_inventory_search_input.position[2] == 102

    general_vendor = search_ui.decorate_definitions(
        vendor_definitions,
        lua.table_from({"__class_name": "CreditsGoodsVendorView"}),
        lua.globals().test_mod,
    )
    assert general_vendor.grid_settings.top_padding == 128
    assert general_vendor.scenegraph_definition.better_inventory_search_input.position[2] == 84

    sacrifice_view = lua.table_from({"__class_name": "CraftingMechanicusBarterItemsView"})
    sacrifice = search_ui.decorate_definitions(
        definitions, sacrifice_view, lua.globals().test_mod
    )
    assert sacrifice.scenegraph_definition.better_inventory_search_input.position[2] == 58
    assert sacrifice.scenegraph_definition.better_inventory_search_input.size[1] == 486
    assert search_ui.barter_grid_offset() == 100

    # Inventory and Armoury use independent pixel sliders while every other
    # supported view retains its fixed native-contract geometry.
    lua.globals().settings.inventory_search_inventory_top_padding = 18
    lua.globals().settings.inventory_search_inventory_bottom_padding = 42
    custom_inventory = search_ui.decorate_definitions(
        definitions,
        lua.table_from({"__class_name": "InventoryWeaponsView"}),
        lua.globals().test_mod,
    )
    assert custom_inventory.grid_settings.top_padding == 42
    assert custom_inventory.grid_settings.better_inventory_search_clip_pivot_y == 162
    assert custom_inventory.scenegraph_definition.better_inventory_search_input.position[2] == 126
    lua.globals().settings.inventory_search_armoury_top_padding = 26
    lua.globals().settings.inventory_search_armoury_bottom_padding = 44
    custom_armoury = search_ui.decorate_definitions(
        vendor_definitions,
        lua.table_from({"__class_name": "CreditsVendorView"}),
        lua.globals().test_mod,
    )
    assert custom_armoury.grid_settings.top_padding == 124
    assert custom_armoury.grid_settings.better_inventory_search_clip_pivot_y == 142
    assert custom_armoury.scenegraph_definition.better_inventory_search_input.position[2] == 106

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
    input_widget.content.force_caret_update = False
    assert search_ui.sync_query(lua.globals().features, view) is True
    assert input_widget.content.force_caret_update is False
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

    # Caret positions count UTF-8 codepoints rather than bytes, so Simplified
    # Chinese input remains editable without corrupting field state.
    input_widget.content.input_text = "动力剑"
    assert search_ui.focus(view) is True
    assert input_widget.content.caret_position == 4
    assert search_ui.defocus(view) is True

    # Controller Up from any card in the first row transfers selection to the
    # search field. Confirm activates native text entry; Down restores the
    # current result grid's first item. Lower rows retain native grid input.
    lua.globals().controller_view = view
    lua.execute(
        r'''
        controller_active = true
        selected_index = 2
        grid_widgets = {
            {content = {row = 1}},
            {content = {row = 1}},
            {content = {row = 2}},
        }
        controller_view._item_grid = {
            selected_grid_index = function() return selected_index end,
            first_interactable_grid_index = function() return 1 end,
            widget_by_index = function(_, index) return grid_widgets[index] end,
            select_grid_index = function(_, index) selected_index = index end,
            select_first_index = function() selected_index = 1 return 1 end,
        }
        input_service.actions.navigate_up_continuous = true
        '''
    )
    assert search_ui.handle_grid_input(
        view, view._item_grid, lua.globals().input_service
    ) is True
    assert lua.globals().selected_index is None
    assert input_widget.content.hotspot.is_selected is True
    assert search_ui.is_writing(view) is False
    assert search_ui.handle_view_input(
        lua.globals().test_mod, view, lua.globals().input_service
    ) is True
    lua.globals().input_service.actions.navigate_up_continuous = False
    lua.globals().input_service.actions.confirm_pressed = True
    assert search_ui.handle_view_input(
        lua.globals().test_mod, view, lua.globals().input_service
    ) is True
    assert input_widget.content.hotspot.force_input_pressed is True
    lua.globals().input_service.actions.confirm_pressed = False
    lua.globals().input_service.actions.navigate_down_continuous = True
    assert search_ui.handle_view_input(
        lua.globals().test_mod, view, lua.globals().input_service
    ) is True
    assert lua.globals().selected_index == 1
    assert input_widget.content.hotspot.is_selected is False
    lua.globals().input_service.actions.navigate_down_continuous = False
    lua.execute("selected_index = 3; input_service.actions.navigate_up_continuous = true")
    assert search_ui.handle_grid_input(
        view, view._item_grid, lua.globals().input_service
    ) is False
    lua.execute("controller_active = false; input_service.actions.navigate_up_continuous = false")

    # Native ViewElementGrid centers its mask. Search clipping moves only the
    # top edge below the field and preserves the native bottom edge.
    lua.execute(
        r'''
        clip_grid = {
            _menu_settings = {
                better_inventory_search_clip_pivot_y = 158,
                title_height = 108,
            },
            _display_name_key = "Primary Weapon",
            sizes = {
                grid_background = {596, 737},
                grid_mask = {680, 701},
                grid_interaction = {680, 701},
            },
            positions = {grid_mask = {0, 18, 2}},
            _scenegraph_size = function(self, id)
                return self.sizes[id][1], self.sizes[id][2]
            end,
            scenegraph_position = function(self, id)
                return self.positions[id]
            end,
            _set_scenegraph_size = function(self, id, width, height)
                self.sizes[id] = {width or self.sizes[id][1], height or self.sizes[id][2]}
            end,
            _set_scenegraph_position = function(self, id, x, y)
                local position = self.positions[id] or {0, 0, 0}
                position[1] = x or position[1]
                position[2] = y or position[2]
                self.positions[id] = position
            end,
        }
        clip_before_bottom = 737 * 0.5 + clip_grid.positions.grid_mask[2] + clip_grid.sizes.grid_mask[2] * 0.5
        '''
    )
    assert search_ui.finalize_grid_clip(lua.globals().clip_grid) is True
    assert lua.globals().clip_grid.sizes.grid_mask[2] == 671
    assert lua.globals().clip_grid.sizes.grid_interaction[2] == 671
    assert lua.globals().clip_grid.positions.grid_mask[2] == 33
    assert (
        lua.globals().clip_grid.sizes.grid_mask[2] * 0.5
        + lua.globals().clip_grid.positions.grid_mask[2]
        + 737 * 0.5
        == lua.globals().clip_before_bottom
    )
    assert search_ui.finalize_grid_clip(lua.table_from({})) is False

    # Missing actions must never be passed to InputService:get: Darktide crashes
    # instead of returning false when its action rule does not exist.
    input_widget.content.input_text = "sword"
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

    # The master Mod Options switch immediately hides and defocuses an
    # already-created field. The integration test separately proves that all
    # cached search state and ranking/filtering activity are released.
    lua.globals().settings.enable_inventory_search = False
    search_ui.update(lua.globals().test_mod, lua.globals().features, view, 5)
    assert input_widget.visible is False
    assert search_ui.is_writing(view) is False

    search_ui.release(view)
    assert view._better_inventory_search_widget_initialized is None
    assert view._better_inventory_search_last_text is None

    print("BetterInventory search UI tests passed.")


if __name__ == "__main__":
    main()
