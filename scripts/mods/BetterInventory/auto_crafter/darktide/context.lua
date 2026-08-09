local Context = {}

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
