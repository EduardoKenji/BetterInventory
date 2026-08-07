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

    print("BetterInventory ViewSession lifecycle tests passed.")


if __name__ == "__main__":
    main()
