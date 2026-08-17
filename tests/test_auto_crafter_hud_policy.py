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

    print("Auto Crafter HUD terminal-transition policy tests passed.")


if __name__ == "__main__":
    main()
