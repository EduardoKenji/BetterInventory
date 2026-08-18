local ImportedQueueWorkflow = {}

function ImportedQueueWorkflow.install(self, services)
	local acquire_account_operation = services.acquire_account_operation
	local cancel_catalog = services.cancel_catalog
	local candidate_matches_stat_targets = services.candidate_matches_stat_targets
	local candidate_stat_target_distance = services.candidate_stat_target_distance
	local copy_stat_identity = services.copy_stat_identity
	local copy_stat_targets = services.copy_stat_targets
	local current_character_id = services.current_character_id
	local find_item = services.find_item
	local has_trait_targets = services.has_trait_targets
	local invalidate_generation = services.invalidate_generation
	local offer_key = services.offer_key
	local operation_report = services.operation_report
	local planner_config = services.planner_config
	local planner_config_signature = services.planner_config_signature
	local planner_setting_ids = services.planner_setting_ids
	local release_account_operation_if_settled = services.release_account_operation_if_settled
	local run_is_active = services.run_is_active
	local safe_call = services.safe_call
	local selected_offer_ids = services.selected_offer_ids
	local setting = services.setting
	local snapshot_matches_character = services.snapshot_matches_character
	local unseen_blessing_tier_count = services.unseen_blessing_tier_count
	local valid_custom_stat_targets = services.valid_custom_stat_targets
	local MAX_EXPERTISE_LEVEL = services.constants.MAX_EXPERTISE_LEVEL
	local TRANSCENDENT_RARITY = services.constants.TRANSCENDENT_RARITY

	local function imported_dump_stat(job)
		return job and (job.resolved_dump_stat or job.dump_stat)
	end

	function self:set_imported_job(job)
		local custom_valid, custom_total = true, nil
		if job and job.custom_stats_enabled == true then
			custom_valid, custom_total = valid_custom_stat_targets(job.custom_stat_targets, false)
			custom_valid = custom_valid and (job.custom_stat_total == nil or tonumber(job.custom_stat_total) == custom_total)
		end
		if type(job) ~= "table" or job.kind ~= "games_lantern_job" or type(job.offer) ~= "table" or job.offer.master_id == nil or job.dump_stat == nil or not custom_valid or type(job.perks) ~= "table" or #job.perks ~= 2 or type(job.blessings) ~= "table" or #job.blessings ~= 2 or type(job.catalog) ~= "table" or job.catalog.available ~= true then
			return false, "invalid imported job"
		end

		if run_is_active() or self._operation_inflight or self._operation_quarantined or (self._auxiliary_inflight_count or 0) > 0 then
			return false, "Auto Crafter is busy"
		end

		job.resolved_dump_stat = nil
		job.dump_stat_identity = nil
		cancel_catalog()
		self._imported_job = job
		self._run_imported_job = nil
		self._catalog = job.catalog
		self._catalog_key = offer_key(job.offer)
		self._selected_target_key = nil
		self._selected_native_key = offer_key(job.offer)
		self:_refresh_plan("games_lantern_job_staged")

		return true
	end

	function self:clear_imported_job()
		if run_is_active() or self._operation_inflight or self._operation_quarantined or (self._auxiliary_inflight_count or 0) > 0 then
			return false
		end

		self._imported_job = nil
		self._run_imported_job = nil
		self._catalog = nil
		self._catalog_key = nil
		self._selected_target_key = nil
		self._selected_native_key = nil
		self:_refresh_plan("games_lantern_job_cleared")

		if self._view_is_valid and self._snapshot then
			self:_schedule_catalog("games_lantern_job_cleared")
		end

		return true
	end

	function self:capture_queue_run_policy()
		if run_is_active() or self._operation_inflight or self._operation_quarantined or self._reconciliation_required or (self._auxiliary_inflight_count or 0) > 0 then
			return nil, "Auto Crafter is busy"
		end

		local values = {}
		for setting_id in pairs(planner_setting_ids) do
			values[setting_id] = setting(setting_id)
		end
		values.auto_crafter_buy_until_target = setting("auto_crafter_buy_until_target", "target_search")
		values.auto_crafter_favorite_result = setting("auto_crafter_favorite_result", true)

		return {
			kind = "games_lantern_queue_run_policy",
			character_id = current_character_id(),
			values = values,
		}
	end

	function self:preview_imported_queue(build)
		if not self._snapshot or type(build) ~= "table" or type(build.jobs) ~= "table" or #build.jobs < 1 or #build.jobs > 2 or not self._planner or type(self._planner.build) ~= "function" then
			return nil, "queue preview unavailable"
		end

		local previews = {}
		local signature_parts = { "games_lantern_authority_v1", tostring(current_character_id()) }
		local aggregate = { dockets_max = 0, dockets_min = 0, plasteel_max = 0, plasteel_min = 0, diamantine_max = 0, diamantine_min = 0 }
		for index, job in ipairs(build.jobs) do
			local config = planner_config()
			config.dump_stat = job.dump_stat
			config.dump_target = job.dump_target
			config.dump_comparison = setting("auto_crafter_dump_stat_comparison", "exact")
			config.custom_stats_enabled = job.custom_stats_enabled == true
			config.custom_stat_targets = copy_stat_targets(job.custom_stat_targets)
			config.target_offer = job.offer
			config.trait_catalog = job.catalog
			local ok, plan = pcall(self._planner.build, self._snapshot, config)
			if not ok or type(plan) ~= "table" or type(plan.estimate) ~= "table" then
				return nil, "queue job " .. tostring(index) .. " preview unavailable"
			end
			if plan.custom_stats_enabled and (plan.custom_stats_valid ~= true or tonumber(plan.custom_stat_total) ~= 380) then
				return nil, "queue job " .. tostring(index) .. " has an invalid custom stat total"
			end
			previews[index] = plan
			signature_parts[#signature_parts + 1] = table.concat({
				tostring(job.queue_id),
				tostring(job.job_id),
				tostring(job.slot),
				tostring(job.offer and (job.offer.offer_id or job.offer.master_id)),
				tostring(job.dump_stat),
				tostring(job.dump_target),
				tostring(job.custom_stats_enabled == true),
				planner_config_signature(config),
			}, ":")
			for _, target in ipairs(job.custom_stat_targets or {}) do
				signature_parts[#signature_parts + 1] = "stat:" .. tostring(target.name) .. ":" .. tostring(target.value)
			end
			for _, trait in ipairs(job.perks or {}) do
				signature_parts[#signature_parts + 1] = "perk:" .. tostring(trait.id or trait.name) .. ":" .. tostring(trait.rarity)
			end
			for _, trait in ipairs(job.blessings or {}) do
				signature_parts[#signature_parts + 1] = "blessing:" .. tostring(trait.id or trait.name) .. ":" .. tostring(trait.rarity)
			end
			local estimate = plan.estimate
			aggregate.dockets_min = aggregate.dockets_min + (tonumber(estimate.dockets_floor) or 0) + (tonumber(estimate.dockets_min) or 0)
			aggregate.dockets_max = aggregate.dockets_max + (tonumber(estimate.dockets_cap) or 0) + (tonumber(estimate.dockets_max) or 0)
			aggregate.plasteel_min = aggregate.plasteel_min + (tonumber(estimate.plasteel_min) or 0)
			aggregate.plasteel_max = aggregate.plasteel_max + (tonumber(estimate.plasteel_max) or 0)
			aggregate.diamantine_min = aggregate.diamantine_min + (tonumber(estimate.diamantine_min) or 0)
			aggregate.diamantine_max = aggregate.diamantine_max + (tonumber(estimate.diamantine_max) or 0)
		end

		for _, field in ipairs({ "dockets_min", "dockets_max", "plasteel_min", "plasteel_max", "diamantine_min", "diamantine_max" }) do
			signature_parts[#signature_parts + 1] = field .. ":" .. tostring(aggregate[field])
		end

		return { aggregate = aggregate, jobs = previews, signature = table.concat(signature_parts, "|") }
	end

	function self:stop_imported_queue_boundary()
		if run_is_active() then
			return self:_stop_active_run("user_stopped")
		end
		if not self._queue_preflight then
			return false
		end

		invalidate_generation()
		cancel_catalog()
		self._queue_preflight = nil
		self._probe_scheduled = false
		self._probe_elapsed = 0
		self._phase = "user_stopped"
		release_account_operation_if_settled()

		return true
	end

	function self:prepare_imported_job(job, index, completed_results, jobs)
		if type(job) ~= "table" or job.job_id == nil or job.queue_id == nil or self._imported_job ~= job then
			return false, "imported job identity unavailable"
		end

		local character_id = current_character_id()
		if not self._queue_run_policy or self._queue_run_policy.character_id ~= character_id then
			return false, "active character differs from confirmed queue policy"
		end

		local selected_ok, raw_offer = safe_call(self._get_selected_offer, self._active_view)
		local selected = selected_ok and selected_offer_ids(raw_offer) or nil
		if offer_key(selected) ~= offer_key(job.offer) then
			return nil, "waiting for native weapon selection"
		end

		local preflight = self._queue_preflight
		if not preflight or preflight.job_id ~= job.job_id then
			self._queue_preflight = {
				job_id = job.job_id,
				probe_count = self._probe_count,
			}
			cancel_catalog()
			self._catalog = nil
			self._catalog_key = nil
			if not self:_schedule_probe("games_lantern_queue_boundary") then
				return false, "fresh authoritative probe could not be scheduled"
			end

			return nil, "waiting for fresh authoritative probe"
		end

		if self._probe_count <= preflight.probe_count or self._probe_scheduled or self._probe_inflight then
			return nil, "waiting for fresh authoritative probe"
		end

		if not snapshot_matches_character(self._snapshot, character_id) then
			return false, "fresh inventory snapshot belongs to another character"
		end

		if self._catalog_inflight or not self._catalog then
			return nil, "waiting for fresh weapon catalogue"
		elseif self._catalog.available ~= true or self._catalog_key ~= offer_key(job.offer) then
			return false, self._catalog.reason or "fresh weapon catalogue unavailable"
		end

		job.catalog = self._catalog
		self._imported_job.catalog = self._catalog

		local completed_count = math.max(0, (tonumber(index) or 1) - 1)
		for completed_index = 1, completed_count do
			local verified, verify_reason = self:_verify_imported_result(completed_results and completed_results[completed_index], jobs and jobs[completed_index], completed_index)
			if not verified then
				return false, "completed queue prefix changed before next job: " .. tostring(verify_reason)
			end
		end

		self:_refresh_plan("games_lantern_boundary_preflight")
		if not self._plan or not self._plan.preflight or self._plan.preflight.ok ~= true then
			return false, self._plan and self._plan.preflight and self._plan.preflight.summary or "queue job preflight unavailable"
		end

		-- Imported IDs are advisory. Bind the job to the selected live mark's
		-- authoritative stat identity before any inventory reuse or purchase.
		job.resolved_dump_stat = self._plan.resolved_dump_stat
		job.dump_stat_identity = copy_stat_identity(self._plan.dump_stat_identity)
		job.dump_comparison = self._plan.dump_comparison

		local inventory_action, completed = self:_imported_job_inventory_decision(job)
		if inventory_action == "skip" and completed then
			operation_report("imported_queue_job_already_complete", {
				candidate = completed.candidate,
				slot = job.slot,
			})

			return completed
		end

		return true
	end

	function self:_verify_imported_result(result, job, index)
		local snapshot = self._snapshot
		local character_id = current_character_id()
		local policy = self._queue_run_policy and self._queue_run_policy.values or {}
		local gear = snapshot and snapshot.gear or {}
		local item = result and result.gear_id ~= nil and find_item(gear.items, result.gear_id, gear.items_by_id) or nil
		local label = tostring(index or "?")

		if type(result) ~= "table" or type(job) ~= "table" then
			return false, "completed queue weapon " .. label .. " has invalid identity"
		end
		if not snapshot_matches_character(snapshot, character_id) or result.character_id ~= character_id or not item or item.available ~= true then
			return false, "completed queue weapon " .. label .. " is missing from authoritative inventory"
		end

		local expected_pattern = job.parent_pattern or job.offer and job.offer.parent_pattern
		if expected_pattern and (item.parent_pattern or item.mastery_id) ~= expected_pattern then
			return false, "completed queue weapon " .. label .. " changed weapon family"
		end
		local target_matches = candidate_matches_stat_targets(item, imported_dump_stat(job), job.dump_target, job.custom_stats_enabled and job.custom_stat_targets or nil, job.dump_stat_identity, job.dump_comparison)
		local fallback_distance = result.fallback_accepted and candidate_stat_target_distance(item, imported_dump_stat(job), job.dump_target, job.custom_stats_enabled and job.custom_stat_targets or nil, job.dump_stat_identity) or nil
		local expected_fallback_distance = tonumber(result.fallback_target_distance)
		local fallback_matches = fallback_distance ~= nil and fallback_distance ~= math.huge and expected_fallback_distance ~= nil and expected_fallback_distance ~= math.huge and fallback_distance == expected_fallback_distance

		if not target_matches and not fallback_matches then
			return false, "completed queue weapon " .. label .. (job.custom_stats_enabled and " changed custom stats" or " changed dump stat")
		end
		if policy.auto_crafter_consecrate_transcendent == true and (tonumber(item.rarity) or -1) < TRANSCENDENT_RARITY then
			return false, "completed queue weapon " .. label .. " is below Transcendent"
		end
		if policy.auto_crafter_upgrade_expertise_500 == true and (tonumber(item.expertise_level) or -1) < MAX_EXPERTISE_LEVEL then
			return false, "completed queue weapon " .. label .. " is below item level 500"
		end
		if policy.auto_crafter_change_perks == true and not has_trait_targets(item.perks, job.perks) then
			return false, "completed queue weapon " .. label .. " changed perks"
		end
		if policy.auto_crafter_change_blessings == true and not has_trait_targets(item.traits, job.blessings) then
			return false, "completed queue weapon " .. label .. " changed blessings"
		end

		return true
	end

	function self:_completed_imported_job_result(job)
		local character_id = current_character_id()
		local snapshot = self._snapshot
		local catalog = job and job.catalog
		local expected_pattern = job and (job.parent_pattern or job.offer and job.offer.parent_pattern)

		if type(job) ~= "table" or job.kind ~= "games_lantern_job" or job.job_id == nil or job.queue_id == nil or expected_pattern == nil or job.dump_stat == nil or job.dump_target == nil or type(catalog) ~= "table" or catalog.available ~= true or not snapshot_matches_character(snapshot, character_id) then
			return nil
		end

		local completed
		for _, item in ipairs(snapshot.gear and snapshot.gear.items or {}) do
			if self:_imported_item_is_complete(item, job) and (not completed or tostring(item.gear_id) < tostring(completed.gear_id)) then
				completed = item
			end
		end

		if not completed then
			return nil
		end

		return {
			candidate = completed,
			character_id = character_id,
			gear_id = completed.gear_id,
			job_id = job.job_id,
			kind = "games_lantern_completed_inventory_result",
			queue_id = job.queue_id,
		}
	end

	function self:verify_imported_queue_results(results, jobs)
		if type(results) ~= "table" or type(jobs) ~= "table" or #jobs < 1 or #jobs > 2 or #results ~= #jobs or not self._snapshot then
			return false, "one completed result per queued job is required"
		end

		local character_id = current_character_id()
		if not snapshot_matches_character(self._snapshot, character_id) then
			return false, "final inventory snapshot belongs to another character"
		end

		for index, result in ipairs(results) do
			local verified, reason = self:_verify_imported_result(result, jobs[index], index)
			if not verified then return false, reason end
		end

		return true
	end

	function self:begin_queue_operation(policy)
		if self._queue_operation_owner or run_is_active() or self._operation_inflight or self._operation_quarantined or self._reconciliation_required or (self._auxiliary_inflight_count or 0) > 0 then
			return false, "Auto Crafter is busy"
		end
		if type(policy) ~= "table" or policy.kind ~= "games_lantern_queue_run_policy" or type(policy.values) ~= "table" or policy.character_id ~= current_character_id() then
			return false, "queue run policy is invalid or stale"
		end

		local acquired, reason = acquire_account_operation()
		if not acquired then
			return false, reason or "account-operation ownership unavailable"
		end

		self._queue_operation_owner = true
		self._queue_run_policy = policy
		self._queue_preflight = nil

		return true
	end

	function self:end_queue_operation()
		self._queue_operation_owner = false
		self._queue_preflight = nil
		local released = release_account_operation_if_settled()
		if released then
			self._queue_run_policy = nil
		end

		return released
	end

	return true
end

return ImportedQueueWorkflow
