# Auto Crafter safety audit — 2.0.2

## Enforced invariants

- One BetterInventory account mutation owner across Auto Crafter, automatic/manual discard, and Automatic Curio Buyer.
- One generic Auto Crafter mutation plus its explicitly bounded mastery-upgrade lane; timed-out writes stay quarantined until their original Promise settles.
- Every continuation validates generation, runtime context, active character, and account-operation ownership.
- STOP closes future dispatch immediately but never pretends to cancel an already-sent request.
- Purchases are never repeated when their result is ambiguous; authoritative inventory reconciliation uses the confirmed UUID.
- Inventory reuse requires the selected mark when exact identity exists, excludes equipped gear, respects favorite policy, and resolves equal candidates deterministically.
- Mark selection never mutates existing gear: Auto Crafter acquires/resumes the exact selected mark and dispatches no `switch_mark` request. Melee/ranged mark catalogues fail closed on unresolved, cross-family, cross-slot, duplicate, or missing-template entries. Native external mark switching is account-mutation guarded during active runs.
- Live recipe minimums block provably unaffordable workflows. Backend dockets/material/capacity rejection is terminal and never retried.
- Probe and trait-catalog reads time out after 45 seconds; late callbacks are inert.
- Panel/presentation faults detach the panel. A controller update fault closes the context and disables Auto Crafter until reload instead of escaping into Darktide's frame loop.

## Edge-state coverage

Integration cases include four back-to-back crafts; fresh, partial, level-500, mastery-20, and fully allocated starting states; two-slot swaps; multiple resume candidates; equipped candidates; insufficient dockets/plasteel/diamantine; full inventory; 7-second network stalls; timeout/late settlement; character changes; Brunt closure; loading/Psykanium-style context exit; explicit STOP; and post-purchase visibility delay.

## Installed-mod conflict audit

- `quick_level_mastery` directly purchases, upgrades, extracts mastery, and claims levels. BetterInventory blocks startup while its public Brunt `_purchase_promise` is visible. Its private later queue has no stable public busy signal, so users must not click its Sacrifice action during Auto Crafter.
- `InstantCharacterChange` changes active profile identity. Auto Crafter snapshots the character at each mutation boundary and quarantines in-flight work on mismatch.
- `GlobalStore` reads per-character stores; no competing weapon-crafting mutation was found.
- `MyFavorites` observes favorite changes only; no competing crafting mutation was found.
- `SoloPlay` changes game mode. Auto Crafter exits on non-Morningstar runtime context and retains unresolved mutation ownership until settlement.

No hook was added to block another mod's private UI action: that would couple BetterInventory to unstable internals and create a larger regression surface. Authoritative fail-closed reconciliation remains the compatibility boundary.
