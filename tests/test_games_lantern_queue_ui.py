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
    assert "_games_lantern_queue_snapshot" in panel
    assert "games_lantern_queue_snapshot" in facade
    assert "GamesLanternQueue.new" in facade

    # Queue orchestration remains host-owned; panel exposes explicit queue
    # lifecycle and spending-authority actions without calling queue methods.
    assert "queue:start" not in panel
    assert "queue:stop" not in panel
    assert '"Clear Queue"' in panel
    assert '"Replace Queue"' in panel
    assert '"Queued ("' in panel
    assert '"Projected authority:' in panel
    assert "_queue_craft_confirmation_signature" in panel
    assert "aggregate_confirmation_stale" in facade
    assert "enabled = not queue_owned" in panel


if __name__ == "__main__":
    main()
