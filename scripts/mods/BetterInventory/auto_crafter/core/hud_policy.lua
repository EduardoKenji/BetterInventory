local HudPolicy = {}

local COMPLETION_VISIBLE_SECONDS = 12

local function finite_nonnegative(value)
	value = tonumber(value)

	if value == nil or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end

	return math.max(0, value)
end

function HudPolicy.run_active(snapshot)
	local search = snapshot and snapshot.search
	local phase3 = snapshot and snapshot.phase3
	local phase4 = snapshot and snapshot.phase4
	local mastery = snapshot and snapshot.mastery

	return search and search.running == true
		or phase3 and phase3.running == true
		or phase4 and phase4.running == true
		or mastery and mastery.running == true
		or false
end

function HudPolicy.completion_key(snapshot)
	local phase4 = snapshot and snapshot.phase4

	if snapshot and not snapshot.last_error and type(phase4) == "table" and phase4.running ~= true and phase4.elapsed_seconds ~= nil then
		local search = snapshot.search or {}

		return table.concat({
			tostring(snapshot.terminal_sequence or ""),
			tostring(search.generation or ""),
			tostring(phase4.gear_id or ""),
			tostring(phase4.completed_at or ""),
		}, ":")
	end

	return nil
end

function HudPolicy.completion_visible(snapshot, elapsed)
	return HudPolicy.completion_key(snapshot) ~= nil and finite_nonnegative(elapsed) <= COMPLETION_VISIBLE_SECONDS
end

function HudPolicy.completion_pending(snapshot, line_count)
	return HudPolicy.completion_key(snapshot) ~= nil and (tonumber(line_count) or 0) > 0
end

function HudPolicy.presentation_needs_update(snapshot, line_count, dirty)
	return dirty == true or HudPolicy.completion_pending(snapshot, line_count)
end

function HudPolicy.advance_completion_elapsed(snapshot, line_count, elapsed, dt)
	if not HudPolicy.completion_pending(snapshot, line_count) then
		return 0
	end

	return finite_nonnegative(elapsed) + finite_nonnegative(dt)
end

function HudPolicy.phase4_status(snapshot)
	local phase4 = snapshot and snapshot.phase4
	local item = phase4 and phase4.current_item or {}

	if not phase4 or phase4.running ~= true then
		return nil
	elseif phase4.final_reconcile_started then
		return "final_reconcile"
	elseif phase4.consecrate and (tonumber(item.rarity) or 0) < 5 then
		return "consecrate"
	elseif phase4.expertise and (tonumber(item.expertise_level) or 0) < 500 then
		return "expertise"
	end

	local points_spent = tonumber(phase4.blessing_points_spent)
	local points_total = tonumber(phase4.blessing_points_total)
	local allocating_points = phase4.allocate_mastery and (points_total == nil or points_spent == nil or points_spent < points_total)

	if allocating_points then
		return "allocate_mastery"
	elseif phase4.target_mark_id and item.master_id ~= phase4.target_mark_id then
		return "switch_mark"
	elseif phase4.targets and (next(phase4.targets.perks or {}) ~= nil or next(phase4.targets.traits or {}) ~= nil) then
		return "traits"
	end

	return "final_reconcile"
end

return HudPolicy
