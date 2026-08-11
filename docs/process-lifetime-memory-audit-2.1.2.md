# BetterInventory 2.1.2 process-lifetime memory and idle-CPU audit

## Objective

Extend the view-lifecycle audit to state that can survive a view: backend snapshots, promises and callbacks, crafting controllers, automatic systems, item-derived caches, persistent records, diagnostics, and global update gates. The target is bounded Lua ownership over multi-hour sessions without changing crafting request order or retry semantics.

This document complements `view-lifecycle-memory-audit-2.1.2.md`. A stable Lua heap may retain allocator high-water pages; the failure signal is monotonic retained-object growth after repeating equivalent work and allowing garbage collection, not failure to return to startup RAM immediately.

## Audit method

- Enumerated module-scope tables, registries, caches, promises, closures, view references, backend response graphs, reports, and queues.
- Traced every asynchronous owner through success, rejection, cancellation, timeout, view close, context exit, character change, mod disable, and late settlement.
- Preserved the measured Character Overview CPU invariant: approximately 1.600 ms before the native-update ownership fix and approximately 0.030 ms afterward on Potty's large inventory.
- Compared native vendor, inventory, Hadron, and profile lifecycles with `Content/Darktide-Source-Code`.
- Added harness coverage for repeated release, delayed promises, rejected destructive requests, stale callbacks, and dormant update gates.

## Findings fixed

### Full backend inventory retention

Auto Crafter's backend kept the last authoritative `_raw_gear` response and wallet snapshot after Brunt closed. On a large account this can retain the complete gear graph indefinitely.

`release_read_cache()` now clears both. The controller invokes it on character change, settled view/context exit, and shutdown. It never clears while an operation or auxiliary mutation is in flight, so callbacks retain the authoritative state they require. A request settling after view close performs the deferred release.

### Transient item-derived caches

Quick Look projected modifier values and perfect-roll policy results used weak item keys. Darktide can itself retain item keys in native gear caches, so weak keys alone do not guarantee retirement during a long session.

Both caches now expose explicit reset operations. They are retired when the last Character Overview closes, when generic item-grid views exit or are destroyed, and when the mod is disabled. Per-view sorting priority caches are also cleared during sorting restoration.

### Facade/controller shutdown graph

Auto Crafter shutdown previously left module references to controller, panel, queue/import controllers, runtime context, presentation snapshots, HUD lines, catalogue generation state, and queue-start closures. Shutdown now detaches/cancels safely, clears controller-owned catalogues and purchase confirmation state, then releases the complete facade graph.

### Pending equipment persistence

A native equipment promise that never settled could retain immutable loadout intent forever. Pending persistence now has a 120-second ownership ceiling. Expiry drops BetterInventory's operation without retrying an ambiguous write; a late callback becomes inert through operation identity and generation checks.

This is fail-closed: it prevents retention and duplicate writes, but does not claim the backend write failed.

### Closed-view manual discard

An in-flight manual discard previously kept the complete inventory view reachable until DELETE settlement. Closing the view now detaches only the view reference while preserving the shared mutation owner/token. No competing inventory mutation may start until the native request settles.

### Automatic-discard reads and mutation failures

- Inventory GET/revalidation reads now time out after 45 seconds, are cancelled where supported, and retry only within the existing bounded read-attempt budget.
- A rejected DELETE now releases both the shared transaction and the internal mutation flag atomically. The old path could leave the subsystem permanently busy.
- Once DELETE is dispatched, delayed callbacks retain only gear ID and rarity summaries, not full item records or the authoritative inventory list.
- Ambiguous in-flight DELETE has no local timeout release. Keeping the mutation lock until backend settlement is intentional; unlocking could permit overlapping destructive writes.

### Dormant global updates

Global `mod.update` now enters subsystems only while they own work:

- Character Overview only with registered views;
- marker synchronization only with tracked/dirty grids;
- Auto Crafter only with Brunt presentation, import/queue work, a run, or unsettled controller work;
- customization only with editor/deletion/persistence work;
- equipment persistence only with an active operation;
- automatic discard and Curio acquisition only in supported context or while state is pending/in flight.

Reusable protected-call helpers replace anonymous per-frame closures in Character Overview, MyFavorites synchronization, Auto Crafter field reads, and related contracts. Operation-dispatch closures remain because they belong to one bounded promise chain rather than an idle frame loop.

## Ownership matrix

| State | Maximum/shape | Release contract |
| --- | --- | --- |
| Registered views/grids/sessions | Weak keys plus active views only | `on_exit`, `destroy`, mod disable; idempotent |
| Quick Look/perfect-roll cache | Items touched by current UI ownership interval | Last overview/grid close or mod disable |
| Sorting priority cache | Current view layout entries | Sorting restore/view teardown |
| Auto Crafter raw gear | One latest authoritative response | Settled view/context exit, character change, shutdown |
| Auto Crafter queue | At most melee+ranged jobs | Queue clear/context exit/shutdown |
| Games Lantern import | One current build/model and bounded choices | Replacement, clear, context exit, shutdown |
| Equipment persistence | One immutable intent | Success, rejection, bounded retry exhaustion, 120 s ceiling, reset |
| Manual discard | One owner/token and native settlement | Settlement; closed view detached immediately |
| Automatic discard read | One cancellable read | Settlement, cancellation, 45 s timeout |
| Automatic discard DELETE | Compact IDs/rarities and one mutation lock | Backend settlement or explicit native rejection |
| Curio read work | Generation-owned cancellable requests | Settlement, context cancellation, disable |
| Curio history/reports | Four accounts, eight reports, eight compact items/report | Sanitized replacement/pruning |
| Curio profiles | Native operative capacity, capped at 64 | Reconciled replacement/context cancellation |
| Diagnostics | Fixed-name counters and samples | Disable/reset |
| Custom names/colors | User-authored records keyed by gear ID | Gear/character deletion hooks or user removal |

## Intentional persistent state

The following is not treated as a leak:

- user settings and valid item customization records;
- a staged two-weapon Games Lantern queue;
- an active Auto Crafter run after Brunt closes;
- bounded Curio rotation history and undelivered compact reports;
- one destructive mutation lock awaiting an already-dispatched backend request;
- native MasterItems/catalogue data owned by Darktide.

None may retain a closed view, grid, widget, renderer, popup handler, full inventory response, or superseded promise graph.

## Regression coverage

- `test_view_session.py` and `test_feature_domains.py`: 250-cycle registry cleanup and zero retained owners.
- `test_view_lifecycle_memory.py`: explicit lifecycle hooks, cache retirement, shutdown release, idle gates, and prohibition on shared native update/draw wrappers.
- `test_equipment_persistence.py`: never-settling promise ceiling, no ambiguous retry, detached view, inert late settlement.
- `test_operation_arbiter.py`: view detachment preserves mutation owner/token until settlement.
- `test_features.py`: manual-discard detachment, automatic-read timeout/cancellation, rejected DELETE recovery, and unsupported-context dormancy.
- `test_auto_crafter_backend.py`: full read-cache release and idempotency.
- `test_curio_acquisition.py`: disabled/unsupported-context dormancy while hub and pending work still wake correctly.

## Long-session live soak

Run with both a minimal mod list and Potty's compatibility list:

1. Record `collectgarbage("count")`, BetterInventory self CPU, and active-operation diagnostics at baseline.
2. Repeat 50 cycles each: Character Overview tabs; melee/ranged/Curio inventory; stores; Hadron; Brunt; Social; Talents; Cosmetics; Party Finder.
3. Paste/replace/clear the same Games Lantern build 50 times, then close Brunt.
4. Start and stop Auto Crafter at read-only and mutation boundaries; close/reopen Brunt during a request.
5. Simulate unresolved/rejected inventory reads and DELETE/equipment promises, then allow settlement.
6. Change character through native selection and InstantCharacterChange, then repeat the view cycle.
7. Wait through several Curio/automatic-discard idle polling intervals and one store rotation boundary.
8. Compare settled memory after equivalent garbage-collection intervals.

Pass conditions:

- no retained-memory slope proportional to cycles, imports, or inventory size after settling;
- no growth in registered view/grid/session counts or active promise counts;
- no full gear response remains after settled Brunt/context close;
- no idle subsystem runs in unsupported views/contexts;
- no duplicated panels, widgets, hooks, notifications, or mutation owners;
- crafting, discard, Curio purchase, and equipment writes remain serialized and preserve existing request order.

## Conclusion

The second pass found actionable retention in backend inventory snapshots, transient item caches, facade shutdown, never-settling equipment writes, closed-view manual discard, and automatic-discard failure/read paths. These now have explicit bounded ownership. No additional unbounded BetterInventory-owned collection was found. Final engine-level proof remains the live soak above because Lua and the engine allocator can retain reusable high-water memory without a source-level leak.
