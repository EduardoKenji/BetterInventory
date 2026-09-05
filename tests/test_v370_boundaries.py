from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime

ROOT = Path(__file__).resolve().parents[1] / "scripts/mods/BetterInventory"


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    facade_path = ROOT / "BetterInventory_auto_crafter.lua"
    lua.globals().Facade = lua.execute(facade_path.read_text(encoding="utf-8"), name=str(facade_path))
    lua.execute("""
        local function set_upvalue(fn, key, value)
            for i=1,100 do
                local name = debug.getupvalue(fn, i)
                if not name then break end
                if name == key then debug.setupvalue(fn, i, value); return end
            end
            error("missing upvalue: " .. key)
        end
        assert(Facade.snapshot().phase == "unavailable")
        set_upvalue(Facade.snapshot, "controller", {
            snapshot=function() return {phase="crafting", operation_inflight=true, operation_sequence=42} end,
        })
        local snapshot = Facade.snapshot()
        assert(snapshot.phase == "crafting" and snapshot.operation_inflight and snapshot.operation_sequence == 42)
        set_upvalue(Facade.snapshot, "controller", {snapshot=function() error("injected") end})
        assert(Facade.snapshot().phase == "unavailable")
    """)

    runtime = (ROOT / "BetterInventory_runtime.lua").read_text(encoding="utf-8")
    shutdown = runtime[runtime.index("local function shutdown(unloading)"):runtime.index("function mod.on_disabled")]
    lua.execute("""
        errors, releases = 0, 0
        mod = {error=function() errors=errors+1 end}
        Features = setmetatable({}, {__index=function() return function() end end})
        ItemCustomization = {on_unload=function() error("injected customization cleanup failure") end}
        CurioAcquisition = {cancel=function() error("injected curio cleanup failure") end}
        RuntimeLifecycle = {release_all=function() releases=releases+1 end}
        Diagnostics = {}
        release_transient_item_caches = function() releases=releases+1 end
    """)
    lua.execute(shutdown + """
        shutdown(true)
        shutdown(true)
        assert(errors == 4 and releases == 4)
    """)
    print("v3.7.0 facade return and fault-isolated teardown regressions passed.")


if __name__ == "__main__":
    main()
