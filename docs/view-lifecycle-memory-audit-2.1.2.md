# BetterInventory 2.1.2 view-lifecycle and retained-memory audit

## Objective

Prove that repeatedly opening and closing inventory-related views does not grow BetterInventory-owned view registries, retain closed views through module globals, or duplicate UI elements. Scope includes Character Overview, melee/ranged/Curio inventory, Requisition, Global Store, Brunt's Armoury, and Hadron's Entreat view.

This audit preserves the 2.1.0 post-draw/update CPU fix. Lifecycle cleanup must use `on_exit`, `destroy`, weak registries, and explicit module release functions. It must not wrap a shared native `draw` or `update` chain. Potty's measured Character Overview cost fell from about 1.600 ms to 0.030 ms after that fix, making this a release invariant.

## Method

The pass combined:

- ownership review of every module-level table or value that can reference a view, grid, widget, element, callback, promise, queue, or operation;
- comparison with Darktide lifecycle contracts in the local source checkout;
- explicit normal-exit and abnormal-destroy cleanup paths;
- idempotency review for views that receive both callbacks;
- 250-cycle Lua-harness tests for view sessions and marker grids;
- static regression checks that all covered view classes have lifecycle release hooks and no shared update/draw ownership returned;
- full repository verification and archive/runtime synchronization before handoff.

This is a source and harness audit. Final proof of engine allocator behavior still requires a live repeated-open soak while observing Lua memory after garbage collection. A stable Lua heap can retain a high-water allocation without being a leak; the criterion is unbounded growth over repeated identical cycles, not whether memory immediately returns to process startup.

## Darktide lifecycle contracts checked

Source root: `Content/Darktide-Source-Code`.

| Native view | Contract | BetterInventory consequence |
| --- | --- | --- |
| `ItemGridViewBase` | `on_exit` is empty; `destroy` destroys elements and clears grids/renderers. | Release marker/grid metadata at both `on_exit` and `destroy`; do not depend on native `on_exit` for module state. |
| `InventoryWeaponsView` | `on_exit` cancels `_store_promise`, destroys world spawner, and delegates to the base lifecycle. | Native store work is already cancelled. Release BetterInventory options, Lantern section, sort/session state, and grid metadata. |
| `InventoryView` | `on_exit` removes item stats, destroys loadout/grid widgets and offscreen GUI, closes child weapon inventory, then calls the super lifecycle. | Explicitly unregister Character Overview from BetterInventory's frame registry on exit and destroy. |
| `InventoryBackgroundView` | `on_exit` first persists local equipment changes, then unloads icons and destroys active child/world/profile resources. | Drop the closed view from BetterInventory's pending persistence operation after native persistence captures immutable intent. Keep backend settlement independent of the view. |
| `CraftingMechanicusModifyView` | `on_exit` cancels `_inventory_promise` before calling the super lifecycle. | No BetterInventory promise cancellation is needed for Hadron; generic item-grid release handles module-owned metadata. |
| `VendorViewBase` | `destroy` deletes its `PromiseContainer`; list refresh also cancels `_store_promise`. | Requisition, Global Store, and Brunt native request ownership remains native. BetterInventory releases only panels, grids, snapshots, and active-view references. |
| `CreditsGoodsVendorView` | Inherits vendor lifecycle and owns Brunt presentation/update behavior. | Auto Crafter facade must detach Brunt presentation on both normal exit and destroy without cancelling a background crafting run. |

Relevant source locations:

- `scripts/ui/views/item_grid_view_base/item_grid_view_base.lua:647`
- `scripts/ui/views/inventory_weapons_view/inventory_weapons_view.lua:857`
- `scripts/ui/views/inventory_view/inventory_view.lua:313`
- `scripts/ui/views/inventory_background_view/inventory_background_view.lua:2392`
- `scripts/ui/views/crafting_mechanicus_modify_view/crafting_mechanicus_modify_view.lua:377`
- `scripts/ui/views/vendor_view_base/vendor_view_base.lua:178`

## Ownership findings and fixes

### View sessions

`BetterInventory_view_session.lua` used weak view keys but each session value also stored its key as `session.view`. That key-value cycle could keep a view alive despite the weak-key registry. The back-reference is removed. Closing now clears callbacks, cleanup order, and field snapshots immediately.

Close is reentrancy-safe: a cleanup callback may open a replacement session for the same view, and completion of the old close will not erase that new owner. `close_all` provides deterministic mod-disable cleanup.

### Character Overview

The registered-view table already used weak keys, but cleanup previously relied on `_destroyed` being observed by a later frame update. Explicit `InventoryView.on_exit` and `destroy` hooks now unregister immediately and clear BetterInventory widget/reconciliation caches.

This cleanup does not reintroduce `InventoryView.update` ownership. Character Overview still uses the dedicated weak registry and dirty/bounded update path that produced Potty's performance improvement.

### Inventory options and Armoury sort panels

Inventory and vendor views held references to BetterInventory elements, widget tables, controller legends, focus-restore snapshots, geometry, and composition state. Native teardown would eventually discard the parent view, but these fields and registered-view entries were not explicitly released.

Release functions now:

- restore controller focus only when BetterInventory owns it;
- remove BetterInventory legend entries and elements through guarded calls;
- clear widget, panel, layout, geometry, signature, and restore-state fields;
- unregister the view;
- tolerate duplicate `on_exit`/`destroy` calls.

### MyFavorites marker grids

Tracked and dirty grid registries were weak-key tables, but closed grid metadata was retained until polling or garbage collection. `release_grid` clears registry entries and all marker widget/generation fields immediately. `release_all` handles mod disable. Polling now routes inactive grids through the same release function.

### Brunt Auto Crafter presentation

The facade retained `active_brunt_view` and panel view references until a later controller/context event. Brunt now calls `AutoCrafter.on_view_closed` on both `on_exit` and `destroy`. Panel detach clears view, element, widget, snapshot, and queue-presentation references while the controller's background workflow remains unchanged.

A stale close from an old Brunt instance cannot clear a newer active view. Duplicate exit/destroy calls are no-ops after the first release.

### Equipment persistence

Character Overview equipment persistence stored the originating `InventoryBackgroundView` while a backend request or bounded retry was pending. Native `on_exit` must run first because it captures local equipment changes. BetterInventory's post-exit hook then removes only the optional UI-cache target from the operation.

Immutable account/character/slot intent remains available for backend settlement and retry. Late success cannot mutate a closed view. Mod disable invalidates the generation and clears active operation state.

### Custom-name popup

The editor cached an input widget owned by `ConstantElementPopupHandler`. If the handler disappeared, resolution could leave the stale widget in a module global. Missing handlers now clear the cache. Inventory exit clears pending editor action, closes input, and drops the widget reference.

### Status overlays and generic grids

`ItemGridViewBase.on_exit` and `destroy` clear BetterInventory marker metadata and `_auto_crafter_status_overlay`. This covers Hadron and vendor subclasses without owning their frame traversal.

## View matrix

| Repeated view | BetterInventory-owned state | Normal release | Fallback | Native async cleanup |
| --- | --- | --- | --- | --- |
| Character Overview | weak registered view; card/reconcile caches | `InventoryView.on_exit` | `InventoryView.destroy`, mod disable | native widget/offscreen cleanup |
| Melee/ranged/Curio inventory | options panel; sort/session state; markers; editor widget | `InventoryWeaponsView.on_exit` | `destroy`, generic grid destroy, mod disable | `_store_promise:cancel()` |
| Requisition / Global Store | Armoury sort panel; controller legend; markers | `CreditsVendorView.on_exit` | `destroy`, generic grid destroy | vendor `PromiseContainer:delete()` |
| Brunt's Armoury | active facade view; Auto Crafter panel; overlay; queue presentation | `CreditsGoodsVendorView.on_exit` | `destroy`, generic grid destroy | vendor `PromiseContainer:delete()` |
| Hadron Entreat | expanded-grid marker/overlay metadata | generic `ItemGridViewBase.on_exit` | generic grid destroy | `_inventory_promise:cancel()` |
| Character Overview parent | optional equipment-persistence view target | `InventoryBackgroundView.on_exit` | `destroy`, mod disable | BetterInventory observes native persistence promise |

## State intentionally retained across view close

These bounded values are product state, not leaks:

- Auto Crafter controller/run state while a background crafting run is active;
- at most the currently staged Games Lantern queue/import model;
- persistent item-name/color settings and user configuration;
- bounded operation reports, diagnostics counters, and account-scoped Curio state;
- immutable equipment intent only while a backend write or bounded retry remains active.

None should retain a closed view, grid, widget, renderer, element, or popup handler.

## Regression coverage

- `test_view_session.py`: 250 open/close cycles return session count to zero; tests cleanup idempotency, ownership-preserving restore, reentrant replacement, and bulk close.
- `test_feature_domains.py`: 250 grid track/dirty/release cycles return both marker registries to zero; tests bulk release and unrelated-grid isolation.
- `test_equipment_persistence.py`: closed view is detached from pending operation; late settlement is UI-neutral; reset invalidates pending state.
- `test_features.py`: inventory/Armoury panel teardown clears element/widget/layout references and legend ownership.
- `test_view_lifecycle_memory.py`: all covered classes expose exit/destroy cleanup, disable cleanup exists, weak ownership cycle is absent, native promise cleanup contracts remain present when source is available, and shared update-chain ownership remains forbidden.
- `test_auto_crafter_viewport.py`: no normal wrapping hook owns shared native draw work.

## Live validation matrix

Run each row for at least 50 cycles in one session. Record Lua memory after opening, after closing, and after a garbage-collection settling interval. Also record BetterInventory self CPU while closed.

1. Character Overview -> melee inventory -> back -> ranged inventory -> back -> Curios -> back -> close overview.
2. Armoury -> Requisition -> close, then Global Store -> close.
3. Brunt -> switch weapon category/selection -> close while idle.
4. Brunt -> start Auto Crafter -> close Brunt while request is active -> let run settle -> reopen Brunt.
5. Hadron Entreat -> switch item/category -> close.
6. Open custom-name editor -> close inventory without submitting -> reopen.
7. Change loadout in Character Overview -> close during normal latency and during simulated delayed settlement -> reopen.
8. Repeat with inspect/profile/BetterLoadouts compatibility mods enabled, then compare against a minimal mod list.

Pass conditions:

- no monotonic Lua-memory growth proportional to cycle count after settling;
- no growth in BetterInventory session, marker, or registered Character Overview counts;
- no duplicated panels, legends, queue cards, overlays, or popup inputs;
- no stale view receives a late equipment/UI update;
- Auto Crafter background behavior and stop/resume invariants remain unchanged;
- unrelated views remain near Potty's corrected approximately 0.030 ms BetterInventory self time rather than inheriting native draw/update cost.

## Conclusion

Source-level retained-view gaps found in sessions, Character Overview registration, panels, marker grids, Brunt presentation, equipment persistence, and popup widgets now have explicit cleanup. Native store/Hadron requests already own cancellation/destruction. No workflow request ordering, crafting mutation, retry, or queue behavior changed. Remaining release evidence is live allocator soak data, not another known code gap.
