from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
QUEUE_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "games_lantern" / "queue.lua"
IMPORT_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "games_lantern" / "import_controller.lua"
CLIPBOARD_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "games_lantern" / "clipboard.lua"
FACADE_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_auto_crafter.lua"
PANEL_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "darktide" / "panel.lua"
RUNTIME_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_runtime.lua"


def main() -> None:
    facade_source = FACADE_PATH.read_text(encoding="utf-8")
    panel_source = PANEL_PATH.read_text(encoding="utf-8")
    runtime_source = RUNTIME_PATH.read_text(encoding="utf-8")

    # Games Lantern and InstantCharacterChange are optional neighbors. BetterInventory
    # owns neither mod, does not call either API, and remains safe when either is absent.
    assert "get_mod(\"Lantern of the Omnissiah\")" not in facade_source
    assert "get_mod(\"InstantCharacterChange\")" not in facade_source
    assert "GamesLanternClipboardHost.read" in facade_source
    assert "can_import = games_lantern_import_allowed" in facade_source
    assert "if ctrl_v and not self._ctrl_v_down" in panel_source
    assert panel_source.count("self._ctrl_v_down = false") >= 2
    assert "GameplayStateRun_exit" in runtime_source
    assert "operative_selection_entered" in runtime_source
    assert "CreditsGoodsVendorView" in runtime_source

    lua = LuaRuntime(unpack_returned_tuples=True)

    def to_lua(value):
        if isinstance(value, dict):
            return lua.table_from({key: to_lua(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([to_lua(item) for item in value])
        return value

    def callback_wrapper(callback):
        return lua.eval("function(callback) return function(...) return callback(...) end end")(callback)

    def first_result(value):
        return value[0] if isinstance(value, tuple) else value

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

    # Four complete imports and four complete two-job queues exercise the same
    # session repeatedly and prove that no generation, queue index, or callback
    # from one run leaks into the next run.
    import_module = lua.execute(IMPORT_PATH.read_text(encoding="utf-8"), name=str(IMPORT_PATH))
    clipboard = lua.execute(CLIPBOARD_PATH.read_text(encoding="utf-8"), name=str(CLIPBOARD_PATH))
    url = "https://darktide.gameslantern.com/builds/00000000-0000-0000-0000-000000000000"
    transport_state = ["idle"]
    staged_callbacks = []
    installed = []
    allowed = [False]

    build_model = to_lua({"source_archetype": "psyker", "source_uuid": "00000000-0000-0000-0000-000000000000", "weapons": [{"display_name": "melee"}, {"display_name": "ranged"}]})
    identity = to_lua({"kind": "games_lantern_identity_build", "jobs": []})
    resolved = to_lua({"kind": "games_lantern_build", "jobs": []})

    transport = to_lua(
        {
            "start": callback_wrapper(lambda *args: transport_state.__setitem__(0, "running") or True),
            "cancel": callback_wrapper(lambda *args: transport_state.__setitem__(0, "cancelled") or True),
            "update": callback_wrapper(lambda *args: "complete" if transport_state[0] == "running" else transport_state[0]),
            "take_result": callback_wrapper(lambda *args: (to_lua({"body": "<html>"}), None)),
            "snapshot": callback_wrapper(lambda *args: to_lua({"last_error": "transport_failed"})),
        }
    )
    parser = to_lua({"parse": callback_wrapper(lambda html: (build_model, None))})
    resolver = to_lua(
        {
            "resolve_identities": callback_wrapper(lambda model, context: (identity, None)),
            "attach_catalogs": callback_wrapper(lambda identity_build, catalogs: (resolved, None)),
        }
    )

    def fetch_catalogs(identity_build, complete, generation):
        staged_callbacks.append(complete)
        return True

    controller = import_module.new(
        to_lua(
            {
                "clipboard_read": callback_wrapper(lambda: url),
                "clipboard": clipboard,
                "transport": transport,
                "parser": parser,
                "resolver": resolver,
                "get_resolution_context": callback_wrapper(lambda: to_lua({"active_archetype": "psyker"})),
                "fetch_catalogs": callback_wrapper(fetch_catalogs),
                "install_queue": callback_wrapper(lambda build: installed.append(build) or True),
                "can_import": callback_wrapper(lambda: allowed[0]),
                "queue_snapshot": callback_wrapper(lambda: to_lua({"state": "empty"})),
            }
        )
    )

    assert first_result(controller.paste(controller)) is False
    assert controller.snapshot(controller)["last_error"] is None
    assert transport_state[0] == "idle"
    allowed[0] = True

    for _ in range(4):
        assert first_result(controller.paste(controller)) is True
        assert controller.update(controller) == "resolving_catalogues"
        assert len(staged_callbacks) == len(installed) + 1
        assert staged_callbacks[-1](to_lua({"melee": {"available": True}, "ranged": {"available": True}}), None) is True
        assert controller.snapshot(controller)["state"] == "staged"
        clear_result = controller.clear(controller)
        assert clear_result is True

    assert len(installed) == 4
    stale_callback = staged_callbacks[0]
    assert stale_callback(to_lua({}), None) is False

    starts = []
    for _ in range(4):
        queue = queue_module.new(
            to_lua(
                {
                    "select_job": callback_wrapper(lambda job, index: True),
                    "configure_job": callback_wrapper(lambda job, index: True),
                    "start_job": callback_wrapper(lambda job, index: starts.append(int(index)) or True),
                    "stop_job": callback_wrapper(lambda reason: True),
                    "view_is_valid": callback_wrapper(lambda: True),
                }
            )
        )
        assert queue.install(queue, build) is True
        assert queue.start(queue) is True
        snapshot = queue.snapshot(queue)
        first = snapshot["jobs"][1]
        assert queue.on_event(queue, "phase4_complete", to_lua({"candidate": {"gear_id": "melee"}, "character_id": "character-1", "job_id": first["job_id"], "queue_id": snapshot["queue_id"], "terminal_sequence": 1})) is True
        queue.update(queue)
        assert queue.snapshot(queue)["current_index"] == 2
        snapshot = queue.snapshot(queue)
        second = snapshot["jobs"][2]
        assert queue.on_event(queue, "phase4_complete", to_lua({"candidate": {"gear_id": "ranged"}, "character_id": "character-1", "job_id": second["job_id"], "queue_id": snapshot["queue_id"], "terminal_sequence": 2})) is True
        queue.update(queue)
        assert queue.snapshot(queue)["state"] == "complete"
        assert queue.snapshot(queue)["transition_count"] == 2
        clear_result = queue.clear(queue)
        assert clear_result is True
        assert queue.snapshot(queue)["state"] == "empty"

    assert starts == [1, 2, 1, 2, 1, 2, 1, 2]


if __name__ == "__main__":
    main()
