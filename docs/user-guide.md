# BetterInventory user guide

BetterInventory v2.1.6 improves inventory, Character Overview, Hadron, Requisition Weapons & Curios, and optional GlobalStore cards while preserving Darktide's native item and icon lifecycle.

## Install

Copy the `BetterInventory` directory into `Content/mods`, add `BetterInventory` to `Content/mods/mod_load_order.txt`, and restart Darktide. For a release archive, use the repository's `tools/package_release.ps1` script.

## Safety defaults

Normal card/layout features do not change inventory or wallet data. Experimental Quick Discard, automatic discard, and Automatic Curio Buyer are opt-in. Automatic writes re-fetch and revalidate state immediately before dispatch, protect favorites/loadouts, serialize destructive work, and fail closed when required profile data is unavailable.

Weapon and Curio equips still use Darktide's native loadout request. BetterInventory preserves the shared local preview while navigating between equipment and Character Overview, observes the eventual request across rapid exits, retries only confirmed failures for the same account/character, and refreshes a reopened overview when Darktide publishes the authoritative profile.

Customization persistence follows DMF's actual contract: a normal no-return save is delegated to DMF and is not retried forever; thrown, unavailable, or explicitly rejected calls are bounded and observable. Manual discard remains serialized through native deletion settlement. Same-gear item revisions refresh detailed overview cards. The Debug section's hot-path diagnostics are opt-in and should be enabled only for a short baseline capture, then disabled for normal play.

## Auto Crafter custom stats

Enable **Custom stats** in Brunt's Auto Crafter Planner to replace the single dump-stat target with an exact five-stat allocation. The contextual grid follows the selected weapon's native stat catalogue, shows two cells per row plus a total cell, and adjusts each value by one within 60-80. Lower one value before raising another when the total is already 380.

Crafting requires an exact total of 380. A lower or otherwise invalid total is highlighted and the Craft action emits a notification without acquiring account-operation ownership or sending a purchase. A valid allocation is frozen for the run and revalidated against projected level-500 stats during Brunt acquisition, family-equivalent inventory resume across marks, post-mastery reconciliation, and final completion.

Enable **Use closest fallback candidate weapon if exact stat match weapon is not found** to retain the valid roll with the smallest sum of absolute differences across all five requested values. For example, `80/73/77/80/70` has distance 4 from `80/75/75/80/70`, while `80/70/80/80/70` has distance 10. Incomplete stat profiles cannot win, and equal-distance rolls retain the earlier purchase.

Games Lantern imports preserve all five website stat values when they form a uniquely mapped 380-point profile. Click either staged queue card to inspect and edit that weapon's exact stats, perks, and blessings; Brunt follows the matching melee or ranged weapon while only the selected job's session-local target changes. It never reorders the fixed melee-then-ranged execution cursor. Clear Queue restores the Brunt weapon selected before the first import when that offer remains available. Queue editing locks as soon as crafting starts, and malformed or sub-380 jobs remain staged with a visible blocked notification and zero account mutation.

## Validation

1. Run `tests/verify.ps1` for syntax, source contracts, behavior tests, schema drift, packaging, and archive parity.
2. Run `py -3 tests/run_tests.py --coverage-output lua-coverage.json` for timeout-bounded JSON results, 135 named risk cases, and risk-weighted Lua line coverage. The command fails if the case manifest is incomplete or a non-declarative runtime module falls below its threshold.
3. Validate in-game after changing one setting at a time, reopening affected views, switching operatives, and exercising disabled/cancelled flows.

The prioritized backlog and remaining release gates are maintained in [`v2.0.0-full-project-audit.md`](v2.0.0-full-project-audit.md).
