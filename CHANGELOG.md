# BetterInventory changelog

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
