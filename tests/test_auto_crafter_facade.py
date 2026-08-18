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
    assert "queue_owned = queue_state and queue_state.job_count > 0" in source
    assert "local queue_state = games_lantern_queue and games_lantern_queue:state()" in source
    assert "local controller_busy = controller and controller:is_busy() or false" in source
    assert "pcall(games_lantern_queue.clear, games_lantern_queue)" in source
    assert 'pcall(games_lantern_import.cancel, games_lantern_import, "shutdown")' in source
    assert "if view and active_brunt_view ~= view then" in source
    assert "active_brunt_view = nil" in source
    assert "local configured_dependencies" in source
    assert "function AutoCrafter.ensure_configured()" in source
    assert "return controller ~= nil or AutoCrafter.configure()" in source
    assert "local function publish_hud_lines(lines)" in source
    assert "function AutoCrafter.hud_presentation()" in source
    assert 'table.concat(lines, "\\n")' in source
    assert "HudPolicy.presentation_needs_update" in source
    assert "HudPolicy.advance_completion_elapsed" in source
    assert '"Verifying final crafted weapon"' in source
    assert '"Applying selected weapon mark"' in source

    # Controller-detected Psych Ward context loss must also stop and settle the
    # host-owned imported queue after any late backend response becomes inert.
    assert 'kind == "context_exit" or kind == "phase4_complete"' in source
    assert 'queue_snapshot.stop_requested' in source
    assert '"stop_settled", { reason = "context_exit_settled" }' in source
    assert "not controller_snapshot.operation_inflight" in source
    assert "not controller_snapshot.operation_quarantined" in source

    # Staged Games Lantern planner selection mirrors Brunt's native weapon
    # preview through a bounded deferred-tab coordinator. It is cancelled at
    # crafting/lifecycle boundaries and owns no queue execution cursor.
    assert 'games_lantern/selection_coordinator' in source
    assert "games_lantern_selection.capture_original" in source
    assert '"queue_installed"' in source
    assert '"queue_card_selected"' in source
    assert "games_lantern_selection.restore" in source
    assert "games_lantern_selection.cancel_pending" in source
    assert "games_lantern_selection.abandon" in source
    assert "games_lantern_selection, active_brunt_view, dt" in source
    assert 'log("info", string.format(' in source
    assert "Brunt preview synchronization is presentation-only" in source
    assert "Games Lantern Brunt preview selection" in source
    assert "timeout=%s" in source

    # DMF log methods pass their first payload through string.format. Imported
    # perk/blessing labels contain literal percent signs, so runtime text must
    # always be supplied as a value for a constant format string.
    assert 'pcall(logger, mod, "%s", tostring(message))' in source

    print("Auto Crafter facade crash-containment checks passed.")


if __name__ == "__main__":
    main()
