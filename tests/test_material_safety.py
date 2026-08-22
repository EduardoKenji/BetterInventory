from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
MODULE_PATH = RUNTIME_ROOT / "BetterInventory_material_safety.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    material_safety = lua.execute(
        MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH)
    )
    lua.execute(
        """
        material_safety_warnings = {}
        material_safety_mod = {
            warning = function(_, message, ...)
                material_safety_warnings[#material_safety_warnings + 1] = string.format(message, ...)
            end,
        }
        """
    )
    mod = lua.globals().material_safety_mod
    warnings = lua.globals().material_safety_warnings
    native_icon = "content/ui/materials/icons/items/containers/item_container_landscape"

    assert material_safety.valid_material_reference(native_icon) is True
    assert material_safety.valid_material_reference("") is False
    assert material_safety.valid_material_reference(128) is False
    assert material_safety.valid_material_reference(lua.table_from([255, 128, 128, 128])) is False

    icon_pass = lua.table_from(
        {
            "pass_type": "texture_uv",
            "style_id": "icon",
            "value_id": "icon",
            "value": native_icon,
        }
    )
    assert material_safety.guard_pass(mod, icon_pass) is True
    assert material_safety.guard_pass(mod, icon_pass) is False

    content = lua.table_from({"icon": 128})
    icon_pass.change_function(content, lua.table_from({}), lua.table_from({}), 0)
    assert content.icon == native_icon
    assert len(warnings) == 1
    assert "number" in warnings[1] and "icon" in warnings[1]

    # Repeated corruption is repaired without producing a per-frame warning storm.
    content.icon = 64
    icon_pass.change_function(content, lua.table_from({}), lua.table_from({}), 0)
    assert content.icon == native_icon
    assert len(warnings) == 1
    content.icon = "content/ui/materials/custom/valid_weapon_icon"
    icon_pass.change_function(content, lua.table_from({}), lua.table_from({}), 0)
    assert content.icon == "content/ui/materials/custom/valid_weapon_icon"

    # Compatibility callbacks run between two checks. Even a callback that leaks
    # a render-target grid index into the dynamic material cannot reach UIRenderer.
    lua.globals().material_safety_original_calls = 0
    mutating_pass = lua.execute(
        """
        return {
            pass_type = "texture",
            style_id = "icon",
            value_id = "icon",
            value = "content/ui/materials/native/fallback",
            change_function = function(content)
                material_safety_original_calls = material_safety_original_calls + 1
                content.icon = 128
            end,
        }
        """
    )
    assert material_safety.guard_pass(mod, mutating_pass) is True
    mutated_content = lua.table_from({"icon": None})
    mutating_pass.change_function(mutated_content, lua.table_from({}), None, 0)
    assert lua.globals().material_safety_original_calls == 1
    assert mutated_content.icon == "content/ui/materials/native/fallback"

    blueprint = lua.table_from(
        {
            "pass_template": lua.table_from(
                [
                    lua.table_from(
                        {
                            "pass_type": "texture",
                            "value_id": "wallet_icon",
                            "value": "content/ui/materials/base/ui_default_base",
                        }
                    ),
                    lua.table_from(
                        {"pass_type": "text", "value_id": "display_name", "value": ""}
                    ),
                    lua.table_from(
                        {
                            "pass_type": "texture",
                            "value": "content/ui/materials/static/frame",
                        }
                    ),
                    lua.table_from(
                        {
                            "pass_type": "rotated_texture",
                            "value_id": "loading_icon",
                            "value": "content/ui/materials/loading/loading_small",
                        }
                    ),
                ]
            )
        }
    )
    assert material_safety.guard_blueprint(mod, blueprint) == 2
    assert material_safety.guard_blueprint(mod, blueprint) == 0

    # Reused inventory widgets get the same one-time guard, covering native cards
    # when BetterInventory's grid geometry is disabled as well as modified cards.
    widget_pass = lua.table_from(
        {
            "pass_type": "texture_uv",
            "style_id": "icon",
            "value_id": "icon",
            "value": native_icon,
        }
    )
    widget = lua.table_from(
        {
            "passes": lua.table_from([widget_pass]),
            "style": lua.table_from(
                {
                    "icon": lua.table_from(
                        {
                            "material_values": lua.table_from(
                                {"grid_index": 127, "rows": 16, "columns": 16}
                            )
                        }
                    )
                }
            ),
            "content": lua.table_from({"icon": native_icon}),
        }
    )
    assert material_safety.guard_widget(mod, widget) == 1
    widget.content.icon = 128
    widget_pass.change_function(widget.content, widget.style.icon, None, 0)
    assert widget.content.icon == native_icon
    assert widget.style.icon.material_values.grid_index == 127
    assert widget.style.icon.material_values.rows == 16
    assert widget.style.icon.material_values.columns == 16

    scoped_pass = lua.table_from(
        {
            "pass_type": "texture",
            "style_id": "icon",
            "value_id": "icon",
            "value": native_icon,
        }
    )
    scoped_widget = lua.table_from({"passes": lua.table_from([scoped_pass])})
    inventory_grid = lua.table_from({})
    inventory_view = lua.table_from(
        {"__class_name": "InventoryWeaponsView", "_item_grid": inventory_grid}
    )
    inventory_grid._parent = inventory_view
    assert material_safety.guard_inventory_widget(mod, inventory_grid, scoped_widget) == 1

    runtime_source = (RUNTIME_ROOT / "BetterInventory_runtime.lua").read_text(encoding="utf-8")
    blueprint_source = (RUNTIME_ROOT / "BetterInventory_layout_blueprints.lua").read_text(
        encoding="utf-8"
    )
    overview_source = (RUNTIME_ROOT / "BetterInventory_character_overview_ui.lua").read_text(
        encoding="utf-8"
    )
    assert "Layout.MaterialSafety.guard_inventory_widget(mod, item_grid, widget)" in runtime_source
    assert material_safety.guard_inventory_widget(
        mod,
        lua.table_from({"_parent": lua.table_from({"__class_name": "OtherView"})}),
        widget,
    ) == 0
    assert "MaterialSafety.guard_blueprint(mod, item_blueprint)" in blueprint_source
    assert "Layout.MaterialSafety.guard_blueprint(mod, blueprint)" in overview_source
    assert 'mod:hook(UIRenderer' not in runtime_source
    assert 'mod:hook(UIPasses' not in runtime_source

    print("BetterInventory material safety tests passed.")


if __name__ == "__main__":
    main()
