from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
CONTROLLER_PATH = RUNTIME_ROOT / "auto_crafter" / "core" / "controller.lua"
PLANNER_PATH = RUNTIME_ROOT / "auto_crafter" / "core" / "planner.lua"


def main() -> None:
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
                auto_crafter_allow_mutations = true,
                auto_crafter_buy_until_target = true,
                auto_crafter_target_dump_stat = "damage_stat",
                auto_crafter_dump_stat_target = 60,
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
				auto_crafter_change_perks = false,
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
                store = {available = true, offer_count = 1, offers = {target_offer()}},
                wallets = {currencies = {credits = {amount = 10000}}},
                gear = {available = true, item_count = #items, items = items},
            }
        end

		function snapshot_with_items(items)
			items = items or {}

			return {
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
                mastery_id = "pattern-1",
                parent_pattern = "pattern-1",
                base_stats = {damage_stat = dump_stat or 50},
                damage = dump_stat or 50,
				potential_base_stats = {damage_stat = dump_stat or 50},
				potential_damage = dump_stat or 50,
                display_name = "Test Weapon",
            }
        end

        function context()
            return {
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
    planner = lua.execute(PLANNER_PATH.read_text(encoding="utf-8"))
    controller_module = lua.execute(CONTROLLER_PATH.read_text(encoding="utf-8"))
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
            local settings = base_settings({auto_crafter_target_dump_stat = "damage"})
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
			local backend = {purchase_promise = pending()}
			function backend:purchase_offer(_) return self.purchase_promise end
			function backend:probe_snapshot() return resolved(snapshot_with(state.item)) end
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
			-- DMF/panel teardown may replay unchanged values. Same-value callbacks are noise,
			-- not user configuration changes, and must not stop frozen background work.
			assert(controller:on_setting_changed("auto_crafter_target_dump_stat") == true)
			assert(controller:on_setting_changed("auto_crafter_dump_stat_target") == true)
			assert(controller:snapshot().search.running == true)
			state.item = summarized_item("gear-background", 0, 60)
			backend.purchase_promise.next_callback({items = {state.item}})
			assert(controller:snapshot().search.running == false)
			assert(controller:snapshot().search.result.gear_id == "gear-background")
			assert(controller:snapshot().phase == "search_complete")
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
			assert(reporter.events[#reporter.events - 1].kind == "candidate_favorited")
			assert(reporter.events[#reporter.events].kind == "purchase_search_complete")
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
			assert(controller:snapshot().phase == "phase3_complete")
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

        -- Phase 3 fallback reserves one live best candidate instead of sacrificing it.
        do
            local state = {item = nil}
            local backend = {purchase_calls = 0, extract_calls = 0}
            function backend:purchase_offer(_)
                self.purchase_calls = self.purchase_calls + 1
                state.item = summarized_item("gear-best", 0, 55)
                return resolved({items = {state.item}})
            end
            function backend:probe_snapshot() return resolved(snapshot_with(state.item)) end
            function backend:get_mastery_by_pattern(_) return resolved({mastery_id = "pattern-1", current_xp = 100, mastery_level = 5, claimed_level = 4, mastery_max_level = 20}) end
            function backend:extract_weapon_mastery(_, _) self.extract_calls = self.extract_calls + 1 return resolved({}) end

            local settings = base_settings({auto_crafter_level_mastery_20 = true, auto_crafter_best_candidate_fallback = true})
            CurrentOffer = raw_offer()
            local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = settings, reporter = reports(), get_selected_offer = function() return CurrentOffer end})
            controller._snapshot = snapshot_with(nil)
            controller._active_view = {}
            controller._view_is_valid = true
            assert(controller:start_purchase_search() == true)
            local result = controller:snapshot()
            assert(backend.purchase_calls == 1)
            assert(backend.extract_calls == 0)
            assert(result.search.running == false)
            assert(result.search.result.gear_id == "gear-best")
            assert(result.phase == "search_max_purchases")
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
			assert(reporter.events[#reporter.events - 1].kind == "inventory_base_selected")
		end

		-- Phase 4 serially consecrates, advances 100-level milestones, allocates
		-- a selected blessing, replaces targets, and verifies every refresh.
		do
			local item = summarized_item("gear-final", 3, 60)
			item.favorite_known = true
			item.favorited = false
			item.expertise_level = 330
			item.perks = {{id = "old_perk", rarity = 4}, {id = "keep_perk", rarity = 4}}
			item.traits = {{id = "old_blessing", rarity = 4}, {id = "keep_blessing", rarity = 4}}
			local state = {sticker_seen = false}
			local backend = {purchase_calls = 0, rarity_calls = 0, expertise_calls = 0, perk_calls = 0, blessing_calls = 0, allocation_calls = 0}
			function backend:purchase_offer(_) self.purchase_calls = self.purchase_calls + 1 return resolved({items = {item}}) end
			function backend:probe_snapshot() return resolved(snapshot_with(item)) end
			function backend:get_mastery_by_pattern(_) return resolved({mastery_id = "pattern-1", current_xp = 999, mastery_level = 20, claimed_level = 19, mastery_max_level = 20}) end
			function backend:upgrade_weapon_rarity(_) self.rarity_calls = self.rarity_calls + 1 item.rarity = item.rarity + 1 return resolved({}) end
			function backend:add_weapon_expertise(_, target) self.expertise_calls = self.expertise_calls + 1 item.expertise_level = target return resolved({}) end
			function backend:purchase_mastery_trait(_, id, tier) assert(id == "new_blessing" and tier == 4) self.allocation_calls = self.allocation_calls + 1 state.sticker_seen = true return resolved({}) end
			function backend:get_trait_sticker_book(_) return resolved({{id = "new_blessing", tiers = {{tier = 4, status = state.sticker_seen and "seen" or "unseen"}}}}) end
			function backend:replace_perk(_, index, id, tier) self.perk_calls = self.perk_calls + 1 item.perks[index] = {id = id, rarity = tier} return resolved({}) end
			function backend:replace_blessing(_, index, id, tier) self.blessing_calls = self.blessing_calls + 1 item.traits[index] = {id = id, rarity = tier} return resolved({}) end

			local settings = base_settings({
				auto_crafter_consecrate_transcendent = true,
				auto_crafter_upgrade_expertise_500 = true,
				auto_crafter_allocate_mastery_points = true,
				auto_crafter_level_mastery_20 = true,
				auto_crafter_change_perks = true,
				auto_crafter_change_blessings = true,
				auto_crafter_perk_1_target = "perk:new_perk:4",
				auto_crafter_perk_2_target = "keep",
				auto_crafter_blessing_1_target = "new_blessing",
				auto_crafter_blessing_2_target = "keep",
			})
			CurrentOffer = raw_offer()
			local controller = Controller.new({backend = backend, planner = Planner, context = context(), settings = settings, reporter = reports(), get_selected_offer = function() return CurrentOffer end})
			controller._catalog = {
				available = true,
				trait_category = "test_category",
				perks = {{id = "new_perk", tier = 4}},
				blessings = {{id = "new_blessing", tiers = {{tier = 4, status = "unseen"}}}},
			}
			controller._snapshot = snapshot_with(nil)
			controller._active_view = {}
			controller._view_is_valid = true
			assert(controller:start_purchase_search() == true)
			local result = controller:snapshot()
			assert(result.phase == "phase4_complete", tostring(result.phase) .. " " .. tostring(result.last_error))
			assert(item.rarity == 5 and item.expertise_level == 500)
			assert(backend.rarity_calls == 2 and backend.expertise_calls == 2)
			assert(backend.allocation_calls == 1 and backend.perk_calls == 1 and backend.blessing_calls == 1)
			assert(item.perks[1].id == "new_perk" and item.traits[1].id == "new_blessing")
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
        end

		print("Auto Crafter controller Phase 2/3/4 behavior tests passed.")
        '''
    )


if __name__ == "__main__":
    main()
