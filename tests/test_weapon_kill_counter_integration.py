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


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    mod, wkc = lua.execute(
        r"""
        local settings = {
            debug_weapon_kill_counter_kills = 0,
            show_pattern_mark = false,
            show_rarity_name = false,
        }
        local mod = {
            settings = settings,
            get = function(self, setting_id)
                return self.settings[setting_id]
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

    # Optional native subtitle rows move the counter downward rather than
    # allowing title, mark, rarity, and kills to overlap.
    mod.settings.show_pattern_mark = True
    assert integration.profile(mod, 210, 12, lua.table_from({}), 3).top == 54
    mod.settings.show_rarity_name = True
    assert integration.profile(mod, 210, 12, lua.table_from({}), 3).top == 74
    mod.settings.show_pattern_mark = False
    mod.settings.show_rarity_name = False

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

    text_pass.change_function(weapon_content)
    icon_pass.change_function(weapon_content)
    assert weapon_content.wkc_kills == "77"
    assert weapon_content.wkc_kills_icon == "test/wkc/icon"

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
