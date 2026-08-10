from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
FACADE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_auto_crafter.lua"
)


def main() -> None:
    source = FACADE_PATH.read_text(encoding="utf-8")

    # Per-frame UI failures detach only the panel; controller failures stop the
    # workflow and cannot escape through mod.update into Darktide's frame loop.
    assert "pcall(active_panel.update, active_panel, dt)" in source
    assert 'pcall(controller.update, controller, dt)' in source
    assert 'pcall(controller.on_context_exit, controller, "controller_update_crash")' in source
    assert "controller_faulted = true" in source
    assert "pcall(rebuild_hud_lines, snapshot)" in source
    assert "pcall(panel.sync_controller_snapshot, panel, snapshot)" in source
    assert "function AutoCrafter.interrupt_for_external_mutation(kind)" in source
    assert "snapshot.operation_inflight or snapshot.operation_quarantined" in source

    print("Auto Crafter facade crash-containment checks passed.")


if __name__ == "__main__":
    main()
