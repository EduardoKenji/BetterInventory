from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
LAYOUT_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_layout.lua"


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

        function callback(fn, ...)
            local bound = {...}
            local bound_count = select("#", ...)

            return function(...)
                local arguments = {}
                local call_count = select("#", ...)

                for i = 1, bound_count do
                    arguments[#arguments + 1] = bound[i]
                end

                for i = 1, call_count do
                    arguments[#arguments + 1] = select(i, ...)
                end

                local unpack_values = table.unpack or unpack

				return fn(unpack_values(arguments, 1, bound_count + call_count))
            end
        end

        captured_render_context = nil
        Managers = { ui = {} }

        function Managers.ui:load_item_icon(item, on_loaded, render_context, dummy_profile, prioritize)
            captured_render_context = render_context
            on_loaded(2, 3, 4, "test_render_target")
            return 77
        end

        test_mod = {
            settings = {
                columns = 3,
                grid_spacing = 10,
                card_height = 110,
                icon_darkness = 25,
                show_pattern_mark = true,
                show_rarity_name = true,
                show_rarity_tag = true,
                compact_favorite_marker = true,
                item_name_font_size = 16,
                secondary_text_font_size = 13,
                expertise_font_size = 20,
                enable_melee_inventory = true,
                enable_ranged_inventory = false,
                enable_curio_inventory = true,
            }
        }

        function test_mod:get(setting_id)
            return self.settings[setting_id]
        end

        sentinel_unload = function() end
        sentinel_update = function() end
        test_blueprint = {
            size = { 586, 110 },
            unload_icon = sentinel_unload,
            update = sentinel_update,
            pass_template = {
                { style_id = "icon", style = { material_values = {} } },
                { style_id = "loading", style = {} },
                { style_id = "display_name", style = {} },
                { style_id = "sub_display_name", style = {} },
                { style_id = "rarity_name", style = {} },
                { style_id = "item_level", style = {} },
                { style_id = "rarity_tag", style = {} },
                { style_id = "equipped_icon", style = {} },
                { style_id = "favorite_icon", value = "Favorite", style = {} },
                { style_id = "salvage_icon", style = {} },
                { style_id = "salvage_circle", style = {} },
                { style_id = "inner_shadow", style = { size = {} } },
                { style_id = "inner_highlight", style = { size = {} } },
                { style_id = "required_level_background", style = { offset = {} } },
                { style_id = "required_level", style = { offset = {} } },
                { style_id = "warning_message_background", style = { offset = {} } },
                { style_id = "warning_message", style = { offset = {} } },
                {
                    value = "content/ui/materials/symbols/new_item_indicator",
                    style = {},
                },
            },
        }
        """
    )

    layout = lua.execute(LAYOUT_PATH.read_text(encoding="utf-8"))
    globals_ = lua.globals()
    mod = globals_.test_mod
    blueprint = globals_.test_blueprint

    item_size = layout.item_size(mod, 640)
    assert (item_size[1], item_size[2]) == (206, 110)

    assert layout.is_enabled_for_view(mod, lua.table_from({"_selected_slot": lua.table_from({"name": "slot_primary"})}))
    assert not layout.is_enabled_for_view(mod, lua.table_from({"_selected_slot": lua.table_from({"name": "slot_secondary"})}))
    assert layout.is_enabled_for_view(mod, lua.table_from({"_selected_slot": lua.table_from({"name": "slot_attachment_2"})}))
    assert not layout.is_enabled_for_view(mod, lua.table_from({"_selected_slot": lua.table_from({"name": "slot_gear_head"})}))

    layout.configure_item_blueprint(mod, blueprint, 640)

    assert (blueprint.size[1], blueprint.size[2]) == (206, 110)
    assert lua.eval("test_blueprint.unload_icon == sentinel_unload")
    assert lua.eval("test_blueprint.update == sentinel_update")

    icon_pass = blueprint.pass_template[1]
    assert (icon_pass.style.size[1], icon_pass.style.size[2]) == (206, 110)
    assert tuple(icon_pass.style.color[index] for index in range(1, 5)) == (255, 191, 191, 191)

    widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(
                {"icon": lua.table_from({"material_values": lua.table_from({})})}
            ),
        }
    )
    element = lua.table_from({"item": lua.table_from({"gear_id": "test-gear"})})

    blueprint.load_icon(None, widget, element, None, None, True)

    assert widget.content.icon_load_id == 77
    assert (globals_.captured_render_context.size[1], globals_.captured_render_context.size[2]) == (206, 110)
    assert widget.style.icon.material_values.render_target == "test_render_target"
    assert widget.style.icon.material_values.grid_index == 1

    grid = lua.table_from({"_menu_settings": lua.table_from({})})
    layout.configure_grid(mod, grid)
    assert (grid._menu_settings.grid_spacing[1], grid._menu_settings.grid_spacing[2]) == (10, 10)

    print("BetterInventory layout behavior tests passed.")


if __name__ == "__main__":
    main()
