# BetterInventory

[![BetterInventory verification](https://github.com/EduardoKenji/BetterInventory/actions/workflows/verify.yml/badge.svg)](https://github.com/EduardoKenji/BetterInventory/actions/workflows/verify.yml)

> Current release: **v2.9.4** (2026-08-22). No account-changing workflow runs automatically from the default configuration; destructive, purchasing, and automatic-favorite features require explicit user action or opt-in.

BetterInventory is a standalone inventory and item-management mod for Warhammer 40,000: Darktide. It adds responsive weapon and Curio cards, richer item information, configurable sorting, supported vendor layouts, optional mod integrations, and safety-gated inventory workflows.

## Highlights

- Responsive melee, ranged, and Curio layouts with native single-column cards or independently configurable two-to-five-column grids.
- Detailed weapon cards with marks, perks, blessings, maximum-potential attributes, item power, favorite/equipped state, and configurable image and text geometry.
- Detailed Curio cards with the innate stat and up to three perks, compact text modes, type-aware colours, item power, and Character Overview support.
- Separate layouts for Inventory, Character Overview, Hadron's Entreat view, Requisition Weapons & Curios, and GlobalStore's Multi-Operative Supply.
- Configurable equipped-item and newly-acquired-item highlights using native Darktide materials.
- Built-in item names and colours, with optional Name It synchronization.
- A standalone configurable legendary tier for visually identifying exceptional Transcendent weapons and Curios, with no Red Weapons At Home dependency.
- Sorting that preserves equipped and favorite priorities and recognizes fifth attributes of 60, 61, and 62 as perfect rolls, ordered `62 > 61 > 60`.
- A bounded inventory-options panel for sorting, discard rules, integrations, and view-specific controls.
- Optional Quick Discard, Automatic Discard, Automatic Curio Buyer, and Auto Crafter workflows with explicit ownership, authoritative revalidation, and fail-closed behavior.

## What's new in v2.9.4

- Older DMF releases no longer reject BetterInventory's complete Mod Options schema when they encounter the newer native `color` widget type.
- Current DMF retains the live custom-tier colour picker. Legacy DMF omits only that optional preview while preserving the colour preset, RGB sliders, custom-tier rules, and stored colour.
- Modern and legacy option-schema paths are covered by regression tests; the framework capability check runs once during options construction and adds no frame-time work.

## What changed in v2.9.3

- Automatic Curio Buyer now defaults Stamina's minimum primary roll to +3, so enabling Stamina no longer accepts +1 or +2 Curios unless the threshold is deliberately lowered.
- A default-on target of three owned Curios per operative and primary-stat type turns repeat buying into a bounded upgrade path. Once three qualifying Curios are owned, only a candidate whose Power is strictly higher than the lowest of the current best three is eligible; `0` disables this gate.
- The ownership check reuses Darktide's authoritative all-profile gear snapshot, retains only three Power numbers per operative/stat for the current pass, and updates that bounded set only after a confirmed purchase.
- The complete v2.9.0-v2.9.3 performance pass removes repeated per-card framework checks and temporary modifier arrays from custom-tier classification, snapshots Curio eligibility settings once per scan, and reuses unchanged Mod Options dependency-reason storage. No unbounded collection, retained closed view, or new idle-frame work was found.
- Every English localization entry has a non-empty Simplified Chinese value; the only intentionally identical values are language-neutral keybind labels. New custom-tier Stamina wording now consistently uses `体力` across the Chinese UI.

### v2.9.2 changes included

- **Custom legendary tier** defaults to the Red Weapons At Home reference behavior: RGB `210/30/40`, Power-500 Transcendent weapons, and Transcendent Curios with maximum primary rolls. Its live colour preview can also edit the RGB value directly and stays synchronized with presets and sliders.
- Melee and ranged weapons have independent minimum Power, base-stat total, every-modifier floor, required-high-stat count, and high-stat threshold controls. Health, Toughness, Stamina, and Wound Curios each have independent roll and Power filters.
- BetterInventory owns the classification when Red Weapons At Home is installed simultaneously. Turning BetterInventory's feature Off restores the other mod's behavior instead of stacking both rule sets.

### v2.9.1 changes included

- Reused Inventory and Character Overview cards now repair numeric or malformed dynamic material references before Darktide renders them, covering the reported `material '128'` weapon-switch crash signature.
- The guard is limited to BetterInventory-transformed cards and native cards in `InventoryWeaponsView`; it does not hook the global renderer or scan widgets every frame.
- Malformed blessing and Auto Crafter trait texture metadata is rejected at ingestion while valid native render-target atlas data and third-party material paths remain untouched.

### v2.9.0 changes included

- Better Inventory's name in Mod Options now uses an always-on bright green `#AEEF69` to aqua-blue `#62EFD8` gradient for every user, implemented with DMF's native rich-text colors and no dependency on Alf's DMF Extensions.

### v2.8.6 changes included

- Automatic Curio Buyer's Operative Selection scan, once-per-store-rotation throttle, and idle store-refresh rescan now default to On. The master Automatic Curio Buyer toggle remains Off, so this does not enable purchasing by default.
- Simplified Chinese now translates the 46 generated weapon and Curio image-layout controls that previously appeared in English; automated coverage permits only language-neutral keybind labels to remain identical to English.

### v2.8.5 changes included

- Auto Crafter now preserves a valid user-selected dump stat when the weapon Mark changes instead of silently resetting it to Damage.
- Mark selection now appears before Dump stat, and a Mark only changes the saved stat when that stat is unavailable for the selected Mark.

### v2.8.4 changes included

- Character Overview now offers three long blessing-name modes for mirrored weapons: two-line wrapping, font-size reduction to one line, or the default one-line cropping with `...`.
- The setting updates an already-open Character Overview and does not change blessing-name behavior in inventory, Hadron, Armoury, or GlobalStore cards.

### v2.8.3 changes included

- Weapon equip and favorite callbacks now defer priority re-sorting until Darktide completes the current inventory update, avoiding mutation of the item-grid widget array during native traversal.
- Repeated same-frame sort requests coalesce into one refresh, and a broken third-party sort hook is contained to the current view.
- Loadout persistence now rejects stale cross-character views and late callbacks after an InstantCharacterChange-style swap.
- Automatic Discard and Automatic Curio Buyer remain Morningstar-only; Auto Crafter remains restricted to its validated Brunt context and cannot be triggered by mission-lobby or Psykanium weapon switching.

### v2.8.2 changes included

- Simplified Chinese localization now incorporates all 907 entries from lershu's community translation, replacing 212 distinct stale or English values across the mod.
- All 34 newer localization entries absent from the supplied reference remain present and translated, including Curio perk-category colours and compact Auto Crafter estimates.

### v2.8.1 changes included

- Auto Crafter's Estimates section now uses five compact one-line rows with currency icons: current resources, generous cost, unlucky cost, and the remaining resources after each estimate. Negative projected balances are red.
- Total estimates now include base-weapon acquisition and live recipe-derived perk/blessing replacement costs in addition to mastery, consecration, and expertise costs. Target search uses visible 100,000/300,000-docket planning boundaries, constrained by the configured acquisition cap.
- Stable Auto Crafter panels now keep Ctrl+V responsive while amortizing native selection, layout pivot, runtime-context, and character checks. Psych Ward also recognizes a remaining queue weapon that was selected despite a false-negative preview result, preventing redundant post-removal retries.
- Staging a Games Lantern queue now retires any older native trait-discovery request, so an idle imported queue cannot acquire a false `trait_discovery_failed` state after 45 seconds.
- Repeated Games Lantern imports remain intentionally deferred. The bounded six-card proposal and required duplicate-input/lifecycle coverage are recorded in [the deferred queue design](docs/deferred-games-lantern-multi-import-queue.md).

### v2.8.0 changes included

- Auto Crafter now renders its status overlay in Psych Ward's live Brunt view, making queued, purchasing, mastery, crafting, completion, and failure states visible before entering the Morningstar.
- Leaving Psych Ward during a backend mutation stops future work, waits for the late response to become inert, then releases Games Lantern queue ownership instead of remaining indefinitely busy after the character transition.
- Craft and Stop / Interrupt now share one workflow-state predicate. Manual, imported, in-flight, quarantined, and reconciliation states are mutually exclusive in the controls and force a panel refresh when activity changes.
- Repeated native mastery requests blocked during that settlement now produce one notification per unresolved operation instead of flooding the notification stack.
- Auto Crafter's MyFavorites assignment now refreshes MyFavorites' cloned runtime cache, applying the chosen icon color immediately and preserving it across restarts.
- Pasted Games Lantern builds now expose a red X on each staged card, allowing either melee or ranged equipment to be removed before confirmation so only the remaining weapon is crafted.

### v2.7.0 changes included

- Secondary Curio perks now use category colours by default, grouping Health, Toughness, Wounds, stamina/efficiency, enemy damage resistance, corruption resistance, ability regeneration, mission rewards, and revive speed.
- Health and Toughness secondary perks share their corresponding primary-stat colours; stamina regeneration, sprint efficiency, and block efficiency share Max Stamina's colour. Corruption resistance shares the Wound purple, enemy damage resistance uses pink, mission rewards use a soft peach, and Revive Speed uses a neutral tone distinct from Toughness.
- Every category has independent preset and RGB controls. The previous single-colour mode remains available, and its colour safely handles unknown future Curio perks.

### v2.6.3 changes included

- Detects an equipped compound shield before Darktide initializes the weapon-inventory base view, preventing dense geometry from reaching the engine's failing preview path.
- Rechecks the fetched inventory for unequipped Slab Shields and current Arbites shield families, then uses the known-safe three-column layout for the complete affected view.
- Keeps configured four- and five-column layouts for ordinary weapon inventories while preserving Darktide's native weapon images in both Character Overview and inventory; the failed static-texture substitution has been removed.

### v2.6.2 changes included

- Weapon inventories containing a compound shield automatically used a conservative three-column compatibility layout while the four/five-column crash path was investigated.
- The compatibility guard covered all four current Ogryn and Arbites marks across the Slab Shield, power-maul shield, and shotpistol shield families.
- Per-card modifier projection contains and caches malformed expertise/template failures, preventing repeated draw-time retries from blocking the inventory grid.

### v2.6.1 changes included

- Ogryn Slab Shields no longer crash, stall, or empty the melee inventory grid. Card modifiers now read their five identities directly from bounded item and weapon-template data instead of running Darktide's full action-heavy weapon-stat calculator for every visible card.
- The compatibility audit covers all 142 shipped weapon templates and 37 modifier display identities, with no missing or duplicate identities. Slab Shield and sparse, malformed, or failed future-template records now have critical fail-soft regression coverage.

### v2.6.0 changes included

- Auto Crafter now admits Psych Ward's character-selection Brunt view while that exact live vendor view remains valid; unrelated main-menu views, destroyed views, and matchmaking still fail closed.
- Reaching an enabled acquisition cap now promotes and crafts the closest valid candidate when fallback is enabled. Games Lantern preserves its frozen stat-distance proof and revalidates it after final crafting and between queued jobs.
- Ordo-docket and maximum-purchase caps now govern target acquisition only. After a target is frozen, below-20 mastery may continue buying fodder until the real wallet or inventory limit, fixing runs that stopped midway after the HUD vanished.
- **Base weapon acquisition** is now a three-state selector: Disabled, buy the first authoritative Brunt weapon and proceed, or search for the target-stat weapon (default). Existing On/Off saves migrate to target search/disabled.
- The dump-target row's comparison selector can require an exact target (original behavior) or accept the first projected level-500 value lower than or equal to it. Custom five-stat plans remain exact.

### v2.5.1 changes included

- WKC kill counters on Brunt's native two-column weapon cards now use a compact 14 px font and 16 px icon in a lower row aligned with the weapon-name inset.
- BetterInventory reapplies that Brunt-specific geometry after WKC style refreshes, preventing the counter from drifting back while leaving other listing and weapon-detail profiles unchanged.

### v2.5.0 changes included

- Conditional inventory-widget rows retain the current scroll offset instead of jumping to the top after option clicks.
- Quick Discard adds default-off minimum Health (21%) and Toughness (17%) roll rules. When enabled, each roll threshold overrides item level for its matching Curio primary type; Wound and Stamina Curios continue to use the enabled minimum-item-level rule.
- Automatic Curio Buyer can favorite its own confirmed purchases through a separate default-off checkbox shown in the inventory widget.
- The Armoury option covers manual purchases from the rotating Armoury Exchange. Sire Melk has independent options for Limited Time Acquisitions and Mystery Acquisitions. All three options default Off; Brunt's Armoury, Auto Crafter, and Automatic Curio Buyer purchases remain excluded.
- With GlobalStore installed, Armoury and Sire Melk Multi-Operative Supply purchases inherit the corresponding Armoury or Limited Time Acquisitions favorite option. Favorites are saved to the character that owns the selected GlobalStore offer, even when another character is viewing it. GlobalStore adds no extra favorite setting. Auto Crafter remains independent, so rejected rolls stay unfavorited and discardable.
- When MyFavorites is available and **Automatically favorite crafted weapon** is enabled, the crafting widget shows a Color 1-5 selector directly beneath it and previews each configured color.
- The crafting widget's **Active Queue** section supports click-to-collapse like its other sections.
- WKC listing counters are stripped from weapon-information stat rows, preventing repeated icon/count pairs while retaining the intended weapon-detail counter.

### Weapon Kill Counter integration

When the `wkc` mod is installed and its card display is enabled, BetterInventory places the kill total on:

- three-column Inventory and Hadron cards;
- native single-column Inventory and Hadron cards;
- Character Overview weapon cards; and
- Brunt's native two-column weapon cards, using the compact lower-left v2.5.1 profile.

Compact cards reserve a dedicated row between the weapon name and perk lines. Brunt cards align their counter with the weapon-name inset near the bottom edge. Single-column and Character Overview cards retain Weapon Kill Counter's native-style icon, font, colour, and number abbreviation where available.

The **Debug (testing only)** option **Weapon Kill Counter test kills** can substitute a 1,000-kill presentation fixture. It defaults to **Off** and never modifies Weapon Kill Counter's stored statistics.

### v2.4.0 changes included

- The native Marks/Cosmetics/Inspect weapon-action panel grows through seven complete rows. At eight or more rows, it keeps the seven-row frame and uses a clipped scrollable viewport with consistent top and bottom padding.
- Auto Crafter was split into fail-closed policies, workflows, controller, Darktide adapters, Games Lantern adapters, and UI modules with explicit lifecycle and mutation-ownership contracts.
- Auto Crafter verifies an explicitly selected final mark from fresh authoritative gear after crafting. Regression coverage includes sibling-mark stat identities, sub-20 mastery, stalled reads, late callbacks, mutation-safe failures, and terminal HUD cleanup.
- Perfect-roll sorting now recognizes 61- and 62-point fifth attributes and ranks them above 60-point rolls without overriding equipped or favorite priority.

See the complete [changelog](CHANGELOG.md) for earlier releases.

## Supported views

| View | BetterInventory behavior |
| --- | --- |
| Character Inventory | Native single-column or responsive two-to-five-column weapon and Curio layouts |
| Character Overview | Detailed melee, ranged, and Curio cards with independent controls |
| Hadron: Entreat | Mirrored Inventory cards, capped at three columns |
| Requisition Weapons & Curios | Responsive cards, window expansion, price/footer handling, and sorting panel |
| GlobalStore: Multi-Operative Supply | Optional two- or three-column cards, operative details, and sorting |
| Brunt's Armoury | Auto Crafter planner, queue, progress HUD, and Games Lantern import; Brunt's native store cards remain owned by Darktide |

Hadron's Sacrifice Weapons grid, Sire Melk, and unrelated custom vendor services retain their native presentation.

## Auto Crafter Helper

Auto Crafter Helper is available from Brunt's Armoury. It can search for a target weapon, level mastery when needed, apply configured perks and blessings, and switch to an explicitly selected mark near the end of the workflow.

**Base weapon acquisition** defaults to **Automatically buy until target stats weapon is found**. Choose **Automatically buy first weapon and proceed** when the roll does not matter, or **Disabled** to block the automated acquisition workflow. The dump-target row independently toggles between **exactly matches** and **is lower or equal to**; the latter accepts the first authoritative projected level-500 dump stat at or below the selected value. It does not relax custom five-stat profiles.

Important contracts include:

- exact five-stat targets must total 380 and each value must remain within 60-80;
- optional closest-candidate fallback minimizes total absolute distance across all five attributes, then becomes the frozen target when an acquisition boundary is reached;
- acquisition caps stop only target searching; mastery fodder remains bounded by the authoritative wallet and inventory capacity;
- selected marks are frozen by exact identity and verified again from authoritative gear before success;
- account mutations remain serialized with BetterInventory and known native/third-party mutation paths;
- ambiguous mutations are not retried automatically;
- character changes, stale generations, missing data, and failed postconditions stop or quarantine the workflow;
- terminal completion or failure wakes and clears the top HUD through bounded state transitions.

Games Lantern build links can stage melee and ranged jobs with their exact stats, perks, blessings, and marks. Queue editing locks before crafting begins, and malformed or ambiguous imports fail without sending an account mutation.

See [Auto Crafter architecture](docs/auto-crafter-architecture.md) for module ownership and lifecycle contracts.

## Safety defaults

Normal card, sorting, and integration features do not write inventory or wallet data.

- Quick Discard and Automatic Discard are disabled by default. Enabling discard management initially selects Manual mode and retains confirmation.
- Automatic Curio Buyer remains disabled by default. If enabled, Operative Selection scanning, the once-per-store-rotation throttle, and idle store-refresh rescanning now default to On.
- Automatic favorite options for Curio Buyer, Armoury Exchange, Sire Melk Limited Time Acquisitions, and Sire Melk Mystery Acquisitions are disabled by default. GlobalStore's matching Multi-Operative Supply routes inherit the relevant vendor option. Auto Crafter color assignment follows its existing **Automatically favorite crafted weapon** checkbox and defaults to MyFavorites Color 1.
- Auto Crafter performs no mutation until the user starts a validated plan.
- Favorites, equipped items, active and saved loadouts, protected perfect rolls, and configured Curio rules are checked before discard operations.
- Automatic purchase and discard paths re-fetch and revalidate authoritative state immediately before writes.
- One shared account-operation guard prevents BetterInventory workflows from overlapping each other.
- Debug weapon-action buttons and the Weapon Kill Counter test value are inert presentation fixtures and default to Off.

Account-changing mods always carry risk. Review the planned operation and keep destructive or purchasing automation disabled unless you intend to use it.

## Optional integrations

BetterInventory has no optional mod dependency. Integrations activate only when the corresponding mod is present and enabled.

| Integration | Behavior |
| --- | --- |
| Weapon Kill Counter (`wkc`) | Responsive kill totals on supported weapon cards without taking ownership of WKC statistics |
| Quick Look Card | Reuses or suppresses overlapping modifier passes while BetterInventory provides its own modifier display |
| Enhanced Descriptions | Sanitizes rich-text markup before compact perk and Curio measurement |
| GlobalStore | Adds responsive Multi-Operative Supply cards and sorting |
| ItemSorting | Exposes its custom comparators beside the complete native sorting set |
| MyFavorites | Preserves colour groups and cycling, synchronizes the compact favorite marker, and optionally assigns Auto Crafter results to a selected color group |
| Lantern of the Omnissiah | Hosts melee/ranged recommendations in the scrollable options panel and avoids icon overlap |
| Name It | Imports and synchronizes names with BetterInventory's item customization storage |
| Quick Level Mastery | Shares the mutation guard and preserves Acquire/Sacrifice layout compatibility |
| Visible Equipment | Preserves Cosmetics placement widgets alongside detailed Loadout cards |
| Inspect from Social / Party Finder | Supports detailed cards while inspecting other players |
| Equipped Icon Plus | Separates inactive-loadout equipped badges from the favorite marker |
| Red Weapons at Home | BetterInventory's enabled custom-tier criteria take precedence; disabling BetterInventory's custom tier restores the other mod's styling |
| Alf's DMF Extensions | Supports its generalized Mod Options layout |

Do not run BetterInventory together with Inventory2D or the Inventory2D Bound by Duty compatibility patch; they modify overlapping inventory presentation paths.

## Installation

BetterInventory requires a working Darktide Mod Loader and Darktide Mod Framework installation.

1. Extract the release archive into Darktide's `Content/mods` directory.
2. Confirm that the descriptor is at `Content/mods/BetterInventory/BetterInventory.mod`.
3. Add `BetterInventory` on its own line in `Content/mods/mod_load_order.txt`.
4. Start or restart Darktide.

The release archive intentionally contains exactly one outer `BetterInventory` directory:

```text
Content/
`-- mods/
    `-- BetterInventory/
        |-- BetterInventory.mod
        `-- scripts/mods/BetterInventory/
```

Configure the mod through **Options > Mod Options > BetterInventory**. Reopen an affected inventory or vendor view after changing structural layout options.

## Development and verification

The runtime is split into 79 Lua sources plus the DMF descriptor. Generated manifests track the runtime bundle, settings schema, localization keys, module ownership, and named risk cases.

Run the complete repository verification from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\verify.ps1
```

The v2.9.3 suite currently discovers 43 behavior-test files and 165 named cases. To run the behavior suite directly with risk-weighted Lua coverage:

```powershell
py -3 .\tests\run_tests.py --timeout-seconds 45 --coverage-output lua-coverage.json
```

Create a verified release archive only with the repository packager:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\package_release.ps1 -OutputPath .\BetterInventory.zip
```

For this checkout, synchronize and hash-verify the canonical live installation with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync_deployed_mod.ps1
```

See [release packaging](docs/release-packaging.md) before publishing an archive. The generated ZIP is intentionally ignored by Git.

## Documentation

- [User guide](docs/user-guide.md) - configuration, safety defaults, custom stats, and live validation guidance.
- [Architecture and ownership](docs/architecture.md) - runtime boundaries, generated contracts, and refactoring rules.
- [Auto Crafter architecture](docs/auto-crafter-architecture.md) - core policies, workflows, adapters, UI ownership, and extraction boundary.
- [Release packaging](docs/release-packaging.md) - archive invariants and the mandatory packaging procedure.
- [Changelog](CHANGELOG.md) - release-by-release changes.
- [v2.9.0 DMF/Alf compatibility and runtime audit](docs/v2.9.0-dmf-alf-compatibility-audit.md) - updated framework contracts, lifecycle fixes, concurrency, memory, and CPU findings.
- [v2.9.1 material crash audit](docs/v2.9.1-material-crash-audit.md) - renderer evidence, weapon-switch vectors, scoped remediation, and remaining attribution limits.
- [v2.9.2 custom-tier design](docs/v2.9.2-custom-tier.md) - classification criteria, exact reference defaults, compatibility ownership, and performance boundaries.
- [v2.3.0 memory and performance audit](docs/v2.3.0-memory-performance-audit.md) - historical audit and verification ledger.
- [v2.0.0 full-project audit](docs/v2.0.0-full-project-audit.md) - historical architecture research and backlog.

Historical audits describe the project at their dated checkpoints; they are not the current feature-status document.

## Credits

BetterInventory is a standalone modern implementation inspired by [Inventory2D](https://www.nexusmods.com/warhammer40kdarktide/mods/188), originally created by Redbeardt. Thanks to Redbeardt for the original multi-column inventory concept and for permitting modifications and improvements with attribution.

Thanks to NexusMods user **lershu** for contributing the comprehensive Simplified Chinese translation incorporated in v2.8.2.

BetterInventory's current implementation, architecture, and additional features were developed independently. It does not include files from the [Bound by Duty compatibility patch](https://www.nexusmods.com/warhammer40kdarktide/mods/594) or third-party assets.
