local Context = {}

local function read_member(value, key)
	return value[key]
end

local function safe_member(value, key)
	if type(value) ~= "table" and type(value) ~= "userdata" then
		return nil
	end

	local ok, result = pcall(read_member, value, key)

	return ok and result or nil
end

local function live_player()
	local managers = rawget(_G, "Managers")
	local player_manager = managers and managers.player
	local local_player = player_manager and player_manager.local_player

	if type(local_player) ~= "function" then
		return nil
	end

	local ok, player = pcall(local_player, player_manager, 1)

	return ok and player and not safe_member(player, "__deleted") and player or nil
end

local function is_brunt_view_class(view)
	local class_name = view and view.__class_name

	return class_name == "CreditsGoodsVendorView"
end

local function current_game_mode_name()
	local managers = rawget(_G, "Managers")
	local state = managers and managers.state
	local game_mode = state and state.game_mode

	if not game_mode or type(game_mode.game_mode_name) ~= "function" then
		return nil
	end

	local ok, name = pcall(game_mode.game_mode_name, game_mode)

	return ok and name or nil
end

local function mission_matchmaking_active()
	local managers = rawget(_G, "Managers")
	local party = managers and managers.party_immaterium

	if not party or type(party.is_in_matchmaking) ~= "function" then
		return false
	end

	local ok, active = pcall(party.is_in_matchmaking, party)

	return ok and active == true
end

function Context.new(dependencies)
	dependencies = dependencies or {}

	local context = {}

	function context:current_identity()
		if type(dependencies.current_identity) == "function" then
			local ok, identity = pcall(dependencies.current_identity)

			if ok and type(identity) == "table" then
				return identity
			end
		end

		if type(dependencies.current_character_id) == "function" or type(dependencies.current_archetype) == "function" then
			local id_ok, character_id = pcall(dependencies.current_character_id or function() end)
			local archetype_ok, archetype = pcall(dependencies.current_archetype or function() end)

			return {
				archetype = archetype_ok and archetype or nil,
				character_id = id_ok and character_id ~= nil and tostring(character_id) or nil,
				stable = true,
			}
		end

		local player = live_player()
		if not player then
			return {
				reason = "character_context_unavailable",
				stable = false,
			}
		end

		local player_character_id
		local character_id_method = safe_member(player, "character_id")
		if type(character_id_method) == "function" then
			local id_ok, value = pcall(character_id_method, player)
			player_character_id = id_ok and value ~= nil and tostring(value) or nil
		end

		local profile
		local profile_method = safe_member(player, "profile")
		if type(profile_method) == "function" then
			local profile_ok, value = pcall(profile_method, player)
			profile = profile_ok and value or nil
		end

		local profile_character_id = safe_member(profile, "character_id")
		profile_character_id = profile_character_id ~= nil and tostring(profile_character_id) or nil
		local archetype = safe_member(profile, "archetype")
		local archetype_name = safe_member(archetype, "name") or safe_member(archetype, "archetype_name")
		local mismatched = player_character_id and profile_character_id and player_character_id ~= profile_character_id
		local complete = (player_character_id or profile_character_id) ~= nil and archetype_name ~= nil
		local stable = complete and not mismatched

		return {
			archetype = stable and archetype_name and tostring(archetype_name) or nil,
			character_id = stable and (player_character_id or profile_character_id) or nil,
			player_character_id = player_character_id,
			profile_character_id = profile_character_id,
			reason = stable and nil or mismatched and "character_context_settling" or "character_context_unavailable",
			stable = stable,
		}
	end

	function context:current_character_id()
		local identity = self:current_identity()

		return identity and identity.stable ~= false and identity.character_id or nil
	end

	function context:current_archetype()
		local identity = self:current_identity()

		return identity and identity.stable ~= false and identity.archetype or nil
	end

	function context:is_morningstar()
		local mode_name = current_game_mode_name()

		return mode_name == "hub" or mode_name == "hub_singleplay"
	end

	function context:is_runtime_valid()
		return self:is_morningstar() and not mission_matchmaking_active()
	end

	function context:is_valid_brunt_view(view)
		if not view then
			return false
		end

		if view._destroyed == true then
			return false
		end

		local mode_name = current_game_mode_name()

		-- During view setup the game-mode object can briefly be unavailable. Do
		-- not reject a valid Brunt view during that narrow initialization window;
		-- update() will close it as soon as a non-hub mode is observable.
		if mode_name and mode_name ~= "hub" and mode_name ~= "hub_singleplay" then
			return false
		end

		if type(dependencies.is_brunt_view) == "function" then
			local ok, result = pcall(dependencies.is_brunt_view, view)

			return ok and result == true
		end

		return is_brunt_view_class(view)
	end

	return context
end

return Context
