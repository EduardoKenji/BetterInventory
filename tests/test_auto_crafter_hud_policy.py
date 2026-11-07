from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
POLICY_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "auto_crafter"
    / "core"
    / "hud_policy.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    policy = lua.execute(
        POLICY_PATH.read_text(encoding="utf-8"), name=str(POLICY_PATH)
    )
    table = lua.table_from

    active = table({"phase4": table({"running": True})}, recursive=True)
    completed = table(
        {
            "terminal_sequence": 4,
            "search": {"generation": 2},
            "phase4": {
                "running": False,
                "elapsed_seconds": 12,
                "completed_at": 100,
                "gear_id": "gear-final",
            },
        },
        recursive=True,
    )

    # A terminal callback can settle between frames. Dirty presentation state
    # must wake the facade even after the controller becomes idle.
    assert policy.presentation_needs_update(None, 0, True) is True
    assert policy.run_active(active) is True
    assert policy.completion_pending(completed, 2) is True
    assert policy.presentation_needs_update(completed, 2, False) is True
    assert policy.presentation_needs_update(completed, 0, False) is False

    elapsed = policy.advance_completion_elapsed(completed, 2, 0, 7)
    assert elapsed == 7
    assert policy.completion_visible(completed, elapsed) is True
    elapsed = policy.advance_completion_elapsed(completed, 2, elapsed, 5.01)
    assert elapsed == 12.01
    assert policy.completion_visible(completed, elapsed) is False
    assert policy.advance_completion_elapsed(active, 4, elapsed, 1) == 0

    next_completed = table(
        {
            "terminal_sequence": 5,
            "search": {"generation": 3},
            "phase4": {
                "running": False,
                "elapsed_seconds": 8,
                "completed_at": 120,
                "gear_id": "gear-next",
            },
        },
        recursive=True,
    )
    assert policy.completion_key(completed) != policy.completion_key(next_completed)

    final_refresh = table(
        {"phase4": {"running": True, "final_reconcile_started": True}},
        recursive=True,
    )
    mark_switch = table(
        {
            "phase4": {
                "running": True,
                "target_mark_id": "weapon-2",
                "current_item": {"master_id": "weapon-1"},
            }
        },
        recursive=True,
    )
    trait_step = table(
        {
            "phase4": {
                "running": True,
                "current_item": {"master_id": "weapon-2"},
                "targets": {"perks": {1: {"id": "perk"}}, "traits": {}},
            }
        },
        recursive=True,
    )
    assert policy.phase4_status(final_refresh) == "final_reconcile"
    assert policy.phase4_status(mark_switch) == "switch_mark"
    assert policy.phase4_status(trait_step) == "traits"

    # P16: the per-frame completion checks only need a boolean, not the key string.
    assert policy.completion_ready(completed) is True
    assert policy.completion_ready(active) is False and policy.completion_ready(None) is False
    errored = table({"last_error": "x", "phase4": {"running": False, "elapsed_seconds": 1}}, recursive=True)
    assert policy.completion_ready(errored) is False and policy.completion_key(errored) is None
    assert policy.completion_pending(completed, 0) is False and policy.completion_visible(None, 0) is False
    lua.globals().HudPolicyUnderTest = policy
    lua.globals().HudCompletedSnapshot = completed
    lua.execute(
        '''
        local hook, hook_mask, hook_count = debug.gethook()
        debug.sethook()
        collectgarbage("collect")
        collectgarbage("stop")
        local before = collectgarbage("count")
        for _ = 1, 1000 do
            HudPolicyUnderTest.presentation_needs_update(HudCompletedSnapshot, 2, false)
            HudPolicyUnderTest.completion_visible(HudCompletedSnapshot, 1)
            HudPolicyUnderTest.advance_completion_elapsed(HudCompletedSnapshot, 2, 1, 0.016)
        end
        local grown = collectgarbage("count") - before
        collectgarbage("restart")
        if hook then debug.sethook(hook, hook_mask, hook_count) end
        assert(grown < 1, "completion checks allocated " .. grown .. " KB")
        '''
    )

    # P17: the diagnostic report line keeps its exact text but is built without
    # a table per field.
    mastery_path = POLICY_PATH.with_name("mastery_policy.lua")
    lua.globals().MasteryPolicyUnderTest = lua.execute(
        mastery_path.read_text(encoding="utf-8"), name=str(mastery_path)
    )
    lua.execute(
        r'''
        local M = MasteryPolicyUnderTest
        local state = {_generation=3,_operation_sequence=7,_phase="phase3_wait",_run_elapsed=12.345,
            _search={purchases=4}, _phase3={fodder_count=2,current={mastery_level=5,claimed_level=4,current_xp=1200}}}
        local full = M.diagnostic_message(state, "operation_failed", {kind="upgrade", reason="timeout", error="boom", gear_id="g1", count=2, amount=10.5, expected_xp=300, attempts=3, retry=false,
            candidate={gear_id="g2", rarity=5, expertise_level=480}, duration=1.5, timings={upgrade={count=2,total=1.25}, extract={count=1,total=0.5}}})
        assert(full == "[AutoCrafter] event=operation_failed run=3 op=7 phase=phase3_wait elapsed=12.35s kind=upgrade reason=timeout error=boom gear=g1 count=2 amount=10.5 expected_xp=300 attempt=3 retry=false mastery=5 claimed=4 xp=1200 purchases=4 fodder=2 rarity=5 expertise=480 duration=1.500s timings=extract:1x/0.50s,upgrade:2x/1.25s", full)
        assert(M.diagnostic_message({_generation=1}, "x", nil) == "[AutoCrafter] event=x run=1 op=nil phase=nil elapsed=0.00s")
        local hook, hook_mask, hook_count = debug.gethook()
        debug.sethook()
        collectgarbage("collect")
        collectgarbage("stop")
        local before = collectgarbage("count")
        local payload = {kind="upgrade", reason="timeout", gear_id="g1", count=2}
        for _ = 1, 200 do M.diagnostic_message(state, "operation_failed", payload) end
        local per_call = (collectgarbage("count") - before) / 200
        collectgarbage("restart")
        if hook then debug.sethook(hook, hook_mask, hook_count) end
        assert(per_call < 1.2, "diagnostic_message allocated " .. per_call .. " KB per report")
        '''
    )

    print("Auto Crafter HUD terminal-transition policy tests passed.")


if __name__ == "__main__":
    main()
