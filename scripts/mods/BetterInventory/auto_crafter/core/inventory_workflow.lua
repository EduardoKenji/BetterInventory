local InventoryWorkflow = {}

function InventoryWorkflow.install(self, services)
	local candidate_matches_stat_targets = services.candidate_matches_stat_targets
	local candidate_stat = services.candidate_stat
	local candidate_stat_target_distance = services.candidate_stat_target_distance
	local find_item = services.find_item
	local has_trait_targets = services.has_trait_targets
	local operation_context_valid = services.operation_context_valid
	local operation_report = services.operation_report
	local pending_deferred_count = services.pending_deferred_count
	local pending_fodder_reaches_target = services.pending_fodder_reaches_target
	local same_trait = services.same_trait
	local setting = services.setting
	local track_purchased_spare = services.track_purchased_spare
	local trait_at = services.trait_at
	local unseen_blessing_tier_count = services.unseen_blessing_tier_count
	local MAX_EXPERTISE_LEVEL = services.constants.MAX_EXPERTISE_LEVEL
	local PHASE3_FODDER_BATCH_SIZE = services.constants.PHASE3_FODDER_BATCH_SIZE
	local TRANSCENDENT_RARITY = services.constants.TRANSCENDENT_RARITY

	local function imported_dump_stat(job)
		return job and (job.resolved_dump_stat or job.dump_stat)
	end

	function self:_imported_family_matches(candidate, job)
		local expected_pattern = job and (job.parent_pattern or job.offer and job.offer.parent_pattern)
		local candidate_pattern = candidate and (candidate.parent_pattern or candidate.mastery_id)

		return expected_pattern ~= nil and candidate_pattern ~= nil and expected_pattern == candidate_pattern
	end

	function self:_imported_item_is_complete(item, job)
		local catalog = job and job.catalog

		if not self:_imported_family_matches(item, job) or item.available ~= true or item.gear_id == nil or job.dump_stat == nil or job.dump_target == nil or type(catalog) ~= "table" or catalog.available ~= true then
			return false
		end

		local mastery_enabled = setting("auto_crafter_level_mastery_20", true) == true
		local allocate_mastery = mastery_enabled and setting("auto_crafter_allocate_mastery_points", true) == true
		local change_perks = mastery_enabled and setting("auto_crafter_change_perks", true) == true
		local change_blessings = mastery_enabled and setting("auto_crafter_change_blessings", true) == true
		local mastery = catalog.mastery

		if mastery_enabled and (type(mastery) ~= "table" or (tonumber(mastery.mastery_level) or -1) < 20 or (tonumber(mastery.claimed_level) or -1) < 19) then
			return false
		end
		if allocate_mastery and (#(catalog.blessings or {}) == 0 or unseen_blessing_tier_count(catalog.blessings) > 0) then
			return false
		end

		return candidate_matches_stat_targets(item, imported_dump_stat(job), job.dump_target, job.custom_stats_enabled and job.custom_stat_targets or nil, job.dump_stat_identity, job.dump_comparison)
			and (setting("auto_crafter_consecrate_transcendent", true) ~= true or (tonumber(item.rarity) or -1) >= TRANSCENDENT_RARITY)
			and (setting("auto_crafter_upgrade_expertise_500", true) ~= true or (tonumber(item.expertise_level) or -1) >= MAX_EXPERTISE_LEVEL)
			and (not change_perks or has_trait_targets(item.perks, job.perks))
			and (not change_blessings or has_trait_targets(item.traits, job.blessings))
	end

	function self:_has_resumable_imported_job(job)
		if setting("auto_crafter_reuse_inventory_base", true) ~= true then
			return false
		end

		local include_favorites = setting("auto_crafter_include_favorite_inventory_bases", true) == true
		for _, candidate in ipairs(self._snapshot and self._snapshot.gear and self._snapshot.gear.items or {}) do
			local favorite_allowed = include_favorites or candidate.favorite_known == true and candidate.favorited ~= true
			if candidate.available == true and candidate.gear_id ~= nil and candidate.equipped ~= true and favorite_allowed and self:_imported_family_matches(candidate, job) and candidate_matches_stat_targets(candidate, imported_dump_stat(job), job.dump_target, job.custom_stats_enabled and job.custom_stat_targets or nil, job.dump_stat_identity, job.dump_comparison) and not self:_imported_item_is_complete(candidate, job) then
				return true
			end
		end

		return false
	end

	function self:_imported_job_inventory_decision(job)
		if self:_has_resumable_imported_job(job) then
			return "resume"
		end

		local completed = self:_completed_imported_job_result(job)
		if completed and setting("auto_crafter_craft_duplicate_completed_queued_weapons", false) ~= true then
			return "skip", completed
		end

		return "new"
	end

	function self:_find_inventory_base()
		local search = self._search

		if not search or setting("auto_crafter_reuse_inventory_base", true) ~= true then
			return nil
		end

		local include_favorites = setting("auto_crafter_include_favorite_inventory_bases", true) == true
		local best
		local best_analysis
		local target = search.target_offer or {}
		local imported_job = self._run_imported_job or self._imported_job

		local function family_matches(candidate)
			if imported_job then
				return self:_imported_family_matches(candidate, imported_job), "mastery_family"
			end

			local target_pattern = target.parent_pattern
			local candidate_pattern = candidate.parent_pattern or candidate.mastery_id

			if target_pattern ~= nil and candidate_pattern ~= nil then
				return target_pattern == candidate_pattern, "mastery_family"
			end

			if target.master_id ~= nil and candidate.master_id ~= nil then
				return target.master_id == candidate.master_id, "master_item"
			end

			if target.weapon_template ~= nil and candidate.weapon_template ~= nil then
				return target.weapon_template == candidate.weapon_template, "weapon_template"
			end

			return false, "identity_unavailable"
		end

		local function profile_analysis(candidate)
			local names = {}

			for key, stat in pairs(type(target.base_stats) == "table" and target.base_stats or {}) do
				local name = type(stat) == "table" and stat.name or type(key) == "string" and key or nil

				if name ~= nil then
					names[tostring(name)] = type(stat) == "table" and {
						display_name_key = stat.display_name_key,
						name = tostring(name),
					} or { name = tostring(name) }
				end
			end

			local expected = 0
			local known = 0
			local non_dump_min = math.huge
			local non_dump_sum = 0
			local all_other_stats_maxed = true

			for name, identity in pairs(names) do
				expected = expected + 1
				local value = tonumber(candidate_stat(candidate, name, identity))

				if value ~= nil then
					known = known + 1

					if name ~= search.dump_stat then
						non_dump_min = math.min(non_dump_min, value)
						non_dump_sum = non_dump_sum + value
						all_other_stats_maxed = all_other_stats_maxed and value >= 80
					end
				elseif name ~= search.dump_stat then
					all_other_stats_maxed = false
				end
			end

			if non_dump_min == math.huge then
				non_dump_min = -1
			end

			return {
				all_other_stats_maxed = expected > 1 and known == expected and all_other_stats_maxed,
				expected_stats = expected,
				known_stats = known,
				non_dump_min = non_dump_min,
				non_dump_sum = non_dump_sum,
			}
		end

		local function remaining_steps(candidate)
			local steps = 0

			if setting("auto_crafter_consecrate_transcendent", true) == true then
				steps = steps + math.max(0, 5 - (tonumber(candidate.rarity) or 0))
			end

			if setting("auto_crafter_upgrade_expertise_500", true) == true then
				steps = steps + math.max(0, math.ceil((500 - (tonumber(candidate.expertise_level) or 0)) / 100))
			end

			if search.favorite_result and candidate.favorited ~= true then
				steps = steps + 1
			end

			local targets = self:_phase4_targets(candidate)

			if type(targets) == "table" then
				for index = 1, 2 do
					if targets.perks[index] and not same_trait(trait_at(candidate.perks, index), targets.perks[index]) then
						steps = steps + 1
					end

					if targets.traits[index] and not same_trait(trait_at(candidate.traits, index), targets.traits[index]) then
						steps = steps + 1
					end
				end
			end

			return steps
		end

		local function analysis_is_better(left, right)
			if not right then
				return true
			end

			if left.all_other_stats_maxed ~= right.all_other_stats_maxed then
				return left.all_other_stats_maxed
			end

			if left.known_stats ~= right.known_stats then
				return left.known_stats > right.known_stats
			end

			if left.non_dump_min ~= right.non_dump_min then
				return left.non_dump_min > right.non_dump_min
			end

			if left.non_dump_sum ~= right.non_dump_sum then
				return left.non_dump_sum > right.non_dump_sum
			end

			if left.remaining_steps ~= right.remaining_steps then
				return left.remaining_steps < right.remaining_steps
			end

			if left.expertise ~= right.expertise then
				return left.expertise > right.expertise
			end

			if left.rarity ~= right.rarity then
				return left.rarity > right.rarity
			end

			return left.gear_id < right.gear_id
		end

		for _, candidate in ipairs(self._snapshot and self._snapshot.gear and self._snapshot.gear.items or {}) do
			local matched, identity_source = family_matches(candidate)
			local favorite_allowed = include_favorites or candidate.favorite_known == true and candidate.favorited ~= true

			local imported_complete = imported_job and self:_imported_item_is_complete(candidate, imported_job)
			if candidate.available == true and candidate.gear_id ~= nil and candidate.equipped ~= true and matched and favorite_allowed and not imported_complete and candidate_matches_stat_targets(candidate, search.dump_stat, search.target_dump, search.custom_stat_targets, search.dump_stat_identity, search.dump_comparison) then
				local analysis = profile_analysis(candidate)
				analysis.expertise = tonumber(candidate.expertise_level) or -1
				analysis.family_identity = identity_source
				analysis.gear_id = tostring(candidate.gear_id)
				analysis.rarity = tonumber(candidate.rarity) or -1
				analysis.remaining_steps = remaining_steps(candidate)

				if analysis_is_better(analysis, best_analysis) then
					best = candidate
					best_analysis = analysis
				end
			end
		end

		if best then
			best.resume_analysis = best_analysis
		end

		return best
	end

	function self:_purchase_search_step(generation)
		if not operation_context_valid(generation) then
			return false
		end

		local search = self._search
		local target = search and search.target_offer
		local max_purchases = tonumber(search and search.max_purchases) or 0
		local price = tonumber(target and (target.price_amount or target.price))
		local credits
		local phase3 = self._phase3
		local phase3_has_target = phase3 and phase3.running and phase3.target_candidate ~= nil
		local function flush_pending_fodder()
			if phase3 and phase3.running and phase3.target_candidate and pending_deferred_count(phase3) > 0 then
				self:_phase3_process_deferred(generation, phase3.current)

				return true
			end

			return false
		end
		local function finish_acquisition(reason)
			if not phase3_has_target and setting("auto_crafter_best_candidate_fallback", true) == true and search.best then
				if self:_accept_fallback_candidate(generation, search.best, reason) then
					return true
				end
			end

			self:_stop_search(reason)

			return false
		end

		if not search or not search.running or not target or not price or price <= 0 then
			self:_stop_search("search_blocked")

			return false
		end

		if not phase3_has_target and search.cap_by_max_purchases and search.purchases >= max_purchases then
			if flush_pending_fodder() then
				return true
			end

			return finish_acquisition("search_max_purchases")
		end

		if not phase3_has_target and search.cap_by_dockets and search.spent + price > search.docket_cap then
			if flush_pending_fodder() then
				return true
			end

			return finish_acquisition("search_docket_cap")
		end

		local snapshot_wallets = self._snapshot and self._snapshot.wallets
		local currency = snapshot_wallets and snapshot_wallets.currencies and snapshot_wallets.currencies.credits

		credits = tonumber(currency and currency.amount)

		if credits and credits < price then
			if flush_pending_fodder() then
				return true
			end

			return finish_acquisition("search_insufficient_dockets")
		end

		local raw_offer = search.raw_offer

		if not raw_offer then
			self:_stop_search("search_offer_missing")

			return false
		end

		local backend = self._backend

		if not backend or type(backend.purchase_offer) ~= "function" then
			self:_operation_failed(generation, "purchase adapter unavailable")

			return false
		end

		return self:_dispatch_operation(generation, "purchase", function ()
			return backend:purchase_offer(raw_offer)
		end, function (purchase)
			local purchase_candidate = purchase and purchase.items and purchase.items[1]

			if not purchase_candidate or not purchase_candidate.gear_id then
				self:_operation_failed(generation, "purchase result did not expose a weapon id")

				return
			end

			search.purchases = search.purchases + 1
			search.spent = search.spent + price

			if purchase.wallets and self._snapshot then
				self._snapshot.wallets = purchase.wallets
			end

			if phase3_has_target then
				if purchase_candidate.available ~= true or purchase_candidate.parent_pattern ~= phase3.target_candidate.mastery_id or purchase_candidate.rarity == nil or purchase_candidate.expertise_level == nil then
					self:_operation_failed(generation, "post-target fodder purchase omitted required identity, rarity, or expertise")

					return
				end

				track_purchased_spare(phase3, purchase_candidate)
				phase3.deferred_candidates[#phase3.deferred_candidates + 1] = purchase_candidate
				self:_phase3_queue_fast_upgrade(generation, purchase_candidate)
				search.last = purchase_candidate
				self._last_purchased = purchase_candidate
				operation_report("phase3_fast_fodder_purchase", {
					candidate = purchase_candidate,
					count = pending_deferred_count(phase3),
					search = search,
				})

				local projection_reaches_target, projected_xp = pending_fodder_reaches_target(phase3)
				operation_report("phase3_pending_fodder_projected", {
					count = pending_deferred_count(phase3),
					expected_xp = projected_xp,
				})

				if projection_reaches_target or pending_deferred_count(phase3) >= PHASE3_FODDER_BATCH_SIZE then
					self:_phase3_process_deferred(generation, phase3.current)
				else
					self:_purchase_search_step(generation)
				end

				return
			end

			local function process_candidate(candidate)
				if not candidate or candidate.available ~= true then
					self:_operation_failed(generation, "purchased weapon was not found in authoritative inventory")

					return
				end

				if target.parent_pattern and candidate.parent_pattern ~= target.parent_pattern then
					self:_operation_failed(generation, "purchased weapon family did not match frozen target")

					return
				end

				local dump_stat = candidate_stat(candidate, search.dump_stat, search.dump_stat_identity)

				if dump_stat == nil then
					self:_operation_failed(generation, "authoritative weapon did not expose configured dump stat")

					return
				end

				candidate.dump_stat = dump_stat
				candidate.dump_stat_id = search.dump_stat
				candidate.dump_stat_label = search.dump_stat_identity and search.dump_stat_identity.display_name_key or candidate.base_stat_labels and candidate.base_stat_labels[search.dump_stat]
				candidate.damage = candidate.potential_damage or candidate_stat(candidate, "damage")
				candidate.exact_match = candidate_matches_stat_targets(candidate, search.dump_stat, search.target_dump, search.custom_stat_targets, search.dump_stat_identity, search.dump_comparison)
				candidate.target_distance = candidate_stat_target_distance(candidate, search.dump_stat, search.target_dump, search.custom_stat_targets, search.dump_stat_identity)

				local accepts_first_weapon = search.acquisition_mode == "first_weapon" and not phase3_has_target

				if self._phase3 and self._phase3.running and not candidate.exact_match and not accepts_first_weapon then
					track_purchased_spare(self._phase3, candidate)
				end
				search.last = candidate
				self._last_purchased = candidate

				if self:_candidate_is_better(candidate, search.best) then
					search.best = candidate
				end

				operation_report("purchase_result", {
					candidate = candidate,
					search = search,
				})

				if candidate.exact_match and not phase3_has_target then
					self:_accept_exact_candidate(generation, candidate, "purchase")
				elseif accepts_first_weapon then
					self:_accept_fallback_candidate(generation, candidate, "first_weapon")
				elseif self._phase3 and self._phase3.running and self._phase3.defer_bad_processing and not self._phase3.target_candidate then
					self._phase3.deferred_candidates[#self._phase3.deferred_candidates + 1] = candidate
					operation_report("phase3_candidate_deferred", {
						candidate = candidate,
						count = #self._phase3.deferred_candidates,
					})
					self:_purchase_search_step(generation)
				elseif self._phase3 and self._phase3.running then
					self:_phase3_check_mastery(generation, candidate)
				else
					self:_purchase_search_step(generation)
				end
			end

			operation_report("purchase_response_received", {
				candidate = purchase_candidate,
			})
			self:_begin_purchase_confirmation(generation, purchase_candidate, process_candidate)
		end)
	end

	return true
end

return InventoryWorkflow
