from coverage_support import InstrumentedLuaRuntime, merge_runtime_coverage


def main() -> None:
    first = InstrumentedLuaRuntime(unpack_returned_tuples=True)
    second = InstrumentedLuaRuntime(unpack_returned_tuples=True)

    assert first.execute("local value = 1; return value", name="coverage-first.lua") == 1
    assert second.execute("local value = 2; return value", name="coverage-second.lua") == 2

    merged, errors = merge_runtime_coverage([first, second])

    assert errors == []
    assert merged["coverage-first.lua"]
    assert merged["coverage-second.lua"]

    print("BetterInventory multi-runtime coverage aggregation tests passed.")


if __name__ == "__main__":
    main()
