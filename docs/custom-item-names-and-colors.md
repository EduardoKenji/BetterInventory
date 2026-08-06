# Custom Item Names and Colors maintenance contract

This document describes the runtime invariants for `BetterInventory_item_customization.lua`. Treat them as regression requirements whenever inventory input legends, popup handling, settings persistence, item deletion, or Name It compatibility changes.

## Ownership and storage

- BetterInventory stores one optional record per Darktide gear ID in `custom_item_name_and_colors`.
- A record may contain `name`, `name_color`, `background_color`, `background_preserve_shading`, `character_id`, and the migration-only `name_target` field.
- Empty records must be removed. Deleted gear and deleted characters must remove their records and matching Name It entries.
- Writes are batched until the next module update. A failed DMF settings flush must remain pending and retry; it must never be reported internally as complete.

## Name It integration

- Name It is optional. BetterInventory owns names while its standalone editor is enabled and mirrors successful edits to Name It for compatibility with native views.
- BetterInventory must not replace Name It's map unless reading the complete existing map succeeded. A protected read failure is a no-op for Name It synchronization.
- Disabling BetterInventory's editor restores Name It's inventory legend action. Re-enabling removes that duplicate and restores BetterInventory's three actions without accumulating entries.
- Ownership handoffs preserve BetterInventory-only color fields. Names removed while Name It owns the map are treated as intentional resets when BetterInventory resumes ownership.

## Input legend lifecycle

- Change Name, Name Color, and Background Color callbacks must exist before `InventoryWeaponsView.init` builds the native input legend.
- BetterInventory owns the active Change Name binding while its standalone editor is enabled; Name It's saved binding must not override it. The default is `lobby_open_inventory` (I / Xbox View / PlayStation touchpad), because Q maps to Darktide's native controller Favorite action.
- Existing Q defaults migrate once to `lobby_open_inventory`; explicit alternative bindings remain unchanged.
- Repeated `_setup_input_legend` calls must be idempotent.
- `off` keybinds must not create legend entries.
- Legend visibility requires a selected grid widget; editor callbacks additionally require a real item with a non-empty gear ID.

## Popup-handler lifecycle

Darktide's `ConstantElementPopupHandler` is a global singleton and may be instantiated before DMF applies the custom text-field definition. Change Name is the only customization action that needs this extra widget; the two color editors use native grid-popup content.

The implementation therefore must:

1. Patch the popup definitions through `hook_require`.
2. Detect a live handler that lacks `better_inventory_name_input`.
3. Rebuild that handler's scenegraph once from the complete patched definition and attach the missing widget.
4. Resolve the current handler on demand before opening or closing the editor, because another mod can recreate it.
5. Bound protected creation failures to three attempts per handler and emit only one warning.
6. Roll back `visible` and `is_writing` if the popup cannot be opened, and release keyboard capture when BetterInventory is disabled.

Do not simplify this to a cached widget populated only by the handler's `update`: that ordering caused the v1.9.2 regression where Q appeared in the legend but silently did nothing.

## Required regression coverage

`tests/test_item_customization.py` must cover:

- popup handlers created before the custom definition is attached;
- on-demand repair before the handler's next update;
- idempotent repair and bounded failure behavior;
- popup-open rollback and mod-disable keyboard release;
- callback registration before native view initialization;
- repeated legend builds and Name It action restoration;
- name normalization, length limits, colors, resets, immediate card refresh, and popup layout;
- Name It import, synchronization, ownership handoff, read failure, and removal behavior;
- batched gear/character cleanup and retry after a failed settings flush.

Run `tests/verify.ps1` after every change to this module, its settings, localization, layout provider, or popup definitions.
