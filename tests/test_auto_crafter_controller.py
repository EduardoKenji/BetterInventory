from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
CONTROLLER_PATH = RUNTIME_ROOT / "auto_crafter" / "core" / "controller.lua"
PLANNER_PATH = RUNTIME_ROOT / "auto_crafter" / "core" / "planner.lua"


def main() -> None:
    controller_source = CONTROLLER_PATH.read_text(encoding="utf-8")
    update_source = controller_source.split("\tfunction self:update(dt)", 1)[1].split("\tfunction self:snapshot()", 1)[0]
    assert "local update_dt = finite_dt(dt)" in update_source
    assert update_source.count("finite_dt(dt)") == 1
    assert "local current_config = planner_config()" not in update_source

    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        package.preload["scripts/foundation/utilities/promise"] = function() return {} end

        function resolved(value)
            local promise = {value = value}

            function promise:next(callback)
                local ok, result = pcall(callback, self.value)

                if not ok then
                    return rejected(result)
                end

                if type(result) == "table" and type(result.next) == "function" then
                    return result
                end

                return resolved(result)
            end

            function promise:catch(_)
                return self
            end

            return promise
        end

        function rejected(error_value)
            local promise = {error_value = error_value}

            function promise:next(_)
                return self
            end

            function promise:catch(callback)
                return resolved(callback(self.error_value))
            end

            return promise
        end

        function pending()
            local promise = {}

            function promise:next(callback)
                self.next_callback = callback
                return self
            end

            function promise:catch(callback)
                self.catch_callback = callback
                return self
            end

            return promise
        end

        function base_settings(overrides)
            local values = {
                auto_crafter_enable = true,
                auto_crafter_buy_until_target = true,
                auto_crafter_target_dump_stat = "damage_stat",
                auto_crafter_dump_stat_target = 60,
				auto_crafter_dump_stat_comparison = "exact",
                auto_crafter_cap_by_dockets = false,
                auto_crafter_cap_by_max_purchases = true,
                auto_crafter_max_purchases = 1,
                auto_crafter_best_candidate_fallback = false,
				auto_crafter_defer_bad_weapon_processing = false,
				auto_crafter_favorite_result = false,
                auto_crafter_level_mastery_20 = false,
                auto_crafter_request_mode = "sequential",
				auto_crafter_reuse_inventory_base = false,
				auto_crafter_consecrate_transcendent = false,
				auto_crafter_upgrade_expertise_500 = false,
				auto_crafter_allocate_mastery_points = false, auto_crafter_change_perks = false,
				auto_crafter_change_blessings = false,
            }

            for key, value in pairs(overrides or {}) do
                values[key] = value
            end

            return {
                values = values,
                get = function(self, key) return self.values[key] end,
                set = function(self, key, value)
                    self.values[key] = value

                    if self.switch_offer_on_set then
                        CurrentOffer = self.switch_offer_on_set
                        self.switch_offer_on_set = nil
                    end

                    return true
                end,
            }
        end

        function target_offer()
            return {
                offer_id = "offer-1",
                master_id = "weapon-1",
                parent_pattern = "pattern-1",
                display_name = "Test Weapon",
                price_amount = 100,
                price_type = "credits",
                base_stats = {
                    {name = "damage_stat", display_name_key = "loc_stats_display_damage_stat"},
                    {name = "mobility_stat", display_name_key = "loc_stats_display_mobility_stat"},
                },
            }
        end

        function raw_offer(master_id)
            return {offerId = "offer-1", masterId = master_id or "weapon-1"}
        end

        function snapshot_with(item)
            local items = {}

            if item then
                items[1] = item
            end

            return {
				character_id = "character-1",
                store = {available = true, offer_count = 1, offers = {target_offer()}},
                wallets = {currencies = {credits = {amount = 10000}}},
                gear = {available = true, item_count = #items, items = items},
            }
        end

		function snapshot_with_items(items)
			items = items or {}

			return {
				character_id = "character-1",
				store = {available = true, offer_count = 1, offers = {target_offer()}},
				wallets = {currencies = {credits = {amount = 10000}}},
				gear = {available = true, item_count = #items, items = items},
			}
		end

        function summarized_item(gear_id, rarity, dump_stat)
            return {
                available = true,
                gear_id = gear_id,
                rarity = rarity,
				master_id = "weapon-1",
                mastery_id = "pattern-1",
                parent_pattern = "pattern-1",
                base_stats = {damage_stat = dump_stat or 50},
                damage = dump_stat or 50,
				expertise_level = 320,
				potential_base_stats = {damage_stat = dump_stat or 50},
				potential_damage = dump_stat or 50,
                display_name = "Test Weapon",
            }
        end

        function context()
            return {
				current_character_id = function() return "character-1" end,
                is_valid_brunt_view = function() return true end,
                is_runtime_valid = function() return true end,
            }
        end

        function reports()
            return {
                events = {},
                emit = function(self, kind, payload)
                    self.events[#self.events + 1] = {kind = kind, payload = payload}
                end,
            }
        end
        '''
    )
    planner = lua.execute(
        PLANNER_PATH.read_text(encoding="utf-8"), name=str(PLANNER_PATH)
    )
    controller_module = __import__("auto_crafter_test_support").load_controller(lua)
    lua.globals().Planner = planner
    lua.globals().Controller = controller_module
    lua.execute(
        r'''
        -- Phase 2 must capture mastery before sacrifice, claim from that baseline,
        -- verify deletion, and converge against baseline + awarded XP exactly once.
		do
            local state = {item = summarized_item("gear-1", 1, 50), extracted = false, claimed = false, baseline_reads = 0}
            local backend = {extract_calls = 0, claim_calls = 0, upgrade_calls = 0}

            function backend:probe_snapshot()
                if state.extracted then
                    return resolved(snapshot_with(nil))
                end

                return resolved(snapshot_with(state.item))
            end

            function backend:get_mastery_by_pattern(_)
                if state.claimed then
                    return resolved({mastery_id = "pattern-1", current_xp = 160, mastery_level = 6, claimed_level = 5, mastery_max_level = 20})
                end

                state.baseline_reads = state.baseline_reads + 1
                local current_xp = state.baseline_reads == 1 and 100 or 110

                return resolved({mastery_id = "pattern-1", current_xp = current_xp, mastery_level = 5, claimed_level = 4, mastery_max_level = 20})
            end

            function backend:extract_weapon_mastery(_, gear_ids)
                self.extract_calls = self.extract_calls + 1
                assert(gear_ids[1] == "gear-1")
                state.extracted = true
                return resolved({amount = 50, gear_ids = {"gear-1"}})
            end

            function backend:claim_mastery_levels(before, amount)
                self.claim_calls = self.claim_calls + 1
                self.claim_before_xp = before.current_xp
                self.claim_added_xp = amount
                state.claimed = true
                return resolved({claimed_level = 5})
            end

            function backend:upgrade_weapon_rarity(_)
                self.upgrade_calls = self.upgrade_calls + 1
                state.item.rarity = 2
                return resolved({})
            end

            local settings = base_settings()
            local reporter = reports()
            CurrentOffer = raw_offer()
            local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = settings, reporter = reporter, get_selected_offer = function() return CurrentOffer end})
            controller._snapshot = snapshot_with(state.item)
            controller._active_view = {}
            controller._view_is_valid = true

            assert(controller:start_mastery_operation(state.item) == true)
            assert(backend.extract_calls == 1, "extract calls " .. tostring(backend.extract_calls))
            assert(backend.claim_calls == 1, "claim calls " .. tostring(backend.claim_calls) .. " phase " .. tostring(controller:snapshot().phase) .. " error " .. tostring(controller:snapshot().last_error))
            assert(backend.upgrade_calls == 1)
            assert(state.baseline_reads == 2)
            assert(backend.claim_before_xp == 110)
            assert(backend.claim_added_xp == 50)
            assert(controller:snapshot().mastery.expected_xp == 160)
            controller:update(1)
            assert(controller:snapshot().phase == "mastery_complete")
			local level_events = 0
			for _, event in ipairs(reporter.events) do
				if event.kind == "mastery_level_increased" then
					level_events = level_events + 1
					assert(event.payload.previous_level == 5)
					assert(event.payload.current.mastery_level == 6)
				end
			end
			assert(level_events == 1)
        end

		-- Phase 3 uses the confirmed extraction award to advance a local mastery
		-- projection immediately. It must not perform a gear refresh, claim, or
		-- mastery poll for every fodder weapon.
		do
			local item = summarized_item("gear-fast-fodder", 2, 50)
			local baseline = {mastery_id = "pattern-1", current_xp = 100, mastery_level = 5, claimed_level = 4, mastery_max_level = 20}
			local backend = {extract_calls = 0, probe_calls = 0}
			function backend:probe_snapshot() self.probe_calls = self.probe_calls + 1 return resolved(snapshot_with(nil)) end
			function backend:extract_weapon_mastery(_, gear_ids)
				self.extract_calls = self.extract_calls + 1
				return resolved({amount = 50, gear_ids = {gear_ids[1]}})
			end
			function backend:project_mastery(data, amount)
				return {mastery_id = data.mastery_id, current_xp = data.current_xp + amount, mastery_level = 6, claimed_level = data.claimed_level, mastery_max_level = 20}
			end

			local completed
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings({auto_crafter_level_mastery_20 = true}), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with(item)
			controller._phase3 = {running = true, current_data = baseline}
			controller._mastery = {
				before = {current_xp = 100, mastery_level = 5},
				before_data = baseline,
				gear_id = item.gear_id,
				mastery_id = "pattern-1",
				on_complete = function(current) completed = current end,
				phase3 = true,
				running = true,
			}
			assert(controller:_mastery_extract(0) == true)
			assert(backend.extract_calls == 1)
			assert(backend.probe_calls == 0)
			assert(completed and completed.mastery_level == 6)
			assert(controller:snapshot().phase3.projected_xp_pending == true)
			assert(#controller:snapshot().data.gear.items == 0)
		end

		-- Near level 20, queued XP selects only the minimal fodder prefix and
		-- discards every run-owned spare that survives extraction.
		do
			local target = summarized_item("gear-batch-target", 2, 60)
			local miss_a = summarized_item("gear-batch-a", 0, 55)
			local miss_b = summarized_item("gear-batch-b", 1, 56)
			local miss_c = summarized_item("gear-batch-c", 0, 57)
			miss_a.expertise_level = 40
			miss_b.expertise_level = 40
			miss_c.expertise_level = 40
			local state = {items = {target, miss_a, miss_b, miss_c}, claimed = false}
			local backend = {batch_upgrade_calls = 0, discard_calls = 0, extract_calls = 0, upgrade_calls = 0}
			function backend:probe_snapshot()
				local snapshot = snapshot_with_items(state.items)
				snapshot.crafting_costs = {sacrifice_mastery = {sacrifice_muiltiplier = 1, minimumExpertiseLevel = 0, baseReward = 0, masteryXpPerExpertiseLevel = 10}}
				return resolved(snapshot)
			end
			function backend:upgrade_weapon_rarities(gear_ids)
				self.batch_upgrade_calls = self.batch_upgrade_calls + 1
				assert(#gear_ids == 1 and gear_ids[1] == miss_a.gear_id)
				return resolved({count = #gear_ids})
			end
			function backend:upgrade_weapon_rarity(gear_id)
				self.upgrade_calls = self.upgrade_calls + 1
				return resolved({gear_id = gear_id})
			end
			function backend:extract_weapon_mastery(_, gear_ids)
				self.extract_calls = self.extract_calls + 1
				assert(#gear_ids == 1 and gear_ids[1] == miss_a.gear_id)
				state.items = {target, miss_b, miss_c}
				return resolved({amount = 50, gear_ids = {gear_ids[1]}})
			end
			function backend:project_mastery(data, amount)
				return {mastery_id = data.mastery_id, current_xp = data.current_xp + amount, mastery_level = 20, claimed_level = 18, mastery_max_level = 20, milestones = data.milestones}
			end
			function backend:claim_mastery_levels(_, _)
				state.claimed = true
				return resolved({mastery_id = "pattern-1", current_xp = 150, mastery_level = 20, claimed_level = 19, mastery_max_level = 20})
			end
			function backend:discard_items(gear_ids)
				self.discard_calls = self.discard_calls + 1
				assert(#gear_ids == 2 and gear_ids[1] == miss_b.gear_id and gear_ids[2] == miss_c.gear_id)
				state.items = {target}
				return resolved({})
			end

			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings({auto_crafter_level_mastery_20 = true, auto_crafter_defer_bad_weapon_processing = true}), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = backend:probe_snapshot().value
			controller._search = {dump_stat = "damage_stat", running = true, target_dump = 60}
			controller._phase3 = {
				current = {mastery_id = "pattern-1", current_xp = 100, mastery_level = 19, claimed_level = 18, mastery_max_level = 20},
				current_data = {mastery_id = "pattern-1", current_xp = 100, mastery_level = 19, claimed_level = 18, mastery_max_level = 20, milestones = {{level = 20, xpLimit = 150}}},
				defer_bad_processing = true,
				deferred_candidates = {miss_a, miss_b, miss_c},
				deferred_index = 1,
				fodder_count = 0,
				running = true,
				target_candidate = target,
			}
			assert(controller:_phase3_process_deferred(0, controller._phase3.current) == true)
			assert(backend.batch_upgrade_calls == 1)
			assert(backend.upgrade_calls == 0)
			assert(backend.extract_calls == 1)
			assert(backend.discard_calls == 1)
			assert(controller:snapshot().phase3.fodder_count == 1)
			assert(controller:snapshot().search.result.gear_id == target.gear_id)
			assert(#state.items == 1 and state.items[1].gear_id == target.gear_id)
		end

		-- Post-target purchases remain wallet-ordered after a Damage 80 target has
		-- consumed the acquisition cap. Extraction waits for every upgrade/read.
		do
			local target = summarized_item("gear-pipeline-target", 2, 80)
			local fodder_a = summarized_item("gear-pipeline-a", 0, 55)
			local fodder_b = summarized_item("gear-pipeline-b", 0, 56)
			local purchase_promises = {pending(), pending()}
			local upgrade_promises = {pending(), pending()}
			local state = {items = {target, fodder_a, fodder_b}}
			local backend = {extract_calls = 0, probe_calls = 0, purchase_calls = 0, upgrade_calls = 0}
			function backend:purchase_offer(_)
				self.purchase_calls = self.purchase_calls + 1
				return purchase_promises[self.purchase_calls]
			end
			function backend:upgrade_weapon_rarity(_)
				self.upgrade_calls = self.upgrade_calls + 1
				return upgrade_promises[self.upgrade_calls]
			end
			function backend:probe_snapshot()
				self.probe_calls = self.probe_calls + 1
				local snapshot = snapshot_with_items(state.items)
				snapshot.crafting_costs = {sacrifice_mastery = {sacrifice_muiltiplier = 1, minimumExpertiseLevel = 0, baseReward = 0, masteryXpPerExpertiseLevel = 10}}
				return resolved(snapshot)
			end
			function backend:extract_weapon_mastery(_, gear_ids)
				self.extract_calls = self.extract_calls + 1
				assert(#gear_ids == 2)
				state.items = {target}
				return resolved({amount = 660, gear_ids = gear_ids})
			end
			function backend:project_mastery(data, amount)
				return {mastery_id = data.mastery_id, current_xp = data.current_xp + amount, mastery_level = 20, claimed_level = 18, mastery_max_level = 20, milestones = data.milestones}
			end
			function backend:claim_mastery_levels(_, _)
				return resolved({mastery_id = "pattern-1", current_xp = 660, mastery_level = 20, claimed_level = 19, mastery_max_level = 20})
			end

			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings({auto_crafter_level_mastery_20 = true, auto_crafter_defer_bad_weapon_processing = true, auto_crafter_max_purchases = 1}), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = backend:probe_snapshot().value
			backend.probe_calls = 0
			controller._search = {cap_by_dockets = false, cap_by_max_purchases = true, dump_stat = "damage_stat", max_purchases = 1, purchases = 1, raw_offer = raw_offer(), running = true, spent = 100, target_dump = 80, target_offer = target_offer()}
			controller._phase3 = {current = {mastery_id = "pattern-1", current_xp = 0, mastery_level = 19, claimed_level = 18, mastery_max_level = 20}, current_data = {mastery_id = "pattern-1", current_xp = 0, mastery_level = 19, claimed_level = 18, mastery_max_level = 20, milestones = {{level = 20, xpLimit = 660}}}, defer_bad_processing = true, deferred_candidates = {}, deferred_index = 1, fodder_count = 0, running = true, target_candidate = target}

			assert(controller:_purchase_search_step(0) == true)
			purchase_promises[1].next_callback({items = {fodder_a}})
			assert(backend.purchase_calls == 2 and backend.upgrade_calls == 1)
			assert(controller:snapshot().operation_kind == "purchase")
			purchase_promises[2].next_callback({items = {fodder_b}})
			assert(backend.upgrade_calls == 1 and backend.probe_calls == 0 and backend.extract_calls == 0)
			upgrade_promises[1].next_callback({gear_id = fodder_a.gear_id})
			assert(backend.upgrade_calls == 2 and backend.probe_calls == 0 and backend.extract_calls == 0)
			upgrade_promises[2].next_callback({gear_id = fodder_b.gear_id})
			assert(backend.probe_calls >= 1 and backend.extract_calls == 1)
			assert(controller:snapshot().operation_timings.phase3_fast_upgrade.count == 2)
		end

		-- Final projected claim result is authoritative. Completing directly avoids
		-- an unnecessary poll and cannot leave Phase 3 parked at visible 20/20.
		do
			local target = summarized_item("gear-direct-claim", 2, 60)
			target.dump_stat = 60
			local projected = {mastery_id = "pattern-1", current_xp = 500, mastery_level = 20, claimed_level = 18, mastery_max_level = 20}
			local backend = {claim_calls = 0, mastery_reads = 0}
			function backend:claim_mastery_levels(_, _)
				self.claim_calls = self.claim_calls + 1
				return resolved({mastery_id = "pattern-1", current_xp = 500, mastery_level = 20, claimed_level = 19, mastery_max_level = 20})
			end
			function backend:get_mastery_by_pattern(_)
				self.mastery_reads = self.mastery_reads + 1
				return resolved({})
			end

			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings({auto_crafter_level_mastery_20 = true}), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with(target)
			controller._search = {dump_stat = "damage_stat", running = true, target_dump = 60}
			controller._phase3 = {
				authoritative_current = {mastery_id = "pattern-1", current_xp = 100, mastery_level = 5, claimed_level = 4, mastery_max_level = 20},
				current = projected,
				current_data = projected,
				defer_bad_processing = false,
				deferred_candidates = {},
				deferred_index = 1,
				fodder_count = 2,
				projected_xp_pending = true,
				running = true,
				target_candidate = target,
			}
			assert(controller:_phase3_sync_projected(0) == true)
			assert(backend.claim_calls == 1 and backend.mastery_reads == 0)
			assert(controller:snapshot().phase == "phase4_complete", tostring(controller:snapshot().phase) .. " " .. tostring(controller:snapshot().last_error))
			assert(controller:snapshot().last_error == nil)
		end

		-- Swallowed/stale claim result retries from authoritative mastery data. Two
		-- bounded retries then become a visible operation failure, never silent stop.
		do
			local backend = {claim_calls = 0, mastery_reads = 0}
			function backend:get_mastery_by_pattern(_)
				self.mastery_reads = self.mastery_reads + 1
				return resolved({mastery_id = "pattern-1", current_xp = 500, mastery_level = 20, claimed_level = 18, mastery_max_level = 20})
			end
			function backend:claim_mastery_levels(_, _)
				self.claim_calls = self.claim_calls + 1
				return resolved(nil)
			end

			local reporter = reports()
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reporter, get_selected_offer = function() return CurrentOffer end})
			controller._mastery = {
				before = {current_xp = 100, mastery_level = 5},
				claim_retries = 0,
				expected_xp = 500,
				mastery_id = "pattern-1",
				running = true,
			}
			controller._phase = "mastery_sync_wait"
			controller._mastery_poll_wait = 0
			for _ = 1, 50 do controller:update(1) end
			assert(backend.claim_calls == 2)
			assert(controller:snapshot().phase == "operation_failed")
			assert(string.find(controller:snapshot().last_error, "mastery synchronization failed", 1, true) ~= nil)
			local failed = false
			for _, event in ipairs(reporter.events) do
				failed = failed or event.kind == "operation_failed"
			end
			assert(failed == true)
		end

        -- Reaching mastery 20 before mutation must preserve candidate: no upgrade or sacrifice.
        do
            local item = summarized_item("gear-max", 0, 50)
            local backend = {extract_calls = 0, upgrade_calls = 0}
            function backend:probe_snapshot() return resolved(snapshot_with(item)) end
            function backend:get_mastery_by_pattern(_) return resolved({mastery_id = "pattern-1", current_xp = 999, mastery_level = 20, claimed_level = 19, mastery_max_level = 20}) end
            function backend:extract_weapon_mastery(_, _) self.extract_calls = self.extract_calls + 1 return resolved({}) end
            function backend:upgrade_weapon_rarity(_) self.upgrade_calls = self.upgrade_calls + 1 return resolved({}) end

            CurrentOffer = raw_offer()
            local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
            controller._snapshot = snapshot_with(item)
            controller._active_view = {}
            controller._view_is_valid = true
            assert(controller:start_mastery_operation(item) == true)
            assert(backend.extract_calls == 0)
            assert(backend.upgrade_calls == 0)
            assert(controller:snapshot().phase == "mastery_already_complete")
        end

        -- Selected Brunt target is frozen. A changed native selection stops before purchase POST.
        do
            local backend = {purchase_calls = 0}
            function backend:purchase_offer(_) self.purchase_calls = self.purchase_calls + 1 return resolved({}) end
			local settings = base_settings({auto_crafter_target_dump_stat = "unavailable_stat"})
            settings.switch_offer_on_set = raw_offer("weapon-2")
            CurrentOffer = raw_offer()
            local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = settings, reporter = reports(), get_selected_offer = function() return CurrentOffer end})
            controller._snapshot = snapshot_with(nil)
            controller._active_view = {}
            controller._view_is_valid = true
            local started = controller:start_purchase_search()
            assert(started == false, "mismatch start " .. tostring(started))
            assert(backend.purchase_calls == 0, "mismatch purchase calls " .. tostring(backend.purchase_calls))
			assert(controller:snapshot().phase == "idle", "mismatch phase " .. tostring(controller:snapshot().phase))
        end

		-- Closing Brunt detaches UI only; frozen search continues in Morningstar.
		do
			local state = {item = nil}
			local backend = {purchase_promise = pending(), release_calls = 0}
			function backend:purchase_offer(_) return self.purchase_promise end
			function backend:probe_snapshot() return resolved(snapshot_with(state.item)) end
			function backend:release_read_cache() self.release_calls = self.release_calls + 1 return true end
			CurrentOffer = raw_offer()
			local view = {}
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with(nil)
			controller._active_view = view
			controller._view_is_valid = true
			assert(controller:start_purchase_search() == true)
			assert(controller:on_view_closed(view) == true)
			assert(controller:snapshot().view_is_valid == false)
			assert(controller:snapshot().search.running == true)
			assert(backend.release_calls == 0)
			-- DMF/panel teardown may replay unchanged values. Same-value callbacks are noise,
			-- not user configuration changes, and must not stop frozen background work.
			assert(controller:on_setting_changed("auto_crafter_target_dump_stat") == true)
			assert(controller:on_setting_changed("auto_crafter_dump_stat_target") == true)
			assert(controller:snapshot().search.running == true)
			state.item = summarized_item("gear-background", 0, 60)
			backend.purchase_promise.next_callback({items = {state.item}})
			assert(controller:snapshot().search.running == false)
			assert(controller:snapshot().search.result.gear_id == "gear-background")
			assert(controller:snapshot().phase == "phase4_complete")
			assert(backend.release_calls == 1)
		end

		-- Purchase response cannot declare exact result; refreshed inventory is authoritative.
		do
			local authoritative = summarized_item("gear-revalidated", 0, 55)
			local backend = {favorite_calls = 0}
			function backend:purchase_offer(_) return resolved({items = {summarized_item("gear-revalidated", 0, 60)}}) end
			function backend:probe_snapshot() return resolved(snapshot_with(authoritative)) end
			function backend:favorite_item(_) self.favorite_calls = self.favorite_calls + 1 return resolved({favorited = true}) end
			local reporter = reports()
			CurrentOffer = raw_offer()
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings({auto_crafter_favorite_result = true}), reporter = reporter, get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:start_purchase_search() == true)
			assert(controller:snapshot().phase == "search_max_purchases")
			assert(controller:snapshot().search.best.dump_stat == 55)
			assert(backend.favorite_calls == 0)
			for _, event in ipairs(reporter.events) do
				assert(event.kind ~= "purchase_search_complete")
			end
		end

		-- A current stat matching 60 is not exact when its level-500 potential is 80.
		do
			local authoritative = summarized_item("gear-current-only-match", 0, 60)
			authoritative.potential_base_stats = {damage_stat = 80}
			local backend = {favorite_calls = 0}
			function backend:purchase_offer(_) return resolved({items = {authoritative}}) end
			function backend:probe_snapshot() return resolved(snapshot_with(authoritative)) end
			function backend:favorite_item(_) self.favorite_calls = self.favorite_calls + 1 return resolved({favorited = true}) end
			CurrentOffer = raw_offer()
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings({auto_crafter_favorite_result = true}), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:start_purchase_search() == true)
			assert(controller:snapshot().phase == "search_max_purchases")
			assert(controller:snapshot().search.best.dump_stat == 80)
			assert(backend.favorite_calls == 0)
		end

		-- Exact authoritative candidate is favorited before completion is reported.
		do
			local authoritative = summarized_item("gear-favorite", 0, 60)
			local backend = {favorite_calls = 0}
			function backend:purchase_offer(_) return resolved({items = {authoritative}}) end
			function backend:probe_snapshot() return resolved(snapshot_with(authoritative)) end
			function backend:favorite_item(gear_id)
				assert(gear_id == "gear-favorite")
				self.favorite_calls = self.favorite_calls + 1
				return resolved({favorited = true})
			end
			local reporter = reports()
			CurrentOffer = raw_offer()
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings({auto_crafter_favorite_result = true}), reporter = reporter, get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:start_purchase_search() == true)
			assert(backend.favorite_calls == 1)
			assert(controller:snapshot().search.result.gear_id == "gear-favorite")
			assert(reporter.events[#reporter.events - 2].kind == "candidate_favorited")
			assert(reporter.events[#reporter.events - 1].kind == "purchase_search_complete")
			assert(reporter.events[#reporter.events].kind == "phase4_complete")
		end

		-- Deferred processing leaves misses untouched until exact target exists,
		-- then discards all leftovers when mastery is already 20.
		do
			local state = {items = {}}
			local backend = {discard_calls = 0, extract_calls = 0, purchase_calls = 0}
			function backend:purchase_offer(_)
				self.purchase_calls = self.purchase_calls + 1
				local item = summarized_item(self.purchase_calls == 1 and "gear-deferred" or "gear-exact", 2, self.purchase_calls == 1 and 55 or 60)
				state.items[#state.items + 1] = item

				return resolved({items = {item}})
			end
			function backend:probe_snapshot() return resolved(snapshot_with_items(state.items)) end
			function backend:get_mastery_by_pattern(_) return resolved({mastery_id = "pattern-1", current_xp = 999, mastery_level = 20, claimed_level = 19, mastery_max_level = 20}) end
			function backend:extract_weapon_mastery(_, _) self.extract_calls = self.extract_calls + 1 return resolved({}) end
			function backend:discard_items(gear_ids)
				assert(self.purchase_calls == 2)
				assert(#gear_ids == 1 and gear_ids[1] == "gear-deferred")
				self.discard_calls = self.discard_calls + 1
				state.items = {state.items[2]}

				return resolved({})
			end
			local settings = base_settings({auto_crafter_level_mastery_20 = true, auto_crafter_defer_bad_weapon_processing = true, auto_crafter_max_purchases = 3})
			CurrentOffer = raw_offer()
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = settings, reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with_items(state.items)
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:start_purchase_search() == true)
			assert(backend.purchase_calls == 2)
			assert(backend.extract_calls == 0)
			assert(backend.discard_calls == 1)
			assert(controller:snapshot().phase == "phase4_complete")
			assert(controller:snapshot().search.result.gear_id == "gear-exact")
			assert(#state.items == 1 and state.items[1].gear_id == "gear-exact")
		end

		-- Acquisition cap before exact target preserves every deferred miss.
		do
			local state = {item = nil}
			local backend = {discard_calls = 0, mastery_reads = 0}
			function backend:purchase_offer(_)
				state.item = summarized_item("gear-preserved-miss", 0, 55)

				return resolved({items = {state.item}})
			end
			function backend:probe_snapshot() return resolved(snapshot_with(state.item)) end
			function backend:get_mastery_by_pattern(_) self.mastery_reads = self.mastery_reads + 1 return resolved({}) end
			function backend:discard_items(_) self.discard_calls = self.discard_calls + 1 return resolved({}) end
			local settings = base_settings({auto_crafter_level_mastery_20 = true, auto_crafter_defer_bad_weapon_processing = true})
			CurrentOffer = raw_offer()
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = settings, reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:start_purchase_search() == true)
			assert(controller:snapshot().phase == "search_max_purchases")
			assert(controller:snapshot().phase3.deferred_candidates[1].gear_id == "gear-preserved-miss")
			assert(backend.mastery_reads == 0)
			assert(backend.discard_calls == 0)
			assert(controller:snapshot().data.gear.items[1].gear_id == "gear-preserved-miss")
		end

        -- Acquisition-cap fallback promotes the live best candidate into Phase 3
        -- and completes it instead of emitting a terminal search failure.
        do
            local state = {item = nil}
            local backend = {purchase_calls = 0, extract_calls = 0}
            function backend:purchase_offer(_)
                self.purchase_calls = self.purchase_calls + 1
                state.item = summarized_item("gear-best", 0, 55)
                return resolved({items = {state.item}})
            end
            function backend:probe_snapshot() return resolved(snapshot_with(state.item)) end
            function backend:get_mastery_by_pattern(_) return resolved({mastery_id = "pattern-1", current_xp = 100, mastery_level = 20, claimed_level = 19, mastery_max_level = 20}) end
            function backend:extract_weapon_mastery(_, _) self.extract_calls = self.extract_calls + 1 return resolved({}) end

            local settings = base_settings({auto_crafter_level_mastery_20 = true, auto_crafter_best_candidate_fallback = true, auto_crafter_defer_bad_weapon_processing = true})
            CurrentOffer = raw_offer()
            local reporter = reports()
            local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = settings, reporter = reporter, get_selected_offer = function() return CurrentOffer end})
            controller._snapshot = snapshot_with(nil)
            controller._active_view = {}
            controller._view_is_valid = true
            assert(controller:start_purchase_search() == true)
            local result = controller:snapshot()
            assert(backend.purchase_calls == 1)
            assert(backend.extract_calls == 0)
            assert(result.search.running == false)
            assert(result.search.result.gear_id == "gear-best")
            assert(result.search.fallback_accepted == true)
            assert(result.search.fallback_reason == "search_max_purchases")
            assert(result.search.fallback_target_distance == 5)
            assert(result.phase4.fallback_accepted == true)
            assert(result.phase == "phase4_complete")
            for _, event in ipairs(reporter.events) do
                assert(event.kind ~= "purchase_search_stopped")
            end
        end

		-- A safe, non-favorite exact inventory base prevents every Brunt purchase.
		do
			local item = summarized_item("gear-reused", 2, 60)
			item.favorite_known = true
			item.favorited = false
			item.expertise_level = 300
			local backend = {purchase_calls = 0}
			function backend:purchase_offer(_) self.purchase_calls = self.purchase_calls + 1 return resolved({}) end
			function backend:probe_snapshot() return resolved(snapshot_with(item)) end
			local reporter = reports()
			CurrentOffer = raw_offer()
			local settings = base_settings({auto_crafter_reuse_inventory_base = true})
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = settings, reporter = reporter, get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with(item)
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:start_purchase_search() == true)
			assert(backend.purchase_calls == 0)
			assert(controller:snapshot().search.result.gear_id == "gear-reused")
			assert(reporter.events[#reporter.events - 2].kind == "inventory_base_selected")
			assert(reporter.events[#reporter.events].kind == "phase4_complete")
		end

		-- Explicitly allowing favorites makes favorite-state availability irrelevant.
		-- Prefer a complete 80/80/.../60 profile and less remaining crafting work,
		-- rather than blindly choosing highest current expertise.
		do
			local cheap_but_incomplete = summarized_item("gear-incomplete", 0, 60)
			cheap_but_incomplete.favorite_known = true
			cheap_but_incomplete.favorited = false
			cheap_but_incomplete.expertise_level = 500
			cheap_but_incomplete.potential_base_stats = {damage_stat = 70, mobility_stat = 60}
			local resumed = summarized_item("gear-resumed", 5, 60)
			resumed.favorite_known = false
			resumed.favorited = true
			resumed.expertise_level = 400
			resumed.potential_base_stats = {damage_stat = 80, mobility_stat = 60}
			local backend = {purchase_calls = 0}
			function backend:purchase_offer(_) self.purchase_calls = self.purchase_calls + 1 return resolved({}) end
			function backend:probe_snapshot() return resolved(snapshot_with_items({cheap_but_incomplete, resumed})) end
			CurrentOffer = raw_offer()
			local settings = base_settings({
				auto_crafter_include_favorite_inventory_bases = true,
				auto_crafter_reuse_inventory_base = true,
				auto_crafter_target_dump_stat = "mobility_stat",
			})
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = settings, reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with_items({cheap_but_incomplete, resumed})
			controller._active_view = {}
			controller._view_is_valid = true
			controller:_refresh_plan("test_target_ready")
			settings.values.auto_crafter_target_dump_stat = "mobility_stat"
			assert(controller:start_purchase_search() == true)
			local result = controller:snapshot()
			assert(backend.purchase_calls == 0, "unexpected purchases " .. tostring(backend.purchase_calls) .. " phase " .. tostring(result.phase))
			assert(result.search.result and result.search.result.gear_id == "gear-resumed", "selected " .. tostring(result.search.result and result.search.result.gear_id))
			assert(controller:snapshot().search.result.resume_analysis.all_other_stats_maxed == true)
			assert(controller:snapshot().search.result.resume_analysis.remaining_steps == 0)
		end

		-- Missing parent-pattern metadata can safely fall back to matching weapon
		-- templates. Known parent-pattern mismatches still fail closed.
		do
			local item = summarized_item("gear-template-fallback", 5, 60)
			item.master_id = nil
			item.parent_pattern = nil
			item.mastery_id = nil
			item.weapon_template = "template-1"
			item.favorite_known = true
			item.favorited = false
			item.expertise_level = 500
			local snapshot = snapshot_with(item)
			snapshot.store.offers[1].parent_pattern = nil
			snapshot.store.offers[1].weapon_template = "template-1"
			local backend = {purchase_calls = 0}
			function backend:purchase_offer(_) self.purchase_calls = self.purchase_calls + 1 return resolved({}) end
			function backend:probe_snapshot() return resolved(snapshot) end
			CurrentOffer = raw_offer()
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings({auto_crafter_reuse_inventory_base = true}), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:start_purchase_search() == true)
			assert(backend.purchase_calls == 0)
			assert(controller:snapshot().search.result.gear_id == "gear-template-fallback")
			assert(controller:snapshot().search.result.resume_analysis.family_identity == "weapon_template")
		end

		-- Marks inside one mastery family are interchangeable resume bases;
		-- equipped candidates remain excluded and ties resolve deterministically.
		do
			local wrong_mark = summarized_item("gear-0-wrong-mark", 5, 60)
			wrong_mark.master_id = "weapon-2"
			wrong_mark.favorite_known = true
			wrong_mark.favorited = false
			local equipped = summarized_item("gear-0-equipped", 5, 60)
			equipped.master_id = "weapon-1"
			equipped.equipped = true
			equipped.favorite_known = true
			equipped.favorited = false
			local safe_b = summarized_item("gear-b", 5, 60)
			safe_b.master_id = "weapon-1"
			safe_b.favorite_known = true
			safe_b.favorited = false
			local safe_a = summarized_item("gear-a", 5, 60)
			safe_a.master_id = "weapon-1"
			safe_a.favorite_known = true
			safe_a.favorited = false
			local settings = base_settings({auto_crafter_reuse_inventory_base = true})
			local controller = Controller.new({backend = {}, planner = Planner, context = context(), settings = settings, reporter = reports()})
			controller._snapshot = snapshot_with_items({wrong_mark, equipped, safe_b, safe_a})
			controller._search = {dump_stat = "damage_stat", favorite_result = false, target_dump = 60, target_offer = target_offer()}
			local selected = controller:_find_inventory_base()
			assert(selected and selected.gear_id == "gear-0-wrong-mark")
			assert(selected.resume_analysis.family_identity == "mastery_family")
		end

		-- Planner mark selection only changes exact target identity. Unknown/stale marks
		-- are no-ops, while a valid mark keeps the native family offer eligible at
		-- the final mutation boundary even when its default master ID is unchanged.
		do
			local offer = target_offer()
			offer.base_stats = {
				{name = "shovel_m1_damage_stat", display_name_key = "loc_stats_display_damage_stat"},
				{name = "shovel_m1_mobility_stat", display_name_key = "loc_stats_display_mobility_stat"},
			}
			offer.marks = {
				{base_stats = {{name = "shovel_m1_damage_stat", display_name_key = "loc_stats_display_damage_stat"}, {name = "shovel_m1_mobility_stat", display_name_key = "loc_stats_display_mobility_stat"}}, master_id = "weapon-1", parent_pattern = "pattern-1", slot_type = "slot_primary", weapon_template = "template-1"},
				{base_stats = {{name = "shovel_m7_damage_stat", display_name_key = "loc_stats_display_damage_stat"}, {name = "shovel_m7_mobility_stat", display_name_key = "loc_stats_display_mobility_stat"}}, master_id = "weapon-2", parent_pattern = "pattern-1", slot_type = "slot_primary", weapon_template = "template-2"},
			}
			local snapshot = snapshot_with(nil)
			snapshot.store.offers = {offer}
			local reporter = reports()
			local backend = {purchase_calls = 0, purchase_promise = pending()}
			function backend:purchase_offer(_) self.purchase_calls = self.purchase_calls + 1 return self.purchase_promise end
			CurrentOffer = raw_offer("weapon-1")
			local settings = base_settings({auto_crafter_target_dump_stat = "shovel_m1_mobility_stat"})
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = settings, reporter = reporter, get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:_refresh_plan("initial_mark") == true)
			assert(controller:snapshot().plan.resolved_dump_stat == "shovel_m1_mobility_stat")
			assert(controller:select_manual_mark("offer-1", "missing-mark") == false)
			assert(reporter.events[#reporter.events].kind == "mark_selection_rejected")
			assert(reporter.events[#reporter.events].payload.reason == "weapon_mark_unavailable")
			assert(controller:select_manual_mark("stale-offer", "weapon-2") == false)
			assert(reporter.events[#reporter.events].payload.reason == "selected_weapon_changed")
			assert(controller:select_manual_mark("offer-1", "weapon-2") == true)
			assert(settings.values.auto_crafter_target_dump_stat == "shovel_m7_mobility_stat")
			assert(controller:snapshot().plan.resolved_dump_stat == "shovel_m7_mobility_stat")
			assert(controller:_selected_offer_summary().master_id == "weapon-2")
			assert(controller:start_purchase_search() == true)
			assert(backend.purchase_calls == 1)
			assert(controller:snapshot().search.target_offer.master_id == "weapon-2")
			assert(controller:snapshot().search.target_offer.family_mark_selection == true)
		end

		-- Phase 4 serially consecrates, advances 100-level milestones, allocates
		-- a selected blessing, replaces targets, switches an explicitly selected
		-- mark at the end, and verifies every authoritative refresh.
		do
			local item = summarized_item("gear-final", 3, 60)
			item.base_stats = {shovel_m1_defence_stat = 60}
			item.base_stat_labels = {shovel_m1_defence_stat = "loc_stats_display_defense_stat"}
			item.potential_base_stats = {shovel_m1_defence_stat = 60}
			item.favorite_known = true
			item.favorited = false
			item.expertise_level = 330
			item.perks = {{id = "old_perk", rarity = 4}, {id = "new_perk", rarity = 4}}
			item.traits = {{id = "old_blessing", rarity = 4}, {id = "keep_blessing", rarity = 4}}
			local state = {
				allocation_order = {},
				wallet = {credits = 10000, plasteel = 5000, diamantine = 1000},
				pending = nil,
				perk_order = {},
				statuses = {
					filler_blessing = {"unseen", "unseen", "unseen", "unseen"},
					new_blessing = {"unseen", "unseen", "unseen", "unseen"},
				},
			}
			local backend = {purchase_calls = 0, rarity_calls = 0, expertise_calls = 0, perk_calls = 0, blessing_calls = 0, allocation_calls = 0, mark_calls = 0}
			local function phase_snapshot(current_item)
				local snapshot = snapshot_with(current_item)
				snapshot.store.offers[1].marks = {
					{base_stats = {{name = "shovel_m1_defence_stat", display_name_key = "loc_stats_display_defense_stat"}}, master_id = "weapon-1", parent_pattern = "pattern-1", slot_type = "slot_primary", weapon_template = "template-1"},
					{base_stats = {{name = "shovel_m3_defence_stat", display_name_key = "loc_stats_display_defense_stat"}}, master_id = "weapon-2", parent_pattern = "pattern-1", slot_type = "slot_primary", weapon_template = "template-2"},
				}
				snapshot.wallets.currencies.plasteel = {amount = state.wallet.plasteel}
				snapshot.wallets.currencies.diamantine = {amount = state.wallet.diamantine}
				snapshot.wallets.currencies.credits.amount = state.wallet.credits
				return snapshot
			end
			function backend:purchase_offer(_) self.purchase_calls = self.purchase_calls + 1 state.wallet.credits = state.wallet.credits - 100 return resolved({items = {item}}) end
			function backend:probe_snapshot() return resolved(phase_snapshot(item)) end
			function backend:get_mastery_by_pattern(_) return resolved({mastery_id = "pattern-1", current_xp = 999, mastery_level = 20, claimed_level = 19, mastery_max_level = 20}) end
			function backend:upgrade_weapon_rarity(_) self.rarity_calls = self.rarity_calls + 1 state.wallet.plasteel = state.wallet.plasteel - 10 state.wallet.diamantine = state.wallet.diamantine - 2 item.rarity = item.rarity + 1 return resolved({}) end
			function backend:add_weapon_expertise(_, target) self.expertise_calls = self.expertise_calls + 1 state.wallet.plasteel = state.wallet.plasteel - 5 item.expertise_level = target return resolved({}) end
			function backend:purchase_mastery_trait(_, id, tier)
				self.allocation_calls = self.allocation_calls + 1
				state.allocation_order[#state.allocation_order + 1] = id .. ":" .. tostring(tier)
				state.pending = {id = id, reads = 0, tier = tier}
				return resolved({})
			end
			function backend:purchase_mastery_traits(_, operations)
				self.allocation_calls = self.allocation_calls + #operations

				for _, operation in ipairs(operations) do
					state.allocation_order[#state.allocation_order + 1] = operation.trait_id .. ":" .. tostring(operation.rarity)
					state.statuses[operation.trait_id][operation.rarity] = "seen"
				end

				state.pending = nil
				return resolved({count = #operations})
			end
			function backend:get_mastery_trait_costs()
				return resolved({
					tier_costs = {["1"] = 1, ["2"] = 1, ["3"] = 1, ["4"] = 1},
					tier_thresholds = {["1"] = 0, ["2"] = 2, ["3"] = 4, ["4"] = 6},
				})
			end
			function backend:get_trait_sticker_book(_)
				if state.pending then
					state.pending.reads = state.pending.reads + 1

					if state.pending.reads >= 2 then
						state.statuses[state.pending.id][state.pending.tier] = "seen"
						state.pending = nil
					end
				end

				local result = {}

				for _, id in ipairs({"filler_blessing", "new_blessing"}) do
					local tiers = {}

					for tier = 1, 4 do
						tiers[tier] = {tier = tier, status = state.statuses[id][tier]}
					end

					result[#result + 1] = {id = id, tiers = tiers}
				end

				return resolved(result)
			end
			function backend:replace_perk(_, index, id, tier) assert(item.expertise_level == 500) self.perk_calls = self.perk_calls + 1 state.perk_order[#state.perk_order + 1] = index item.perks[index] = {id = id, rarity = tier} return resolved({}) end
			function backend:replace_blessing(_, index, id, tier) assert(item.expertise_level == 500) self.blessing_calls = self.blessing_calls + 1 item.traits[index] = {id = id, rarity = tier} return resolved({}) end
			function backend:switch_mark(gear_id, mark_id)
				assert(gear_id == item.gear_id and mark_id == "weapon-2")
				assert(item.rarity == 5 and item.expertise_level == 500)
				assert(item.perks[1].id == "new_perk" and item.perks[2].id == "other_perk")
				assert(item.traits[1].id == "new_blessing" and item.traits[2].id == "keep_blessing")
				self.mark_calls = self.mark_calls + 1
				item.master_id = mark_id
				item.base_stats = {shovel_m3_defence_stat = 60}
				item.base_stat_labels = {shovel_m3_defence_stat = "loc_stats_display_defense_stat"}
				item.potential_base_stats = {shovel_m3_defence_stat = 60}

				return resolved({gear_id = gear_id, mark_id = mark_id})
			end

			local settings = base_settings({
				auto_crafter_target_dump_stat = "defenses",
				auto_crafter_consecrate_transcendent = true,
				auto_crafter_upgrade_expertise_500 = true,
				auto_crafter_allocate_mastery_points = true,
				auto_crafter_level_mastery_20 = true,
				auto_crafter_change_perks = true,
				auto_crafter_change_blessings = true,
				auto_crafter_perk_1_target = "perk:new_perk:4",
				auto_crafter_perk_2_target = "perk:other_perk:4",
				auto_crafter_blessing_1_target = "new_blessing",
				auto_crafter_blessing_2_target = "keep",
			})
			CurrentOffer = raw_offer()
			TestTime = 100
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = settings, reporter = reports(), clock = {now = function() return TestTime end}, get_selected_offer = function() return CurrentOffer end})
			controller._catalog = {
				available = true,
				trait_category = "test_category",
				perks = {{id = "new_perk", tier = 4}, {id = "other_perk", tier = 4}},
				blessings = {
					{id = "filler_blessing", tiers = {{tier = 1, status = "unseen"}, {tier = 2, status = "unseen"}, {tier = 3, status = "unseen"}, {tier = 4, status = "unseen"}}},
					{id = "new_blessing", tiers = {{tier = 1, status = "unseen"}, {tier = 2, status = "unseen"}, {tier = 3, status = "unseen"}, {tier = 4, status = "unseen"}}},
				},
			}
			controller._snapshot = phase_snapshot(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:select_manual_mark("offer-1", "weapon-2") == true)
			assert(controller:start_purchase_search() == true)
			for _ = 1, 30 do TestTime = TestTime + 1 controller:update(10) end
			local result = controller:snapshot()
			assert(result.phase == "phase4_complete", tostring(result.phase) .. " " .. tostring(result.last_error))
			assert(result.search.dump_stat == "shovel_m3_defence_stat")
			assert(result.search.dump_stat_identity.display_name_key == "loc_stats_display_defense_stat")
			assert(result.search.result.dump_stat == 60)
			assert(item.rarity == 5 and item.expertise_level == 500)
			assert(backend.rarity_calls == 2 and backend.expertise_calls == 2)
			assert(backend.allocation_calls == 8 and backend.perk_calls == 2 and backend.blessing_calls == 1 and backend.mark_calls == 1)
			assert(state.allocation_order[1] == "new_blessing:1")
			assert(state.allocation_order[2] == "filler_blessing:1")
			assert(state.allocation_order[7] == "new_blessing:4")
			assert(state.allocation_order[8] == "filler_blessing:4")
			assert(result.phase4.blessing_points_spent == 8 and result.phase4.blessing_points_total == 8)
			assert(result.phase4.elapsed_seconds > 0 and result.search.elapsed_seconds == result.phase4.elapsed_seconds)
			assert(result.resource_costs.credits == 100 and result.resource_costs.plasteel == 30 and result.resource_costs.diamantine == 4)
			assert(result.phase4.resource_costs.credits == 100 and result.phase4.resource_costs.plasteel == 30 and result.phase4.resource_costs.diamantine == 4)
			assert(state.perk_order[1] == 2 and state.perk_order[2] == 1)
			assert(item.master_id == "weapon-2")
			assert(item.perks[1].id == "new_perk" and item.perks[2].id == "other_perk" and item.traits[1].id == "new_blessing")
			controller:_operation_failed(controller._generation, {code = "backend_error", description = "readable backend failure"})
			assert(controller:snapshot().last_error == "readable backend failure")
		end

		-- Darktide's mastery service resolves a rejected mark PATCH as an error
		-- value. Promise resolution alone must never let the wrong mark complete.
		do
			local item = summarized_item("gear-unconfirmed-mark", 5, 60)
			item.expertise_level = 500
			local backend = {mark_calls = 0}
			local function mark_snapshot(current_item)
				local snapshot = snapshot_with(current_item)
				snapshot.store.offers[1].marks = {
					{master_id = "weapon-1", parent_pattern = "pattern-1", slot_type = "slot_primary", weapon_template = "template-1"},
					{master_id = "weapon-2", parent_pattern = "pattern-1", slot_type = "slot_primary", weapon_template = "template-2"},
				}

				return snapshot
			end
			function backend:purchase_offer(_) return resolved({items = {item}}) end
			function backend:probe_snapshot() return resolved(mark_snapshot(item)) end
			function backend:switch_mark()
				self.mark_calls = self.mark_calls + 1

				return resolved({code = "backend_rejected", description = "mark is locked"})
			end
			CurrentOffer = raw_offer("weapon-1")
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = mark_snapshot(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:select_manual_mark("offer-1", "weapon-2") == true)
			assert(controller:start_purchase_search() == true)
			assert(backend.mark_calls == 1)
			assert(controller:snapshot().phase == "operation_failed")
			assert(controller:snapshot().last_error == "selected weapon mark switch was not confirmed")
			assert(controller:snapshot().search.running == false)
			assert(controller:snapshot().phase4.result == nil)
		end

		-- A below-20 family can acquire an exact sibling-mark stat, level mastery
		-- using only run-owned fodder, and switch the preserved target to the
		-- explicitly selected mark only after the level-20 claim converges.
		do
			local target = summarized_item("gear-cross-mark-target", 1, 60)
			target.base_stats = {shovel_m1_defence_stat = 60}
			target.base_stat_labels = {shovel_m1_defence_stat = "loc_stats_display_defense_stat"}
			target.potential_base_stats = {shovel_m1_defence_stat = 60}
			local fodder = summarized_item("gear-cross-mark-fodder", 0, 50)
			fodder.expertise_level = 40
			local state = {
				items = {},
				mastery_claimed = false,
				sequence = {},
			}
			local backend = {
				claim_calls = 0,
				extract_calls = 0,
				mark_calls = 0,
				purchase_calls = 0,
				upgrade_calls = 0,
			}
			local function cross_mark_snapshot()
				local snapshot = snapshot_with_items(state.items)
				snapshot.store.offers[1].marks = {
					{base_stats = {{name = "shovel_m1_defence_stat", display_name_key = "loc_stats_display_defense_stat"}}, master_id = "weapon-1", parent_pattern = "pattern-1", slot_type = "slot_primary", weapon_template = "template-1"},
					{base_stats = {{name = "shovel_m3_defence_stat", display_name_key = "loc_stats_display_defense_stat"}}, master_id = "weapon-2", parent_pattern = "pattern-1", slot_type = "slot_primary", weapon_template = "template-2"},
				}
				snapshot.crafting_costs = {
					sacrifice_mastery = {
						baseReward = 0,
						masteryXpPerExpertiseLevel = 10,
						minimumExpertiseLevel = 0,
						sacrifice_muiltiplier = 1,
					},
				}

				return snapshot
			end
			function backend:purchase_offer(_)
				self.purchase_calls = self.purchase_calls + 1
				local item = self.purchase_calls == 1 and target or fodder
				state.items[#state.items + 1] = item

				return resolved({items = {item}})
			end
			function backend:probe_snapshot()
				return resolved(cross_mark_snapshot())
			end
			function backend:get_mastery_by_pattern(mastery_id)
				assert(mastery_id == "pattern-1")

				return resolved({
					mastery_id = "pattern-1",
					current_xp = 100,
					mastery_level = 19,
					claimed_level = 18,
					mastery_max_level = 20,
					milestones = {{level = 20, xpLimit = 150}},
				})
			end
			function backend:upgrade_weapon_rarity(gear_id)
				assert(gear_id == fodder.gear_id)
				assert(self.mark_calls == 0 and state.mastery_claimed == false)
				self.upgrade_calls = self.upgrade_calls + 1
				fodder.rarity = 2
				state.sequence[#state.sequence + 1] = "fodder_upgrade"

				return resolved({gear_id = gear_id})
			end
			function backend:extract_weapon_mastery(mastery_id, gear_ids)
				assert(mastery_id == "pattern-1")
				assert(#gear_ids == 1 and gear_ids[1] == fodder.gear_id)
				assert(gear_ids[1] ~= target.gear_id and self.mark_calls == 0)
				self.extract_calls = self.extract_calls + 1
				state.items = {target}
				state.sequence[#state.sequence + 1] = "fodder_extract"

				return resolved({amount = 50, gear_ids = {fodder.gear_id}})
			end
			function backend:project_mastery(data, amount)
				assert(data.mastery_level == 19 and data.current_xp == 100 and amount == 50)

				return {
					mastery_id = "pattern-1",
					current_xp = 150,
					mastery_level = 20,
					claimed_level = 18,
					mastery_max_level = 20,
					milestones = data.milestones,
				}
			end
			function backend:claim_mastery_levels(data, amount)
				assert(data.mastery_level == 20 and data.current_xp == 150 and amount == 0)
				assert(self.extract_calls == 1 and self.mark_calls == 0)
				self.claim_calls = self.claim_calls + 1
				state.mastery_claimed = true
				state.sequence[#state.sequence + 1] = "mastery_claim"

				return resolved({mastery_id = "pattern-1", current_xp = 150, mastery_level = 20, claimed_level = 19, mastery_max_level = 20})
			end
			function backend:switch_mark(gear_id, mark_id)
				assert(gear_id == target.gear_id and mark_id == "weapon-2")
				assert(state.mastery_claimed == true and self.extract_calls == 1)
				assert(#state.items == 1 and state.items[1].gear_id == target.gear_id)
				self.mark_calls = self.mark_calls + 1
				state.sequence[#state.sequence + 1] = "mark_switch"
				target.master_id = mark_id
				target.base_stats = {shovel_m3_defence_stat = 60}
				target.base_stat_labels = {shovel_m3_defence_stat = "loc_stats_display_defense_stat"}
				target.potential_base_stats = {shovel_m3_defence_stat = 60}

				return resolved({gear_id = gear_id, mark_id = mark_id})
			end

			local settings = base_settings({
				auto_crafter_target_dump_stat = "defenses",
				auto_crafter_level_mastery_20 = true,
				auto_crafter_defer_bad_weapon_processing = true,
				auto_crafter_max_purchases = 2,
			})
			CurrentOffer = raw_offer("weapon-1")
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = settings, reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = cross_mark_snapshot()
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:select_manual_mark("offer-1", "weapon-2") == true)
			assert(controller:start_purchase_search() == true)
			local result = controller:snapshot()
			assert(result.phase == "phase4_complete", tostring(result.phase) .. " " .. tostring(result.last_error))
			assert(backend.purchase_calls == 2 and backend.upgrade_calls == 1)
			assert(backend.extract_calls == 1 and backend.claim_calls == 1 and backend.mark_calls == 1)
			assert(result.phase3.fodder_count == 1 and result.phase3.current.mastery_level == 20 and result.phase3.current.claimed_level == 19)
			assert(result.search.result.gear_id == target.gear_id and result.search.result.dump_stat == 60)
			assert(result.search.dump_stat == "shovel_m3_defence_stat")
			assert(result.search.dump_stat_identity.display_name_key == "loc_stats_display_defense_stat")
			assert(target.master_id == "weapon-2" and target.potential_base_stats.shovel_m3_defence_stat == 60)
			assert(#state.items == 1 and state.items[1].gear_id == target.gear_id)
			assert(state.sequence[1] == "fodder_upgrade")
			assert(state.sequence[2] == "fodder_extract")
			assert(state.sequence[3] == "mastery_claim")
			assert(state.sequence[4] == "mark_switch" and state.sequence[5] == nil)
		end

		-- The last runtime refresh is read-only and follows an already authoritative
		-- gear verification. If that duplicate read never settles, retire it without
		-- retrying any mutation and complete from the preserved confirmed snapshot.
		do
			local item = summarized_item("gear-final-refresh-timeout", 5, 60)
			item.expertise_level = 500
			local final_refresh = pending()
			local backend = {mutation_calls = 0, refresh_calls = 0}
			function backend:refresh_runtime_snapshot(_)
				self.refresh_calls = self.refresh_calls + 1

				return final_refresh
			end
			local reporter = reports()
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reporter})
			controller._snapshot = snapshot_with(item)
			controller._search = {
				dump_stat = "damage_stat",
				running = true,
				start_wallet = {credits = 10000},
				target_dump = 60,
			}
			controller._phase4 = {
				allocate_mastery = false,
				consecrate = false,
				dump_stat = "damage_stat",
				expertise = false,
				favorite_result = false,
				gear_id = item.gear_id,
				mastery_id = item.parent_pattern,
				running = true,
				sticker_book = {},
				target_dump = 60,
				targets = {perks = {}, traits = {}},
				verify_completion = true,
			}
			assert(controller:_phase4_step(controller._generation, controller._snapshot) == true)
			assert(backend.refresh_calls == 1 and backend.mutation_calls == 0)
			assert(controller:snapshot().phase == "authoritative_refresh_inflight")
			assert(controller:snapshot().operation_read_only == true)
			controller:update(15)
			local result = controller:snapshot()
			assert(result.phase == "phase4_complete", tostring(result.phase) .. " " .. tostring(result.last_error))
			assert(result.last_error == nil and result.operation_inflight == false and result.operation_quarantined == false)
			assert(result.reconciliation_required == false and result.phase4.running == false)
			assert(result.phase4.final_reconcile_fallback == "read_timeout")
			assert(result.phase4.result.gear_id == item.gear_id and controller:is_busy() == false and controller:needs_update() == false)
			assert(backend.mutation_calls == 0)
			local terminal_sequence = result.terminal_sequence
			final_refresh.next_callback(snapshot_with(item))
			assert(controller:snapshot().phase == "phase4_complete")
			assert(controller:snapshot().terminal_sequence == terminal_sequence)
			assert(backend.mutation_calls == 0)
			assert(reporter.events[#reporter.events - 1].kind == "phase4_final_reconcile_fallback")
			assert(reporter.events[#reporter.events].kind == "phase4_complete")
		end

		-- A stalled read before the final confirmed boundary fails visibly and is
		-- retired without mutation quarantine or a late-callback continuation.
		do
			local refresh = pending()
			local callback_calls = 0
			local backend = {}
			function backend:refresh_gear_snapshot(_) return refresh end
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reports()})
			controller._snapshot = snapshot_with(nil)
			controller._search = {running = true}
			assert(controller:_refresh_after_operation(controller._generation, function () callback_calls = callback_calls + 1 end) == true)
			assert(controller:snapshot().operation_read_only == true)
			controller:update(15)
			local result = controller:snapshot()
			assert(result.phase == "operation_failed")
			assert(result.operation_inflight == false and result.operation_quarantined == false and result.reconciliation_required == false)
			assert(string.find(result.last_error, "no mutation was retried", 1, true) ~= nil)
			refresh.next_callback(snapshot_with(nil))
			assert(callback_calls == 0 and controller:snapshot().phase == "operation_failed")
		end

		-- A resumed sub-500 weapon can never reach a perk/blessing mutation when
		-- automatic expertise is disabled. The authoritative snapshot, not request
		-- completion or a projected local value, owns this safety boundary.
		do
			local item = summarized_item("gear-sub-500-trait-guard", 5, 60)
			item.expertise_level = 499
			item.perks = {{id = "old_perk", rarity = 4}, {id = "keep_perk", rarity = 4}}
			item.traits = {{id = "keep_blessing", rarity = 4}, {id = "other_blessing", rarity = 4}}
			local backend = {perk_calls = 0, blessing_calls = 0}
			function backend:replace_perk() self.perk_calls = self.perk_calls + 1 return resolved({}) end
			function backend:replace_blessing() self.blessing_calls = self.blessing_calls + 1 return resolved({}) end
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reports()})
			controller._snapshot = snapshot_with(item)
			controller._active_view = {}
			controller._view_is_valid = true
			controller._search = {running = true}
			controller._phase4 = {
				catalog = {perks = {}, blessings = {}},
				consecrate = false,
				dump_stat = "damage_stat",
				expertise = false,
				gear_id = item.gear_id,
				mastery_id = item.parent_pattern,
				running = true,
				sticker_book = {},
				target_dump = 60,
				targets = {
					perks = {{id = "new_perk", rarity = 4}, {id = "keep_perk", rarity = 4}},
					traits = {{id = "keep_blessing", rarity = 4}, {id = "other_blessing", rarity = 4}},
				},
			}
			assert(controller:_phase4_step(controller._generation, controller._snapshot) == false)
			assert(backend.perk_calls == 0 and backend.blessing_calls == 0)
			assert(controller:snapshot().phase == "operation_failed")
			assert(string.find(controller:snapshot().last_error, "authoritatively item level 500", 1, true) ~= nil)
		end

		-- Replacement-only blessing mode verifies ownership before spending any
		-- final-crafting materials when automatic point allocation is disabled.
		do
			local item = summarized_item("gear-unowned-blessing", 2, 60)
			item.expertise_level = 300
			item.perks = {{id = "keep_perk", rarity = 4}, {id = "other_perk", rarity = 4}}
			item.traits = {{id = "old_blessing", rarity = 4}, {id = "keep_blessing", rarity = 4}}
			local backend = {rarity_calls = 0}
			function backend:purchase_offer(_) return resolved({items = {item}}) end
			function backend:probe_snapshot() return resolved(snapshot_with(item)) end
			function backend:get_mastery_by_pattern(_) return resolved({mastery_id = "pattern-1", current_xp = 20000, mastery_level = 20, claimed_level = 19, mastery_max_level = 20}) end
			function backend:get_trait_sticker_book(_)
				return resolved({
					{id = "new_blessing", tiers = {{tier = 4, status = "unseen"}}},
					{id = "keep_blessing", tiers = {{tier = 4, status = "seen"}}},
				})
			end
			function backend:upgrade_weapon_rarity(_) self.rarity_calls = self.rarity_calls + 1 return resolved({}) end
			local settings = base_settings({
				auto_crafter_allocate_mastery_points = false,
				auto_crafter_blessing_1_target = "new_blessing",
				auto_crafter_blessing_2_target = "keep_blessing",
				auto_crafter_change_blessings = true,
				auto_crafter_consecrate_transcendent = true,
				auto_crafter_level_mastery_20 = true,
			})
			CurrentOffer = raw_offer()
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = settings, reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._catalog = {
				available = true,
				trait_category = "test_category",
				perks = {},
				blessings = {
					{id = "new_blessing", tiers = {{tier = 4, status = "unseen"}}},
					{id = "keep_blessing", tiers = {{tier = 4, status = "seen"}}},
				},
			}
			controller._snapshot = snapshot_with(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:start_purchase_search() == true)
			assert(controller:snapshot().phase == "operation_failed")
			assert(controller:snapshot().last_error == "selected blessing tier is not allocated in mastery")
			assert(backend.rarity_calls == 0)
		end

		-- Four complete crafts may run back to back through one controller. Each run
		-- owns fresh generation/state, preserves prior results, and reports only its
		-- own wallet/material deltas and operation counts.
		do
			local state = {
				claimed_level = 18,
				inventory = {},
				wallet = {credits = 50000, plasteel = 10000, diamantine = 5000},
			}
			local backend = {
				claim_calls = 0,
				expertise_calls = 0,
				favorite_calls = 0,
				mastery_cost_calls = 0,
				perk_calls = 0,
				purchase_calls = 0,
				rarity_calls = 0,
				trait_calls = 0,
				mark_calls = 0,
			}
			local function integration_snapshot()
				local snapshot = snapshot_with_items(state.inventory)
				snapshot.wallets.currencies.credits.amount = state.wallet.credits
				snapshot.wallets.currencies.plasteel = {amount = state.wallet.plasteel}
				snapshot.wallets.currencies.diamantine = {amount = state.wallet.diamantine}

				return snapshot
			end
			function backend:purchase_offer(_)
				self.purchase_calls = self.purchase_calls + 1
				local run = self.purchase_calls
				local item = summarized_item("gear-integration-" .. tostring(run), 2, 60)
				item.expertise_level = 290 + run * 10
				item.favorite_known = true
				item.favorited = false
				item.perks = run >= 3 and {{id = "keep_perk", rarity = 4}, {id = "new_perk", rarity = 4}} or {{id = "old_perk_" .. tostring(run), rarity = 4}, {id = "keep_perk", rarity = 4}}
				item.traits = (run == 2 or run == 4) and {{id = "keep_blessing", rarity = 4}, {id = "new_blessing", rarity = 4}} or {{id = "old_blessing_" .. tostring(run), rarity = 4}, {id = "keep_blessing", rarity = 4}}
				state.inventory[#state.inventory + 1] = item
				state.wallet.credits = state.wallet.credits - 100

				return resolved({items = {item}})
			end
			function backend:probe_snapshot()
				return resolved(integration_snapshot())
			end
			function backend:get_mastery_by_pattern(_)
				return resolved({mastery_id = "pattern-1", current_xp = 20000, mastery_level = 20, claimed_level = state.claimed_level, mastery_max_level = 20})
			end
			function backend:claim_mastery_levels(_, _)
				self.claim_calls = self.claim_calls + 1
				state.claimed_level = 19

				return resolved({mastery_id = "pattern-1", current_xp = 20000, mastery_level = 20, claimed_level = state.claimed_level, mastery_max_level = 20})
			end
			function backend:switch_mark()
				self.mark_calls = self.mark_calls + 1

				return rejected("Auto Crafter must never mutate weapon marks")
			end
			function backend:favorite_item(gear_id)
				self.favorite_calls = self.favorite_calls + 1

				for _, item in ipairs(state.inventory) do
					if item.gear_id == gear_id then
						item.favorited = true
						return resolved({gear_id = gear_id})
					end
				end

				return rejected("favorite target missing")
			end
			function backend:upgrade_weapon_rarity(gear_id)
				self.rarity_calls = self.rarity_calls + 1

				for _, item in ipairs(state.inventory) do
					if item.gear_id == gear_id then
						item.rarity = item.rarity + 1
						state.wallet.plasteel = state.wallet.plasteel - 10
						state.wallet.diamantine = state.wallet.diamantine - 2
						return resolved({gear_id = gear_id})
					end
				end

				return rejected("rarity target missing")
			end
			function backend:add_weapon_expertise(gear_id, target)
				self.expertise_calls = self.expertise_calls + 1

				for _, item in ipairs(state.inventory) do
					if item.gear_id == gear_id then
						item.expertise_level = target
						state.wallet.plasteel = state.wallet.plasteel - 5
						return resolved({gear_id = gear_id})
					end
				end

				return rejected("expertise target missing")
			end
			function backend:get_trait_sticker_book(_)
				return resolved({
					{id = "new_blessing", tiers = {{tier = 4, status = "seen"}}},
					{id = "keep_blessing", tiers = {{tier = 4, status = "seen"}}},
					{id = "temporary_blessing", tiers = {{tier = 4, status = "seen"}}},
				})
			end
			function backend:get_mastery_trait_costs()
				self.mastery_cost_calls = self.mastery_cost_calls + 1

				return rejected("already allocated mastery tree must not request costs")
			end
			function backend:replace_perk(gear_id, index, id, tier)
				self.perk_calls = self.perk_calls + 1

				for _, item in ipairs(state.inventory) do
					if item.gear_id == gear_id then
						item.perks[index] = {id = id, rarity = tier}
						return resolved({gear_id = gear_id})
					end
				end

				return rejected("perk target missing")
			end
			function backend:replace_blessing(gear_id, index, id, tier)
				self.trait_calls = self.trait_calls + 1

				for _, item in ipairs(state.inventory) do
					if item.gear_id == gear_id then
						item.traits[index] = {id = id, rarity = tier}
						return resolved({gear_id = gear_id})
					end
				end

				return rejected("blessing target missing")
			end

			local settings = base_settings({
				auto_crafter_allocate_mastery_points = true,
				auto_crafter_change_blessings = true,
				auto_crafter_change_perks = true,
				auto_crafter_consecrate_transcendent = true,
				auto_crafter_favorite_result = true,
				auto_crafter_level_mastery_20 = true,
				auto_crafter_max_purchases = 1,
				auto_crafter_perk_1_target = "perk:new_perk:4",
				auto_crafter_perk_2_target = "perk:keep_perk:4",
				auto_crafter_blessing_1_target = "new_blessing",
				auto_crafter_blessing_2_target = "keep_blessing",
				auto_crafter_upgrade_expertise_500 = true,
			})
			CurrentOffer = raw_offer()
			TestTime = 200
			local reporter = reports()
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = settings, reporter = reporter, clock = {now = function() return TestTime end}, get_selected_offer = function() return CurrentOffer end})
			controller._catalog = {
				available = true,
				trait_category = "test_category",
				perks = {{id = "new_perk", tier = 4}, {id = "keep_perk", tier = 4}, {id = "temporary_perk", tier = 4}},
				blessings = {
					{id = "new_blessing", tiers = {{tier = 4, status = "seen"}}},
					{id = "keep_blessing", tiers = {{tier = 4, status = "seen"}}},
					{id = "temporary_blessing", tiers = {{tier = 4, status = "seen"}}},
				},
			}
			controller._snapshot = integration_snapshot()
			controller._active_view = {}
			controller._view_is_valid = true

			for run = 1, 4 do
				local expected_perk_calls = run >= 3 and 3 or 1
				local expected_trait_calls = (run == 2 or run == 4) and 3 or 1
				local before_rarity = backend.rarity_calls
				local before_expertise = backend.expertise_calls
				local before_perks = backend.perk_calls
				local before_traits = backend.trait_calls
				assert(controller:start_purchase_search() == true, "run " .. tostring(run) .. " did not start")
				TestTime = TestTime + 1
				local result = controller:snapshot()
				local item = state.inventory[run]
				assert(result.phase == "phase4_complete", "run " .. tostring(run) .. " stopped at " .. tostring(result.phase) .. ": " .. tostring(result.last_error))
				assert(result.search.generation == run)
				assert(result.search.purchases == 1 and result.search.result.gear_id == item.gear_id)
				assert(result.phase3.fodder_count == 0 and result.phase3.target_candidate.gear_id == item.gear_id)
				assert(result.phase4.gear_id == item.gear_id and result.phase4.result.gear_id == item.gear_id)
				assert(item.rarity == 5 and item.expertise_level == 500 and item.favorited == true)
				assert(item.perks[1].id == "new_perk" and item.perks[2].id == "keep_perk")
				assert(item.traits[1].id == "new_blessing" and item.traits[2].id == "keep_blessing", "traits " .. tostring(item.traits[1].id) .. "/" .. tostring(item.traits[2].id))
				assert(backend.rarity_calls - before_rarity == 3)
				assert(backend.expertise_calls - before_expertise == 2)
				assert(backend.perk_calls - before_perks == expected_perk_calls)
				assert(backend.trait_calls - before_traits == expected_trait_calls)
				assert(result.resource_costs.credits == 100 and result.resource_costs.plasteel == 40 and result.resource_costs.diamantine == 6)
				controller._snapshot = integration_snapshot()
			end

			assert(#state.inventory == 4 and backend.purchase_calls == 4 and backend.favorite_calls == 4 and backend.claim_calls == 1 and backend.mastery_cost_calls == 0)
			assert(backend.rarity_calls == 12 and backend.expertise_calls == 8 and backend.perk_calls == 8 and backend.trait_calls == 8)
			assert(backend.mark_calls == 0, "exact-mark acquisition must not dispatch switch_mark")
			local phase3_completions = 0
			local phase4_starts = 0

			for _, event in ipairs(reporter.events) do
				if event.kind == "phase3_complete" then
					phase3_completions = phase3_completions + 1
					assert(event.payload.current.mastery_level >= 20)
					assert(event.payload.current.claimed_level >= 19)
				elseif event.kind == "phase4_started" then
					phase4_starts = phase4_starts + 1
					assert(phase3_completions == phase4_starts, "final crafting started before mastery claims converged")
				end
			end

			assert(phase3_completions == 4 and phase4_starts == 4)
			for run, item in ipairs(state.inventory) do
				assert(item.gear_id == "gear-integration-" .. tostring(run))
				assert(item.rarity == 5 and item.expertise_level == 500 and item.favorited == true)
			end
		end

		-- Explicit starting-state matrix covers fresh acquisition, partial inventory
		-- reuse, complete inventory reuse, unallocated mastery, and allocated mastery.
		do
			local matrix = {
				{name = "fresh_profane", reuse = false, rarity = 0, expertise = 300, allocated = true, matching_traits = false, purchases = 1, rarity_calls = 5, expertise_calls = 2, allocation_calls = 0, replacement_calls = 1},
				{name = "reuse_below_500", reuse = true, rarity = 2, expertise = 320, allocated = true, matching_traits = false, purchases = 0, rarity_calls = 3, expertise_calls = 2, allocation_calls = 0, replacement_calls = 1},
				{name = "reuse_complete_500", reuse = true, rarity = 5, expertise = 500, allocated = true, matching_traits = true, purchases = 0, rarity_calls = 0, expertise_calls = 0, allocation_calls = 0, replacement_calls = 0},
				{name = "mastery_20_unallocated", reuse = true, rarity = 5, expertise = 500, allocated = false, matching_traits = false, purchases = 0, rarity_calls = 0, expertise_calls = 0, allocation_calls = 1, replacement_calls = 1},
				{name = "mastery_20_allocated", reuse = true, rarity = 5, expertise = 500, allocated = true, matching_traits = false, purchases = 0, rarity_calls = 0, expertise_calls = 0, allocation_calls = 0, replacement_calls = 1},
			}

			for case_index, case in ipairs(matrix) do
				local state = {item = nil, statuses = {}}
				for _, id in ipairs({"new_blessing", "keep_blessing", "temporary_blessing"}) do
					state.statuses[id] = {}
					for tier = 1, 4 do state.statuses[id][tier] = case.allocated and "seen" or "unseen" end
				end
				local function make_item()
					local item = summarized_item("gear-state-" .. tostring(case_index), case.rarity, 60)
					item.expertise_level = case.expertise
					item.favorite_known = true
					item.favorited = false
					item.perks = {{id = "keep_perk", rarity = 4}, {id = "other_perk", rarity = 4}}
					item.traits = case.matching_traits and {{id = "new_blessing", rarity = 4}, {id = "keep_blessing", rarity = 4}} or {{id = "old_blessing", rarity = 4}, {id = "keep_blessing", rarity = 4}}

					return item
				end
				if case.reuse then
					state.item = make_item()
				end

				local backend = {allocation_calls = 0, expertise_calls = 0, mastery_cost_calls = 0, purchase_calls = 0, rarity_calls = 0, replacement_calls = 0}
				local function state_snapshot()
					return snapshot_with(state.item)
				end
				function backend:purchase_offer(_)
					self.purchase_calls = self.purchase_calls + 1
					state.item = make_item()

					return resolved({items = {state.item}})
				end
				function backend:probe_snapshot() return resolved(state_snapshot()) end
				function backend:get_mastery_by_pattern(_) return resolved({mastery_id = "pattern-1", current_xp = 20000, mastery_level = 20, claimed_level = 19, mastery_max_level = 20}) end
				function backend:upgrade_weapon_rarity(_)
					self.rarity_calls = self.rarity_calls + 1
					state.item.rarity = state.item.rarity + 1

					return resolved({})
				end
				function backend:add_weapon_expertise(_, target)
					self.expertise_calls = self.expertise_calls + 1
					state.item.expertise_level = target

					return resolved({})
				end
				function backend:get_trait_sticker_book(_)
					local result = {}
					for _, id in ipairs({"new_blessing", "keep_blessing", "temporary_blessing"}) do
						local tiers = {}
						for tier = 1, 4 do tiers[#tiers + 1] = {tier = tier, status = state.statuses[id][tier]} end
						result[#result + 1] = {id = id, tiers = tiers}
					end

					return resolved(result)
				end
				function backend:get_mastery_trait_costs()
					self.mastery_cost_calls = self.mastery_cost_calls + 1

					return resolved({tier_costs = {["1"] = 1, ["2"] = 1, ["3"] = 1, ["4"] = 1}, tier_thresholds = {["1"] = 0, ["2"] = 1, ["3"] = 4, ["4"] = 7}})
				end
				function backend:purchase_mastery_traits(_, operations)
					self.allocation_calls = self.allocation_calls + 1
					for _, operation in ipairs(operations) do state.statuses[operation.trait_id][operation.rarity] = "seen" end

					return resolved({count = #operations})
				end
				function backend:replace_blessing(_, index, id, tier)
					self.replacement_calls = self.replacement_calls + 1
					state.item.traits[index] = {id = id, rarity = tier}

					return resolved({})
				end

				local settings = base_settings({
					auto_crafter_allocate_mastery_points = true,
					auto_crafter_blessing_1_target = "new_blessing",
					auto_crafter_blessing_2_target = "keep_blessing",
					auto_crafter_change_blessings = true,
					auto_crafter_consecrate_transcendent = true,
					auto_crafter_level_mastery_20 = true,
					auto_crafter_reuse_inventory_base = case.reuse,
					auto_crafter_upgrade_expertise_500 = true,
				})
				CurrentOffer = raw_offer()
				local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = settings, reporter = reports(), get_selected_offer = function() return CurrentOffer end})
				controller._catalog = {
					available = true,
					trait_category = "test_category",
					perks = {},
					blessings = {
						{id = "new_blessing", tiers = {{tier = 4, status = state.statuses.new_blessing[4]}}},
						{id = "keep_blessing", tiers = {{tier = 4, status = state.statuses.keep_blessing[4]}}},
						{id = "temporary_blessing", tiers = {{tier = 4, status = state.statuses.temporary_blessing[4]}}},
					},
				}
				controller._snapshot = state_snapshot()
				controller._active_view = {}
				controller._view_is_valid = true
				assert(controller:start_purchase_search() == true, case.name .. " did not start")
				for _ = 1, 20 do controller:update(1) end
				local result = controller:snapshot()
				assert(result.phase == "phase4_complete", case.name .. " stopped at " .. tostring(result.phase) .. ": " .. tostring(result.last_error))
				assert(backend.purchase_calls == case.purchases and backend.rarity_calls == case.rarity_calls and backend.expertise_calls == case.expertise_calls, case.name .. " acquisition/final level call mismatch")
				assert(backend.allocation_calls == case.allocation_calls and backend.replacement_calls == case.replacement_calls, case.name .. " mastery/replacement call mismatch")
				assert(backend.mastery_cost_calls == case.allocation_calls, case.name .. " redundant or missing mastery cost read")
				assert(state.item.rarity == 5 and state.item.expertise_level == 500 and state.item.traits[1].id == "new_blessing" and state.item.traits[2].id == "keep_blessing")
			end
		end

		-- Character identity is part of every mutation boundary. This covers
		-- InstantCharacterChange-style live profile swaps without a hub reload.
		do
			local active_character = "character-2"
			local stale = snapshot_with(nil)
			stale.character_id = "character-1"
			local backend = {purchase_calls = 0}
			function backend:purchase_offer(_) self.purchase_calls = self.purchase_calls + 1 return resolved({items = {}}) end
			local live_context = {
				current_character_id = function() return active_character end,
				is_valid_brunt_view = function() return true end,
				is_runtime_valid = function() return true end,
			}
			CurrentOffer = raw_offer()
			local controller = Controller.new({backend = backend, planner = Planner, context = live_context, settings = base_settings(), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = stale
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:start_purchase_search() == false)
			assert(backend.purchase_calls == 0 and controller:snapshot().phase ~= "purchase_offer_inflight")
		end

		do
			local active_character = "character-1"
			local backend = {purchase_calls = 0, purchase_promise = pending()}
			function backend:purchase_offer(_)
				self.purchase_calls = self.purchase_calls + 1
				return self.purchase_promise
			end
			function backend:probe_snapshot()
				local snapshot = snapshot_with(nil)
				snapshot.character_id = active_character
				return resolved(snapshot)
			end
			local live_context = {
				current_character_id = function() return active_character end,
				is_valid_brunt_view = function() return true end,
				is_runtime_valid = function() return true end,
			}
			CurrentOffer = raw_offer()
			local reporter = reports()
			local controller = Controller.new({backend = backend, planner = Planner, context = live_context, settings = base_settings(), reporter = reporter, get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			controller._observed_character_id = active_character
			assert(controller:start_purchase_search() == true and backend.purchase_calls == 1)
			active_character = "character-2"
			controller:on_brunt_view_ready(controller._active_view)
			controller:update(0.1)
			assert(controller:snapshot().phase == "probe_scheduled")
			assert(controller:snapshot().data == nil and controller:snapshot().search == nil)
			backend.purchase_promise.next_callback({items = {{uuid = "wrong-character-item"}}})
			assert(backend.purchase_calls == 1 and controller:snapshot().search == nil)
			local saw_character_change = false
			for _, event in ipairs(reporter.events) do saw_character_change = saw_character_change or event.kind == "character_changed" end
			assert(saw_character_change == true)
		end

		-- Configuration changes close dispatch gate while current request remains unsettled.
        do
            local backend = {purchase_promise = pending()}
            function backend:purchase_offer(_) return self.purchase_promise end
            local settings = base_settings()
            CurrentOffer = raw_offer()
            local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = settings, reporter = reports(), get_selected_offer = function() return CurrentOffer end})
            controller._snapshot = snapshot_with(nil)
            controller._active_view = {}
            controller._view_is_valid = true
            assert(controller:start_purchase_search() == true)
            assert(controller:snapshot().search.running == true)
            settings.values.auto_crafter_dump_stat_target = 59
            assert(controller:on_setting_changed("auto_crafter_dump_stat_target") == true)
            assert(controller:snapshot().search.running == false)
            assert(controller:snapshot().phase == "run_configuration_changed")
        end

        -- Explicit Stop control closes dispatch without attempting to cancel an account mutation.
        do
            local backend = {purchase_promise = pending()}
            function backend:purchase_offer(_) return self.purchase_promise end
            CurrentOffer = raw_offer()
            local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
            controller._snapshot = snapshot_with(nil)
            controller._active_view = {}
            controller._view_is_valid = true
            assert(controller:start_purchase_search() == true)
            assert(controller:stop_active_run() == true)
            assert(controller:snapshot().search.running == false)
            assert(controller:snapshot().operation_inflight == true)
            assert(controller:snapshot().phase == "user_stopped")
			backend.purchase_promise.next_callback({items = {}})
			assert(controller:snapshot().operation_inflight == false)
        end

		-- Every request family shares same graceful interruption boundary. Settled
		-- callbacks become inert, including runs adopting partially crafted gear.
		do
			local cases = {
				{kind = "purchase", field = "_search", state = {running = true}},
				{kind = "authoritative_refresh", field = "_phase3", state = {running = true, current = {gear_id = "resumed-base"}}},
				{kind = "mastery_upgrade_batch", field = "_phase3", state = {running = true, current = {gear_id = "resumed-mastery"}}},
				{kind = "mastery_sacrifice_batch", field = "_mastery", state = {running = true, gear_id = "fodder"}},
				{kind = "mastery_claim", field = "_mastery", state = {running = true, mastery_id = "track"}},
				{kind = "phase4_sticker_preflight", field = "_phase4", state = {running = true, gear_id = "resumed-final"}},
				{kind = "phase4_consecrate", field = "_phase4", state = {running = true, gear_id = "resumed-final"}},
				{kind = "phase4_expertise", field = "_phase4", state = {running = true, gear_id = "resumed-final"}},
				{kind = "phase4_allocate_blessing_batch", field = "_phase4", state = {running = true, gear_id = "resumed-final"}},
				{kind = "phase4_replace_perk", field = "_phase4", state = {running = true, gear_id = "resumed-final"}},
				{kind = "phase4_replace_blessing", field = "_phase4", state = {running = true, gear_id = "resumed-final"}},
				{kind = "favorite", field = "_phase4", state = {running = true, gear_id = "resumed-final"}},
			}

			for _, case in ipairs(cases) do
				local promise = pending()
				local followups = 0
				local controller = Controller.new({backend = {}, planner = Planner, context = context(), settings = base_settings(), reporter = reports()})
				controller[case.field] = case.state
				assert(controller:_dispatch_operation(0, case.kind, function() return promise end, function() followups = followups + 1 end) == true, case.kind)
				assert(controller:stop_active_run() == true, case.kind)
				assert(controller:snapshot().operation_inflight == true, case.kind)
				assert(controller:snapshot().phase == "user_stopped", case.kind)
				promise.next_callback({})
				assert(controller:snapshot().operation_inflight == false, case.kind)
				assert(controller:snapshot().phase == "user_stopped", case.kind)
				assert(followups == 0, case.kind .. " dispatched follow-up after stop")
				assert(controller:stop_active_run() == false, case.kind)
			end
		end

		-- Fast mastery upgrade lane is outside generic operation gate but obeys
		-- same generation guard and cannot pump another upgrade after Stop.
		do
			local upgrade_promise = pending()
			local upgrade_calls = 0
			local backend = {}
			function backend:upgrade_weapon_rarity(_)
				upgrade_calls = upgrade_calls + 1
				return upgrade_promise
			end
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reports()})
			controller._phase3 = {
				running = true,
				fast_upgrade_head = 1,
				fast_upgrade_inflight = {},
				fast_upgrade_inflight_count = 0,
				fast_upgrade_queue = {},
				fast_upgrade_states = {},
			}
			assert(controller:_phase3_queue_fast_upgrade(0, {gear_id = "fast-fodder", rarity = 1}) == true)
			assert(upgrade_calls == 1)
			assert(controller:stop_active_run() == true)
			upgrade_promise.next_callback({})
			assert(upgrade_calls == 1)
			assert(controller:snapshot().phase == "user_stopped")
		end

		-- Idle Brunt selection/config reconciliation is amortized, while active
		-- operation timeout accounting remains frame-driven.
		do
			local selected_reads = 0
			local controller = Controller.new({backend = {}, planner = Planner, context = context(), settings = base_settings(), reporter = reports(), get_selected_offer = function()
				selected_reads = selected_reads + 1
				return raw_offer()
			end})
			controller._snapshot = snapshot_with(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			for _ = 1, 16 do controller:update(0.03) end
			assert(selected_reads == 0)
			controller:update(0.03)
			assert(selected_reads > 0)

			local operation = pending()
			controller._search = {running = true}
			assert(controller:_dispatch_operation(0, "purchase", function() return operation end, function() end) == true)
			controller:update(0.03)
			assert(controller:snapshot().operation_elapsed_seconds >= 0.03)
		end

		-- A confirmed purchase may be temporarily absent from GearService. Poll only
		-- its UUID and never dispatch a second purchase while visibility converges.
		do
			local item = summarized_item("gear-delayed-visibility", 0, 60)
			local backend = {purchase_calls = 0, refresh_calls = 0}
			function backend:purchase_offer(_)
				self.purchase_calls = self.purchase_calls + 1
				return resolved({items = {item}})
			end
			function backend:refresh_gear_snapshot(_)
				self.refresh_calls = self.refresh_calls + 1
				return resolved(self.refresh_calls < 3 and snapshot_with(nil) or snapshot_with(item))
			end
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			CurrentOffer = raw_offer()
			assert(controller:start_purchase_search() == true)
			assert(controller:snapshot().phase == "purchase_confirmation_wait", "unexpected delayed phase " .. tostring(controller:snapshot().phase) .. " error " .. tostring(controller:snapshot().last_error) .. " refreshes " .. tostring(backend.refresh_calls))
			controller:update(0.05)
			assert(backend.purchase_calls == 1 and backend.refresh_calls == 2)
			controller:update(0.1)
			assert(backend.purchase_calls == 1 and backend.refresh_calls == 3)
			assert(controller:snapshot().search.result.gear_id == item.gear_id)
		end

		-- Exhausted visibility polling fails closed with the confirmed UUID. It must
		-- neither rebuy nor allow Stop to dispatch another request.
		do
			local item = summarized_item("gear-never-visible", 0, 60)
			local backend = {purchase_calls = 0, refresh_calls = 0}
			function backend:purchase_offer(_)
				self.purchase_calls = self.purchase_calls + 1
				return resolved({items = {item}})
			end
			function backend:refresh_gear_snapshot(_)
				self.refresh_calls = self.refresh_calls + 1
				return resolved(snapshot_with(nil))
			end
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			CurrentOffer = raw_offer()
			assert(controller:start_purchase_search() == true)
			for _ = 1, 8 do controller:update(0.5) end
			assert(controller:snapshot().phase == "operation_failed")
			assert(string.find(controller:snapshot().last_error, item.gear_id, 1, true) ~= nil)
			assert(string.find(controller:snapshot().last_error, "will not be repeated", 1, true) ~= nil)
			assert(backend.purchase_calls == 1 and backend.refresh_calls == 6)
		end

		-- Stop during purchase visibility reconciliation cancels future polls at the
		-- request boundary; the already-confirmed purchase is neither retried nor used.
		do
			local item = summarized_item("gear-stopped-confirmation", 0, 60)
			local backend = {purchase_calls = 0, refresh_calls = 0}
			function backend:purchase_offer(_)
				self.purchase_calls = self.purchase_calls + 1
				return resolved({items = {item}})
			end
			function backend:refresh_gear_snapshot(_)
				self.refresh_calls = self.refresh_calls + 1
				return resolved(snapshot_with(nil))
			end
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			CurrentOffer = raw_offer()
			assert(controller:start_purchase_search() == true)
			assert(controller:stop_active_run() == true)
			controller:update(1)
			assert(controller:snapshot().phase == "user_stopped")
			assert(backend.purchase_calls == 1 and backend.refresh_calls == 1)
		end

		-- A mutation settling while character identity is temporarily unavailable
		-- must release its gate, suppress continuations, and require reconciliation.
		do
			local active_character = "character-1"
			local operation = pending()
			local followups = 0
			local live_context = {
				current_character_id = function() return active_character end,
				is_valid_brunt_view = function() return true end,
				is_runtime_valid = function() return true end,
			}
			local controller = Controller.new({backend = {}, planner = Planner, context = live_context, settings = base_settings(), reporter = reports()})
			controller._active_view = {}
			controller._view_is_valid = true
			controller._search = {running = true}
			controller._run_character_id = "character-1"
			assert(controller:_dispatch_operation(0, "purchase", function() return operation end, function() followups = followups + 1 end) == true)
			active_character = nil
			operation.next_callback({items = {}})
			local result = controller:snapshot()
			assert(result.operation_inflight == false and result.reconciliation_required == true)
			assert(followups == 0)
		end

		-- Timed-out account mutations remain quarantined until original Promise
		-- settles; no new request can overlap ambiguous backend state.
		do
			local operation = pending()
			local controller = Controller.new({backend = {}, planner = Planner, context = context(), settings = base_settings(), reporter = reports()})
			controller._active_view = {}
			controller._view_is_valid = true
			controller._search = {running = true}
			assert(controller:_dispatch_operation(0, "purchase", function() return operation end, function() error("stale continuation") end) == true)
			controller:update(46)
			assert(controller:snapshot().operation_inflight == true)
			assert(controller:snapshot().operation_quarantined == true)
			assert(controller:_dispatch_operation(controller._generation, "purchase", function() return resolved({}) end, function() end) == false)
			operation.next_callback({items = {}})
			assert(controller:snapshot().operation_inflight == false)
			assert(controller:snapshot().reconciliation_required == true)
		end

		-- Fast-lane settlement outside valid runtime cannot pump another queued
		-- crafting mutation.
		do
			local runtime_valid = true
			local promises = {pending(), pending()}
			local backend = {upgrade_calls = 0}
			function backend:upgrade_weapon_rarity(_)
				self.upgrade_calls = self.upgrade_calls + 1
				return promises[self.upgrade_calls]
			end
			local live_context = {
				current_character_id = function() return "character-1" end,
				is_valid_brunt_view = function() return true end,
				is_runtime_valid = function() return runtime_valid end,
			}
			local controller = Controller.new({backend = backend, planner = Planner, context = live_context, settings = base_settings(), reporter = reports()})
			controller._phase3 = {running = true, fast_upgrade_head = 1, fast_upgrade_inflight = {}, fast_upgrade_inflight_count = 0, fast_upgrade_queue = {}, fast_upgrade_states = {}}
			assert(controller:_phase3_queue_fast_upgrade(0, {gear_id = "fast-a", rarity = 1}) == true)
			assert(controller:_phase3_queue_fast_upgrade(0, {gear_id = "fast-b", rarity = 1}) == true)
			assert(backend.upgrade_calls == 1)
			runtime_valid = false
			promises[1].next_callback({})
			assert(backend.upgrade_calls == 1)
			assert(controller:snapshot().auxiliary_inflight_count == 0)
		end

		-- Fast-upgrade rejection while next purchase is pending quarantines the
		-- purchase instead of clearing its gate and losing its late settlement.
		do
			local upgrade = pending()
			local purchase = pending()
			local backend = {}
			function backend:upgrade_weapon_rarity(_) return upgrade end
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reports()})
			controller._active_view = {}
			controller._view_is_valid = true
			controller._phase3 = {running = true, fast_upgrade_head = 1, fast_upgrade_inflight = {}, fast_upgrade_inflight_count = 0, fast_upgrade_queue = {}, fast_upgrade_states = {}}
			controller._search = {running = true}
			assert(controller:_phase3_queue_fast_upgrade(0, {gear_id = "fast-fail", rarity = 1}) == true)
			assert(controller:_dispatch_operation(0, "purchase", function() return purchase end, function() error("stale purchase continuation") end) == true)
			upgrade.catch_callback("backend rejected")
			assert(controller:snapshot().operation_inflight == true)
			assert(controller:snapshot().operation_quarantined == true)
			purchase.next_callback({items = {{gear_id = "late-purchase"}}})
			assert(controller:snapshot().operation_inflight == false)
			assert(controller:snapshot().reconciliation_required == true)
		end

		-- Auto Crafter must join the shared account-operation arbiter. A held
		-- owner blocks the run before any purchase is dispatched.
		do
			local backend = {purchase_calls = 0}
			function backend:purchase_offer(_)
				self.purchase_calls = self.purchase_calls + 1
				return resolved({})
			end
			local account_operation = {
				acquire = function() return nil end,
				is_current = function() return false end,
			}
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reports(), account_operation = account_operation, get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			CurrentOffer = raw_offer()
			assert(controller:start_purchase_search() == false)
			assert(backend.purchase_calls == 0)
		end

		-- STOP cannot release shared ownership while its already-dispatched
		-- mutation is unresolved. The late settlement releases exactly once.
		do
			local purchase = pending()
			local held_token = nil
			local releases = 0
			local account_operation = {
				acquire = function(owner)
					assert(owner == "auto_crafter" and held_token == nil)
					held_token = 91
					return held_token
				end,
				is_current = function(owner, token)
					return owner == "auto_crafter" and token == held_token
				end,
				release = function(owner, token)
					assert(owner == "auto_crafter" and token == held_token)
					releases = releases + 1
					held_token = nil
					return true
				end,
			}
			local backend = {purchase_calls = 0}
			function backend:purchase_offer(_)
				self.purchase_calls = self.purchase_calls + 1
				return purchase
			end
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reports(), account_operation = account_operation, get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			CurrentOffer = raw_offer()
			assert(controller:start_purchase_search() == true)
			assert(held_token == 91 and backend.purchase_calls == 1)
			assert(controller:stop_active_run() == true)
			assert(held_token == 91 and releases == 0)
			purchase.next_callback({items = {summarized_item("late-owned-purchase", 0, 60)}})
			assert(held_token == nil and releases == 1)
			assert(controller:snapshot().operation_inflight == false)
		end

		-- Every mutation family fails closed on resource/capacity rejection. No
		-- continuation or hidden retry may spend again after the backend rejects.
		do
			local cases = {
				{kind = "purchase", error = "insufficient dockets"},
				{kind = "purchase", error = "inventory full"},
				{kind = "phase4_consecrate", error = "insufficient plasteel"},
				{kind = "phase4_expertise", error = "insufficient plasteel"},
				{kind = "phase4_replace_perk", error = "insufficient diamantine"},
				{kind = "phase4_replace_blessing", error = "insufficient diamantine"},
			}

			for _, case in ipairs(cases) do
				local dispatches = 0
				local followups = 0
				local controller = Controller.new({backend = {}, planner = Planner, context = context(), settings = base_settings(), reporter = reports()})
				controller._active_view = {}
				controller._view_is_valid = true
				controller._search = {running = true}
				assert(controller:_dispatch_operation(0, case.kind, function()
					dispatches = dispatches + 1
					return rejected(case.error)
				end, function() followups = followups + 1 end) == true)
				assert(dispatches == 1 and followups == 0)
				assert(controller:snapshot().operation_inflight == false)
				assert(controller:snapshot().phase == "operation_failed")
				assert(string.find(controller:snapshot().last_error, case.error, 1, true) ~= nil)
			end
		end

		-- A transient 7-second network stall is below the quarantine threshold and
		-- resumes exactly once when the original request settles.
		do
			local operation = pending()
			local followups = 0
			local controller = Controller.new({backend = {}, planner = Planner, context = context(), settings = base_settings(), reporter = reports()})
			controller._active_view = {}
			controller._view_is_valid = true
			controller._search = {running = true}
			assert(controller:_dispatch_operation(0, "purchase", function() return operation end, function() followups = followups + 1 end) == true)
			controller:update(7)
			assert(controller:snapshot().operation_inflight == true)
			assert(controller:snapshot().operation_quarantined == false)
			operation.next_callback({items = {}})
			assert(followups == 1 and controller:snapshot().operation_inflight == false)
		end

		-- Entering a loading/non-hub context stops continuations but preserves the
		-- mutation lock until the backend request settles.
		do
			local operation = pending()
			local followups = 0
			local controller = Controller.new({backend = {}, planner = Planner, context = context(), settings = base_settings(), reporter = reports()})
			controller._active_view = {}
			controller._view_is_valid = true
			controller._search = {running = true}
			assert(controller:_dispatch_operation(0, "phase4_expertise", function() return operation end, function() followups = followups + 1 end) == true)
			controller:on_context_exit("loading")
			assert(controller:snapshot().operation_inflight == true)
			operation.next_callback({})
			assert(followups == 0)
			assert(controller:snapshot().operation_inflight == false)
			assert(controller:snapshot().reconciliation_required == true)
		end

		-- Read-only probe/catalog promises have bounded lifetimes. Late callbacks
		-- after timeout are inert and cannot overwrite the visible failure.
		do
			local probe = pending()
			local backend = {}
			function backend:probe_snapshot() return probe end
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reports()})
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:_schedule_probe("timeout_test") == true)
			controller:update(1)
			assert(controller:snapshot().probe_inflight == true)
			controller:update(46)
			assert(controller:snapshot().probe_inflight == false)
			assert(controller:snapshot().phase == "probe_failed")
			probe.next_callback(snapshot_with(nil))
			assert(controller:snapshot().phase == "probe_failed")
		end

		do
			local catalog = pending()
			local backend = {}
			function backend:discover_weapon_catalog(_) return catalog end
			CurrentOffer = raw_offer()
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:_schedule_catalog("timeout_test") == true)
			controller:update(46)
			assert(controller:snapshot().catalog_inflight == false)
			assert(controller:snapshot().phase == "trait_discovery_failed")
			catalog.next_callback({available = true})
			assert(controller:snapshot().phase == "trait_discovery_failed")
		end

		-- External account writes may stop an active workflow only between backend
		-- requests. An unresolved mutation retains ownership and must be blocked by
		-- the service guard until its original promise settles.
			do
			local controller = Controller.new({backend = {}, planner = Planner, context = context(), settings = base_settings(), reporter = reports()})
			controller._active_view = {}
			controller._view_is_valid = true
			controller._search = {running = true}
			assert(controller:interrupt_for_external_mutation("store.purchase_item") == true)
			assert(controller:snapshot().search.running == false)
			assert(controller:snapshot().phase == "external_mutation_store.purchase_item")

			controller._search = {running = true}
			controller._operation_inflight = true
			assert(controller:interrupt_for_external_mutation("gear.delete_gear_batch") == false)
			assert(controller:snapshot().search.running == true)
			assert(controller:snapshot().operation_inflight == true)

			controller._operation_inflight = false
			controller._auxiliary_inflight_count = 1
			assert(controller:interrupt_for_external_mutation("mastery.purchase_traits") == false)
			assert(controller:snapshot().search.running == true)
		end

		-- Exact custom-stat acquisition is authoritative across all five projected
		-- level-500 stats. Invalid totals fail before account ownership or purchase.
		do
			local function custom_snapshot(item)
				local snapshot = snapshot_with(item)
				snapshot.store.offers[1].base_stats = {
					{name = "damage_stat", display_name_key = "loc_stats_display_damage_stat"},
					{name = "mobility_stat", display_name_key = "loc_stats_display_mobility_stat"},
					{name = "first_target_stat", display_name_key = "loc_stats_display_first_target_stat"},
					{name = "penetration_stat", display_name_key = "loc_stats_display_ap_stat"},
					{name = "defense_stat", display_name_key = "loc_stats_display_defense_stat"},
				}

				return snapshot
			end
			local function custom_item(gear_id, values)
				local item = summarized_item(gear_id, 0, values[1])
				item.base_stats = {
					damage_stat = values[1], mobility_stat = values[2], first_target_stat = values[3],
					penetration_stat = values[4], defense_stat = values[5],
				}
				item.potential_base_stats = {
					damage_stat = values[1], mobility_stat = values[2], first_target_stat = values[3],
					penetration_stat = values[4], defense_stat = values[5],
				}

				return item
			end
			local invalid_backend = {purchase_calls = 0}
			function invalid_backend:purchase_offer(_) self.purchase_calls = self.purchase_calls + 1 return resolved({}) end
			local invalid_reporter = reports()
			local invalid_settings = base_settings({
				auto_crafter_custom_stats = true,
				auto_crafter_custom_stat_1 = 60,
				auto_crafter_custom_stat_2 = 79,
				auto_crafter_custom_stat_3 = 80,
				auto_crafter_custom_stat_4 = 80,
				auto_crafter_custom_stat_5 = 80,
			})
			CurrentOffer = raw_offer()
			local invalid_controller = Controller.new({backend = invalid_backend, planner = Planner, context = context(), settings = invalid_settings, reporter = invalid_reporter, get_selected_offer = function() return CurrentOffer end})
			invalid_controller._snapshot = custom_snapshot(nil)
			invalid_controller._active_view = {}
			invalid_controller._view_is_valid = true
			assert(invalid_controller:start_purchase_search() == false)
			assert(invalid_backend.purchase_calls == 0)
			assert(invalid_reporter.events[#invalid_reporter.events].kind == "mutation_blocked")
			assert(string.find(invalid_reporter.events[#invalid_reporter.events].payload.reason, "expected 380, current 379", 1, true))

			local exact = custom_item("gear-custom-exact", {60, 80, 80, 80, 80})
			local exact_backend = {purchase_calls = 0}
			function exact_backend:purchase_offer(_)
				self.purchase_calls = self.purchase_calls + 1
				return resolved({items = {exact}})
			end
			function exact_backend:probe_snapshot() return resolved(custom_snapshot(exact)) end
			local exact_settings = base_settings({
				auto_crafter_custom_stats = true,
				auto_crafter_custom_stat_1 = 60,
				auto_crafter_custom_stat_2 = 80,
				auto_crafter_custom_stat_3 = 80,
				auto_crafter_custom_stat_4 = 80,
				auto_crafter_custom_stat_5 = 80,
			})
			local exact_controller = Controller.new({backend = exact_backend, planner = Planner, context = context(), settings = exact_settings, reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			exact_controller._snapshot = custom_snapshot(nil)
			exact_controller._active_view = {}
			exact_controller._view_is_valid = true
			assert(exact_controller:start_purchase_search() == true)
			assert(exact_backend.purchase_calls == 1)
			assert(exact_controller:snapshot().search.result.gear_id == "gear-custom-exact")
			assert(exact_controller:snapshot().phase == "phase4_complete")

			local resumed = custom_item("gear-custom-resume", {60, 80, 80, 80, 80})
			resumed.potential_base_stats = {
				alternate_damage_stat = 60,
				alternate_mobility_stat = 80,
				alternate_first_target_stat = 80,
				alternate_penetration_stat = 80,
				alternate_defense_stat = 80,
			}
			resumed.base_stat_labels = {
				alternate_damage_stat = "loc_stats_display_damage_stat",
				alternate_mobility_stat = "loc_stats_display_mobility_stat",
				alternate_first_target_stat = "loc_stats_display_first_target_stat",
				alternate_penetration_stat = "loc_stats_display_ap_stat",
				alternate_defense_stat = "loc_stats_display_defense_stat",
			}
			resumed.master_id = "weapon-alternate-mark"
			resumed.favorite_known = true
			resumed.favorited = false
			local resume_backend = {purchase_calls = 0}
			function resume_backend:purchase_offer(_) self.purchase_calls = self.purchase_calls + 1 return resolved({}) end
			function resume_backend:probe_snapshot() return resolved(custom_snapshot(resumed)) end
			exact_settings.values.auto_crafter_reuse_inventory_base = true
			local resume_controller = Controller.new({backend = resume_backend, planner = Planner, context = context(), settings = exact_settings, reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			resume_controller._snapshot = custom_snapshot(resumed)
			resume_controller._active_view = {}
			resume_controller._view_is_valid = true
			assert(resume_controller:start_purchase_search() == true)
			assert(resume_backend.purchase_calls == 0)
			assert(resume_controller:snapshot().search.result.gear_id == "gear-custom-resume")

			-- Livestream regression: desired 70/70/80/80/80 is unavailable, while
			-- 72/68/80/80/80 is frozen and crafted when docket acquisition cap hits.
			local fallback = custom_item("gear-custom-fallback", {72, 68, 80, 80, 80})
			local fallback_backend = {purchase_calls = 0}
			function fallback_backend:purchase_offer(_)
				self.purchase_calls = self.purchase_calls + 1
				return resolved({items = {fallback}})
			end
			function fallback_backend:probe_snapshot() return resolved(custom_snapshot(fallback)) end
			local fallback_reporter = reports()
			local fallback_settings = base_settings({
				auto_crafter_best_candidate_fallback = true,
				auto_crafter_cap_by_dockets = true,
				auto_crafter_cap_by_max_purchases = false,
				auto_crafter_custom_stats = true,
				auto_crafter_custom_stat_1 = 70,
				auto_crafter_custom_stat_2 = 70,
				auto_crafter_custom_stat_3 = 80,
				auto_crafter_custom_stat_4 = 80,
				auto_crafter_custom_stat_5 = 80,
				auto_crafter_docket_cap = 100,
			})
			local fallback_controller = Controller.new({backend = fallback_backend, planner = Planner, context = context(), settings = fallback_settings, reporter = fallback_reporter, get_selected_offer = function() return CurrentOffer end})
			fallback_controller._snapshot = custom_snapshot(nil)
			fallback_controller._active_view = {}
			fallback_controller._view_is_valid = true
			assert(fallback_controller:start_purchase_search() == true)
			local fallback_result = fallback_controller:snapshot()
			assert(fallback_backend.purchase_calls == 1)
			assert(fallback_result.phase == "phase4_complete")
			assert(fallback_result.search.result.gear_id == "gear-custom-fallback")
			assert(fallback_result.search.fallback_reason == "search_docket_cap")
			assert(fallback_result.search.fallback_target_distance == 4)
			assert(fallback_result.phase4.fallback_target_distance == 4)
			for _, event in ipairs(fallback_reporter.events) do
				assert(event.kind ~= "purchase_search_stopped")
			end
		end

		-- Three-state acquisition preserves legacy checkbox saves, buys exactly one
		-- authoritative weapon in first-weapon mode, and applies <= only to the
		-- single dump-stat policy.
		do
			for _, disabled_value in ipairs({false, "disabled"}) do
				local backend = {purchase_calls = 0}
				function backend:purchase_offer(_) self.purchase_calls = self.purchase_calls + 1 return resolved({}) end
				CurrentOffer = raw_offer()
				local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings({auto_crafter_buy_until_target = disabled_value}), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
				controller._snapshot = snapshot_with(nil)
				controller._active_view = {}
				controller._view_is_valid = true
				assert(controller:start_purchase_search() == false)
				assert(backend.purchase_calls == 0)
				assert(controller:snapshot().phase == "idle")
			end

			for _, target_mode in ipairs({true, "target_search"}) do
				local item = summarized_item("gear-target-mode-" .. tostring(target_mode), 0, 60)
				local backend = {purchase_calls = 0}
				function backend:purchase_offer(_)
					self.purchase_calls = self.purchase_calls + 1
					return resolved({items = {item}})
				end
				function backend:probe_snapshot() return resolved(snapshot_with(item)) end
				CurrentOffer = raw_offer()
				local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings({auto_crafter_buy_until_target = target_mode}), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
				controller._snapshot = snapshot_with(nil)
				controller._active_view = {}
				controller._view_is_valid = true
				assert(controller:start_purchase_search() == true)
				assert(backend.purchase_calls == 1)
				assert(controller:snapshot().phase == "phase4_complete")
			end

			local existing = summarized_item("gear-existing-exact", 0, 60)
			local purchased = summarized_item("gear-first-purchased", 0, 55)
			local state = {items = {existing}}
			local first_backend = {purchase_calls = 0}
			function first_backend:purchase_offer(_)
				self.purchase_calls = self.purchase_calls + 1
				state.items[#state.items + 1] = purchased
				return resolved({items = {purchased}})
			end
			function first_backend:probe_snapshot() return resolved(snapshot_with_items(state.items)) end
			CurrentOffer = raw_offer()
			local first_controller = Controller.new({backend = first_backend, planner = Planner, context = context(), settings = base_settings({auto_crafter_buy_until_target = "first_weapon", auto_crafter_reuse_inventory_base = true}), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			first_controller._snapshot = snapshot_with_items(state.items)
			first_controller._active_view = {}
			first_controller._view_is_valid = true
			assert(first_controller:start_purchase_search() == true)
			local first_result = first_controller:snapshot()
			assert(first_backend.purchase_calls == 1)
			assert(first_result.phase == "phase4_complete")
			assert(first_result.search.result.gear_id == "gear-first-purchased")
			assert(first_result.search.fallback_accepted == true)
			assert(first_result.search.fallback_reason == "first_weapon")

			local at_most = summarized_item("gear-at-most", 0, 55)
			local at_most_backend = {purchase_calls = 0}
			function at_most_backend:purchase_offer(_)
				self.purchase_calls = self.purchase_calls + 1
				return resolved({items = {at_most}})
			end
			function at_most_backend:probe_snapshot() return resolved(snapshot_with(at_most)) end
			CurrentOffer = raw_offer()
			local at_most_controller = Controller.new({backend = at_most_backend, planner = Planner, context = context(), settings = base_settings({auto_crafter_dump_stat_comparison = "at_most"}), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			at_most_controller._snapshot = snapshot_with(nil)
			at_most_controller._active_view = {}
			at_most_controller._view_is_valid = true
			assert(at_most_controller:start_purchase_search() == true)
			local at_most_result = at_most_controller:snapshot()
			assert(at_most_backend.purchase_calls == 1)
			assert(at_most_result.phase == "phase4_complete")
			assert(at_most_result.search.result.gear_id == "gear-at-most")
			assert(at_most_result.search.fallback_accepted ~= true)
		end

		-- A staged-but-idle queue in Psych Ward must not run expensive runtime,
		-- character, view, and native-selection probes every rendered frame.
		do
			local calls = {character = 0, runtime = 0, selection = 0, view = 0}
			local idle_context = {
				current_character_id = function()
					calls.character = calls.character + 1
					return "character-1"
				end,
				is_runtime_valid = function()
					calls.runtime = calls.runtime + 1
					return true
				end,
				is_valid_brunt_view = function()
					calls.view = calls.view + 1
					return true
				end,
			}
			CurrentOffer = raw_offer()
			local controller = Controller.new({
				backend = {},
				planner = Planner,
				context = idle_context,
				settings = base_settings(),
				reporter = reports(),
				get_selected_offer = function()
					calls.selection = calls.selection + 1
					return CurrentOffer
				end,
			})
			controller._snapshot = snapshot_with(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			controller:_refresh_plan("idle_performance_setup")
			for key in pairs(calls) do calls[key] = 0 end

			for _ = 1, 60 do controller:update(1 / 60) end

			assert(calls.runtime <= 2, "idle runtime checks " .. tostring(calls.runtime))
			assert(calls.character <= 2, "idle character checks " .. tostring(calls.character))
			assert(calls.view <= 2, "idle view checks " .. tostring(calls.view))
			assert(calls.selection <= 2, "idle selection checks " .. tostring(calls.selection))
		end

		-- Staging an imported queue owns its parsed trait catalogue. Any native
		-- discovery already running for the Brunt selection must be retired so its
		-- timeout or late completion cannot replace the imported state.
		do
			local native_catalog = pending()
			function native_catalog:cancel() self.cancelled = true end
			local backend = {}
			function backend:discover_weapon_catalog(_) return native_catalog end
			CurrentOffer = raw_offer()
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = base_settings(), reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._snapshot = snapshot_with(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:_schedule_catalog("native_before_import") == true)
			assert(controller:snapshot().catalog_inflight == true)

			local imported_catalog = {available = true, perks = {}, blessings = {}}
			local imported_job = {
				kind = "games_lantern_job",
				offer = target_offer(),
				dump_stat = "damage_stat",
				dump_target = 60,
				perks = {{id = "perk-1", rarity = 4}, {id = "perk-2", rarity = 4}},
				blessings = {{id = "blessing-1", rarity = 4}, {id = "blessing-2", rarity = 4}},
				catalog = imported_catalog,
			}
			assert(controller:set_imported_job(imported_job) == true)
			assert(native_catalog.cancelled == true)
			assert(controller:snapshot().catalog_inflight == false)
			assert(controller:snapshot().catalog == imported_catalog)

			controller:update(46)
			assert(controller:snapshot().phase ~= "trait_discovery_failed")
			assert(controller:snapshot().catalog == imported_catalog)
			native_catalog.next_callback({available = false, reason = "late native result"})
			assert(controller:snapshot().catalog == imported_catalog)
		end

		print("Auto Crafter controller Phase 2/3/4 behavior tests passed.")
        '''
    )


if __name__ == "__main__":
    main()
