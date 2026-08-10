# BetterInventory user guide

BetterInventory v2.0.2 improves inventory, Character Overview, Hadron, Requisition Weapons & Curios, and optional GlobalStore cards while preserving Darktide's native item and icon lifecycle.

## Install

Copy the `BetterInventory` directory into `Content/mods`, add `BetterInventory` to `Content/mods/mod_load_order.txt`, and restart Darktide. For a release archive, use the repository's `tools/package_release.ps1` script.

## Safety defaults

Normal card/layout features do not change inventory or wallet data. Experimental Quick Discard, automatic discard, and Automatic Curio Buyer are opt-in. Automatic writes re-fetch and revalidate state immediately before dispatch, protect favorites/loadouts, serialize destructive work, and fail closed when required profile data is unavailable.

Weapon and Curio equips still use Darktide's native loadout request. BetterInventory preserves the shared local preview while navigating between equipment and Character Overview, observes the eventual request across rapid exits, retries only confirmed failures for the same account/character, and refreshes a reopened overview when Darktide publishes the authoritative profile.

Customization persistence follows DMF's actual contract: a normal no-return save is delegated to DMF and is not retried forever; thrown, unavailable, or explicitly rejected calls are bounded and observable. Manual discard remains serialized through native deletion settlement. Same-gear item revisions refresh detailed overview cards. The Debug section's hot-path diagnostics are opt-in and should be enabled only for a short baseline capture, then disabled for normal play.

## Validation

1. Run `tests/verify.ps1` for syntax, source contracts, behavior tests, schema drift, packaging, and archive parity.
2. Run `py -3 tests/run_tests.py --coverage-output lua-coverage.json` for timeout-bounded JSON results, 43 named risk cases, and risk-weighted Lua line coverage. The command fails if the case manifest is incomplete or a non-declarative runtime module falls below its threshold.
3. Validate in-game after changing one setting at a time, reopening affected views, switching operatives, and exercising disabled/cancelled flows.

The prioritized backlog and remaining release gates are maintained in [`v2.0.0-full-project-audit.md`](v2.0.0-full-project-audit.md).
