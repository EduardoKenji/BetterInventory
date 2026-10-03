# BetterInventory

[![BetterInventory verification](https://github.com/EduardoKenji/BetterInventory/actions/workflows/verify.yml/badge.svg)](https://github.com/EduardoKenji/BetterInventory/actions/workflows/verify.yml)

A standalone inventory and item-management mod for Warhammer 40,000: Darktide.
Responsive weapon and Curio cards, text search, sorting and vendor layouts make
large inventories easier to use, with optional purchasing and crafting tools.

[Download on Nexus Mods](https://www.nexusmods.com/warhammer40kdarktide/mods/1144)
· [User guide](docs/user-guide.md) · [Changelog](CHANGELOG.md)

> Development version: **v3.7.4**. The changelog marks this version unreleased;
> live-game acceptance for the recent automation and audit fixes remains pending.
> See the [release audit](docs/v3.7.3-release-audit.md) and
> [Darktide 1.13 compatibility/performance audit](docs/v3.7.2-compatibility-performance-audit.md).

## Features

- Native single-column cards or configurable two-to-five-column grids, with
  independent Inventory, Character Overview and supported vendor settings.
- Weapon marks, perks, blessings, maximum-potential stats, power and equipped/
  favorite indicators; detailed, primary-stat or title-only Curio profiles.
- Built-in item names and colours, configurable legendary classification,
  localized rarity/stars, and equipped/new-item highlights.
- Sorting with equipped/favorite priorities, perfect-roll recognition
  (`62 > 61 > 60`) and individually selectable sorting choices.
- Equipment Text Search with quoted phrases, AND queries, typed fields,
  match-first ranking and dim-or-hide behavior for unmatched cards.
- Optional Quick Discard, Automatic Discard, Automatic Curio Buyer and
  Auto Crafter Helper, including Games Lantern build import.

## Installation and first use

Requires Darktide Mod Loader and Darktide Mod Framework.

1. Extract the release archive into `Content/mods/`.
2. Confirm the descriptor is at `Content/mods/BetterInventory/BetterInventory.mod`.
   There should be exactly one outer `BetterInventory` folder.
3. Add `BetterInventory` on its own line in `Content/mods/mod_load_order.txt`.
4. Restart Darktide and configure **Options > Mod Options > Better Inventory**.
   Reopen affected views after changing structural layout settings.

To shorten the sorting list, open **Inventory Sorting > Visible sorting choices**
and uncheck unwanted choices. Every choice is on by default; no separate master
switch is needed. Reopen the view to update its active sort. If all available
choices are unchecked, Name A-Z (or the first available choice) remains usable;
unknown third-party choices remain visible.

## Supported views

| View | Behavior |
| --- | --- |
| Character Inventory | Single-column or responsive two-to-five-column weapon/Curio cards |
| Character Overview | Detailed melee, ranged and Curio cards with independent controls |
| Hadron: Entreat | Mirrored Inventory cards, capped at three columns |
| Requisition Weapons & Curios | Responsive cards, expanded window, prices and sorting |
| Sire Melk: Limited Time Acquisitions | Configurable responsive weapon/Curio grids and text search |
| GlobalStore: Armoury and Melk Multi-Operative Supply | Optional responsive cards, operative details and sorting |
| Brunt's Armoury | Auto Crafter planner, queue and progress HUD; native store-card layout |

Hadron's Sacrifice Weapons selectors, Melk's Mystery Acquisitions and unrelated
custom vendor services retain their native card layouts. Weapon inventories with
compound-shield previews use three columns to avoid the known denser-grid stall.

## Automation and defaults

Card display, sorting and search do not spend currency or discard items.

- **Quick Discard and Automatic Discard default to Off.** Discard management
  initially uses Manual mode with confirmation. Favorites, equipped items,
  saved loadouts and configured protection rules are checked before discarding.
- **Automatic Curio Buyer defaults to Off.** When enabled, its **Consecrate
  bought Curios to Transcendent** option defaults to **On** and spends crafting
  materials. It upgrades confirmed purchases one at a time, pauses for missing
  materials and resumes recorded work in supported hub/operative-selection
  contexts. See [consecration and interruption handling](docs/v3.7.1-curio-consecration.md).
- Vendor automatic-favorite options default to Off. GlobalStore follows the
  corresponding vendor's option; Auto Crafter has its own favorite setting.
- **Auto Crafter starts only after you start a validated plan.** At Brunt's
  Armoury it can acquire a target weapon, level mastery, set perks/blessings and
  select a final mark. Exact five-stat targets must total 380, with each stat
  between 60 and 80. See [acquisition modes, caps and fallback rules](docs/user-guide.md#auto-crafter-custom-stats).

Workflows share an account-operation guard and revalidate authoritative state
before writes. Ambiguous mutations stop or remain blocked for reconciliation.
Check the configured purchase and crafting options before starting automation.

## Optional integrations

These integrations activate when their corresponding mod is present and enabled.

| Mod | Integration |
| --- | --- |
| Weapon Kill Counter (`wkc`) | Kill totals on supported cards; WKC retains statistics ownership |
| Quick Look Card / Enhanced Descriptions | Avoid overlapping modifier passes; fit compact rich text |
| GlobalStore | Armoury and Melk Multi-Operative Supply cards and sorting |
| ItemSorting | Custom comparators alongside native sorting choices |
| MyFavorites | Colour groups, favorite markers and optional crafted-item colour assignment |
| Name It | Item-name import and synchronization |
| God Stat Checker / Red Weapons at Home | Background-owner choice / one-time custom-tier settings import |
| Lantern of the Omnissiah | Recommendations in the options panel |
| Quick Level Mastery | Shared mutation guard and Acquire/Sacrifice layout compatibility |
| Hub Hotkey Menus | Auto Crafter in its live Psykanium Brunt view |
| Visible Equipment | Cosmetics placement widgets alongside Loadout cards |
| Inspect from Social / Party Finder | Detailed cards when inspecting players |
| Equipped Icon Plus | Inactive-loadout badges separate from favorites |
| Alf's DMF Extensions | Generalized Mod Options layout |

Do not run alongside Inventory2D or its Bound by Duty compatibility patch;
they modify overlapping inventory presentation paths.

## Development

From the repository root, with Python, `lupa` and `luaparser` installed:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\verify.ps1
```

For behavior results with risk-weighted Lua coverage:

```powershell
py -3 .\tests\run_tests.py --timeout-seconds 45 --coverage-output lua-coverage.json
```

Build release archives through the verified packager:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\package_release.ps1 -OutputPath .\BetterInventory.zip
```

Follow [release packaging](docs/release-packaging.md) for archive and installed
runtime verification. See [architecture and ownership](docs/architecture.md)
and [Auto Crafter architecture](docs/auto-crafter-architecture.md) before changing
runtime boundaries. Historical audits describe their dated snapshots; current
changes belong in the [changelog](CHANGELOG.md).

## Credits

Inspired by [Inventory2D](https://www.nexusmods.com/warhammer40kdarktide/mods/188),
created by Redbeardt, with permission to modify and improve with attribution.
BetterInventory's implementation and additional features were developed
independently; it includes no files from the Bound by Duty compatibility patch
or third-party assets. Thanks to **lershu** for the Simplified Chinese translation.
