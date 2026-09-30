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

    facade = facade_path.read_text(encoding="utf-8")
    context = facade[facade.index("\tgames_lantern_resolution_context = function()"):facade.index("\tlocal function games_lantern_fetch_catalogs")]
    lua.execute("""
        controller = {snapshot=function() return {data={store={offers={{offer_id="one"}}}}} end}
        runtime_context = {current_identity=function() return {stable=true} end}
        CandidatePolicy = {}
        setting = function(_, default) return default end
        active_brunt_view = {_offer_items_layout={}}
    """)
    lua.execute(context + """
        assert(not games_lantern_resolution_context().native_store_ready)
        active_brunt_view._offer_items_layout = {{offer={offerId="stale"}}}
        assert(not games_lantern_resolution_context().native_store_ready)
        active_brunt_view._offer_items_layout = {{offer={offerId="one"}}}
        assert(games_lantern_resolution_context().native_store_ready)
    """)


def test_catalog_host_recreation():
    lua = LuaRuntime(unpack_returned_tuples=True)
    facade = (ROOT / "BetterInventory_auto_crafter.lua").read_text(encoding="utf-8")
    host = facade[facade.index("\tlocal function games_lantern_fetch_catalogs"):facade.index("\tlocal function games_lantern_import_allowed")]
    lua.execute("""
        games_lantern_catalog_generation = 0
        callbacks, completions = {}, 0
        backend = {discover_weapon_catalog=function()
            return {next=function(self, callback)
                callbacks[#callbacks+1] = callback
                return self
            end, catch=function() end}
        end}
    """)
    lua.execute(host + """
        local identity = {jobs={{master_id="one", offer={}}, {master_id="two", offer={}}}}
        local function complete() completions=completions+1 end
        games_lantern_fetch_catalogs(identity, complete, 1)
        games_lantern_cancel_catalogs(1)
        -- A replacement import controller starts its serial counter at one.
        games_lantern_fetch_catalogs(identity, complete, 1)
        assert(#callbacks == 2)
        callbacks[1]({available=true})
        assert(#callbacks == 2 and completions == 0)
        callbacks[2]({available=true})
        assert(#callbacks == 3)
        callbacks[3]({available=true})
        assert(completions == 1)
    """)


def test_queue_stop_polling():
    from auto_crafter_test_support import load_controller

    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().Controller = load_controller(lua)
    path = ROOT / "BetterInventory_auto_crafter.lua"
    lua.globals().Facade = lua.execute(path.read_text(encoding="utf-8"), name=str(path))
    lua.execute("""
        local controller = assert(Controller.new())
        controller.update = function() end
        controller.snapshot = function() error("stop polling must not allocate a snapshot") end
        local settled, requested, state = 0, true, "stopping"
        local queue = {
            state=function() return state end,
            stop_requested=function() return requested end,
            on_event=function(_, event)
                assert(event == "stop_settled")
                settled=settled+1
            end,
        }
        local values = {controller=controller, games_lantern_queue=queue,
            presentation_dirty=false, presentation_snapshot={}}
        for i=1,100 do
            local name = debug.getupvalue(Facade.update, i)
            if not name then break end
            if values[name] ~= nil then debug.setupvalue(Facade.update, i, values[name]) end
        end
        for _, queue_state in ipairs({"stopping", "quarantined", "reconciliation_required"}) do
            state = queue_state
            for _, field in ipairs({"_operation_inflight", "_operation_quarantined",
                "_auxiliary_inflight_count", "_search", "_phase3", "_phase4", "_mastery"}) do
                local previous = controller[field]
                controller[field] = field == "_auxiliary_inflight_count" and 1
                    or string.find(field, "operation", 1, true) and true or {running=true}
                local before = settled
                Facade.update(1/60)
                assert(settled == before, field .. " must block settlement")
                controller[field] = previous
            end
            local before = settled
            requested = false
            Facade.update(1/60)
            assert(settled == before)
            requested = true
            Facade.update(1/60)
            assert(settled == before+1)
        end
    """)


if __name__ == "__main__":
    main()
    test_catalog_host_recreation()
    test_queue_stop_polling()
