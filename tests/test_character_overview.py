from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_character_overview.lua"
)


def item(lua, **values):
    return lua.table_from(values)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    overview = lua.execute(MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH))

    old = item(
        lua,
        gear_id="old",
        name="Old Curio",
        icon_name="old-icon",
        item_level=400,
        rarity=3,
        traits=lua.table_from([lua.table_from({"id": "health"})]),
        properties=lua.table_from([lua.table_from({"id": "toughness"})]),
    )
    new = item(
        lua,
        gear_id="new",
        name="New Curio",
        icon_name="new-icon",
        item_level=410,
        rarity=5,
        traits=lua.table_from(
            [lua.table_from({"id": "health"}), lua.table_from({"id": "toughness"})]
        ),
        properties=lua.table_from(
            [
                lua.table_from({"id": "toughness"}),
                lua.table_from({"id": "stamina"}),
            ]
        ),
    )

    assert overview.changed(old, old) is False
    assert overview.changed(old, new) is True
    assert overview.changed(old, None) is True
    assert overview.changed(None, new) is True

    model = overview.build_model(new, "curio", lua.table_from({"selected": True, "widget_type": "curio"}))
    assert model.empty is False
    assert model.identity == "new"
    assert model.name == "New Curio"
    assert model.icon == "new-icon"
    assert model.item_level == 410
    assert model.rarity == 5
    assert model.traits_count == 2
    assert model.properties_count == 2
    assert model.selected is True
    assert "new" in model.render_key

    empty_model = overview.build_model(None, "curio", None)
    assert empty_model.empty is True
    assert empty_model.identity is None
    assert empty_model.render_key is None

    content = lua.table_from(
        {
            "better_inventory_curio_fit_initialized": True,
            "better_inventory_full_display_name": "stale",
            "better_inventory_overview_full_curio_stat_1": "old line",
            "better_inventory_overview_fitted_curio_stat_2": "old fitted line",
        }
    )
    assert overview.clear_derived_content(content, 4) is True
    assert content.better_inventory_curio_fit_initialized is None
    assert content.better_inventory_full_display_name is None
    assert content.better_inventory_overview_full_curio_stat_1 is None
    assert content.better_inventory_overview_fitted_curio_stat_2 is None

    wrap_rows = lua.eval(
        """
        function(text, font_size)
            local maximum_characters = math.max(1, math.floor(125 / (font_size * 0.6)))
            local rows = {}
            local row = ""

            for word in string.gmatch(text, "%S+") do
                local candidate = row == "" and word or row .. " " .. word

                if #candidate > maximum_characters and row ~= "" then
                    rows[#rows + 1] = row
                    row = word
                else
                    row = candidate
                end
            end

            if row ~= "" then
                rows[#rows + 1] = row
            end

            return rows
        end
        """
    )
    crop_row = lua.eval("function(text) return string.sub(text, 1, 12) end")
    long_title = "Laurel of the Righteous (Reliquary)"
    fitted_title, fitted_font_size, fitted_lines, cropped = overview.fit_title(
        long_title, 18, 6, 2, wrap_rows, crop_row
    )
    assert fitted_font_size < 18
    assert fitted_lines <= 2
    assert fitted_title.count("\n") <= 1
    assert fitted_title.replace("\n", " ") == long_title
    assert cropped is False

    impossible_wrap = lua.eval("function() return {'one', 'two', 'three'} end")
    cropped_title, minimum_size, cropped_lines, was_cropped = overview.fit_title(
        "one two three", 10, 8, 2, impossible_wrap, crop_row
    )
    assert minimum_size == 8
    assert cropped_lines == 2
    assert cropped_title.count("\n") == 1
    assert was_cropped is True

    print("BetterInventory Character Overview view-model tests passed.")


if __name__ == "__main__":
    main()
