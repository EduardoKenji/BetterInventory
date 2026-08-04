# Release packaging

## Critical archive-root invariant

`BetterInventory.zip` must contain the mod payload directly at the archive root:

```text
BetterInventory.mod
scripts/mods/BetterInventory/BetterInventory.lua
scripts/mods/BetterInventory/BetterInventory_curio_acquisition.lua
scripts/mods/BetterInventory/BetterInventory_curio_values.lua
scripts/mods/BetterInventory/BetterInventory_data.lua
scripts/mods/BetterInventory/BetterInventory_features.lua
scripts/mods/BetterInventory/BetterInventory_layout.lua
scripts/mods/BetterInventory/BetterInventory_localization.lua
```

It must **not** contain an outer `BetterInventory/` directory. Nexus Mod Manager/Vortex installs the archive into `mods/BetterInventory`; an outer directory produces `mods/BetterInventory/BetterInventory/...`, prevents Darktide Mod Framework from finding the mod, and breaks the release for every affected user.

This happened to the NexusMods v1.2.0 package and is a critical production packaging failure. Do not build a release with `Compress-Archive BetterInventory` or by zipping the `BetterInventory` directory itself.

## Mandatory release procedure

Only create the release archive with the repository-owned packager:

```powershell
.\tools\package_release.ps1 -OutputPath "C:\XboxGames\Warhammer 40,000- Darktide\Content\mods\BetterInventory.zip"
```

The packager writes only the eight runtime files, rejects an incorrect archive root or file set, and compares the SHA-256 of every compressed entry with its source file before replacing the destination archive.

Before upload, the command output must end with `BetterInventory release archive verified`, and `tar -tf` must begin with `BetterInventory.mod`, not `BetterInventory/BetterInventory.mod`.

Never upload a hand-built archive, and never treat a successful compression command as sufficient validation.
