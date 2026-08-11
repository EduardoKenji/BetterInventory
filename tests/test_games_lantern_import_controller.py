from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
IMPORT_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "games_lantern" / "import_controller.lua"
CLIPBOARD_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "games_lantern" / "clipboard.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    import_module = lua.execute(IMPORT_PATH.read_text(encoding="utf-8"), name=str(IMPORT_PATH))
    clipboard = lua.execute(CLIPBOARD_PATH.read_text(encoding="utf-8"), name=str(CLIPBOARD_PATH))
    url = "https://darktide.gameslantern.com/builds/00000000-0000-0000-0000-000000000000"

    def to_lua(value):
        if isinstance(value, dict):
            return lua.table_from({key: to_lua(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([to_lua(item) for item in value])
        return value

    def callback_wrapper(callback):
        return lua.eval("function(callback) return function(...) return callback(...) end end")(callback)

    transport_state = ["idle"]
    staged_callbacks = []
    installed = []
    errors = []
    build_model = to_lua(
        {
            "source_archetype": "psyker",
            "source_uuid": "00000000-0000-0000-0000-000000000000",
            "weapons": [{"display_name": "melee"}, {"display_name": "ranged"}],
        }
    )
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
            "attach_catalogs": callback_wrapper(lambda identity_build, catalogs, context=None: (resolved, None)),
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
                "queue_snapshot": callback_wrapper(lambda: to_lua({"state": "empty"})),
                "report": callback_wrapper(lambda kind, payload: errors.append(str(kind)) if str(kind) == "import_failed" else None),
            }
        )
    )

    assert controller.paste(controller) is True
    assert controller.snapshot(controller)["state"] == "fetching"
    assert controller.update(controller) == "resolving_catalogues"
    # Catalog completion is the atomic installation boundary.
    assert len(staged_callbacks) == 1
    assert staged_callbacks[0](to_lua({"melee": {"available": True}, "ranged": {"available": True}}), None) is True
    assert controller.snapshot(controller)["state"] == "staged"
    assert len(installed) == 1

    # A stale callback from a replaced paste cannot install a second queue.
    assert controller.paste(controller) is True
    stale = staged_callbacks[-1]
    assert controller.paste(controller) is True
    assert stale(to_lua({}), None) is False
    assert len(installed) == 1

    # Ambiguous live weapon cards require an explicit valid choice, then
    # continue the same generation into catalogue resolution.
    chooser_callbacks = []
    chooser_installed = []
    choice_candidates = to_lua({
        "melee": [
            {"display_name": "A", "external": {"card_index": 1}},
            {"display_name": "B", "external": {"card_index": 2}},
        ],
        "ranged": [],
    })

    def resolve_with_choice(model, context):
        choices = context["weapon_choices"]
        if choices is None or choices["melee"] is None:
            return None, "weapon_choice_required", choice_candidates
        return identity, None

    chooser_resolver = to_lua({
        "resolve_identities": callback_wrapper(resolve_with_choice),
        "attach_catalogs": callback_wrapper(lambda identity_build, catalogs, context=None: (resolved, None)),
    })
    chooser = import_module.new(to_lua({
        "clipboard_read": callback_wrapper(lambda: url),
        "clipboard": clipboard,
        "transport": transport,
        "parser": parser,
        "resolver": chooser_resolver,
        "get_resolution_context": callback_wrapper(lambda: to_lua({"active_archetype": "psyker"})),
        "fetch_catalogs": callback_wrapper(lambda identity_build, complete, generation: chooser_callbacks.append(complete) or True),
        "install_queue": callback_wrapper(lambda build: chooser_installed.append(build) or True),
        "queue_snapshot": callback_wrapper(lambda: to_lua({"state": "empty"})),
    }))
    assert chooser.paste(chooser) is True
    assert chooser.update(chooser) == "awaiting_weapon_choice"
    assert chooser.select_weapon_choice(chooser, "melee", 99)[0] is False
    assert chooser.select_weapon_choice(chooser, "melee", 2) is True
    assert chooser.snapshot(chooser)["state"] == "resolving_catalogues"
    assert len(chooser_callbacks) == 1
    assert chooser_callbacks[0](to_lua({"melee": {"available": True}, "ranged": {"available": True}}), None) is True
    assert chooser.snapshot(chooser)["state"] == "staged"
    assert len(chooser_installed) == 1

    # Invalid clipboard text is rejected before transport starts.
    bad = import_module.new(
        to_lua(
            {
                "clipboard_read": callback_wrapper(lambda: "https://evil.example/builds/nope"),
                "clipboard": clipboard,
                "transport": transport,
                "parser": parser,
                "resolver": resolver,
                "get_resolution_context": callback_wrapper(lambda: to_lua({})),
                "fetch_catalogs": callback_wrapper(fetch_catalogs),
                "install_queue": callback_wrapper(lambda build: True),
                "report": callback_wrapper(lambda kind, payload: errors.append(str(kind))),
            }
        )
    )
    assert bad.paste(bad) is False
    assert bad.snapshot(bad)["state"] == "failed"
    assert errors

    transport_reports = []
    failed_transport = to_lua({})
    failed_transport.start = lua.eval("function() return false, 'process_spawn_failed' end")
    failed_transport.cancel = lua.eval("function() return false end")
    transport_failure = import_module.new(
        to_lua(
            {
                "clipboard_read": callback_wrapper(lambda: url),
                "clipboard": clipboard,
                "transport": failed_transport,
                "report": callback_wrapper(lambda kind, payload: transport_reports.append((str(kind), str(payload["error"])))),
            }
        )
    )
    assert transport_failure.paste(transport_failure) is False
    assert transport_reports == [("import_failed", "process_spawn_failed")]

    mismatch_reports = []
    mismatch_resolver = to_lua({})
    mismatch_resolver.resolve_identities = lua.eval("function() return nil, 'archetype_mismatch' end")
    mismatch_resolver.canonical_archetype = lua.eval("function(value) if value == 'skitarii' then return 'cryptic' end return value end")
    mismatch = import_module.new(to_lua({
        "resolver": mismatch_resolver,
        "get_resolution_context": callback_wrapper(lambda: to_lua({"active_archetype": "veteran"})),
        "report": callback_wrapper(lambda kind, payload: mismatch_reports.append((str(kind), str(payload["error"])) )),
    }))
    mismatch._model = to_lua({"source_archetype": "skitarii"})
    assert mismatch._begin_catalog_resolution(mismatch) is False
    assert mismatch_reports == [("import_failed", "source=skitarii->cryptic active=veteran->veteran")]


if __name__ == "__main__":
    main()
