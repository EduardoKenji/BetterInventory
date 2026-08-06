# Inventory options container research spike

Date: 2026-08-03 (historical design spike)
Branch: `research/inventory-options-container`

Status: implemented on `main` for v1.7.2. The inventory options panel is enabled by default, retains the loose-widget path as a guarded fallback, and remains subject to in-game input and resolution validation.

## Outcome

All three proposed capabilities are technically feasible:

| Capability | Feasible? | Recommended implementation |
| --- | --- | --- |
| Bounded options rectangle | Yes | A nested `ViewElementGrid` with Darktide's terminal background and dividers. |
| Scrollable options | Yes | Move the option rows into that element so its managed render target and mask clip the content correctly. |
| Collapsible sections | Yes | Clickable header rows rebuild the visible grid layout with the collapsed section's child rows omitted. |

The important constraint is that scrolling cannot be added safely by drawing a scrollbar beside the current root-level widgets. Those widgets are rendered by `InventoryWeaponsView` directly and have no clipping boundary. Moving them without a managed masked renderer would let rows draw outside the rectangle.

## Prototype status

The implementation described by this spike was carried into `main` behind `enable_inventory_options_panel_prototype`, which is enabled by default in v1.7.2. It:

- creates one `ViewElementGrid` through the inventory view's managed element lifecycle;
- uses a terminal background, native mask and scrollbar;
- migrates all current synchronized Sorting and discard controls into custom grid rows;
- caps the panel at 320 reference pixels so the full expanded discard section scrolls;
- shrinks the bounded panel when sections collapse;
- stores collapse state locally per live inventory view;
- presents only Sorting while Darktide's native discard UI is active;
- preserves the existing loose widgets and restores them if initialization or positioning fails.

The remaining work is in-game validation of the render target, mouse-wheel ownership, controller navigation, every inventory slot, native discard transitions, hot reload and the supported resolution matrix.

## Existing BetterInventory UI

The current controls are injected as individual scenegraph nodes by `Features.add_inventory_sort_toggle_definition` in `BetterInventory_features.lua`. They are parented to either `weapon_compare_stats_pivot` for weapons or `weapon_stats_pivot` for Curios and are positioned by fixed offsets.

`Features.update_inventory_sort_toggle` already solves the difficult placement cases:

- below the dynamically sized Curio details card;
- below Marks/Cosmetics/Inspect for weapons;
- to the left of Darktide's native discard panel while that panel is open;
- with only Sorting visible during the native discard workflow.

That positioning logic should be retained. The migration changes the thing being positioned from many independent widgets to one panel element.

## Native Darktide support

Darktide already uses the required component in the same view. `InventoryWeaponsView._setup_weapon_options` creates the Marks/Cosmetics/Inspect block through `ViewElementGrid`, presents a layout, and moves the complete element with `set_pivot_offset`. This is a stronger compatibility signal than introducing a custom renderer.

Relevant source contracts in the local Darktide 1.12.3 snapshot:

- `scripts/ui/views/base_view.lua:649` — `_add_element` registers an element with the parent view and its managed lifecycle.
- `scripts/ui/views/inventory_weapons_view/inventory_weapons_view.lua:975` — the native weapon-options setup.
- `scripts/ui/views/inventory_weapons_view/inventory_weapons_view.lua:1002` — the view creates its own `ViewElementGrid`.
- `scripts/ui/view_elements/view_element_grid/view_element_grid.lua:822` — `present_grid_layout` accepts a layout and arbitrary content blueprints.
- `scripts/ui/view_elements/view_element_grid/view_element_grid.lua:844` — layout changes create or update the grid entries.
- `scripts/ui/view_elements/view_element_grid/view_element_grid.lua:938` — the grid assigns its native scrollbar.
- `scripts/ui/view_elements/view_element_grid/view_element_grid.lua:476` — the element composites its masked render target back to the screen.
- `scripts/ui/view_elements/view_element_grid/view_element_grid.lua:1369` — the element releases grid widgets, renderers, resources and its viewport during destruction.
- `scripts/ui/view_elements/view_element_grid/view_element_grid_definitions.lua:170` — native scrollbar scenegraph node.
- `scripts/ui/view_elements/view_element_grid/view_element_grid_definitions.lua:177` — native masked viewport node.
- `scripts/ui/view_elements/view_element_grid/view_element_grid_definitions.lua:318` — optional terminal background.

## Recommended panel architecture

Create one BetterInventory-owned `ViewElementGrid` per live `InventoryWeaponsView`:

```text
BetterInventory options panel
├─ Sorting header                         [collapse/expand]
│  └─ Equipped and favorited items...    [checkbox]
└─ Manual/Automated Item Discard...      [collapse/expand]
   ├─ Mode + Skip confirmation            [composite row]
   ├─ Rarity + action button              [composite row]
   ├─ Maximum item level                  [stepper]
   ├─ Melee / Ranged / Curios             [checkbox row]
   ├─ Perfect-roll protection             [checkbox]
   ├─ High-level Curio protection         [checkbox]
   └─ Curio protection level              [stepper]
```

Use custom row blueprints because several existing rows are compact composites rather than the full-width widgets from Darktide's Options view. Each blueprint can keep the current pass templates, content, setting callbacks and disabled-state behavior.

The panel should be created once after the inventory view has initialized, registered through `view:_add_element`, and destroyed by the view's normal element lifecycle. It must not be recreated during `update`.

### Panel geometry

Suggested reference-canvas values:

- weapon width: 420 px;
- Curio width: 420 px even though the details region is 530 px, matching the current compact control column;
- maximum visible height: 360 px initially;
- minimum visible height: the sum of currently visible rows, capped by the maximum;
- scrollbar width: 7 px;
- edge padding: 12–16 px;
- terminal background: enabled;
- title height: zero because section headers live inside the scrollable content.

The existing base-position calculation becomes the panel pivot. Available height should be clamped against the 1080 px reference canvas's safe bottom margin. At lower resolutions the scale remains native, while the logical height clamp ensures the panel does not collide with the footer.

## Scrolling behavior

Scrolling should be automatic only when the content height exceeds the panel's current mask height. `ViewElementGrid` already provides:

- a managed render target and mask;
- native scrollbar assignment;
- pointer hover detection for the grid interaction area;
- mouse-wheel and gamepad scrolling support;
- widget visibility and resource lifecycle management.

The panel should consume wheel input only while its interaction mask is hovered. Otherwise the inventory item grid must retain scrolling. This needs an in-game mouse and controller test because both grids are live in the same view.

Rebuild the layout only when one of these changes:

- a section is collapsed or expanded;
- Manual/Automatic mode changes and the conditional confirmation control appears or disappears;
- experimental discard management is enabled or disabled;
- Darktide enters or exits its native discard workflow;
- a setting mutation changes which rows are applicable.

Ordinary per-frame updates should synchronize widget values without recreating grid entries.

## Collapsible sections

Darktide does not expose a general-purpose collapsible header behavior for this view, but custom `ViewElementGrid` blueprints can implement it safely:

1. Give each section header a hotspot and a chevron.
2. Store `collapsed` state outside the generated widget.
3. On activation, toggle the state and rebuild the layout.
4. Omit child rows belonging to a collapsed section.
5. Recalculate the panel height and clamp scrollbar progress.

Recommended initial state:

- Sorting: expanded;
- Item Discard Management: expanded while the experimental feature is enabled;
- native discard workflow: only Sorting exists, preserving today's behavior.

Collapse state remains session-local to the live view. Persisting it is intentionally deferred so a broken or off-screen layout can recover when the view is reopened.

DMF's mod-options screen has its own persisted collapsed-widget machinery, but that implementation is specific to DMF's options data model and should not be copied into the inventory view. Only its state-management pattern is relevant.

## Synchronization and safety

The panel remains a second presentation of the existing settings, not a second source of truth. Every action should continue to call `mod:set`; existing `Features.sync_inventory_sort_setting` and `Features.sync_quick_discard_settings` then update all live inventories and the mod-options page.

The discard pipeline, candidate evaluation, confirmation dialog and backend calls do not need to change. This spike is a presentation refactor only.

When Darktide's native discard panel is active:

- do not present the Item Discard Management section;
- show the Sorting section only;
- position the bounded panel using the current native-discard offset;
- keep its height small enough not to overlap the selected weapon details or Darktide's discard filter panel.

## Risks and test gates

Remaining v1.7.2 in-game regression gates are:

1. Mouse wheel scrolls the options only while the pointer is over the panel.
2. Inventory scrolling still works normally outside it.
3. Controller focus can enter, operate and leave the panel without trapping navigation.
4. Collapse/expand preserves every setting value and does not trigger actions.
5. The destructive discard button cannot be activated while clipped or hidden.
6. Automatic-mode conditional rows do not leave blank layout gaps.
7. Native discard mode shows Sorting only and restores the complete panel on ESC.
8. Melee, ranged and all three Curio slots position the panel correctly.
9. `1600x900`, `1920x1080`, `1920x1200`, `2560x1440` and `3840x2160` keep the panel within the safe canvas.
10. Repeated entry/exit and `Ctrl+Shift+R` do not retain an orphan renderer, viewport or widget.

## Historical implementation sequence

1. Add a dedicated `BetterInventory_inventory_options_panel.lua` module and custom row blueprints.
2. Add a default-off research switch so the existing UI remains the fallback during in-game validation.
3. Create the element once through `_add_element` and reuse the current pivot calculations.
4. Present Sorting first, then migrate discard rows without changing their callbacks.
5. Add bounded geometry and dynamic height.
6. Add scrolling and verify input ownership.
7. Add collapsible header blueprints and local collapse state.
8. After the test matrix passes, remove the legacy root-widget path and the research switch.

## Decision

The spike's decision was to proceed with a guarded `ViewElementGrid` prototype. That prototype is now part of the v1.7.2 implementation: it provides the bounded rectangle, clipping, scrollbar and lifecycle while preserving BetterInventory's existing settings and discard safety logic.
