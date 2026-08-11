# BetterInventory frame CPU audit

## Observed hot paths

- Auto Crafter rebuilt a full controller snapshot and HUD text every frame, including missions and idle Morningstar sessions.
- Detached Auto Crafter panel still entered its update path every frame. Attached Brunt panel duplicated selected-offer and pivot checks every frame.
- Idle Brunt controller rebuilt planner configuration and inspected native selection every frame.
- Item customization replaced an empty deleted-gear queue with a new table every frame.
- Disabled Automatic Discard and Automatic Curio Buyer still entered their full update paths every frame.
- Opt-in hot-path diagnostics re-read their setting every frame even while disabled.
- BetterInventory wrapped Darktide's complete `InventoryWeaponsView.update`, `CreditsVendorView.update`, and `ViewElementGrid._update_grid_widgets` methods. This both added work on native O(inventory) paths and made hook-based performance monitors attribute the enclosed native traversal to BetterInventory.
- Character Overview weapon/Curio blueprints called their native update callback every stable frame even though those callbacks only mutate content after an equipped-item identity change.
- Character Overview revisited unchanged Curio fitting and equipped-marker state every frame. Large retained/hidden inventories amplified the apparent BetterInventory cost.

## Behavior-preserving changes

- Controller mutation, timeout, mastery polling, blessing polling, and stop-generation guards remain frame-driven.
- Auto Crafter presentation is event-driven. Active elapsed-time presentation refreshes at 4 Hz; controller events refresh immediately.
- Detached panel work exits immediately. Stable Brunt selection, layout pivot, and idle controller reconciliation run at 10 Hz; pending selection and deferred layout work remain immediate.
- Empty customization deletion queues no longer allocate replacement tables. Pending deletion and persistence work still runs on the next frame.
- Disabled, settled Automatic Discard and Automatic Curio Buyer now sleep. Setting changes, lifecycle transitions, pending reads, pending reports, scheduled work, and active transactions wake their existing update paths.
- Manual discard reconciliation runs only while a discard owner exists. Diagnostics use cached setting state and run only while explicitly enabled.
- Inventory, vendor, and grid work now uses post-native safe hooks. Controller input capture remains before native `_handle_input`, preserving same-frame focus behavior without wrapping the full update.
- MyFavorites marker alignment is dirty/generation driven after native grid update. Hidden grids perform zero card scans; generationless fallback reconciliation is bounded to once per 60 visible frames.
- Stable Character Overview cards do not re-enter native item-slot update, text fitting, or equipped-marker loops. Curio transition polling is bounded to 4 Hz and equipped-marker synchronization runs only when widgets, Lantern state, or content become dirty.
- Settled automatic discard identity polling is bounded to 4 Hz; scheduled and in-flight work remains frame-driven.
- Card content caches weapon/Curio kind, and blueprint visibility functions consume those cached booleans instead of repeatedly resolving item type.

## Validation invariants

- No backend request ordering, retry limit, timeout, cap, projection, reconciliation, or cleanup behavior changed.
- Active operation elapsed accounting remains per-frame.
- Selection/configuration changes are reconciled within 100 ms while idle; Craft start still performs authoritative preflight and freezes current target before mutation.
- Background gates cannot suppress in-flight backend settlement, retries, cancellation cleanup, persisted Curio reports, or first ledger hydration.
- Full behavior suite must pass before installation synchronization.
- High-cardinality regression coverage constructs 1,000 tracked cards and proves a hidden dirty grid performs zero BetterInventory per-card calls, then exactly one repair pass when visible.
