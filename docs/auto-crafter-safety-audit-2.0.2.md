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

## 2.1 imported-queue re-audit (2026-08-11)

Darktide source contracts were rechecked against `backend/crafting.lua`, `crafting_service.lua`, `crafting_mechanicus_settings.lua`, `gear_service.lua`, and mastery services. Native crafting uses one-based service slots and converts to zero-based backend slots; duplicate/wasteful trait replacements are invalid. Auto Crafter therefore keeps all requests serial, validates complete request shape before dispatch, never retries ambiguous mutations, and confirms authoritative gear after every write.

Additional enforced rules:

- Completed imported jobs are detected only from a fresh current-character inventory/catalogue boundary. Mastery family, level-500 potential dump stat, enabled rarity/expertise, set-equivalent perks/blessings, mastery level 20 with claimed level 19, and fully allocated blessing tiers must all match.
- Favorite, unfavorite, equipped, and mark state do not hide a completed family-equivalent weapon because skipping is read-only and marks can be changed without crafting cost.
- Mutable in-progress resume still excludes equipped gear and respects `Include favorited inventory weapons when resuming`. Every mark in the same mastery family is an equivalent resume base.
- An incomplete resumable family weapon always wins over completion skipping. If none exists, completed queued weapons are skipped by default; `Craft duplicates of already completed queued weapons` instead forces a fresh Brunt purchase.
- Completed queue prefix is revalidated from the next job's fresh snapshot before any next-job mutation. Removed, discarded, mark-changed, or trait-changed prior gear blocks continuation.
- Phase 4 now rechecks family, dump stat, rarity, expertise, perk/blessing sets, mastery allocation, and requested favorite state before reporting terminal success.
- Malformed expertise, discard, rarity-batch, mastery-allocation, and mastery-extraction arguments reject locally before Darktide service dispatch. Duplicate IDs/operations, empty IDs, non-finite levels, and out-of-range tiers are no-ops with normal Auto Crafter failure logging.

Automated evidence: 29 behavior scripts / 113 named cases. Live Darktide validation remains required; automated tests cannot prove backend availability, real account balances, or third-party mod runtime behavior.

## 2.1.0 P0 mutation and character-switch re-audit (2026-08-11)

The supplied 2.0.3 crash log proves two separate defects rather than one generic backend failure:

- The weapon was authoritatively item level 500 before `phase4_replace_perk`, but the rejected request omitted `traitTier`. The old no-cost argument left a nil vararg hole before the trailing tier. The backend now packs/unpacks exact arity and passes an explicit `false` cost sentinel, so the native perk signature remains `(gear, slot, target, costs, tier)` through every hook.
- `MasteryService.purchase_traits` asynchronously calls `CraftingService.reset_sticker_book` before its Promise settles. That method only resets/warms the local trait cache. Guarding it as an external account mutation caused Auto Crafter to block its own mastery-allocation completion. It is no longer classified as an account write.

Trait mutation is now fail-closed at two independent boundaries:

1. The controller waits for a fresh authoritative gear snapshot reporting item level 500 before any pending perk or blessing replacement.
2. The backend re-resolves the same gear ID from the latest authoritative inventory, runs the native recipe item validator, verifies an occupied one-based source slot, rejects duplicate/no-op/downgrade targets, validates target master-item kind and rank, and independently requires maximum expertise.

Any malformed request becomes a rejected/no-op Auto Crafter operation with normal error reporting. It cannot call Darktide's perk or blessing service, and it is never retried ambiguously.

InstantCharacterChange compatibility now reads player ID, profile ID, and archetype from one live player snapshot. Mixed IDs are `character_context_settling`; missing profile components are `character_context_unavailable`. Import and crafting wait/fail closed instead of combining an old operative ID with a new operative archetype.

Darktide contracts were checked against the locally available upstream source at version 1.12.3 (`CraftingService`, `MasteryService`, crafting recipes, item expertise utilities). The upstream source mirror had not yet published the reported live 1.12.4 code, so 1.12.4-specific runtime behavior still requires in-game validation.

Automated evidence after this pass: 30 behavior scripts / 118 named cases, including malformed perk/blessing shape, absent slots, wrong target kinds, sub-500 mutations, mastery cache reset ownership, atomic character switching, four serial imported queues, network/resource/capacity boundaries, and a 1,000-card hidden-grid performance case.
