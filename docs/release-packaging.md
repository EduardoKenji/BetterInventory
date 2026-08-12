# Release packaging

## Critical Nexus archive invariant

The BetterInventory v2.1.6 release archive must contain exactly one install directory named `BetterInventory`. Every ZIP entry name must use a forward slash (`/`), never a Windows backslash (`\`). The descriptor and every `.lua` file recursively beneath `scripts/mods/BetterInventory` are mandatory runtime files, including portable subtrees such as `auto_crafter/`. The exact source set is recorded in `docs/generated-runtime-bundle-manifest.json` and is therefore not duplicated here:

Use the manifest as the authoritative list when inspecting an archive; the
packager and verifier discover the same set directly from the runtime source
directory.

This is the archive layout used by known-good Nexus releases in `Inventory2D_mod_research`, including Inventory2D, Quick Look Card and Alf's DMF Extensions. It lets a mod manager install the outer directory directly as `Darktide/mods/BetterInventory`.

The following layouts are both release-blocking failures:

```text
# Missing install directory; a manager installs `scripts` as the mod folder.
BetterInventory.mod
scripts/mods/BetterInventory/...

# Duplicate install directory; the loader cannot find the descriptor where expected.
BetterInventory/BetterInventory/BetterInventory.mod
BetterInventory/BetterInventory/scripts/...
```

Backslash-bearing entry names such as `BetterInventory\scripts\...` are also invalid even when an archive viewer makes the hierarchy look plausible. ZIP paths are portable forward-slash paths; Nexus tooling can interpret backslashes as literal filename characters or construct an incorrect nested install.

## Incident history and root cause

- The NexusMods v1.2.0 archive included the required outer directory but encoded paths with Windows backslashes. That was the original production failure.
- The attempted safeguard incorrectly diagnosed the outer directory as the problem. It normalized backslashes during verification, removed the required install directory, and produced a rootless archive that worked only when manually extracted into an already-created `mods/BetterInventory` folder.
- The verifier therefore validated an internally consistent but Nexus-incompatible archive. A successful hash comparison did not validate installation semantics.
- The NexusMods v1.7.0 archive omitted `BetterInventory_item_customization.lua`. Both packager and verifier used the same manually maintained file list, so the duplicated omission passed. Packaging now discovers every runtime Lua source, while verification independently derives the required archive set from the source tree and checks every local `io_dofile` dependency.

The invariant is now based on direct comparison with known-good Nexus mod archives: **one outer mod directory, no duplicate directory, forward slashes only**.

## Mandatory release procedure

Only create the release archive with the repository-owned packager:

```powershell
.\tools\package_release.ps1 -OutputPath "C:\XboxGames\Warhammer 40,000- Darktide\Content\mods\BetterInventory.zip"
```

The packager:

1. recursively discovers and writes the descriptor plus every `.lua` runtime source beneath one `BetterInventory/` directory;
2. constructs entry names explicitly with forward slashes;
3. rejects rootless files, a duplicated outer directory, backslash-bearing names or any unexpected file;
4. compares every compressed entry's SHA-256 with its source file before replacing the destination archive.
5. is independently tested against the runtime source directory, including a check that every locally loaded `io_dofile` module exists in the archive.

Before upload, the command output must end with `BetterInventory release archive verified`. Independently inspect the archive and confirm its first file is:

```text
BetterInventory/BetterInventory.mod
```

Never upload a hand-built archive, never use `Compress-Archive` for the release, and never treat successful compression or source-hash equality alone as sufficient validation.

## Installed-runtime synchronization

Before live testing, synchronize the runtime payload into the installed mod directory:

```powershell
.\tools\sync_installed_mod.ps1
```

The command is deliberately limited to `Content\mods\BetterInventory`, copies the descriptor and every runtime Lua file, and verifies the resulting file set and SHA-256 hashes. It does not copy tests, docs, archives, or user logs, and it does not remove unrelated non-runtime files from an existing managed checkout. Run it again after every runtime source change before collecting in-game evidence.
