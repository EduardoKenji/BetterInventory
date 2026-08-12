# Item image size and position audit (v2.2.0)

## Scope and invariants

BetterInventory v2.2.0 adds two top-level option sections: **Weapons images size and position** and **Curios images size and position**. The controls modify only the item-art pass whose style ID is `icon`. They do not mutate item data, card text, selection, sorting, inventory operations, Auto Crafter state, or Darktide's icon lifecycle.

All defaults are zero, so upgrading preserves the exact pre-v2.2.0 image geometry. X and Y are additive offsets measured as a percentage of the resolved card width and height. Width and height are percentage changes from the resolved base icon dimensions: `-50` halves a dimension and `100` doubles it. The resolver clamps malformed settings and never allows an image dimension below one logical UI unit.

Darktide renders these logical card coordinates through its UI canvas. Because the offsets derive from the resolved card dimensions rather than physical pixels, the same profile scales proportionally across screen resolutions and aspect ratios.

## Ownership hierarchy

Each item kind owns these independent profiles:

- Character Overview: one weapon profile and one Curio profile.
- Inventory/Hadron: single-column plus 2, 3, 4, and 5-column profiles. Hadron intentionally mirrors Inventory.
- Armoury Exchange store: single-column plus 2-5-column profiles.
- Armoury Exchange GlobalStore: single-column plus 2-5-column profiles.

The dropdown in each list-view group selects the profile shown for editing. It does not select the runtime layout. Card construction always chooses the profile matching the card's actual column count, preventing stale editor state from affecting another layout.

## Existing-option conflict audit

- `icon_darkness` changes image tint only and composes safely with geometry.
- Grid columns, spacing, card height, inventory expansion, Curio target width, and vendor expansion establish parent/card geometry first. Image percentages apply afterward.
- `curio_preview_height_percent` controls the separate upper Curio preview panel and its preview art, not card item images.
- `curio_information_width_percent` controls the information panel only.
- GlobalStore character-photo size and character-row spacing control operative portraits and metadata, not item art.
- GlobalStore modifier X/Y settings control modifier text only.
- Character Overview's weapon Y correction, compact Curio landscape image, and optional native Curio overlay remain the base geometry. User percentages apply last.

No prior option was removed, repurposed, or migrated.

## Lifecycle and performance

Profiles are read and applied once while Darktide/BetterInventory constructs a card blueprint. No per-frame callbacks, polling, caches, retained views, or recurring allocations were added. Setting changes invalidate existing composition using the established lifecycle; Character Overview settings additionally bump its visual generation so reopening/rebuilding uses the new geometry.

## Regression coverage

Automated coverage checks:

- weapon versus Curio profile ownership;
- all list-view contexts and actual column-count selection;
- Hadron-to-Inventory mirroring;
- Character Overview's independent profile;
- zero-impact defaults;
- proportional logical-canvas scaling;
- width/height and X/Y composition over base geometry;
- malformed values, unknown contexts, missing styles, and minimum dimensions.
