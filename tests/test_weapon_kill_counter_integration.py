from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_wkc_integration.lua"
)
EDITOR_PATH = MODULE_PATH.with_name("BetterInventory_item_customization_editor.lua")
RUNTIME_PATH = MODULE_PATH.with_name("BetterInventory_runtime.lua")


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    mod, wkc = lua.execute(
        r"""
        local settings = {
            debug_weapon_kill_counter_kills = 0,
            show_pattern_mark = false,
            weapon_kill_counter_show_zero_kills = true,
        }
        package.preload["scripts/utilities/items"] = function()
            return {
                is_weapon = function(item_type)
                    return item_type == "WEAPON"
                end,
            }
        end
        local mod = {
            settings = settings,
            get = function(self, setting_id)
                return self.settings[setting_id]
            end,
            hook_safe = function(self, class_name, method_name, callback)
                self.hooked_class_name = class_name
                self.hooked_method_name = method_name
                self.hooked_callback = callback
            end,
        }
        local wkc = {
            _stats = {
                weapons = {
                    combat_axe = {kills = 77},
                },
            },
            settings = {wkc_card_kills = true},
            card = {
                on = true,
                icon_on = true,
                x = -244,
                y = 10,
                layer = 0,
                icon_size = 34,
                gap = 0,
                font_size = 24,
                text_w = 58,
                font_type = "proxima_nova_bold",
                color = {a = 255, r = 210, g = 220, b = 230},
                icon_color = {a = 255, r = 190, g = 200, b = 210},
            },
            get = function(self, setting_id)
                return self.settings[setting_id]
            end,
            _layout_geom = function()
                return {card = wkc_test_mod.card}
            end,
            _overlay_kills_for_item = function(item)
                local stat = wkc_test_mod._stats.weapons[item.template_name]

                return stat and stat.kills or nil
            end,
            _abbrev_num = function(value)
                return value == 1000 and "1k" or tostring(value)
            end,
            _card_offsets = function(configuration)
                return configuration.x, configuration.y
            end,
            _overlay_icon_material = function()
                return "test/wkc/icon"
            end,
        }

        return mod, wkc
        """
    )
    lua.globals()["wkc_test_mod"] = wkc
    lua.execute(
        r"""
        function get_mod(name)
            if name == "wkc" then
                return wkc_test_mod
            end

            return nil
        end
        """
    )
    integration = lua.execute(
        MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH)
    )

    weapon_content = lua.table_from(
        {
            "better_inventory_is_weapon": True,
            "item": lua.table_from({"template_name": "combat_axe"}),
        }
    )
    curio_content = lua.table_from(
        {
            "better_inventory_is_weapon": False,
            "item": lua.table_from({"template_name": "combat_axe"}),
        }
    )

    assert integration.resolve_kills(mod, weapon_content) == 77
    assert integration.resolve_kills(mod, curio_content) is None

    unused_weapon_content = lua.table_from(
        {
            "better_inventory_is_weapon": True,
            "item": lua.table_from(
                {"template_name": "unused_sword", "item_type": "WEAPON"}
            ),
        }
    )
    assert integration.resolve_kills(mod, unused_weapon_content) == 0
    mod.settings.weapon_kill_counter_show_zero_kills = False
    assert integration.resolve_kills(mod, unused_weapon_content) is None
    mod.settings.weapon_kill_counter_show_zero_kills = True

    # Three-column Inventory/Hadron cards keep the row below the weapon title,
    # but use legible type and an icon large enough to match WKC's visual weight.
    grid = integration.profile(mod, 210, 12, lua.table_from({}), 3)
    assert grid.compact is True
    assert grid.native is False
    assert grid.top == 34
    assert grid.icon_size == 19
    assert grid.font_size == 18
    assert grid.left == 9
    assert grid.text_left == 31
    assert grid.layer == 16
    assert integration.compact_card_height_padding(mod, lua.table_from({}), 3) == 7
    assert integration.compact_card_height_padding(mod, lua.table_from({}), 2) == 0
    assert integration.compact_card_height_padding(
        mod, lua.table_from({"native_single_column": True}), 3
    ) == 0

    single = integration.profile(
        mod,
        420,
        15,
        lua.table_from({"native_single_column": True, "card_height": 140}),
        1,
    )
    assert single.compact is False
    assert single.native is True
    assert single.icon_size == 34
    assert single.font_size == 24
    assert single.left == -303
    assert single.text_left == -245
    assert single.text_width == 58
    assert single.top == 6
    assert single.horizontal_alignment == "right"
    assert single.vertical_alignment == "center"
    assert single.layer == 0

    overview = integration.profile(
        mod,
        420,
        15,
        lua.table_from(
            {"native_single_column": True, "character_overview": True}
        ),
        1,
    )
    assert overview.native is True
    assert overview.icon_size == 34
    assert overview.font_size == 24
    assert overview.left == -302
    assert overview.text_left == -244
    assert overview.top == 10
    assert overview.horizontal_alignment == "right"
    assert overview.vertical_alignment == "center"
    assert overview.layer == 0

    # The optional native pattern row moves the counter downward rather than
    # allowing the title, pattern, and kill counter to overlap.
    mod.settings.show_pattern_mark = True
    assert integration.profile(mod, 210, 12, lua.table_from({}), 3).top == 54
    mod.settings.show_pattern_mark = False

    # New horizontal rarity profiles own the optional rows above WKC. The
    # default 13 px rating font uses a compact 15 px advance. Persisted values
    # from the removed vertical experiment safely resolve to the Full row.
    mod.settings.weapon_rarity_rating_mode = "compact_horizontal"
    assert integration.profile(mod, 210, 12, lua.table_from({}), 3).top == 45
    mod.settings.weapon_rarity_rating_mode = "full_horizontal"
    assert integration.profile(mod, 210, 12, lua.table_from({}), 3).top == 45
    mod.settings.show_pattern_mark = True
    assert integration.profile(mod, 210, 12, lua.table_from({}), 3).top == 65
    mod.settings.show_pattern_mark = False
    mod.settings.weapon_rarity_rating_mode = "vertical"
    assert integration.profile(mod, 210, 12, lua.table_from({}), 3).top == 45
    mod.settings.weapon_rarity_rating_mode = "off"

    pass_template = lua.execute(
        r"""
        return {
            {pass_type = "text", style_id = "unrelated", style = {}},
            {pass_type = "text", style_id = "wkc_kills", style = {}},
            {pass_type = "text", style_id = "wkc_kills", style = {}},
            {pass_type = "texture", style_id = "wkc_kills_icon", style = {}},
        }
        """
    )
    assert integration.configure_passes(
        mod, pass_template, 210, 12, lua.table_from({}), 3
    ) is True
    assert len(pass_template) == 3

    text_pass = next(
        pass_template[index]
        for index in range(1, len(pass_template) + 1)
        if pass_template[index].style_id == "wkc_kills"
    )
    icon_pass = next(
        pass_template[index]
        for index in range(1, len(pass_template) + 1)
        if pass_template[index].style_id == "wkc_kills_icon"
    )
    assert text_pass.style.font_size == 18
    assert text_pass.style.offset[2] == 34
    assert text_pass.style.horizontal_alignment == "left"
    assert text_pass.style.vertical_alignment == "top"
    assert icon_pass.style.size[1] == 19
    assert icon_pass.style.offset[2] == 34
    assert icon_pass.value == "test/wkc/icon"
    assert text_pass.visibility_function(weapon_content) is True
    assert icon_pass.visibility_function(weapon_content) is True
    assert text_pass.visibility_function(unused_weapon_content) is True
    assert icon_pass.visibility_function(unused_weapon_content) is True

    text_pass.change_function(weapon_content)
    icon_pass.change_function(weapon_content)
    assert weapon_content.wkc_kills == "77"
    assert weapon_content.wkc_kills_icon == "test/wkc/icon"
    text_pass.change_function(unused_weapon_content)
    icon_pass.change_function(unused_weapon_content)
    assert unused_weapon_content.wkc_kills == "0"
    assert unused_weapon_content.wkc_kills_icon == "test/wkc/icon"

    mod.settings.weapon_kill_counter_show_zero_kills = False
    assert text_pass.visibility_function(unused_weapon_content) is False
    assert icon_pass.visibility_function(unused_weapon_content) is False
    mod.settings.weapon_kill_counter_show_zero_kills = True

    # Store grids retain WKC's native hide-empty behavior. BetterInventory
    # synthesizes skull + 0 only for owned inventory cards, while preserving
    # real positive counts in every view.
    store_template = lua.table_from([])
    assert integration.configure_passes(
        mod,
        store_template,
        210,
        12,
        lua.table_from({"store_item": True}),
        3,
    ) is True
    store_text_pass = next(
        store_template[index]
        for index in range(1, len(store_template) + 1)
        if store_template[index].style_id == "wkc_kills"
    )
    store_icon_pass = next(
        store_template[index]
        for index in range(1, len(store_template) + 1)
        if store_template[index].style_id == "wkc_kills_icon"
    )
    assert store_text_pass.visibility_function(weapon_content) is True
    assert store_icon_pass.visibility_function(weapon_content) is True
    assert store_text_pass.visibility_function(unused_weapon_content) is False
    assert store_icon_pass.visibility_function(unused_weapon_content) is False

    # Brunt's native two-column cards bypass BetterInventory's custom grid
    # profile. Cap WKC's raw 22/20 px listing pair after grid construction and
    # again after WKC's own change functions refresh their configured sizes.
    brunt_grid = lua.execute(
        r"""
        local widget = {
            passes = {
                {
                    style_id = "wkc_kills",
                    change_function = function(content, style)
                        content.text_refreshes = (content.text_refreshes or 0) + 1
                        style.font_size = 24
                        style.horizontal_alignment = "right"
                        style.vertical_alignment = "center"
                        style.offset[1] = -210
                        style.offset[2] = 10
                    end,
                },
                {
                    style_id = "wkc_kills_icon",
                    change_function = function(content, style)
                        content.icon_refreshes = (content.icon_refreshes or 0) + 1
                        style.size[1] = 34
                        style.size[2] = 34
                        style.horizontal_alignment = "right"
                        style.vertical_alignment = "center"
                        style.offset[1] = -248
                        style.offset[2] = 10
                    end,
                },
            },
            content = {size = {292, 56}},
            style = {
                wkc_kills = {font_size = 20, size = {34, 30}, offset = {-210, 10, 12}},
                wkc_kills_icon = {size = {22, 22}, offset = {-248, 10, 12}},
            },
        }

        return {
            _all_grid_widgets = {widget},
            _grid_widgets = {widget},
        }
        """
    )
    assert integration.cap_brunt_listing_overlay_sizes(brunt_grid) == 2
    brunt_widget = brunt_grid._all_grid_widgets[1]
    assert brunt_widget.style.wkc_kills.font_size == 14
    assert brunt_widget.style.wkc_kills_icon.size[1] == 16
    assert brunt_widget.style.wkc_kills_icon.size[2] == 16
    assert brunt_widget.style.wkc_kills.horizontal_alignment == "left"
    assert brunt_widget.style.wkc_kills.vertical_alignment == "top"
    assert brunt_widget.style.wkc_kills.offset[1] == 28
    assert brunt_widget.style.wkc_kills.offset[2] == 37
    assert brunt_widget.style.wkc_kills.size[2] == 17
    assert brunt_widget.style.wkc_kills_icon.horizontal_alignment == "left"
    assert brunt_widget.style.wkc_kills_icon.vertical_alignment == "top"
    assert brunt_widget.style.wkc_kills_icon.offset[1] == 10
    assert brunt_widget.style.wkc_kills_icon.offset[2] == 37
    assert brunt_widget.dirty is True
    brunt_widget.passes[1].change_function(
        brunt_widget.content, brunt_widget.style.wkc_kills
    )
    brunt_widget.passes[2].change_function(
        brunt_widget.content, brunt_widget.style.wkc_kills_icon
    )
    assert brunt_widget.content.text_refreshes == 1
    assert brunt_widget.content.icon_refreshes == 1
    assert brunt_widget.style.wkc_kills.font_size == 14
    assert brunt_widget.style.wkc_kills_icon.size[1] == 16
    assert brunt_widget.style.wkc_kills.offset[1] == 28
    assert brunt_widget.style.wkc_kills.offset[2] == 37
    assert brunt_widget.style.wkc_kills_icon.offset[1] == 10
    assert brunt_widget.style.wkc_kills_icon.offset[2] == 37
    assert integration.cap_brunt_listing_overlay_sizes(brunt_grid) == 0

    assert integration.install_brunt_listing_hook(mod) is True
    assert integration.install_brunt_listing_hook(mod) is False
    assert mod.hooked_class_name == "ViewElementGrid"
    assert mod.hooked_method_name == "_on_present_grid_layout_changed"
    brunt_grid._parent = lua.table_from({"__class_name": "CreditsGoodsVendorView"})
    brunt_widget.style.wkc_kills.font_size = 30
    brunt_widget.style.wkc_kills_icon.size[1] = 30
    mod.hooked_callback(brunt_grid)
    assert brunt_widget.style.wkc_kills.font_size == 14
    assert brunt_widget.style.wkc_kills_icon.size[1] == 16
    assert "Layout.install_brunt_wkc_listing_hook(mod)" in RUNTIME_PATH.read_text(
        encoding="utf-8"
    )

    # WKC injects listing passes into every native item pass template. Weapon
    # information can consequently inherit multiple card counters on its stat
    # rows. Remove all three misplaced pairs while preserving WKC's dedicated
    # detail counter widget and leave a sentinel that blocks runtime reattach.
    weapon_stats = lua.execute(
        r"""
        local detail = {
            name = "wkc_detail_kills",
            passes = {{style_id = "text"}, {style_id = "wkc_icon"}},
            content = {text = "77"},
            style = {},
        }
        local rows = {}

        for index = 1, 3 do
            rows[index] = {
                name = "modifier_row_" .. tostring(index),
                passes = {
                    {style_id = "unrelated", value_id = "unrelated"},
                    {style_id = "wkc_kills", value_id = "wkc_kills"},
                    {style_id = "wkc_kills_icon", value_id = "wkc_kills_icon"},
                },
                content = {item = {template_name = "combat_axe"}, wkc_kills = "77"},
                style = {wkc_kills = {}, wkc_kills_icon = {}},
            }
        end

        return {
            _widgets = {rows[1], rows[2], rows[3], detail},
            _widgets_by_name = {
                modifier_row_1 = rows[1],
                modifier_row_2 = rows[2],
                modifier_row_3 = rows[3],
                wkc_detail_kills = detail,
            },
        }
        """
    )
    assert integration.remove_weapon_stats_listing_overlays(weapon_stats) == 6
    for index in range(1, 4):
        row = weapon_stats._widgets[index]
        assert len(row.passes) == 1
        assert row.passes[1].style_id == "unrelated"
        assert row.content.wkc_kills == ""
        assert row.style.wkc_kills is None
        assert row.style.wkc_kills_icon is None
        assert row.dirty is True
    detail = weapon_stats._widgets_by_name.wkc_detail_kills
    assert len(detail.passes) == 2
    assert detail.content.text == "77"
    assert integration.remove_weapon_stats_listing_overlays(weapon_stats) == 0
    editor_source = EDITOR_PATH.read_text(encoding="utf-8")
    assert 'mod:hook_safe("ViewElementWeaponStats", "_on_present_grid_layout_changed"' in editor_source
    assert "layout.remove_weapon_stats_wkc_listing_overlays(weapon_stats)" in editor_source

    # Native single-column and Character Overview cards retain WKC's own
    # right/centre anchoring, 34 px icon, 24 px type, and configurable offsets.
    native_template = lua.table_from([])
    assert integration.configure_passes(
        mod,
        native_template,
        420,
        15,
        lua.table_from({"native_single_column": True, "card_height": 140}),
        1,
    ) is True
    native_text_pass = next(
        native_template[index]
        for index in range(1, len(native_template) + 1)
        if native_template[index].style_id == "wkc_kills"
    )
    native_icon_pass = next(
        native_template[index]
        for index in range(1, len(native_template) + 1)
        if native_template[index].style_id == "wkc_kills_icon"
    )
    assert native_text_pass.style.horizontal_alignment == "right"
    assert native_text_pass.style.vertical_alignment == "center"
    assert native_text_pass.style.font_size == 24
    assert native_text_pass.style.offset[1] == -245
    assert native_text_pass.style.offset[2] == 6
    assert native_text_pass.style.size[1] == 58
    assert native_icon_pass.style.horizontal_alignment == "right"
    assert native_icon_pass.style.vertical_alignment == "center"
    assert native_icon_pass.style.size[1] == 34
    assert native_icon_pass.style.offset[1] == -303
    assert native_icon_pass.style.offset[2] == 6

    # The debug fixture changes only presentation. WKC itself abbreviates 1000
    # as 1k, and its persistent statistics remain byte-for-byte equivalent.
    original_kills = wkc._stats.weapons.combat_axe.kills
    mod.settings.debug_weapon_kill_counter_kills = 1000
    assert integration.resolve_kills(mod, weapon_content) == 1000
    text_pass.change_function(weapon_content)
    assert weapon_content.wkc_kills == "1k"
    assert wkc._stats.weapons.combat_axe.kills == original_kills == 77

    # WKC owns the feature toggle. BetterInventory fails closed when the mod is
    # absent, its card overlay is disabled, or the content is not a weapon.
    wkc.card.icon_on = False
    assert icon_pass.visibility_function(weapon_content) is False
    assert text_pass.visibility_function(weapon_content) is True
    wkc.card.on = False
    assert text_pass.visibility_function(weapon_content) is False
    wkc.card.on = True
    wkc.settings.wkc_card_kills = False
    assert integration.resolve_kills(mod, weapon_content) is None
    assert integration.compact_card_height_padding(mod, lua.table_from({}), 3) == 0
    wkc.settings.wkc_card_kills = True
    lua.globals()["wkc_test_mod"] = None
    assert integration.resolve_kills(mod, weapon_content) is None
    assert text_pass.visibility_function(weapon_content) is False

    late_template = lua.table_from([])
    assert integration.configure_passes(
        mod, late_template, 210, 12, lua.table_from({}), 3
    ) is True
    assert len(late_template) == 2
    lua.globals()["wkc_test_mod"] = wkc
    assert late_template[2].visibility_function(weapon_content) is True

    print("BetterInventory Weapon Kill Counter integration tests passed.")


if __name__ == "__main__":
    main()
