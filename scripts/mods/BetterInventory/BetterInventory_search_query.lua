local Query = {}

local DEFAULT_MAX_QUERY_CHARACTERS = 128
local DEFAULT_MAX_QUERY_BYTES = 512
local DEFAULT_MAX_CLAUSES = 16

local FIELD_ALIASES = {
	base = "base",
	bless = "blessing",
	blessing = "blessing",
	equipped = "equipped",
	favorite = "favorite",
	favourite = "favorite",
	mark = "mark",
	name = "name",
	loadout = "loadout",
	saved_loadout = "loadout",
	["saved-loadout"] = "loadout",
	native_quality = "native_rarity",
	["native-quality"] = "native_rarity",
	native_rarity = "native_rarity",
	["native-rarity"] = "native_rarity",
	new = "new",
	perk = "perk",
	perfect = "perfect",
	quality = "rarity",
	rarity = "rarity",
	rating = "rating",
	type = "type",
}

local NUMERIC_FIELDS = {
	base = true,
	rating = true,
}

local BOOLEAN_FIELDS = {
	equipped = true,
	favorite = true,
	loadout = true,
	new = true,
	perfect = true,
}

local ENGLISH_RARITY_ALIASES = {
	anointed = "anointed",
	exalted = "exalted",
	profane = "profane",
	redeemed = "redeemed",
	sainted = "sainted",
	transcendent = "transcendent",
}

local function utf8_lower(value)
	local utf8 = rawget(_G, "Utf8")

	if type(utf8) == "table" and type(utf8.lower) == "function" then
		local ok, lowered = pcall(utf8.lower, value)

		if ok and type(lowered) == "string" then
			return lowered
		end
	end

	return string.lower(value)
end

local function trim(value)
	return string.match(value or "", "^%s*(.-)%s*$") or ""
end

local function normalize(value)
	if type(value) ~= "string" then
		value = tostring(value or "")
	end

	return string.gsub(trim(utf8_lower(value)), "%s+", " ")
end

local function utf8_length(value)
	local utf8 = rawget(_G, "Utf8")

	if type(utf8) == "table" and type(utf8.string_length) == "function" then
		local ok, length = pcall(utf8.string_length, value)

		if ok and type(length) == "number" then
			return length
		end
	end

	local _, continuation_bytes = string.gsub(value, "[\128-\191]", "")

	return #value - continuation_bytes
end

local function invalid(source, code)
	return {
		clauses = {},
		empty = true,
		error = code,
		fail_open = true,
		source = source,
		valid = false,
	}
end

local function split_clauses(source, maximum)
	local clauses = {}
	local buffer = {}
	local quoted = false
	local escaped = false

	for index = 1, #source do
		local character = string.sub(source, index, index)

		if character == "\\" and not escaped then
			escaped = true
			buffer[#buffer + 1] = character
		elseif character == '"' and not escaped then
			quoted = not quoted
			buffer[#buffer + 1] = character
		elseif character == "&" and not quoted then
			local clause = trim(table.concat(buffer))
			buffer = {}

			if clause ~= "" then
				clauses[#clauses + 1] = clause

				if #clauses > maximum then
					return nil, "too_many_clauses"
				end
			end
			escaped = false
		else
			buffer[#buffer + 1] = character
			escaped = false
		end
	end

	if quoted then
		return nil, "unterminated_quote"
	end

	local clause = trim(table.concat(buffer))

	if clause ~= "" then
		clauses[#clauses + 1] = clause
	end

	if #clauses > maximum then
		return nil, "too_many_clauses"
	end

	return clauses
end

local function unquote(value)
	value = trim(value)

	if string.sub(value, 1, 1) ~= '"' then
		return value
	end

	if #value < 2 or string.sub(value, -1) ~= '"' then
		return nil, "unterminated_quote"
	end

	value = string.sub(value, 2, -2)
	value = string.gsub(value, '\\"', '"')
	value = string.gsub(value, "\\\\", "\\")

	return value
end

local function build_rarity_aliases(options)
	local aliases = {}

	for alias, canonical in pairs(ENGLISH_RARITY_ALIASES) do
		aliases[alias] = canonical
	end

	for alias, canonical in pairs(options and options.rarity_aliases or {}) do
		local normalized_alias = normalize(alias)
		local normalized_canonical = normalize(canonical)

		if normalized_alias ~= "" and normalized_canonical ~= "" then
			aliases[normalized_alias] = normalized_canonical
		end
	end

	return aliases
end

local function parse_number_clause(field, value)
	local range_start = string.find(value, "..", 1, true)

	if range_start then
		local minimum = tonumber(trim(string.sub(value, 1, range_start - 1)))
		local maximum = tonumber(trim(string.sub(value, range_start + 2)))

		if minimum == nil or maximum == nil or minimum ~= minimum or maximum ~= maximum then
			return nil, "invalid_number"
		end

		if minimum > maximum then
			minimum, maximum = maximum, minimum
		end

		return {
			field = field,
			kind = "number_range",
			maximum = maximum,
			minimum = minimum,
		}
	end

	local operators = { ">=", "<=", ">", "<" }

	for index = 1, #operators do
		local operator = operators[index]

		if string.sub(value, 1, #operator) == operator then
			local number = tonumber(trim(string.sub(value, #operator + 1)))

			if number == nil or number ~= number then
				return nil, "invalid_number"
			end

			return {
				field = field,
				kind = "number_compare",
				number = number,
				operator = operator,
			}
		end
	end

	local number = tonumber(value)

	if number == nil or number ~= number then
		return nil, "invalid_number"
	end

	return {
		field = field,
		kind = "number_equal",
		number = number,
	}
end

local function parse_boolean_clause(field, value)
	local truthy = value == "true" or value == "yes" or value == "on" or value == "1"
	local falsy = value == "false" or value == "no" or value == "off" or value == "0"

	if not truthy and not falsy then
		return nil, "invalid_boolean"
	end

	return {
		field = field,
		kind = "boolean",
		value = truthy,
	}
end

local function parse_text_clause(field, value, rarity_aliases)
	local normalized = normalize(value)

	if normalized == "" then
		return nil, "empty_value"
	end

	if field == "rarity" or field == "native_rarity" then
		local canonical = rarity_aliases[normalized]

		if canonical then
			return {
				field = field,
				kind = "text_equal",
				value = canonical,
			}
		end

		if field == "native_rarity" and tonumber(normalized) ~= nil then
			return {
				field = field,
				kind = "text_equal",
				value = normalized,
			}
		end
	end

	return {
		field = field,
		kind = "text_contains",
		value = normalized,
	}
end

local function parse_clause(raw_clause, rarity_aliases)
	local alias, raw_value = string.match(raw_clause, "^([%w_%-]+)%s*:%s*(.-)%s*$")
	local field = alias and FIELD_ALIASES[normalize(alias)]

	if alias and field then
		local value, quote_error = unquote(raw_value)

		if value == nil then
			return nil, quote_error
		end

		value = normalize(value)

		if NUMERIC_FIELDS[field] then
			return parse_number_clause(field, value)
		elseif BOOLEAN_FIELDS[field] then
			return parse_boolean_clause(field, value)
		end

		return parse_text_clause(field, value, rarity_aliases)
	end

	local value, quote_error = unquote(raw_clause)

	if value == nil then
		return nil, quote_error
	end

	value = normalize(value)

	if value == "" then
		return nil, "empty_value"
	end

	local rarity = rarity_aliases[value]

	if rarity then
		return {
			field = "rarity",
			kind = "text_equal",
			value = rarity,
		}
	end

	local number = tonumber(value)

	if number ~= nil and number == number then
		return {
			kind = "number_any_equal",
			number = number,
		}
	end

	return {
		field = "text",
		kind = "text_contains",
		value = value,
	}
end

Query.compile = function(source, options)
	options = type(options) == "table" and options or {}
	source = type(source) == "string" and source or tostring(source or "")
	local maximum_characters = tonumber(options.max_query_characters) or DEFAULT_MAX_QUERY_CHARACTERS
	local maximum_bytes = tonumber(options.max_query_bytes) or DEFAULT_MAX_QUERY_BYTES
	local maximum_clauses = tonumber(options.max_clauses) or DEFAULT_MAX_CLAUSES

	if #source > maximum_bytes or utf8_length(source) > maximum_characters then
		return invalid(source, "query_too_long")
	end

	local raw_clauses, split_error = split_clauses(source, maximum_clauses)

	if not raw_clauses then
		return invalid(source, split_error)
	end

	local rarity_aliases = build_rarity_aliases(options)
	local clauses = {}

	for index = 1, #raw_clauses do
		local clause, parse_error = parse_clause(raw_clauses[index], rarity_aliases)

		if not clause then
			return invalid(source, parse_error)
		end

		clauses[#clauses + 1] = clause
	end

	return {
		clauses = clauses,
		empty = #clauses == 0,
		fail_open = false,
		source = source,
		valid = true,
	}
end

local function text_contains(value, expected)
	return type(value) == "string" and string.find(value, expected, 1, true) ~= nil
end

local function any_text_value(record, field, expected, exact)
	local value = record and record[field]

	if type(value) == "string" then
		return exact and value == expected or not exact and text_contains(value, expected)
	elseif type(value) == "table" then
		for index = 1, #value do
			local candidate = value[index]

			if exact and candidate == expected or not exact and text_contains(candidate, expected) then
				return true
			end
		end
	end

	return false
end

local function number_matches(clause, value)
	if type(value) ~= "number" then
		return false
	elseif clause.kind == "number_equal" then
		return value == clause.number
	elseif clause.kind == "number_range" then
		return value >= clause.minimum and value <= clause.maximum
	elseif clause.operator == ">=" then
		return value >= clause.number
	elseif clause.operator == "<=" then
		return value <= clause.number
	elseif clause.operator == ">" then
		return value > clause.number
	elseif clause.operator == "<" then
		return value < clause.number
	end

	return false
end

local function clause_matches(clause, record)
	if clause.kind == "text_contains" then
		return any_text_value(record, clause.field, clause.value, false)
	elseif clause.kind == "text_equal" then
		return any_text_value(record, clause.field, clause.value, true)
	elseif clause.kind == "boolean" then
		return record and record[clause.field] == clause.value
	elseif clause.kind == "number_any_equal" then
		return record and (record.rating == clause.number or record.base == clause.number)
	end

	return number_matches(clause, record and record[clause.field])
end

Query.matches = function(compiled, record)
	if type(compiled) ~= "table" or compiled.fail_open == true or compiled.empty == true then
		return true
	end

	for index = 1, #compiled.clauses do
		if not clause_matches(compiled.clauses[index], record) then
			return false
		end
	end

	return true
end

Query.rank = function(compiled, record, matched, prioritize_equipped)
	if matched ~= true then
		return 0
	elseif type(compiled) ~= "table" or compiled.fail_open == true or compiled.empty == true then
		return 1
	end

	local primary_match = false
	local secondary_match = false

	for index = 1, #compiled.clauses do
		local clause = compiled.clauses[index]

		if (clause.field == "text" or clause.field == "perk") and (clause.kind == "text_contains" or clause.kind == "text_equal") then
			local exact = clause.kind == "text_equal"
			primary_match = primary_match or any_text_value(record, "curio_primary", clause.value, exact)
			secondary_match = secondary_match or any_text_value(record, "curio_secondary", clause.value, exact)
		end
	end

	if not primary_match and not secondary_match then
		return 1
	end

	-- Rank 7..2 encodes the requested Curio hierarchy while rank 1 remains
	-- the ordinary matched group and rank 0 remains unmatched. Existing
	-- Better Inventory/native sorting is still the tie-breaker inside a group.
	return 1 + (prioritize_equipped ~= false and record and record.equipped == true and 3 or 0) + (primary_match and 2 or 0) + (secondary_match and 1 or 0)
end

Query.normalize = normalize
Query.default_rarity_aliases = ENGLISH_RARITY_ALIASES
Query.limits = {
	max_clauses = DEFAULT_MAX_CLAUSES,
	max_query_bytes = DEFAULT_MAX_QUERY_BYTES,
	max_query_characters = DEFAULT_MAX_QUERY_CHARACTERS,
}

return Query
