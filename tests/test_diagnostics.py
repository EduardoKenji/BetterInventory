from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_diagnostics.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    diagnostics = lua.execute(MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH))
    globals_ = lua.globals()
    mod = lua.table_from({"debug_enable_hot_path_diagnostics": False})
    mod.get = lua.eval("function(self, setting_id) return self[setting_id] end")

    diagnostics.configure(mod)
    diagnostics.count("disabled_counter")
    disabled_snapshot = diagnostics.snapshot()
    assert disabled_snapshot.enabled is False
    assert len(disabled_snapshot.counters) == 0
    assert len(disabled_snapshot.samples) == 0

    mod.debug_enable_hot_path_diagnostics = True
    diagnostics.configure(mod)
    diagnostics.count("panel_rebuilds", 2)
    diagnostics.count("pivot_writes")
    curio = lua.table_from(
        {
            "active_read_requests": lua.eval("function() return 3 end"),
            "oldest_read_request_age": lua.eval("function() return 2.5 end"),
        }
    )
    features = lua.table_from(
        {"automatic_discard_read_request_count": lua.eval("function() return 1 end")}
    )
    diagnostics.update(mod, 0.5, curio, features)
    half_snapshot = diagnostics.snapshot()
    assert half_snapshot.samples.sample_count is None
    diagnostics.update(mod, 0.5, curio, features)
    sampled_snapshot = diagnostics.snapshot()
    assert sampled_snapshot.counters.panel_rebuilds == 2
    assert sampled_snapshot.counters.pivot_writes == 1
    assert sampled_snapshot.samples.active_promises == 4
    assert sampled_snapshot.samples.oldest_operation_age == 2.5
    assert sampled_snapshot.samples.sample_count == 1
    assert sampled_snapshot.samples.lua_memory_kb > 0

    mod.debug_enable_hot_path_diagnostics = False
    diagnostics.configure(mod)
    diagnostics.update(mod, 0, curio, features)
    reset_snapshot = diagnostics.snapshot()
    assert reset_snapshot.enabled is False
    assert len(reset_snapshot.counters) == 0
    assert len(reset_snapshot.samples) == 0

    print("BetterInventory diagnostics tests passed.")


if __name__ == "__main__":
    main()
