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
- BetterInventory still installed safe hooks on every `ViewElementGrid.update`, the shared `ConstantElementPopupHandler.update`, and `InventoryView.update`. Darktide's `ViewElementGrid.update` advances grids, updates every grid widget, and reconciles visibility; its popup handler also owns all popup lifecycle/drawing work. Hook profilers could therefore charge unrelated Social, Talents, Party Finder, and Character Overview native work to BetterInventory.
- Potty's captures matched this ownership leak: BetterInventory call counts changed with each view's number of grids (`3` Social, `6` Party Finder, `8` Character Overview), despite no BetterInventory feature needing those views.

## Behavior-preserving changes

- Controller mutation, timeout, mastery polling, blessing polling, and stop-generation guards remain frame-driven.
- Auto Crafter presentation is event-driven. Active elapsed-time presentation refreshes at 4 Hz; controller events refresh immediately.
- Detached panel work exits immediately. Stable Brunt selection, layout pivot, and idle controller reconciliation run at 10 Hz; pending selection and deferred layout work remain immediate.
- Empty customization deletion queues no longer allocate replacement tables. Pending deletion and persistence work still runs on the next frame.
- Disabled, settled Automatic Discard and Automatic Curio Buyer now sleep. Setting changes, lifecycle transitions, pending reads, pending reports, scheduled work, and active transactions wake their existing update paths.
- Manual discard reconciliation runs only while a discard owner exists. Diagnostics use cached setting state and run only while explicitly enabled.
- Inventory and vendor-specific work still uses narrow post-native hooks. Controller input capture remains before native `_handle_input`, preserving same-frame focus behavior.
- BetterInventory no longer hooks global `ViewElementGrid.update`, `InventoryView.update`, or `ConstantElementPopupHandler.update`. One mod-owned frame update processes only weakly registered Character Overview views and dirty MyFavorites grids. Name-editor input repair occurs only when the editor opens.
- MyFavorites marker alignment is dirty/generation driven. Hidden grids perform zero card scans; generationless fallback reconciliation is bounded to once per second without entering unrelated grids.
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
- Unregistered grids from Social, Talents, Party Finder, or other mods perform zero BetterInventory marker callbacks.

## Potty mod-list audit

- `ScanHelper` occurs twice. This exactly explains DMF's duplicate-name startup error for `ScanHelper`.
- `outline_colours` occurs twice. This exactly explains DMF's duplicate-name startup error for `outline_colours`.
- Remove the second occurrence of both names from `Potty_mod_load_order.txt`. Duplicate registration can leave uncertain hook/load state and invalidates performance comparisons.
- `InspectFromSocial` and `InspectFromPartyFinder` both add their own view-specific `update` hooks and can open read-only `inventory_background_view` instances. They do not directly call BetterInventory, but they share the inspected `InventoryView` path. BetterInventory now keeps that integration to five loadout cards through a weak registered-view pass instead of wrapping the complete inspected view update.
- `OpenPlayerProfile`, `who_are_you`, `BetterLoadouts`, `LoadoutNames`, and several Talent UI mods were listed but unavailable in this installation, so no source-level conflict claim is made. Retest after duplicate cleanup; disable inspect/profile mods one at a time only if residual cost remains.

## Source contracts checked

- Darktide 1.12.3 source: `scripts/ui/view_elements/view_element_grid/view_element_grid.lua:312` shows global grid update owns grid input, widget updates, scroll state, visibility, and base update.
- Darktide 1.12.3 source: `scripts/ui/views/inventory_view/inventory_view.lua:1305` shows Character Overview/Talents share substantial native inventory-view update work.
- Darktide 1.12.3 source: `scripts/ui/constant_elements/elements/popup_handler/constant_element_popup_handler.lua:965` shows popup update is a global constant-element lifecycle, not a name-editor-only path.
