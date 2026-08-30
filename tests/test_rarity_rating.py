from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_rarity_rating.lua"
)


def pass_by_style_id(pass_template, style_id):
    return next(
        pass_template[index]
        for index in range(1, len(pass_template) + 1)
        if pass_template[index].style_id == style_id
    )


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    mod, items = lua.execute(
        r"""
        local function clone(value)
            if type(value) ~= "table" then
                return value
            end

            local result = {}

            for key, nested in pairs(value) do
                result[clone(key)] = clone(nested)
            end

            return result
        end

        table.clone = clone

        local items = {
            rarity_display_name = function(item)
                return item.display_rarity
            end,
            rarity_color = function(item)
                return item.color
            end,
        }

        package.preload["scripts/utilities/items"] = function()
            return items
        end

        local mod = {
            settings = {
                weapon_rarity_rating_mode = "off",
                curio_rarity_rating_mode = "off",
                secondary_text_font_size = 13,
                show_pattern_mark = false,
            },
            get = function(self, setting_id)
                return self.settings[setting_id]
            end,
        }

        return mod, items
        """
    )
    rating = lua.execute(MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH))
    base_style = lua.table_from(
        {
            "font_type": "proxima_nova_bold",
            "text_color": lua.table_from([255, 255, 255, 255]),
        }
    )

    assert rating.mode(mod, lua.table_from({})) == "off"
    assert rating.horizontal_rows(mod, lua.table_from({})) == 0
    assert rating.vertical_rail_width(mod, "melee") == 0

    mod.settings.weapon_rarity_rating_mode = "compact_horizontal"
    compact_passes = lua.table_from([])
    rating.add_passes(mod, compact_passes, 230, 114, 12, base_style, lua.table_from({}))
    assert len(compact_passes) == 1
    compact_pass = pass_by_style_id(
        compact_passes, "better_inventory_weapon_rarity_rating"
    )
    assert compact_pass.change_function is None
    assert tuple(compact_pass.style.offset[index] for index in range(1, 4)) == (12, 27, 11)
    assert rating.horizontal_rows(mod, lua.table_from({})) == 1
    assert rating.horizontal_rows(
        mod, lua.table_from({"slot_kind": "curio"})
    ) == 0

    compact_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(
                {compact_pass.style_id: compact_pass.style}
            ),
        }
    )
    transcendent = lua.table_from(
        {
            "rarity": 5,
            "display_rarity": "Transcendent",
            "color": lua.table_from([255, 240, 120, 20]),
        }
    )
    rating.populate(mod, compact_widget, transcendent, True)
    assert compact_widget.content.better_inventory_weapon_rarity_rating == "T ★★★★★", repr(
        compact_widget.content.better_inventory_weapon_rarity_rating
    )
    assert tuple(compact_pass.style.text_color[index] for index in range(1, 5)) == (
        255,
        240,
        120,
        20,
    )
    assert compact_pass.visibility_function(compact_widget.content) is True

    transcendent.display_rarity = "{#color(240,120,20)}Transcendent{#reset()}"
    rating.populate(mod, compact_widget, transcendent, True)
    assert compact_widget.content.better_inventory_weapon_rarity_rating.startswith("T ")
    assert "{" not in compact_widget.content.better_inventory_weapon_rarity_rating
    assert rating._test.rarity_name(transcendent) == "Transcendent"
    transcendent.display_rarity = "Transcendent"

    # Reconfiguring a reused blueprint replaces owned passes instead of growing
    # the template, and horizontal modes remain weapon-only.
    rating.add_passes(mod, compact_passes, 230, 114, 12, base_style, lua.table_from({}))
    assert len(compact_passes) == 1
    rating.populate(mod, compact_widget, transcendent, False)
    assert compact_widget.content.better_inventory_rarity_rating_visible is False

    mod.settings.weapon_rarity_rating_mode = "full_horizontal"
    full_passes = lua.table_from([])
    rating.add_passes(mod, full_passes, 230, 154, 12, base_style, lua.table_from({}))
    assert len(full_passes) == 1
    assert rating.horizontal_rows(mod, lua.table_from({})) == 1
    assert pass_by_style_id(
        full_passes, "better_inventory_weapon_rarity_rating"
    ).style.offset[2] == 27
    full_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(
                {full_passes[1].style_id: full_passes[1].style}
            ),
        }
    )
    rating.populate(mod, full_widget, transcendent, "weapon")
    assert full_widget.content.better_inventory_weapon_rarity_rating == (
        "Transcendent ★★★★★"
    )

    mod.settings.show_pattern_mark = True
    patterned_passes = lua.table_from([])
    rating.add_passes(mod, patterned_passes, 230, 174, 12, base_style, lua.table_from({}))
    assert pass_by_style_id(
        patterned_passes, "better_inventory_weapon_rarity_rating"
    ).style.offset[2] == 47
    mod.settings.show_pattern_mark = False

    # Curios use an independent profile and a pass anchored between their title
    # and primary line. Mixed grids retain both passes without duplicating rows.
    mod.settings.weapon_rarity_rating_mode = "off"
    mod.settings.curio_rarity_rating_mode = "full_horizontal"
    curio_passes = lua.table_from([])
    curio_configuration = lua.table_from(
        {"slot_kind": "curio", "curio_rating_top": 53}
    )
    rating.add_passes(
        mod, curio_passes, 230, 154, 12, base_style, curio_configuration
    )
    assert len(curio_passes) == 1
    curio_pass = pass_by_style_id(
        curio_passes, "better_inventory_curio_rarity_rating"
    )
    assert curio_pass.style.offset[2] == 53
    assert rating.horizontal_rows(mod, curio_configuration, "curio") == 1
    curio_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from({curio_pass.style_id: curio_pass.style}),
        }
    )
    rating.populate(mod, curio_widget, transcendent, "curio")
    assert curio_widget.content.better_inventory_curio_rarity_rating == (
        "Transcendent ★★★★★"
    )

    mod.settings.weapon_rarity_rating_mode = "compact_horizontal"
    mixed_passes = lua.table_from([])
    rating.add_passes(mod, mixed_passes, 230, 154, 12, base_style, lua.table_from({}))
    assert len(mixed_passes) == 2
    assert rating.horizontal_rows(mod, lua.table_from({})) == 1

    mod.settings.weapon_rarity_rating_mode = "vertical"
    mod.settings.curio_rarity_rating_mode = "off"
    assert rating.vertical_rail_width(mod, "melee") == 28
    assert rating.vertical_rail_width(mod, None) == 28
    assert rating.vertical_rail_width(mod, "curio") == 0
    assert rating.vertical_rail_width(mod, "slot_attachment_1") == 0
    assert rating.vertical_rail_width(
        mod, "melee", lua.table_from({"native_single_column": True})
    ) == 0

    vertical_passes = lua.table_from([])
    rating.add_passes(mod, vertical_passes, 258, 114, 40, base_style, lua.table_from({}))
    assert len(vertical_passes) == 1
    vertical_pass = pass_by_style_id(
        vertical_passes, "better_inventory_rarity_rating_vertical"
    )
    assert vertical_pass.change_function is None
    assert tuple(vertical_pass.style.size[index] for index in (1, 2)) == (23, 106)

    vertical_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(
                {vertical_pass.style_id: vertical_pass.style}
            ),
        }
    )
    sainted = lua.table_from(
        {
            "rarity": 5,
            "display_rarity": "Sainted",
            "color": lua.table_from([255, 220, 30, 15]),
            "custom_tier": True,
        }
    )
    provider = lua.execute(
        "return {matches = function(item) return item.custom_tier == true end}"
    )
    rating.set_custom_tier_provider(provider)
    rating.populate(mod, vertical_widget, sainted, True)
    assert vertical_widget.content.better_inventory_rarity_rating_vertical == (
        "S\n★\n★\n★\n★\n★\n★"
    )
    assert rating._test.effective_rarity(transcendent) == 5
    assert rating._test.effective_rarity(sainted) == 6

    chinese = lua.table_from(
        {
            "rarity": 3,
            "display_rarity": "精制",
            "color": lua.table_from([255, 30, 120, 220]),
        }
    )
    rating.populate(mod, vertical_widget, chinese, True)
    assert vertical_widget.content.better_inventory_rarity_rating_vertical == "精\n★\n★\n★"
    assert rating._test.first_utf8_character("圣化") == "圣"

    mod.settings.weapon_rarity_rating_mode = "off"
    mod.settings.curio_rarity_rating_mode = "vertical"
    assert rating.vertical_rail_width(mod, "curio") == 28
    assert rating.vertical_rail_width(mod, "slot_attachment_1") == 28
    assert rating.vertical_rail_width(mod, "melee") == 0
    rating.populate(mod, vertical_widget, transcendent, "curio")
    assert vertical_widget.content.better_inventory_rarity_rating_vertical.startswith(
        "T\n"
    )

    mod.settings.weapon_rarity_rating_mode = "invalid"
    mod.settings.curio_rarity_rating_mode = "invalid"
    assert rating.mode(mod, lua.table_from({})) == "off"

    print("BetterInventory rarity-rating behavior tests passed.")


if __name__ == "__main__":
    main()
