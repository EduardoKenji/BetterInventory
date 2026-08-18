# Deferred Games Lantern multi-import queue

Status: design only; intentionally deferred after v2.8.0. No runtime behavior changes are authorized by this document.

## Goal

Allow repeated Games Lantern pastes to append independent weapon batches instead of treating the current build URL as already staged. A two-weapon build pasted three times would produce six ordered cards. Clear Queue would remove every staged batch.

## Proposed limits and rules

- Cap the queue at six cards (three complete two-weapon builds).
- Preserve duplicate jobs intentionally. Every paste and every card needs a new internal identity even when its build URL, weapon, stats, perks, and blessings match an existing card.
- Append a build atomically: either all resolved cards fit and are added, or the existing queue remains unchanged.
- Accept paste only while the queue is staged. Never append during starting, active, stopping, quarantined, reconciliation-required, or terminal-settlement states.
- Preserve paste order and each build's melee-before-ranged order. Removing one card must not reorder the survivors.
- Recompute aggregate cost authority after every append or removal. Craft confirmation must be invalidated whenever that authority changes.
- Keep Clear Queue as the single full reset, including all build provenance, selected-card state, confirmation state, and cached import presentation.

## Safety work required before implementation

- Add rising-edge/debounce coverage so one Ctrl+V press cannot append the same clipboard payload twice through multiple input routes or frames.
- Separate deliberate duplicate imports from accidental callback replay, late HTTP completion, and retry completion.
- Give each import attempt a generation token; late resolution from a cleared, replaced, interrupted, or character-switched queue must become inert.
- Prove queue ownership and stop behavior across Psych Ward/Morningstar transitions for all six card boundaries.
- Test partial removal, repeated identical imports, capacity rejection, failed second/third imports, clear during import, resource-authority refresh, resume/skip behavior, and serial completion of duplicate weapons.
- Keep runtime and persistence bounded. Staged multi-build queues should remain session-local until a separate persistence contract is designed and tested.

Until these invariants have dedicated coverage, BetterInventory keeps the v2.8.0 single-build queue contract.
