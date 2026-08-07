# BetterInventory changelog

## 1.9.4 - Unreleased

### Fixed / Added

- Fixed Curio rarity colour strips on native/hybrid card lifecycles while preserving per-item custom background colours.
- Added the default-off **Use native Curio overlay** option for detailed Character Overview cards. It restores Darktide's ornate frame and portrait geometry while retaining BetterInventory's title and stat lines. See `docs/v1.9.4-curio-card-visuals-plan.md` for validation details.
- Aligned native-overlay Curio titles, stat rows, and equipped markers 8 px lower within the ornate frame.

## 1.9.3 - 2026-08-07

### Implemented

- Added optional Operative Selection scanning, default-on account-scoped Armoury rotation throttling, backend-boundary timing, and optional idle refresh rescans for the Automatic Curio Buyer. See `docs/v1.9.3-automatic-curio-buyer-plan.md` for the implementation handoff and in-game validation matrix.

## 1.9.2 - 2026-08-06

### Fixed

- Fixed Change Name silently doing nothing when Darktide's global popup handler was created before BetterInventory added its text field.
- Repair the live popup scenegraph when necessary and resolve its active text widget when opening or closing the name editor.
- Hardened failed persistence writes, Name It map reads, editor shutdown, and repeated input-legend rebuilds; expanded lifecycle regression coverage and maintenance documentation.

## 1.9.1 - 2026-08-06

### Fixed

- Added RT controller focus switching and directional navigation to BetterInventory's Armoury Exchange and GlobalStore sorting panels, including a matching input-legend entry.

## 1.9.0 - 2026-08-06

### Added

- Added controller navigation for the scalable inventory-options widget, with RT switching focus between the item grid and widget, directional navigation between rows and controls, and the normal confirm action activating the selected option.
- Added a collapsible Darktide Native Sorting section to the discard-mode widget, placed after ItemSorting when that integration is active.

### Fixed

- Positioned the scalable options widget directly below and left-aligned with Darktide's native discard-filter window, preventing overlap with item information and the Discard Items button across resolutions.
- Fixed controller right-navigation in multi-column melee and ranged inventories so it selects the next item in the current row before transferring focus to Darktide's Marks/Cosmetics/Inspect options at the row edge.
- Moved Background Color's default controller binding from R3 to LT so it no longer conflicts with Darktide's native Discard Items action, including migration of the previous default binding.
- Kept controller handling action-based and device-agnostic for Xbox, PlayStation and custom controllers mapped through Darktide's normal navigation inputs.
- Consolidated inventory update handling into one DMF hook so Ctrl+Shift+R hot reload no longer warns about rehooking `InventoryWeaponsView.update` with a different hook type.

## 1.8.0 - 2026-08-06

### Added

- Added a default-on Lantern of the Omnissiah integration that hosts Lantern's weapon recommendation window as the top section of BetterInventory's scalable inventory-options panel and suppresses the duplicate floating panel while active.
- Added a default-on option that keeps Lantern's Recommended Curios panel in its native standalone placement instead of hosting it inside BetterInventory's panel.
- Added automatic ItemSorting integration to the melee, ranged, Curio, Armoury Exchange and GlobalStore sorting panels.
- Added a collapsible `ItemSorting mod` section with its complete custom method set, including Family + Mark and both Base Rating directions, while preserving every vanilla-style method under `Darktide Native Sorting`.
- Kept ItemSorting's comparator ownership, ordering and callbacks intact without changing its saved Mod Options, and kept the expanded store panels bounded and scrollable.

### Fixed

- Moved the equipped marker lower on Character Overview cards so it no longer collides with Lantern's recommendation icon.
- Made the Character Overview marker offset follow Lantern's live enabled/recommendations state, and restore each card's original placement when inactive.
- Hid hosted Lantern recommendations during item comparison and discard management, and released stale hosted content when Lantern is disabled at runtime.

## 1.7.4 - 2026-08-06

### Added

- Added a default-on option to show or hide the complete inventory options widget without changing its saved sorting or item-management settings.
- Added signed inventory and GlobalStore width stress controls for validating responsive cards and sibling-panel positioning.

### Fixed

- Anchored the inventory options widget to the live weapon-information right edge and native button-section bottom edge across centered ultrawide workspaces.

## 1.7.3 - 2026-08-06

### Added

- Added a default-off Armoury geometry stress test with a configurable 10-100% store-width increase and proportionally resized equipment cards.

### Fixed

- Centered the combined Acquire and Quick Level Mastery Sacrifice actions on the rendered weapon-information panel, independent of the store-grid width.
- Anchored the Armoury Sorting panel to the weapon-information panel and kept it below the Ordo Dockets frame with consistent padding.
- Corrected the weapon-information scenegraph API used by the Quick Level Mastery compatibility path.

## 1.7.2 - 2026-08-05

### Added

- Added Character Overview weapon and Curio cards with configurable Curio title modes and text scaling.
- Added Visible Equipment, MyFavorites, Name It and standalone **Custom Item Names and Colors** integrations.
- Added GlobalStore Multi-Operative Supply cards and sorting controls.
- Added supported-vendor single-column mirrors for Entreat Hadron and Requisition Weapons & Curios.

### Improved

- Stabilized DMF options cardinality for Alf's DMF Extensions and fixed operative-slot discovery across cold starts.
- Added Armoury sorting, store-card footer layout, native sorting controls and safe two-to-three-column vendor limits.
- Hardened discard revalidation, Automatic Curio Buyer character targeting, wallet selection and transaction sequencing.

### Fixed

- Release packaging now discovers every runtime Lua module and independently verifies the complete archive, including `BetterInventory_item_customization.lua`.

## 1.3.0 - 2026-08-04

### Added

- Added individual saved-character targeting to the Automatic Curio Buyer, with safe fallback to class targeting when character data is unavailable.
- Added built-in maximum-potential weapon modifier stats without requiring Quick Look Card: all five modifiers in single-column mode and the lowest modifier in grid mode.
- Added a dedicated **Single-column layout** options section with controls for weapon-name font size and blessing tier-symbol placement.
- Added single-column modifier controls for font size and horizontal and vertical positioning.

### Improved

- Curio Buyer notifications now identify the character receiving each purchase, and purchases use that character's wallet.
- Reused and normalized Quick Look Card passes when that mod is installed, avoiding duplicate weapon modifier displays.
- Improved fitting of long blessing names on weapon cards.
- Refined Curio Buyer labels and character-selection behavior.

### Fixed

- Normalized Curio primary-stat roll values across localized and rich-text descriptions so valid Health, Toughness, Stamina, and Wound rolls are evaluated consistently.
- Kept Curio Buyer character selections valid after settings reloads and hot reloads.

## 1.2.0 - 2026-08-04

### Added

- Added the Automatic Curio Buyer: cross-character scans for Curios meeting configurable criteria and automatic purchase of desirable Curios.
- Added complete Simplified Chinese (`zh-cn`) localization.

### Improved

- Improved Enhanced Descriptions mod integration.
