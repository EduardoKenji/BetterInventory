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
        "retry_interval": 0.1,
        "max_wait_seconds": 0.3,
    }))
    view = lua.table_from({})

    assert coordinator.capture_original(coordinator, view) is True
    relic = lua.table_from({"offer_id": "relic-blade", "master_id": "relic-mark", "slot_type": "slot_primary"})
    assert coordinator.request(coordinator, view, relic, "queue_installed") is True
    assert coordinator.has_pending(coordinator) is True
    assert coordinator.update(coordinator, view, 0.05) is False
    assert attempts["relic-blade"] == 1
    pending = coordinator.snapshot(coordinator)["pending"]
    assert abs(float(pending["elapsed"]) - 0.05) < 0.001
    assert coordinator.update(coordinator, view, 0.05) is True
    assert attempts["relic-blade"] == 2
    assert coordinator.has_pending(coordinator) is False

    ranged = lua.table_from({"offer_id": "purgation-flamer", "master_id": "flamer-mark", "slot_type": "slot_secondary"})
    assert coordinator.request(coordinator, view, ranged, "queue_card_selected") is True
    assert coordinator.update(coordinator, view) is True
    assert coordinator.restore(coordinator, view) is True
    assert coordinator.snapshot(coordinator)["original"] is None
    assert coordinator.update(coordinator, view) is True
    assert attempts["thunder-hammer-family"] == 2

    # A permanently unavailable offer is bounded and becomes inert.
    failure_events = []
    failing_attempts = 0

    def unavailable_offer(_view, _offer):
        nonlocal failing_attempts
        failing_attempts += 1
        return False, "offer_not_in_native_store", 17

    failing = module.new(lua.table_from({
        "current_selection": wrapper(lambda _view: current),
        "select_offer": wrapper(unavailable_offer),
        "view_is_valid": wrapper(lambda _view: True),
        "report": wrapper(lambda kind, payload: failure_events.append((str(kind), payload))),
        "max_attempts": 2,
        "retry_interval": 0.1,
        "max_wait_seconds": 0.3,
    }))
    assert failing.request(failing, view, relic, "unavailable") is True
    assert failing.update(failing, view, 0.05) is False
    assert failing.has_pending(failing) is True
    assert failing_attempts == 1
    assert failing.update(failing, view, 0.05) is False
    assert failing.has_pending(failing) is False
    assert failing_attempts == 2
    failure_kind, failure_payload = failure_events[-1]
    assert failure_kind == "selection_failed"
    assert failure_payload["error"] == "offer_not_in_native_store"
    assert failure_payload["detail"] == 17
    assert failure_payload["timeout_reason"] == "attempt_limit"
    assert abs(float(failure_payload["elapsed"]) - 0.1) < 0.001

    # Elapsed time provides an independent wall-clock bound without retrying
    # on every rendered frame or issuing a burst after one slow frame.
    timeout_events = []
    timeout_attempts = 0

    def pending_tab_switch(_view, _offer):
        nonlocal timeout_attempts
        timeout_attempts += 1
        return False, "tab_switch_pending", 2

    timing_out = module.new(lua.table_from({
        "current_selection": wrapper(lambda _view: current),
        "select_offer": wrapper(pending_tab_switch),
        "view_is_valid": wrapper(lambda _view: True),
        "report": wrapper(lambda kind, payload: timeout_events.append((str(kind), payload))),
        "max_attempts": 30,
        "retry_interval": 0.1,
        "max_wait_seconds": 0.25,
    }))
    assert timing_out.request(timing_out, view, relic, "slow_native_preview") is True
    assert timing_out.update(timing_out, view, 0.1) is False
    assert timing_out.update(timing_out, view, 0.1) is False
    assert timing_out.update(timing_out, view, 0.05) is False
    assert timing_out.has_pending(timing_out) is False
    assert timeout_attempts == 3
    timeout_kind, timeout_payload = timeout_events[-1]
    assert timeout_kind == "selection_failed"
    assert timeout_payload["timeout_reason"] == "elapsed_timeout"
    assert timeout_payload["error"] == "tab_switch_pending"
    assert abs(float(timeout_payload["elapsed"]) - 0.25) < 0.001

    # Native VendorViewBase defers cb_switch_tab until its input pass. The host
    # adapter therefore snapshots only scalar selection identity, requests the
    # slot tab, returns false, then focuses the offer on a later bounded retry.
    host = MOD_PATH.read_text(encoding="utf-8")
    assert "local function auto_crafter_selected_offer_snapshot(view)" in host
    assert 'auto_crafter_read(view, "_previewed_offer")' in host
    assert 'auto_crafter_read(view, "_tabs_content")' in host
    assert "tab_menu.selected_index" in host
    assert "view.cb_switch_tab" in host
    assert '"offer_not_in_native_store"' in host
    assert '"offer_not_in_native_layout"' in host
    assert '"tab_switch_pending"' in host
    assert 'type(view._preview_element) == "function"' in host
    assert '"preview_element_failed"' in host
    assert '"preview_not_confirmed"' in host
    switch_branch = host.split("if target_tab_index and selected_tab_index", 1)[1].split("local focused_ok", 1)[0]
    assert "return false" in switch_branch
    assert "get_selected_offer_snapshot = auto_crafter_selected_offer_snapshot" in host

    # Execute the production adapter in isolation. Darktide's focus_on_offer
    # returns nil even when it silently misses a grid widget, so a validated
    # native layout entry must drive the native preview fallback directly.
    adapter_body = host.split("local function read_member", 1)[1].split("AutoCrafter.configure =", 1)[0]
    adapter = lua.execute("local function read_member" + adapter_body + "\nreturn auto_crafter_select_offer")
    target_offer = lua.table_from({
        "offerId": "knife-offer",
        "description": lua.table_from({"lootChoices": lua.table_from(["combatknife_p1_m1"])}),
    })
    previous_offer = lua.table_from({"offerId": "sword-offer"})
    target_entry = lua.table_from({
        "offer": target_offer,
        "item": lua.table_from({"slots": lua.table_from(["slot_primary"])}),
    })
    tab_menu = lua.table_from({"selected_index": lua.eval("function() return 1 end")})
    silent_focus = lua.eval("function() end")
    native_preview = lua.eval("function(view, entry) view._previewed_offer = entry.offer end")
    adapter_view = lua.table_from({
        "_offers": lua.table_from([target_offer]),
        "_offer_items_layout": lua.table_from([target_entry]),
        "_tabs_content": lua.table_from([lua.table_from({"slot_types": lua.table_from(["slot_primary"])})]),
        "_tab_menu_element": tab_menu,
        "_previewed_offer": previous_offer,
        "focus_on_offer": silent_focus,
        "_preview_element": native_preview,
    })
    selected_offer = lua.table_from({
        "offer_id": "knife-offer",
        "master_id": "combatknife_p1_m1",
        "slot_type": "slot_primary",
    })
    selected = adapter(adapter_view, selected_offer)
    assert selected is True
    assert adapter_view["_previewed_offer"]["offerId"] == "knife-offer"

    missing_layout_view = lua.table_from({
        "_offers": lua.table_from([target_offer]),
        "_offer_items_layout": lua.table_from([]),
        "focus_on_offer": silent_focus,
    })
    selected, selection_error, layout_count = adapter(missing_layout_view, selected_offer)
    assert selected is False
    assert selection_error == "offer_not_in_native_layout"
    assert layout_count == 0


if __name__ == "__main__":
    main()
