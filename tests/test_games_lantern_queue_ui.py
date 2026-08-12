from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PANEL_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "darktide" / "panel.lua"
FACADE_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_auto_crafter.lua"


def main() -> None:
    panel = PANEL_PATH.read_text(encoding="utf-8")
    facade = FACADE_PATH.read_text(encoding="utf-8")

    # The queue is visible above Planner in both manual and imported modes,
    # while detailed imported rows carry a highlighted current item.
    assert '"Active Queue"' in panel
    assert 'variant = "queue_job"' in panel
    assert "queue_current" in panel
    assert "_manual_queue_detail" in panel
    assert '"%s\\nPerk 1: %s\\nPerk 2: %s\\nBlessings: %s"' in panel
    assert '"Stats: " .. table.concat(stats, " / ")' in panel
    assert "local QUEUE_JOB_ROW_HEIGHT = 110" in panel
    queue_passes = panel.split("local function queue_job_passes", 1)[1].split("local function currency_row_passes", 1)[0]
    assert queue_passes.count("pass_type") == 5 and 'content_id = "hotspot"' in queue_passes and "visibility_function" not in queue_passes
    assert panel.count('color = Color.terminal_background(220, true), size = { width, height }') == 1
    assert "border_color = highlighted and Color.terminal_corner_selected" in panel
    assert "entry.initial_content and entry.initial_content.queue_current == true" in panel
    assert "_games_lantern_queue_snapshot" in panel
    assert "games_lantern_queue_snapshot" in facade
    assert "GamesLanternQueue.new" in facade
    assert "games_lantern_select_queue_job" in panel and "games_lantern_select_queue_job" in facade
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
    assert "craft_enabled = not queue_active and not import_busy" in panel

    # Manual mark selection sits between Planner and trait targeting. Estimates
    # own all projected costs and remain immediately above Craft.
    planner = panel.index('localize("auto_crafter_panel_planner", "Planner configuration")')
    marks = panel.index('localize("auto_crafter_panel_marks", "Marks")')
    traits = panel.index('localize("auto_crafter_panel_trait_targets", "Perk and blessing targets")')
    estimates = panel.index('localize("auto_crafter_panel_estimates", "Estimates")')
    craft = panel.index('localize("auto_crafter_panel_preview", "> CLICK HERE TO CRAFT <")')
    assert planner < marks < traits < estimates < craft
    assert "SECTION_MARKS" in panel
    assert "SECTION_ESTIMATES" in panel
    assert "selected_manual_mark" in facade

    # Invalid custom profiles are visible safety failures even if optional probe
    # notices are disabled; the queue is checked before spending confirmation.
    assert "_invalid_queue_custom_stats" in panel
    assert "_notify_craft_blocked(custom_stat_error)" in panel
    assert 'notify_blocked = function(reason)' in facade
    assert '"Mutation blocked: " .. tostring(reason), true' in facade


if __name__ == "__main__":
    main()
