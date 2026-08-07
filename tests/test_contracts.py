from pathlib import Path

from lupa import LuaRuntime


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
    contracts = lua.execute(CONTRACTS_PATH.read_text(encoding="utf-8"))

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

    print("BetterInventory contract adapter tests passed.")


if __name__ == "__main__":
    main()
