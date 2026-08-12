from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SELECTION_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "games_lantern" / "selection_coordinator.lua"
MOD_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    module = lua.execute(SELECTION_PATH.read_text(encoding="utf-8"), name=str(SELECTION_PATH))

    def wrapper(callback):
        return lua.eval("function(callback) return function(...) return callback(...) end end")(callback)

    current = lua.table_from({
        "offer_id": "thunder-hammer-family",
        "master_id": "thunder-hammer-mark",
        "slot_type": "slot_primary",
        "tab_index": 1,
    })
    attempts: dict[str, int] = {}
    events: list[str] = []

    def select_offer(_view, offer):
        offer_id = str(offer["offer_id"])
        attempts[offer_id] = attempts.get(offer_id, 0) + 1
        # Darktide defers tab switching; success is possible on the next frame.
        return attempts[offer_id] >= 2

    coordinator = module.new(lua.table_from({
        "current_selection": wrapper(lambda _view: current),
        "select_offer": wrapper(select_offer),
        "view_is_valid": wrapper(lambda _view: True),
        "report": wrapper(lambda kind, _payload: events.append(str(kind))),
        "max_attempts": 3,
    }))
    view = lua.table_from({})

    assert coordinator.capture_original(coordinator, view) is True
    relic = lua.table_from({"offer_id": "relic-blade", "master_id": "relic-mark", "slot_type": "slot_primary"})
    assert coordinator.request(coordinator, view, relic, "queue_installed") is True
    assert coordinator.has_pending(coordinator) is True
    assert coordinator.update(coordinator, view) is True
    assert coordinator.has_pending(coordinator) is False

    ranged = lua.table_from({"offer_id": "purgation-flamer", "master_id": "flamer-mark", "slot_type": "slot_secondary"})
    assert coordinator.request(coordinator, view, ranged, "queue_card_selected") is True
    assert coordinator.update(coordinator, view) is True
    assert coordinator.restore(coordinator, view) is True
    assert coordinator.snapshot(coordinator)["original"] is None
    assert coordinator.update(coordinator, view) is True
    assert attempts["thunder-hammer-family"] == 2

    # A permanently unavailable offer is bounded and becomes inert.
    failing = module.new(lua.table_from({
        "current_selection": wrapper(lambda _view: current),
        "select_offer": wrapper(lambda _view, _offer: False),
        "view_is_valid": wrapper(lambda _view: True),
        "report": wrapper(lambda kind, _payload: events.append(str(kind))),
        "max_attempts": 2,
    }))
    assert failing.request(failing, view, relic, "unavailable") is True
    assert failing.update(failing, view) is False
    assert failing.has_pending(failing) is False
    assert "selection_failed" in events

    # Native VendorViewBase defers cb_switch_tab until its input pass. The host
    # adapter therefore snapshots only scalar selection identity, requests the
    # slot tab, returns false, then focuses the offer on a later bounded retry.
    host = MOD_PATH.read_text(encoding="utf-8")
    assert "local function auto_crafter_selected_offer_snapshot(view)" in host
    assert 'auto_crafter_read(view, "_previewed_offer")' in host
    assert 'auto_crafter_read(view, "_tabs_content")' in host
    assert "tab_menu.selected_index" in host
    assert "view.cb_switch_tab" in host
    switch_branch = host.split("if target_tab_index and selected_tab_index", 1)[1].split("local focused_ok", 1)[0]
    assert "return false" in switch_branch
    assert "get_selected_offer_snapshot = auto_crafter_selected_offer_snapshot" in host


if __name__ == "__main__":
    main()
