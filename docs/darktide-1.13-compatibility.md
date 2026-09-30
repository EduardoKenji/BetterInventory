# Darktide 1.13.0 compatibility review

Reviewed 2026-09-30 on `fix/darktide-1.13-blessing-layout`.

Follow-up: [v3.7.2 full compatibility and performance audit](v3.7.2-compatibility-performance-audit.md), including the version bump, LuaJIT validation and queue allocation fix. The verification counts below record the initial blessing-fix pass.

## Repository state

- Canonical working repository: `Content/mod_creations/BetterInventory`.
- At entry, `v3.7.1` and local `main` both pointed to `c2cd679`.
- After fetching, local `main` was 21 commits ahead of `origin/main`, with none behind. No local branch had commits outside local `main`. GitHub advertises only `main`, at `11470b0` (2026-08-30); the committed local version is 3.7.0, with 3.7.1 still in the working tree.
- The working tree already contained uncommitted v3.7.1 changes, including Curio consecration. These were preserved on the new branch, without committing or publishing them.
- Installed `Content/mods/BetterInventory` reports 3.6.0 and was left unchanged.

## Reference and compatibility findings

The source repository was clean and equal to `origin/master` after fetching:
`419fe18d4` (1.13.0 scripts, 2026-09-29). Installed game metadata reports
`1.13.6762.0`. Changes were compared with the preceding 1.12.5 source, `0f0cb4599`.

All 39 directly required game modules exist. All 54 statically named native hook
targets resolve, including inherited methods. Dynamic/external hook targets were
checked through the existing integration verification and behavior suite.

The changed inventory selection/preview code, vendor/store handling, equipment
save promises, mastery reward presentation, and UI widget lifecycle do not require
an additional BetterInventory API migration in the paths reviewed. The existing
checks also validate card-content APIs, grid geometry, gear cache/deletion,
mark unlocks, Curio trait mappings, and profile-spawner lifecycle against 1.13.0.
The removed preview labels and mannequin helper are not required by these paths.
The new Ogryn hammer uses the existing data-driven weapon/trait presentation.

## Blessing overlap

The supplied image appears to show two separate blessings, **Execution** and
**Unstoppable Force**, on a Cruncher Mk IIa. Its exact screen and settings were
not provided. This is a general layout defect, not a hammer-specific lookup error.

The shared fitter permits wrapping when auto-fit is disabled or reaches its
minimum font size. Blessing passes are bottom aligned and have fixed row heights;
a wrapped second name can extend upward into the first. The renderer's font
options do not honor `style.word_wrap` as a no-wrap guarantee.

The fix measures wrapped height using Darktide's text helper. Text that exceeds
its row falls back to the existing measured ellipsis and non-breaking-space
helper. Names that fit, including two-line text that fits its row, retain their
configured behavior. Full names remain in the card's full-text content fields.
The shared init and item-rebind paths both use this fix; no per-frame work is added.

## Verification

- Baseline: 58 behavior scripts / 200 named cases, with coverage gates passing.
- Regression: screenshot names across native, grid, vendor and overview cards;
  auto-fit on/off; long text at minimum font size; short-name rebind; existing
  shrink, ellipsis and fitting two-line cases. The updated layout test fails with
  the pre-fix Lua and passes with the fix.
- The full verifier initially hit a pre-existing stale popup-ownership check.
  It now reads the field from its current owner, the operation arbiter.
- Final behavior/coverage run: **58/58 scripts, 201/201 cases**, no coverage or
  branch-matrix gate failures. Local JSON evidence is in
  `test-results/darktide-1.13-tests.json` and `test-results/darktide-1.13-coverage.json`.
- Full `tests/verify.ps1 -DarktideSourcePath ../../Darktide-Source-Code` passed:
  architecture, recursive Lua parsing, schema/bundle manifests, game-source
  contracts, installed current/legacy DMF and Alf's extensions, GlobalStore,
  behavior tests, package contents, failure cleanup and local archive parity.
- `BetterInventory.zip` was rebuilt from this entire development working tree,
  including the pre-existing v3.7.1 work. Its previous copy was backed up to the
  system temporary directory. The archive was not installed or published.
- `git diff --check` passed. Changes remain uncommitted on the new branch.

Live-game visual acceptance is still required at the affected UI scale and
settings. The Lua harness uses simulated font metrics, not the game's renderer.
The pre-existing v3.7.1 Curio-consecration live acceptance also remains pending.
