# Cross-character Curio acquisition research spike

Date: 2026-08-04

Branch: `spike/cross-character-curio-acquisition`

BetterInventory version: `1.2.0` (unchanged)

## Outcome

Scanning Curio offers for every character and filtering them against configurable rules is feasible and already proven by CuriosChecker and GlobalStore.

Purchasing a matching offer for a character other than the currently selected character also appears technically feasible. Darktide's offer object retains the target character ID, and the backend exposes wallets by explicit character ID. The important constraint is that BetterInventory must supply the target character's wallet explicitly; the ordinary `StoreService.purchase_item` path resolves the currently selected character's wallets and is unsafe for a cross-character transaction.

The feature should be developed in three gated stages:

1. Scan and notify only.
2. Show a reviewed batch and prompt before each purchase or batch.
3. Permit unattended automatic purchasing only after live cross-character transaction tests pass.

Static analysis is sufficient to approve a scan-only prototype. It is not sufficient to enable unattended purchasing by default.

## Confidence by capability

| Capability | Confidence | Evidence / remaining gate |
| --- | --- | --- |
| Fetch all character profiles | High | Native `ProfilesService.fetch_all_profiles` returns every profile. |
| Fetch Armoury offers for each character | High | CuriosChecker and GlobalStore both do this with explicit character IDs. |
| Fetch Melk offers for each character | High | CuriosChecker does this through the archetype-specific Marks store. |
| Normalize Curios and evaluate primary stats | High | CuriosChecker uses stable trait IDs and `MasterItems.get_store_item_instance`. |
| Inspect owned Curios per character | High | The profile result includes the account gear list; entries retain `characterId`. |
| Purchase for the selected character | High | This is Darktide's normal StoreService flow. |
| Purchase for another character | Medium-high | The source-level request contract supports it, but one controlled in-game purchase must prove wallet and ownership behavior. |
| Safe unattended auto-purchase | Medium | Requires transaction serialization, rotation-race handling, capacity/error tests, and explicit user safeguards. |

## Evidence from the researched mods

### CuriosChecker 1.3.4

The researched archive is `CuriosChecker 1026 1.3.4 2026-07-14T16-19Z 8bwV4bcV4.zip`.

CuriosChecker demonstrates the complete discovery half of this feature:

- calls `Managers.data_service.profiles:fetch_all_profiles()`;
- resolves the archetype-specific Credits and Marks storefront methods;
- fetches each store with the profile's explicit `character_id`;
- examines personal offers and ignores non-`GADGET` items;
- normalizes offers with `MasterItems.get_store_item_instance`;
- matches stable innate trait IDs for Health, Toughness, Stamina and Wounds;
- supports minimum rarity, item power and primary-stat thresholds;
- skips offers already represented in owned gear;
- tracks rotation timing, throttles scans, and retries failed requests a bounded number of times;
- removes a displayed result when `GearService.on_gear_created` reports that it was acquired.

It does not purchase automatically. Selecting a result switches to the relevant character and opens the vanilla Armoury or Melk Curio tab, leaving the purchase to the user.

Useful lessons for BetterInventory:

- primary-type matching needs explicit `ANY` versus `ALL` semantics;
- storefront calls should be bounded rather than sending `2 x character count` requests at once;
- normalization must fail closed when an item or description cannot be read;
- scan results should be discarded at rotation and after purchases instead of being retained for the process lifetime.

### GlobalStore 0.4.0

GlobalStore independently proves all-character store aggregation. It fetches all profiles, fetches each character's archetype-specific storefront, merges the offers, and maps each `offerId` back to its profile for presentation.

GlobalStore does not provide a dedicated cross-character purchase implementation. Its value to this spike is evidence that cross-character offer discovery and presentation can coexist with Darktide's normal vendor views.

## Native Darktide contracts

Relevant contracts in the local Darktide source snapshot:

- `scripts/managers/data_service/services/profiles_service.lua:27` fetches characters, progression, account gear and the selected character together.
- `scripts/managers/data_service/services/profiles_service.lua:69` returns `profiles`, `selected_profile`, and the account-wide `gear` list.
- `scripts/managers/data_service/services/gear_service.lua:250` filters that gear by an explicit `character_id`; account-owned entries are also included.
- `scripts/backend/utilities/store_front.lua:6` stores the storefront's `character_id` and `wallet_owner`.
- `scripts/backend/utilities/offer.lua:37` validates an offer against its `validFrom` and `validTo` interval.
- `scripts/backend/utilities/offer.lua:67` builds a purchase request containing the storefront's target `characterId`.
- `scripts/backend/utilities/offer.lua:76` charges `wallet.owner` when supplied, otherwise the storefront's wallet owner.
- `scripts/backend/utilities/offer.lua:82` mutates the wallet balance and `lastTransactionId` after success.
- `scripts/backend/wallet.lua:14` fetches wallets for an explicit character ID.
- `scripts/managers/data_service/services/store_service.lua:286` resolves Credits or Marks using the currently selected character's combined wallets.
- `scripts/managers/data_service/services/store_service.lua:307` exposes `purchase_item_with_wallet(offer, wallet)` and still runs the normal gear/cache decoration.

### Critical cross-character rule

Do not call this for an offer belonging to another character:

```lua
Managers.data_service.store:purchase_item(offer)
```

That method obtains the currently selected character's wallets. Because `Offer.make_purchase` prefers `wallet.owner`, the supplied current-character wallet can override the storefront's intended wallet owner.

The safe candidate path is:

1. Keep the offer's target `character_id` from the fetched storefront.
2. Fetch account wallets and `Managers.backend.interfaces.wallet:character_wallets(target_character_id)`.
3. Select the wallet matching `offer.price.amount.type`, following Darktide's account-wallet-first behavior.
4. Revalidate wallet owner, balance, reserve, and `lastTransactionId`.
5. Call `Managers.data_service.store:purchase_item_with_wallet(offer, target_wallet)`.
6. Wait for completion and refresh the target wallet before attempting another transaction charged to it.

The implementation must never purchase two offers against the same wallet concurrently. `latestTransactionId` makes wallet operations ordered transactions, not independent fire-and-forget requests.

## Proposed mod options

Create a separate `Curio acquisition` section. Keep it collapsed when disabled.

### General

- **Enable Curio acquisition scanner**: Off by default for the first release.
- **Acquisition mode**:
  - `Scan and notify` (default)
  - `Prompt before purchasing`
  - `Automatic purchase` (locked until the prompted path passes validation)
- **Character scope**: `Current character` or `All characters`.
- **Scan Armoury Exchange**: On by default.
- **Scan Melk's Requisitorium**: Off by default because Marks are scarce.
- **Scan on entering the Mourningstar**: On.
- **Manual rescan keybind**.

### Primary Curio condition

- desired primary types: Health, Toughness, Stamina, Wounds;
- minimum value for each enabled type;
- type matching: `Any enabled type` or `All enabled types`;
- minimum rarity;
- minimum item power.

For Curio primaries, `Any enabled type` is the useful default: an offer must meet the threshold belonging to its own primary type. `All` is generally impossible because a Curio has one primary trait, so the UI should either omit `All` here or explain it precisely.

### Secondary perk conditions

- desired perk toggles or a searchable perk allowlist;
- minimum value per enabled perk where values are comparable;
- matching mode: `At least N`, `Any`, or `All`;
- optional rejected-perk denylist;
- optional `Only if the Curio improves this character's best owned match`.

Matching must use stable item/perk IDs, never localized or Enhanced Descriptions-rendered text.

### Spending safeguards

- maximum price per Curio for Credits and Marks;
- minimum balance to preserve per currency and character;
- maximum purchases per scan;
- maximum purchases per store rotation;
- skip an exact duplicate already owned by the target character;
- do not purchase when the target inventory is at or near capacity;
- show character, vendor, item, price and post-purchase balance in confirmations.

All monetary limits must fail closed. A missing wallet, unreadable price, unknown currency, absent balance, or failed capacity check means `do not purchase`.

### Per-character overrides

Start with one global rule set and optional per-character enable/disable toggles. Full per-character rule editors would multiply the settings surface and should be deferred until the scanner proves useful.

## Matching semantics

The matcher should be a pure function so it can be exhaustively tested without a live backend.

Global gates are combined with `AND`:

```text
valid offer
AND target character enabled
AND vendor enabled
AND primary rule matches
AND rarity/power gates pass
AND secondary-perk rule passes
AND price and reserve gates pass
AND duplicate/improvement rule passes
```

Only explicitly grouped choices use `ANY`, such as acceptable primary types or an `Any desired perk` setting. The review screen should explain the first failing reason for rejected offers; that makes complicated filters debuggable.

## Recommended architecture

Do not add this subsystem to the already large `BetterInventory_features.lua`. Use dedicated modules with one narrow responsibility each:

```text
BetterInventory_curio_acquisition.lua
|-- lifecycle, scan scheduling, cancellation and notifications
|-- scanner
|   |-- profiles
|   |-- owned Curios
|   `-- bounded storefront request queue
|-- normalizer
|-- pure rule matcher
|-- compact result model
`-- purchase coordinator
    |-- confirmation/review
    |-- final offer and wallet revalidation
    |-- sequential transaction queue
    `-- idempotency ledger
```

If the result browser grows into a substantial vendor UI, it should become a companion mod instead of expanding BetterInventory's inventory-view module indefinitely. A settings-driven scanner and small review dialog remain coherent with BetterInventory's equipment-management scope.

### Transaction state machine

Reuse the safety ideas already present in BetterInventory's automatic discard system:

```text
idle -> scanning -> reviewed -> awaiting_confirmation
     -> revalidating -> purchasing -> refreshing -> completed
                                      `-> failed/cancelled
```

Every asynchronous continuation must verify:

- the feature and selected mode are still enabled;
- the session/account token is unchanged;
- the target profile still exists;
- the offer ID, item fingerprint, price and target character still match;
- the offer is still valid using backend server time;
- the wallet is owned by the intended target, has sufficient balance, and preserves the configured reserve;
- no purchase for that wallet is already in flight;
- the offer was not already completed in this rotation.

Once the purchase POST has been sent, cancellation can stop later queued purchases but cannot assume the in-flight request was cancelled. Its result must be reconciled before proceeding.

### Idempotency

Record completed or in-flight operations with a key containing at least:

```text
account/session + characterId + vendor + rotation + offerId
```

Clear expired rotation entries and cap the ledger. Never keep full offer, storefront, profile or item-instance graphs longer than the active scan/review; store compact IDs and normalized values instead.

## Performance and memory plan

- Never scan per frame.
- Coalesce login, hub-entry, rotation and manual triggers into one pending scan.
- Use a minimum scan interval and bounded retries with backoff.
- Limit storefront concurrency to two requests, or one request per vendor queue.
- Fetch profiles/gear once per scan, not once per character.
- Reject non-Curio descriptions before expensive normalization.
- Normalize each offer once and retain only compact matching records.
- Release storefronts, normalized item instances, rejected-reason details and confirmation widgets when the scan or dialog ends.
- Cap diagnostic history and the idempotency ledger.
- Cancel or ignore stale promise continuations using a generation token on reload, account change, mod disable and leaving a supported game state.

At Darktide's normal character limit, this is a small bounded workload. The larger risk is unnecessary backend traffic, not Lua heap size.

## Race conditions and edge cases

The implementation must handle:

- a store rotation between scan and purchase;
- the same scan being triggered by login, hub entry and a keybind simultaneously;
- another mod or the vanilla store spending from the same wallet;
- two matching offers charged to the same wallet;
- a user changing filters while a scan or confirmation is open;
- character deletion, account change or character selection during a scan;
- backend authentication not yet ready;
- one character/vendor request failing while others succeed;
- missing archetype store mappings;
- malformed, unknown or newly introduced Curio traits;
- already-owned or already-purchased offers;
- inventory capacity limits;
- insufficient funds after an earlier queued purchase;
- hot reload while promises or a confirmation are active;
- no characters, no offers, no enabled conditions, or impossible conditions;
- account-wide versus character-owned currencies;
- a purchase succeeding server-side while the client receives an error or timeout.

For an ambiguous timeout, invalidate gear and wallet caches and reconcile ownership before retrying. Never immediately repeat the POST.

## Compatibility

### CuriosChecker

CuriosChecker exposes no stable result-sharing API, so BetterInventory should not hook or scrape its UI. Running both scanners would duplicate backend requests. If CuriosChecker is detected, BetterInventory can show a non-blocking compatibility note and leave its own automatic scan disabled until the user enables it. Manual scanning remains safe.

### GlobalStore

GlobalStore adds StoreService methods and hooks store-view behavior, but its all-character views are separate from a direct, read-only BetterInventory scanner. Use Darktide's public service/backend contracts rather than GlobalStore internals. The expected conflict risk is low, but prompted-purchase tests should be repeated with GlobalStore enabled.

### Enhanced Descriptions, Quick Look Card and Inventory2D-derived UI mods

These presentation mods should not affect matching because BetterInventory must operate on stable trait/perk IDs and raw item data. Do not parse rendered descriptions.

## Validation gates

### Gate 1: scan-only prototype

1. Compare every reported Armoury and Melk Curio with CuriosChecker for every character.
2. Verify primary values, rarity, power, perks, prices and character ownership.
3. Verify owned-best and duplicate rules against each character's inventory.
4. Exercise authentication delay, partial failures, rotation, hot reload and repeated scan triggers.
5. Profile request count, scan duration and retained Lua objects over repeated rotations.

### Gate 2: prompted transactions

1. Buy one inexpensive Armoury Curio for the selected character.
2. Buy one inexpensive Armoury Curio for a non-selected character using an explicitly fetched target wallet.
3. Verify which character owns the created gear and which wallet changed.
4. Verify cache invalidation and UI updates.
5. Repeat with GlobalStore and CuriosChecker enabled.
6. Test an expired offer, insufficient balance, full inventory and a changed `lastTransactionId`.
7. Test a simulated timeout and prove reconciliation prevents a duplicate purchase.

Melk should remain scan-only until the Credits path is proven, then require its own explicit test because its currency is more valuable.

### Gate 3: automatic mode

Automatic mode can be unlocked only after all prompted tests pass. It should remain off by default, require a clear warning/acknowledgement, enforce purchase and reserve limits, and provide a persistent session report of what it bought and why.

## Decision

Proceed with a scan-only prototype on a future feature branch. The requested capability fits BetterInventory if it remains a modular, optional Curio-management feature.

Do not implement unattended purchasing first. The correct next deliverable is a dedicated scanner plus pure matcher and review output. After its results match CuriosChecker across all characters, add a single-purchase prompted proof using the explicitly targeted wallet path. Only then consider the automatic mode.
