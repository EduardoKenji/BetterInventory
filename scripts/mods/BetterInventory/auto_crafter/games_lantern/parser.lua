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

	for perk in block:gmatch('rotate%-45"></div>%s*<div class="text%-%[#D1FFC3%] font%-bold text%-sm">([^<]+)</div>') do
		if #perks >= Parser.MAX_PERKS then
			return nil, "too_many_perks"
		end

		local label = bounded_label(perk, 240)

		if not label then
			return nil, "invalid_perk"
		end

		perks[#perks + 1] = {label = label}
	end

	local blessings = {}

	for trait_id, inner in block:gmatch('weapon_trait_(%d+)%.webp[^/]*/>%s*<div[^>]*>(.-)</div>') do
		if #blessings >= Parser.MAX_BLESSINGS then
			return nil, "too_many_blessings"
		end

		local blessing_name = bounded_label(inner:match('<h3[^>]*>([^<]+)</h3>'), 160)
		local description = bounded_label(inner:match('<p[^>]*>([^<]+)</p>') or "", 480) or ""

		if not blessing_name or #trait_id == 0 then
			return nil, "invalid_blessing"
		end

		blessings[#blessings + 1] = {
			label = blessing_name,
			description = description,
			external_icon_id = trait_id,
		}
	end

	local stats = {}

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

	local weapons = {}
	local card_count = 0

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
		source_title = page_field(html, '<title[^>]*>(.-)</title>', 240),
		source_author = page_field(html, 'By%s*</[^>]+>%s*([^<]+)', 120),
		source_archetype = page_field(html, 'href="/classes/([^"/?]+)', 80),
		weapons = weapons,
		curios = {},
	}
end

Parser._test = {
	trim = trim,
	unescape_html = unescape_html,
	parse_weapon_block = parse_weapon_block,
}

return Parser
