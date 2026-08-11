from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
GUARD_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_account_mutation_guard.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        package.preload["scripts/foundation/utilities/promise"] = function()
            return {
                rejected = function(error_value)
                    return {rejected = true, error_value = error_value}
                end,
            }
        end

        Managers = {
            event = {
                trigger = function() end,
            },
        }
        '''
    )
    guard = lua.execute(GUARD_PATH.read_text(encoding="utf-8"))
    lua.globals().Guard = guard
    lua.execute(
        r'''
        local state = {
            busy = false,
            snapshot = {},
            interruptions = 0,
        }
        local auto_crafter = {}
        function auto_crafter.is_busy() return state.busy end
        function auto_crafter.snapshot() return state.snapshot end
        function auto_crafter.interrupt_for_external_mutation(kind)
            state.interruptions = state.interruptions + 1
            state.last_kind = kind
            state.busy = false
            return true
        end

        local warnings = {}
        local mod = {}
        function mod:warning(message) warnings[#warnings + 1] = message end
        function mod:info(_) end
        Guard.configure({mod = mod, auto_crafter = auto_crafter})

        local calls = 0
        local function original(service, value)
            calls = calls + 1
            return service.prefix .. value
        end

        -- Inactive automation never changes native/manual behavior.
        assert(Guard.intercept("store.purchase_item", original, {prefix = "ok:"}, "one") == "ok:one")
        assert(calls == 1 and state.interruptions == 0)

		-- Invalid mark PATCH inputs are visible no-ops even while automation is idle.
		local invalid_mark = Guard.intercept("mastery.switch_mark", original, {prefix = "bad:"}, "", nil)
		assert(invalid_mark.rejected == true)
		assert(invalid_mark.error_value.code == "better_inventory_invalid_mark_request")
		assert(calls == 1 and state.interruptions == 0)

        -- Between requests, a manual mutation atomically stops Auto Crafter and wins.
        state.busy = true
        state.snapshot = {operation_inflight = false, auxiliary_inflight_count = 0}
        assert(Guard.intercept("store.purchase_item", original, {prefix = "ok:"}, "two") == "ok:two")
        assert(calls == 2 and state.interruptions == 1)
        assert(state.last_kind == "store.purchase_item" and state.busy == false)

        -- During an unresolved primary or auxiliary request, external writes fail closed.
        state.busy = true
        state.snapshot = {operation_inflight = true, auxiliary_inflight_count = 0}
        local blocked = Guard.intercept("gear.delete_gear_batch", original, {prefix = "bad:"}, "three")
        assert(blocked.rejected == true)
        assert(blocked.error_value.code == "better_inventory_auto_crafter_busy")
        assert(calls == 2 and state.interruptions == 1)

        state.snapshot = {operation_inflight = false, auxiliary_inflight_count = 1}
        blocked = Guard.intercept("crafting.upgrade_weapon_rarity", original, {prefix = "bad:"}, "four")
        assert(blocked.rejected == true and calls == 2)

        state.snapshot = {operation_quarantined = true, auxiliary_inflight_count = 0}
        blocked = Guard.intercept("mastery.purchase_traits", original, {prefix = "bad:"}, "five")
        assert(blocked.rejected == true and calls == 2)

		state.snapshot = {operation_inflight = true, auxiliary_inflight_count = 0}
		blocked = Guard.intercept("mastery.switch_mark", original, {prefix = "bad:"}, "mark-id")
		assert(blocked.rejected == true and calls == 2)

        -- Calls explicitly owned by Auto Crafter bypass its own service hooks only
        -- for the synchronous backend dispatch scope.
        state.snapshot = {operation_inflight = true}
        local owned_result = Guard.with_owned_call(function()
            assert(Guard.is_owned_call() == true)
            return Guard.intercept("store.purchase_item_with_wallet", original, {prefix = "owned:"}, "six")
        end)
        assert(owned_result == "owned:six" and calls == 3)
        assert(Guard.is_owned_call() == false)

		-- Preserve explicit no-cost sentinel and trailing tier through the owned
		-- hook path used by CraftingService.replace_perk_in_weapon.
		local perk_arguments
		Guard.with_owned_call(function()
			return Guard.intercept("crafting.replace_perk_in_weapon", function(_, ...)
				perk_arguments = table.pack(...)
			end, {}, "gear-1", 1, "perk-1", false, 4)
		end)
		assert(perk_arguments.n == 5)
		assert(perk_arguments[1] == "gear-1" and perk_arguments[2] == 1)
		assert(perk_arguments[3] == "perk-1" and perk_arguments[4] == false and perk_arguments[5] == 4)

        local owned_ok = pcall(Guard.with_owned_call, function() error("owned failure") end)
        assert(owned_ok == false and Guard.is_owned_call() == false)

        -- The hook inventory covers every account-writing service used by native UI,
        -- Quick Level Mastery, Auto Crafter, and BetterInventory discard automation.
        -- CraftingService.reset_sticker_book is deliberately absent: Darktide's
        -- MasteryService.purchase_traits invokes it asynchronously as a local cache
        -- refresh before the owned purchase promise settles. Treating that refresh
        -- as an external write makes Auto Crafter reject its own mastery allocation.
        local expected = {
            ["store.purchase_item"] = true,
            ["store.purchase_item_with_wallet"] = true,
            ["crafting.add_weapon_expertise"] = true,
            ["crafting.extract_weapon_mastery"] = true,
            ["crafting.replace_perk_in_weapon"] = true,
            ["crafting.replace_trait_in_weapon"] = true,
            ["crafting.upgrade_weapon_rarity"] = true,
            ["mastery.claim_levels_by_new_exp"] = true,
            ["mastery.purchase_traits"] = true,
			["mastery.switch_mark"] = true,
            ["gear.delete_gear_batch"] = true,
            ["items.set_item_id_as_favorite"] = true,
        }
        local actual = {}
        local service_classes = {}
        for _, definition in ipairs(Guard.SERVICE_MUTATIONS) do
            local service_class = {}
            service_classes[definition.path] = service_class
            package.preload[definition.path] = function() return service_class end
            for _, method_name in ipairs(definition.methods) do
                actual[definition.prefix .. "." .. method_name] = true
                service_class[method_name] = function() end
            end
        end
        for kind in pairs(expected) do assert(actual[kind] == true, kind) end
        for kind in pairs(actual) do assert(expected[kind] == true, kind) end

        local hooks = {}
        function mod:hook(service_class, method_name, callback)
            hooks[#hooks + 1] = {service_class, method_name, callback}
        end
        assert(Guard.install_hooks(mod) == true)
        assert(#hooks == 12)

        print("Account mutation guard exclusion and hook coverage tests passed.")
        '''
    )


if __name__ == "__main__":
    main()
