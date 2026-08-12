from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_image_layout.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    image_layout = lua.execute(MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH))
    settings = lua.table_from({})
    lua.globals()["image_layout_test_settings"] = settings
    mod = lua.execute(
        "return {"
        " get = function(_, setting_id) return image_layout_test_settings[setting_id] end,"
        " set = function(_, setting_id, value) image_layout_test_settings[setting_id] = value end"
        " }"
    )

    inventory_weapon = lua.table_from(
        {"image_layout_context": "inventory", "slot_kind": "slot_primary"}
    )
    default_profile = image_layout.resolve(mod, inventory_weapon, 3)
    assert default_profile["prefix"] == "weapon_image_inventory_3"
    assert default_profile["item_kind"] == "weapon"
    assert default_profile["columns"] == 3
    assert default_profile["x_offset_percent"] == 0

    # The editor dropdown does not drive runtime selection. Actual card columns
    # choose one of five independent persisted profiles.
    settings["weapon_image_inventory_profile_selector"] = 5
    assert image_layout.resolve(mod, inventory_weapon, 2)["prefix"] == "weapon_image_inventory_2"
    assert image_layout.resolve(mod, inventory_weapon, 5)["prefix"] == "weapon_image_inventory_5"

    # Only one four-slider editor is visible. It proxies the independently
    # persisted profile selected by the dropdown without changing the runtime
    # profile chosen from the card's actual column count.
    settings["weapon_image_inventory_single_x_offset_percent"] = -4
    settings["weapon_image_inventory_5_x_offset_percent"] = 17
    settings["weapon_image_inventory_editor_x_offset_percent"] = 0
    assert image_layout.initialize_settings(mod) is True
    assert settings["weapon_image_inventory_editor_x_offset_percent"] == 17
    assert settings["curio_image_global_store_3_height_offset_percent"] == 0
    settings["weapon_image_inventory_editor_x_offset_percent"] = 23
    assert image_layout.on_setting_changed(
        mod, "weapon_image_inventory_editor_x_offset_percent"
    ) is True
    assert settings["weapon_image_inventory_5_x_offset_percent"] == 23
    assert settings["weapon_image_inventory_single_x_offset_percent"] == -4
    settings["weapon_image_inventory_profile_selector"] = 1
    assert image_layout.on_setting_changed(
        mod, "weapon_image_inventory_profile_selector"
    ) is True
    assert settings["weapon_image_inventory_editor_x_offset_percent"] == -4
    assert image_layout.on_setting_changed(mod, "unrelated_setting") is False
    assert image_layout.initialize_settings(None) is False

    settings["weapon_image_inventory_3_x_offset_percent"] = 10
    settings["weapon_image_inventory_3_y_offset_percent"] = -20
    settings["weapon_image_inventory_3_width_offset_percent"] = 50
    settings["weapon_image_inventory_3_height_offset_percent"] = -50
    profile = image_layout.resolve(mod, inventory_weapon, 3)
    style = lua.table_from(
        {"offset": lua.table_from([5, 6, 4]), "size": lua.table_from([160, 80])}
    )
    assert image_layout.apply_style(style, lua.table_from([200, 100]), profile) is True
    assert [style["offset"][i] for i in range(1, 4)] == [25, -14, 4]
    assert [style["size"][i] for i in range(1, 3)] == [240, 40]

    # Logical-canvas percentages remain proportional when Darktide resolves a
    # larger card at another screen resolution.
    scaled_style = lua.table_from(
        {"offset": lua.table_from([10, 12, 4]), "size": lua.table_from([320, 160])}
    )
    assert image_layout.apply_style(scaled_style, lua.table_from([400, 200]), profile) is True
    assert [scaled_style["offset"][i] for i in range(1, 4)] == [50, -28, 4]
    assert [scaled_style["size"][i] for i in range(1, 3)] == [480, 80]

    # Hadron deliberately uses the Inventory context, while both vendor views
    # and Character Overview keep independent weapon/Curio profiles.
    assert image_layout.resolve(
        mod, lua.table_from({"image_layout_context": "inventory", "slot_kind": "curio"}), 1
    )["prefix"] == "curio_image_inventory_single"
    assert image_layout.resolve(
        mod, lua.table_from({"image_layout_context": "armoury", "slot_kind": "ranged"}), 4
    )["prefix"] == "weapon_image_armoury_4"
    assert image_layout.resolve(
        mod, lua.table_from({"image_layout_context": "global_store", "slot_kind": "curio"}), 5
    )["prefix"] == "curio_image_global_store_5"
    assert image_layout.resolve(
        mod,
        lua.table_from({"character_overview": True, "slot_kind": "melee"}),
        5,
    )["prefix"] == "weapon_image_character_overview"

    # Defaults are a literal no-op, unknown contexts fail closed, and malformed
    # values are bounded rather than producing invalid UI dimensions.
    untouched_style = lua.table_from(
        {"offset": lua.table_from([7, 8, 9]), "size": lua.table_from([100, 50])}
    )
    assert image_layout.apply_style(
        untouched_style, lua.table_from([200, 100]), default_profile
    ) is False
    assert [untouched_style["offset"][i] for i in range(1, 4)] == [7, 8, 9]
    assert image_layout.resolve(
        mod, lua.table_from({"image_layout_context": "unknown", "slot_kind": "curio"}), 3
    ) is None
    assert image_layout.resolve(mod, inventory_weapon, 0)["prefix"] == "weapon_image_inventory_single"
    assert image_layout.resolve(mod, inventory_weapon, 99)["prefix"] == "weapon_image_inventory_5"
    assert image_layout.item_kind("slot_attachment_1") == "curio"
    assert image_layout.item_kind("weapon") == "weapon"
    assert image_layout.item_kind("unsupported") is None
    assert image_layout.resolve(
        mod,
        lua.table_from({"image_layout_context": "inventory", "slot_kind": "unsupported"}),
        2,
    ) is None
    assert image_layout.resolve(
        mod,
        lua.table_from({"image_layout_context": "inventory", "slot_kind": "unsupported"}),
        2,
        "weapon",
    )["prefix"] == "weapon_image_inventory_2"

    # Settings access is defensive: absent mods, throwing getters, and
    # non-finite persisted values all resolve to safe defaults.
    assert image_layout.resolve(None, inventory_weapon, 3)["x_offset_percent"] == 0
    throwing_mod = lua.execute("return { get = function() error('settings unavailable') end }")
    assert image_layout.resolve(throwing_mod, inventory_weapon, 3)["y_offset_percent"] == 0
    settings["weapon_image_inventory_3_x_offset_percent"] = float("inf")
    assert image_layout.resolve(mod, inventory_weapon, 3)["x_offset_percent"] == 0
    settings["weapon_image_inventory_3_x_offset_percent"] = None

    settings["curio_image_character_overview_width_offset_percent"] = -999
    bounded = image_layout.resolve(
        mod,
        lua.table_from({"image_layout_context": "character_overview", "slot_kind": "curio"}),
        1,
    )
    assert bounded["width_offset_percent"] == -90
    malformed_style = lua.table_from({})
    assert image_layout.apply_style(
        malformed_style, lua.table_from([200, 100]), bounded
    ) is True
    assert malformed_style["size"][1] == 20
    assert malformed_style["size"][2] == 100
    created_geometry = lua.table_from({})
    assert image_layout.apply_style(
        created_geometry,
        lua.table_from([101, 51]),
        lua.table_from(
            {
                "x_offset_percent": 10,
                "y_offset_percent": -10,
                "width_offset_percent": 25,
                "height_offset_percent": 50,
            }
        ),
    ) is True
    assert [created_geometry["offset"][i] for i in range(1, 4)] == [10, -5, 0]
    assert [created_geometry["size"][i] for i in range(1, 3)] == [126, 77]
    assert image_layout.apply_style(None, lua.table_from([1, 1]), default_profile) is False
    assert image_layout.apply_style(lua.table_from({}), None, default_profile) is False

    blueprint = lua.table_from(
        {
            "size": lua.table_from([200, 100]),
            "pass_template": lua.table_from(
                [
                    lua.table_from({"style_id": "display_name", "style": lua.table_from({})}),
                    lua.table_from(
                        {
                            "style_id": "icon",
                            "style": lua.table_from(
                                {
                                    "offset": lua.table_from([0, 0, 4]),
                                    "size": lua.table_from([100, 50]),
                                }
                            ),
                        }
                    ),
                ]
            ),
        }
    )
    assert image_layout.apply_blueprint(
        mod,
        blueprint,
        lua.table_from({"image_layout_context": "character_overview", "slot_kind": "curio"}),
        1,
        "curio",
    ) is True
    assert image_layout.apply_blueprint(
        mod,
        lua.table_from({"size": lua.table_from([200, 100]), "pass_template": lua.table_from([])}),
        inventory_weapon,
        3,
    ) is False
    assert image_layout.apply_blueprint(mod, None, inventory_weapon, 3) is False


if __name__ == "__main__":
    main()
