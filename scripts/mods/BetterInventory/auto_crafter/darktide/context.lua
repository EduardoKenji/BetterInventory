local Context = {}

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

function Context.new(dependencies)
	dependencies = dependencies or {}

	local context = {}

	function context:is_morningstar()
		local mode_name = current_game_mode_name()

		return mode_name == "hub" or mode_name == "hub_singleplay"
	end

	function context:is_runtime_valid()
		return self:is_morningstar()
	end

	function context:is_valid_brunt_view(view)
		if not view then
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

		return true
	end

	return context
end

return Context
