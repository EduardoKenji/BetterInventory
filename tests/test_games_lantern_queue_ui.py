from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PANEL_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "darktide" / "panel.lua"
FACADE_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_auto_crafter.lua"


def main() -> None:
    panel = PANEL_PATH.read_text(encoding="utf-8") + PANEL_PATH.with_name("panel_blueprints.lua").read_text(encoding="utf-8")
    facade = FACADE_PATH.read_text(encoding="utf-8")

    # The queue is visible above Planner in both manual and imported modes,
    # while detailed imported rows carry a highlighted current item.
    assert '"Active Queue"' in panel
    active_queue_entry = panel.split('localize("auto_crafter_panel_active_queue", "Active Queue")', 1)[1].split('localize("auto_crafter_panel_planner", "Planner configuration")', 1)[0]
    assert "selectable = true" in active_queue_entry and "selectable = false" not in active_queue_entry
    assert 'variant = "queue_job"' in panel
    assert "queue_current" in panel
    assert "_manual_queue_detail" in panel
    assert '"%s\\nPerk 1: %s\\nPerk 2: %s\\nBlessings: %s"' in panel
    assert '"Stats: " .. table.concat(stats, " / ")' in panel
    assert "local QUEUE_JOB_ROW_HEIGHT = 110" in panel
    queue_passes = panel.split("local function queue_job_passes", 1)[1].split("local function currency_row_passes", 1)[0]
    assert queue_passes.count("pass_type") == 9
    assert 'content_id = "hotspot"' in queue_passes and 'content_id = "remove_hotspot"' in queue_passes
    assert 'value = "X"' in queue_passes and "Color.ui_red_medium" in queue_passes
    assert "visibility_function = removable" in queue_passes
    assert "content.parent" in queue_passes and "button_y = height - 30" in queue_passes
    assert "widget.content.remove_hotspot.pressed_callback = entry.remove_callback" in panel
    assert panel.count('color = Color.terminal_background(220, true), size = { width, height }') == 1
    assert "border_color = highlighted and Color.terminal_corner_selected" in panel
    assert "entry.initial_content and entry.initial_content.queue_current == true" in panel
    assert "_games_lantern_queue_snapshot" in panel
    assert "games_lantern_queue_snapshot" in facade
    assert "GamesLanternQueue.new" in facade
    assert "games_lantern_select_queue_job" in panel and "games_lantern_select_queue_job" in facade
    assert "games_lantern_remove_queue_job" in panel and "games_lantern_remove_queue_job" in facade
    assert "remove_staged_job" in facade and '"queue_job_removed"' in facade
    assert "queue_removable = not queue_active and #queue_jobs > 1" in panel
    assert '"> CONFIRM ONE-WEAPON CRAFT <"' in panel
    assert '"queue_card_selected"' in facade
    assert "games_lantern_selection.request" in facade
    assert "games_lantern_selection.restore" in facade
    assert "games_lantern_update_queue_custom_stat" in panel and "games_lantern_update_queue_custom_stat" in facade
    assert "games_lantern_update_queue_trait" in panel and "games_lantern_update_queue_trait" in facade
    assert "queue.state ~= \"staged\"" in panel

    # Queue orchestration remains host-owned; panel exposes explicit queue
    # lifecycle and spending-authority actions without calling queue methods.
    assert "queue:start" not in panel
    assert "queue:stop" not in panel
    assert '"Clear Queue"' in panel
    assert '"Paste Games Lantern build (Ctrl+V)"' in panel
    assert "_queue_replace_armed" not in panel and "replacement_confirmation_required" not in panel
    assert "_request_games_lantern_paste(current_owned)" in panel
    assert '"Queued ("' in panel
    assert '"Projected authority:' in panel
    assert "_queue_craft_confirmation_signature" in panel
    assert "_queue_craft_confirmation_text" in panel
    assert "_refresh_games_lantern_snapshots" in panel and "invalidate_games_lantern_snapshots" in panel
    assert "invalidate_games_lantern_panel()" in facade
    assert "_queue_snapshot_cache" in panel
    assert "presentation_snapshot()" in facade
    assert "aggregate_confirmation_stale" in facade
    assert "enabled = not queue_active" in panel
    assert "craft_enabled = not run_is_active() and not import_busy" in panel
    assert "workflow_active(self._controller_state" in panel
    assert "selectable = stop_enabled" in panel

    # Manual mark selection sits between Planner and trait targeting. Estimates
    # own all projected costs and remain immediately above Craft.
    planner = panel.index('localize("auto_crafter_panel_planner", "Planner configuration")')
    marks = panel.index('localize("auto_crafter_panel_marks", "Marks")')
    dump_stat = panel.index('localize("auto_crafter_panel_dump_stat", "Dump stat")')
    traits = panel.index('localize("auto_crafter_panel_trait_targets", "Perk and blessing targets")')
    estimates = panel.index('localize("auto_crafter_panel_estimates", "Estimates")')
    craft = panel.index('localize("auto_crafter_panel_preview", "> CLICK HERE TO CRAFT <")')
    assert planner < marks < dump_stat < traits < estimates < craft
    assert "SECTION_MARKS" in panel
    assert "SECTION_ESTIMATES" in panel
    assert "selected_manual_mark" in facade

    # Invalid custom profiles are visible safety failures even if optional probe
    # notices are disabled; the queue is checked before spending confirmation.
    assert "_invalid_queue_custom_stats" in panel
    assert "_notify_craft_blocked(custom_stat_error)" in panel
    assert 'notify_blocked = function(reason)' in facade
    assert '"Mutation blocked: " .. tostring(reason), true' in facade

    # ViewElementGrid passes nested hotspot content to visibility functions.
    # Exercise that real contract: root-owned removability must keep the nested
    # hit target active, then the blueprint init must bind its direct callback.
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
        PANEL_PATH.with_name("panel_blueprints.lua").read_text(encoding="utf-8"),
        name=str(PANEL_PATH.with_name("panel_blueprints.lua")),
    )
    removed = []
    callback = lua.eval("function(callback) return function() callback() end end")(
        lambda: removed.append(True)
    )
    passes = blueprints.queue_job_passes(
        420, 110, False, lua.table_from({"remove_callback": callback})
    )
    remove_pass = passes[6]
    assert remove_pass["content_id"] == "remove_hotspot"
    assert remove_pass["style"]["offset"][2] == 80
    root_content = lua.table_from({"queue_removable": True})
    nested_content = lua.table_from({"parent": root_content})
    assert remove_pass["visibility_function"](nested_content, None) is True
    root_content["queue_removable"] = False
    assert remove_pass["visibility_function"](nested_content, None) is False

    widget = lua.table_from(
        {"content": lua.table_from({"hotspot": lua.table(), "remove_hotspot": lua.table()})}
    )
    entry = lua.table_from(
        {
            "initial_content": lua.table_from({"queue_removable": True}),
            "remove_callback": callback,
        }
    )
    blueprints.definitions.auto_crafter_row.init(None, widget, entry, None)
    widget.content.remove_hotspot.pressed_callback()
    assert removed == [True]


if __name__ == "__main__":
    main()
