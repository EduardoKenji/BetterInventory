from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
FEATURES_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_features.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r"""
        function table.clone(value)
            if type(value) ~= "table" then
                return value
            end

            local copy = {}

            for key, child in pairs(value) do
                copy[table.clone(key)] = table.clone(child)
            end

            return setmetatable(copy, getmetatable(value))
        end

        Color = setmetatable({}, {
            __index = function()
                return function(alpha)
                    return {alpha or 255, 200, 210, 190}
                end
            end,
        })

        TestItems = {
            favorites = {},
            is_item_id_favorited = function(gear_id)
                return TestItems.favorites[gear_id] == true
            end,
        }
        TestUIWidget = {
            create_definition = function(pass_template, scenegraph_id, content)
                content.hotspot = content.hotspot or {}

                return {
                    pass_template = pass_template,
                    scenegraph_id = scenegraph_id,
                    content = content,
                }
            end,
        }
        TestSoundEvents = {
            default_mouse_hover = "hover",
            default_click = "click",
        }
        function require(path)
            if path == "scripts/utilities/items" then
                return TestItems
            elseif path == "scripts/managers/ui/ui_widget" then
                return TestUIWidget
            elseif path == "scripts/settings/ui/ui_sound_events" then
                return TestSoundEvents
            end

            error("Unexpected test require: " .. tostring(path))
        end

        test_mod = {
            settings = {
                prioritize_equipped_favorites = true,
            },
            get = function(self, setting_id)
                return self.settings[setting_id]
            end,
            set = function(self, setting_id, value)
                self.settings[setting_id] = value
            end,
            localize = function(self, localization_id)
                return localization_id
            end,
        }
        test_layout = {
            slot_kind = function(view)
                return view.slot_kind
            end,
        }
        """
    )
    features = lua.execute(FEATURES_PATH.read_text(encoding="utf-8"))
    globals_ = lua.globals()
    mod = globals_.test_mod
    layout = globals_.test_layout

    definitions = lua.table_from(
        {
            "scenegraph_definition": lua.table_from({}),
            "widget_definitions": lua.table_from({}),
            "grid_settings": lua.table_from(
                {"grid_size": lua.table_from([620, 860])}
            ),
        }
    )
    view = lua.execute(
        r"""
        return {
            __class_name = "InventoryWeaponsView",
            slot_kind = "curio",
        }
        """
    )
    adjusted = features.add_inventory_sort_toggle_definition(mod, layout, definitions, view)
    toggle_id = "better_inventory_sort_priority"
    assert adjusted.scenegraph_definition[toggle_id].parent == "weapon_stats_pivot"
    assert adjusted.scenegraph_definition[toggle_id].position[2] == 500
    assert (
        adjusted.widget_definitions[toggle_id].content.label
        == "prioritize_equipped_favorites_inventory_label"
    )

    view._ui_scenegraph = adjusted.scenegraph_definition
    view._set_scenegraph_position = lua.eval(
        """
        function(self, scenegraph_id, x, y)
            local position = self._ui_scenegraph[scenegraph_id].position

            position[1] = x
            position[2] = y
            self.position_set_with_view_api = true
            self._update_scenegraph = true
        end
        """
    )
    view._weapon_stats = lua.table_from(
        {
            "_menu_settings": lua.table_from(
                {"grid_size": lua.table_from([530, 920])}
            ),
            "_ui_scenegraph": lua.table_from(
                {
                    "grid_background_pivot": lua.table_from(
                        {"position": lua.table_from([0, 13, 0])}
                    ),
                    "grid_background": lua.table_from(
                        {
                            "position": lua.table_from([0, 0, 0]),
                            "size": lua.table_from([530, 430]),
                        }
                    ),
                    "grid_divider_bottom": lua.table_from(
                        {
                            "position": lua.table_from([0, 16, 0]),
                            "size": lua.table_from([530, 36]),
                        }
                    ),
                    "grid_divider_bottom_weapon": lua.table_from(
                        {
                            "position": lua.table_from([0, 0, 0]),
                            "size": lua.table_from([530, 36]),
                        }
                    )
                }
            ),
            "grid_length": lua.eval("function() return 475 end"),
        }
    )
    features.update_inventory_sort_toggle(mod, layout, view)
    assert adjusted.scenegraph_definition[toggle_id].position[1] == 0
    assert adjusted.scenegraph_definition[toggle_id].position[2] == 474
    assert view.position_set_with_view_api is True
    assert view._update_scenegraph is True

    melee_view = lua.execute(
        r"""
        return {
            __class_name = "InventoryWeaponsView",
            slot_kind = "slot_primary",
        }
        """
    )
    melee_definitions = features.add_inventory_sort_toggle_definition(
        mod, layout, definitions, melee_view
    )
    assert (
        melee_definitions.scenegraph_definition[toggle_id].parent
        == "weapon_compare_stats_pivot"
    )
    melee_view._ui_scenegraph = melee_definitions.scenegraph_definition
    melee_view._weapon_options_element = lua.table_from(
        {
            "_menu_settings": lua.table_from(
                {"grid_size": lua.table_from([420, 270])}
            )
        }
    )
    features.update_inventory_sort_toggle(mod, layout, melee_view)
    assert melee_definitions.scenegraph_definition[toggle_id].position[1] == 20
    assert melee_definitions.scenegraph_definition[toggle_id].position[2] == 285

    ranged_view = lua.execute(
        r"""
        return {
            __class_name = "InventoryWeaponsView",
            slot_kind = "slot_secondary",
        }
        """
    )
    ranged_definitions = features.add_inventory_sort_toggle_definition(
        mod, layout, definitions, ranged_view
    )
    assert (
        ranged_definitions.scenegraph_definition[toggle_id].parent
        == "weapon_compare_stats_pivot"
    )

    sortable_view = lua.execute(
        r"""
        return {
            __class_name = "InventoryWeaponsView",
            slot_kind = "curio",
            is_item_equipped_in_any_slot = function(self, item)
                return item.equipped == true
            end,
            _sort_options = {
                {
                    sort_function = function(left, right)
                        return left.item.rating > right.item.rating
                    end,
                },
            },
        }
        """
    )
    globals_.TestItems.favorites.favorite = True
    features.configure_inventory_sort_options(mod, layout, sortable_view)
    sorted_ids = lua.execute(
        r"""
        local view, ordinary, favorite, equipped = ...
        local entries = {ordinary, favorite, equipped}

        table.sort(entries, view._sort_options[1].sort_function)

        return entries[1].item.gear_id, entries[2].item.gear_id, entries[3].item.gear_id
        """,
        sortable_view,
        lua.table_from(
            {"item": lua.table_from({"gear_id": "ordinary", "rating": 100, "slots": lua.table_from(["slot_attachment_1"])})}
        ),
        lua.table_from(
            {"item": lua.table_from({"gear_id": "favorite", "rating": 10, "slots": lua.table_from(["slot_attachment_1"])})}
        ),
        lua.table_from(
            {
                "item": lua.table_from(
                    {"gear_id": "equipped", "rating": 1, "equipped": True, "slots": lua.table_from(["slot_attachment_1"])}
                )
            }
        ),
    )
    assert sorted_ids == ("equipped", "favorite", "ordinary")

    mod.settings.prioritize_equipped_favorites = False
    rating_first = lua.execute(
        r"""
        local view, high, low = ...
        return view._sort_options[1].sort_function(high, low)
        """,
        sortable_view,
        lua.table_from({"item": lua.table_from({"gear_id": "high", "rating": 100})}),
        lua.table_from(
            {
                "item": lua.table_from(
                    {"gear_id": "low", "rating": 1, "equipped": True, "slots": lua.table_from(["slot_attachment_1"])}
                )
            }
        ),
    )
    assert rating_first is True

    mod.settings.prioritize_equipped_favorites = True
    sortable_view._widgets_by_name = lua.table_from(
        {toggle_id: adjusted.widget_definitions[toggle_id]}
    )
    melee_view._widgets_by_name = lua.table_from(
        {toggle_id: melee_definitions.widget_definitions[toggle_id]}
    )
    sortable_view._selected_sort_option_index = 1
    sortable_view._sort_grid_layout = lua.eval(
        "function(self, sort_function) self.resorted = sort_function ~= nil end"
    )
    melee_view._sort_options = sortable_view._sort_options
    melee_view._selected_sort_option_index = 1
    melee_view._sort_grid_layout = lua.eval(
        "function(self, sort_function) self.resorted = sort_function ~= nil end"
    )
    features.bind_inventory_sort_toggle(mod, layout, sortable_view)
    features.bind_inventory_sort_toggle(mod, layout, melee_view)
    sortable_view._widgets_by_name[toggle_id].content.hotspot.pressed_callback()
    assert mod.settings.prioritize_equipped_favorites is False
    assert sortable_view.resorted is True
    assert melee_view.resorted is True
    assert sortable_view._widgets_by_name[toggle_id].content.checked is False
    assert melee_view._widgets_by_name[toggle_id].content.checked is False

    mod.settings.prioritize_equipped_favorites = True
    features.sync_inventory_sort_setting(mod, layout)
    assert sortable_view._widgets_by_name[toggle_id].content.checked is True
    assert melee_view._widgets_by_name[toggle_id].content.checked is True

    features.unregister_inventory_view(melee_view)
    mod.settings.prioritize_equipped_favorites = False
    features.sync_inventory_sort_setting(mod, layout)
    assert sortable_view._widgets_by_name[toggle_id].content.checked is False
    assert melee_view._widgets_by_name[toggle_id].content.checked is True


if __name__ == "__main__":
    main()
