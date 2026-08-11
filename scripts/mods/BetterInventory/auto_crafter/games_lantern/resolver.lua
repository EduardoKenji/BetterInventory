-- Pure Games Lantern -> Darktide catalogue resolution.
--
-- The external page is descriptive data only.  This module never writes
-- settings, selects a Brunt offer, or calls a crafting service.  It returns a
-- complete two-slot target or an explicit ambiguity/unsupported error.
local Resolver = {}

-- Games Lantern's public class slugs do not always equal Darktide's internal
-- archetype IDs.  Keep this compatibility boundary explicit and aligned with
-- Lantern of the Omnissiah's SLUG_TO_ARCHETYPE contract.
local ARCHETYPE_ALIASES = {
	["arbites"] = "adamant",
	["hive-scum"] = "broker",
	["skitarii"] = "cryptic",
	["skitarius"] = "cryptic",
}

local function canonical_archetype(value)
	if value == nil then
		return nil
	end

	local normalized = string.lower(tostring(value)):gsub("^%s+", ""):gsub("%s+$", ""):gsub("_", "-"):gsub("%s+", "-")

	if normalized == "" then
		return nil
	end

	return ARCHETYPE_ALIASES[normalized] or normalized
end

local function archetype_compatible(source, active)
	local canonical_source = canonical_archetype(source)
	local canonical_active = canonical_archetype(active)

	return canonical_source ~= nil and canonical_active ~= nil and canonical_source == canonical_active, canonical_source, canonical_active
end

Resolver.CONTRACT_VERSION = "games_lantern_resolver_v1"

local STOP_WORDS = {
	["and"] = true,
	["the"] = true,
	["for"] = true,
	["vs"] = true,
	["with"] = true,
	["enemies"] = true,
	["enemy"] = true,
	["weapon"] = true,
}

local function text(value)
	return type(value) == "string" and value or value ~= nil and tostring(value) or ""
end

local function normalize(value)
	local result = string.lower(text(value))
	result = result:gsub("&amp;", "and")
	result = result:gsub("&#0?39;", "'")
	result = result:gsub("&#x27;", "'")
	result = result:gsub("(%d+)%s*%-%s*(%d+)", "%2")
	result = result:gsub("armoured", "armored")
	result = result:gsub("[^%w]+", " ")
	result = result:gsub("%s+", " ")
	result = result:gsub("^%s+", "")
	result = result:gsub("%s+$", "")

	return result
end

local function tokens(value)
	local result = {}
	local seen = {}

	for token in normalize(value):gmatch("[%w]+") do
		if not STOP_WORDS[token] and not token:match("^%d+$") and not seen[token] then
			seen[token] = true
			result[#result + 1] = token
		end
	end

	return result
end

local function token_set(value)
	local result = {}

	for _, token in ipairs(tokens(value)) do
		result[token] = true
	end

	return result
end

local function contains_all(haystack, needles)
	local values = token_set(haystack)

	for _, needle in ipairs(needles) do
		if not values[needle] then
			return false
		end
	end

	return #needles > 0
end

local function localized_offer_label(localize_offer_label, value)
	if type(localize_offer_label) ~= "function" or type(value) ~= "string" or value == "" then
		return ""
	end

	local ok, localized = pcall(localize_offer_label, value)

	return ok and type(localized) == "string" and localized or ""
end

local function offer_text(offer, localize_offer_label)
	if type(offer) ~= "table" then
		return ""
	end

	return table.concat({
		text(offer.display_name),
		localized_offer_label(localize_offer_label, offer.display_name),
		text(offer.sub_display_name),
		localized_offer_label(localize_offer_label, offer.sub_display_name),
		text(offer.master_id),
		text(offer.weapon_category),
		text(offer.weapon_template),
	}, " ")
end

local function slot_matches(offer, slot, classify_offer)
	if type(classify_offer) == "function" then
		local ok, classified = pcall(classify_offer, offer)

		if not ok or classified == nil then
			return false
		end

		return classified == slot
	end

	local category = string.lower(text(offer and (offer.weapon_category or offer.slot_type)))

	if slot == "melee" then
		if category == "melee" or category == "slot_primary" then
			return true
		end
	elseif category == "ranged" or category == "slot_secondary" then
		return true
	end

	-- Some Brunt snapshots expose a usable master ID before slot metadata is
	-- populated. The item path is authoritative and keeps import independent
	-- from timing of MasterItems metadata hydration.
	local identity = string.lower(table.concat({
		text(offer and offer.master_id),
		text(offer and offer.parent_pattern),
		text(offer and offer.weapon_template),
		text(offer and offer.sku_category),
	}, " "))

	if slot == "melee" then
		return identity:find("/melee/", 1, true) ~= nil or identity:find("slot_primary", 1, true) ~= nil
	end

	return identity:find("/ranged/", 1, true) ~= nil or identity:find("slot_secondary", 1, true) ~= nil
end

local function match_score(external, offer, localize_offer_label)
	local family = tokens(external and external.external_family_slug)
	local mark = tokens(external and external.external_mark_slug)
	local candidate_text = offer_text(offer, localize_offer_label)

	if contains_all(candidate_text, family) and contains_all(candidate_text, mark) then
		return 300
	end

	-- Brunt exposes one purchasable offer per weapon family, not one offer per
	-- named mark.  Games Lantern links preserve the full mark (for example,
	-- "Branx Mk XI Paired Transonic Blades") while the live Brunt offer is
	-- simply "Paired Transonic Blades".  A family match is authoritative at
	-- this boundary; if more than one live offer matches, resolve_weapon keeps
	-- failing closed as ambiguous instead of guessing.
	if contains_all(candidate_text, family) then
		return 250
	end

	local display = tokens(external and external.display_name)

	if contains_all(candidate_text, display) then
		return 200
	end

	return 0
end

local function sorted_candidates(candidates)
	table.sort(candidates, function(left, right)
		local left_score = tonumber(left.score) or 0
		local right_score = tonumber(right.score) or 0

		if left_score ~= right_score then
			return left_score > right_score
		end

		return text(left.offer and (left.offer.master_id or left.offer.display_name)) < text(right.offer and (right.offer.master_id or right.offer.display_name))
	end)

	return candidates
end

local function resolve_weapon(external, slot, offers, classify_offer, localize_offer_label)
	local candidates = {}

	for _, offer in ipairs(offers or {}) do
		if slot_matches(offer, slot, classify_offer) then
			local score = match_score(external, offer, localize_offer_label)

			if score > 0 then
				candidates[#candidates + 1] = {offer = offer, score = score}
			end
		end
	end

	sorted_candidates(candidates)

	if #candidates == 0 then
		return nil, "unavailable_" .. slot
	end

	local top_score = candidates[1].score
	local top_count = 0

	for _, candidate in ipairs(candidates) do
		if candidate.score == top_score then
			top_count = top_count + 1
		end
	end

	if top_count ~= 1 then
		return nil, "ambiguous_" .. slot
	end

	return {
		slot = slot,
		external = external,
		offer = candidates[1].offer,
		identity_score = top_score,
	}, nil
end

local STAT_ALIASES = {
	["warp resistance"] = {"warp", "resist"},
	["cleave damage"] = {"cleave"},
	["cleave damage targets"] = {"cleave"},
	["cleave efficiency"] = {"cleave"},
	["charge rate"] = {"charge", "speed"},
	["charge speed"] = {"charge", "speed"},
	["reload speed"] = {"reload"},
	["heat management"] = {"heat", "management"},
	["power output"] = {"power", "output"},
	["first target"] = {"first", "target"},
	["defenses"] = {"defense"},
	["defence"] = {"defense"},
}

local function stat_matches(external_label, candidate, localize_offer_label)
	local normalized_external = normalize(external_label)
	local aliases = STAT_ALIASES[normalized_external]
	local candidate_text = offer_text({
		display_name = candidate and candidate.name,
		sub_display_name = candidate and candidate.display_name_key,
	}, localize_offer_label)

	if aliases then
		return contains_all(candidate_text, aliases)
	end

	return contains_all(candidate_text, tokens(normalized_external))
end

local function resolve_stat(external_label, offer, localize_offer_label)
	local matches = {}

	for _, candidate in ipairs(offer and offer.base_stats or {}) do
		if stat_matches(external_label, candidate, localize_offer_label) then
			matches[#matches + 1] = candidate
		end
	end

	if #matches == 0 then
		return nil, "dump_stat_unavailable"
	end

	if #matches ~= 1 then
		return nil, "dump_stat_ambiguous"
	end

	return matches[1].name, nil
end

local function resolve_dump_stat(external, offer, localize_offer_label)
	local lowest
	local tied = false

	for _, stat in ipairs(external and external.stats or {}) do
		local value = tonumber(stat.value)

		if value == nil then
			return nil, "invalid_external_stat"
		end

		if lowest == nil or value < lowest.value then
			lowest = {label = stat.label, value = value}
			tied = false
		elseif value == lowest.value then
			tied = true
		end
	end

	if not lowest then
		return nil, "no_external_stats"
	end

	if tied then
		return nil, "dump_stat_tie"
	end

	local stat_id, reason = resolve_stat(lowest.label, offer, localize_offer_label)

	if not stat_id then
		return nil, reason
	end

	return {
		id = stat_id,
		label = lowest.label,
		value = lowest.value,
	}, nil
end

local function catalog_for(context, offer)
	if type(context and context.catalog_for_offer) == "function" then
		local ok, catalog = pcall(context.catalog_for_offer, offer)

		return ok and catalog or nil
	end

	local catalogs = context and context.catalogs
	local key = offer and (offer.master_id or offer.parent_pattern)

	return type(catalogs) == "table" and key ~= nil and catalogs[key] or context and context.catalog
end

-- Darktide's canonical perk traits use combat-system armor names while the UI
-- and Games Lantern use player-facing enemy armor names. Keep this mapping at
-- the resolver boundary and still require the mapped trait to exist in the
-- selected weapon's live catalogue.
local function trait_semantic_aliases(entry)
	local raw = string.lower(table.concat({
		text(entry and entry.id),
		text(entry and entry.trait),
	}, " "))
	local aliases = {}

	if string.find(raw, "super_armor", 1, true) then
		aliases[#aliases + 1] = "carapace armored"
	elseif string.find(raw, "disgustingly_resilient", 1, true) then
		aliases[#aliases + 1] = "infested"
	elseif string.find(raw, "unarmored", 1, true) then
		aliases[#aliases + 1] = "unarmored"
	elseif string.find(raw, "armored", 1, true) then
		aliases[#aliases + 1] = "flak armored"
	elseif string.find(raw, "resistant", 1, true) then
		aliases[#aliases + 1] = "unyielding"
	elseif string.find(raw, "berserker", 1, true) then
		aliases[#aliases + 1] = "maniac maniacs"
	end

	if string.find(raw, "crit_chance", 1, true) then
		aliases[#aliases + 1] = "critical strike chance"
	elseif string.find(raw, "crit_damage", 1, true) then
		aliases[#aliases + 1] = "critical hit damage"
	end

	if string.find(raw, "weakspot", 1, true) then
		aliases[#aliases + 1] = "weak spot"
	end

	if string.find(raw, "damage_specials", 1, true) then
		aliases[#aliases + 1] = "damage specialist specialists"
	elseif string.find(raw, "damage_hordes", 1, true) then
		aliases[#aliases + 1] = "damage horde hordes"
	end

	if string.find(raw, "reduce_sprint_cost", 1, true) then
		aliases[#aliases + 1] = "sprint efficiency"
	elseif string.find(raw, "reduced_block_cost", 1, true) then
		aliases[#aliases + 1] = "block efficiency"
	end

	return table.concat(aliases, " ")
end

local function trait_text(entry, localize_trait_label)
	return table.concat({
		text(entry and entry.display_name),
		text(entry and entry.display_name_key),
		localized_offer_label(localize_trait_label, entry and entry.display_name_key),
		text(entry and entry.description_key),
		localized_offer_label(localize_trait_label, entry and entry.description_key),
		text(entry and entry.trait),
		text(entry and entry.id),
		trait_semantic_aliases(entry),
	}, " ")
end

local function trait_failure_detail(external, entries)
	local ids = {}

	for index, entry in ipairs(entries or {}) do
		if index > 8 then
			break
		end

		ids[#ids + 1] = text(entry and (entry.trait or entry.id))
	end

	return string.format(
		"target=%s catalog=%d candidates=%s",
		text(external and (external.label or external.name)),
		type(entries) == "table" and #entries or 0,
		table.concat(ids, ",")
	)
end

local function trait_slot(entry)
	local raw = string.lower(table.concat({
		text(entry and entry.id),
		text(entry and entry.trait),
	}, " "))

	if string.find(raw, "weapon_trait_ranged", 1, true) then
		return "ranged"
	end

	if string.find(raw, "weapon_trait_melee", 1, true)
		or string.find(raw, "weapon_trait_increase_stamina", 1, true)
		or string.find(raw, "weapon_trait_reduce_sprint_cost", 1, true)
		or string.find(raw, "weapon_trait_reduced_block_cost", 1, true)
		or string.find(raw, "weapon_trait_increase_impact", 1, true) then
		return "melee"
	end

	return nil
end

local function trait_raw_identity(entry)
	return string.lower(table.concat({
		text(entry and entry.id),
		text(entry and entry.trait),
	}, " "))
end

local function entry_perk_family(entry)
	local raw = trait_raw_identity(entry)

	if string.find(raw, "super_armor", 1, true) then
		return "damage_carapace"
	elseif string.find(raw, "disgustingly_resilient", 1, true) then
		return "damage_infested"
	elseif string.find(raw, "unarmored", 1, true) then
		return "damage_unarmored"
	elseif string.find(raw, "armored", 1, true) then
		return "damage_flak"
	elseif string.find(raw, "resistant", 1, true) then
		return "damage_unyielding"
	elseif string.find(raw, "berserker", 1, true) then
		return "damage_maniac"
	elseif string.find(raw, "reduce_sprint_cost", 1, true) then
		return "sprint_efficiency"
	elseif string.find(raw, "reduced_block_cost", 1, true) then
		return "block_efficiency"
	elseif string.find(raw, "reload_speed", 1, true) then
		return "reload_speed"
	elseif string.find(raw, "crit_chance", 1, true) then
		return "critical_chance"
	elseif string.find(raw, "crit_damage", 1, true) then
		return "critical_damage"
	elseif string.find(raw, "weakspot", 1, true) then
		return "weakspot_damage"
	elseif string.find(raw, "increase_stamina", 1, true) then
		return "flat_stamina"
	elseif string.find(raw, "damage_elites", 1, true) then
		return "damage_elites"
	elseif string.find(raw, "damage_specials", 1, true) then
		return "damage_specials"
	elseif string.find(raw, "damage_hordes", 1, true) then
		return "damage_hordes"
	elseif string.find(raw, "increase_finesse", 1, true) then
		return "finesse"
	elseif string.find(raw, "increase_impact", 1, true) then
		return "impact"
	elseif string.find(raw, "increase_power", 1, true) then
		return "power"
	elseif string.find(raw, "increase_damage", 1, true) then
		return "damage"
	end

	return nil
end

local function external_perk_family(external)
	local raw = normalize(external and (external.label or external.name))

	if string.find(raw, "carapace", 1, true) then
		return "damage_carapace"
	elseif string.find(raw, "infested", 1, true) then
		return "damage_infested"
	elseif string.find(raw, "unarmored", 1, true) then
		return "damage_unarmored"
	elseif string.find(raw, "flak", 1, true) then
		return "damage_flak"
	elseif string.find(raw, "unyielding", 1, true) then
		return "damage_unyielding"
	elseif string.find(raw, "maniac", 1, true) then
		return "damage_maniac"
	elseif string.find(raw, "sprint", 1, true) then
		return "sprint_efficiency"
	elseif string.find(raw, "block", 1, true) then
		return "block_efficiency"
	elseif string.find(raw, "reload", 1, true) then
		return "reload_speed"
	elseif string.find(raw, "critical", 1, true) and string.find(raw, "chance", 1, true) then
		return "critical_chance"
	elseif string.find(raw, "critical", 1, true) and string.find(raw, "damage", 1, true) then
		return "critical_damage"
	elseif (string.find(raw, "weak spot", 1, true) or string.find(raw, "weakspot", 1, true)) and string.find(raw, "damage", 1, true) then
		return "weakspot_damage"
	elseif string.find(raw, "stamina", 1, true) then
		return "flat_stamina"
	elseif string.find(raw, "elite", 1, true) then
		return "damage_elites"
	elseif string.find(raw, "specialist", 1, true) then
		return "damage_specials"
	elseif string.find(raw, "horde", 1, true) then
		return "damage_hordes"
	elseif string.find(raw, "finesse", 1, true) then
		return "finesse"
	elseif string.find(raw, "impact", 1, true) then
		return "impact"
	elseif string.find(raw, "power", 1, true) then
		return "power"
	elseif string.find(raw, "damage", 1, true) then
		return "damage"
	end

	return nil
end

local function candidate_identity(entry)
	local id = entry and entry.id

	if id ~= nil and tostring(id) ~= "" then
		return "id:" .. tostring(id)
	end

	local trait = entry and entry.trait

	if trait ~= nil and tostring(trait) ~= "" then
		return "trait:" .. tostring(trait)
	end

	return nil
end

local function icon_trait_id(value)
	if value == nil then
		return nil
	end

	local rendered = tostring(value)

	return rendered:match("weapon_trait_0*(%d+)") or rendered:match("^0*(%d+)$")
end

local function trait_score(external, entry, localize_trait_label)
	local external_tokens = tokens(external and (external.label or external.name))
	local candidate = token_set(trait_text(entry, localize_trait_label))
	local score = 0
	local external_icon_id = icon_trait_id(external and external.external_icon_id)
	local candidate_icon_id = icon_trait_id(entry and (entry.external_icon_id or entry.icon_id or entry.icon or entry.texture_id))
	if external_icon_id ~= nil and candidate_icon_id ~= nil and external_icon_id == candidate_icon_id then
		score = score + 100
	end

	for _, token in ipairs(external_tokens) do
		if candidate[token] then
			score = score + 1
		end
	end

	local label_score = score >= 100 and score - 100 or score
	return label_score == #external_tokens and label_score > 0 and score or 0
end

local function resolve_traits(external_values, entries, kind, localize_trait_label, slot)
	local result = {}

	if type(external_values) ~= "table" or #external_values ~= 2 then
		return nil, "incomplete_" .. kind .. "_targets"
	end

	for index, external in ipairs(external_values) do
		local candidates = {}
		local candidate_indexes = {}
		local target_family = kind == "perk" and external_perk_family(external) or nil

		for _, entry in ipairs(entries or {}) do
			local score = trait_score(external, entry, localize_trait_label)
			local entry_slot = kind == "perk" and trait_slot(entry) or nil
			local entry_family = kind == "perk" and entry_perk_family(entry) or nil
			local family_compatible = target_family == nil or entry_family == nil or target_family == entry_family
			local semantic_fallback = kind == "perk"
				and score == 0
				and target_family ~= nil
				and entry_family == target_family
				and (entry_slot == nil or slot == nil or entry_slot == slot)

			if semantic_fallback then
				-- Games Lantern occasionally renders descriptive perk wording that
				-- differs from Darktide's localization/trait tense (for example
				-- "Increase ... by" versus "..._increased_crit_chance"). Canonical
				-- family plus weapon slot is authoritative only when the normal
				-- candidate ranking still yields one unique live mutation identity.
				score = 1
			end

			if score > 0 and family_compatible and (entry_slot == nil or slot == nil or entry_slot == slot) then
				local identity = candidate_identity(entry)
				local existing_index = identity and candidate_indexes[identity]
				local candidate = {entry = entry, score = score}

				if existing_index == nil then
					candidates[#candidates + 1] = candidate
					if identity ~= nil then
						candidate_indexes[identity] = #candidates
					end
				else
					local existing = candidates[existing_index]
					local existing_tier = tonumber(existing.entry and (existing.entry.rarity or existing.entry.tier)) or 0
					local candidate_tier = tonumber(entry and (entry.rarity or entry.tier)) or 0

					if score > existing.score or (score == existing.score and candidate_tier > existing_tier) then
						candidates[existing_index] = candidate
					end
				end
			end
		end

		sorted_candidates(candidates)

		if #candidates == 0 then
			return nil, kind .. "_unavailable_slot_" .. tostring(index), trait_failure_detail(external, entries)
		end

		local top_score = candidates[1].score
		local top_count = 0

		for _, candidate in ipairs(candidates) do
			if candidate.score == top_score then
				top_count = top_count + 1
			end
		end

		if top_count ~= 1 then
			local tied = {}

			for candidate_index = 1, top_count do
				tied[#tied + 1] = candidates[candidate_index].entry
			end

			return nil, kind .. "_ambiguous", trait_failure_detail(external, tied)
		end

		local selected = candidates[1].entry
		local rarity = tonumber(selected.rarity or selected.tier)

		if kind == "blessing" then
			for _, tier in ipairs(selected.tiers or {}) do
				rarity = math.max(rarity or 0, tonumber(tier.tier) or 0)
			end
		end

		if rarity == nil or rarity <= 0 then
			return nil, kind .. "_tier_unavailable"
		end

		for prior_index, prior in ipairs(result) do
			if prior.id == selected.id then
				return nil, kind .. "_duplicate_slots"
			end
		end

		result[index] = {
			id = selected.id,
			rarity = rarity,
			label = external.label or external.name,
			external = external,
		}
	end

	return result, nil
end

local function resolve_identity(external, slot, context)
	local offers = context and (context.offers or (slot == "melee" and context.melee_offers or context.ranged_offers)) or {}
	local resolved, reason = resolve_weapon(external, slot, offers, context and context.classify_offer, context and context.localize_offer_label)

	if not resolved then
		return nil, reason
	end

	local dump_stat, dump_reason = resolve_dump_stat(external, resolved.offer, context and context.localize_offer_label)

	if not dump_stat then
		return nil, dump_reason
	end

	return {
		kind = "games_lantern_job",
		slot = slot,
		display_name = external.display_name,
		offer = resolved.offer,
		external = external,
		dump_stat = dump_stat.id,
		dump_stat_label = dump_stat.label,
		dump_target = tonumber(context and context.dump_target) or 60,
		parent_pattern = resolved.offer.parent_pattern,
		master_id = resolved.offer.master_id,
	}, nil
end

local function attach_catalog(job, catalog, localize_trait_label)
	if type(catalog) ~= "table" or catalog.available ~= true then
		return nil, "trait_catalog_unavailable"
	end

	local external = job.external or {}

	local perks, perk_reason, perk_detail = resolve_traits(external.perks, catalog.perks, "perk", localize_trait_label, job.slot)

	if not perks then
		return nil, perk_reason, perk_detail
	end

	local blessings, blessing_reason, blessing_detail = resolve_traits(external.blessings, catalog.blessings, "blessing", localize_trait_label, job.slot)

	if not blessings then
		return nil, blessing_reason, blessing_detail
	end

	job.perks = perks
	job.blessings = blessings
	job.catalog = catalog

	return job, nil
end

local function resolve_one(external, slot, context)
	local job, reason = resolve_identity(external, slot, context)

	if not job then
		return nil, reason
	end

	local catalog = catalog_for(context, job.offer)
	local completed, catalog_reason = attach_catalog(job, catalog, context and context.localize_offer_label)

	if not completed then
		return nil, catalog_reason
	end

	return completed, nil
end

-- Identity resolution is split from trait resolution so the host can perform
-- the two live read-only catalogue requests without installing a partial
-- queue. Neither function mutates settings, selection, or account state.
function Resolver.resolve_identities(model, context)
	if type(model) ~= "table" or type(model.weapons) ~= "table" then
		return nil, "external_model_unavailable"
	end

	context = context or {}

	local archetype_matches = archetype_compatible(model.source_archetype, context.active_archetype)
	if not model.source_archetype or not context.active_archetype then
		return nil, "archetype_unavailable"
	elseif not archetype_matches then
		return nil, "archetype_mismatch"
	end

	if #model.weapons < 2 then
		return nil, "expected_two_weapons"
	end

	local melee_candidates = {}
	local ranged_candidates = {}
	local melee_failure
	local ranged_failure

	for _, external in ipairs(model.weapons) do
		local melee, melee_reason = resolve_identity(external, "melee", context)
		local ranged, ranged_reason = resolve_identity(external, "ranged", context)

		if melee then
			melee_candidates[#melee_candidates + 1] = melee
		end

		if ranged then
			ranged_candidates[#ranged_candidates + 1] = ranged
		end

		if not melee and melee_reason ~= "unavailable_melee" then
			melee_failure = melee_failure or melee_reason
		end

		if not ranged and ranged_reason ~= "unavailable_ranged" then
			ranged_failure = ranged_failure or ranged_reason
		end
	end

	local choices = context.weapon_choices or {}
	local function selected_candidates(candidates, slot)
		local selected = choices[slot]
		if selected == nil then
			return candidates
		end
		local filtered = {}
		for _, candidate in ipairs(candidates) do
			if tostring(candidate.external and candidate.external.card_index) == tostring(selected) then
				filtered[#filtered + 1] = candidate
			end
		end
		return filtered
	end
	melee_candidates = selected_candidates(melee_candidates, "melee")
	ranged_candidates = selected_candidates(ranged_candidates, "ranged")

	if #melee_candidates > 1 or #ranged_candidates > 1 then
		return nil, "weapon_choice_required", {
			melee = melee_candidates,
			ranged = ranged_candidates,
		}
	end

	if #melee_candidates ~= 1 then
		return nil, #melee_candidates == 0 and (melee_failure or "melee_weapon_unavailable") or "multiple_melee_weapons"
	end

	if #ranged_candidates ~= 1 then
		return nil, #ranged_candidates == 0 and (ranged_failure or "ranged_weapon_unavailable") or "multiple_ranged_weapons"
	end

	return {
		kind = "games_lantern_identity_build",
		resolver_contract_version = Resolver.CONTRACT_VERSION,
		source_uuid = model.source_uuid,
		source_archetype = model.source_archetype,
		jobs = { melee_candidates[1], ranged_candidates[1] },
	}, nil
end

function Resolver.attach_catalogs(identity_build, catalogs, context)
	if type(identity_build) ~= "table" or type(identity_build.jobs) ~= "table" or #identity_build.jobs ~= 2 then
		return nil, "identity_build_unavailable"
	end

	local completed_jobs = {}

	for index, job in ipairs(identity_build.jobs) do
		local key = job.master_id or job.offer and (job.offer.master_id or job.offer.parent_pattern)
		local catalog = type(catalogs) == "table" and key ~= nil and catalogs[key] or nil
		local completed, reason, detail = attach_catalog(job, catalog, context and context.localize_offer_label)

		if not completed then
			return nil, tostring(reason or "trait_catalog_unavailable") .. "_" .. tostring(index), detail
		end

		completed_jobs[index] = completed
	end

	return {
		kind = "games_lantern_build",
		resolver_contract_version = Resolver.CONTRACT_VERSION,
		source_uuid = identity_build.source_uuid,
		source_archetype = identity_build.source_archetype,
		jobs = completed_jobs,
	}, nil
end

function Resolver.resolve(model, context)
	if type(model) ~= "table" or type(model.weapons) ~= "table" then
		return nil, "external_model_unavailable"
	end

	context = context or {}

	local archetype_matches = archetype_compatible(model.source_archetype, context.active_archetype)
	if not model.source_archetype or not context.active_archetype then
		return nil, "archetype_unavailable"
	elseif not archetype_matches then
		return nil, "archetype_mismatch"
	end

	local melee_candidates = {}
	local ranged_candidates = {}

	for _, external in ipairs(model.weapons) do
		local melee, melee_reason = resolve_one(external, "melee", context)
		local ranged, ranged_reason = resolve_one(external, "ranged", context)

		if melee then
			melee_candidates[#melee_candidates + 1] = melee
		end

		if ranged then
			ranged_candidates[#ranged_candidates + 1] = ranged
		end

		if not melee and not ranged and #model.weapons == 2 then
			return nil, tostring(melee_reason or ranged_reason or "weapon_unavailable")
		end
	end

	if #melee_candidates ~= 1 then
		return nil, #melee_candidates == 0 and "melee_weapon_unavailable" or "multiple_melee_weapons"
	end

	if #ranged_candidates ~= 1 then
		return nil, #ranged_candidates == 0 and "ranged_weapon_unavailable" or "multiple_ranged_weapons"
	end

	return {
		kind = "games_lantern_build",
		resolver_contract_version = Resolver.CONTRACT_VERSION,
		source_uuid = model.source_uuid,
		source_archetype = model.source_archetype,
		jobs = {melee_candidates[1], ranged_candidates[1]},
	}, nil
end

Resolver.canonical_archetype = canonical_archetype

Resolver._test = {
	canonical_archetype = canonical_archetype,
	archetype_compatible = archetype_compatible,
	normalize = normalize,
	resolve_dump_stat = resolve_dump_stat,
	resolve_traits = resolve_traits,
	match_score = match_score,
}

return Resolver
