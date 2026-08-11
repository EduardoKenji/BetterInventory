from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
QUEUE_PATH = RUNTIME_ROOT / "auto_crafter" / "games_lantern" / "queue.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)

    def to_lua(value):
        if isinstance(value, dict):
            return lua.table_from({key: to_lua(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([to_lua(item) for item in value])
        return value

    def callback(callback):
        return lua.eval("function(callback) return function(...) return callback(...) end end")(callback)

    module = lua.execute(QUEUE_PATH.read_text(encoding="utf-8"), name=str(QUEUE_PATH))

    def build(melee_state="fresh", ranged_state="fresh"):
        return to_lua({
            "kind": "games_lantern_build",
            "source_uuid": "00000000-0000-0000-0000-000000000000",
            "jobs": [
                {"kind": "games_lantern_job", "slot": "melee", "start_state": melee_state, "dump_stat": "damage", "offer": {"master_id": "melee"}, "perks": [{"id": "p1"}, {"id": "p2"}], "blessings": [{"id": "b1"}, {"id": "b2"}]},
                {"kind": "games_lantern_job", "slot": "ranged", "start_state": ranged_state, "dump_stat": "mobility", "offer": {"master_id": "ranged"}, "perks": [{"id": "p3"}, {"id": "p4"}], "blessings": [{"id": "b3"}, {"id": "b4"}]},
            ],
        })

    def terminal(queue, sequence, gear_id, **overrides):
        snapshot = queue.snapshot(queue)
        job = snapshot["jobs"][snapshot["current_index"]]
        payload = {
            "candidate": {"gear_id": gear_id},
            "character_id": "character-1",
            "job_id": job["job_id"],
            "operation_sequence": sequence,
            "queue_id": snapshot["queue_id"],
            "terminal_sequence": sequence,
        }
        payload.update(overrides)
        return to_lua(payload)

    # Typed terminal identity is mandatory and monotonic. Wrong queue, job,
    # character, missing gear, and duplicate events cannot advance the queue.
    verified = []
    starts = []
    queue = module.new(to_lua({
        "current_character_id": callback(lambda: "character-1"),
        "select_job": callback(lambda job, index: True),
        "configure_job": callback(lambda job, index: True),
        "start_job": callback(lambda job, index: starts.append(int(index)) or True),
        "stop_job": callback(lambda reason: True),
        "view_is_valid": callback(lambda: True),
        "validate_event": callback(lambda job, payload: payload["operation_sequence"] == payload["terminal_sequence"]),
        "verify_results": callback(lambda results, queue_id, jobs: verified.append([results[1]["gear_id"], results[2]["gear_id"]]) or True),
    }))
    assert queue.install(queue, build()) is True
    assert queue.start(queue) is True
    assert queue.on_event(queue, "phase4_complete", terminal(queue, 1, "m", queue_id="wrong")) is False
    assert queue.on_event(queue, "phase4_complete", terminal(queue, 1, "m", job_id="wrong")) is False
    assert queue.on_event(queue, "phase4_complete", terminal(queue, 1, "m", character_id="other")) is False
    assert queue.on_event(queue, "phase4_complete", terminal(queue, 1, "m", operation_sequence=99)) is False
    assert queue.on_event(queue, "phase4_complete", terminal(queue, 1, None)) is False
    melee_terminal = terminal(queue, 1, "m")
    assert queue.on_event(queue, "phase4_complete", melee_terminal) is True
    queue.update(queue)
    assert starts == [1, 2]
    assert queue.on_event(queue, "phase4_complete", melee_terminal) is False
    assert queue.on_event(queue, "phase4_complete", terminal(queue, 2, "r")) is True
    queue.update(queue)
    assert queue.snapshot(queue)["state"] == "complete"
    assert verified == [["m", "r"]]

    # A missing/changed completed result cannot produce queue success.
    rejected = module.new(to_lua({
        "select_job": callback(lambda job, index: True),
        "configure_job": callback(lambda job, index: True),
        "start_job": callback(lambda job, index: True),
        "stop_job": callback(lambda reason: True),
        "view_is_valid": callback(lambda: True),
        "verify_results": callback(lambda results, queue_id, jobs: False),
    }))
    assert rejected.install(rejected, build()) is True
    assert rejected.start(rejected) is True
    assert rejected.on_event(rejected, "phase4_complete", terminal(rejected, 1, "m")) is True
    rejected.update(rejected)
    assert rejected.on_event(rejected, "phase4_complete", terminal(rejected, 2, "r")) is True
    rejected.update(rejected)
    assert rejected.snapshot(rejected)["state"] == "failed"

    # Every fresh/resume/exact starting-state pair remains serial. Resource
    # preflight blocks before dispatch, and quarantine requires reconciliation.
    for melee_state in ("fresh", "resume", "exact"):
        for ranged_state in ("fresh", "resume", "exact"):
            order = []
            mutation_count = []
            matrix_queue = module.new(to_lua({
                "select_job": callback(lambda job, index: True),
                "configure_job": callback(lambda job, index: True),
                "start_job": callback(lambda job, index: (order.append((int(index), str(job["start_state"]))) or mutation_count.append(0 if str(job["start_state"]) == "exact" else 1) or True)),
                "stop_job": callback(lambda reason: True),
                "view_is_valid": callback(lambda: True),
            }))
            assert matrix_queue.install(matrix_queue, build(melee_state, ranged_state)) is True
            assert matrix_queue.start(matrix_queue) is True
            assert matrix_queue.on_event(matrix_queue, "phase4_complete", terminal(matrix_queue, 1, "m")) is True
            matrix_queue.update(matrix_queue)
            assert order == [(1, melee_state), (2, ranged_state)]
            assert matrix_queue.on_event(matrix_queue, "phase4_complete", terminal(matrix_queue, 2, "r")) is True
            matrix_queue.update(matrix_queue)
            assert matrix_queue.snapshot(matrix_queue)["state"] == "complete"
            assert sum(mutation_count) == (0 if melee_state == "exact" else 1) + (0 if ranged_state == "exact" else 1)

    prepare_calls = []
    blocked = module.new(to_lua({
        "select_job": callback(lambda job, index: True),
        "configure_job": callback(lambda job, index: True),
        "prepare_job": callback(lambda job, index, results: (prepare_calls.append(int(index)) or True) if int(index) == 1 else False),
        "start_job": callback(lambda job, index: True),
        "stop_job": callback(lambda reason: True),
        "view_is_valid": callback(lambda: True),
    }))
    # Explicit Lua callback supplies resource reason for second preflight.
    blocked._prepare_job = lua.eval("function(job, index) if index == 1 then return true end return false, 'insufficient resources' end")
    assert blocked.install(blocked, build()) is True
    assert blocked.start(blocked) is True
    assert blocked.on_event(blocked, "phase4_complete", terminal(blocked, 1, "m")) is True
    blocked.update(blocked)
    assert blocked.snapshot(blocked)["state"] == "blocked"
    assert blocked.snapshot(blocked)["current_index"] == 2

    no_dispatches = []
    blocked_first = module.new(to_lua({
        "select_job": callback(lambda job, index: True),
        "configure_job": callback(lambda job, index: True),
        "prepare_job": callback(lambda job, index, results: False),
        "start_job": callback(lambda job, index: no_dispatches.append(int(index)) or True),
        "stop_job": callback(lambda reason: True),
        "view_is_valid": callback(lambda: True),
    }))
    blocked_first._prepare_job = lua.eval("function() return false, 'insufficient resources' end")
    assert blocked_first.install(blocked_first, build()) is True
    assert blocked_first.start(blocked_first) is False
    assert blocked_first.snapshot(blocked_first)["state"] == "blocked"
    assert no_dispatches == []

    # Closing Brunt after authoritative melee completion preserves 1/2 and
    # stops before any ranged dispatch.
    boundary_open = [True]
    boundary_starts = []
    boundary = module.new(to_lua({
        "select_job": callback(lambda job, index: True),
        "configure_job": callback(lambda job, index: True),
        "start_job": callback(lambda job, index: boundary_starts.append(int(index)) or True),
        "stop_job": callback(lambda reason: True),
        "view_is_valid": callback(lambda: boundary_open[0]),
    }))
    assert boundary.install(boundary, build()) is True
    assert boundary.start(boundary) is True
    assert boundary.on_event(boundary, "phase4_complete", terminal(boundary, 1, "m")) is True
    boundary_open[0] = False
    boundary.update(boundary)
    assert boundary.snapshot(boundary)["state"] == "stopped"
    assert boundary.snapshot(boundary)["current_index"] == 2
    assert boundary_starts == [1]

    # STOP remains unresolved until the active mutation settles/reconciles.
    stopping = module.new(to_lua({
        "select_job": callback(lambda job, index: True),
        "configure_job": callback(lambda job, index: True),
        "start_job": callback(lambda job, index: True),
        "stop_job": callback(lambda reason: True),
        "view_is_valid": callback(lambda: True),
    }))
    stopping._stop_job = lua.eval("function() return true, false end")
    assert stopping.install(stopping, build()) is True
    assert stopping.start(stopping) is True
    assert stopping.stop(stopping, "test") is True
    assert stopping.snapshot(stopping)["state"] == "stopping"
    assert stopping.on_event(stopping, "operation_reconciliation_required", to_lua({"reason": "late"})) is True
    assert stopping.snapshot(stopping)["state"] == "reconciliation_required"

    quarantined = module.new(to_lua({
        "select_job": callback(lambda job, index: True),
        "configure_job": callback(lambda job, index: True),
        "start_job": callback(lambda job, index: True),
        "stop_job": callback(lambda reason: True),
        "view_is_valid": callback(lambda: True),
    }))
    assert quarantined.install(quarantined, build()) is True
    assert quarantined.start(quarantined) is True
    assert quarantined.on_event(quarantined, "operation_quarantined", to_lua({"error": "timeout"})) is True
    assert quarantined.snapshot(quarantined)["state"] == "quarantined"
    assert quarantined.on_event(quarantined, "operation_reconciliation_required", to_lua({"reason": "late settlement"})) is True
    assert quarantined.snapshot(quarantined)["state"] == "reconciliation_required"
    assert quarantined.on_event(quarantined, "probe_complete", to_lua({"character_id": "character-1"})) is True
    assert quarantined.snapshot(quarantined)["state"] == "stopped"

    # Presentation reads must stay bounded: the imported catalogue/external
    # payload remains available to orchestration snapshots but never reaches
    # the panel's periodically refreshed model.
    compact = module.new(to_lua({}))
    compact_build = build()
    compact_build["jobs"][1]["catalog"] = to_lua({"large_marker": "must-not-reach-panel"})
    compact_build["jobs"][1]["external"] = to_lua({"html": "must-not-reach-panel"})
    compact_build["jobs"][1]["display_name"] = "Arc Maul"
    assert compact.install(compact, compact_build) is True
    full_snapshot = compact.snapshot(compact)
    presentation = compact.presentation_snapshot(compact)
    assert compact.state(compact) == "staged"
    assert full_snapshot["jobs"][1]["catalog"]["large_marker"] == "must-not-reach-panel"
    assert presentation["jobs"][1]["display_name"] == "Arc Maul"
    assert presentation["jobs"][1]["catalog"] is None
    assert presentation["jobs"][1]["external"] is None

    # Source-level release contracts guard seams not available in pure queue
    # simulation: frozen policy, fresh boundary probe/catalog, locked targets,
    # explicit replacement/clear, aggregate confirmation, and bounded polling.
    controller = (RUNTIME_ROOT / "auto_crafter" / "core" / "controller.lua").read_text(encoding="utf-8")
    facade = (RUNTIME_ROOT / "BetterInventory_auto_crafter.lua").read_text(encoding="utf-8")
    panel = (RUNTIME_ROOT / "auto_crafter" / "darktide" / "panel.lua").read_text(encoding="utf-8")
    transport = (RUNTIME_ROOT / "auto_crafter" / "games_lantern" / "transport.lua").read_text(encoding="utf-8")
    windows = (RUNTIME_ROOT / "auto_crafter" / "games_lantern" / "transport_win.lua").read_text(encoding="utf-8")
    assert "capture_queue_run_policy" in controller
    assert "games_lantern_queue_boundary" in controller
    assert "verify_imported_queue_results" in controller
    assert "payload.terminal_sequence" in controller
    assert "aggregate_confirmation_required" in facade
    assert '"Clear Queue"' in panel and '"Replace Queue (Ctrl+V)"' in panel
    assert '"Confirm Replace Queue (Ctrl+V)"' in panel
    assert "enabled = not queue_owned" in panel
    assert "Projected authority:" in panel
    assert "_queue_craft_confirmation_signature" in panel
    assert "_queue_craft_confirmation_text" in panel
    assert "presentation_snapshot()" in facade
    assert 'games_lantern_import:state() == "fetching"' in facade
    assert "controller:is_busy()" in facade
    busy_body = facade.split("function AutoCrafter.is_busy()", 1)[1].split("\nend", 1)[0]
    assert ":snapshot()" not in busy_body
    assert panel.count("_games_lantern_cost_authority()") == 2
    assert "aggregate_confirmation_stale" in facade
    assert "_poll_interval_seconds" in transport
    assert "taskkill /PID" in windows


if __name__ == "__main__":
    main()
