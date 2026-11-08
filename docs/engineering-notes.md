# BetterInventory engineering notes

Durable facts about Darktide, DMF and this codebase that were verified against
source. Read this before re-researching any of them. Each entry names where it
was confirmed, so it can be re-checked after a game or DMF update.

Last verified: v3.8.0, Darktide 1.13.4 (`Darktide-Source-Code` `e46b8926c`),
installed DMF as of 2026-10-22, 2026-11-05.

## Engine and framework behavior

### `class()` copies superclass methods at definition

`scripts/foundation/utilities/class.lua` copies every super field into the
subclass table when the subclass is defined (`for k, v in pairs(super)`).

- **Consequence:** a later `mod:hook(Base, "m")` changes only `Base.m`.
  Subclasses keep calling their copied, unhooked function.
- **Fix pattern:** `ensure_class_method(Subclass, "m")`, in
  `BetterInventory_runtime.lua` and `BetterInventory_search_hooks.lua`. It
  replaces the copy with a forwarder that looks up `super[m]` at call time.
- **Order:** install forwarders on the base view first (for example
  `VendorViewBase`), then on its children.
- **Load-order caveat:** if another mod hooks the subclass method before BI
  installs its forwarder, `ensure_class_method` sees an own method and does
  nothing. BI then drops out of that chain. In the user's setup BI loads before
  MaxStatMark, which hooks `InventoryWeaponsView`, `CreditsVendorView` and
  `MarksVendorView._present_layout_by_slot_filter`.
- **Overriding subclasses:** `InventoryWeaponsView._cb_on_present` and
  `CraftingMechanicusModifyView._cb_on_present` call `super`, so base hooks do
  reach them.

### DMF hooks

- **`mod:hook` errors are not caught**, so an error inside one can crash the
  game. **`hook_safe` handlers are pcall'd.** See
  `dmf/scripts/mods/dmf/modules/core/hooks.lua` (`safe_call_nr` is used for
  safe hooks only).
- **Inherited wrappers:** when DMF hooks a method whose inherited value is
  already a DMF wrapper, it swaps in the raw original and builds a separate
  chain on the subclass (`hooks.lua` around lines 347-356). That chain skips the
  base hooks, which is a second reason to use forwarders.
- **`mod:get` deep-clones table-valued settings** on every call
  (`modules/core/settings.lua`). Read a table setting once per scan, never per
  item. Example: `custom_item_name_and_colors` in `BetterInventory_discard_policy.lua`.
- **Defaults:** DMF fills in data defaults, but code fallbacks still run when a
  value is nil. That happens on first load and in the Python test harnesses,
  which leave settings unset.
  - Keep every `mod:get(x) or FALLBACK` and `setting(id, FALLBACK)` equal to
    its `BetterInventory_data.lua` default. v3.8.0 fixed 9 that had drifted.
  - Tests that depend on "off" behaviour must set the setting explicitly.
  - A bare `mod:get("id")` of a string setting (no `or`/comparison) is drift too;
    `tests/test_default_drift_guard.py` flags it (migrations are allowlisted).
- **Localization shards:** a new shard must be added in `BetterInventory_localization.lua`
  and in the hardcoded lists in `tests/localization_support.py`,
  `tests/check_schema_drift.py` and `tools/schema_manifest.py`, plus
  `tests/coverage_policy.json` `declarative_modules`, `docs/runtime-module-ownership.json`
  and `tests/branch_matrix.json`. Missing a loader shows up as "zh-CN missing" asserts.

### ViewElementGrid

`select_grid_index`, `select_first_index` and `selected_grid_index` index
`self._grid` with no nil check (`view_element_grid.lua`). Before the grid is
presented, `_grid` is nil and the call crashes. Guard every call site with
`element._grid`.

### Inventory background view (loadout) save path

- **Batching:** native `InventoryBackgroundView._equip_local_changes` sends
  every changed slot in `_preview_profile_equipped_items` in one backend batch.
  One unequippable item, such as a fake gear id, fails the whole batch.
- **Snapshot, not live profile:** `_presentation_profile` is
  `table.clone_instance(profile)`, and `_preview_profile_equipped_items` is that
  clone's `.loadout`.
- **1.13.x changes:**
  - `on_exit` now sets `_preview_player = nil`.
  - `_handle_back_pressed(force_close)` no longer calls `_switch_active_view(nil)`.
  - `event_switch_mark` became a promise chain that strips weapon skins
    incompatible with the new mark and re-attaches trinkets. The Auto Crafter
    switches marks through `Managers.data_service.mastery:switch_mark` directly,
    so it doesn't get that cleanup. This is fine for its fresh Brunt weapons.
- **Preview markers:**
  - Native store previews carry `__is_preview_item = true`.
  - Character Cosmetics View Improved (CCVI, checked through 4.7.09) builds
    unowned preview cosmetics with `__locked = true` and a fake `math.uuid()`
    gear id.
  - Owned items never carry either marker; native `__locked` exists only on
    `table.make_locked` tables.
  - `EquipmentPersistence` restores the owned starting item for those slots
    before native equip runs.

### Favorites

`Items.set_item_id_as_favorite` writes only the **active** character's save,
with a sound plus `queue_save`. Gear is per character. For another character,
write `Managers.save:character_data(id).favorite_items` and call `queue_save`,
as `favorite_purchase_items(..., target_character_id)` does.

### Weapon marks have different stats

Brunt sells a weapon family; a purchase can return any mark of it. These
families have marks with different displayed stats (1.13.4 templates):

| Family | Difference |
| --- | --- |
| combatsword_p3 (Duelling Sword) | m3 (Mk V) Defence vs Cleave Damage on m1/m2 |
| combataxe_p1 | m2 Cleave Targets vs Finesse |
| autogun_p2 | m3 Power vs Control |
| ogryn_heavystubber_p2 | m1 Power vs Crit |
| ogryn_pickaxe_2h_p1 | all three marks differ |
| ogryn_powermaul_p1 | m2 Cleave Damage vs Power Output |
| ogryn_thumper_p1 | m2 shares only Mobility |

Stats are matched across marks by `display_name_key` (`candidate_policy.lua`
`candidate_stat`). A sibling mark without the dump stat is a miss. The selected
mark itself missing it means stat resolution is broken, so the run fails fast.

### Games Lantern and Cloudflare

- Cloudflare returns 403 to curl's default User-Agent. BI sends
  `BetterInventory-Darktide-Mod (+nexus URL)` from `transport_win.lua` and
  `transport_wine.lua`.
- Cloudflare often judges the TLS fingerprint rather than the UA, so an honest
  UA may still be challenged. If it is, the reliable fix is asking the site to
  allowlist the client. Do not impersonate a browser: that is fragile, and a
  live probe of it was refused as bot-check circumvention.
- **Quoting rules for the UA string:**
  - Windows `.bat`: no `%` and no `"`.
  - bash: no `'`.

## Codebase rules that bite

- **Size limit:** each runtime module must be 100,000 bytes or less
  (`tests/check_architecture.py`). `auto_crafter/core/controller.lua`
  and `BetterInventory_features.lua` sit near the limit. Move pure helpers out
  (for example `MasteryPolicy.diagnostic_message`) rather than raising it.
- **Test case manifest:** `tests/case_manifest.json` maps line ranges in each
  test to named cases. Inserting test lines needs
  `python tools/remap_manifest.py . <test.py> [...]`.
- **Generated manifests:** regenerate them after edits.
  - Runtime edits: `tools/generate_runtime_bundle_manifest.py`.
  - Setting or localization edits: `tools/generate_schema_manifest.py`.
  - Run both without `python -I`, because they import sibling modules.
- **`verify.ps1`:**
  - It checks release-zip parity, so run `tools/package_release.ps1 -OutputPath BetterInventory.zip` first.
  - It contains source-text contracts (log messages, hook shapes). Update them
    on purpose when a contract changes.
- **Structure checks:** `tests/check_lua_structure.py` rejects undeclared bare
  globals and ALL_CAPS constants read without a declaration in the same file.
  The second rule was added after an undefined constant from another module
  aborted the Curio scan.
- **Dead code:** `python tools/dead_locals.py scripts/mods/BetterInventory`
  uses the Lua AST. The test harness can't reach locals, so a local referenced
  only at its declaration is dead.
- **Holey tables:** `#t` is undefined when `t` has nil holes. Iterate a fixed
  count when entries may be nil.

## Install and release workflow

- **Folders:**
  - Development: `Content/mod_creations/BetterInventory` (remote `EduardoKenji/BetterInventory`).
  - Deployed copy: `Content/mods/BetterInventory`, managed by Vortex.
    `tools/sync_installed_mod.ps1` copies runtime files there and hash-checks
    them. Vortex then reports external changes; keep them when asked.
- **Release:** `tools/package_release.ps1 -OutputPath BetterInventory-<ver>.zip`.
- **Branches:** one branch per release (`v3.x.y`), fast-forwarded into `main`.
  The remote has only `main`.
- **Tests:** `PYTHONPATH=tests python tests/run_tests.py --timeout-seconds 600`,
  then `tests/verify.ps1 -DarktideSourcePath ../../Darktide-Source-Code`.
  Optionally add `-DmfSourcePath ../../mods/dmf`.

## Auditing a new Darktide version

1. `git -C ../../Darktide-Source-Code pull --ff-only`, then
   `git diff --name-only <old> <new>`. The previous baseline is recorded in the
   latest `docs/v*-audit.md`.
2. Intersect the changed files with BI's surface:
   - `require` paths;
   - `mod:hook*` targets, including class-name strings and
     `ensure_class_method` targets;
   - game basenames referenced in runtime Lua.
3. Check that every `Items.*` and `Text.*` function BI calls still exists with a
   compatible signature. A grep of `Items\.([a-z_]+)` against `items.lua` is enough.
4. Record the result in a new `docs/v<ver>-...-audit.md` and update this file
   if any fact above changes.

## Mod compatibility map (user's 57 enabled mods, 2026-11-05)

- **BI integrations, still compatible:** wkc, GlobalStore, MyFavorites,
  ItemSorting, god_stat_checker, red_weapons_at_home, GodRolls,
  EquippedIconPlus, hub_hotkey_menus, psych_ward, InstantCharacterChange,
  true_level, NumericUI, Enhanced_descriptions, PerformanceAllInOne,
  InspectFromPartyFinder/Social, Alfs_DMF_Extensions.
  - wkc symbols BI relies on: `_layout_gen`, `_overlay_kills_for_item`,
    `_overlay_per_instance_for_item`, `_overlay_icon_material(cfg, per_instance)`
    (returns material and scale), `_card_offsets`, `_abbrev_num`, `_layout_geom().card`.
- **Shared hook points that chain correctly:**
  - `ViewElementGrid._create_entry_widget_from_config`: BI, wkc, MyFavorites, GSC.
  - `ViewElementGrid.present_grid_layout`: BI, GSC.
  - `InventoryView.update`: BI, wkc, GSC.
  - `CreditsVendorView` and `MarksVendorView.present_grid_layout`: BI, GlobalStore.
- **MaxStatMark:** subclass hooks on `_present_layout_by_slot_filter` are
  handled by BI's forwarders, as long as BI loads first.
- **Cosmetic only:** Alf's RGB widget merges BI's `*_r/_g/_b` sliders into one
  widget, which doesn't show BI's disabled state.
- **Everything else:** gameplay or HUD only, no overlap.

## Open, deferred findings

See "Deferred, with rationale" in `docs/v3.8.0-darktide-1.13.4-audit.md`.
Re-verify those before building on them.
