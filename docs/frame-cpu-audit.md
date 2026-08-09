# BetterInventory frame CPU audit

## Observed hot paths

- Auto Crafter rebuilt a full controller snapshot and HUD text every frame, including missions and idle Morningstar sessions.
- Detached Auto Crafter panel still entered its update path every frame. Attached Brunt panel duplicated selected-offer and pivot checks every frame.
- Idle Brunt controller rebuilt planner configuration and inspected native selection every frame.
- Item customization replaced an empty deleted-gear queue with a new table every frame.
- Disabled Automatic Discard and Automatic Curio Buyer still entered their full update paths every frame.
- Opt-in hot-path diagnostics re-read their setting every frame even while disabled.

## Behavior-preserving changes

- Controller mutation, timeout, mastery polling, blessing polling, and stop-generation guards remain frame-driven.
- Auto Crafter presentation is event-driven. Active elapsed-time presentation refreshes at 4 Hz; controller events refresh immediately.
- Detached panel work exits immediately. Stable Brunt selection, layout pivot, and idle controller reconciliation run at 10 Hz; pending selection and deferred layout work remain immediate.
- Empty customization deletion queues no longer allocate replacement tables. Pending deletion and persistence work still runs on the next frame.
- Disabled, settled Automatic Discard and Automatic Curio Buyer now sleep. Setting changes, lifecycle transitions, pending reads, pending reports, scheduled work, and active transactions wake their existing update paths.
- Manual discard reconciliation runs only while a discard owner exists. Diagnostics use cached setting state and run only while explicitly enabled.

## Validation invariants

- No backend request ordering, retry limit, timeout, cap, projection, reconciliation, or cleanup behavior changed.
- Active operation elapsed accounting remains per-frame.
- Selection/configuration changes are reconciled within 100 ms while idle; Craft start still performs authoritative preflight and freezes current target before mutation.
- Background gates cannot suppress in-flight backend settlement, retries, cancellation cleanup, persisted Curio reports, or first ledger hydration.
- Full behavior suite must pass before installation synchronization.
