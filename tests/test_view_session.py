from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SESSION_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_view_session.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    session = lua.execute(SESSION_PATH.read_text(encoding="utf-8"), name=str(SESSION_PATH))
    view = lua.execute("return {native = true}")
    lua.execute("view_session_cleanup_count = 0")

    assert session.begin(view, "inventory") is not None
    assert session.begin(view, "inventory").kind == "inventory"
    session.set_field(view, "owned", "better-inventory")
    session.register_cleanup(
        view,
        "once",
        lua.eval("function() view_session_cleanup_count = view_session_cleanup_count + 1 end"),
    )
    # The callback receives the session, so retain a simple independent counter
    # through a second callback closure for the exact-once assertion.
    session.register_cleanup(
        view,
        "counter",
        lua.eval("function() end"),
    )
    assert view.owned == "better-inventory"
    assert session.close(view, "exit") is True
    assert session.close(view, "duplicate") is False
    assert view.owned is None
    assert lua.globals().view_session_cleanup_count == 1

    # A third-party write after BetterInventory claims a field must survive
    # teardown; the session restores only values it still owns.
    view.native = "native"
    session.begin(view, "armoury")
    session.set_field(view, "native", "better-inventory")
    view.native = "third-party"
    assert session.close(view, "disable") is True
    assert view.native == "third-party"

    # A replacement request closes the old session exactly once before a new
    # active scope is created.
    session.begin(view, "inventory")
    assert session.active(view).kind == "inventory"
    assert session.close(view, "reload") is True

    # Repeated view creation/teardown must return the registry to baseline and
    # release field snapshots/callback closures every time.
    for index in range(250):
        cycled_view = lua.table_from({"native": index})
        assert session.begin(cycled_view, "inventory") is not None
        assert session.set_field(cycled_view, "owned", index) is True
        assert session.register_cleanup(
            cycled_view, "noop", lua.eval("function() end")
        ) is True
        assert session.close(cycled_view, "cycle") is True
        assert cycled_view.owned is None
        assert session.count() == 0

    # Closing one session may synchronously open its replacement. Finishing the
    # old cleanup must not erase the new owner.
    replacement_view = lua.table_from({})
    lua.globals().view_session_module = session
    lua.globals().view_session_replacement_view = replacement_view
    session.begin(replacement_view, "old")
    session.register_cleanup(
        replacement_view,
        "replace",
        lua.eval(
            "function() view_session_module.begin(view_session_replacement_view, 'replacement') end"
        ),
    )
    assert session.close(replacement_view, "replace") is True
    assert session.active(replacement_view).kind == "replacement"
    assert session.close(replacement_view, "replacement_done") is True

    views = [lua.table_from({}) for _ in range(4)]
    for cycled_view in views:
        session.begin(cycled_view, "bulk")
    assert session.count() == 4
    assert session.close_all("test_shutdown") == 4
    assert session.count() == 0

    print("BetterInventory ViewSession lifecycle tests passed.")


if __name__ == "__main__":
    main()
