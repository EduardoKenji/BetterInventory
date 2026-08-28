local Compatibility = {}

-- LobbyView reuses a UIProfileSpawner after calling destroy() when its weapon
-- presentation changes. UIProfileSpawner.destroy() releases and nils the
-- single-item loader, while spawn_profile() assumes init/reset already owns a
-- live loader. Reinitialize only at that impossible-after-init boundary. This
-- preserves native profile loading and every third-party spawn_profile hook.
local function prepare_reused_spawner(profile_spawner)
	if type(profile_spawner) ~= "table"
		or profile_spawner._single_item_profile_loader ~= nil
		or type(profile_spawner._reference_name) ~= "string"
		or type(profile_spawner._item_definitions) ~= "table"
		or type(profile_spawner.reset) ~= "function" then
		return false
	end

	profile_spawner:reset()

	return profile_spawner._single_item_profile_loader ~= nil
end

Compatibility.prepare_reused_spawner = prepare_reused_spawner

Compatibility.install = function(mod, UIProfileSpawner)
	if type(mod) ~= "table"
		or type(mod.hook) ~= "function"
		or type(UIProfileSpawner) ~= "table"
		or type(UIProfileSpawner.spawn_profile) ~= "function" then
		return false
	end

	mod:hook(UIProfileSpawner, "spawn_profile", function(func, profile_spawner, ...)
		prepare_reused_spawner(profile_spawner)

		return func(profile_spawner, ...)
	end)

	return true
end

return Compatibility
