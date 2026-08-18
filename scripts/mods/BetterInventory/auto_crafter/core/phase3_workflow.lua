local Phase3Workflow = {}

function Phase3Workflow.install(self, services)
	local candidate_matches_stat_targets = services.candidate_matches_stat_targets
	local candidate_stat = services.candidate_stat
	local candidate_stat_target_distance = services.candidate_stat_target_distance
	local estimated_fodder_xp = services.estimated_fodder_xp
	local extraction_contains_all = services.extraction_contains_all
	local fast_upgrade_pending = services.fast_upgrade_pending
	local find_item = services.find_item
	local mastery_claims_converged = services.mastery_claims_converged
	local mastery_level_target_xp = services.mastery_level_target_xp
	local mastery_poll_delay = services.mastery_poll_delay
	local mastery_summary = services.mastery_summary
	local mastery_target_reached = services.mastery_target_reached
	local operation_report = services.operation_report
	local pending_deferred_count = services.pending_deferred_count
	local pending_fodder_reaches_target = services.pending_fodder_reaches_target
	local remove_snapshot_gear = services.remove_snapshot_gear
	local setting = services.setting
	local PHASE3_FODDER_BATCH_SIZE = services.constants.PHASE3_FODDER_BATCH_SIZE
	local REDEEMED_RARITY = services.constants.REDEEMED_RARITY

	function self:_phase3_finish(current)
		local phase3 = self._phase3
		local search = self._search
		local target = phase3 and phase3.target_candidate
		local item = target and find_item(self._snapshot and self._snapshot.gear and self._snapshot.gear.items, target.gear_id)

		if not phase3 or not phase3.running or not target or not search then
			return false
		end

		phase3.current = current or phase3.current

		if mastery_target_reached(phase3.current) and not mastery_claims_converged(phase3.current) then
			if not phase3.current_data then
				self:_operation_failed(self._generation, "mastery level 20 reached but raw state is unavailable for missing tier claims")

				return false
			end

			return self:_phase3_sync_projected(self._generation)
		end

		local target_matches = candidate_matches_stat_targets(item, search.dump_stat, search.target_dump, search.custom_stat_targets, search.dump_stat_identity, search.dump_comparison)
		local fallback_distance = search.fallback_accepted and candidate_stat_target_distance(item, search.dump_stat, search.target_dump, search.custom_stat_targets, search.dump_stat_identity) or nil
		local fallback_matches = fallback_distance ~= nil and fallback_distance ~= math.huge and fallback_distance == search.fallback_target_distance

		if not item or item.available ~= true or item.parent_pattern ~= target.mastery_id or not target_matches and not fallback_matches then
			self:_operation_failed(self._generation, search.custom_stats_enabled and "Phase 3 target failed authoritative family or custom-stat reconciliation" or "Phase 3 target failed authoritative family or dump-stat reconciliation")

			return false
		end

		phase3.running = false
		search.running = false
		search.result = phase3.target_candidate
		self._phase = "phase3_complete"
		operation_report("phase3_complete", {
			candidate = phase3.target_candidate,
			current = phase3.current,
			fodder_count = phase3.fodder_count,
			search = search,
		})
		operation_report("phase3_timing_summary", {
			current = phase3.current,
			timings = self._operation_timings,
		})
		self:_start_phase4(phase3.target_candidate)

		return true
	end

	function self:_phase3_discard_deferred(generation, current)
		local phase3 = self._phase3
		local backend = self._backend

		if not phase3 or not phase3.running or not phase3.target_candidate then
			return false
		end

		if phase3.cleanup_started then
			return false
		end

		phase3.cleanup_started = true
		self._phase = "phase3_deferred_cleanup_preflight"

		return self:_refresh_after_operation(generation, function (snapshot)
			local target = phase3.target_candidate
			local queue = phase3.deferred_candidates or {}
			local cleanup_candidates = phase3.purchased_spares or queue
			local gear_ids = {}
			local included = {}

			for _, queued in ipairs(cleanup_candidates) do
				local item = queued and find_item(snapshot and snapshot.gear and snapshot.gear.items, queued.gear_id)

				if item and not included[item.gear_id] then
					if item.available ~= true or item.gear_id == target.gear_id or item.parent_pattern ~= target.mastery_id then
						if item.gear_id == target.gear_id then
							included[item.gear_id] = true
						else
							self:_operation_failed(generation, "run-owned spare cleanup failed authoritative family protection")

							return
						end
					else
						included[item.gear_id] = true
						gear_ids[#gear_ids + 1] = item.gear_id
					end
				end
			end

			if #gear_ids == 0 then
				phase3.deferred_index = #queue + 1
				self:_phase3_finish(current)

				return
			end

			if not backend or type(backend.discard_items) ~= "function" then
				self:_operation_failed(generation, "deferred weapon discard adapter unavailable")

				return
			end

			self:_dispatch_operation(generation, "phase3_deferred_cleanup", function ()
				return backend:discard_items(gear_ids)
			end, function ()
				self:_refresh_after_operation(generation, function (updated_snapshot)
					for _, gear_id in ipairs(gear_ids) do
						if find_item(updated_snapshot and updated_snapshot.gear and updated_snapshot.gear.items, gear_id) then
							self:_operation_failed(generation, "deferred weapon discard was not confirmed by authoritative inventory")

							return
						end
					end

					phase3.deferred_index = #queue + 1
					operation_report("phase3_deferred_cleanup_complete", {
						count = #gear_ids,
						current = current,
					})
					self:_phase3_finish(current)
				end)
			end)
		end)
	end

	function self:_phase3_process_deferred(generation, current)
		local phase3 = self._phase3

		if not phase3 or not phase3.running or not phase3.target_candidate then
			return false
		end

		if fast_upgrade_pending(phase3) then
			phase3.fast_purchase_paused = true
			self._phase = "phase3_fast_upgrade_wait"
			self:_phase3_pump_fast_upgrades(generation)

			return true
		end

		if mastery_target_reached(current) and phase3.projected_xp_pending then
			return self:_phase3_sync_projected(generation)
		elseif mastery_target_reached(current) then
			return self:_phase3_discard_deferred(generation, current)
		end

		local queue = phase3.deferred_candidates or {}

		if queue[phase3.deferred_index or 1] then
			return self:_phase3_start_deferred_batch(generation)
		end

		return self:_purchase_search_step(generation)
	end

	function self:_phase3_extract_deferred_batch(generation)
		local phase3 = self._phase3
		local backend = self._backend
		local batch = phase3 and phase3.deferred_batch

		if not phase3 or not phase3.running or not batch or #batch.gear_ids == 0 or not backend or type(backend.extract_weapon_mastery) ~= "function" then
			self:_operation_failed(generation, "deferred mastery extraction batch became invalid")

			return false
		end

		return self:_dispatch_operation(generation, "mastery_sacrifice_batch", function ()
			return backend:extract_weapon_mastery(batch.mastery_id, batch.gear_ids)
		end, function (result)
			local amount = tonumber(result and result.amount) or 0

			if amount <= 0 or not extraction_contains_all(result and result.gear_ids, batch.gear_ids) then
				self:_operation_failed(generation, "batched mastery extraction did not confirm every fodder item")

				return
			end

			local projected = type(backend.project_mastery) == "function" and backend:project_mastery(phase3.current_data, amount) or nil
			local current = mastery_summary(projected)

			if not projected or not current or current.current_xp == nil or current.mastery_level == nil then
				self:_operation_failed(generation, "local mastery projection failed after batched extraction")

				return
			end

			remove_snapshot_gear(self._snapshot, batch.gear_ids)
			phase3.current = current
			phase3.current_data = projected
			phase3.projected_xp_pending = true
			phase3.fodder_count = phase3.fodder_count + #batch.gear_ids
			phase3.deferred_index = batch.queue_end + 1
			phase3.deferred_batch = nil
			operation_report("phase3_fodder_batch_complete", {
				amount = amount,
				count = #batch.gear_ids,
				current = current,
				fodder_count = phase3.fodder_count,
			})

			if mastery_target_reached(current) then
				self:_phase3_sync_projected(generation)
			else
				self:_purchase_search_step(generation)
			end
		end)
	end

	function self:_phase3_upgrade_deferred_batch(generation)
		local phase3 = self._phase3
		local backend = self._backend
		local batch = phase3 and phase3.deferred_batch

		if not phase3 or not phase3.running or not batch then
			return false
		end

		local item = batch.items[batch.upgrade_index]

		if not item then
			return self:_phase3_extract_deferred_batch(generation)
		end

		if batch.upgrade_index == 1 and type(backend and backend.upgrade_weapon_rarities) == "function" then
			local gear_ids = {}

			for _, pending_item in ipairs(batch.items) do
				if tonumber(pending_item.rarity) == nil or pending_item.rarity < REDEEMED_RARITY then
					gear_ids[#gear_ids + 1] = pending_item.gear_id
				end
			end

			if #gear_ids == 0 then
				batch.upgrade_index = #batch.items + 1

				return self:_phase3_extract_deferred_batch(generation)
			end

			operation_report("phase3_fodder_batch_upgrade_started", {
				count = #gear_ids,
			})

			return self:_dispatch_operation(generation, "mastery_upgrade_batch", function ()
				return backend:upgrade_weapon_rarities(gear_ids)
			end, function ()
				for _, pending_item in ipairs(batch.items) do
					pending_item.rarity = math.max(tonumber(pending_item.rarity) or 0, REDEEMED_RARITY)
				end

				batch.upgrade_index = #batch.items + 1
				operation_report("phase3_fodder_batch_upgrade_complete", {
					count = #gear_ids,
				})
				self:_phase3_extract_deferred_batch(generation)
			end)
		end

		if tonumber(item.rarity) and item.rarity >= REDEEMED_RARITY then
			batch.upgrade_index = batch.upgrade_index + 1

			return self:_phase3_upgrade_deferred_batch(generation)
		end

		if not backend or type(backend.upgrade_weapon_rarity) ~= "function" then
			self:_operation_failed(generation, "batched fodder rarity upgrade adapter unavailable")

			return false
		end

		return self:_dispatch_operation(generation, "mastery_upgrade_batch_item", function ()
			return backend:upgrade_weapon_rarity(item.gear_id)
		end, function ()
			item.rarity = REDEEMED_RARITY
			batch.upgrade_index = batch.upgrade_index + 1
			self:_phase3_upgrade_deferred_batch(generation)
		end)
	end

	function self:_phase3_start_deferred_batch(generation)
		local phase3 = self._phase3

		if not phase3 or not phase3.running or not phase3.current_data or phase3.deferred_batch then
			return false
		end

		return self:_refresh_after_operation(generation, function (snapshot)
			local queue = phase3.deferred_candidates or {}
			local start_index = phase3.deferred_index or 1
			local items = {}
			local gear_ids = {}
			local queue_end = start_index - 1

			local target_xp = mastery_level_target_xp(phase3.current_data, 20)
			local projected_xp = tonumber(phase3.current and phase3.current.current_xp)

			for index = start_index, math.min(#queue, start_index + PHASE3_FODDER_BATCH_SIZE - 1) do
				local candidate = queue[index]
				local item = candidate and find_item(snapshot and snapshot.gear and snapshot.gear.items, candidate.gear_id)

				if item then
					if item.available ~= true or item.gear_id == phase3.target_candidate.gear_id or item.parent_pattern ~= phase3.target_candidate.mastery_id then
						self:_operation_failed(generation, "deferred mastery batch failed authoritative family protection")

						return
					end

					items[#items + 1] = item
					gear_ids[#gear_ids + 1] = item.gear_id
					local amount = estimated_fodder_xp(item)

					if projected_xp and amount then
						projected_xp = projected_xp + amount
					else
						projected_xp = nil
					end
				end

				queue_end = index

				if target_xp and projected_xp and projected_xp >= target_xp then
					break
				end
			end

			if #gear_ids == 0 then
				phase3.deferred_index = queue_end + 1
				self:_purchase_search_step(generation)

				return
			end

			phase3.deferred_batch = {
				gear_ids = gear_ids,
				items = items,
				mastery_id = phase3.target_candidate.mastery_id,
				queue_end = queue_end,
				upgrade_index = 1,
			}
			self._phase = "phase3_deferred_batch_upgrade"
			self:_phase3_upgrade_deferred_batch(generation)
		end)
	end

	function self:_phase3_sync_projected(generation)
		local phase3 = self._phase3
		local backend = self._backend
		local projected_data = phase3 and phase3.current_data
		local projected = mastery_summary(projected_data)

		if not phase3 or not phase3.running or not projected_data or not mastery_target_reached(projected) then
			self:_operation_failed(generation, "projected mastery level 20 state became unavailable before final claim")

			return false
		end

		if self._mastery and self._mastery.running then
			self:_operation_failed(generation, "projected mastery claim collided with an active mastery operation")

			return false
		end

		if not backend or type(backend.claim_mastery_levels) ~= "function" then
			self:_operation_failed(generation, "projected mastery claim adapter unavailable")

			return false
		end

		self._mastery = {
			before = phase3.authoritative_current or projected,
			expected_xp = projected.current_xp,
			mastery_id = projected.mastery_id or phase3.target_candidate and phase3.target_candidate.mastery_id,
			on_complete = function (current)
				local active = self._phase3

				self._mastery = nil

				if not active or not active.running then
					return
				end

				active.current = current
				active.current_data = nil
				active.projected_xp_pending = false

				if active.defer_bad_processing and active.target_candidate then
					self:_phase3_discard_deferred(generation, current)
				else
					self:_phase3_finish(current)
				end
			end,
			phase3 = true,
			claim_retries = 0,
			running = true,
		}
		self._phase = "phase3_mastery_claim"

		return self:_dispatch_operation(generation, "mastery_claim", function ()
			return backend:claim_mastery_levels(projected_data, 0)
		end, function (result)
			if self:_complete_mastery_sync(generation, mastery_summary(result), "claim_result") then
				return
			end

			self._mastery_poll_elapsed = 0
			self._mastery_poll_attempts = 0
			self._mastery_poll_wait = mastery_poll_delay(0)
			self._phase = "mastery_sync_wait"
			operation_report("mastery_sync_started", {
				expected_xp = projected.current_xp,
			})
		end)
	end

	function self:_phase3_start_fodder(generation, candidate)
		local phase3 = self._phase3

		if not phase3 or not phase3.running or not candidate or not candidate.gear_id or not candidate.mastery_id then
			self:_operation_failed(generation, "Phase 3 fodder candidate is missing gear or mastery identity")

			return false
		end

		if self._operation_inflight or self._mastery and self._mastery.running then
			return false
		end

		self._mastery = {
			candidate = candidate,
			claim_retries = 0,
			gear_id = candidate.gear_id,
			mastery_id = candidate.mastery_id,
			on_complete = function (current)
				local active_phase3 = self._phase3

				if not active_phase3 or not active_phase3.running then
					return
				end

				active_phase3.fodder_count = active_phase3.fodder_count + 1
				active_phase3.current = current
				operation_report("phase3_fodder_complete", {
					candidate = candidate,
					current = current,
					fodder_count = active_phase3.fodder_count,
				})
				self._mastery = nil

				if active_phase3.defer_bad_processing and active_phase3.target_candidate then
					self:_phase3_process_deferred(generation, current)
				elseif active_phase3.target_candidate and mastery_target_reached(current) then
					self:_phase3_sync_projected(generation)
				else
					self:_purchase_search_step(generation)
				end
			end,
			phase3 = true,
			running = true,
		}
		self._phase = "phase3_fodder_preflight"
		operation_report("phase3_fodder_started", {
			candidate = candidate,
			current = phase3.current,
		})

		local refreshed = self:_refresh_after_operation(generation, function (snapshot)
			self:_mastery_after_refresh(generation, snapshot)
		end)

		if not refreshed then
			if generation == self._generation and phase3.running then
				self:_operation_failed(generation, "Phase 3 fodder authoritative refresh could not start")
			end
		end

		return refreshed
	end

	function self:_phase3_check_mastery(generation, candidate)
		local phase3 = self._phase3
		local target = phase3 and (phase3.target_candidate or candidate)
		local backend = self._backend

		if not phase3 or not phase3.running or not target or not target.mastery_id then
			self:_operation_failed(generation, "Phase 3 mastery target identity is missing")

			return false
		end

		if not backend or type(backend.get_mastery_by_pattern) ~= "function" then
			self:_operation_failed(generation, "Phase 3 mastery read adapter is unavailable")

			return false
		end

		local function handle_mastery(data)
			local current = mastery_summary(data)
			local candidate_is_target = phase3.target_candidate and candidate and phase3.target_candidate.gear_id == candidate.gear_id

			if not current or current.mastery_level == nil then
				self:_operation_failed(generation, "Phase 3 authoritative mastery response omitted level data")

				return
			end

			phase3.current = current
			phase3.current_data = data
			if not phase3.projected_xp_pending then
				phase3.authoritative_current = current
			end
			operation_report("phase3_mastery_check_complete", {
				candidate = candidate,
				current = current,
			})

			if phase3.defer_bad_processing and phase3.target_candidate and candidate and not candidate_is_target then
				phase3.deferred_candidates[#phase3.deferred_candidates + 1] = candidate
				local projection_reaches_target, projected_xp = pending_fodder_reaches_target(phase3)
				operation_report("phase3_pending_fodder_projected", {
					count = pending_deferred_count(phase3),
					expected_xp = projected_xp,
				})

				if mastery_target_reached(current) then
					self:_phase3_discard_deferred(generation, current)
				elseif projection_reaches_target or pending_deferred_count(phase3) >= PHASE3_FODDER_BATCH_SIZE then
					self:_phase3_process_deferred(generation, current)
				else
					self:_purchase_search_step(generation)
				end
			elseif phase3.defer_bad_processing and phase3.target_candidate then
				self:_phase3_process_deferred(generation, current)
			elseif phase3.target_candidate and mastery_target_reached(current) then
				if phase3.projected_xp_pending then
					self:_phase3_sync_projected(generation)
				else
					self:_phase3_finish(current)
				end
			elseif candidate and not candidate_is_target and not mastery_target_reached(current) then
				if setting("auto_crafter_best_candidate_fallback", true) == true then
					local reserved = phase3.fallback_candidate

					if not reserved then
						phase3.fallback_candidate = candidate
						self:_purchase_search_step(generation)
					elseif self:_candidate_is_better(candidate, reserved) then
						phase3.fallback_candidate = candidate
						self:_phase3_start_fodder(generation, reserved)
					else
						self:_phase3_start_fodder(generation, candidate)
					end
				else
					if self._search and self._search.best == candidate then
						self._search.best = nil
					end

					self:_phase3_start_fodder(generation, candidate)
				end
			elseif phase3.target_candidate and phase3.fallback_candidate and not mastery_target_reached(current) then
				local fallback_candidate = phase3.fallback_candidate

				phase3.fallback_candidate = nil
				self:_phase3_start_fodder(generation, fallback_candidate)
			else
				self:_purchase_search_step(generation)
			end
		end

		if phase3.current_data then
			handle_mastery(phase3.current_data)

			return true
		end

		return self:_dispatch_operation(generation, "phase3_mastery_check", function ()
			return backend:get_mastery_by_pattern(target.mastery_id)
		end, handle_mastery)
	end

	function self:_accept_exact_candidate(generation, candidate, source)
		local search = self._search
		local backend = self._backend

		if not search or not search.running or not candidate or not candidate.gear_id then
			return false
		end

		candidate.dump_stat = candidate_stat(candidate, search.dump_stat, search.dump_stat_identity)
		candidate.dump_stat_id = search.dump_stat
		candidate.dump_stat_label = search.dump_stat_identity and search.dump_stat_identity.display_name_key or candidate.base_stat_labels and candidate.base_stat_labels[search.dump_stat]
		candidate.damage = candidate.potential_damage or candidate_stat(candidate, "damage")
		candidate.exact_match = candidate_matches_stat_targets(candidate, search.dump_stat, search.target_dump, search.custom_stat_targets, search.dump_stat_identity, search.dump_comparison)
		candidate.target_distance = candidate_stat_target_distance(candidate, search.dump_stat, search.target_dump, search.custom_stat_targets, search.dump_stat_identity)

		if not candidate.exact_match then
			return false
		end

		local function continue_exact_match()
			search.result = candidate
			search.last = candidate
			search.best = candidate

			if self._phase3 and self._phase3.running then
				self._phase3.target_candidate = candidate
			end

			self._phase = "search_complete"
			operation_report("purchase_search_complete", {
				candidate = candidate,
				reused_inventory = source == "inventory",
				search = search,
			})

			if self._phase3 and self._phase3.running then
				self:_phase3_check_mastery(generation, candidate)
			else
				self:_start_phase4(candidate)
			end
		end

		if source == "inventory" then
			operation_report("inventory_base_selected", {
				candidate = candidate,
			})
		end

		if search.favorite_result and candidate.favorited ~= true then
			if not backend or type(backend.favorite_item) ~= "function" then
				self:_operation_failed(generation, "favorite adapter unavailable")
				return false
			end

			return self:_dispatch_operation(generation, "favorite", function ()
				return backend:favorite_item(candidate.gear_id)
			end, function ()
				candidate.favorited = true
				candidate.favorite_known = true
				operation_report("candidate_favorited", {
					candidate = candidate,
				})
				continue_exact_match()
			end)
		end

		continue_exact_match()

		return true
	end

	function self:_accept_fallback_candidate(generation, candidate, reason)
		local search = self._search
		local backend = self._backend

		if not search or not search.running or not candidate or not candidate.gear_id or candidate.available ~= true then
			return false
		end

		candidate.dump_stat = candidate_stat(candidate, search.dump_stat, search.dump_stat_identity)
		candidate.dump_stat_id = search.dump_stat
		candidate.dump_stat_label = search.dump_stat_identity and search.dump_stat_identity.display_name_key or candidate.base_stat_labels and candidate.base_stat_labels[search.dump_stat]
		candidate.damage = candidate.potential_damage or candidate_stat(candidate, "damage")
		candidate.exact_match = false
		candidate.target_distance = candidate_stat_target_distance(candidate, search.dump_stat, search.target_dump, search.custom_stat_targets, search.dump_stat_identity)

		if candidate.target_distance == math.huge then
			return false
		end

		local function continue_fallback()
			search.result = candidate
			search.last = candidate
			search.best = candidate
			search.fallback_accepted = true
			search.fallback_reason = reason
			search.fallback_target_distance = candidate.target_distance

			local phase3 = self._phase3
			if phase3 and phase3.running then
				local retained = {}
				for _, deferred in ipairs(phase3.deferred_candidates or {}) do
					if deferred and deferred.gear_id ~= candidate.gear_id then
						retained[#retained + 1] = deferred
					end
				end
				phase3.deferred_candidates = retained
				phase3.deferred_index = 1
				phase3.fallback_candidate = phase3.fallback_candidate and phase3.fallback_candidate.gear_id ~= candidate.gear_id and phase3.fallback_candidate or nil
				phase3.target_candidate = candidate
				phase3.target_distance = candidate.target_distance
			end

			self._phase = "search_fallback_selected"
			operation_report("purchase_search_fallback_selected", {
				candidate = candidate,
				reason = reason,
				search = search,
			})
			operation_report("purchase_search_complete", {
				candidate = candidate,
				fallback = true,
				reason = reason,
				search = search,
			})

			if phase3 and phase3.running then
				self:_phase3_check_mastery(generation, candidate)
			else
				self:_start_phase4(candidate)
			end
		end

		if search.favorite_result and candidate.favorited ~= true then
			if not backend or type(backend.favorite_item) ~= "function" then
				self:_operation_failed(generation, "favorite adapter unavailable")
				return false
			end

			return self:_dispatch_operation(generation, "favorite", function ()
				return backend:favorite_item(candidate.gear_id)
			end, function ()
				candidate.favorited = true
				candidate.favorite_known = true
				operation_report("candidate_favorited", {
					candidate = candidate,
				})
				continue_fallback()
			end)
		end

		continue_fallback()

		return true
	end

	return true
end

return Phase3Workflow
