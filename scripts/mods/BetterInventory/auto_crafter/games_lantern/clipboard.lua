-- Pure Games Lantern URL extraction.  This module deliberately has no clipboard,
-- filesystem, process, or network access; the platform adapter owns those concerns.
local Clipboard = {}

Clipboard.MAX_INPUT_BYTES = 4096
Clipboard.HOST = "darktide.gameslantern.com"
Clipboard.PATH_PREFIX = "https://darktide.gameslantern.com/builds/"

local UUID_LENGTH = 36
local UUID_PATTERN = "^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]%-[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]%-[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]%-[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]%-[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]"

local function safe_text(value)
	return type(value) == "string" and value or nil
end

local function valid_boundary(character)
	if character == "" then
		return true
	end

	-- A slug, query, fragment, or surrounding clipboard punctuation may follow
	-- the UUID.  Alphanumeric, dot, underscore, and hyphen continuation is not
	-- accepted because it would make the identifier ambiguous or malformed.
	return string.find(character, "^[/?#%s\"'<>]$") ~= nil
end

local function find_candidate(text, from)
	local prefix_start, prefix_end = string.find(text, Clipboard.PATH_PREFIX, from, true)

	if not prefix_start then
		return nil, nil, "missing_url"
	end

	local uuid_start = prefix_end + 1
	local uuid = string.sub(text, uuid_start, uuid_start + UUID_LENGTH - 1)

	if #uuid ~= UUID_LENGTH or not string.match(uuid, UUID_PATTERN) then
		return nil, prefix_start, "malformed_uuid"
	end

	local following = string.sub(text, uuid_start + UUID_LENGTH, uuid_start + UUID_LENGTH)

	if not valid_boundary(following) then
		return nil, prefix_start, "invalid_url_boundary"
	end

	return string.lower(uuid), prefix_start, nil
end

function Clipboard.extract_url(text)
	text = safe_text(text)

	if not text or #text == 0 then
		return nil, "empty_clipboard"
	end

	if #text > Clipboard.MAX_INPUT_BYTES then
		return nil, "clipboard_too_large"
	end

	local uuid, first_start, reason = find_candidate(text, 1)

	if not uuid then
		return nil, reason
	end

	local second_uuid, second_start, second_reason = find_candidate(text, first_start + #Clipboard.PATH_PREFIX)

	if second_uuid or second_reason ~= "missing_url" then
		return nil, second_uuid and "multiple_urls" or second_reason
	end

	return Clipboard.PATH_PREFIX .. uuid
end

function Clipboard.is_canonical_url(value)
	return type(value) == "string" and #value == #Clipboard.PATH_PREFIX + UUID_LENGTH and Clipboard.extract_url(value) == value
end

return Clipboard
