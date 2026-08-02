return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`BetterInventory` encountered an error loading the Darktide Mod Framework.")

		new_mod("BetterInventory", {
			mod_script = "BetterInventory/scripts/mods/BetterInventory/BetterInventory",
			mod_data = "BetterInventory/scripts/mods/BetterInventory/BetterInventory_data",
			mod_localization = "BetterInventory/scripts/mods/BetterInventory/BetterInventory_localization",
		})
	end,
	packages = {},
}
