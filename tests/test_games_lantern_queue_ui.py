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
    assert '"Dump stat: %s %s\\nPerk 1: %s\\nPerk 2: %s\\nBlessings: %s"' in panel
    assert "local QUEUE_JOB_ROW_HEIGHT = 110" in panel
    assert 'color = Color.terminal_corner_selected(255, true), size = { width, height }' in panel
    assert panel.count('color = Color.terminal_background(220, true), size = { width, height }') == 1
    assert "local current = options.queue_current == true" in panel
    assert "if job then" in panel
    assert "_games_lantern_queue_snapshot" in panel
    assert "games_lantern_queue_snapshot" in facade
    assert "GamesLanternQueue.new" in facade

    # Queue orchestration remains host-owned; panel exposes explicit queue
    # lifecycle and spending-authority actions without calling queue methods.
    assert "queue:start" not in panel
    assert "queue:stop" not in panel
    assert '"Clear Queue"' in panel
    assert '"Replace Queue (Ctrl+V)"' in panel
    assert '"Confirm Replace Queue (Ctrl+V)"' in panel
    assert "_request_games_lantern_paste(current_owned)" in panel
    assert '"Queued ("' in panel
    assert '"Projected authority:' in panel
    assert "_queue_craft_confirmation_signature" in panel
    assert "_queue_craft_confirmation_text" in panel
    assert "_refresh_games_lantern_snapshots" in panel
    assert "_queue_snapshot_cache" in panel
    assert "presentation_snapshot()" in facade
    assert "aggregate_confirmation_stale" in facade
    assert "enabled = not queue_owned" in panel
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


if __name__ == "__main__":
    main()
