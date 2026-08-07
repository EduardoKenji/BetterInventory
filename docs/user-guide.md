# BetterInventory user guide

BetterInventory v2.0.0 improves inventory, Character Overview, Hadron, Requisition Weapons & Curios, and optional GlobalStore cards while preserving Darktide's native item and icon lifecycle.

## Install

Copy the `BetterInventory` directory into `Content/mods`, add `BetterInventory` to `Content/mods/mod_load_order.txt`, and restart Darktide. For a release archive, use the repository's `tools/package_release.ps1` script.

## Safety defaults

Normal card/layout features do not change inventory or wallet data. Experimental Quick Discard, automatic discard, and Automatic Curio Buyer are opt-in. Automatic writes re-fetch and revalidate state immediately before dispatch, protect favorites/loadouts, serialize destructive work, and fail closed when required profile data is unavailable.

## Validation

1. Run `tests/verify.ps1` for syntax, source contracts, behavior tests, schema drift, packaging, and archive parity.
2. Run `py -3 tests/run_tests.py --coverage-output lua-coverage.json` for timeout-bounded JSON results and Lua line coverage.
3. Validate in-game after changing one setting at a time, reopening affected views, switching operatives, and exercising disabled/cancelled flows.

The prioritized backlog and remaining release gates are maintained in [`v2.0.0-full-project-audit.md`](v2.0.0-full-project-audit.md).
