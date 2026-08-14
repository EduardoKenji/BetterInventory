from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_equipment_persistence.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r"""
        TestPromise = {}
        unpack = table.unpack

        function TestPromise.resolved(value)
            local promise = {_settled = true, _value = value}

            function promise:next(callback)
                local success, result = pcall(callback, self._value)

                if success then
                    return TestPromise.resolved(result)
                end

                return TestPromise.rejected(result)
            end

            function promise:catch(_callback)
                return self
            end

            return promise
        end

        function TestPromise.rejected(error_value)
            local promise = {_error = error_value, _settled = true}

            function promise:next(_callback)
                return self
            end

            function promise:catch(callback)
                local success, result = pcall(callback, self._error)

                if success then
                    return TestPromise.resolved(result)
                end

                return TestPromise.rejected(result)
            end

            return promise
        end

        function TestPromise.pending()
            local promise = {
                _failure = nil,
                _settled = false,
                _success = nil,
            }

            function promise:next(callback)
                self._success = callback
                return self
            end

            function promise:catch(callback)
                self._failure = callback
                return self
            end

            function promise:resolve(value)
                assert(not self._settled)
                self._settled = true

                if self._success then
                    local success, error_value = pcall(self._success, value)

                    if not success and self._failure then
                        self._failure(error_value)
                    end
                end
            end

            function promise:reject(error_value)
                assert(not self._settled)
                self._settled = true

                if self._failure then
                    self._failure(error_value)
                end
            end

            return promise
        end

        Promise = {
            all = function(...)
                local values = {}

                for index = 1, select("#", ...) do
                    local promise = select(index, ...)

                    if promise._error ~= nil then
                        return TestPromise.rejected(promise._error)
                    end

                    values[index] = promise._value
                end

                return TestPromise.resolved(values)
            end,
        }

        retry_results = {}
        retry_calls = 0
        retried_items = nil
        retry_throw = false
        retry_invalid = false
        Items = {
            equip_slot_items = function(items)
                retry_calls = retry_calls + 1
                retried_items = items

                if retry_throw then
                    error("synchronous retry failure")
                end

                if retry_invalid then
                    return nil
                end

                local result = retry_results[retry_calls]

                if result == nil then
                    result = true
                end

                return TestPromise.resolved(result)
            end,
            equip_slot_master_items = function(_items)
                return TestPromise.resolved(true)
            end,
            unequip_slots = function(_slots)
                return TestPromise.resolved(true)
            end,
        }

        ItemSlotSettings = {
            slot_primary = {},
            slot_trinket_1 = {},
        }

        local require_map = {
            ["scripts/foundation/utilities/promise"] = Promise,
            ["scripts/settings/item/item_slot_settings"] = ItemSlotSettings,
            ["scripts/utilities/items"] = Items,
        }

        require = function(path)
            local value = require_map[path]
            assert(value, "unexpected require: " .. tostring(path))
            return value
        end

        current_character = "character-a"
        current_account = "account-a"
        authoritative_profile = {
            loadout = {},
            marker = "authoritative",
        }
        Managers = {
            backend = {
                account_id = function()
                    return current_account
                end,
            },
            player = {
                local_player_safe = function()
                    return {
                        character_id = function()
                            return current_character
                        end,
                    }
                end,
            },
        }

        old_weapon = {gear_id = "old-weapon"}
        new_weapon = {gear_id = "new-weapon"}
        old_curio = {gear_id = "old-curio"}
        new_curio = {gear_id = "new-curio"}
        view_update_count = 0
        view = {
            _current_profile_equipped_items = {},
            _duplicated_slots = {},
            _invalid_slots = {},
            _is_own_player = true,
            _is_readonly = false,
            _preview_player = {
                character_id = function()
                    return "character-a"
                end,
                profile = function()
                    return authoritative_profile
                end,
            },
            _preview_profile_equipped_items = {
                slot_primary = new_weapon,
                slot_trinket_1 = new_curio,
            },
            _starting_profile_equipped_items = {
                slot_primary = old_weapon,
                slot_trinket_1 = old_curio,
            },
            _valid_slot_for_archetype = function()
                return true
            end,
            _get_item = function(_self, item)
                return item
            end,
            _update_equipped_items = function()
                view_update_count = view_update_count + 1
            end,
        }

        captured_errors = {}
        test_mod = {
            error = function(_self, message)
                captured_errors[#captured_errors + 1] = message
            end,
        }
        """
    )

    module = lua.execute(f"return dofile({str(MODULE_PATH)!r})")
    globals_ = lua.globals()

    captured = module._test.capture_intent(globals_.view)
    assert captured.character_id == "character-a"
    assert captured.gear_items.slot_primary.gear_id == "new-weapon"
    assert captured.gear_items.slot_trinket_1.gear_id == "new-curio"
    assert "slot_primary=new-weapon" in captured.signature
    assert "slot_trinket_1=new-curio" in captured.signature

    # Before the outer Character Overview closes, Y exists only in the shared
    # preview table. A delayed/unrelated authoritative X event must not revert
    # that local delta or the next child inventory will mark X as equipped.
    assert module.refresh_from_authoritative_profile(globals_.view) is False
    assert globals_.view_update_count == 0
    assert globals_.view._preview_profile_equipped_items.slot_primary.gear_id == "new-weapon"

    # A merely pending native request must never trigger a parallel retry.
    globals_.native_promise = globals_.TestPromise.pending()
    globals_.native_calls = 0
    lua.execute(
        """
        native_equip = function(_view)
            native_calls = native_calls + 1
            return native_promise
        end
        """
    )
    returned = module.persist_local_changes(
        globals_.test_mod, globals_.native_equip, globals_.view
    )
    assert returned._settled is False
    assert module.status() == ("pending", 0)
    module.update(globals_.test_mod, 30)
    assert globals_.retry_calls == 0
    assert globals_.native_calls == 1

    # A confirmed false result is safe to retry because equipping the same
    # gear IDs into the same slots is idempotent.
    globals_.native_promise.resolve(globals_.native_promise, lua.table_from([False]))
    assert module.status() == ("waiting_retry", 0)
    module.update(globals_.test_mod, 1.49)
    assert globals_.retry_calls == 0
    module.update(globals_.test_mod, 0.01)
    assert globals_.retry_calls == 1
    assert globals_.retried_items.slot_primary.gear_id == "new-weapon"
    assert globals_.retried_items.slot_trinket_1.gear_id == "new-curio"
    assert globals_.view._starting_profile_equipped_items.slot_primary.gear_id == "new-weapon"
    assert globals_.view._starting_profile_equipped_items.slot_trinket_1.gear_id == "new-curio"
    assert module.status() == ("idle", 0)

    # A profile event cannot erase an optimistic loadout while persistence is
    # pending, but it refreshes the reopened view after settlement.
    globals_.view._starting_profile_equipped_items.slot_primary = globals_.old_weapon
    globals_.view._starting_profile_equipped_items.slot_trinket_1 = globals_.old_curio
    globals_.native_promise = globals_.TestPromise.pending()
    module.persist_local_changes(globals_.test_mod, globals_.native_equip, globals_.view)
    assert module.refresh_from_authoritative_profile(globals_.view) is False
    assert globals_.view_update_count == 0
    globals_.native_promise.resolve(globals_.native_promise, lua.table_from([True]))
    assert module.refresh_from_authoritative_profile(globals_.view) is True
    assert globals_.view._presentation_profile.marker == "authoritative"
    assert globals_.view_update_count == 1

    # A retry from another character/account generation must become inert.
    globals_.view._starting_profile_equipped_items.slot_primary = globals_.old_weapon
    globals_.view._starting_profile_equipped_items.slot_trinket_1 = globals_.old_curio
    globals_.native_promise = globals_.TestPromise.pending()
    module.persist_local_changes(globals_.test_mod, globals_.native_equip, globals_.view)
    globals_.native_promise.resolve(globals_.native_promise, lua.table_from([False]))
    globals_.current_character = "character-b"
    retries_before_switch = globals_.retry_calls
    module.update(globals_.test_mod, 2)
    assert globals_.retry_calls == retries_before_switch
    assert module.status() == ("idle", 0)
    globals_.current_character = "character-a"

    # Confirmed failures are bounded and surface an error after two retries.
    globals_.view._starting_profile_equipped_items.slot_primary = globals_.old_weapon
    globals_.view._starting_profile_equipped_items.slot_trinket_1 = globals_.old_curio
    globals_.retry_results = lua.table_from([False, False])
    globals_.retry_calls = 0
    globals_.captured_errors = lua.table_from([])
    globals_.native_promise = globals_.TestPromise.pending()
    module.persist_local_changes(globals_.test_mod, globals_.native_equip, globals_.view)
    globals_.native_promise.resolve(globals_.native_promise, lua.table_from([False]))
    module.update(globals_.test_mod, 1.5)
    assert module.status() == ("waiting_retry", 1)
    module.update(globals_.test_mod, 1.5)
    assert globals_.retry_calls == 2
    assert module.status() == ("idle", 0)
    assert len(globals_.captured_errors) == 1

    # Retry helpers execute from the frame update. Synchronous exceptions and
    # incompatible promise results must remain inside the bounded retry state
    # instead of crashing the frame or treating a partial operation as success.
    for failure_flag in ("retry_throw", "retry_invalid"):
        globals_.view._starting_profile_equipped_items.slot_primary = globals_.old_weapon
        globals_.view._starting_profile_equipped_items.slot_trinket_1 = globals_.old_curio
        globals_.retry_results = lua.table_from([])
        globals_.retry_calls = 0
        globals_.native_promise = globals_.TestPromise.pending()
        setattr(globals_, failure_flag, True)
        module.persist_local_changes(globals_.test_mod, globals_.native_equip, globals_.view)
        globals_.native_promise.resolve(globals_.native_promise, lua.table_from([False]))
        module.update(globals_.test_mod, 1.5)
        assert module.status() == ("waiting_retry", 1)
        assert globals_.view._starting_profile_equipped_items.slot_primary.gear_id == "old-weapon"
        setattr(globals_, failure_flag, False)
        module.update(globals_.test_mod, 1.5)
        assert module.status() == ("idle", 0)
        assert globals_.view._starting_profile_equipped_items.slot_primary.gear_id == "new-weapon"

    # A pending backend operation keeps its immutable intent but must release a
    # closed Character Overview view immediately. Late settlement then becomes
    # UI-cache-neutral while still completing the backend state machine.
    globals_.view._starting_profile_equipped_items.slot_primary = globals_.old_weapon
    globals_.native_promise = globals_.TestPromise.pending()
    module.persist_local_changes(globals_.test_mod, globals_.native_equip, globals_.view)
    assert module.on_view_closed(globals_.view) is True
    assert module.on_view_closed(globals_.view) is False
    globals_.native_promise.resolve(globals_.native_promise, lua.table_from([True]))
    assert module.status() == ("idle", 0)
    assert globals_.view._starting_profile_equipped_items.slot_primary.gear_id == "old-weapon"

    globals_.native_promise = globals_.TestPromise.pending()
    module.persist_local_changes(globals_.test_mod, globals_.native_equip, globals_.view)
    reset_operation = module._test.active_operation()
    assert module.has_pending() is True
    module.reset()
    assert module.has_pending() is False
    assert reset_operation.retired is True
    assert reset_operation.intent is None
    assert reset_operation.promise is None
    assert reset_operation.view is None
    globals_.native_promise.resolve(globals_.native_promise, lua.table_from([False]))
    assert module.status() == ("idle", 0)

    # Superseding a still-pending write must likewise detach the old callback's
    # operation shell from its captured inventory graph.
    globals_.native_promise = globals_.TestPromise.pending()
    first_promise = globals_.native_promise
    module.persist_local_changes(globals_.test_mod, globals_.native_equip, globals_.view)
    superseded_operation = module._test.active_operation()
    globals_.native_promise = globals_.TestPromise.pending()
    module.persist_local_changes(globals_.test_mod, globals_.native_equip, globals_.view)
    assert superseded_operation.retired is True
    assert superseded_operation.intent is None
    assert superseded_operation.promise is None
    assert superseded_operation.view is None
    first_promise.resolve(first_promise, lua.table_from([True]))
    assert module.has_pending() is True
    module.reset()

    # A backend promise that never settles cannot retain the immutable intent
    # graph forever. Timeout is fail-closed: retire local ownership and never
    # dispatch an ambiguous duplicate equip request.
    globals_.captured_errors = lua.table_from([])
    globals_.native_promise = globals_.TestPromise.pending()
    retries_before_timeout = globals_.retry_calls
    module.persist_local_changes(globals_.test_mod, globals_.native_equip, globals_.view)
    timeout_operation = module._test.active_operation()
    module.update(globals_.test_mod, 119.9)
    assert module.has_pending() is True
    module.update(globals_.test_mod, 0.1)
    assert module.has_pending() is False
    assert globals_.retry_calls == retries_before_timeout
    assert len(globals_.captured_errors) == 1
    assert timeout_operation.retired is True
    assert timeout_operation.intent is None
    assert timeout_operation.promise is None
    assert timeout_operation.view is None
    globals_.native_promise.resolve(globals_.native_promise, lua.table_from([True]))
    assert module.status() == ("idle", 0)

    print("BetterInventory equipment persistence tests passed.")


if __name__ == "__main__":
    main()
