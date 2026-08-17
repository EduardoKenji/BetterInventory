────────────────────────────
ABOUT THIS MOD
────────────────────────────

BetterInventory is a modern, highly configurable inventory and item-management overhaul for Warhammer 40,000: Darktide.

It replaces the restrictive single-column inventory with responsive two-to-five-column grids while retaining an enhanced native single-column option. Useful weapon and Curio information is displayed directly on each item card without taking ownership of Darktide's item-icon resources.

Layout, typography, colours, spacing, item images, information density, sorting priorities, supported vendor grids, highlights, and optional integrations can all be configured through Mod Options.

BetterInventory supports melee weapons, ranged weapons, Curios, Character Overview cards, Entreat Hadron, Requisition Weapons & Curios, and GlobalStore's Multi-Operative Supply. Vendor grids are limited to three columns where needed to preserve the surrounding interface.

It also provides optional inventory-management tools:

- Auto Crafter Helper in Brunt's Armoury
- Automatic Curio Buyer
- Experimental manual and automatic item-discard management
- Standalone Custom Item Names and Colors

Automatic purchasing and discard management are disabled by default. Auto Crafter can display its planner and perform a read-only probe by default, but account changes begin only after an explicit Craft click on a valid plan.

────────────────────────────
COMPATIBILITY WITH OTHER MODS / SUPPORTED INTEGRATIONS
────────────────────────────

Supported integrations:

- (v1.0.0+) Red Weapons at Home: preserves red-coloured equipment cards when the original mod marks an item accordingly.
- (v1.2.0+) Enhanced Descriptions: safely handles rich-text Curio and compact perk strings, with an option controlling simplified Curio primary labels.
- (v1.3.0+) Quick Look Card: optional integration for native single-column and grid layouts. BetterInventory also includes its own weapon-modifier display.
- (v1.3.2+) Alf's DMF Extensions: compatible with BetterInventory's stable DMF Mod Options layout.
- (v1.5.0+) GlobalStore: supported Multi-Operative Supply integration with stylized cards and custom sorting in two or three columns.
- (v1.5.2+) Equipped Icon Plus: inactive-loadout equipped badges coexist with BetterInventory's favorite marker.
- (v1.6.0+) Inspect from Social: detailed weapon and Curio cards when inspecting other players.
- (v1.6.0+) Inspect from Party Finder: detailed weapon and Curio cards when inspecting other players.
- (v1.6.2+) Visible Equipment: detailed Loadout cards coexist with Cosmetics placement widgets.
- (v1.6.3+) MyFavorites: preserves coloured favorite groups and cycling while synchronizing BetterInventory's compact favorite marker.
- (v1.7.0+) Name It: optional import and synchronization through BetterInventory's Custom Item Names and Colors module.
- (v1.7.4+) Quick Level Mastery: preserves Acquire/Sacrifice button alignment and shares Auto Crafter's mutation guard. It stops Auto Crafter safely between requests or is rejected while an Auto Crafter request remains unresolved.
- (v1.8.0+) Lantern of the Omnissiah: embeds melee and ranged recommendations in BetterInventory's scrollable options panel and prevents icon overlap. Curio recommendations remain separate by default.
- (v1.8.0+) ItemSorting: preserves native sorting and adds a dedicated section for Family, Family + Mark, and both Base Rating directions.
- (v2.4.1+) Weapon Kill Counter: displays WKC-owned kill totals on supported three-column, native single-column, Hadron, and Character Overview cards.

BetterInventory has no optional mod dependencies. Integrations activate only when the corresponding mods are installed and enabled.

────────────────────────────
VERSION 2.4.1 HIGHLIGHTS
────────────────────────────

- Adds responsive Weapon Kill Counter totals to three-column, native single-column, Hadron, and Character Overview weapon cards.
- Adds an off-by-default 1,000-kill visual test that never changes Weapon Kill Counter's saved statistics.
- Expands the native Marks/Cosmetics/Inspect weapon-action panel through seven complete rows, then uses a clipped scrollable viewport with consistent top and bottom padding.
- Recognizes 61- and 62-point fifth attributes as perfect rolls and sorts them as 62 > 61 > 60 while preserving equipped and favorite priorities.
- Refactors Auto Crafter into fail-closed policy, workflow, controller, Darktide adapter, Games Lantern adapter, and UI modules with explicit lifecycle and mutation-ownership contracts.
- Hardens Auto Crafter mark changes, sibling-mark stat matching, sub-20 mastery, exact final-mark verification, stalled reads, late callbacks, terminal HUD cleanup, and mutation-safe failure recovery.

────────────────────────────
MAIN FEATURES
────────────────────────────

- Responsive two-to-five-column grids for melee, ranged, and Curio inventories
- Enhanced native single-column weapon and Curio cards
- Independent column and enable settings for melee, ranged, and Curio inventories
- Automatic inventory-window expansion with safe screen-boundary clamping
- Configurable card width, height, spacing, icon darkness, and typography
- Automatic card height based on the information currently displayed
- Independent item-image position and size profiles for supported views and layouts
- Adaptive item names that shrink or use an ellipsis while preserving the Mark
- Correct current weapon pattern and Mark display
- Configurable weapon quality, expertise, item-power icon, and favorite marker
- Equipped-item and newly-acquired-item highlight modes
- Equipped and favorited item prioritization
- Perfect-roll prioritization with 62 > 61 > 60 fifth-attribute ordering
- Native Rating, Rarity, and Name sorting inside each priority group
- A scalable, scrollable inventory-options panel with collapsible sections
- Armoury sorting and complete native sorting controls
- Built-in maximum-potential weapon modifier information
- Responsive native weapon-action panel with scrolling after seven rows
- Character Overview weapon and Curio cards
- Entreat Hadron and Requisition Weapons & Curios cards
- Optional GlobalStore Multi-Operative Supply integration
- Optional Weapon Kill Counter card integration
- Standalone Custom Item Names and Colors
- Optional Name It synchronization
- Auto Crafter Helper with Games Lantern build import
- Optional cross-character Automatic Curio Buyer
- Optional experimental manual and automatic item-discard management
- English and Simplified Chinese localization

────────────────────────────
WEAPON INFORMATION
────────────────────────────

- Configurable weapon perk and blessing information directly on item cards
- Four blessing display modes:
  - Tier symbols with blessing names
  - Ranked blessing icons
  - Compact text lines
  - Off
- Native Darktide perk and blessing rank symbols
- Configurable icon sizes, spacing, text sizes, colours, and opacity
- Full, compressed, or heavily compressed perk descriptions
- Unknown or newly added perks fall back to their native descriptions
- Optional removal of leading plus signs
- Automatic layout space reservation for perks, blessings, and item power
- Built-in maximum-potential weapon modifier display
- All five maximum-potential modifiers in native single-column mode
- Lowest maximum-potential modifier in grid mode
- Optional Quick Look Card pass reuse with duplicate-display prevention
- Optional Weapon Kill Counter total with layout-aware icon and text placement

────────────────────────────
WEAPON-ACTION BUTTON PANEL
────────────────────────────

Other mods can add actions beside the weapon details below Darktide's native Marks, Cosmetics, and Inspect buttons.

BetterInventory expands that native panel to fit up to seven complete rows. At eight or more rows, the panel keeps its seven-row maximum height and uses Darktide's clipped, scrollable grid so buttons no longer draw below the frame. The first and final rows retain consistent padding at the top and bottom of the scroll range.

The Debug section can generate 5, 10, or 20 total rows with inert test buttons for presentation and controller-navigation checks. This option defaults to Off and should remain disabled during normal play.

────────────────────────────
WEAPON KILL COUNTER INTEGRATION
────────────────────────────

Weapon Kill Counter is optional and remains the owner of all kill statistics.

When Weapon Kill Counter is installed and its weapon-card display is enabled, BetterInventory adds its kill total to:

- Three-column Inventory cards
- Three-column Hadron cards
- Native single-column Inventory and Hadron cards
- Character Overview weapon cards

Compact cards reserve a dedicated row between the weapon name and perk lines. Single-column and Character Overview cards retain Weapon Kill Counter's native-style icon, font, colour, and number formatting where available. For example, Weapon Kill Counter normally formats 1,000 as 1k.

The Debug option Weapon Kill Counter test kills can show a presentation-only 1,000-kill value on every supported weapon card. It defaults to Off and never writes to or replaces Weapon Kill Counter's saved data.

────────────────────────────
ITEM HIGHLIGHTS
────────────────────────────

Equipped-item highlight modes:

- Off
- Soft glow
- Animated dashed border
- Pulsing animated dashed border
- Solid border

The default is a gold Animated dashed border at width 2. Glow intensity, border width, colour presets, and custom RGB channels are configurable. The dashed modes use Darktide's native animated material.

Newly-acquired-item highlight modes:

- Native dot only
- Soft glow
- Animated dashed border
- Pulsing animated dashed border
- Solid border

The default is a green Pulsing animated dashed border at width 2. BetterInventory uses Darktide's authoritative persisted new-item state instead of maintaining a second acquisition database.

New items are acknowledged on selection by default. An optional Hover mode acknowledges an item when the mouse enters its card; controller focus also counts in Hover mode.

────────────────────────────
CURIO INFORMATION
────────────────────────────

- Detailed profile showing the innate stat and all three secondary perks
- Compact profile showing only the primary innate stat
- Optional Curio item-level display
- Independent primary and secondary stat font sizes
- Configurable spacing between primary and secondary stats
- Full, compressed, and heavily compressed Curio descriptions
- Distinct configurable colours for Health, Toughness, Wounds, and Stamina
- Separate colour controls for secondary Curio perks
- Optional simplified labels such as Health, Toughness, and Stamina
- Optional native Character Overview Curio overlay
- Enhanced Descriptions integration with configurable primary-line ownership
- Unknown descriptions remain unchanged instead of being discarded

────────────────────────────
CHARACTER OVERVIEW
────────────────────────────

Character Overview can display BetterInventory's detailed cards for:

- Equipped melee weapons
- Equipped ranged weapons
- Curios

Features include:

- Independent melee and ranged card switches
- Detailed Curio cards with all four stat lines
- Configurable Curio title mode
- Optional one-line or two-line Curio names
- Configurable Curio text scaling
- Independent item-image position and size controls
- Optional weapon dump-stat-only mode
- Optional Weapon Kill Counter totals
- Wrapped long stat descriptions
- Native empty and locked Curio-slot artwork
- Compatibility with Inspect from Social and Inspect from Party Finder
- Compatibility with Visible Equipment's Cosmetics placement widgets

Character Overview changes are limited to overview widgets and do not alter normal inventory card geometry.

────────────────────────────
AUTO CRAFTER HELPER
────────────────────────────

WARNING: Auto Crafter can spend Ordo Dockets, Plasteel, Diamantine, and other crafting resources. Depending on the selected workflow, it can also upgrade, sacrifice, or discard run-owned weapons. Review the complete plan and safety caps before clicking Craft.

Auto Crafter Helper adds a dedicated planner to Brunt's Armoury. The panel and read-only Brunt probe can be enabled without changing account data. Mutations begin only after an explicit Craft click and fresh authoritative validation.

The planner can:

- Target the currently selected Brunt weapon family and an optional exact Mark
- Search for a configured dump stat and value
- Target an exact five-stat allocation with each value from 60 to 80
- Require the exact five-stat allocation to total 380
- Keep the closest fallback candidate by total five-stat distance
- Limit the search by an Ordo Docket budget and optional purchase count
- Reuse compatible inventory weapons under the configured protection rules
- Level weapon mastery to 20 using run-owned fodder when requested
- Allocate mastery points
- Consecrate the result
- Upgrade expertise to 500
- Apply two selected perks and two selected blessings
- Switch to the explicitly selected Mark near the end of crafting
- Favorite the final verified weapon
- Show progress in the top crafting HUD while the run continues across views

Games Lantern build links can stage melee and ranged jobs with exact stats, perks, blessings, and Marks. The queue is fixed to melee then ranged, but either staged card can be inspected and edited before crafting starts. Malformed, ambiguous, or invalid builds remain blocked and send no account mutation.

Safety behavior includes:

- One serialized account mutation at a time
- Shared ownership with BetterInventory discard and Curio Buyer workflows
- Protection against overlapping known native and third-party account writes
- Character, gear ID, weapon family, stat identity, and selected-Mark checks
- Fresh authoritative inventory verification after important mutations
- No blind retry after timeout or another ambiguous mutation result
- Stale-generation and late-callback rejection
- Exact final-Mark verification before success
- Bounded terminal HUD completion/failure cleanup
- Fail-closed behavior when required modules, data, or postconditions are missing

────────────────────────────
AUTOMATIC CURIO BUYER
────────────────────────────

WARNING: This feature spends Ordo Dockets automatically and does not display a confirmation prompt before each purchase.

The Automatic Curio Buyer is disabled by default.

Morningstar entry is the normal scan trigger. An additional Operative Selection scan is available as a separate default-off option. A separate account-scoped rotation gate can limit both contexts to one scan per actual Armoury refresh, and an optional idle watcher can perform one additional scan after the store refreshes while the user remains in an eligible view. These additional scheduling options default to Off.

In the Morningstar, automatic discard is allowed to finish before the Curio Buyer starts.

Available filters include:

- Minimum Curio item level
- Minimum Health primary roll
- Minimum Toughness primary roll
- Health Curios
- Toughness Curios
- Stamina Curios
- Wound Curios
- Individual class selection
- Individual character selection

Character targeting is the default. If no usable character profiles are returned, BetterInventory safely falls back to class targeting.

Item-level and primary-roll requirements use an inclusive AND relationship.

For example, with item level 410 and Toughness 17% configured, a Toughness Curio must be both item level 410 or higher and have a primary roll of 17% or higher.

The buyer:

- Scans Armoury offers across enabled characters
- Uses Darktide's displayed Curio roll values
- Revalidates each offer immediately before purchasing
- Uses the wallet belonging to the target character
- Processes purchases sequentially
- Never blindly retries an ambiguous purchase response
- Fails safely when offer or roll information cannot be validated
- Shares account-operation ownership with Auto Crafter and discard workflows
- Protects Curios matching its active acquisition rule from automatic discard

Notifications report purchased Curios, total Ordo Dockets spent, insufficient funds, failures, and optionally when no eligible Curios were found.

Detailed diagnostic logging is available as an opt-in troubleshooting option.

────────────────────────────
EXPERIMENTAL DISCARD MANAGEMENT
────────────────────────────

WARNING: Discarding items is irreversible. Review the preview carefully before confirming any operation.

Discard management is disabled by default. When enabled, it initially uses Manual mode and retains a confirmation prompt.

Available controls include:

- Manual or Automatic mode
- Included melee, ranged, and Curio categories
- Maximum rarity and item-level thresholds
- Protection for favorited items
- Protection for items used by the active or any saved loadout
- Protection for items above the highest equipped level in their category
- Protection for perfect-roll weapons
- Minimum Curio item-level protection
- Separate Health, Toughness, Wound, and Stamina Curio protections
- Optional colour-coded item and category summaries

Automatic mode requires a separate explicit selection and runs only in the Morningstar. Before deleting anything, BetterInventory fetches the inventory again and revalidates:

- The selected character
- The current game mode
- The active discard settings
- Equipped and favorited items
- Active and saved loadout items
- The originally selected gear IDs
- Curios protected by the Automatic Curio Buyer

Skipping automatic confirmation is a separate option and is disabled by default. The manual discard button always retains its confirmation prompt.

────────────────────────────
CUSTOM ITEM NAMES AND COLORS
────────────────────────────

BetterInventory includes a standalone Custom Item Names and Colors module.

Selecting an inventory item can expose direct actions for:

- Change Name
- Name Color
- Background Color

Changes are stored per gear ID, survive restarts, refresh the selected card immediately, and are removed when Darktide deletes the item.

Name It remains optional. When installed, BetterInventory can import and synchronize Name It data while retaining BetterInventory's own records.

────────────────────────────
QUICK LOOK CARD INTEGRATION
────────────────────────────

Quick Look Card is optional.

BetterInventory provides its own built-in weapon-modifier display and can also integrate with Quick Look Card when it is installed.

Native single-column integration can preserve BetterInventory's perk and blessing lines while displaying all maximum-potential weapon modifiers.

Grid integration can display the weapon's lowest maximum modifier near its name or above the weapon-power value.

BetterInventory reuses or suppresses overlapping passes to prevent duplicate modifier information.

────────────────────────────
ENHANCED DESCRIPTIONS INTEGRATION
────────────────────────────

BetterInventory supports Enhanced Descriptions and safely handles its rich-text formatting before compact strings are parsed, measured, or cropped.

A dedicated integration option controls Curio primary lines:

- Enabled: BetterInventory preserves its simplified Curio primary-stat labels
- Disabled: Enhanced Descriptions may override those primary labels

BetterInventory uses stable gameplay data for Automatic Curio Buyer filtering, so presentation changes from Enhanced Descriptions do not alter eligibility.

Enhanced Descriptions is not required.

────────────────────────────
SUPPORTED VIEWS AND INTENTIONAL SCOPE
────────────────────────────

BetterInventory can use its detailed cards in:

- Character Inventory
- Character Overview
- Entreat Hadron
- Requisition Weapons & Curios
- GlobalStore Multi-Operative Supply

Entreat Hadron, Requisition Weapons & Curios, and GlobalStore are limited to a maximum of three columns.

Brunt's native store-card layout remains owned by Darktide, but BetterInventory adds the Auto Crafter planner, Games Lantern queue, progress HUD, and related lifecycle handling to Brunt's Armoury.

The following interfaces retain their native presentation:

- Hadron's Sacrifice Weapons grid
- Sire Melk
- Unrelated custom vendor services

────────────────────────────
LOCALIZATION
────────────────────────────

BetterInventory currently includes:

- English
- Simplified Chinese (zh-cn)

Most settings, tooltips, notifications, integrations, and workflow information are localized in both languages. A small number of the newest technical, debugging, and Auto Crafter HUD strings remain in English in v2.4.1 while translation catches up.

────────────────────────────
INSTALLATION
────────────────────────────

- Install the Darktide Mod Loader
- Install the Darktide Mod Framework
- Extract the BetterInventory folder into your Darktide mods directory
- Add BetterInventory to mod_load_order.txt after dmf
- Launch Darktide
- Configure BetterInventory through Mod Options

The final descriptor path should be:

Warhammer 40,000- Darktide/Content/mods/BetterInventory/BetterInventory.mod

If you see BetterInventory/BetterInventory/BetterInventory.mod, the archive was extracted with one directory too many.

────────────────────────────
REQUIREMENTS
────────────────────────────

Required:

- Darktide Mod Loader
- Darktide Mod Framework

BetterInventory has no optional mod dependencies.

────────────────────────────
KNOWN CONFLICTS AND COMPATIBILITY NOTES
────────────────────────────

Do not install BetterInventory alongside Inventory2D or the Inventory2D Bound by Duty compatibility patch. They modify overlapping inventory presentation paths and may conflict.

BetterInventory uses chain-safe hooks and narrowly identifies the views it modifies. GlobalStore's supported route is integrated explicitly. Brunt's native store cards and Hadron's Sacrifice Weapons grid remain native, although Brunt's view is extended with Auto Crafter UI and lifecycle handling.

Other mods that replace the same inventory item blueprints, weapon-action panel, or presentation methods may still conflict.

When reporting a compatibility problem, please include:

- Your mod load order
- The inventory, vendor, Brunt, Hadron, or Character Overview screen involved
- Your BetterInventory settings
- The other installed UI and inventory mods
- The relevant Darktide console log when available

────────────────────────────
IMPORTANT NOTES
────────────────────────────

- Some geometry settings require closing and reopening the affected view
- Disabling the main grid restores Darktide's native card width while retaining compatible enabled information features
- Extreme width, spacing, and column combinations are clamped to the UI canvas
- Weapon-action and Weapon Kill Counter test options default to Off
- Experimental discard management is disabled by default
- Automatic discard and confirmation skipping require separate explicit choices
- Automatic Curio Buyer is disabled by default
- Automatic purchasing spends Ordo Dockets without per-item confirmation
- Auto Crafter changes account data only after an explicit validated Craft click
- Auto Crafter can consume currency, crafting resources, and run-owned fodder
- New Darktide updates may change blueprints, data, or services and require a BetterInventory update

────────────────────────────
SOURCE / DOCUMENTATION
────────────────────────────

GitHub repository: https://github.com/EduardoKenji/BetterInventory

The repository contains the current README, complete changelog, user guide, architecture notes, Auto Crafter ownership contracts, release-packaging rules, and automated behavior tests.

────────────────────────────
INSPIRATION / CREDITS
────────────────────────────

BetterInventory is a standalone modern inventory overhaul inspired by Inventory2D, originally created by Redbeardt.

Thanks to Redbeardt for the original multi-column inventory concept and for permitting modifications and improvements with attribution.

Thanks to deluxghost, creator of Quick Look Card. BetterInventory's weapon-modifier display began as an optional Quick Look Card integration and later evolved into a standalone built-in feature.

BetterInventory's current architecture, responsive layout system, sorting, vendor integrations, Character Overview cards, Auto Crafter, Automatic Curio Buyer, discard-management tools, custom item editor, and compatibility handling were developed independently using current Darktide APIs.

BetterInventory does not bundle files from Inventory2D, Inventory2D Bound by Duty, Quick Look Card, Weapon Kill Counter, or any other optional integration.

Thanks to the Darktide Mod Framework maintainers and the wider Darktide modding community for the tools, documentation, and research that make projects like this possible.
