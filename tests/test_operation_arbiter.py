from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ARBITER_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_operation_arbiter.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    factory = lua.execute(ARBITER_PATH.read_text(encoding="utf-8"), name=str(ARBITER_PATH))
    arbiter = factory.new()
    view = lua.execute("return {}")

    token = arbiter.acquire(arbiter, "manual", view)
    assert token == 1
    assert arbiter.acquire(arbiter, "automatic") is None
    assert arbiter.is_current(arbiter, "manual", token) is True
    assert arbiter.set_popup(arbiter, "manual", token, "popup-1") is True
    assert arbiter.set_popup(arbiter, "automatic", token, "stale-popup") is False
    assert arbiter.manual_settlement_active(arbiter) is False

    lua.execute("settlement_callback_count = 0")
    promise = lua.execute(
        "return {next = function(self, callback) self.callback = callback return self end, "
        "catch = function(self, callback) self.catch_callback = callback return self end}"
    )
    assert arbiter.observe_manual_settlement(
        arbiter,
        promise,
        lua.eval("function() settlement_callback_count = settlement_callback_count + 1 end"),
    ) is True
    assert arbiter.manual_settlement_active(arbiter) is True
    promise.callback("ok")
    assert lua.globals().settlement_callback_count == 1
    released, released_view, popup_id = arbiter.release(arbiter, "manual", token)
    assert released is True
    assert lua.eval("function(left, right) return left == right end")(released_view, view) is True
    assert popup_id == "popup-1"
    assert arbiter.manual_settlement_active(arbiter) is False

    # Stale generations cannot release a newer owner.
    next_token = arbiter.acquire(arbiter, "automatic")
    assert arbiter.release(arbiter, "manual", token) is False
    assert arbiter.is_current(arbiter, "automatic", next_token) is True
    assert arbiter.release(arbiter, "automatic", next_token)[0] is True

    print("BetterInventory operation arbiter tests passed.")


if __name__ == "__main__":
    main()
