-- Repository-owned fixture of the DMF reload boundary used by BetterInventory.
-- tests/verify.ps1 separately checks installed current and legacy DMF sources
-- when those optional external trees are available.
local function reload_mods(dmf)
	dmf.mods_unload_event(false)
	dmf.hooks_unload()
end

return reload_mods
