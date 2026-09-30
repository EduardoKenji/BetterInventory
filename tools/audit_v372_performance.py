"""Offline CPU/allocation probes; no game, network, or account access.

Run: py -3 tools/audit_v372_performance.py [lua55|luajit21|luajit21-nojit]
Uses production Lua and the existing controller loader. GC-stopped allocation is
temporary heap growth, not a leak; post-collection drift is reported separately.
"""
import importlib
import json
from pathlib import Path
import statistics
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / "scripts/mods/BetterInventory"
sys.path.insert(0, str(ROOT / "tests"))
from auto_crafter_test_support import load_controller

ENGINE = sys.argv[1] if len(sys.argv) > 1 else "luajit21"
Runtime = importlib.import_module("lupa." + ENGINE.removesuffix("-nojit")).LuaRuntime


def LuaRuntime(**kwargs):
    lua = Runtime(**kwargs)
    if ENGINE.endswith("-nojit"):
        lua.execute("jit.off()")
    return lua


def measure(lua, operation, count=10000):
    loop = lua.eval("function(n) for i=1,n do " + operation + " end end")
    loop(2000)  # Warm traces and caches outside the samples.
    collect = lua.eval('function() collectgarbage("collect"); collectgarbage("collect"); return collectgarbage("count") end')
    samples, retained = [], []
    initial = collect()
    for _ in range(5):
        before = collect()
        lua.execute('collectgarbage("stop")')
        started = time.perf_counter()
        loop(count)
        elapsed = time.perf_counter() - started
        after = lua.eval('collectgarbage("count")')
        lua.execute('collectgarbage("restart")')
        retained.append(collect() - initial)
        samples.append((elapsed * 1e6 / count, (after - before) * 1024 / count))
    return {
        "iterations_per_sample": count,
        "median_us_per_call": round(statistics.median(x[0] for x in samples), 4),
        "median_temporary_bytes_per_call": round(statistics.median(x[1] for x in samples), 3),
        "retained_delta_kib_after_each_batch": [round(x, 3) for x in retained],
    }


def queue_probe(source):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().Controller = load_controller(lua)
    lua.globals().Facade = lua.execute(source)
    lua.execute('''
        local controller = assert(Controller.new())
        controller.update = function() end
        controller._operation_quarantined = true
        local queue = {
            state=function() return "quarantined" end,
            stop_requested=function() return true end,
            on_event=function() error("quarantined write must not settle") end,
        }
        local values = {controller=controller, games_lantern_queue=queue,
            presentation_dirty=false, presentation_snapshot={}}
        for i=1,100 do
            local name = debug.getupvalue(Facade.update, i)
            if not name then break end
            if values[name] ~= nil then debug.setupvalue(Facade.update, i, values[name]) end
        end
    ''')
    return measure(lua, "Facade.update(1/60)")


def idle_probe():
    lua = LuaRuntime(unpack_returned_tuples=True)
    source = (RUNTIME / "BetterInventory_runtime.lua").read_text(encoding="utf-8")
    update = source[source.index("function mod.update(dt)"):source.index("local function shutdown(unloading)")]
    lua.execute('''
        local function idle() return false end
        local function unexpected() error("idle dispatch should skip subsystem updates") end
        mod = {}
        active_highlight_views = {}
        CharacterOverviewUI = {needs_update=idle, update_registered_views=unexpected}
        AutoCrafter = {needs_update=idle, update=unexpected}
        FeatureDomains = {markers={needs_update=idle, update=unexpected}}
        ItemCustomization = {needs_update=idle, update_runtime=unexpected}
        EquipmentPersistence = {has_pending=idle, update=unexpected}
        Features = {discard_owner=idle, morningstar_auto_discard_needs_update=idle}
        CurioAcquisition = {needs_update=idle, update=unexpected}
        Diagnostics = {enabled=idle, update=unexpected}
    ''')
    lua.execute(update)
    return measure(lua, "mod.update(1/60)", 100000)


def lifecycle_probe():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().Sessions = lua.execute((RUNTIME / "BetterInventory_view_session.lua").read_text(encoding="utf-8"))
    lua.execute('''
        closed = setmetatable({}, {__mode="k"})
        function cycle()
            local view = {}
            closed[view] = true
            Sessions.begin(view, "audit")
            Sessions.set_field(view, "callback", function() return view end)
            Sessions.register_cleanup(view, "closure", function() return view end)
            Sessions.close(view, "audit")
            assert(view.callback == nil)
        end
    ''')
    result = measure(lua, "cycle()", 5000)
    result["remaining_sessions"] = lua.eval("Sessions.count()")
    result["retained_views"] = lua.eval("(function() local n=0; for _ in pairs(closed) do n=n+1 end; return n end)()")
    assert result["remaining_sessions"] == result["retained_views"] == 0
    return result


if __name__ == "__main__":
    facade = "scripts/mods/BetterInventory/BetterInventory_auto_crafter.lua"
    before = subprocess.check_output(["git", "show", "c2cd679:" + facade], cwd=ROOT, text=True)
    print(json.dumps({
        "engine": ENGINE,
        "method": "five warmed batches; perf_counter wall time; GC stopped inside each sample",
        "quarantined_queue_before": queue_probe(before),
        "quarantined_queue_after": queue_probe((ROOT / facade).read_text(encoding="utf-8")),
        "idle_dispatch_with_idle_subsystem_stubs": idle_probe(),
        "explicit_session_close_with_captured_view": lifecycle_probe(),
    }, indent=2))
