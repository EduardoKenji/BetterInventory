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

    # Batch 3 is display-only. It must not wire queue start/stop into the
    # existing manual craft action before the later orchestration batch.
    assert "queue:start" not in panel
    assert "queue:stop" not in panel


if __name__ == "__main__":
    main()
