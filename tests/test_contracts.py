from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CONTRACTS_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_contracts.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    contracts = lua.execute(
        CONTRACTS_PATH.read_text(encoding="utf-8"), name=str(CONTRACTS_PATH)
    )

    ok, value = contracts.safe_call(lua.eval("function(value) return value + 1 end"), 4)
    assert ok is True
    assert value == 5

    ok, error = contracts.safe_call(lua.eval("function() error('expected') end"))
    assert ok is False
    assert error is not None

    target = lua.execute("return {value = 7, read = function(self) return self.value end}")
    ok, value = contracts.safe_method(target, "read")
    assert ok is True
    assert value == 7

    throwing_lookup = lua.execute(
        "return setmetatable({}, {__index = function() error('lookup failed') end})"
    )
    ok, error = contracts.safe_method(throwing_lookup, "read")
    assert ok is False
    assert error is not None

    explicit_false = lua.execute(
        "return {read = function() return false end, broken = function() error('call failed') end}"
    )
    status, value = contracts.read_only(explicit_false, "read")
    assert status == "ok"
    assert value is False
    status, detail = contracts.read_only(explicit_false, "missing")
    assert status == "unavailable"
    assert detail is not None
    status, detail = contracts.mutation(explicit_false, "broken")
    assert status == "error"
    assert detail is not None
    refresh_required, status, detail = contracts.registry_refresh_required(
        throwing_lookup, "should_refresh_dependencies"
    )
    assert refresh_required is True
    assert status == "unavailable"
    assert detail is not None
    refresh_required, status, value = contracts.registry_refresh_required(
        explicit_false, "read"
    )
    assert refresh_required is False
    assert status == "ok"
    assert value is False

    print("BetterInventory contract adapter tests passed.")


if __name__ == "__main__":
    main()
