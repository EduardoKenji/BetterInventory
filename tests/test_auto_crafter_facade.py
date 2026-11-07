from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
FACADE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_auto_crafter.lua"
)


def main() -> None:
    source = FACADE_PATH.read_text(encoding="utf-8")

    # Per-frame UI failures detach only the panel; controller failures stop the
    # workflow and cannot escape through mod.update into Darktide's frame loop.
    assert "pcall(active_panel.update, active_panel, dt)" in source
    assert 'pcall(controller.update, controller, dt)' in source
    assert 'pcall(controller.on_context_exit, controller, "controller_update_crash")' in source
    assert "controller_faulted = true" in source
    assert "pcall(rebuild_hud_lines, snapshot)" in source
    assert "pcall(panel.sync_controller_snapshot, panel, snapshot)" in source
    assert "function AutoCrafter.interrupt_for_external_mutation(kind)" in source
    assert "snapshot.operation_inflight or snapshot.operation_quarantined" in source
    assert "queue_owned = queue_state and queue_state.job_count > 0" in source
    assert "games_lantern_queue:is_settling()" in source
    assert "local controller_busy = controller and controller:is_busy() or false" in source
    assert "pcall(games_lantern_queue.clear, games_lantern_queue)" in source
    assert 'pcall(games_lantern_import.cancel, games_lantern_import, "shutdown")' in source
    assert "if view and active_brunt_view ~= view then" in source
    assert "active_brunt_view = nil" in source
    assert "local configured_dependencies" in source
    assert "function AutoCrafter.ensure_configured()" in source
    assert "return controller ~= nil or AutoCrafter.configure()" in source
    assert "local function publish_hud_lines(lines)" in source
    assert "function AutoCrafter.hud_presentation()" in source
    assert 'table.concat(lines, "\\n")' in source
    assert "HudPolicy.presentation_needs_update" in source
    assert "HudPolicy.advance_completion_elapsed" in source
    assert '"Verifying final crafted weapon"' in source
    assert '"Applying selected weapon mark"' in source

    # Controller-detected Psych Ward context loss must also stop and settle the
    # host-owned imported queue after any late backend response becomes inert.
    assert 'kind == "context_exit" or kind == "phase4_complete"' in source
    assert 'games_lantern_queue:stop_requested()' in source
    assert '"stop_settled", { reason = "context_exit_settled" }' in source
    assert "games_lantern_queue:stop_requested() and not (busy_ok and busy)" in source
    assert "local controller_snapshot = controller:snapshot()" not in source

    # Staged Games Lantern planner selection mirrors Brunt's native weapon
    # preview through a bounded deferred-tab coordinator. It is cancelled at
    # crafting/lifecycle boundaries and owns no queue execution cursor.
    assert 'games_lantern/selection_coordinator' in source
    assert "games_lantern_selection.capture_original" in source
    assert '"queue_installed"' in source
    assert '"queue_card_selected"' in source
    assert "games_lantern_selection.restore" in source
    assert "games_lantern_selection.cancel_pending" in source
    assert "games_lantern_selection.abandon" in source
    assert "games_lantern_selection, active_brunt_view, dt" in source
    assert 'log("info", string.format(' in source
    assert "Brunt preview synchronization is presentation-only" in source
    assert "Games Lantern Brunt preview selection" in source
    assert "timeout=%s" in source

    # Unknown Games Lantern marks must surface their automatic native fallback.
    assert 'kind == "import_staged"' in source
    assert "job.mark_fallback" in source
    assert "could not be identified. Using fallback mark" in source
    assert "Incompatible profile fields were replaced with valid native choices" in source
    assert 'notify(localize("auto_crafter_notification_title", "Auto Crafter Helper"), message, true)' in source

    # Import waits for one coherent native-layout/backend snapshot and checks
    # staged offer IDs again before acquiring mutation ownership.
    assert "native_store_ready = native_store_ready" in source
    assert 'native_store_reason = type(layout) ~= "table"' in source
    assert "games_lantern_import:is_busy()" in source
    assert "Brunt's Armoury changed after this build was imported" in source

    # DMF log methods pass their first payload through string.format. Imported
    # perk/blessing labels contain literal percent signs, so runtime text must
    # always be supplied as a value for a constant format string.
    assert 'pcall(logger, mod, "%s", tostring(message))' in source

    # A controller crash must not leave the imported queue "stopping" forever:
    # is_busy() would stay true and AccountMutationGuard would refuse every
    # native purchase/craft/delete/favorite for the rest of the session.
    lua = LuaRuntime(unpack_returned_tuples=True)
    facade = lua.execute(source, name=str(FACADE_PATH))
    lua.execute(
        r'''
        local facade = ...
        local function upvalue(name, value)
            local index = 1
            while true do
                local found, current = debug.getupvalue(facade.update, index)
                if not found then error("missing upvalue " .. name) end
                if found == name then
                    if value ~= nil then debug.setupvalue(facade.update, index, value) end
                    return current
                end
                index = index + 1
            end
        end
        local function fake_queue(state)
            local queue = {state_value = state, stop_wanted = true, events = {}}
            function queue:state() return self.state_value end
            function queue:is_settling() return self.state_value == "stopping" or self.state_value == "quarantined" end
            function queue:is_pre_dispatch() return false end
            function queue:is_busy() return self.state_value ~= "stopped" end
            function queue:stop_requested() return self.stop_wanted end
            function queue:on_event(kind)
                self.events[#self.events + 1] = kind
                if kind == "stop_settled" then self.state_value = "stopped" end
            end
            return queue
        end
        local function fake_controller(busy)
            local controller = {busy = busy}
            function controller:update() error("boom") end
            function controller:on_context_exit() end
            function controller:is_busy() return self.busy end
            return controller
        end

        local queue = fake_queue("running")
        local controller = fake_controller(false)
        upvalue("controller", controller)
        upvalue("games_lantern_queue", queue)
        facade.update(0.1)
        assert(upvalue("controller_faulted") == true, "controller crash must fault the facade")
        local hud = facade.hud_presentation()
        assert(string.find(hud, "controller update failed", 1, true), "crash must reach the HUD")

        -- Queue entered stopping via the controller context_exit report.
        queue.state_value = "stopping"
        controller.busy = true
        facade.update(0.1)
        assert(queue.state_value == "stopping" and #queue.events == 0, "in-flight work must keep the lock held")
        assert(facade.is_busy() == true)
        controller.busy = false
        facade.update(0.1)
        assert(queue.state_value == "stopped", "faulted controller must still settle a stopping queue")
        assert(facade.is_busy() == false)

        -- A dead controller whose is_busy() errors cannot hold work.
        queue = fake_queue("stopping")
        upvalue("games_lantern_queue", queue)
        controller.is_busy = function() error("dead") end
        facade.update(0.1)
        assert(queue.state_value == "stopped")
        ''',
        facade,
    )

    # Games Lantern paste over an existing queue: the Paste button and Ctrl+V
    # are the explicit replacement action (a completed queue is replaceable
    # too), and an import the Auto Crafter would reject must be refused before
    # the existing queue is cleared.
    paste_lua = LuaRuntime(unpack_returned_tuples=True)
    paste_facade = paste_lua.execute(source, name=str(FACADE_PATH))
    paste_lua.execute(
        r'''
        local facade = ...
        local ok_fn = function() return true end
        local calls, queue_state, controller_busy = {}, "complete", false
        local fake_queue = {
            snapshot = function() return {job_count = 1, state = queue_state} end,
            state = function() return queue_state end,
            is_busy = function() return false end,
            clear = function() calls[#calls + 1] = "queue_clear"; return true end,
        }
        local fake_import = {
            clipboard_matches_current = function() return false end,
            clear = function() calls[#calls + 1] = "import_clear" end,
            paste = function() calls[#calls + 1] = "import_paste"; return true end,
            state = function() return "idle" end,
        }
        local fake_controller = {
            snapshot = function() return {operation_inflight = controller_busy} end,
            clear_imported_job = function() calls[#calls + 1] = "controller_clear" end,
        }
        local panel_dependencies
        local modules = {
            ["auto_crafter/core/controller"] = {configure = ok_fn, new = function() return fake_controller end},
            ["auto_crafter/core/hud_policy"] = {presentation_needs_update = ok_fn},
            ["auto_crafter/core/planner"] = {build = ok_fn},
            ["auto_crafter/darktide/backend"] = {new = function() return {} end},
            ["auto_crafter/darktide/context"] = {new = function() return {} end},
            ["auto_crafter/games_lantern/queue"] = {new = function() return fake_queue end},
            ["auto_crafter/games_lantern/clipboard"] = {extract_url = ok_fn},
            ["auto_crafter/games_lantern/clipboard_host"] = {read = ok_fn},
            ["auto_crafter/games_lantern/parser"] = {parse = ok_fn},
            ["auto_crafter/games_lantern/resolver"] = {resolve_identities = ok_fn, attach_catalogs = ok_fn},
            ["auto_crafter/games_lantern/transport"] = {new = function() return {} end},
            ["auto_crafter/games_lantern/transport_win"] = {spawn = ok_fn},
            ["auto_crafter/games_lantern/transport_wine"] = {spawn = ok_fn},
            ["auto_crafter/games_lantern/import_controller"] = {new = function() return fake_import end},
            ["auto_crafter/darktide/panel"] = {
                configure = ok_fn,
                new = function(dependencies) panel_dependencies = dependencies; return {} end,
            },
            ["auto_crafter/darktide/viewport_layout"] = {panel_pivot = ok_fn},
        }
        local mod = {
            io_dofile = function(_, path)
                for name, module in pairs(modules) do
                    if string.sub(path, -#name) == name then return module end
                end
                return false
            end,
            get = function() end,
            info = function() end,
            error = function() end,
            localize = function(_, id) return id end,
        }
        assert(facade.configure({mod = mod}) == true, "stubbed Auto Crafter must configure")
        assert(panel_dependencies, "panel must be constructed")
        local paste = panel_dependencies.games_lantern_paste

        -- Completed queue + Ctrl+V: replaced, not silently refused.
        assert(paste() == true)
        assert(table.concat(calls, ",") == "queue_clear,controller_clear,import_clear,import_paste", table.concat(calls, ","))

        -- Rejected import: the existing queue survives untouched.
        calls, controller_busy = {}, true
        local pasted, reason = paste()
        assert(pasted == false and reason == "auto_crafter_busy", tostring(reason))
        assert(#calls == 0, "a rejected import must not clear the queue")
        ''',
        paste_facade,
    )

    print("Auto Crafter facade crash-containment checks passed.")


if __name__ == "__main__":
    main()
