# God Stat Checker 1.1.2 compatibility

BetterInventory v3.0.0 gives one mod exclusive ownership of weapon and Curio background colours when **Custom legendary tier** and **God Stat Checker 1.1.2** are enabled together. The selector is shown in two places for discoverability:

- **Custom legendary tier > Background colour owner**
- **Mod integration: God Stat Checker 1.1.2 > Background colour owner**

The controls are mirrored. Changing either immediately saves the same choice in both. **Custom legendary tier** is the default.

## Why ownership is necessary

God Stat Checker 1.1.2 has two colour paths. It wraps `Items.rarity_color`, which is also the seam used by the right item-information panel, and it directly repaints tracked inventory/loadout cards after their widgets have been built. Before v3.0.0, Better Inventory's outer Custom Tier wrapper could therefore make the detail panel red while God Stat Checker's later card repaint made the left cards gold or grey. Load order alone could not make both surfaces agree.

GodRolls Version 3 does not participate in this conflict. Its relevant code changes displayed weapon names and inline star/roll markup, not rarity background colours.

## Custom legendary tier owns backgrounds

This is the default mode.

- Qualifying backgrounds use Better Inventory's configured Custom Tier colour on cards and the detail panel.
- God Stat Checker is switched to `verdict_text_only` only when its current style would paint a background. Its grading/name text remains active.
- The user's previous God Stat Checker card style is stored and restored later. A subsequent GSC style selection is also remembered, then constrained back to text-only while this ownership mode remains active.
- God Stat Checker's captured original-rarity function is compatibility-wrapped so its direct repaint recognizes qualifying Custom Tier colours instead of treating them as an unknown foreign override.

## God Stat Checker owns backgrounds

- Better Inventory restores the user's saved God Stat Checker card style.
- Custom Tier defers its background result for qualifying items, allowing God Stat Checker's grade colour to reach both cards and the detail panel.
- Custom Tier still owns its classification criteria and Sainted rarity name. This selector governs backgrounds only.

If the saved God Stat Checker style is `verdict_text_only` or `none`, selecting God Stat Checker respects that preference and does not invent a background.

## Priority and lifecycle

An explicit per-item background from **Custom item names and colours** keeps final priority over Custom Tier. When God Stat Checker owns backgrounds, its selected card style retains God Stat Checker's native priority behavior. If God Stat Checker is missing, mod-disabled, or has its display feature disabled, Custom Tier automatically becomes the effective owner so qualifying items do not lose their red background. Disabling Better Inventory restores any God Stat Checker style it temporarily constrained; re-enabling reconciles the saved owner again.

The compatibility layer reacts only to settings and mod lifecycle events. It reuses God Stat Checker's own tracked-card repaint and does not add a per-frame callback, recurring widget scan, retained item list, backend request, or account mutation.
