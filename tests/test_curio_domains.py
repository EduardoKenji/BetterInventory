from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_curio_domains.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    domains = lua.execute(MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH))

    state = lua.table_from(
        {
            "account_key": "account-a",
            "active_context": "morningstar",
            "context_entry_id": 4,
            "read_request_generation": 2,
            "token": 9,
        }
    )
    snapshot = domains.context.snapshot(state)
    assert domains.context.matches(snapshot, state) is True
    state.token = 10
    assert domains.context.matches(snapshot, state) is False
    assert domains.context.token_matches(state, 10) is True

    first = lua.table_from({"report_id": "first"})
    second = lua.table_from({"report_id": "second"})
    replacement = lua.table_from({"report_id": "first", "updated": True})
    queue = lua.table_from([first, second])
    bounded, inserted = domains.reports.upsert_bounded(queue, replacement, 2)
    assert inserted is False
    assert bounded[1].updated is True
    bounded, inserted = domains.reports.upsert_bounded(bounded, lua.table_from({"report_id": "third"}), 2)
    assert inserted is True
    assert bounded[1].report_id == "second"
    assert bounded[2].report_id == "third"
    assert queue[1].updated is None

    remaining, removed = domains.reports.remove_head(bounded)
    assert removed.report_id == "second"
    assert remaining[1].report_id == "third"
    assert domains.scheduler.next_retry_delay("morningstar", 5, 6, 1) == 1
    assert domains.scheduler.next_retry_delay("operative_selection", 5, 6, 1) == 0

    print("BetterInventory Curio-domain boundary tests passed.")


if __name__ == "__main__":
    main()
