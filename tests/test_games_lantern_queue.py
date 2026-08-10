from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
QUEUE_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "games_lantern" / "queue.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)

    def to_lua(value):
        if isinstance(value, dict):
            return lua.table_from({key: to_lua(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([to_lua(item) for item in value])
        return value

    queue_module = lua.execute(QUEUE_PATH.read_text(encoding="utf-8"), name=str(QUEUE_PATH))

    build = to_lua(
        {
            "kind": "games_lantern_build",
            "jobs": [
                {
                    "kind": "games_lantern_job",
                    "slot": "melee",
                    "dump_stat": "damage",
                    "offer": {"master_id": "melee"},
                    "perks": [{"id": "p1"}, {"id": "p2"}],
                    "blessings": [{"id": "b1"}, {"id": "b2"}],
                },
                {
                    "kind": "games_lantern_job",
                    "slot": "ranged",
                    "dump_stat": "mobility",
                    "offer": {"master_id": "ranged"},
                    "perks": [{"id": "p3"}, {"id": "p4"}],
                    "blessings": [{"id": "b3"}, {"id": "b4"}],
                },
            ],
        }
    )

    def callback_wrapper(callback):
        return lua.eval("function(callback) return function(...) return callback(...) end end")(callback)

    events = []
    starts = []
    selections = []
    configured = []
    view_valid = [True]

    queue = queue_module.new(
        to_lua(
            {
                "select_job": callback_wrapper(lambda job, index: selections.append(int(index)) or True),
                "configure_job": callback_wrapper(lambda job, index: configured.append(int(index)) or True),
                "start_job": callback_wrapper(lambda job, index: starts.append(int(index)) or True),
                "stop_job": callback_wrapper(lambda reason: True),
                "view_is_valid": callback_wrapper(lambda: view_valid[0]),
                "report": callback_wrapper(lambda kind, payload: events.append(str(kind))),
            }
        )
    )

    install_result = queue.install(queue, build)
    assert install_result is True
    assert queue.snapshot(queue)["state"] == "staged"
    assert queue.start(queue) is True
    assert starts == [1]
    assert selections == [1]
    assert configured == [1]
    assert queue.snapshot(queue)["jobs"][1]["current"] is True

    assert queue.on_event(queue, "phase4_complete", {"gear_id": "melee-result"}) is True
    assert queue.snapshot(queue)["state"] == "waiting_next"
    queue.update(queue)
    assert starts == [1, 2]
    assert queue.snapshot(queue)["current_index"] == 2
    assert queue.on_event(queue, "phase4_complete", {"gear_id": "ranged-result"}) is True
    queue.update(queue)
    assert queue.snapshot(queue)["state"] == "complete"
    assert "queue_complete" in events

    # An explicit stop at the item boundary must prevent the next request.
    stopped_starts = []
    stopped = queue_module.new(
        to_lua(
            {
                "select_job": callback_wrapper(lambda job, index: True),
                "configure_job": callback_wrapper(lambda job, index: True),
                "start_job": callback_wrapper(lambda job, index: stopped_starts.append(int(index)) or True),
                "stop_job": callback_wrapper(lambda reason: True),
                "view_is_valid": callback_wrapper(lambda: True),
            }
        )
    )
    assert stopped.install(stopped, build) is True
    assert stopped.start(stopped) is True
    assert stopped.on_event(stopped, "phase4_complete", {}) is True
    assert stopped.stop(stopped, "user_stopped") is True
    stopped.update(stopped)
    assert stopped.snapshot(stopped)["state"] == "stopped"
    assert stopped_starts == [1]

    # A failed first item never dispatches the ranged item.
    failed_starts = []
    failed = queue_module.new(
        to_lua(
            {
                "select_job": callback_wrapper(lambda job, index: True),
                "configure_job": callback_wrapper(lambda job, index: True),
                "start_job": callback_wrapper(lambda job, index: failed_starts.append(int(index)) or True),
                "stop_job": callback_wrapper(lambda reason: True),
                "view_is_valid": callback_wrapper(lambda: True),
            }
        )
    )
    assert failed.install(failed, build) is True
    assert failed.start(failed) is True
    assert failed.on_event(failed, "operation_failed", {"error": "backend"}) is True
    failed.update(failed)
    assert failed.snapshot(failed)["state"] == "failed"
    assert failed_starts == [1]

    # View loss is checked at the transition boundary, before job 2.
    boundary = queue_module.new(
        to_lua(
            {
                "select_job": callback_wrapper(lambda job, index: True),
                "configure_job": callback_wrapper(lambda job, index: True),
                "start_job": callback_wrapper(lambda job, index: True),
                "stop_job": callback_wrapper(lambda reason: True),
                "view_is_valid": callback_wrapper(lambda: view_valid[0]),
            }
        )
    )
    assert boundary.install(boundary, build) is True
    assert boundary.start(boundary) is True
    assert boundary.on_event(boundary, "phase4_complete", {}) is True
    view_valid[0] = False
    boundary.update(boundary)
    assert boundary.snapshot(boundary)["state"] == "failed"
    assert boundary.snapshot(boundary)["last_error"] == "brunt_view_unavailable_at_boundary"

    invalid = to_lua({"kind": "games_lantern_build", "jobs": [build["jobs"][1], build["jobs"][1]]})
    result, reason = queue_module._test.valid_build(invalid)
    assert result is False
    assert reason == "invalid_ranged_job"


if __name__ == "__main__":
    main()
