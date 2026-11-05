# BetterInventory: notes for Claude Code sessions

A Darktide mod (LuaJIT on the Darktide Mod Framework) with a Python+lupa test suite.

Read `docs/engineering-notes.md` before researching engine, DMF, mod
compatibility or release workflow questions. It records facts already verified
against source, so they don't need re-deriving. Other references:
- architecture and ownership: `docs/architecture.md`
- latest release audit and deferred findings: `docs/v3.8.0-darktide-1.13.4-audit.md`
- what users see: `docs/user-guide.md`

## Locations

- Develop in this repo. `../../mods/BetterInventory` is the Vortex-deployed
  install. Update it only with `tools/sync_installed_mod.ps1`, and only when asked.
- Decompiled game source: `../../Darktide-Source-Code`. Run
  `git pull --ff-only` there to update it.
- DMF: `../../mods/dmf` (installed) and `../../Darktide-Mod-Framework` (git checkout).
- Runtime Lua: `scripts/mods/BetterInventory/`. Settings defaults:
  `BetterInventory_data.lua`. Localization: `BetterInventory_localization_*.lua`.
  Every new key needs both en and zh-CN.

## Every change must pass

```
PYTHONPATH=tests python tests/run_tests.py --timeout-seconds 600
python tools/generate_runtime_bundle_manifest.py     # after runtime edits
python tools/generate_schema_manifest.py             # after settings/localization edits
powershell -File tools/package_release.ps1 -OutputPath BetterInventory.zip
powershell -File tests/verify.ps1 -DarktideSourcePath ../../Darktide-Source-Code
```

Gotchas:
- After inserting lines in a test, run `python tools/remap_manifest.py . <test.py>`
  to update `tests/case_manifest.json`.
- Each runtime module is limited to 100,000 bytes.
- Darktide's `class()` copies superclass methods into subclasses, so a hook on a
  base class needs forwarders (`ensure_class_method`).
- Code fallbacks must match the defaults in `data.lua`.
- `verify.ps1` holds source-text contracts. Update them on purpose when a
  contract changes.

## Conventions

- **Branches:** one branch per release (`v3.x.y`), fast-forwarded into `main`.
  Push only when the user says so.
- **Versions:** bump in 5 places: `info.json`, `BetterInventory_data.lua`
  `MOD_VERSION`, `README.md` banner, `tests/check_runtime_bundle.py` and
  `tests/test_settings.py`. Add a `CHANGELOG.md` entry, marked "Unreleased"
  until the live test passes.
- **Fixes:** add a regression test that fails on the old code, and confirm it
  does by temporarily restoring the old file. Destructive or currency-spending
  paths fail closed.
