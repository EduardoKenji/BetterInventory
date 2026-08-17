from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


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
    assert queue.snapshot(queue)["planner_index"] == 1

    # Planner selection is independent from the execution cursor. Editing the
    # ranged card cannot reorder or advance the serial melee-first queue.
    selected, selected_job = queue.select_for_planning(queue, 2)
    assert selected is True and selected_job["slot"] == "ranged"
    assert queue.snapshot(queue)["planner_index"] == 2
    assert queue.snapshot(queue)["current_index"] == 1
    assert queue.snapshot(queue)["jobs"][2]["selected"] is True
    assert queue.start(queue) is True
    assert starts == [1]
    assert selections == [1]
    assert configured == [1]
    assert queue.snapshot(queue)["jobs"][1]["current"] is True
    assert queue.select_for_planning(queue, 1)[0] is False

    def completion(target_queue, sequence, gear_id):
        snapshot = target_queue.snapshot(target_queue)
        job = snapshot["jobs"][snapshot["current_index"]]
        return to_lua({
            "candidate": {"gear_id": gear_id},
            "character_id": "character-1",
            "job_id": job["job_id"],
            "queue_id": snapshot["queue_id"],
            "terminal_sequence": sequence,
        })

    first_completion = completion(queue, 1, "melee-result")
    assert queue.on_event(queue, "phase4_complete", first_completion) is True
    assert queue.snapshot(queue)["state"] == "waiting_next"
    queue.update(queue)
    assert starts == [1, 2]
    assert queue.snapshot(queue)["current_index"] == 2
    assert queue.on_event(queue, "phase4_complete", first_completion) is False
    assert queue.snapshot(queue)["current_index"] == 2
    assert queue.on_event(queue, "phase4_complete", completion(queue, 2, "ranged-result")) is True
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
    assert stopped.on_event(stopped, "phase4_complete", completion(stopped, 1, "stopped-melee")) is True
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
    boundary_starts = []
    boundary = queue_module.new(
        to_lua(
            {
                "select_job": callback_wrapper(lambda job, index: True),
                "configure_job": callback_wrapper(lambda job, index: True),
                "start_job": callback_wrapper(lambda job, index: boundary_starts.append(int(index)) or True),
                "stop_job": callback_wrapper(lambda reason: True),
                "view_is_valid": callback_wrapper(lambda: view_valid[0]),
            }
        )
    )
    assert boundary.install(boundary, build) is True
    assert boundary.start(boundary) is True
    assert boundary.on_event(boundary, "phase4_complete", completion(boundary, 1, "boundary-melee")) is True
    view_valid[0] = False
    boundary.update(boundary)
    assert boundary.snapshot(boundary)["state"] == "stopped"
    assert boundary.snapshot(boundary)["last_error"] is None
    assert boundary.snapshot(boundary)["current_index"] == 2
    view_valid[0] = True
    assert boundary.start(boundary) is True
    assert boundary_starts == [1, 2]
    assert boundary.snapshot(boundary)["state"] == "running"

    invalid = to_lua({"kind": "games_lantern_build", "jobs": [build["jobs"][1], build["jobs"][1]]})
    result, reason = queue_module._test.valid_build(invalid)
    assert result is False
    assert reason == "invalid_ranged_job"

    editable = to_lua({
        "kind": "games_lantern_build",
        "jobs": [
            {
                "kind": "games_lantern_job", "slot": "melee", "dump_stat": "damage", "dump_target": 60,
                "offer": {"master_id": "melee"}, "custom_stats_enabled": True,
                "custom_stat_targets": [
                    {"name": "damage", "value": 60}, {"name": "mobility", "value": 80},
                    {"name": "penetration", "value": 80}, {"name": "finesse", "value": 80},
                    {"name": "defense", "value": 80},
                ],
                "custom_stat_total": 380,
                "catalog": {
                    "perks": [{"id": "p1", "tier": 4}, {"id": "p2", "tier": 4}, {"id": "p5", "tier": 4}],
                    "blessings": [{"id": "b1", "tiers": [{"tier": 4}]}, {"id": "b2", "tiers": [{"tier": 4}]}],
                },
                "perks": [{"id": "p1", "rarity": 4}, {"id": "p2", "rarity": 4}],
                "blessings": [{"id": "b1", "rarity": 4}, {"id": "b2", "rarity": 4}],
            },
            build["jobs"][2],
        ],
    })
    editor = queue_module.new(to_lua({}))
    assert editor.install(editor, editable) is True
    updated, edited_job = editor.update_selected_custom_stat(editor, 2, 79)
    assert updated is True and edited_job["custom_stat_total"] == 379
    assert editor.snapshot(editor)["current_index"] == 1
    assert editor.update_selected_custom_stat(editor, 1, 61)[0] is True
    assert editor.snapshot(editor)["jobs"][1]["custom_stat_total"] == 380
    assert editor.update_selected_trait(editor, "perk", 1, to_lua({"id": "p5", "rarity": 4, "label": "P5"}))[0] is True
    assert editor.snapshot(editor)["jobs"][1]["perks"][1]["id"] == "p5"
    assert editor.update_selected_trait(editor, "perk", 2, to_lua({"id": "p5", "rarity": 4}))[0] is False
    assert editor.start(editor) is False  # no execution dependencies; edit lock still applies after start attempt


if __name__ == "__main__":
    main()
