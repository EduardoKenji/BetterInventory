-- Bounded, versioned parser for the server-rendered Games Lantern equipment
-- cards.  It is intentionally independent of Lantern of the Omnissiah and has
-- no side effects.  Resolver code must still map these external labels to the
-- live Darktide catalogue before any planner or account state changes.
local Parser = {}

Parser.CONTRACT_VERSION = "games_lantern_html_v1"
Parser.MAX_HTML_BYTES = 2 * 1024 * 1024
Parser.MAX_WEAPONS = 16
Parser.MAX_STATS = 16
Parser.MAX_PERKS = 4
Parser.MAX_BLESSINGS = 4

local function trim(value)
	if type(value) ~= "string" then
		return nil
	end

	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function unescape_html(value)
	value = trim(value)

	if not value then
		return nil
	end

	return (value
		:gsub("&#0?39;", "'")
		:gsub("&#x27;", "'")
		:gsub("&quot;", '"')
		:gsub("&amp;", "&")
		:gsub("&lt;", "<")
		:gsub("&gt;", ">"))
end

local function bounded_label(value, max_bytes)
	value = unescape_html(value)

	if not value or #value == 0 or #value > max_bytes then
		return nil
	end

	return value
end

local function parse_weapon_block(block)
	local display_name = bounded_label(block:match('<div class="text%-xl">([^<]+)</div>'), 160)
	local rarity = bounded_label(block:match('<div class="text%-md"%s*>([^<]+)</div>'), 64)
	local family, mark = block:match('href="[^\"]*/weapons/([^/]+)/([^\"]+)"')
	family = bounded_label(family, 120)
	mark = bounded_label(mark, 160)

	if not display_name or not rarity or not family or not mark then
		return nil, "incomplete_weapon_identity"
	end

	local perks = {}
	local seen_perks = {}

	for perk in block:gmatch('rotate%-45"></div>%s*<div class="text%-%[#D1FFC3%] font%-bold text%-sm">([^<]+)</div>') do
		if #perks >= Parser.MAX_PERKS then
			return nil, "too_many_perks"
		end

		local label = bounded_label(perk, 240)

		if not label then
			return nil, "invalid_perk"
		end
		local perk_key = string.lower(label)
		if seen_perks[perk_key] then
			return nil, "duplicate_perk"
		end
		seen_perks[perk_key] = true

		perks[#perks + 1] = {label = label}
	end

	local blessings = {}
	local seen_blessings = {}

	for trait_id, inner in block:gmatch('weapon_trait_(%d+)%.webp[^/]*/>%s*<div[^>]*>(.-)</div>') do
		if #blessings >= Parser.MAX_BLESSINGS then
			return nil, "too_many_blessings"
		end

		local blessing_name = bounded_label(inner:match('<h3[^>]*>([^<]+)</h3>'), 160)
		local description = bounded_label(inner:match('<p[^>]*>([^<]+)</p>') or "", 480) or ""

		if not blessing_name or #trait_id == 0 then
			return nil, "invalid_blessing"
		end
		local blessing_key = string.lower(blessing_name)
		if seen_blessings[blessing_key] then
			return nil, "duplicate_blessing"
		end
		seen_blessings[blessing_key] = true

		blessings[#blessings + 1] = {
			label = blessing_name,
			description = description,
			external_icon_id = trait_id,
		}
	end

	local stats = {}
	local seen_stats = {}

	for label, percentage in block:gmatch(
		'font%-semibold whitespace%-nowrap text%-sm text%-%[#D1FFC3%]">([^<]+)</div>'
			.. '%s*<div[^>]*>%s*<div[^>]*style="width:%s*(%d+)%%') do
		if #stats >= Parser.MAX_STATS then
			return nil, "too_many_stats"
		end

		local stat_label = bounded_label(label, 120)
		local stat_value = tonumber(percentage)

		if not stat_label or not stat_value or stat_value < 0 or stat_value > 100 then
			return nil, "invalid_stat"
		end
		local stat_key = string.lower(stat_label)
		if seen_stats[stat_key] then
			return nil, "duplicate_stat"
		end
		seen_stats[stat_key] = true

		stats[#stats + 1] = {
			label = stat_label,
			value = stat_value,
		}
	end

	-- A card with missing target traits is not a usable typed target.  Returning
	-- an unsupported-format error prevents later code from guessing or applying
	-- a partial build.
	if #stats == 0 or #perks ~= 2 or #blessings ~= 2 then
		return nil, "incomplete_weapon_traits"
	end

	return {
		display_name = display_name,
		rarity = rarity,
		external_family_slug = family,
		external_mark_slug = mark,
		stats = stats,
		perks = perks,
		blessings = blessings,
	}
end

local function page_field(html, pattern, max_bytes)
	return bounded_label(html:match(pattern), max_bytes)
end

local function canonical_build_uuid(html)
	for tag in html:gmatch("<link[^>]+>") do
		if string.lower(tag):find("canonical", 1, true) then
			local href = tag:match('href=["\']([^"\']+)["\']')
			local uuid = href and href:match("darktide%.gameslantern%.com/builds/(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)")
			if uuid then return string.lower(uuid) end
		end
	end

	return nil
end

local function unique_archetype(html)
	local found = {}
	local count = 0
	local function include(slug)
		local normalized_slug = bounded_label(slug, 80)
		if normalized_slug and not found[normalized_slug] then
			found[normalized_slug] = true
			count = count + 1
		end
	end
	for slug in html:gmatch('href=["\'][^"\']*/classes/([^"\'/?#]+)["\']') do
		include(slug)
	end
	-- Current build breadcrumbs link to /builds/<archetype> rather than the
	-- older /classes/<archetype> route.  Requiring the quote immediately after
	-- the slug excludes /builds/<uuid>/<title> build links.
	for slug in html:gmatch('href=["\'][^"\']*/builds/([^"\'/?#]+)["\']') do
		include(slug)
	end
	if count ~= 1 then return nil end
	for slug in pairs(found) do return slug end
end

function Parser.parse(html)
	if type(html) ~= "string" then
		return nil, "response_not_text"
	end

	if #html == 0 then
		return nil, "empty_response"
	end

	if #html > Parser.MAX_HTML_BYTES then
		return nil, "response_too_large"
	end

	local lowered = string.lower(html)
	local has_weapons_anchor = lowered:find('id="weapons"', 1, true) or lowered:find("id='weapons'", 1, true)
	local challenge_only = lowered:find("challenge%-platform") and not has_weapons_anchor
	if lowered:find("captcha", 1, true) or challenge_only or lowered:find("please log in", 1, true) or lowered:find("sign in to continue", 1, true) then
		return nil, "login_or_challenge_page"
	end

	if not has_weapons_anchor then
		return nil, "weapons_section_unavailable"
	end

	local weapons = {}
	local card_count = 0

	-- Games Lantern changed the weapons container from a section to a div in
	-- 2026.  Card boundaries remain stable, so scan the bounded page after
	-- requiring the explicit weapons anchor instead of coupling to a tag name.
	for block in html:gmatch('<div class="max%-w%-sm w%-full">(.-)weapon_box_bottom%.webp') do
		card_count = card_count + 1

		if card_count > Parser.MAX_WEAPONS then
			return nil, "too_many_weapon_cards"
		end

		if block:find('/weapons/', 1, true) then
			local weapon, reason = parse_weapon_block(block)

			if not weapon then
				return nil, reason
			end

			weapon.card_index = card_count
			weapons[#weapons + 1] = weapon
		end
	end

	if #weapons == 0 then
		return nil, card_count > 0 and "no_structured_weapon_cards" or "unsupported_html_format"
	end

	return {
		parser_contract_version = Parser.CONTRACT_VERSION,
		source_uuid = canonical_build_uuid(html),
		source_title = page_field(html, '<title[^>]*>(.-)</title>', 240),
		source_author = page_field(html, 'By%s*</[^>]+>%s*([^<]+)', 120),
		source_archetype = unique_archetype(html),
		weapons = weapons,
		curios = {},
	}
end

Parser._test = {
	trim = trim,
	unescape_html = unescape_html,
	parse_weapon_block = parse_weapon_block,
	canonical_build_uuid = canonical_build_uuid,
	unique_archetype = unique_archetype,
}

return Parser
