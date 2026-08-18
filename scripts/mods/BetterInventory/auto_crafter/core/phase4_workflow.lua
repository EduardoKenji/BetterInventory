local Phase4Workflow = {}

function Phase4Workflow.install(self, services)
	local blessing_poll_delay = services.blessing_poll_delay
	local candidate_matches_stat_targets = services.candidate_matches_stat_targets
	local candidate_stat_target_distance = services.candidate_stat_target_distance
	local clock_now = services.clock_now
	local copy_stat_identity = services.copy_stat_identity
	local copy_stat_targets = services.copy_stat_targets
	local find_item = services.find_item
	local has_pending_trait_replacement = services.has_pending_trait_replacement
	local has_trait_targets = services.has_trait_targets
	local mastery_allocation_operations = services.mastery_allocation_operations
	local mastery_allocation_progress = services.mastery_allocation_progress
	local operation_report = services.operation_report
	local parse_perk_target = services.parse_perk_target
	local release_account_operation_if_settled = services.release_account_operation_if_settled
	local release_backend_read_cache_if_settled = services.release_backend_read_cache_if_settled
	local requires_temporary_swap = services.requires_temporary_swap
	local same_optional_trait = services.same_optional_trait
	local same_trait = services.same_trait
	local setting = services.setting
	local sticker_status = services.sticker_status
	local temporary_swap_trait = services.temporary_swap_trait
	local trait_at = services.trait_at
	local unseen_blessing_tier_count = services.unseen_blessing_tier_count
	local wallet_consumption = services.wallet_consumption
	local wallet_values = services.wallet_values
	local MAX_BLESSING_SYNC_ATTEMPTS = services.constants.MAX_BLESSING_SYNC_ATTEMPTS
	local MAX_EXPERTISE_LEVEL = services.constants.MAX_EXPERTISE_LEVEL
	local TRANSCENDENT_RARITY = services.constants.TRANSCENDENT_RARITY

	local function matches_frozen_fallback(item, phase4)
		local expected = tonumber(phase4 and phase4.fallback_target_distance)

		if not item or not phase4 or phase4.fallback_accepted ~= true or expected == nil or expected == math.huge then
			return false
		end

		local actual = candidate_stat_target_distance(item, phase4.dump_stat, phase4.target_dump, phase4.custom_stat_targets, phase4.dump_stat_identity)

		return actual ~= math.huge and actual == expected
	end

	local function catalog_choice(catalog, value, current_trait, excluded_id, is_perk)
		if value == "keep" then
			return nil
		end

		local explicit = is_perk and parse_perk_target(value) or nil

		for _, entry in ipairs(catalog or {}) do
			local highest = entry.tier

			if not is_perk then
				for _, tier in ipairs(entry.tiers or {}) do
					highest = math.max(tonumber(highest) or 0, tonumber(tier.tier) or 0)
				end
			end

			local matches_explicit = explicit and entry.id == explicit.id and tonumber(highest) == tonumber(explicit.rarity)
			local matches_blessing = not is_perk and value ~= "auto" and entry.id == value
			local matches_auto = value == "auto" and entry.id ~= excluded_id and (not current_trait or entry.id ~= current_trait.id)

			if matches_explicit or matches_blessing or matches_auto then
				return {
					id = entry.id,
					rarity = explicit and explicit.rarity or tonumber(highest),
				}
			end
		end

		return nil
	end

	function self:_phase4_targets(item)
		local imported_job = self._run_imported_job or self._imported_job
		local catalog = imported_job and imported_job.catalog or self._search and self._search.catalog or self._catalog
		local mastery_enabled = setting("auto_crafter_level_mastery_20", true) == true
		local allocate_mastery = mastery_enabled and setting("auto_crafter_allocate_mastery_points", true) == true
		local change_perks = mastery_enabled and setting("auto_crafter_change_perks", true) == true
		local change_blessings = mastery_enabled and setting("auto_crafter_change_blessings", true) == true

		if type(catalog) ~= "table" or catalog.available ~= true then
			return nil, "weapon perk/blessing catalogue unavailable"
		end

		local targets = {
			perks = {},
			traits = {},
		}
		local perk_values = imported_job and { imported_job.perks[1], imported_job.perks[2] } or {
			setting("auto_crafter_perk_1_target"),
			setting("auto_crafter_perk_2_target"),
		}
		local blessing_values = imported_job and { imported_job.blessings[1], imported_job.blessings[2] } or {
			setting("auto_crafter_blessing_1_target"),
			setting("auto_crafter_blessing_2_target"),
		}

		if change_perks then
			for index = 1, 2 do
				local excluded = targets.perks[index == 1 and 2 or 1]
				local peer_index = index == 1 and 2 or 1
				local kept_peer = perk_values[peer_index] == "keep" and trait_at(item.perks, peer_index) or nil
				targets.perks[index] = imported_job and {
					id = perk_values[index] and perk_values[index].id,
					rarity = perk_values[index] and perk_values[index].rarity,
				} or catalog_choice(catalog.perks, perk_values[index], trait_at(item.perks, index), excluded and excluded.id or kept_peer and kept_peer.id, true)

				if imported_job then
					if not targets.perks[index] or not targets.perks[index].id then
						return nil, "imported perk target is unavailable"
					end
				elseif perk_values[index] ~= "keep" and not targets.perks[index] then
					return nil, "selected Tier IV perk target is unavailable"
				end
			end
		end

		if change_blessings then
			for index = 1, 2 do
				local excluded = targets.traits[index == 1 and 2 or 1]
				local peer_index = index == 1 and 2 or 1
				local kept_peer = blessing_values[peer_index] == "keep" and trait_at(item.traits, peer_index) or nil
				targets.traits[index] = imported_job and {
					id = blessing_values[index] and blessing_values[index].id,
					rarity = blessing_values[index] and blessing_values[index].rarity,
				} or catalog_choice(catalog.blessings, blessing_values[index], trait_at(item.traits, index), excluded and excluded.id or kept_peer and kept_peer.id, false)

				if imported_job then
					if not targets.traits[index] or not targets.traits[index].id then
						return nil, "imported blessing target is unavailable"
					end
				elseif blessing_values[index] ~= "keep" and not targets.traits[index] then
					return nil, "selected blessing target is unavailable"
				end
			end
		end

		if targets.perks[1] and targets.perks[2] and targets.perks[1].id == targets.perks[2].id then
			return nil, "perk targets must be different"
		end
		if targets.perks[1] and perk_values[2] == "keep" and targets.perks[1].id == (trait_at(item.perks, 2) or {}).id or targets.perks[2] and perk_values[1] == "keep" and targets.perks[2].id == (trait_at(item.perks, 1) or {}).id then
			return nil, "selected perk duplicates a kept perk"
		end

		if targets.traits[1] and targets.traits[2] and targets.traits[1].id == targets.traits[2].id then
			return nil, "blessing targets must be different"
		end
		if targets.traits[1] and blessing_values[2] == "keep" and targets.traits[1].id == (trait_at(item.traits, 2) or {}).id or targets.traits[2] and blessing_values[1] == "keep" and targets.traits[2].id == (trait_at(item.traits, 1) or {}).id then
			return nil, "selected blessing duplicates a kept blessing"
		end

		return targets
	end

	function self:_phase4_complete(item, snapshot)
		local phase4 = self._phase4

		if not phase4 or not phase4.running then
			return false
		end

		if phase4.verify_completion then
			local invalid_reason

			if not item or item.available ~= true or item.gear_id ~= phase4.gear_id then
				invalid_reason = "final weapon is absent from authoritative inventory"
			elseif phase4.mastery_id ~= nil and (item.parent_pattern or item.mastery_id) ~= phase4.mastery_id then
				invalid_reason = "final weapon changed weapon family"
			elseif phase4.target_mark_id ~= nil and item.master_id ~= phase4.target_mark_id then
				invalid_reason = "final weapon mark does not match the selected mark"
			elseif not candidate_matches_stat_targets(item, phase4.dump_stat, phase4.target_dump, phase4.custom_stat_targets, phase4.dump_stat_identity, phase4.dump_comparison) and not matches_frozen_fallback(item, phase4) then
				invalid_reason = phase4.custom_stats_enabled and "final weapon changed custom stats" or "final weapon changed dump stat"
			elseif phase4.consecrate and (tonumber(item.rarity) or -1) < TRANSCENDENT_RARITY then
				invalid_reason = "final weapon is below Transcendent"
			elseif phase4.expertise and (tonumber(item.expertise_level) or -1) < MAX_EXPERTISE_LEVEL then
				invalid_reason = "final weapon is below item level 500"
			elseif not has_trait_targets(item.perks, phase4.targets and phase4.targets.perks) then
				invalid_reason = "final weapon perks do not match targets"
			elseif not has_trait_targets(item.traits, phase4.targets and phase4.targets.traits) then
				invalid_reason = "final weapon blessings do not match targets"
			elseif phase4.allocate_mastery and unseen_blessing_tier_count(phase4.sticker_book) > 0 then
				invalid_reason = "final weapon mastery points are not fully allocated"
			elseif phase4.favorite_result and item.favorited ~= true then
				invalid_reason = "final weapon favorite state was not preserved"
			end

			if invalid_reason then
				self:_operation_failed(self._generation, invalid_reason)

				return false
			end
		end

		local completed_at = clock_now()
		local elapsed = completed_at and self._run_started_at and math.max(0, completed_at - self._run_started_at) or math.max(0, self._run_elapsed or 0)
		local resource_costs = wallet_consumption(self._search and self._search.start_wallet, wallet_values(snapshot or self._snapshot))

		phase4.running = false
		phase4.result = item
		phase4.completed_at = completed_at
		phase4.elapsed_seconds = elapsed
		phase4.resource_costs = resource_costs
		if self._search then
			self._search.running = false
			self._search.result = item
			self._search.elapsed_seconds = elapsed
		end
		self._phase = "phase4_complete"
		operation_report("phase4_complete", {
			candidate = item,
			elapsed_seconds = elapsed,
			phase4 = phase4,
			resource_costs = resource_costs,
		})
		release_account_operation_if_settled()
		release_backend_read_cache_if_settled()

		return true
	end

	function self:_phase4_step(generation, snapshot)
		local phase4 = self._phase4
		local backend = self._backend
		local item = phase4 and find_item(snapshot and snapshot.gear and snapshot.gear.items, phase4.gear_id)

		if not phase4 or not phase4.running then
			return false
		end

		if phase4.pending_blessing then
			return true
		end

		local target_matches = item and candidate_matches_stat_targets(item, phase4.dump_stat, phase4.target_dump, phase4.custom_stat_targets, phase4.dump_stat_identity, phase4.dump_comparison)
		local fallback_matches = matches_frozen_fallback(item, phase4)

		if not item or item.available ~= true or item.parent_pattern ~= phase4.mastery_id or not target_matches and not fallback_matches then
			self:_operation_failed(generation, "final weapon failed authoritative identity or level-500 stat verification")

			return false
		end

		phase4.current_item = item

		if phase4.consecrate and (tonumber(item.rarity) or -1) < TRANSCENDENT_RARITY then
			if not backend or type(backend.upgrade_weapon_rarity) ~= "function" then
				self:_operation_failed(generation, "final rarity upgrade adapter unavailable")
				return false
			end

			local before = tonumber(item.rarity) or -1
			return self:_dispatch_operation(generation, "phase4_consecrate", function ()
				return backend:upgrade_weapon_rarity(phase4.gear_id)
			end, function ()
				self:_refresh_after_operation(generation, function (updated)
					local upgraded = find_item(updated and updated.gear and updated.gear.items, phase4.gear_id)

					if not upgraded or (tonumber(upgraded.rarity) or -1) <= before then
						self:_operation_failed(generation, "final rarity upgrade was not confirmed")
						return
					end
					self:_phase4_step(generation, updated)
				end)
			end)
		end

		local expertise = tonumber(item.expertise_level)

		if phase4.expertise and (expertise == nil or expertise < MAX_EXPERTISE_LEVEL) then
			if expertise == nil then
				self:_operation_failed(generation, "final weapon expertise is unavailable")
				return false
			end

			if not backend or type(backend.add_weapon_expertise) ~= "function" then
				self:_operation_failed(generation, "weapon expertise adapter unavailable")
				return false
			end

			local target_level = math.min(MAX_EXPERTISE_LEVEL, (math.floor(expertise / 100) + 1) * 100)

			return self:_dispatch_operation(generation, "phase4_expertise", function ()
				return backend:add_weapon_expertise(phase4.gear_id, target_level)
			end, function ()
				self:_refresh_after_operation(generation, function (updated)
					local upgraded = find_item(updated and updated.gear and updated.gear.items, phase4.gear_id)

					if not upgraded or (tonumber(upgraded.expertise_level) or -1) < target_level then
						self:_operation_failed(generation, "weapon level milestone was not confirmed")
						return
					end
					operation_report("phase4_expertise_milestone", {
						candidate = upgraded,
						level = tonumber(upgraded.expertise_level),
					})
					self:_phase4_step(generation, updated)
				end)
			end)
		end

		-- Trait mutations remain gated by an authoritative level-500 snapshot.
		local trait_replacement_pending = has_pending_trait_replacement(item.perks, phase4.targets.perks)
			or has_pending_trait_replacement(item.traits, phase4.targets.traits)

		if trait_replacement_pending and (expertise == nil or expertise < MAX_EXPERTISE_LEVEL) then
			self:_operation_failed(generation, "perk or blessing replacement was blocked until the weapon is authoritatively item level 500")

			return false
		end

		if not phase4.replacement_baseline then
			phase4.replacement_baseline = {
				perks = { trait_at(item.perks, 1), trait_at(item.perks, 2) },
				traits = { trait_at(item.traits, 1), trait_at(item.traits, 2) },
			}
		else
			for _, group in ipairs({ "perks", "traits" }) do
				for index = 1, 2 do
					if not same_optional_trait(trait_at(item[group], index), phase4.replacement_baseline[group][index]) then
						self:_operation_failed(generation, "final weapon perks or blessings changed outside the active run")
						return false
					end
				end
			end
		end

		local blessing_targets_pending = false

		for index = 1, 2 do
			local desired = phase4.targets.traits[index]

			if desired and sticker_status(phase4.sticker_book, desired.id, desired.rarity) ~= "seen" then
				blessing_targets_pending = true
			end
		end

		local blessing_points_spent, blessing_points_total, unseen_blessing_tiers = mastery_allocation_progress(phase4.sticker_book, phase4.mastery_costs)
		phase4.blessing_points_spent = blessing_points_spent
		phase4.blessing_points_total = blessing_points_total
		phase4.blessing_tiers_remaining = unseen_blessing_tiers

		if blessing_targets_pending or phase4.allocate_mastery and unseen_blessing_tiers > 0 then
			if not phase4.allocate_mastery then
				self:_operation_failed(generation, "selected blessing tier is not allocated in mastery")
				return false
			end

			if not backend or type(backend.purchase_mastery_traits) ~= "function" or type(backend.get_trait_sticker_book) ~= "function" or type(backend.get_mastery_trait_costs) ~= "function" then
				self:_operation_failed(generation, "mastery blessing allocation adapter unavailable")
				return false
			end

			local operations, allocation_error = mastery_allocation_operations(phase4.sticker_book, phase4.targets.traits, phase4.mastery_costs)

			if not operations or #operations == 0 then
				self:_operation_failed(generation, allocation_error or "mastery blessing allocation prerequisites could not be resolved")
				return false
			end

			self._phase = "phase4_allocate_blessing_batch"
			phase4.blessing_operations_pending = #operations

			return self:_dispatch_operation(generation, "phase4_allocate_blessing_batch", function ()
				return backend:purchase_mastery_traits(phase4.mastery_id, operations)
			end, function ()
				phase4.pending_blessing = {
					operations = operations,
				}
				phase4.blessing_poll_attempts = 0
				phase4.blessing_poll_elapsed = 0
				phase4.blessing_poll_wait = blessing_poll_delay(0)
				self._phase = "phase4_blessing_sync"
				operation_report("phase4_blessing_allocation_batch_submitted", {
					count = #operations,
				})
			end)
		end

		local replacement_groups = {
			{ adapter = "replace_perk", current = item.perks, kind = "perk", source = "perks", targets = phase4.targets.perks },
			{ adapter = "replace_blessing", current = item.traits, kind = "blessing", source = "traits", targets = phase4.targets.traits },
		}

		for _, group in ipairs(replacement_groups) do
			local replacement_index
			local replacement_target
			local temporary_swap = false

			for index = 1, 2 do
				local desired = group.targets[index]
				local current = trait_at(group.current, index)

				if desired and not same_trait(current, desired) then
					local peer = trait_at(group.current, index == 1 and 2 or 1)

					if not peer or peer.id ~= desired.id then
						replacement_index = index
						break
					end
				end
			end

			if not replacement_index then
				for index = 1, 2 do
					local desired = group.targets[index]
					local current = trait_at(group.current, index)

					if desired and not same_trait(current, desired) then
						replacement_target = temporary_swap_trait(group.kind, group.current, group.targets, phase4.catalog, phase4.sticker_book)

						if not replacement_target then
							self:_operation_failed(generation, group.kind .. " two-slot swap has no safe temporary target")
							return false
						end

						replacement_index = index
						temporary_swap = true
						break
					end
				end
			end

			if replacement_index then
				local index = replacement_index
				local desired = replacement_target or group.targets[index]
				local adapter = backend and backend[group.adapter]

				if type(adapter) ~= "function" then
					self:_operation_failed(generation, group.kind .. " replacement adapter unavailable")
					return false
				end

				if temporary_swap then
					operation_report("phase4_temporary_swap_started", {
						gear_id = phase4.gear_id,
						kind = group.kind,
					})
				end

				operation_report("phase4_trait_mutation_preflight", {
					gear_id = phase4.gear_id,
					kind = group.kind,
					slot = index,
					target = desired.id,
					tier = desired.rarity,
				})

				return self:_dispatch_operation(generation, temporary_swap and "phase4_temporary_swap_" .. group.kind or "phase4_replace_" .. group.kind, function ()
					return adapter(backend, phase4.gear_id, index, desired.id, desired.rarity)
				end, function ()
					self:_refresh_after_operation(generation, function (updated)
						local changed = find_item(updated and updated.gear and updated.gear.items, phase4.gear_id)
						local changed_traits = changed and (group.kind == "perk" and changed.perks or changed.traits)

						if not same_trait(trait_at(changed_traits, index), desired) then
							self:_operation_failed(generation, group.kind .. " replacement was not confirmed")
							return
						end
						phase4.replacement_baseline[group.source][index] = desired
						self:_phase4_step(generation, updated)
					end)
				end)
			end
		end

		if phase4.target_mark_id and item.master_id ~= phase4.target_mark_id then
			if not backend or type(backend.switch_mark) ~= "function" then
				self:_operation_failed(generation, "weapon mark switch adapter unavailable")
				return false
			end

			local target_mark_id = phase4.target_mark_id
			self._phase = "phase4_switch_mark"
			operation_report("phase4_mark_switch_started", {
				gear_id = phase4.gear_id,
				mark_id = target_mark_id,
			})

			return self:_dispatch_operation(generation, "phase4_switch_mark", function ()
				return backend:switch_mark(phase4.gear_id, target_mark_id)
			end, function ()
				self:_refresh_after_operation(generation, function (updated)
					local changed = find_item(updated and updated.gear and updated.gear.items, phase4.gear_id)

					if not changed or changed.master_id ~= target_mark_id then
						self:_operation_failed(generation, "selected weapon mark switch was not confirmed")
						return
					end

					operation_report("phase4_mark_switch_confirmed", {
						candidate = changed,
						mark_id = target_mark_id,
					})
					self:_phase4_step(generation, updated)
				end)
			end)
		end

		if not phase4.final_reconcile_started then
			phase4.final_reconcile_started = true
			self._phase = "phase4_final_reconcile"

			return self:_refresh_after_operation(generation, function (updated_snapshot)
				local completed_item = find_item(updated_snapshot and updated_snapshot.gear and updated_snapshot.gear.items, phase4.gear_id)

				if not completed_item or completed_item.available ~= true then
					self:_operation_failed(generation, "final crafted weapon was not found during authoritative reconciliation")

					return
				end

				self:_phase4_complete(completed_item, updated_snapshot)
			end, "runtime")
		end

		return false
	end

	function self:_poll_phase4_blessing()
		local phase4 = self._phase4
		local pending = phase4 and phase4.pending_blessing
		local generation = self._generation
		local backend = self._backend

		if not phase4 or not phase4.running or not pending or self._operation_inflight then
			return false
		end

		if not backend or type(backend.get_trait_sticker_book) ~= "function" then
			self:_operation_failed(generation, "fresh blessing sticker-book adapter unavailable")
			return false
		end

		phase4.blessing_poll_elapsed = 0

		return self:_dispatch_operation(generation, "phase4_verify_blessing", function ()
			return backend:get_trait_sticker_book(phase4.trait_category, true)
		end, function (sticker_book)
			phase4.sticker_book = sticker_book

			local all_seen = true

			for _, operation in ipairs(pending.operations or {}) do
				if sticker_status(sticker_book, operation.trait_id, operation.rarity) ~= "seen" then
					all_seen = false
					break
				end
			end

			if all_seen then
				phase4.pending_blessing = nil
				phase4.blessing_operations_pending = 0
				phase4.blessing_poll_attempts = 0
				phase4.blessing_poll_wait = blessing_poll_delay(0)
				phase4.blessing_points_spent, phase4.blessing_points_total, phase4.blessing_tiers_remaining = mastery_allocation_progress(sticker_book, phase4.mastery_costs)
				operation_report("phase4_blessing_allocation_confirmed", {
					points_spent = phase4.blessing_points_spent,
					points_total = phase4.blessing_points_total,
					count = #(pending.operations or {}),
				})
				self:_phase4_step(generation, self._snapshot)
				return
			end

			phase4.blessing_poll_attempts = (phase4.blessing_poll_attempts or 0) + 1

			if phase4.blessing_poll_attempts >= MAX_BLESSING_SYNC_ATTEMPTS then
				self:_operation_failed(generation, "mastery blessing allocation did not synchronize after bounded polling")
				return
			end

			phase4.blessing_poll_wait = blessing_poll_delay(phase4.blessing_poll_attempts)
			self._phase = "phase4_blessing_sync"
		end)
	end

	function self:_start_phase4(candidate)
		if not candidate or not candidate.gear_id then
			self:_operation_failed(self._generation, "final crafting candidate unavailable")
			return false
		end

		local consecrate = setting("auto_crafter_consecrate_transcendent", true) == true
		local expertise_enabled = setting("auto_crafter_upgrade_expertise_500", true) == true
		local mastery_enabled = setting("auto_crafter_level_mastery_20", true) == true
		local allocate_mastery = mastery_enabled and setting("auto_crafter_allocate_mastery_points", true) == true
		local change_perks = mastery_enabled and setting("auto_crafter_change_perks", true) == true
		local change_blessings = mastery_enabled and setting("auto_crafter_change_blessings", true) == true
		local target_offer = self._search and self._search.target_offer
		local target_mark_id = target_offer and target_offer.family_mark_selection == true and target_offer.master_id or nil

		local item = find_item(self._snapshot and self._snapshot.gear and self._snapshot.gear.items, candidate.gear_id)

		if not item or item.available ~= true then
			self:_operation_failed(self._generation, "final crafting candidate is absent from authoritative inventory")
			return false
		end

		if not consecrate and not expertise_enabled and not allocate_mastery and not change_perks and not change_blessings and not target_mark_id then
			self._phase4 = {
				fallback_accepted = self._search and self._search.fallback_accepted == true,
				fallback_target_distance = tonumber(self._search and self._search.fallback_target_distance),
				gear_id = candidate.gear_id,
				running = true,
			}

			return self:_phase4_complete(item, self._snapshot)
		end

		local needs_traits = allocate_mastery or change_perks or change_blessings
		local targets = { perks = {}, traits = {} }

		if needs_traits then
			local error_value
			targets, error_value = self:_phase4_targets(item)

			if not targets then
				self:_operation_failed(self._generation, error_value)
				return false
			end
		end

		local catalog = self._search and self._search.catalog or self._catalog
		local function validate_swap_preflight(sticker_book)
			for _, group in ipairs({
				{ current = item.perks, kind = "perk", targets = targets.perks },
				{ current = item.traits, kind = "blessing", targets = targets.traits },
			}) do
				if requires_temporary_swap(group.current, group.targets) and not temporary_swap_trait(group.kind, group.current, group.targets, catalog, sticker_book) then
					self:_operation_failed(self._generation, group.kind .. " two-slot swap has no safe temporary target; no final crafting materials were spent")

					return false
				end
			end

			return true
		end

		self._phase4 = {
			allocate_mastery = allocate_mastery,
			blessing_poll_attempts = 0,
			blessing_poll_elapsed = 0,
			blessing_poll_wait = blessing_poll_delay(0),
			catalog = catalog,
			consecrate = consecrate,
			custom_stats_enabled = self._search and self._search.custom_stats_enabled == true,
			custom_stat_targets = copy_stat_targets(self._search and self._search.custom_stat_targets),
			dump_stat = self._search and self._search.dump_stat,
			dump_stat_identity = copy_stat_identity(self._search and self._search.dump_stat_identity),
			dump_comparison = self._search and self._search.dump_comparison,
			expertise = expertise_enabled,
			fallback_accepted = self._search and self._search.fallback_accepted == true,
			fallback_target_distance = tonumber(self._search and self._search.fallback_target_distance),
			favorite_result = self._search and self._search.favorite_result == true,
			gear_id = candidate.gear_id,
			mastery_id = candidate.mastery_id or candidate.parent_pattern,
			running = true,
			sticker_book = catalog and catalog.blessings or {},
			mastery_costs = nil,
			target_dump = self._search and self._search.target_dump,
			target_mark_id = target_mark_id,
			targets = targets,
			trait_category = catalog and catalog.trait_category,
			verify_completion = true,
		}
		self._phase = "phase4_preflight"
		operation_report("phase4_started", {
			candidate = candidate,
			phase4 = self._phase4,
		})

		return self:_refresh_after_operation(self._generation, function (snapshot)
			if allocate_mastery or next(targets.traits or {}) ~= nil then
				local backend = self._backend

				if not backend or type(backend.get_trait_sticker_book) ~= "function" or not self._phase4.trait_category then
					self:_operation_failed(self._generation, "fresh blessing sticker-book adapter unavailable")
					return
				end

				self:_dispatch_operation(self._generation, "phase4_sticker_preflight", function ()
					return backend:get_trait_sticker_book(self._phase4.trait_category, true)
				end, function (sticker_book)
					self._phase4.sticker_book = sticker_book

					if not validate_swap_preflight(sticker_book) then
						return
					end

					if not allocate_mastery or unseen_blessing_tier_count(sticker_book) == 0 then
						for _, target in pairs(targets.traits or {}) do
							if target and sticker_status(sticker_book, target.id, target.rarity) ~= "seen" then
								self:_operation_failed(self._generation, "selected blessing tier is not allocated in mastery")

								return
							end
						end

						self:_phase4_step(self._generation, snapshot)
						return
					end

					if type(backend.get_mastery_trait_costs) ~= "function" then
						self:_operation_failed(self._generation, "live mastery blessing cost adapter unavailable")
						return
					end

					self:_dispatch_operation(self._generation, "phase4_mastery_cost_preflight", function ()
						return backend:get_mastery_trait_costs()
					end, function (costs)
						self._phase4.mastery_costs = costs
						self:_phase4_step(self._generation, snapshot)
					end)
				end)
			else
				if not validate_swap_preflight(self._phase4.sticker_book) then
					return
				end

				self:_phase4_step(self._generation, snapshot)
			end
		end)
	end

	return true
end

return Phase4Workflow
