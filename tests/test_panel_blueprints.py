from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
BLUEPRINT_PATH = (
    PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "darktide" / "panel_blueprints.lua"
)


def load_blueprints():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        "Color = setmetatable({}, {__index = function() return function(...) return {...} end end})"
    )
    lua.globals().require = lambda _name: lua.table_from(
        {"default_mouse_hover": "hover", "default_click": "click"}
    )
    lua.execute(
        "table.clone = function(value) local result = {} for key, item in pairs(value) do result[key] = item end return result end"
    )
    blueprints = lua.execute(
        BLUEPRINT_PATH.read_text(encoding="utf-8"), name=str(BLUEPRINT_PATH)
    )
    return lua, blueprints


def main() -> None:
    lua, blueprints = load_blueprints()
    row = blueprints.definitions.auto_crafter_row
    lua_function = lua.eval("function(sink) return function(...) sink(...) end end")

    def template(variant, **extra):
        entry = lua.table_from({"size": lua.table_from([420, 40]), "variant": variant, **extra})
        assert row.size_function(None, entry)[1] == 420
        return row.pass_template_function(None, entry)

    # Every row variant resolves to a non-empty pass template; unknown variants
    # fall back to the summary line instead of failing the whole panel.
    for variant in (
        "title", "status", "queue_job", "currency", "section", "selector", "checkbox",
        "stepper", "dump_target_stepper", "acquisition_stepper", "enum_stepper",
        "action", "offer", "summary", "unrecognised",
    ):
        passes = template(variant)
        assert len(passes) >= 2, variant
        for pass_definition in passes.values():
            assert pass_definition["pass_type"] in ("text", "rect", "texture", "hotspot", "logic")

    # Offer rows toggle between selected and normal presentation.
    visible = {
        p["style_id"]: p["visibility_function"]
        for p in template("offer").values()
        if p["style_id"] and p["visibility_function"]
    }
    selected_content, plain_content = lua.table_from({"selected": True}), lua.table_from({})
    assert visible["selected_background"](selected_content) is True
    assert visible["normal_background"](selected_content) is False
    assert visible["label"](plain_content) is True

    # Action buttons highlight only while enabled.
    action = template("action")
    assert action[2]["visibility_function"](lua.table_from({"enabled": True})) is True
    assert action[2]["visibility_function"](plain_content) is False
    assert action[3]["visibility_function"](plain_content) is True

    # Trait presses dispatch right-click first, then left-click, else nothing.
    calls = []
    left = lua_function(lambda: calls.append("left"))
    right = lua_function(lambda: calls.append("right"))
    press = blueprints.dispatch_trait_press
    assert press(lua.table_from({"on_pressed": True, "on_right_pressed": True}), left, right) is True
    assert press(lua.table_from({"on_pressed": True}), left, right) is True
    assert press(lua.table_from({"on_pressed": True}), None, right) is False
    assert press(None, left, right) is False
    assert calls == ["right", "left"]

    # Stat grid: five buttons at most, selection/hover visibility, press callback.
    pressed = []
    stat_entry = lua.table_from({
        "stat_buttons": lua.table_from([lua.table_from({"name": f"stat_{i}"}) for i in range(1, 8)]),
        "stat_pressed_callback": lua_function(pressed.append),
    })
    stat_passes = blueprints.stat_grid_passes(300, stat_entry)
    assert len(stat_passes) == 1 + 5 * 7
    hotspot_ids = [p["content_id"] for p in stat_passes.values() if p["pass_type"] == "hotspot"]
    assert hotspot_ids == [f"stat_hotspot_{i}" for i in range(1, 6)]
    stat_content = lua.table_from({
        "stat_count": 5, "selected_stat_index": 2,
        "stat_hotspot_4": lua.table_from({"is_hover": True, "on_pressed": True}),
    })
    # Per button: hotspot, selected rect, normal rect, hover rect, frame, two labels.
    selected_rect, normal_rect = stat_passes[3], stat_passes[4]
    assert selected_rect["visibility_function"](lua.table_from({"stat_count": 5, "selected_stat_index": 1})) is True
    assert selected_rect["visibility_function"](stat_content) is False
    assert normal_rect["visibility_function"](stat_content) is True
    assert normal_rect["style"]["size"][1] == (300 - 12) / 3
    hover_rect_for_four = stat_passes[1 + 3 * 7 + 4]
    assert hover_rect_for_four["visibility_function"](stat_content)
    stat_passes[1]["value"](None, None, None, stat_content)
    assert pressed == ["stat_4"]
    stat_passes[1]["value"](None, None, None, lua.table_from({"stat_count": 5}))
    assert pressed == ["stat_4"]
    assert len(blueprints.stat_grid_passes(300, None)) == 1

    # Custom stat grid: decrease/increase dispatch and total validity colours.
    deltas = []
    custom = blueprints.custom_stat_grid_passes(300)
    callbacks = lua.table_from({3: lua_function(deltas.append)})
    for key in ("custom_stat_decrease_hotspot_3", "custom_stat_increase_hotspot_3"):
        custom[1]["value"](None, None, None, lua.table_from({
            "custom_stat_callbacks": callbacks,
            key: lua.table_from({"on_pressed": True}),
        }))
    custom[1]["value"](None, None, None, plain_content)
    assert deltas == [-1, 1]
    totals = [p for p in custom.values() if p["value_id"] == "custom_stat_total"]
    assert len(totals) == 2
    assert totals[0]["visibility_function"](lua.table_from({"custom_stat_total_value": "380"})) is True
    assert totals[1]["visibility_function"](lua.table_from({"custom_stat_total_value": 379})) is True
    assert totals[1]["visibility_function"](lua.table_from({"custom_stat_total_value": 380})) is False

    # Trait grid: optional icons, target highlighting and press dispatch.
    traits = template("trait_grid", trait_count=6, trait_columns=3, trait_button_height=30, trait_icons=True)
    icon = [p for p in traits.values() if p["style_id"] == "trait_icon_2"]
    assert len(icon) == 1
    assert icon[0]["visibility_function"](lua.table_from({"trait_icon_2": "icon"})) is True
    assert icon[0]["visibility_function"](lua.table_from({"trait_icon_2": ""})) is False
    first_cell = [p for p in traits.values() if p["pass_type"] == "rect" and p["style"]["offset"][1] == 0 and p["style"]["offset"][2] == 0]
    target_one, target_two, unselected = first_cell
    assert target_one["visibility_function"](lua.table_from({"trait_target_1_index": 1})) is True
    assert target_two["visibility_function"](lua.table_from({"trait_target_2_index": 1})) is True
    assert unselected["visibility_function"](lua.table_from({"trait_target_1_index": 2})) is True
    trait_calls = []
    traits[1]["value"](None, None, None, lua.table_from({
        "trait_count": 6,
        "trait_hotspot_2": lua.table_from({"on_right_pressed": True}),
        "trait_right_callbacks": lua.table_from({2: lua_function(lambda: trait_calls.append("r2"))}),
    }))
    assert trait_calls == ["r2"]
    assert len(template("trait_grid")) == 1

    # Init copies initial content (cloning tables), binds the offer callback,
    # and runs bind/refresh hooks; update refreshes only when a hook exists.
    events = []
    widget = lua.table_from({"content": lua.table_from({"hotspot": lua.table()})})
    entry = lua.table_from({
        "offer": True,
        "initial_content": lua.table_from({"nested": lua.table_from({"a": 1})}),
        "bind": lua_function(lambda _widget: events.append("bind")),
        "refresh": lua_function(lambda _widget: events.append("refresh")),
    })
    lua.globals().callback = lambda parent, name, _widget, _entry: f"{parent}:{name}"
    row.init("P", widget, entry, "on_offer")
    assert widget.content.hotspot.pressed_callback == "P:on_offer"
    entry.initial_content.nested.a = 2
    assert widget.content.nested.a == 1
    assert widget.content.entry.offer is True and widget.content.element.offer is True
    assert events == ["bind", "refresh"]
    row.update(None, widget)
    row.update(None, lua.table_from({"content": lua.table_from({})}))
    assert events == ["bind", "refresh", "refresh"]
    print("Panel blueprint behavior tests passed.")


if __name__ == "__main__":
    main()
