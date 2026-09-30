from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime

ROOT = Path(__file__).resolve().parents[1] / "scripts/mods/BetterInventory"


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(r'''
        function pending()
            local p = {callbacks={}}
            function p:next(success, failure)
                local child = pending()
                local function run()
                    local fn = success
                    if self.failed then fn = failure end
                    if not fn then child:settle(self.value, self.failed); return end
                    local ok, value = pcall(fn, self.value)
                    if not ok then child:settle(value, true)
                    elseif type(value) == "table" and type(value.next) == "function" then
                        value:next(function(v) child:settle(v) end, function(e) child:settle(e,true) end)
                    else child:settle(value) end
                end
                if self.done then run() else self.callbacks[#self.callbacks+1] = run end
                return child
            end
            function p:cancel() read_cancels=(read_cancels or 0)+1 end
            function p:catch(fn) return self:next(nil, fn) end
            function p:settle(value, failed)
                assert(not self.done, "double settlement")
                self.value, self.failed, self.done = value, failed, true
                for _, fn in ipairs(self.callbacks) do fn() end
                self.callbacks = {}
            end
            return p
        end
        function resolved(value) local p=pending(); p:settle(value); return p end
        package.preload["scripts/backend/master_items"] = function()
            return {get_item_instance=function(raw,id)
                return {item_type=raw.item_type or "GADGET", rarity=raw.rarity, gear_id=id}
            end}
        end
        costs = {{type="plasteel",amount=10}}
        package.preload["scripts/settings/item/crafting_settings"] = function()
            return {recipes={upgrade_item={can_craft=function() return true end, get_costs=function() return costs end}}}
        end
        package.preload["scripts/foundation/utilities/promise"] = function()
            return {rejected=function(e) local p=pending(); p:settle(e,true); return p end}
        end
        settings = {enable_automatic_curio_acquisition=true}
        persistent, saves, warnings, writes, reads = {}, 0, 0, {}, 0
        function clone(v)
            if type(v) ~= "table" then return v end
            local t={}; for k,c in pairs(v) do t[k]=clone(c) end; return t
        end
        function table.equals(a,b)
            for k,v in pairs(a) do
                if type(v)=="table" and type(b[k])=="table" then
                    if not table.equals(v,b[k]) then return false end
                elseif v~=b[k] then return false end
            end
            for k in pairs(b) do if a[k]==nil then return false end end
            return true
        end
        mod = {
            get_name=function() return "BetterInventory" end,
            get=function(_,key) return clone(settings[key]) end,
            set=function(_,key,value) settings[key]=clone(value) end,
            localize=function(_,key) return key end,
            warning=function() warnings=warnings+1 end,
            persistent_table=function(_,key,initial) persistent[key]=persistent[key] or initial; return persistent[key] end,
        }
        save_fails = false
        saved_settings = {}
        Application = {user_setting=function(root,name,key)
            assert(root=="mods_settings" and name=="BetterInventory")
            return clone(saved_settings[key])
        end}
        function get_mod() return {save_unsaved_settings_to_file=function()
            if save_fails then error("disk unavailable") end
            -- DMF catches Application.set_user_setting errors and returns nil.
            if silent_save_failure then return end
            saved_settings=clone(settings)
            saves=saves+1
        end} end
        account, context, balance = "account-a", "hub:one", 100
        gear = {z={characterId="char-a",rarity=2}, a={characterId="char-b",rarity=4}, unrelated={characterId="char-a",rarity=2}}
        read_pending, wallet_pending = nil, nil
        Managers = {backend={interfaces={
            gear={fetch=function() reads=reads+1; return read_pending or resolved(clone(gear)) end},
            wallet={account_wallets=function() return wallet_pending or resolved({{balance={type="plasteel",amount=balance}}}) end},
        }}, data_service={crafting={upgrade_gadget_rarity=function(_,id,price)
            assert(not last_write or last_write.done)
            assert(settings._automatic_curio_consecration_queue[account][id].attempted_rarity == gear[id].rarity)
            assert(saves > 0 and price[1].amount==10)
            last_write=pending(); writes[#writes+1]=id
            return last_write
        end}}}
        lease, serial = nil, 0
        function acquire() if lease then return end; serial=serial+1; lease=serial; return lease end
        function release(_,token) if lease == token then lease=nil end end
        function setup(worker,guard)
            worker.configure({guard=guard,acquire=acquire,release=release,
                context=function() return context, account end})
        end
        function complete()
            local id=writes[#writes]; gear[id].rarity=gear[id].rarity+1
            last_write:settle({items={}})
        end
    ''')
    guard_path = ROOT / "BetterInventory_account_mutation_guard.lua"
    worker_path = ROOT / "BetterInventory_curio_consecration.lua"
    lua.globals().Guard = lua.execute(guard_path.read_text(encoding="utf-8"), name=str(guard_path))
    lua.globals().Worker = lua.execute(worker_path.read_text(encoding="utf-8"), name=str(worker_path))
    lua.execute(r'''
        Guard.configure({mod=mod,additional_busy=function() return Worker.busy() end})
        setup(Worker,Guard)
        function tick(dt) Worker.update(mod,dt or 30,false) end
        -- Default enabled; FIFO receipt order, independent of lexicographic IDs.
        Worker.enqueue(mod,account,"char-a",{{uuid="z"},{uuid="z"}})
        Worker.enqueue(mod,account,"char-b",{{uuid="a"}})
        Worker.enqueue(mod,"default","char-a",{{uuid="unrelated"}})
        assert(saves==2)
        tick(); assert(#writes==1 and writes[1]=="z" and Worker.mutation_inflight() and Guard.has_pending())
        tick(100); assert(#writes==1) -- Never expire a native write lock.
        complete(); tick(); assert(#writes==2 and writes[2]=="z")
        complete(); tick(); assert(#writes==3 and writes[3]=="z")
        complete(); tick(); tick(); assert(#writes==4 and writes[4]=="a")
        complete(); tick(); tick()
        assert(next(settings._automatic_curio_consecration_queue[account])==nil)
        assert(gear.unrelated.rarity==2 and not Worker.busy() and not lease)
        -- Materials and user switches pause the head without dispatching later items.
        gear.z.rarity=2
        Worker.enqueue(mod,account,"char-a",{{gear_id="z"}})
        balance=0; tick(); tick(); assert(#writes==4 and warnings==1)
        balance=100; settings.automatic_curio_consecrate_transcendent=false
        tick(); assert(#writes==4)
        settings.automatic_curio_consecrate_transcendent=true
        -- Mission/character changes while GET is pending make its callback inert.
        read_pending=pending(); tick(); assert(Worker.busy())
        local blocked=Guard.intercept("crafting.upgrade_gadget_rarity",function() error("external dispatch") end,{})
        assert(blocked.failed and blocked.value.code=="better_inventory_auto_crafter_busy")
        context=nil; tick(); assert(not Worker.busy() and not lease)
        read_pending:settle(clone(gear)); read_pending=nil; assert(#writes==4)
        context="menu:two"; wallet_pending=pending(); tick()
        context="hub:three"; tick(); wallet_pending:settle({{balance={type="plasteel",amount=100}}})
        wallet_pending=nil; assert(#writes==4)
        -- Bound hung reads and allow a fresh read after timeout.
        read_pending=pending(); tick(); tick(31); assert(not Worker.busy())
        assert(read_cancels >= 3)
        local late=read_pending; read_pending=nil
        tick(); assert(#writes==5)
        late:settle(clone(gear)); assert(#writes==5)
        -- Context loss during POST keeps both the write fence and journal.
        context=nil; tick(); assert(Worker.mutation_inflight() and Guard.has_pending())
        complete(); assert(not Worker.busy())
        context="hub:four"; tick(); assert(#writes==6)
        -- Simulate a rejected/ambiguous POST: never replay unchanged rarity.
        last_write:settle("network uncertainty",true)
        tick(); tick(); assert(#writes==6 and not Worker.busy())
        -- An observed native/manual upgrade unblocks reconciliation.
        gear.z.rarity=gear.z.rarity+1; tick(); assert(#writes==7)
    ''')
    # Fresh module generation shares only the DMF fence and serialized journal.
    lua.globals().OldWorker = lua.globals().Worker
    lua.execute('Worker.cancel(); Guard.set_active(false)')
    lua.globals().Worker = lua.execute(worker_path.read_text(encoding="utf-8"), name=str(worker_path))
    lua.globals().Guard = lua.execute(guard_path.read_text(encoding="utf-8"), name=str(guard_path))
    lua.execute(r'''
        Guard.configure({mod=mod,additional_busy=function() return Worker.busy() end}); setup(Worker,Guard)
        tick(); assert(#writes==7 and Guard.has_pending())
        complete(); tick(); assert(#writes==7 and not Guard.has_pending())
        assert(next(settings._automatic_curio_consecration_queue[account])==nil)
        -- Process restart with an uncertain stored attempt is also read-before-write.
        gear.z.rarity=2
        Worker.enqueue(mod,account,"char-a",{{uuid="z"}})
        settings._automatic_curio_consecration_queue[account].z.attempted_rarity=2
        tick(); assert(#writes==7)
        account="account-b"; tick(); assert(#writes==7)
        account="account-a"; gear.z.rarity=5; tick()
        assert(next(settings._automatic_curio_consecration_queue[account])==nil)
        -- Missing/deleted items and changed owners do not receive upgrades.
        Worker.enqueue(mod,account,"char-a",{{uuid="missing"},{uuid="a"}})
        tick(); tick(); assert(#writes==7)
        -- Persistence failure must happen before dispatch.
        gear.z.rarity=2; Worker.enqueue(mod,account,"char-a",{{uuid="z"}})
        save_fails=true; tick(); assert(#writes==7 and not Worker.busy() and not lease)
        save_fails=false
        settings._automatic_curio_consecration_queue[account].z.attempted_rarity=nil
        silent_save_failure=true; tick()
        assert(#writes==7 and not Worker.busy() and not lease, "silent save failure dispatched an upgrade")
        assert(saved_settings._automatic_curio_consecration_queue[account].z.attempted_rarity==nil)
        silent_save_failure=false
        settings._automatic_curio_consecration_queue[account].z.attempted_rarity=nil
        costs={{type="plasteel",amount=-1}}; tick(); assert(#writes==7)
        costs={{type="plasteel",amount=10}}
        lease=999; tick(); assert(#writes==7); lease=nil
        settings.enable_automatic_curio_acquisition=false; tick(); assert(#writes==7)
        settings.enable_automatic_curio_acquisition=true; setup(Worker,{})
        tick(); assert(#writes==7 and not lease)
    ''')
    print("Curio FIFO, default option, authoritative rarity, materials, cancellation, restart/reload and account fences passed.")


if __name__ == "__main__":
    main()
