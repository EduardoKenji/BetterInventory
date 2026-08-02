# BetterInventory

> Project status: Phase 0 technical spike implemented; static verification passed, in-game testing pending.
>
> Audit date: 2026-08-02

BetterInventory is intended to be a standalone, modern replacement for the abandoned Inventory2D mod. The goal is larger than putting several inventory cards on one row: BetterInventory should become a safe, responsive and highly configurable presentation and management layer for Darktide items across the Inventory, Hadron, the Armoury/Brunt and Sire Melk.

The initial release should remain a client-side UI and information mod. Read-only inventory analysis can follow. Any feature that buys, sells, discards or otherwise changes account state must remain behind a separate policy and safety gate.

## Current implementation

The first executable vertical slice now lives beside this document as a normal standalone DMF mod:

```text
BetterInventory/
|-- BetterInventory.mod
|-- scripts/mods/BetterInventory/
|   |-- BetterInventory.lua
|   |-- BetterInventory_layout.lua
|   |-- BetterInventory_data.lua
|   `-- BetterInventory_localization.lua
`-- tests/
    |-- test_layout.py
    `-- verify.ps1
```

It currently covers the character melee, ranged and Curio inventory and provides:

- A chain-safe `InventoryWeaponsView.present_grid_layout` hook that continues through the full DMF chain, plus a narrowly gated grid hook that transforms the final item blueprint.
- Two to five responsive columns calculated from the current grid width.
- Configurable card height, spacing and icon darkness.
- Independent melee, ranged and Curio enable switches.
- Current weapon pattern/mark, rarity, expertise, favorite and equipped state preservation.
- Adaptive single-line item names that shrink to a configurable minimum and use an ellipsis only when still too wide, preventing overlap with the pattern/Mark line.
- Compact favorite-marker and font-size options.
- Darktide's managed item-icon loader with a card-sized render context and the original unload/update lifecycle.
- Graceful fallback to the original presentation path when the view contract or item blueprint is unavailable.

This spike deliberately does not touch Hadron, vendors, sorting, filters or backend transactions yet. It has been statically checked against Darktide 1.12.3 source, but mouse/controller navigation, unusual resolutions, mod interaction and hot enable/disable still need an in-game pass.

For a manual development install, copy this entire `BetterInventory` directory into `Content/mods/BetterInventory`, add `BetterInventory` to `Content/mods/mod_load_order.txt`, and restart Darktide. Do not install it alongside the original Inventory2D or its compatibility patch during the first test pass because both target the same presentation method.

Run the local verification from this directory with:

```powershell
.\tests\verify.ps1 -DarktideSourcePath "$env:TEMP\codex-darktide-current-source-audit"
```

## Vision

BetterInventory should provide:

- Responsive multi-column inventory layouts.
- Modern item cards that preserve every important current-game field.
- Per-view, per-slot and per-element customization.
- Complete weapon pattern/mark, Curio, perk, blessing, rating and state information.
- Coverage beyond the character inventory, including Hadron and vendors.
- Compatibility with existing sorting, filtering, store and item-information mods.
- A future rules engine for read-only item evaluation and assisted inventory workflows.
- Transactional automation only if it is demonstrably permitted, safe and explicitly enabled.

The working product description is:

> A standalone, responsive inventory-card and item-management layer for Inventory, Hadron, the Armoury and Melk, with weapon marks, Curio details, modern ratings and per-view layouts.

## Project principles

1. Preserve information before increasing density.
2. Use current Darktide APIs and data semantics rather than displaying legacy backend fields without explanation.
3. Compose with other mods through chain-safe Darktide Mod Framework hooks.
4. Do not perform backend writes in the core layout module.
5. Treat favorites, locks, equipped items and user-defined keep rules as protected data.
6. Prefer readable presets with optional advanced customization over a wall of unexplained settings.
7. Feature-detect game UI fields and fail gracefully after game updates.
8. Keep destructive or currency-spending behavior separate, conspicuous and reversible where possible.

## Audit scope

### Local inputs

The following downloaded files were inspected:

- [Inventory2D 1.4 archive](../../Inventory2D_mod_research/Inventory2D-188-1-4-1687868107.zip)
- [Inventory2D Bound by Duty Fix 0.9 archive](../../Inventory2D_mod_research/Inventory2D_Bound_by_Duty_Fix-594-0-9-1758728428.7z)

The original archive contains:

- `Inventory2D.mod`
- `main.lua`
- `mod_data.lua`
- `settings_manager.lua`
- `loc.lua`
- `abbreviations.lua`
- `curio_detail_mode.lua`
- `ui_manager_hooks.lua`
- `utils.lua`
- `vendors.lua`
- `todo.txt`

The compatibility patch contains only one replacement file:

- `Inventory2D/main.lua`

The original source archives were not modified. They were extracted to a temporary diagnostic directory for comparison.

### Current game baseline

The installed Microsoft/Xbox package is version `1.12.6294.0`, recorded in [appxmanifest.xml](../../appxmanifest.xml). Its files are dated 2026-07-06, matching the Darktide 1.12.3 source snapshot used for the current-API comparison.

The source comparison used commit [`47379fd3`](https://github.com/Aussiemon/Darktide-Source-Code/tree/47379fd3cbb6d59c3e9001bab1693c307bf46e2b), documented as Darktide 1.12.3 from 2026-07-06.

### Community evidence

The audit also reviewed:

- Inventory2D's Nexus description, changelog, posts and unresolved bugs.
- The Bound by Duty compatibility patch description, changelog and posts.
- Current community requests for marks, vendor support, colors and independent rating toggles.
- Fatshark's modding policy and current EULA for the future automation discussion.

This is a static code and compatibility audit. Runtime testing in every UI view remains necessary once BetterInventory has an executable prototype.

## Executive findings

Inventory2D still demonstrates that a dense multi-column inventory is valuable, but it is not a maintainable foundation for a modern feature-complete mod without substantial reconstruction.

The most important conclusions are:

- The 2025 compatibility patch is not a maintained fork. It replaces only `main.lua` and makes two narrow API-name changes.
- Normal character inventory presentation can still work, which explains the positive 2026 user comments.
- Several advertised features are now partial, misleading or dead.
- Weapon pattern and mark text is intentionally hidden by the old layout code.
- Current item-level presentation is overwritten with a legacy raw field.
- The patch targets the wrong modern class for Hadron's item grid.
- Armoury/Brunt and Melk inventory cards are not supported.
- The original code does not account for modern favorite, rarity, price, owned/sold, required-level and warning fields.
- Direct method replacement and a private icon renderer create compatibility and lifecycle risks.
- The original's English string-matching approach cannot provide reliable localization.
- BetterInventory should be a standalone rewrite with credited inspiration, not a second patch layered over both existing downloads.

## Compatibility patch delta

The downloaded 0.9 patch changes only two functional areas relative to Inventory2D 1.4:

1. It changes the required crafting module from `crafting_modify_view` to `crafting_view`.
2. It changes the removed `ItemUtils.perk_description` call to `ItemUtils.trait_description` and adds a narrow function-existence check.

It does not add or repair:

- Weapon marks or pattern names.
- Melk or Armoury/Brunt coverage.
- Correct current Hadron subview coverage.
- Hadron sacrifice/barter coverage.
- Curio text colors or corrected terminology.
- Independent level/rating toggles.
- Favorite-label layout.
- Rarity-name layout.
- Localization.
- Modern icon-renderer lifecycle management.
- Compatibility with other mods that alter the same grid methods.

The so-called anti-crash check is not a general data-safety layer. It checks whether `trait_description` exists, but still assumes Curio trait/perk arrays and resolved master items are valid.

## Advertised Inventory2D feature audit

| Advertised behavior | Implementation found | Status on the 2026 baseline | BetterInventory requirement |
| --- | --- | --- | --- |
| Three items per row | Global `items_per_row`, range 2–5 | Mostly functional in the normal inventory | Responsive Auto/2–6 columns with per-view profiles |
| Primary weapon inventory | `InventoryWeaponsView.present_grid_layout` replacement | Likely functional | Preserve and modernize |
| Secondary weapon inventory | Same view, filtered by `slot_secondary` | Likely functional | Preserve and modernize |
| Curio inventory | Same view, matching `slot_attachment_*` | Partial | Robust Curio card and separate Curio-slot controls |
| Hadron inventory | Original old crafting view; patch changes it to `CraftingView` | Effectively not correct for the current view hierarchy | Hook actual Hadron item-grid and barter/sacrifice paths |
| Darken item images | One global grayscale multiplier | Functional but crude | Per-profile icon opacity/darkness and text-panel opacity |
| Curio blessing text | Displays `traits[1]` | Partial and weakly guarded | Support valid trait data safely; configurable full/compact presentation |
| Curio Detail Mode | First trait plus every perk | Partially restored by patch | Localized, colored, wrapped, configurable and vendor-capable |
| Primary/secondary/Curio toggles | Three category checkboxes | Functional | Retain, then expand by view and actual slot |
| Per-item-slot toggles | No separate Curio 1/2/3 settings exist | Not implemented as advertised | Add genuine Curio slot 1/2/3 and view-level controls |
| Equipped glow | Added texture overlay | Likely functional | Off/tick/glow/border modes with color and thickness |
| Base/modifiers rating | Displays raw `baseItemLevel` for non-Curios | Mechanically present but poorly explained | Expose meaningful, named metrics with tooltips |
| Total rating | Old code forces raw `item.itemLevel` | Cannot be disabled; may be obsolete/misleading | Independent toggle and current semantics |
| Font sizes | Six legacy element sizes | Partial | Per-element typography plus sensible presets |
| Trait icons | Toggles `trait_1`, `trait_2`, `trait_3` if found | Dead: those passes do not exist in the current compact card template | Add current blessing/perk representation deliberately |
| Grid spacing | One global X/Y value | Functional | Independent X/Y spacing, height and per-view profiles |
| Rarity tag | Present in settings though not highlighted in the feature list | Likely functional | Preserve tag and add rarity-name controls |

The final advertised "per-item-slot basis" bullet duplicates an earlier category-toggle claim. The version 1.3 changelog says "each curio slot," but `mod_data.lua` contains only one `enable_for_curios` checkbox.

## Confirmed modern regressions

### Weapon pattern and mark are hidden

Current Darktide builds `sub_display_name` from the localized weapon pattern and mark. Inventory2D explicitly sets the `sub_display_name` font size to zero, which directly explains reports that selected marks are missing.

References:

- [Current weapon card naming implementation](https://github.com/Aussiemon/Darktide-Source-Code/blob/47379fd3cbb6d59c3e9001bab1693c307bf46e2b/scripts/utilities/items.lua#L363-L375)
- [Current item blueprint populating display, sub-display and rarity names](https://github.com/Aussiemon/Darktide-Source-Code/blob/47379fd3cbb6d59c3e9001bab1693c307bf46e2b/scripts/ui/view_content_blueprints/item_blueprints.lua#L893-L923)
- [Patch user report about missing weapon marks](https://www.nexusmods.com/warhammer40kdarktide/mods/594?tab=posts)

BetterInventory should offer:

- Mark only.
- Pattern and mark.
- Full localized sub-name.
- Hidden.
- Independent font size, color, alignment and truncation behavior.

### Item-level semantics are outdated

The current base game calls `Items.expertise_level(item)` when filling the compact card. Inventory2D calls the original initializer and then overwrites the result with `tostring(item.itemLevel or 0)`.

This creates two problems:

- It discards the game's current expertise-level formatting and symbol.
- It exposes an old backend field without explaining whether it is expertise, total stats, base level or legacy aggregate rating.

BetterInventory should name metrics by meaning rather than by ambiguous old labels. Candidate fields include:

- Current game Expertise display.
- Total weapon-stat value.
- Backend base item level, under an Advanced label.
- Legacy aggregate item level only if still useful and available.

Users should be able to select primary and secondary badges independently instead of enabling several overlapping numbers accidentally.

### Hadron targets the wrong modern view

The patch changes its import to `CraftingView`, whose current superclass is `VendorInteractionViewBase`. It is a top-level/tabbed interaction view rather than the relevant item-grid view.

Current Hadron item selection is split across at least:

- `CraftingMechanicusModifyView`, derived from `ItemGridViewBase`.
- `CraftingMechanicusBarterItemsView`, derived from `BaseView` and managing custom item and pattern grids.

References:

- [Current `CraftingView`](https://github.com/Aussiemon/Darktide-Source-Code/blob/47379fd3cbb6d59c3e9001bab1693c307bf46e2b/scripts/ui/views/crafting_view/crafting_view.lua)
- [Current `CraftingMechanicusModifyView`](https://github.com/Aussiemon/Darktide-Source-Code/blob/47379fd3cbb6d59c3e9001bab1693c307bf46e2b/scripts/ui/views/crafting_mechanicus_modify_view/crafting_mechanicus_modify_view.lua)
- [Current `CraftingMechanicusBarterItemsView`](https://github.com/Aussiemon/Darktide-Source-Code/blob/47379fd3cbb6d59c3e9001bab1693c307bf46e2b/scripts/ui/views/crafting_mechanicus_barter_items_view/crafting_mechanicus_barter_items_view.lua)

### Modern card fields are not adapted

The current item-card pass template contains fields or states that did not exist, or did not have their current form, when Inventory2D was written:

| Current field/state | Inventory2D behavior |
| --- | --- |
| `display_name` | Resized, but based on a fixed card geometry |
| `sub_display_name` | Hidden; loses pattern and mark |
| `rarity_name` | Not deliberately repositioned or configured |
| `item_level` | Resized and overwritten with legacy raw data |
| `required_level` and background | Not adapted to narrow cards |
| `favorite_icon` | Current full text label is not repositioned; overlaps Curio text |
| `wallet_icon` and `price_text` | Not adapted for vendor cards |
| `owned_text` and sold state | Not adapted for vendor cards |
| salvage progress/icon | Uses old hard-coded offsets |
| multi-selection/deleted overlay | Not deliberately adapted |
| warning message/background | Not adapted |
| new-item indicator | Preserved incidentally rather than designed for the compact layout |

Reference: [current item pass templates](https://github.com/Aussiemon/Darktide-Source-Code/blob/47379fd3cbb6d59c3e9001bab1693c307bf46e2b/scripts/ui/pass_templates/item_pass_templates.lua).

### Trait-icon toggle is now a no-op

Inventory2D only changes the visibility of passes with style IDs `trait_1`, `trait_2` and `trait_3`. Those passes are absent from the current item blueprint and pass template. The setting remains visible but has no target to modify.

BetterInventory must create its own current blessing/perk presentation or use a supported current-game component rather than retaining this checkbox unchanged.

### Favorite text overlaps Curio details

The current card renders a favorite symbol and the localized Favorite label near the lower-left area. Inventory2D also places Curio blessing/perk details there. Users reported the overlap and asked for a compact icon.

BetterInventory should provide favorite modes:

- Compact icon.
- Icon plus text.
- Colored corner marker.
- Border tint.
- Hidden.

### Vendor coverage is absent

Inventory2D hooks only its inventory class and a crafting class. It does not hook current vendor views such as:

- `CreditsVendorView` and `CreditsGoodsVendorView` for the Armoury/Brunt paths.
- `MarksVendorView` and `MarksGoodsVendorView` for Melk paths.

The original `vendors.lua` is an unused stub with an empty replacement function. It is not loaded by `main.lua` and provides no vendor implementation.

### Localization is incomplete

The mod's own localization contains English only. Curio abbreviations are implemented by matching localized display strings against English Lua patterns, so non-English descriptions cannot be handled reliably.

Known community evidence includes unresolved Chinese-localization reports and the original author's changelog note that Curio abbreviations only work in English.

BetterInventory should:

- Use stable item/perk/trait identifiers for classification.
- Ask the game to localize final labels.
- Apply colors and compact forms by identifier rather than matching rendered English strings.
- Remain readable when no compact translation exists.
- Keep localization files separate and contributor-friendly.

## Architecture findings

| Finding | Consequence | BetterInventory direction |
| --- | --- | --- |
| Direct assignment to class methods | Bypasses normal DMF hook composition and creates load-order conflicts | Use `mod:hook`/`hook_require` and preserve the next function in the chain |
| Only two directly named view classes | New and split views silently lose support | Implement small per-view adapters around a shared card-layout engine |
| Hard-coded `base_item_size = {586, 110}` | Fragile across view geometry, UI scale and aspect ratios | Derive width from the active grid and selected profile |
| Hard-coded offsets for every card element | New fields overlap or clip | Centralize named anchors and collision-aware regions |
| Custom private `WeaponIconUI` | Duplicates the manager-owned renderer | Use `Managers.ui:load_item_icon` and its supported lifecycle where possible |
| Icon unload intentionally bypassed | Requests can remain retained | Restore unload and destroy semantics |
| Renderer reference set to `nil` after grid-setting changes without `destroy()` | Potential leaked renderer worlds/resources | Never abandon engine resources without explicit cleanup |
| `hook_safe` return used as if it could replace a return value | DMF safe hooks cannot change original return values | Choose the correct hook type and test return behavior |
| Original functions cached globally on first blueprint | Can ignore later mod changes or view-specific behavior | Transform each generated blueprint without global first-call state |
| Global `table.find_predicate` addition | Pollutes shared namespace and may collide | Keep helpers local to the mod |
| Trait/perk arrays and master-item lookups assumed valid | Game updates or unusual items can crash the view | Validate every optional field and log a bounded diagnostic once |
| Only some settings invalidate presentation | Live changes may require closing/reopening views | Explicitly rebuild active grids when presentation settings change |

The installed [DMF hook implementation](../../mods/dmf/scripts/mods/dmf/modules/core/hooks.lua) documents that `hook_safe` runs after the original and cannot change return values.

## Compatibility targets

BetterInventory should behave as a layout/card layer and preserve external sorting, filtering and store behavior.

Initial compatibility targets:

- Base Darktide sorting and filtering.
- Item Sorting.
- Stuff Searcher or its maintained successor.
- Quick Look Card.
- GlobalStore.
- Favorite and item-lock behavior.
- Other mods that add style passes to the item blueprint.

The local installation already contains GlobalStore. Its current implementation hooks Credits and Marks vendor `present_grid_layout` methods. BetterInventory must remain in the DMF hook chain rather than overwrite those methods.

Reference: [installed GlobalStore implementation](../../mods/GlobalStore/scripts/mods/GlobalStore/GlobalStore.lua).

Known historical conflicts listed on Inventory2D's bug tracker include ItemSorting, Stuff Searcher, Hadron crashes and sort-button crashes.

## Proposed view coverage

| View/context | Inventory2D 1.4 + patch | BetterInventory target |
| --- | --- | --- |
| Character melee inventory | Supported | MVP |
| Character ranged inventory | Supported | MVP |
| Character Curio inventory | Partially supported | MVP |
| Hadron modify/item selection | Wrong modern hook | MVP |
| Hadron sacrifice/barter | Unsupported custom grid | Phase 2 unless straightforward during MVP |
| Armoury/Brunt credits store | Unsupported | MVP or Phase 2 |
| Melk marks store | Unsupported | MVP or Phase 2 |
| Weapon mark chooser | Not a target | Preserve; optional specialized layout later |
| Weapon cosmetics | Not a target | Preserve; optional profile later |
| Mastery pattern grid | Not a target | Preserve; explicitly out of initial scope |

## Proposed feature set

### Layout profiles

- Auto-fit and fixed 2–6-column modes.
- Separate profiles for Inventory, Hadron, Armoury and Melk.
- Independent horizontal and vertical spacing.
- Card height, internal padding and icon crop controls.
- Compact, Balanced and Detailed presets.
- Resolution/UI-scale refresh.
- Mouse and controller navigation support.

### Card elements

Each supported element should have an Off/On mode and appropriate size, color and placement controls:

- Weapon family name.
- Weapon pattern and mark.
- Custom item name where applicable.
- Rarity name and rarity strip.
- Current expertise level.
- Total stats value.
- Advanced base/legacy rating fields.
- Perks and blessings as icons, text or both.
- Curio blessing and perk details.
- Favorite marker.
- Equipped marker.
- New-item marker.
- Required-level warning.
- Price and currency icon.
- Owned/sold state.
- Salvage or multi-selection state.
- View-specific warnings.

### Curio Detail Mode 2.0

- Correct and configurable wording, including Maximum Wound terminology.
- Color by stat category or user-selected colors.
- Full, compact and icon-first label modes.
- Configurable line spacing, wrapping and maximum lines.
- Independent blessing and perk font settings.
- Stable-ID-driven abbreviation and coloring.
- Graceful missing-data behavior.
- Inventory, Hadron and relevant vendor support.

### True per-slot and per-view control

- Melee inventory.
- Ranged inventory.
- Curio slot 1.
- Curio slot 2.
- Curio slot 3.
- Inventory view.
- Hadron view.
- Armoury/Brunt view.
- Melk view.

Settings should support inheritance: a global default, overridden only where the user chooses a custom view/slot profile.

## Roadmap

### Phase 0: technical spike

- Create the normal DMF mod skeleton.
- Chain-hook `InventoryWeaponsView` safely.
- Render two or three columns using current item blueprints.
- Preserve pattern/mark, favorite, equipped, rarity and current expertise data.
- Use managed icon loading/unloading.
- Demonstrate clean enable/disable behavior.
- Confirm mouse and controller selection behavior.

Exit criterion: the normal melee/ranged/Curio inventory works without losing current card information or conflicting with the base sort button.

### Phase 1: BetterInventory MVP

- Responsive Inventory layout profiles.
- Correct modern card field placement.
- Weapon pattern/mark controls.
- Favorite and equipped marker modes.
- Current rating selectors and independent visibility.
- Curio Detail Mode 2.0.
- Real per-slot controls.
- English localization structured for translation.
- Safe settings-driven grid refresh.
- Compatibility testing with GlobalStore and Item Sorting.

### Phase 2: complete item-view coverage

- Hadron modify view.
- Hadron sacrifice/barter view.
- Armoury/Brunt vendor views.
- Melk vendor views.
- Vendor prices, currency, owned/sold and warning layouts.
- Per-view presets and customization.

### Phase 3: inventory intelligence, read-only

- Saved criteria profiles for different builds.
- Attribute threshold evaluation.
- Dump-stat identification.
- Perk/blessing matching.
- Duplicate and upgrade-candidate detection.
- Highlighting, badges and comparison scores.
- Wishlist and store-candidate notifications.
- Dry-run reports such as "these items match" or "these items are probably safe to review for sale."

This phase should evaluate items without buying, selling, discarding or spending currency.

### Phase 4: assisted operations, policy gated

Potential examples:

- Select items matching explicit criteria.
- Prepare a sale queue for review.
- Present a candidate purchase with an explanation.
- Require confirmation before every account-changing transaction or bounded batch.
- Record a local audit log of requested and confirmed actions.

This phase must not begin until current policy, API behavior and failure modes have been re-evaluated.

#### Existing local precedent: Quick Level Mastery

The installed `quick_level_mastery` mod is the feature remembered during BetterInventory's initial implementation. It adds an explicit Sacrifice button to Brunt's Armoury and other storefronts. In the Brunt flow, one press checks mastery and affordability, purchases the selected active offer, queues the resulting item for an upgrade when required, groups it by `parent_pattern`, and submits the grouped gear IDs to `Managers.data_service.crafting:extract_weapon_mastery` when the view closes.

This is meaningful precedent for BetterInventory's Phase 4: a bounded workflow initiated by a visible user action can combine several ordinary inventory operations under the QoL umbrella. It is not the same risk class as an unattended reroll loop—the installed implementation acts on a selected offer, checks basic preconditions, and does not continuously purchase until arbitrary criteria match. BetterInventory should therefore distinguish:

- **Assisted operation:** the user selects or reviews a bounded action and triggers it explicitly.
- **Unattended automation:** the mod repeatedly spends currency or disposes of items while evaluating future results.

The former is a strong candidate for later implementation with better previews, limits and error handling. The latter remains outside the committed roadmap until policy and backend safety are clearer.

Local source references:

- [`quick_level_mastery` feature descriptions](../../mods/quick_level_mastery/scripts/quick_level_mastery_localization.lua)
- [Button gating, purchase and sacrifice queue](../../mods/quick_level_mastery/scripts/base_vendor_sacrifice.lua)
- [Upgrade and mastery-extraction transaction calls](../../mods/quick_level_mastery/scripts/quick_sacrifice.lua)

### Phase 5: unattended automation, not currently approved

The idea of repeatedly buying and selling until a desired attribute distribution appears is technically interesting, but it is not part of the committed roadmap.

It requires answers to all of the following:

- Does current Fatshark policy explicitly permit unattended store transactions?
- Does the current EULA's prohibition of bots and automated control make the feature unacceptable even if the older modding policy notes that mods can manage inventories?
- Could repeated requests affect backend service stability or trigger rate limits?
- Can every ambiguous network response be handled without duplicate spending or accidental sale?
- Can the user place a strict transaction count and currency stop-loss on a run?
- Can protected items be guaranteed safe despite other mods and delayed backend state?
- Will the Darktide modding community permit distribution of such a feature?

Until those questions have satisfactory answers, BetterInventory should offer a read-only evaluator and user-confirmed workflows instead of unattended transaction loops.

## Transaction safety requirements

If BetterInventory ever performs account-changing operations, the transaction subsystem must be isolated from the UI/layout core and meet at least these requirements:

- Disabled by default and clearly marked experimental.
- No premium-currency operations under any circumstance.
- Explicit per-run opt-in.
- Dry-run preview showing every proposed action and total cost/proceeds.
- Hard maximum transaction count.
- Hard currency budget and stop-loss.
- Never sell equipped, favorited or locked items.
- User-defined protected item IDs and criteria.
- Re-fetch server state before each write.
- No blind retry after timeout or ambiguous response.
- Rate limiting and immediate abort control.
- Local timestamped action/result log.
- Confirmation summary after completion or failure.
- Automatic shutdown after a game update until compatibility is revalidated.

These safeguards reduce risk; they do not make unsupported automation permissible.

## Modding-policy note

Fatshark's 2023 modding policy states that mods have the same authentication level as the regular game and are technically capable of selling or buying items, spending currencies and managing characters. It also says users assume the risk and Fatshark will not restore losses caused by mods.

The EULA, last updated 2024-11-25, broadly prohibits bots, automated control and automation programs interacting with the services. The relationship between that general language and ordinary community mods is not sufficiently clear to treat unattended transactional automation as approved.

References:

- [Fatshark Darktide Modding Policy](https://forums.fatsharkgames.com/t/darktide-modding-policy/75407/1)
- [Current Darktide EULA](https://www.playdarktide.com/docs/eula)

This document is a technical project note, not legal advice. Policy should be checked again immediately before designing or distributing any automated transaction feature.

## Permissions and clean implementation strategy

The original Inventory2D Nexus permissions allow modification, bug fixes, improvements, redistribution and asset use when Redbeardt is credited as the original creator. Commercial sale is not permitted, while Nexus Donation Points are allowed.

The Bound by Duty compatibility patch uses more restrictive permissions: its author requires permission for modification or asset reuse and prohibits re-uploading.

Recommended strategy:

1. Build BetterInventory as a standalone implementation against current game APIs.
2. Credit Redbeardt and Inventory2D as the inspiration and, if any original source is reused, comply with the original permission terms.
3. Do not copy the compatibility patch file.
4. Independently implement the factual API adaptations required by the current game.
5. Keep a `CREDITS.md` or equivalent attribution before public release.

References:

- [Inventory2D description and permissions](https://www.nexusmods.com/warhammer40kdarktide/mods/188)
- [Bound by Duty patch description and permissions](https://www.nexusmods.com/warhammer40kdarktide/mods/594)

## Community-request evidence

Requests and unresolved reports relevant to BetterInventory include:

- Missing selected weapon marks.
- Replace the full Favorite label with a compact icon.
- Favorite/Curio text overlap.
- Correct `+1 Wound` to clearer Maximum Wound wording.
- Customizable Curio stat colors.
- Show Curio detail tags at Melk and Hadron.
- Separate Item Level, Item Base Level and Item Total Level toggles.
- Hadron remaining one column after later crafting updates.
- Rarity-text problems.
- Localization failures.
- Sort-button crashes.
- Conflicts with ItemSorting and Stuff Searcher.

References:

- [Inventory2D posts](https://www.nexusmods.com/warhammer40kdarktide/mods/188?tab=posts)
- [Inventory2D unresolved bug list](https://www.nexusmods.com/warhammer40kdarktide/mods/188?tab=bugs)
- [Compatibility patch posts](https://www.nexusmods.com/warhammer40kdarktide/mods/594?tab=posts)

## Source index

### Inventory2D

- [Original Nexus page](https://www.nexusmods.com/warhammer40kdarktide/mods/188)
- [Original posts](https://www.nexusmods.com/warhammer40kdarktide/mods/188?tab=posts)
- [Original bug tracker](https://www.nexusmods.com/warhammer40kdarktide/mods/188?tab=bugs)
- [Bound by Duty compatibility patch](https://www.nexusmods.com/warhammer40kdarktide/mods/594)
- [Compatibility patch posts](https://www.nexusmods.com/warhammer40kdarktide/mods/594?tab=posts)

### Current Darktide UI source snapshot

- [Darktide 1.12.3 source snapshot](https://github.com/Aussiemon/Darktide-Source-Code/tree/47379fd3cbb6d59c3e9001bab1693c307bf46e2b)
- [Item blueprints](https://github.com/Aussiemon/Darktide-Source-Code/blob/47379fd3cbb6d59c3e9001bab1693c307bf46e2b/scripts/ui/view_content_blueprints/item_blueprints.lua)
- [Item pass templates](https://github.com/Aussiemon/Darktide-Source-Code/blob/47379fd3cbb6d59c3e9001bab1693c307bf46e2b/scripts/ui/pass_templates/item_pass_templates.lua)
- [Item utilities](https://github.com/Aussiemon/Darktide-Source-Code/blob/47379fd3cbb6d59c3e9001bab1693c307bf46e2b/scripts/utilities/items.lua)
- [Item grid base view](https://github.com/Aussiemon/Darktide-Source-Code/blob/47379fd3cbb6d59c3e9001bab1693c307bf46e2b/scripts/ui/views/item_grid_view_base/item_grid_view_base.lua)
- [Inventory weapons view](https://github.com/Aussiemon/Darktide-Source-Code/blob/47379fd3cbb6d59c3e9001bab1693c307bf46e2b/scripts/ui/views/inventory_weapons_view/inventory_weapons_view.lua)
- [Crafting top-level view](https://github.com/Aussiemon/Darktide-Source-Code/blob/47379fd3cbb6d59c3e9001bab1693c307bf46e2b/scripts/ui/views/crafting_view/crafting_view.lua)
- [Hadron modify view](https://github.com/Aussiemon/Darktide-Source-Code/blob/47379fd3cbb6d59c3e9001bab1693c307bf46e2b/scripts/ui/views/crafting_mechanicus_modify_view/crafting_mechanicus_modify_view.lua)
- [Hadron barter/sacrifice view](https://github.com/Aussiemon/Darktide-Source-Code/blob/47379fd3cbb6d59c3e9001bab1693c307bf46e2b/scripts/ui/views/crafting_mechanicus_barter_items_view/crafting_mechanicus_barter_items_view.lua)
- [UI manager icon lifecycle](https://github.com/Aussiemon/Darktide-Source-Code/blob/47379fd3cbb6d59c3e9001bab1693c307bf46e2b/scripts/managers/ui/ui_manager.lua)
- [Weapon icon renderer](https://github.com/Aussiemon/Darktide-Source-Code/blob/47379fd3cbb6d59c3e9001bab1693c307bf46e2b/scripts/ui/weapon_icon_ui.lua)

### Policy

- [Fatshark Darktide Modding Policy](https://forums.fatsharkgames.com/t/darktide-modding-policy/75407/1)
- [Current Darktide EULA](https://www.playdarktide.com/docs/eula)

## Immediate next validation

The narrow `InventoryWeaponsView` spike is implemented. The next step is an in-game smoke-test matrix covering melee, ranged and all three Curio slots at two, three and five columns; mouse and controller navigation; favorite/equip/discard interactions; unusual aspect ratios; hot enable/disable; and coexistence with the active sorting/information mods. Once that vertical slice is stable, the same card-layout engine can be adapted to Hadron and the vendor views.
