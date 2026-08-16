local CandidatePolicy = {}

local function read_member(object, key)
	return object[key]
end

local function safe_member(object, key)
	if type(object) ~= "table" and type(object) ~= "userdata" then
		return nil
	end

	local ok, value = pcall(read_member, object, key)

	return ok and value or nil
end

function CandidatePolicy.offer_key(offer)
	if not offer then
		return nil
	end

	if offer.offer_id ~= nil then
		return "offer:" .. tostring(offer.offer_id)
	end

	if offer.master_id ~= nil then
		return "master:" .. tostring(offer.master_id)
	end

	return nil
end

function CandidatePolicy.selected_offer_ids(raw_offer)
	if not raw_offer then
		return nil
	end

	local selected_offer = {
		offer_id = safe_member(raw_offer, "offerId") or safe_member(raw_offer, "offer_id"),
		master_id = safe_member(raw_offer, "masterId") or safe_member(raw_offer, "master_id"),
	}
	local description = safe_member(raw_offer, "description")
	local choices = safe_member(description, "lootChoices") or safe_member(description, "loot_choices")
	local choice = type(choices) == "table" and choices[1] or nil

	if selected_offer.master_id == nil then
		if type(choice) == "table" then
			selected_offer.master_id = choice.masterId or choice.master_id or choice.id or choice.name
		else
			selected_offer.master_id = choice
		end
	end

	if selected_offer.offer_id == nil and selected_offer.master_id == nil then
		return nil
	end

	return selected_offer
end

function CandidatePolicy.selected_offer_matches_target(selected_offer, target)
	if not selected_offer or not target then
		return false
	end

	-- Manual mark selection keeps Brunt's family offer selected while narrowing
	-- purchase candidates to one lootChoice. Other targets retain strict IDs.
	if target.family_mark_selection == true and selected_offer.offer_id ~= nil and target.offer_id ~= nil then
		return selected_offer.offer_id == target.offer_id
	end

	if selected_offer.master_id ~= nil and target.master_id ~= nil and selected_offer.master_id ~= target.master_id then
		return false
	end

	if selected_offer.offer_id ~= nil and target.offer_id ~= nil and selected_offer.offer_id ~= target.offer_id then
		return false
	end

	return selected_offer.master_id ~= nil and target.master_id ~= nil or selected_offer.offer_id ~= nil and target.offer_id ~= nil
end

function CandidatePolicy.offer_with_mark(offer, mark)
	local target = {}

	for key, value in pairs(offer or {}) do
		target[key] = value
	end
	for key, value in pairs(mark or {}) do
		target[key] = value
	end
	target.family_mark_selection = true

	return target
end

function CandidatePolicy.find_item(items, gear_id, items_by_id)
	items_by_id = items_by_id or type(items) == "table" and rawget(items, "by_id")
	local indexed = type(items_by_id) == "table" and items_by_id[gear_id] or nil

	if indexed ~= nil then
		return indexed
	end

	for _, item in ipairs(items or {}) do
		if item and item.gear_id == gear_id then
			return item
		end
	end

	return nil
end

function CandidatePolicy.copy_stat_identity(identity)
	if type(identity) ~= "table" or identity.name == nil then
		return nil
	end

	return {
		display_name_key = identity.display_name_key,
		name = tostring(identity.name),
	}
end

function CandidatePolicy.candidate_stat(candidate, stat_name, stat_identity)
	if not candidate or not stat_name then
		return nil
	end

	local potential_stats = candidate.potential_base_stats
	local exact = potential_stats and potential_stats[stat_name]

	if exact ~= nil then
		return exact
	end

	-- Brunt purchases a family offer and may return a sibling mark. Weapon marks
	-- can use different internal stat IDs for the same displayed stat, so bind the
	-- frozen target to Darktide's exact display-name identity. Never guess from a
	-- partial name: absent or ambiguous identities remain unavailable.
	if type(potential_stats) ~= "table"
		or type(stat_identity) ~= "table"
		or tostring(stat_identity.name or "") ~= tostring(stat_name)
		or type(stat_identity.display_name_key) ~= "string"
		or stat_identity.display_name_key == ""
	then
		return nil
	end

	local matched_name

	for candidate_name, display_name_key in pairs(type(candidate.base_stat_labels) == "table" and candidate.base_stat_labels or {}) do
		if display_name_key == stat_identity.display_name_key and potential_stats[candidate_name] ~= nil then
			if matched_name ~= nil and matched_name ~= candidate_name then
				return nil
			end

			matched_name = candidate_name
		end
	end

	return matched_name and potential_stats[matched_name] or nil
end

function CandidatePolicy.copy_stat_targets(targets)
	local copied = {}

	if type(targets) == "table" and #targets > 0 then
		for _, target in ipairs(targets) do
			copied[#copied + 1] = {
				display_name_key = target.display_name_key,
				label = target.label,
				name = target.name,
				value = tonumber(target.value),
			}
		end

		return copied
	end

	for key, target in pairs(type(targets) == "table" and targets or {}) do
		copied[key] = tonumber(target)
	end

	return copied
end

function CandidatePolicy.valid_custom_stat_targets(targets, require_total)
	if type(targets) ~= "table" or #targets ~= 5 then
		return false, nil, "custom stats require exactly five targets"
	end

	local seen = {}
	local total = 0

	for index, target in ipairs(targets) do
		local name = type(target) == "table" and target.name or nil
		local value = tonumber(type(target) == "table" and target.value or target)

		if name == nil or name == "" or seen[tostring(name)] then
			return false, nil, "custom stat identities must be present and unique"
		end
		if value == nil or value ~= math.floor(value) or value < 60 or value > 80 then
			return false, nil, string.format("custom stat %d must be a whole number between 60 and 80", index)
		end

		seen[tostring(name)] = true
		total = total + value
	end

	if total > 380 or require_total and total ~= 380 then
		return false, total, string.format("custom stat total must %s 380 (current: %d)", require_total and "equal" or "not exceed", total)
	end

	return true, total
end

local function custom_stat_value(candidate, stat_name, target)
	return CandidatePolicy.candidate_stat(candidate, stat_name, target)
end

function CandidatePolicy.candidate_matches_stat_targets(candidate, dump_stat, target_dump, custom_targets, dump_stat_identity)
	if type(custom_targets) == "table" and next(custom_targets) ~= nil then
		for stat_name, target in pairs(custom_targets) do
			local target_name = type(target) == "table" and target.name or stat_name
			local target_value = type(target) == "table" and target.value or target

			if tonumber(custom_stat_value(candidate, target_name, target)) ~= tonumber(target_value) then
				return false
			end
		end

		return true
	end

	return tonumber(CandidatePolicy.candidate_stat(candidate, dump_stat, dump_stat_identity)) == tonumber(target_dump)
end

function CandidatePolicy.candidate_stat_target_distance(candidate, dump_stat, target_dump, custom_targets, dump_stat_identity)
	if type(custom_targets) == "table" and next(custom_targets) ~= nil then
		local distance = 0

		for stat_name, target in pairs(custom_targets) do
			local target_name = type(target) == "table" and target.name or stat_name
			local target_value = tonumber(type(target) == "table" and target.value or target)
			local value = tonumber(custom_stat_value(candidate, target_name, target))

			if value == nil or target_value == nil then
				return math.huge
			end

			distance = distance + math.abs(value - target_value)
		end

		return distance
	end

	local value = tonumber(CandidatePolicy.candidate_stat(candidate, dump_stat, dump_stat_identity))

	return value == nil and math.huge or math.abs(value - (tonumber(target_dump) or 60))
end

function CandidatePolicy.trait_at(traits, index)
	local trait = type(traits) == "table" and traits[index] or nil

	return trait and {
		id = trait.id,
		rarity = tonumber(trait.rarity),
	} or nil
end

function CandidatePolicy.same_trait(left, right)
	return left and right and left.id == right.id and tonumber(left.rarity) == tonumber(right.rarity)
end

function CandidatePolicy.same_optional_trait(left, right)
	return left == nil and right == nil or CandidatePolicy.same_trait(left, right)
end

function CandidatePolicy.has_pending_trait_replacement(current_traits, targets)
	for index = 1, 2 do
		local desired = targets and targets[index]

		if desired and not CandidatePolicy.same_trait(CandidatePolicy.trait_at(current_traits, index), desired) then
			return true
		end
	end

	return false
end

function CandidatePolicy.has_trait_targets(values, targets)
	for _, target in ipairs(targets or {}) do
		local found = false

		for _, value in ipairs(values or {}) do
			if CandidatePolicy.same_trait(value, target) then
				found = true
				break
			end
		end

		if not found then
			return false
		end
	end

	return true
end

function CandidatePolicy.temporary_swap_trait(kind, current_traits, targets, catalog, sticker_book)
	local excluded = {}

	for index = 1, 2 do
		local current = CandidatePolicy.trait_at(current_traits, index)
		local target = targets and targets[index]

		if current and current.id then
			excluded[current.id] = true
		end
		if target and target.id then
			excluded[target.id] = true
		end
	end

	if kind == "perk" then
		for _, entry in ipairs(catalog and catalog.perks or {}) do
			if entry.id and not excluded[entry.id] and tonumber(entry.tier) then
				return { id = entry.id, rarity = tonumber(entry.tier) }
			end
		end
	else
		for _, blessing in ipairs(sticker_book or {}) do
			if blessing.id and not excluded[blessing.id] then
				local highest_seen

				for _, entry in ipairs(blessing.tiers or {}) do
					if entry.status == "seen" and tonumber(entry.tier) then
						highest_seen = math.max(highest_seen or 0, tonumber(entry.tier))
					end
				end

				if highest_seen then
					return { id = blessing.id, rarity = highest_seen }
				end
			end
		end
	end

	return nil
end

function CandidatePolicy.requires_temporary_swap(current_traits, targets)
	local mismatch = false

	for index = 1, 2 do
		local desired = targets and targets[index]
		local current = CandidatePolicy.trait_at(current_traits, index)

		if desired and not CandidatePolicy.same_trait(current, desired) then
			mismatch = true

			if not CandidatePolicy.same_trait(CandidatePolicy.trait_at(current_traits, index == 1 and 2 or 1), desired) then
				return false
			end
		end
	end

	return mismatch
end

return CandidatePolicy
