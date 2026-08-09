# Auto Crafter Helper feasibility and implementation research

- Date: 2026-08-08
- Branch: `research/auto-crafter-helper-feasibility`
- Project: BetterInventory
- Target game source snapshot: Darktide 1.12.3, commit `47379fd3cbb6d59c3e9001bab1693c307bf46e2b`

Document purpose: implementation handoff for another coding agent, including a lower-reasoning agent that needs explicit backend contracts, state transitions, safeguards, and test gates.

## Executive decision

Proceeding is justified. At least four requested features are possible; current evidence supports **six out of six**.

| # | Requested feature | Verdict | Confidence | Important qualification |
| --- | --- | --- | --- | --- |
| 1 | Automatically raise weapon-family mastery to level 20 | **Feasible** | High for the operation loop; medium-high for fully unattended convergence | Not a direct “set level” request. Automate `buy Profane -> consecrate to Redeemed -> sacrifice -> claim tiers -> poll` until authoritative level and rewards converge. |
| 2 | Buy until a weapon has the selected dump stat at 60 | **Feasible** | High | Purchase must be serialized. Inspect each returned item’s named base-stat entries, not only total rating. Keep target; discard or retain failures according to policy. |
| 3 | Consecrate a weapon through Transcendent rarity | **Feasible** | High | Call rarity upgrade once per tier and chain only after each returned item is authoritative. Costs are server-configured and must be read live. |
| 4 | Empower a weapon to 500 | **Feasible** | High after mastery synchronization | Backend accepts a target expertise level. The effective cap depends on claimed mastery rewards, not merely the XP bar. UI animation is optional client presentation, not a backend requirement. |
| 5 | Change perks and blessings | **Feasible** | High with ownership/cap checks | Target perk/blessing must be valid for the weapon. Blessing tier must be unlocked; optionally purchase it with mastery points first. Expertise can restrict available rank. |
| 6 | Favorite and rename final weapon | **Feasible** | Very high | Favorite is local save state. Rename is optional local BetterInventory/Name It provider state, disabled without provider. Both run only after final `gear_id` is stable. |

The core backend requests already exist in the shipped client. Two current mods also demonstrate large parts of the workflow in live use: [Buy Until Rating](https://www.nexusmods.com/warhammer40kdarktide/mods/100) repeatedly purchases and evaluates Brunt weapons, while [Weapon XP Farm](https://www.nexusmods.com/warhammer40kdarktide/mods/846) bulk-buys, consecrates, prepares sacrifices, estimates mastery completion, and spends blessing points. [Quick Level Mastery](https://www.nexusmods.com/warhammer40kdarktide/mods/395) demonstrates the exact one-item `buy -> Redeemed -> sacrifice` mastery loop.

This is a feasibility conclusion, not proof that a first implementation will be safe. Purchases, crafting, and sacrifices spend or destroy account resources. Production code needs the transaction state machine and fail-closed rules specified below.

## Scope and terminology

Use these terms consistently:

- **Weapon family/pattern/mastery ID**: client-facing identifier used to associate a weapon family with a mastery track.
- **Track ID**: backend identifier used by track-state and tier-claim endpoints.
- **Mastery XP**: XP tracked on the weapon-family mastery track.
- **Mastery level**: level derived from `xpTracked` and track tier limits.
- **Claimed level**: last mastery tier whose rewards have been claimed. This can lag behind mastery level.
- **Mastery/blessing points**: rewards made usable by successful tier claims. These can appear stale even when XP-derived level is 20.
- **Profane**: base white rarity returned by Brunt’s requisitions.
- **Redeemed**: green rarity; minimum useful sacrifice rarity in the observed workflow.
- **Transcendent**: orange rarity; repeated rarity upgrades are required to reach it.
- **Expertise**: weapon base level/power value displayed as values such as 310, 320, and 500. Client code applies a multiplier of 10 to backend expertise units.
- **Blessing**: represented as a weapon `trait` in backend crafting code.
- **Perk**: represented separately as a weapon `perk`.
- **Dump stat**: a user-selected named base stat intended to be low, commonly exactly 60 in the proposed rule. Do not confuse this with overall base-stat rating. The selected weapon template's base-stat identities are indexed manual choices; changing weapons resets the selector to index 0.
- **Authoritative state**: fresh data returned from backend/service requests, not a UI widget, preview object, cached layout entry, or locally predicted value.

## Evidence hierarchy and source limits

1. Highest weight: decompiled 1.12.3 client code in the local `Darktide-Source-Code` checkout.
2. High weight: maintained open-source mods that call the same game services.
3. Supporting empirical evidence: current Nexus descriptions/changelogs and author/user reports.
4. Lowest weight: inferred behavior that still needs live-account validation.

The source checkout identifies itself as Darktide 1.12.3 and lists that version as the latest captured patch in its [repository README](https://github.com/Aussiemon/Darktide-Source-Code). Fatshark does not publish a stable public crafting API for mods. These are internal client contracts and can change after any game patch.

Do not copy third-party mod code without checking its license/permissions. Use it as behavioral evidence and independently implement against Darktide service contracts. In particular, Buy Until Rating’s Nexus page restricts modification/redistribution even though its source is visible.

## Backend and local-operation map

### Canonical request catalogue

| Operation | Preferred client call | Lower-level request | Response/state effect |
| --- | --- | --- | --- |
| Fetch Brunt requisition catalogue | `Managers.data_service.store:get_credits_goods_store()` | `GET /store/storefront/credits_store_bespoke_weapons_<archetype>` with account and character IDs | Returns public offers, including reusable weapon-type offers. |
| Purchase one Brunt offer | `Managers.data_service.store:purchase_item(offer)` | `POST /store/<account>/wallets/<owner>/purchases` | Returns created gear; updates wallet transaction ID and local gear cache. |
| Consecrate weapon one rarity | `Managers.data_service.crafting:upgrade_weapon_rarity(gear_id, costs)` | `POST /crafting`, body `{ op="upgradeWeaponRarity", gearId=... }` | Returns updated gear and decrements cached crafting wallets. |
| Empower to target expertise | `Managers.data_service.crafting:add_weapon_expertise(gear_id, target, costs)` | `POST /crafting`, body `{ op="addExpertise", gearId=..., newLevel=... }` | Returns updated gear. Backend unit is displayed expertise divided by multiplier. |
| Replace blessing | `Managers.data_service.crafting:replace_trait_in_weapon(...)` | `POST /crafting`, body `{ op="replaceTrait", traitType="traits", ... }` | Returns updated gear. Client indices are converted from 1-based to backend 0-based. |
| Replace perk | `Managers.data_service.crafting:replace_perk_in_weapon(...)` | Same operation with `traitType="perks"` | Returns updated gear. |
| Sacrifice weapons for mastery | `Managers.data_service.crafting:extract_weapon_mastery(mastery_id, gear_ids)` | `POST /crafting`, body `{ op="extractMastery", gearIds={...}, trackId=... }` | Deletes sacrificed gear and returns XP amount per track. Data service batches up to 40 IDs. |
| Fetch mastery state | `Managers.data_service.mastery:get_mastery(track_id)` | `GET /data/<account>/trackstate/<track_id>` plus track definition | Returns fresh XP, derived level, claimed tier, milestones, and claims. |
| Claim mastery tier | `Managers.data_service.mastery:claim_level(...)` or `claim_levels_by_new_exp(...)` | `POST /data/<account>/tracks/<track_id>/tiers/<tier>` | Claims tier rewards, including mastery points and expertise-cap rewards. |
| Purchase blessing tier | `Managers.data_service.mastery:purchase_trait(pattern, trait, tier)` | `PUT /data/<account>/account/traits/<category>/<trait>/tiers/<tier>` | Marks blessing tier owned and spends mastery points if backend accepts. |
| Favorite item | `Items.set_item_id_as_favorite(gear_id, true)` | No title-backend request | Writes character-local `favorite_items`, then queues save. |
| Optional rename | BetterInventory or Name It naming adapter | No title-backend request | Stores local name keyed by `gear_id`; unavailable provider disables feature. |

### Why the data-service layer is preferred

Call `Managers.data_service.*` rather than constructing HTTP requests directly.

The data-service wrappers:

- convert backend gear to item instances;
- update or invalidate gear caches;
- update wallet caches after crafting/purchases;
- preserve current authentication/account routing;
- translate 1-based Lua indices to backend 0-based indices;
- batch mastery extraction;
- catch errors and invalidate stale caches.

Directly invoking `Managers.backend:title_request` would duplicate fragile internal behavior and make cache divergence more likely.

Relevant local source:

- `Darktide-Source-Code/scripts/backend/crafting.lua:9-24` defines the common `/crafting` POST and item conversion.
- `.../scripts/backend/crafting.lua:128-212` defines rarity, replacement, expertise, and mastery-extraction payloads.
- `.../scripts/managers/data_service/services/crafting_service.lua:53-180` updates gear/wallet caches for rarity and replacement operations.
- `.../scripts/managers/data_service/services/crafting_service.lua:270-343` handles expertise and batched mastery extraction.
- `.../scripts/backend/store.lua` resolves archetype-specific Brunt storefronts.
- `.../scripts/backend/utilities/offer.lua:54-91` builds purchases and advances `latestTransactionId`.
- `.../scripts/managers/data_service/services/store_service.lua:263-310` decorates purchase results and registers created gear.

## Feature 1: automatically reach mastery level 20

### Correct interpretation

This feature does not need an illicit or nonexistent “set mastery level” endpoint. It automates the normal economy loop:

```text
fresh mastery read
  -> if authoritative completion, stop
  -> buy Profane weapon(s) of target family
  -> consecrate each to Redeemed
  -> sacrifice eligible batch
  -> claim newly reached mastery tiers
  -> poll fresh mastery/claim state
  -> repeat if still below completion
```

Quick Level Mastery’s author confirms that Profane weapons are upgraded before sacrifice because Profane sacrifices award no XP. Current user reports describe one button buying, upgrading to green, and sacrificing. Weapon XP Farm reports roughly 36-37 Redeemed copies from zero to level 20, but this must remain an estimate, not a hardcoded invariant.

### Vanilla sacrifice flow proves required requests

`CraftingMechanicusBarterItemsView._complete_purchase` does this after the user confirms a sacrifice:

1. Collect selected `gear_id` values.
2. Call `Managers.data_service.crafting:extract_weapon_mastery(mastery_id, gear_ids)`.
3. Read returned `data.amount`.
4. Update local preview XP/level.
5. Call `Managers.data_service.mastery:claim_levels_by_new_exp(...)`.
6. Return to weapon selection.

See `Darktide-Source-Code/scripts/ui/views/crafting_mechanicus_barter_items_view/crafting_mechanicus_barter_items_view.lua:1519-1607`.

This proves both the sacrifice mutation and tier-claim step are callable independently of the visible Hadron animation.

### Three completion conditions

Distinguish **stopping mastery spend** from **completing dependent crafting**. A locally derived level 20 is enough to stop buying/consecrating/sacrificing mastery fodder immediately. It is not enough to declare reward synchronization complete or spend mastery points.

Define completion as all applicable conditions being true on fresh reads:

1. `mastery_level >= mastery_max_level` (normally 20).
2. `claimed_level >= mastery_max_level - 1` because backend tiers are zero-indexed in claim state.
3. Reward-derived state has converged:
   - expected total mastery points are visible, or
   - expected expertise cap is unlocked, and
   - requested blessing purchases no longer fail for “insufficient/unclaimed” state.

Condition 3 should be a postcondition check tailored to the requested downstream actions. If user only asks to reach level 20, condition 1 plus condition 2 is sufficient. If user also asks to empower to 500 and buy blessings, verify the cap and points before continuing.

### Synchronization problem and solution

Observed failure mode: XP bar reaches 20, but blessing points remain unavailable until menu re-entry or game restart. This matches client architecture: mastery XP, tier claims, and trait ownership come from separate calls/caches.

Implement bounded polling after every sacrifice that crosses at least one tier:

```lua
-- Pseudocode, not drop-in production code.
function converge_mastery(run, expected_min_xp)
    -- 1. Fetch fresh track state.
    -- 2. Claim every newly reachable tier sequentially.
    -- 3. Fetch fresh track state again.
    -- 4. Fetch trait sticker-book state if blessing ownership matters.
    -- 5. Accept only monotonic authoritative progress.
    -- 6. Retry with bounded exponential backoff if claims/state lag.
end
```

Recommended retry schedule: immediate, 0.5 s, 1 s, 2 s, 4 s, then 5 s intervals, with a 30-45 second total convergence deadline. These timings are implementation defaults requiring live validation.

Each poll must use `get_mastery(track_id)` or track-state backend service, not the existing `_masteries` table in an open view. Open-view objects can contain optimistic values written by the sacrifice UI.

After a successful tier-claim chain, `MasteryService.claim_levels_by_new_exp` itself re-fetches the mastery through `get_mastery(track_id)`. However, it catches several failures and can resolve without propagating them. The Auto Crafter controller must validate returned state rather than interpreting promise resolution as successful convergence. See `mastery_service.lua:322-388`.

### Loop granularity

Two viable strategies:

#### Strategy A: one weapon per loop

Advantages:

- minimal overshoot and resource waste;
- easy association of purchase, upgrade, and sacrifice;
- easiest recovery after interruption;
- mirrors Quick Level Mastery.

Disadvantages:

- many requests and longer total runtime;
- more frequent wallet/cache traffic.

Recommended for first safe implementation.

#### Strategy B: predictive batches

Advantages:

- faster and fewer mastery polls;
- data service can sacrifice up to 40 IDs per batch.

Disadvantages:

- XP per item/cost calibration may change;
- stale mastery state can cause overbuying;
- partial upgrade failures create mixed eligibility;
- harder cancellation and recovery.

Recommended only after Strategy A is live-validated. Start with batches of 3-5, recalculate after every sacrifice response, and never pre-buy the whole estimated 37 unless user explicitly selects a bulk mode.

### Mastery-loop stop conditions

Stop successfully when authoritative completion conditions converge.

Stop safely without further spending when any condition occurs:

- user cancels;
- active view/character/account changes;
- wallet cannot cover next purchase plus required consecration;
- inventory capacity threshold is reached;
- storefront offer becomes invalid;
- target weapon family/pattern does not match purchased item;
- purchase succeeds but created item cannot be resolved;
- rarity upgrade fails;
- item remains below Redeemed after response refresh;
- sacrifice response omits the submitted gear ID;
- mastery XP does not increase after a successful sacrifice;
- mastery/claims fail to converge before deadline;
- run exceeds configured purchase, spend, or elapsed-time cap.

Do not silently continue after any ambiguous mutation result.

## Feature 2: buy until selected dump stat equals 60

### Feasibility evidence

Darktide returns the purchased gear in the purchase response. `StoreService._decorate_item_purchase_promise` registers it in the gear cache. Buy Until Rating hooks the purchase completion, converts returned gear with `MasterItems.get_item_instance`, evaluates stats, and calls the purchase action again when criteria are not met. Its maintained source is available at [buy_until_rating.lua](https://github.com/zombine04/darktide-mods/blob/main/buy_until_rating/scripts/mods/buy_until_rating/buy_until_rating.lua).

AutoBruntRoller independently advertises stat-target filtering, auto-favorite, deletion, and auto-consecration in a current 2026 release: [AutoBruntRoller](https://www.nexusmods.com/warhammer40kdarktide/mods/836).

### Required criterion model

Do not implement “dump stat 60” as `Items.calculate_stats_rating(item) == 60`. That function returns total base item level/rating, not one named stat.

Evaluate `item.base_stats` entries. Each entry includes a value and enough definition/display identity to map to a user-facing stat. Existing BetterInventory weapon-card logic already consumes weapon stats and can supply identity helpers.

Recommended target structure:

```lua
target = {
    weapon_master_id = "...",      -- exact Brunt offer family/mark identity
    pattern_id = "...",            -- mastery family safety check
    dump_stat_id = "mobility",      -- stable internal identity, not localized text
    dump_stat_value = 0.60,          -- normalize display 60 to raw representation
    other_stat_minimum = nil,        -- optional per-stat/global criteria
    minimum_total_rating = nil,      -- optional
}
```

Values may appear as normalized decimals in `base_stats` while UI displays percentages. Normalize with the same item/stat utility used by weapon cards. Do not compare localized labels because language changes would break selection.

### Purchase serialization is mandatory

Offer purchases include `latestTransactionId` from the wallet and increment it after success. Concurrent purchases can race on this transaction sequence. Buy Until Rating’s historical changelog also notes backend conflicts when concurrent wallet-changing deletion operations were attempted.

Rules:

- one purchase promise in flight per account/character;
- await decorated purchase completion before evaluating and continuing;
- refresh/reacquire offer if backend reports stale/invalid offer;
- do not concurrently sell/discard, craft, or run curio acquisition through the same resource arbiter;
- maintain separate counters for requested, confirmed, retained, and discarded items.

### Failure-item policy

Offer three explicit policies:

1. **Keep all**: safest, no destructive mutation.
2. **Queue failures for review**: recommended default. Show IDs/stats and require confirmation before discard.
3. **Auto-discard failures**: advanced opt-in with strict protection rules.

If auto-discard exists, never discard:

- target match;
- favorited item;
- equipped item;
- item manually protected during the run;
- item above configurable total-rating/perfect-roll threshold;
- item whose identity or stats could not be parsed.

BetterInventory’s existing discard policy/transaction modules should own destructive filtering rather than duplicating it in Auto Crafter.

## Feature 3: consecrate to Transcendent

### Request behavior

`upgradeWeaponRarity` performs one rarity step. Reaching Transcendent requires a sequential loop:

```text
Profane -> Redeemed -> Anointed -> Exalted -> Transcendent
```

Exact rarity names/order should come from current rarity settings, not a hardcoded text list. The controller should compare numeric rarity and continue until target rarity.

For each step:

1. Resolve current authoritative item from prior response/cache.
2. Fetch/compute current operation cost using `CraftingSettings.recipes.upgrade_item.get_costs` or backend-refreshed crafting cost data.
3. Verify wallets.
4. Call `Managers.data_service.crafting:upgrade_weapon_rarity(gear_id, costs)`.
5. Replace run’s item snapshot with `results.items[1]`.
6. Verify rarity increased exactly one step.
7. Continue or stop.

Weapon XP Farm’s July 2026 changelog explicitly states that consecration costs are read live from backend per weapon/rarity/item level. Follow that pattern; never hardcode Plasteel/Diamantine costs.

### Locked animation concern

Crafting animations are UI presentation. Backend mutation occurs in recipe/data-service promises before the view plays success/upgrade animations. Auto Crafter can call service methods from its own controller and update its widget immediately from returned item state.

Do not simulate button presses or wait for animation callbacks. That is more fragile than invoking the same recipe/service contract directly.

## Feature 4: empower weapon to 500

### Request behavior

Backend operation:

```lua
{
    op = "addExpertise",
    gearId = gear_id,
    newLevel = added_expertise,
}
```

Vanilla recipe sends `display_target / Items.get_expertise_multiplier()`. Current multiplier is 10, so displayed 500 corresponds to backend target 50. Use the utility at runtime; do not hardcode division by 10.

The UI supports selecting a target up to `Mastery.get_current_expertise_cap(mastery_data)` and then calls `add_weapon_expertise` once. Therefore 310 -> 500 does not inherently require nineteen backend calls or nineteen animations. One target-level request should be possible when cap and resources allow it.

Relevant source:

- `crafting_mechanicus_settings.lua:233-299` computes costs and calls `add_weapon_expertise`.
- `crafting_mechanicus_upgrade_expertise_view.lua:200-239` performs one craft promise, accepts returned item, and only then plays the animation.
- `mastery.lua:575-628` derives current/max expertise caps from claimed mastery rewards.

### Preconditions

- weapon is valid crafting item;
- target is above current base level;
- target is at or below current **claimed** expertise cap;
- wallet covers live calculated cost;
- mastery state has converged after any automated leveling;
- no other mutation owns the `gear_id`.

If XP-derived mastery is 20 but claimed expertise cap is below 500, return to mastery convergence. Do not repeatedly retry `addExpertise` against a stale cap.

## Feature 5: replace perks and blessings

### Existing calls

Blessing replacement:

```lua
Managers.data_service.crafting:replace_trait_in_weapon(
    gear_id,
    existing_trait_index,
    new_trait_master_id,
    new_trait_tier,
    costs
)
```

Perk replacement:

```lua
Managers.data_service.crafting:replace_perk_in_weapon(
    gear_id,
    existing_perk_index,
    new_perk_master_id,
    costs,
    new_perk_tier
)
```

Both use `replaceTrait` backend operation with different `traitType` values. Service wrappers update gear cache and crafting wallets.

### Blessing ownership and mastery points

Vanilla replacement validation checks the trait sticker book and rejects unseen tiers. Auto Crafter must:

1. Resolve weapon trait category.
2. Fetch fresh trait sticker book.
3. Check requested blessing/tier validity and ownership.
4. If unowned and auto-purchase is allowed, verify mastery points and prerequisites.
5. Call `Managers.data_service.mastery:purchase_trait(...)` sequentially for required tier/path operations.
6. Re-fetch sticker book and confirm ownership.
7. Replace blessing.

`MasteryService.purchase_traits` already builds and serializes multiple trait-tier purchases. Reuse it where its ordering matches desired behavior. Do not infer purchase success from local point arithmetic.

### Selection rules

- Store target by stable master item/trait ID and tier, not localized name.
- Validate blessing belongs to weapon trait category.
- Validate perk is allowed for item type.
- Validate requested rank does not exceed current rank cap.
- If replacing two slots, re-resolve item after first response because slot data may have changed.
- Preserve index mapping: Lua/service input is 1-based; backend payload is 0-based.
- Calculate each operation cost against latest returned item.

### Ordering recommendation

For final weapon crafting:

1. Reach required mastery/claim convergence.
2. Empower to target level.
3. Consecrate to target rarity if not already there.
4. Ensure blessing tiers are purchased.
5. Replace perks/blessings one operation at a time.
6. Verify exact final item state.

Empower before final replacements because operation costs/rank availability can depend on current item level, and final verification is simpler when all slots are stable.

## Feature 6: favorite and rename

### Favorite is local

`Items.set_item_id_as_favorite(gear_id, state)` writes `character_data.favorite_items[gear_id]` and calls `Managers.save:queue_save()`. See `Darktide-Source-Code/scripts/utilities/items.lua:2035-2070`.

No backend request or synchronization poll is required. Apply only to final retained item, never temporary mastery-fodder copies.

### Rename is optional local provider metadata

BetterInventory already owns custom item-name persistence through:

- `BetterInventory_item_customization.lua` orchestration;
- `BetterInventory_item_customization_store.lua` save/dirty-state handling;
- `BetterInventory_item_customization_name_it.lua` compatibility/editor behavior.

This matches the independent Name It implementation, which stores a `name_list[gear_id]` through DMF settings rather than mutating backend gear: [name_it.lua](https://github.com/zombine04/darktide-mods/blob/main/name_it/scripts/mods/name_it/name_it.lua).

Auto Crafter must access either implementation through optional naming adapter, not direct store/table coupling. Rename defaults disabled and remains gray when neither tested BetterInventory nor Name It provider is available.

Run rename after all destructive selection is complete. If provider supports cleanup, remove metadata when gear is later deleted. Naming-provider failure must not roll back or fail backend crafting.

## Runtime discovery: avoid hardcoded weapon, stat, perk, and blessing lists

Future-proofing is practical if Auto Crafter treats current game data as the catalogue.

### Weapon discovery

Read the live Brunt store through `Managers.data_service.store:get_credits_goods_store()`. Vanilla `CreditsGoodsVendorView:_convert_offers_to_layout_entries` resolves each offer's `description.lootChoices[1]` through `MasterItems.get_item(master_id)`. Use the same offer/master-item relationship and current character unlock filters. A newly added weapon should appear automatically when Fatshark adds a valid live offer.

Do not persist an offer object across refreshes. Persist stable selection identity (`master_id`, pattern/mastery family, mark where needed), then resolve a fresh offer before every purchase.

### Base-stat discovery

Build the dump-stat selector from canonical base-stat keys exposed by the selected weapon template, not from the presence of a rolled preview and not from a static global list. `WeaponTemplate.weapon_template_from_item(master_item).base_stats` is the authoritative candidate catalogue. Vanilla `WeaponStats` constructs rows dynamically from `item.base_stats` and `weapon_template.base_stats`, with stable `name`, localized `display_name`, and normalized value/fraction. `Items.total_stats_value` also proves item base stats are data-driven.

Selection records must store the selected mark's exact canonical key and show the vanilla-localized `display_name`. Raw identifiers such as `dual_shivs_p1_m1_finesse_stat` must never be user-facing; that example renders as `Finesse`. If localization is unavailable, use a bounded semantic fallback map before falling back to a cleaned identifier. Unknown/malformed stat layouts fail closed.

Never assume every weapon family has the same ideal dump stat: build choice depends on weapon and build. The Brunt widget must expose every template-defined base-stat key for the currently selected weapon as manual choices. Order common semantic stats deterministically as Damage `0`, Mobility `1`, Finesse `2`, First Target `3`, and Penetration `4`; append weapon-specific stats in stable localized-name order. Missing common stats are skipped without leaving holes in the visible selector. Changing weapon always selects the new catalogue's index 0. Legacy saved `auto` values and unavailable saved keys migrate to index 0. Legacy/common aliases such as `damage`, `mobility`, `finesse`, `first_target`, `penetration`, and `defenses` may resolve to the selected weapon's exact raw stat key.

#### Weapon-stat discovery audit (2026-08-08)

- Static source inspection found 142 weapon templates with `base_stats`: 136 define five stats, five define four, and one special template defines one. Those templates use 34 distinct display-localization keys, confirming that a hard-coded five-stat catalogue is incomplete.
- Crowbar failure was caused by treating rolled offer data as candidate metadata. Brunt descriptions can expose only `lootChoices`, `MasterItems.get_store_item_instance(description)` can return no usable preview, and the old inventory fallback found nothing when the operative owned no matching Crowbar. Crowbar's template still exposes Damage, Defenses, Penetration, First Target, and Mobility, so candidate discovery must succeed without either source.
- Template catalogue entries need no numeric value because the selector chooses stat identity, not a recommendation based on a rolled item.
- Cross-mark fallback never copies a sibling mark's raw key into the purchase plan. It matches the localized display key, then resolves the selected mark's corresponding canonical key.
- Weapon selection changes do not preserve the prior weapon's dump-stat selection. Once the new non-empty catalogue is available, persist its index-0 canonical key. While a catalogue is genuinely empty or loading, defer the reset instead of manufacturing a choice.

### Perk and blessing discovery

- Perks: call `Managers.data_service.crafting:get_item_crafting_metadata(item.name)` and use returned `data.perks`, filtered by current mastery perk-rank cap. This is the same data path used by `ViewElementPerksItem:present_perks`.
- Blessings: resolve `ItemUtils.trait_category(item)`, fetch fresh sticker-book/mastery data, and enumerate valid trait master items for the selected mastery pattern. Vanilla `MasteryService:get_traits_data_by_mastery_id` follows `UISettings.weapon_patterns`, marks, trait category, and sticker-book ownership.
- Store canonical perk/trait IDs and tier; display localized names/icons separately.

The read-only implementation follows this contract for the currently selected Brunt offer: three sequential reads resolve crafting metadata, mastery-family state, and the trait sticker book; results are filtered to valid master items and exposed as canonical IDs plus tier/status data. It does not hard-code weapon, perk, or blessing lists. A missing catalogue blocks only dependent future mutation phases and remains visible as a diagnostic.

Cache discovery by source version, character/archetype, weapon `master_id`/pattern, and trait category. Invalidate on store refresh, selected weapon change, mastery/sticker-book update, mod reload, or game patch. Missing contracts disable Start with a diagnostic instead of silently omitting choices.

## Product configuration and dependency rules

Selected Brunt weapon type plus dump-stat key are mandatory inputs. All controls should exist both in the Armoury widget/configuration popup and DMF mod options, backed by the same `mod:get`/`mod:set` values. UI dependency logic disables invalid children but preserves their saved values.

| Control | Type | Enabled when | Meaning |
| --- | --- | --- | --- |
| Buy until dump stat is 60 | checkbox | weapon and dump stat valid | Run serialized Brunt search; exact displayed value 60 is success. |
| Consecrate to Transcendent | checkbox | final candidate exists/planned | Raise final rarity one authoritative step at a time. |
| Upgrade to 500 | checkbox | final candidate exists/planned | Empower when claimed mastery cap permits 500. |
| Favorite final weapon | checkbox | always | Apply only after final verification. |
| Rename final weapon | checkbox + text | supported naming provider detected | **Disabled by default.** Enable only through BetterInventory or Name It naming adapter; otherwise gray control with explanation. |
| Naming provider | dropdown | two supported providers detected | `Automatic`, `BetterInventory`, or `Name It`; write through exactly one provider. |
| Level weapon mastery to 20 | checkbox | mastery family resolved | Buy/upgrade/sacrifice fodder until fast level-complete gate. |
| Allocate mastery points | checkbox | level-to-20 checked | Claim/synchronize points, buy requested blessing tiers first, then apply chosen remainder policy. |
| Change perks | checkbox | level-to-20 checked | Conservative product rule: mastery 20 guarantees Rank IV perk unlocks, so Auto Crafter never plans a lower-rank final perk. |
| Change blessings | checkbox | level-to-20 checked | Conservative product rule ensuring mastery preparation is included. |
| Choose perk targets | selectors | level-to-20 and change-perks checked | Rank IV values discovered from live crafting metadata; lower-rank entries are deliberately excluded. |
| Choose blessing targets | selectors | level-to-20, allocate-points, and change-blessings checked | Values discovered from trait category/sticker book. |
| Request scheduling | dropdown | no active run | `Sequential (recommended/default)`, `Parallel reads`, or `Experimental parallel mutations`. All remain non-blocking to UI. |
| Show progress notifications | checkbox | always | **Enabled by default.** Show native milestone, completion, and failure notifications. |
| Progress detail | dropdown | notifications or chat enabled | `Milestones` (default), `Every confirmed step`, or `Errors/completion only`. |
| Mirror progress to local chat | checkbox | always | Disabled by default. Write same coalesced status to local/system chat only, never party/team chat. |
| External item-change policy | dropdown | final item exists/planned | `Reconcile compatible changes` (default), `Pause and ask`, or `Stop safely`. |
| Stop if leaving Morningstar | checkbox (locked on first release) | always | **Enabled and mandatory for first release.** Close dispatch gate on mission/loading/operative-selection transition. |

Changing an already owned blessing may technically work without leveling/allocation. Keep the stricter dependency above for first release because it makes the full-auto promise deterministic. A later expert mode may relax it after live tests.

`Allocate mastery points` uses an explicit deterministic policy. At mastery level 20, purchase selected blessing tiers whenever their next valid tier is unlocked, then continue until every valid blessing tier in that weapon family's sticker book is owned and the full available point pool is distributed. Darktide gates Tier II-IV purchases by total mastery points already spent across the tree, so the allocator uses live `tierCosts` and `tierThresholds` and buys deterministic lowest-order prerequisite tiers whenever a selected tier is still locked. Never distribute points randomly. If no legal next tier exists while valid unseen tiers remain, halt before replacing anything.

### One-line Craft action and cost forecast

Preferred compact breakdown:

```text
Search budget: 11,600 each / 1-43 purchases / budget 500,000
Profane -> Transcendent: [dockets] - [plasteel] range [diamantine] range
Mastery fodder investment: [dockets] range [plasteel] range [diamantine] range
Known crafting investment: [dockets] range [plasteel] range [diamantine] range
```

Do not display an average perfect-roll probability or average acquisition cost. Brunt exposes results but no authoritative roll-weight distribution, and a uniform-composition calculation would look exact while modeling the wrong process. Acquisition forecasting is therefore a separately labeled **search budget**, bounded by current offer price plus enabled Docket/purchase caps. Never add the Docket cap to a crafting-investment total: it is a limit, not predicted spend.

Material forecasting reads live backend crafting recipes and reports separate ranges for Profane-to-Transcendent consecration and base-item-level 290-330 to 500. Mastery forecasting reads the selected family's live milestone XP curve plus `get_sacrifice_mastery_costs()`, applies the same sacrifice-XP equation used by Quick Level Mastery, calculates a Redeemed-fodder count range, and multiplies current Brunt price plus live Profane-to-Redeemed recipe costs. Recompute from the authoritative item immediately after purchase; exact item level, current rarity, returned sacrifice XP, and current mastery XP replace provisional ranges before mutation.

Known crafting investment includes only enabled operations whose live recipe or mastery inputs can be evaluated. The compact panel intentionally omits the generated base-level range, standalone level-to-500 estimate, duplicate mastery-fodder count, and obsolete read-only preflight row. Show an em dash for unknown replacement or blessing-unlock costs instead of folding invented values into the total. Currency values use readable 24 px vanilla Docket, Plasteel, and Diamantine icons; text remains present for accessibility and exact values.

Estimate is informational. Hard limits are authoritative. Add:

- maximum Ordo Docket search spend, controlled by checkbox plus 100,000-step arrows/slider;
- maximum purchase count and runtime;
- optional Plasteel and Diamantine caps;
- a reserved final-craft material budget, so fodder upgrades cannot consume resources needed for selected final steps;
- `Proceed with best found if exact 60 is not found` checkbox.

Before every request, project that request's maximum known cost. Do not issue it if confirmed spend plus projected cost exceeds cap. Backend wallet/cost reads remain final authority.

### Best-candidate fallback and sacrifice interaction

When fallback is enabled, retain one best-so-far candidate from the first valid roll. Never sacrifice or discard it. Compare candidates lexicographically:

```text
1. smallest abs(selected_dump_stat - 60)
2. largest discovered `damage` stat, or configured priority stat when `damage` is absent
3. largest total non-dump base-stat value
4. earliest purchase index (deterministic tie-break)
```

When a better candidate arrives, demote the old reserve to fodder only after normal protection checks. This allows nearly every imperfect roll to feed mastery while preserving a usable fallback.

At search-cap exhaustion:

- fallback off: retain best candidate for review, halt before final crafting;
- fallback on: promote best candidate and continue selected final steps;
- no valid candidate: halt with no further mutation.

If exact target appears before mastery reaches 20, retain it and continue buying fodder-only copies until the fast mastery gate is complete. Final target and current fallback reserve must never enter sacrifice sets.

## Standalone-extraction requirement

Auto Crafter starts as a BetterInventory module but should be architected as an independently releasable mod from first commit. BetterInventory is a host/integration, not core domain owner.

### Dependency rule

Core Auto Crafter files must not:

- call `get_mod("BetterInventory")` at module scope;
- import `BetterInventory_*` policy, settings, layout, customization, diagnostics, or transaction files directly;
- read/write BetterInventory-private tables or `view._better_inventory_*` fields;
- assume BetterInventory Armoury panel exists or controls geometry/focus;
- use BetterInventory setting IDs as domain state;
- require BetterInventory-specific item wrappers, sorting data, or persistence formats.

Bootstrap/host layer may inject optional adapters. Every core dependency should be explicit constructor input with a small documented interface. Missing optional capability must degrade one feature, not prevent purchase/crafting/mastery core from loading.

### Portable package layout

Keep relocatable implementation under a neutral subdirectory even while shipped inside BetterInventory:

```text
auto_crafter/core/controller.lua
auto_crafter/core/policy.lua
auto_crafter/core/planner.lua
auto_crafter/core/mastery.lua
auto_crafter/core/journal.lua
auto_crafter/darktide/backend.lua
auto_crafter/darktide/catalogue.lua
auto_crafter/darktide/context.lua
auto_crafter/ui/brunt_panel.lua
auto_crafter/ui/inventory_entry.lua          (later)
auto_crafter/integrations/naming.lua
auto_crafter/integrations/host.lua

BetterInventory_auto_crafter_bootstrap.lua  BetterInventory composition only
```

Relocatable files receive `mod`/services/capabilities through constructors and avoid hardcoded host filesystem prefixes. Standalone extraction should require new manifest/bootstrap/settings/localization packaging plus optional migration—not controller/backend rewrite.

Recommended injected capabilities:

```lua
capabilities = {
    settings = { get=..., set=..., is_enabled=... },
    localization = { text=... },
    logger = { debug=..., info=..., error=... },
    reporter = { emit=... },
    persistence = { load=..., save=... },
    operation_gate = { acquire=..., release=..., conflicts=... },
    naming = { available=..., provider=..., get=..., rename=... }, -- optional
    clock = { now=... },
}
```

Core tests use fake capabilities. Darktide backend adapter may depend on `Managers.data_service` and vanilla item utilities; that is game coupling, not BetterInventory coupling.

### Settings and saved-state portability

Use stable `auto_crafter_*` setting/run-journal keys now. Host settings adapter maps those keys into BetterInventory DMF options. Later standalone version can import/copy values once, tagged with schema version. Never serialize Lua functions, view objects, offer objects, full item instances, or BetterInventory-private records into recovery journal.

### Optional naming integration

Rename is not an Auto Crafter core capability and must default off.

At UI composition/preflight, capability resolver checks supported adapters:

- BetterInventory naming adapter, exposed through a narrow stable function rather than direct customization-store access;
- Name It adapter, only if mod is loaded and a tested callable naming contract is available;
- no provider: rename checkbox/text/provider controls are gray, value remains off, tooltip says install/enable BetterInventory or Name It.

If both providers exist, `Automatic` selects one deterministic tested provider and never writes both. Expose explicit provider dropdown for troubleshooting. If selected provider disappears, errors, or changes version during run, skip rename with warning after final weapon verification; do not fail otherwise successful craft. Provider writes remain keyed by stable final `gear_id`.

## Recommended Auto Crafter architecture

### New module boundaries

Do not place state machine in `BetterInventory_runtime.lua` or existing Armoury panel. Follow neutral portable package layout above. BetterInventory bootstrap should only construct capabilities, register settings/localization, attach lifecycle hooks, and start/stop portable controller/UI.

Keep Darktide backend adapter thin. Put decisions in pure policy/planner/controller modules so tests use deterministic fixtures. UI consumes controller snapshots/events; controller never imports UI.

### Existing BetterInventory components available through adapters

- `BetterInventory_operation_arbiter.lua`: bootstrap adapter can bridge owner/token acquire/release so Auto Crafter cannot race automatic curio acquisition or discard. Standalone host supplies equivalent local gate.
- `BetterInventory_discard_policy.lua` and transaction: optional protection adapter may contribute extra vetoes; core Auto Crafter still owns minimum final/reserve/fodder safety policy.
- `BetterInventory_item_customization_store.lua`: optional naming provider behind stable adapter.
- `BetterInventory_diagnostics.lua`: optional log sink; core journal/report schema remains neutral.
- Existing settings/localization system: host registration only; controller sees neutral capabilities.

Do not reuse `BetterInventory_armoury_panel.lua` as required runtime dependency. Visual patterns may be copied/refactored into neutral Auto Crafter UI, but its panel must initialize, position, focus, update, and destroy independently. This is essential for standalone extraction.

### Single active run model

Only one Auto Crafter run may exist per local account/character.

Run identity:

```lua
run = {
    id = monotonically_increasing_generation,
    account_id = "...",
    character_id = "...",
    target = immutable_target_snapshot,
    limits = immutable_limit_snapshot,
    state = "preflight",
    cancel_requested = false,
    dispatch_closed = false,
    context = "morningstar",
    in_flight = nil,
    expected_final_fingerprint = nil,
    external_change_policy = "reconcile_compatible",
    notification_sequence = 0,
    confirmed_spend = { credits=0, plasteel=0, diamantine=0 },
    purchased_ids = {},
    retained_ids = {},
    fodder_ids = {},
    failed_ids = {},
    journal = {},
}
```

Every promise continuation must verify:

- controller still exists;
- run ID/generation still matches;
- account and character still match;
- expected state still matches;
- view destruction does not invalidate required UI access.

Backend controller must not depend on view staying open. UI can detach and reattach to current run, or cancellation can stop after the current in-flight mutation settles.

### State machine

```text
idle
  -> preflight
  -> awaiting_confirmation
  -> refresh_authoritative_inputs
  -> search_purchase
  -> inspect_purchase
      -> promote_exact_target             (exact selected stat = 60)
      -> replace_best_reserve             (better fallback candidate)
      -> prepare_fodder                    (miss, mastery still needed)
      -> retain_or_review_miss             (not safe/needed as fodder)
  -> consecrate_fodder_to_redeemed
  -> sacrifice_fodder
  -> mastery_fast_gate
      -> search_purchase                   (search and/or mastery incomplete)
      -> reward_sync_wait                  (XP-derived mastery level 20)
  -> reward_sync_wait
      -> claim_reachable_tiers
      -> poll_rewards
      -> interleave_safe_final_step        (optional, between poll timers)
  -> allocate_target_blessing_points
  -> allocate_remaining_points             (only selected policy)
  -> consecrate_final_to_transcendent
  -> empower_final_to_500
  -> replace_perks
  -> replace_blessings
  -> favorite_final
  -> rename_final
  -> verify_final
  -> complete

Any state -> cancel_pending -> canceled after current request settles
Any state -> context_exit_pending -> stopped after current request settles
Any final-item state -> external_change_detected -> reconcile / pause / stop by policy
Any ambiguous/error state -> halted with journal and recovery instructions
```

Not every run uses every state. Compile the user’s selected feature set into an explicit plan during preflight.

Search and mastery have separate completion conditions:

- Exact target found first: protect target, then continue fodder-only purchases until mastery fast gate completes.
- Mastery completes first: stop upgrading/sacrificing misses immediately, but continue ordinary search until target or cap.
- Search cap reached with fallback enabled: promote best reserve and stop search.
- Both complete: enter reward synchronization/finalization.

Default scheduling must not run mutations against the same ordered resource concurrently. Brunt purchases remain one-at-a-time because they share a wallet transaction ID. Phase 3 has one explicit allowlisted exception: at most two independent fodder rarity upgrades may overlap each other and the next ordered Credits purchase while the run owns the mutation arbiter. Extraction waits for every worker and one authoritative gear refresh. No other mutation pair is parallelized. During reward-sync backoff, default mode may interleave one independent final-item mutation before the next read. Empowering beyond current claimed cap must wait.

Experimental parallel scheduling is documented below. State-machine dependencies remain identical; only scheduler dispatch changes.

### Reference orchestration algorithm

Use this order unless live contract testing proves a prerequisite differs:

```text
1. Snapshot options/limits; discover and validate weapon/stat/perk/blessing IDs.
2. Refresh offer, wallet, inventory capacity, final-craft costs, and mastery.
3. While search incomplete OR mastery XP below 20:
   a. Check cancellation, runtime, purchase count, Docket cap, capacity, and material reserve.
   b. Purchase exactly one weapon and inspect canonical base stats.
   c. Protect exact target; otherwise update protected best-so-far reserve.
   d. If mastery still below 20, and item is neither target nor best reserve:
      consecrate it to Redeemed, verify gear, sacrifice it, record returned XP.
   e. If returned/local derived XP reaches 20, close mastery-spending gate immediately.
   f. If search cap is reached, either promote best reserve or halt according to fallback option.
4. Require one protected final candidate. Never submit it to destructive operations.
5. Start non-blocking reward convergence: fetch, claim reachable tiers, fetch, refresh points/sticker book.
6. Between scheduled polls, optionally run one safe independent final step. Sequential mode never overlaps mutations; experimental mode only overlaps operations allowed by its conflict matrix.
7. Once rewards converge, buy selected blessing tiers first; spend remainder only by chosen policy.
8. Verify/perform Transcendent rarity and expertise 500 as selected and permitted.
9. Replace selected perks, then blessings; verify each returned gear snapshot.
10. Verify complete final item, then favorite and rename. Emit run summary.
```

If mastery reaches 20 before exact target, step 3 continues purchases but skips fodder upgrade/sacrifice. If exact target arrives before mastery 20, it remains protected while later misses feed mastery. This prevents both over-sacrifice and target loss.

### Why a controller is required instead of chained UI callbacks

The full workflow may involve dozens of purchases and mutations. A controller provides:

- one mutation at a time;
- exact cancellation boundary;
- immutable target and spend limits;
- retry policy by operation type;
- state reconstruction after each authoritative result;
- useful diagnostics without relying on notification spam;
- testable state transitions independent of rendered widgets.

## Preflight and confirmation design

Before enabling Start, resolve and display:

- selected archetype/character;
- selected Brunt weapon offer and mastery family;
- target dump stat and exact criterion;
- target rarity/expertise/perks/blessings;
- current mastery level, claimed level, points, and expertise cap;
- estimated minimum/likely/maximum spend;
- hard purchase-count cap;
- hard credits/Plasteel/Diamantine caps;
- failure-item policy;
- whether final favorite/name are local-only;
- whether auto-discard and auto-sacrifice are enabled.

Require explicit confirmation for any automated spending. Require a stronger second opt-in for auto-sacrifice or auto-discard because those delete gear.

Recommended controls:

- dry run / preview only;
- stop after target weapon found;
- stop after mastery reaches 20;
- maximum purchases;
- maximum spend per currency;
- maximum runtime;
- keep all failures / review / auto-discard;
- never sacrifice items over rating threshold;
- never sacrifice a dump-stat match;
- favorite final item;
- custom final name;
- Cancel button always visible while running.

## Retry, idempotency, and ambiguity policy

### Safe reads

Catalogue, wallet, gear, mastery, and sticker-book reads can be retried with bounded backoff.

### Mutations are not blindly retryable

Purchase, consecrate, empower, replace, trait purchase, sacrifice, and delete may have succeeded even if client receives timeout/error. Before retrying:

- **Purchase**: refresh gear/wallet and determine whether a new expected item/transaction appeared.
- **Consecrate/empower/replace**: fetch gear by ID and compare current state to requested postcondition.
- **Blessing purchase**: refresh sticker book and check ownership.
- **Sacrifice/delete**: refresh gear; missing item can mean success. Refresh mastery to validate XP delta.

If postcondition proves success, advance without retry. If it proves no mutation, retry within cap. If result is ambiguous, halt and ask user to inspect rather than risk duplicate spending or destroying another item.

### Monotonic invariants

- confirmed spend never decreases;
- mastery XP/claimed level never decreases within one run;
- rarity and expertise never decrease;
- a `gear_id` belongs to exactly one set: purchased, retained, fodder, failed, sacrificed/deleted;
- final retained item is never submitted to sacrifice/delete;
- each mutation has exactly one journal entry with pending -> confirmed/failed/ambiguous outcome.

## Manual or external item modification during a run

User, another mod, or delayed backend response may modify final weapon while Auto Crafter is active. Controller cannot reliably identify actor; treat any authoritative drift from expected item snapshot as an external change.

### Detecting drift

Keep stable `gear_id` plus compact expected fingerprint after every confirmed response:

```lua
fingerprint = {
    gear_id = "...",
    master_id = "...",
    rarity = 3,
    expertise = 300,
    perks = { canonical_ids_and_tiers },
    traits = { canonical_ids_and_tiers },
    favorite = false, -- local state, if relevant
}
```

Before every final-item mutation, fetch/resolve current authoritative gear and compare it with fingerprint. Also compare every mutation response before planning next step. Inventory-change events may mark fingerprint dirty, but event alone is not authority.

Vanilla UI does not participate in BetterInventory operation arbiter. If player submits a manual Hadron action against same item while mod request is already in flight, ordering is ambiguous even when final snapshot appears compatible. Treat this as `ambiguous`, reconcile after both observable operations settle, and stop/pause—do not automatically continue.

Where practical, hook vanilla crafting-operation start callbacks only to detect conflict: close Auto Crafter dispatch gate before player action and show warning that run will reconcile. Do not block player's manual action. Inventory/detail UI should visibly mark final item `Auto Crafter active` and offer Pause/Cancel before manual editing.

Classify differences:

- `compatible_progress`: same `gear_id`/weapon identity and change moves toward or already satisfies configured target;
- `compatible_replan`: same identity, still craftable, but costs/remaining steps changed;
- `conflicting`: user changed a configured perk/blessing away from target, cap/prerequisite changed, or result cannot be safely interpreted;
- `missing_or_replaced`: gear deleted, sacrificed, unavailable, or identity mismatch;
- `ambiguous`: refresh failed or concurrent mutation may still be settling.

### Policy behavior

`Reconcile compatible changes` is default:

- adopt monotonic progress and recompute plan/cost from current state;
- never replay fixed increments or assume previous value;
- skip any postcondition already satisfied;
- pause for confirmation on conflicting changes;
- stop on missing/replaced/ambiguous state.

Example: mod confirms expertise 200 -> 300; user manually empowers same `gear_id` to 310; next refresh adopts 310 and requests remaining target 500, subject to current cap/cost. It must not retry 300 or assume a fixed `+200` operation.

`Pause and ask` closes dispatch gate on any fingerprint change and offers `Adopt current item and replan` or `Stop`. `Stop safely` closes dispatch gate on any external change, lets current request settle, reconciles it, releases ownership, and reports retained item/current state. No policy may overwrite a conflicting user change silently.

Recompute estimated remaining materials after adopted change. Confirmed historical spend stays unchanged. If user manually spends resources so next step exceeds hard cap/reserve, halt normally.

## Polling design for lazy mastery synchronization

### Two distinct completion gates

Do not model mastery as one boolean.

1. **Fast mastery-XP gate**: local preview/returned sacrifice XP or a fresh track read derives level 20. This matches observed Quick Level Mastery behavior where Sacrifice becomes gray immediately. As soon as this gate is true, stop buying mastery-only fodder, stop consecrating fodder, and stop sacrificing. Extra spending here is wasteful even if rewards are stale.
2. **Slow reward-convergence gate**: claimed tier, usable mastery points, sticker-book state, and expertise cap have caught up. Blessing allocation/replacement and empowerment to 500 wait for their required parts of this gate.

Fast gate may use returned XP plus vanilla milestone math for immediate stopping, but it is not authority for reward availability. Slow gate always uses fresh service reads.

Represent both explicitly:

```lua
mastery = {
    xp_level_complete = false,
    authoritative_xp_complete = false,
    claims_complete = false,
    points_available = 0,
    required_points_available = false,
    expertise_cap = 0,
    sticker_book_fresh = false,
    rewards_converged = false,
}
```

Poll from controller timer/promise scheduling, never a tight `update()` loop. Permit at most one mastery read/claim request in flight. Recommended initial delay is 0.5-1 second, then bounded exponential backoff with jitter and a deadline. Reset backoff when monotonic progress appears. UI status should say `Mastery 20 reached; waiting for reward synchronization` so player understands why crafting has paused.

### Inputs

- `mastery_id` and resolved `track_id`;
- pre-sacrifice fresh mastery snapshot;
- XP amount returned by `extract_weapon_mastery`;
- target max level and downstream requirements.

### Expected-progress calculation

```text
expected_min_xp = pre_sacrifice.current_xp + returned_amount
```

Accept fresh mastery state only when:

- same mastery/track identity;
- `current_xp >= expected_min_xp`, unless backend clamps at max XP;
- derived level is consistent with milestones;
- claimed level is monotonic.

Then call sequential tier claims for all reachable unclaimed tiers. Fetch again. If downstream operation needs expertise 500, additionally require `get_current_expertise_cap(fresh_mastery) >= 500`. If blessing points are needed, fetch sticker book and compute available points from fresh claims/traits.

### Poll result types

- `converged`: all required postconditions true.
- `progressing`: XP/claims advanced but not complete; continue polling.
- `stale`: no change yet; continue within deadline.
- `inconsistent`: identity/regression/impossible milestone result; halt.
- `timeout`: preserve run state and instruct user to back out/reopen mastery UI or reconnect, then offer Resume Sync—not Resume Spending.

After timeout, never buy more fodder until a fresh authoritative read proves mastery is still below target. This directly prevents the stale-level overbuy concern.

### Safe latency overlap

Reliability takes priority over maximum throughput. Never fire crafting and mastery mutations simultaneously. While waiting for next scheduled poll, controller may perform a single independent final-item action whose prerequisites are already authoritative, then resume polling:

- favorite/rename should still wait until final item verification;
- rarity consecration can usually proceed because it does not consume mastery points;
- expertise may proceed only to currently claimed cap; target 500 waits if cap is stale;
- blessing purchase/allocation and blessing replacement wait for fresh point/sticker-book state;
- perk replacement is technically independent, but first release should defer replacements until final candidate, rarity, and expertise are verified to simplify recovery.

This overlaps backend waiting time without concurrent wallet/cache mutation or complex rollback.

## Morningstar, mission, loading-screen, and operative-selection lifecycle

Auto Crafter is Morningstar-only. Valid execution context requires:

- `GameplayStateRun` active;
- current game mode `hub` or `hub_singleplay`;
- valid local player and unchanged character/account;
- no operative-selection/loading transition;
- controller dispatch gate open.

BetterInventory already distinguishes these contexts: `mod.on_game_state_changed` handles `GameplayStateRun` enter/exit, `MainMenuView` hooks identify Operative Selection, and automatic curio/discard code checks `hub`/`hub_singleplay`. Reuse one shared context guard rather than inventing a second lifecycle interpretation.

On mission start, `GameplayStateRun` exit, loading screen, disconnect, character change, or entering Operative Selection:

1. synchronously set `dispatch_closed = true` before any next state can enqueue work;
2. cancel poll timers, queued reads, notification timers, and cancellable read promises;
3. do not attempt to cancel or duplicate an account mutation already submitted;
4. let in-flight continuation record/reconcile result, but forbid it from dispatching next operation;
5. persist bounded pending-operation/recovery marker if result remains unknown through transition;
6. release arbiter ownership after settlement/reconciliation;
7. mark run `stopped_context_exit`, not success, and show summary next safe Morningstar entry.

Default first-release behavior is graceful stop, not automatic pause/resume. Loading screens may destroy managers/views or delay callbacks; continuing unseen account mutations is not worth saved time. Closing only Armoury view while remaining in valid Morningstar may detach UI while controller continues, as already described.

Later recovery may offer manual `Resume` only after fresh account, character, gear, wallet, mastery, store, and cost reads. Never resume from pre-loading cached objects. If character differs, keep run read-only for report/review and require original character before continuation.

## Performance, stability, and crash containment

### Runtime budget

Idle cost should be effectively zero when Armoury panel/run is absent. During a run:

- controller `update()` performs O(1) timer/state checks only;
- inspect each purchased item once; pre-index its small `base_stats` array by canonical name;
- never scan full inventory, store, master-item database, or sticker book every frame;
- discover/sort UI choices only on view entry or dirty-key change;
- rebuild widget layouts only when displayed state/options change;
- keep journal, histograms, and retained ID sets bounded; do not retain duplicate full item snapshots;
- avoid per-frame table clones, string formatting, sorting, Promise creation, and backend reads.

Cache discovered catalogues by stable keys and invalidate deliberately. Record lightweight counters/timings (`purchases`, `polls`, `layout_rebuilds`, `policy_eval_ms`) so profiling can find regressions. Set numeric CPU/memory budgets only after live profiling across supported hardware; architectural rule is event-driven work, not frame-driven polling.

### Reliability-first scheduling

- One global account mutation in flight across Auto Crafter, auto-curio, discard, and overlapping mods.
- Reads may only overlap when service/cache contracts are known safe; conservative default serializes them around mutations.
- Use one-item fodder batches initially. Add predictive batches only after live proof and never beyond needed XP.
- Refresh authoritative item/wallet/mastery state after ambiguous results instead of guessing.
- Bound purchases, spend, runtime, retries, poll deadline, queue length, journal length, and histogram samples.
- Pause when inventory capacity, wallet, offer identity, character, or network state changes.

### Optional asynchronous/parallel request scheduling

All modes are asynchronous and non-blocking from UI perspective. Dropdown controls **request overlap**, not whether promises/timers are used:

| Mode | Default | Maximum overlap | Intended behavior |
| --- | --- | --- | --- |
| `Sequential (recommended)` | **Yes** | one backend request total | Strongest ordering, cache consistency, reconciliation, and account safety. |
| `Parallel reads` | No | two allowlisted reads; one mutation maximum | Overlap independent catalogue/wallet/mastery/sticker-book reads when no mutation dependency exists. |
| `Experimental parallel mutations` | No; hidden behind advanced warning | two allowlisted requests maximum | Future profiling/testing mode. Only explicitly proven operation pairs may overlap. Never treat this as unrestricted concurrency. |

Changing mode requires no active run. Snapshot mode into run plan; do not permit mid-run switching. Selecting experimental mutation mode requires a per-version warning/confirmation explaining possible rejected requests, stale caches, duplicate/ambiguous spending, lost gear/materials, service impact, and unsupported account recovery.

#### Conflict matrix

Dispatcher must assign resource keys to every request and reject overlap on any shared key:

```text
account, character, store_transaction, wallet:<currency>, gear:<gear_id>,
mastery:<track_id>, sticker_book:<trait_category>, inventory
```

Initial rules:

- Brunt purchases are always sequential because store flow advances a latest transaction identifier and changes inventory/wallet.
- Two operations touching same `gear_id` never overlap.
- Consecrate/empower/replace operations sharing crafting wallets remain sequential until live tests prove cache updates and server ordering safe.
- Sacrifice never overlaps purchase, gear mutation, deletion, or another sacrifice.
- Tier claims and blessing purchases never overlap each other or mastery-dependent final crafting.
- Poll/read results started before related mutation completion are tagged potentially stale and cannot satisfy convergence.
- Favorite and rename are local; they may run together only after final backend verification.

Therefore first shipped `Parallel reads` mode gains latency only from independent reads. `Experimental parallel mutations` infrastructure may exist, but its mutation allowlist starts empty. Add operation pairs one at a time only after contract, timeout, out-of-order response, wallet-cache, and disconnect tests pass for current game version. This preserves user option without pretending unsafe combinations are proven.

#### Parallel-mode safeguards

- concurrency cap fixed at two initially;
- token-bucket/request-rate cap plus bounded queue;
- per-operation dependency/resource-key declaration required—missing declaration forces sequential dispatch;
- first ambiguous, throttled, out-of-order, or inconsistent result disables parallel dispatch for remainder of run;
- fallback to reconciliation, then sequential mode; never retry both members blindly;
- kill switch by game-source/version compatibility table;
- diagnostics record start/end ordering, resource keys, response status, and reconciliation result without auth data;
- dry-run scheduler visualizer shows which operations would overlap before experimental mode can spend.

Fatshark policy explicitly warns against mods that affect game-service stability and does not promise recovery for mod-caused gear/currency loss. Parallel mode must be described as experimental performance tuning, not recommended normal operation. It must never bypass costs, progression, or ordinary operation eligibility.

### Crash guards and lifecycle safety

- Attach `:catch(...)` to every Promise chain; no unhandled rejection and no `error()` for recoverable backend failures.
- Wrap mod-owned callback boundaries and pure policy evaluation with `xpcall`/`pcall`; convert failures into a halted run plus diagnostic.
- Every continuation validates controller existence, run generation, account/character, expected state, and target `gear_id`.
- View widgets are optional observers. Never dereference destroyed view/widget objects from backend callbacks.
- Release operation-arbiter token in success, failure, cancellation, stale-generation, and view-destruction paths.
- Cancel timers and detach listeners on unload; stale callbacks become no-ops through generation guards.
- Keep final target and best reserve in explicit protected sets checked again immediately before destructive calls.
- On mod reload/crash, do not auto-resume spending. Reconcile wallet/gear/mastery from fresh reads, then offer `Resume Sync` or reviewed continuation.

Prefer slower verified progress over speculative retries. A few extra reads/seconds cost less than duplicate purchases, lost materials, or accidental sacrifice.

## Progress reporting: native notifications and optional chat

Native notifications are enabled by default. BetterInventory already sends guarded `event_add_notification_message` events for automatic curio/discard results; reuse a small Auto Crafter reporting adapter rather than invoking UI widgets directly from controller.

Default `Milestones` notifications:

- run started with target and hard budget;
- first purchase and every tenth purchase with spend and best confirmed result;
- exact target found or fallback promoted;
- favorite confirmation when enabled;
- mastery only when authoritative mastery level increases, always showing current/max level;
- Transcendent/500/selected replacements completed as applicable;
- context-exit stop, user/external-change pause, timeout, ambiguity, or hard-cap halt;
- final completion with item name and confirmed spend.

Do not notify every poll, rarity upgrade, sacrifice, claim, or purchase by default. Unchanged mastery polls never notify. Coalesce repetitive purchase progress into latest summary, rate-limit noncritical messages, and deduplicate by `(run_id, notification_sequence, event_kind)`. Suggested live text:

```text
Purchased 20 weapons. Spent 232,000 Ordo dockets. Best result: Assault Chainaxe — Mobility 59, item level 320
Weapon mastery reached level 12/20.
Stopped after reaching Ordo dockets limit.
```

`Every confirmed step` may report each purchase/consecrate/sacrifice/craft postcondition but still suppress polls with no change. Errors, ambiguity, completion, and destructive stops bypass ordinary throttle.

Optional chat mirror is disabled by default. It must write only to local/system/mod chat output (for example a DMF local echo adapter), never send party/team messages or network chat. If no safe local-chat API exists for current framework version, disable setting with explanation. Notification failure must never fail run; wrap dispatch in `pcall`, record one diagnostic, then continue without recursive error notification.

Controller emits structured progress events; reporter chooses native notification, local chat, panel status, and journal sinks. This keeps transaction logic independent from presentation and prevents stale callbacks from announcing old runs.

## UI integration recommendation

Add an **Auto Crafter Helper** section to Brunt’s `CreditsGoodsVendorView`/Armoury Exchange requisition window. Auto Crafter owns this injection and widget; BetterInventory Armoury panel must not be required.

### Self-owned Brunt widget integration

Portable UI layer should hook vanilla `CreditsGoodsVendorView` lifecycle through thin host/bootstrap registration, identify Brunt requisitions from vanilla view/store context, then create its own managed `ViewElementGrid` or dedicated view element through `view:_add_element`. Use unique Auto Crafter reference names and a weak view registry; never store state under `_better_inventory_*` fields.

Widget module owns:

- scenegraph definitions, frame/background, clipping, scrolling, option rows, and Craft/Cancel controls;
- setup on valid Brunt view enter, dirty/event-driven update, and complete teardown on exit;
- mouse/controller focus capture and restoration without calling BetterInventory focus helpers;
- safe reattachment to controller snapshot after layout rebuild or view reopen;
- geometry at supported resolutions/UI scales;
- collision handling when BetterInventory or another mod adds adjacent panels.

Default geometry should be valid against unmodified vanilla Brunt view. Optional host-layout capability may suggest free rectangle/offset when BetterInventory is present, but absence/failure falls back to standalone geometry. Controller and feature availability must not depend on layout negotiation.

Hook callbacks should be idempotent: mark exact Auto Crafter element/reference, tolerate duplicate setup calls, and destroy only elements owned by Auto Crafter. Never replace vanilla purchase callback or simulate button clicks; controller invokes service adapter directly.

Suggested two-stage UI:

1. Compact Armoury panel:
   - Mode: Find Weapon / Level Mastery / Full Craft.
   - Mandatory dump-stat selector and target value.
   - Quick target summary.
   - Configure button.
   - Single-line `Craft — est. <dockets> / <plasteel> / <diamantine>` button; replace with Cancel while active.
   - Live state, count, and spend.

2. Configuration popup/view:
   - all six feature toggles;
   - dependency-disabled child checkboxes/selectors matching the product configuration table;
   - perk/blessing selectors;
   - 100,000-step Docket cap and best-candidate fallback option;
   - rarity/expertise targets;
   - limits and destructive policies;
   - preflight estimate and confirmation.

Expose the complete workflow policy in the self-owned scroll panel before later backend phases are connected. Split it into independently collapsible Search and limits, Crafting workflow, Perk and blessing targets, Final item handling, Advanced and safety, and Weapon selection sections. A later configuration popup may provide richer searchable perk/blessing catalogues, but every persisted toggle and target policy must remain visible and understandable from Brunt's Armoury.

Use a managed `ViewElementGrid` or dedicated view element for clipping, scrolling, controller navigation, and lifecycle. Keep Auto Crafter state in controller, not widget content. Shared visual constants must live inside neutral UI package or vanilla-derived adapter, not BetterInventory feature modules.

### BetterInventory visual-language contract

The embedded Auto Crafter panel should look like a sibling of BetterInventory's inventory options panel, not a separate diagnostic overlay. This is a presentation contract, not a runtime dependency: Auto Crafter locally owns vanilla-derived pass templates and must not import `BetterInventory_panel_definitions.lua`.

- Keep the 445 px outer panel and terminal frame, with 12 px horizontal content padding, 10 px top/bottom padding, and an 8 px vertical rhythm. `ViewElementGrid.edge_padding` is centered, so use 24 px edge padding with a 421 px grid/content width to produce a real 12 px inset without enlarging the 445 px frame.
- Anchor the panel to Brunt's native selected-weapon frame, not the physical screen edge. Resolve `view._ui_scenegraph.info_box` (the frame parented to the Acquire/Sacrifice `purchase_button`) and place the helper 72 virtual units to its right, with its top at `canvas` top + 110. Clamp against the aspect-expanded virtual viewport derived from `RESOLUTION_LOOKUP / render_scale`, recompute on resolution/UI-scale changes, and retain a right-edge fallback only when native nodes are unavailable. Because Brunt's 1920x1080 canvas remains centered, this preserves X=1380 at 16:9, X=1710 at 3440x1440, and X=2340 at 5120x1440 instead of stranding the panel at the far ultrawide edge.
- Reserve full-width framed rows for hierarchy and decisive interaction: 40 px title/section headers, 32 px offer choices, and 32 px primary actions. Do not put a frame around every diagnostic label/value pair.
- Render short status, resources, inventory count, and target data as quiet 26 px label/value lines. Give longer estimate/preflight text an unframed two-line status block so it remains readable instead of competing for a narrow right column. Labels use bold terminal body text; values use the subdued sub-header color.
- Render enum settings as explicit `< value >` controls, booleans as 22 px checkboxes with adjacent labels, and bounded numeric settings as steppers. Numeric value boxes must accommodate formatted values through `10,000,000`; request mode must have separate previous/next hotspots rather than relying on an ambiguous whole-field click. These dimensions, typography, and colors should match inventory controls.
- Dump stat is a contextual indexed enum control: its arrows wrap through the selected weapon template's complete localized base-stat catalogue. Directly below the arrow selector, render the same candidates as synchronized shortcut buttons: up to three buttons on the first line and the remaining two on the second line. The active candidate uses the inventory-style gold selected treatment; clicking any button updates the same saved canonical key as the arrows, so neither control owns separate state. Common stats use the fixed semantic priority Damage, Mobility, Finesse, First Target, Penetration; remaining weapon-specific stats follow deterministically. Changing weapons resets both controls to visible index 0. Labels use vanilla text such as `Finesse`, never raw implementation IDs. Because these are nested hotspots inside a `ViewElementGrid` row, dispatch clicks from a widget logic pass by consuming each hotspot's `on_pressed` state; direct nested `pressed_callback` wiring is not a reliable Darktide input path.
- Present the two optional acquisition limits as explicit checkboxes: `Cap perfect-roll weapon acquisition by Ordo dockets` above `Ordo dockets cap`, and `Cap perfect-roll weapon acquisition by max purchases` above `Max purchases`. Hide each numeric stepper until its matching checkbox is enabled, but preserve its saved value while hidden.
- Require at least one of the two acquisition-cap checkboxes before enabling a mutation search; this prevents an accidentally unbounded purchase loop while still allowing either cap to be used independently.
- Use gold only for selected offers and enabled primary actions. Disabled actions retain terminal background, remain visibly inert, and expose no active hotspot.
- Keep section headers full-width with a right chevron and optional count. Search limits, workflow, trait targets, final handling, and advanced safety collapse independently; less-frequent target/output/advanced sections start collapsed. Do not duplicate Brunt's native Melee Weapons and Ranged Weapons lists inside the helper panel.
- Section headers contain only hierarchy text and chevron unless a compact count materially helps navigation. Do not place `UI PLAN`, discovery diagnostics, or other redundant right-column copy in headers.
- Perk and blessing targets are contextual enum steppers populated only from the selected weapon's live compatible catalog. Synthetic `Keep current`, `Auto-select`, and auto-discovery choices are intentionally absent: enabling trait replacement means choosing concrete results. Perk labels must use the exact vanilla Refine Item path, `Items.trait_description(perk_item, tier, 1)`, not `perk_item.display_name`; the latter is often an internal content path such as `Content/Items/Perks/...`. Persist perk ID and tier as one distinct option identity so equal IDs at different tiers cannot collapse into one selector value. On catalog/family change, stale targets are replaced with category defaults: melee uses Rank IV Unyielding Damage plus Carapace Damage, while ranged uses Rank IV Flak Damage plus Maniacs Damage. Blessings default to the first two distinct compatible discovered entries. Raw trait IDs never appear unless vanilla formatting genuinely fails.
- Preserve absolute scrolled pixel offset when selecting an offer, changing values, or rebuilding after collapse/expand. Capture `ViewElementGrid:length_scrolled()` before `present_grid_layout`, then restore a clamped offset through `scroll_length()` and `set_scrollbar_progress()` in the presentation callback. Same-size planner changes should refresh existing widgets; structural rebuilds still restore scroll.
- Never call `present_grid_layout` synchronously from a widget press or reporter callback. A press may trigger controller events while `ViewElementGrid` is still drawing its render target; destroying/replacing its widgets in that call stack can leave renderer/widget state nil and crash. Queue structural reflow for a later update frame, coalesce duplicate requests, and drop queued work on detach.
- Keep visible copy task-oriented: combine raw probe counts into concise summary lines, label the explicit serial Craft action clearly, and avoid exposing internal diagnostic noise as equal-weight boxed rows.
- Validate mouse and controller hit targets independently. Selector, checkbox, stepper arrows, section chevrons, offer rows, and action buttons must invoke only their own semantic action.

### Later entry point: continue crafting an existing inventory weapon

Plan this as later module/UI phase, not first release. Add an **Auto Crafter / Continue Crafting** action or compact section to weapon detail area in inventory/character equipment view. Entry passes selected `gear_id` into same controller; do not create separate crafting engine.

Existing-item preflight must:

- resolve fresh item and verify ownership, active account/character, weapon type, mastery family, and supported crafting metadata;
- discover stats/perks/blessings from selected item as usual;
- treat immutable base-stat roll as fixed—cannot search or change dump stat on existing item;
- show whether selected dump-stat criterion already matches, but disable Brunt search for that item;
- compute only remaining rarity/expertise/perk/blessing/mastery work and current live costs;
- preserve equipped/favorite/custom-name state unless user explicitly changes final options;
- reject protected, missing, pending-deletion/sacrifice, or concurrently owned items;
- use same external-change fingerprint, lifecycle guard, caps, journal, notifications, and reconciliation policies.

Distinguish two concepts:

- **Continue existing item**: new run built from a user-selected current weapon.
- **Resume interrupted run**: recovery from persisted journal after context exit/crash, requiring reconciliation before spending.

UI may prefill targets from current item and display `Already satisfied` beside completed steps. Craft button estimate excludes completed work. Never downgrade rarity/expertise or replace a user-selected perk/blessing unless current run explicitly targets a different value.

## Implementation sequence

### Current implementation status (2026-08-09)

- Phase 0 read-only service probe is implemented and validated in-game. It resolves the Brunt view, storefront, wallet, and gear data without spending or deleting anything.
- Phase 1B read-only planner is now implemented. It exposes the selected weapon template's complete base-stat catalogue, deterministic indexed manual dump-stat selection, optional Ordo dockets and maximum-purchase caps, best-candidate fallback, request scheduling mode, and selected-weapon perk/blessing catalogue discovery. Candidate discovery uses `WeaponTemplate.weapon_template_from_item(master_item).base_stats`, so weapons such as Crowbar remain selectable when Brunt exposes only `lootChoices`, no store-item preview can be instantiated, and no matching inventory item exists. Every target change resets to index 0; legacy Auto state migrates to index 0. UI labels use vanilla localization (`Finesse`, `Penetration`, and so on); canonical raw IDs remain internal. Missing or malformed catalogues block mutation rather than guessing. Selected-weapon trait discovery performs bounded sequential reads through native crafting metadata, mastery-family, and trait-sticker-book services, returning localized canonical perk IDs/tiers and valid blessing IDs/tier statuses. The panel exposes each discovered target through guarded arrow selectors and resets incompatible saved targets on weapon change. Discovery is cached per selected offer and cancelled on target/context change. The widget builds a fail-closed preflight, reports acquisition floor/cap, and models configured rarity/expertise materials from live recipes across a 290-330 starting base-level range. It deliberately shows no perfect-roll probability. Exact post-purchase item data must replace the provisional material range before mutation.
- Phase 1C guarded purchase search requires an explicit per-run Craft click. Purchases remain serialized through one exact wallet object so `lastTransactionId` advances in order. Before an exact target exists, every purchase is followed by `fetch_gear`; only that authoritative candidate may become best/exact. After the exact target is frozen, later purchases are fodder-only: their decorated purchase payload supplies temporary gear/family/rarity/expertise data for XP projection and upgrade scheduling, while one batch refresh revalidates every ID before extraction. Closing Brunt detaches only the panel; the frozen run continues while Morningstar context remains valid. Caps, wallet reserve, configuration changes, Stop, and failed reconciliation close future dispatch.
- Phase 2 one-item mastery primitive is authorized by the frozen explicit Craft run. It accepts one explicit purchased candidate, verifies it still exists and belongs to the expected weapon family, reads authoritative mastery before any upgrade, and skips all mutation if mastery is already 20. When a rarity upgrade is required, it refreshes mastery again after the confirmed upgrade and immediately before destructive extraction, trading one read for a fresher claim baseline. It upgrades to Redeemed only when needed, sacrifices exactly one `gear_id`, requires positive XP plus confirmation of that ID, verifies the item disappeared from a fresh authoritative gear read, claims tiers from the pre-sacrifice mastery object plus returned XP exactly once, then polls fresh mastery/claim state with bounded attempts. Level 20 counts as XP convergence even when backend XP is capped below the arithmetic `before + award` value. The primitive is internal to Phase 3; the unsafe standalone `Redeem + sacrifice one` widget action was removed so a completed target cannot be destroyed by an ambiguous click.
- Phase 3 mastery-to-20 uses projected XP as a conservative stop-spending gate. The exact dump-stat target is protected; run-owned misses are queued, and only the minimum prefix estimated to reach level 20 is extracted. Credits purchases remain ordered. Up to two rarity workers overlap fodder upgrades with the next purchase; each worker has generation guards and a 45-second timeout. Extraction cannot start until all selected workers settle and a single authoritative gear refresh confirms identity, family and Redeemed rarity. One multi-item extraction advances local mastery immediately; milestone claiming and bounded authoritative convergence remain the final barrier. Every surviving run-owned spare is discarded after protected reconciliation.
- Optional `Only process bad weapons after finding perfect-rolled weapon` mode changes Phase 3 ordering without weakening verification. Before an exact target exists, every authoritative miss is retained untouched in a run-owned queue; no rarity upgrade, mastery read, sacrifice, or deletion occurs. If acquisition ends at a cap without an exact target, all queued weapons remain in inventory. After an exact target is authoritative and favorited, queued misses are processed sequentially as mastery fodder. Sequential one-item preparation remains intentional because every rarity mutation, extraction, XP award, deletion, claim, and mastery increase needs its own postcondition before another destructive step. Once mastery reaches or already equals 20, remaining queued misses are discarded through Darktide's native batched gear deletion API, followed by a fresh inventory read requiring every deleted ID to be absent. Cleanup rejects the entire batch if profile, favorites, or saved-loadout protection cannot be read, or if any queued item became favorited/equipped. The exact target ID is excluded and revalidated again at final completion.
- Purchase acceptance must use the weapon's maximum level-500 stat projection, not its acquisition-time `item.base_stats`. A 290-330 weapon can temporarily show the configured dump value while later expertise upgrades raise that stat above the target. Runtime now derives `potential_base_stats` with Darktide's native `Items.preview_stats_change(item, 500 - current_expertise, comparing_stats)` path, retains raw current stats separately for diagnostics, and uses projected values for exact-match acceptance, fallback ranking, and final authoritative target reconciliation. Projection failure is fail-closed: current values cannot substitute for level-500 potential during acquisition acceptance.
- Auto Crafter UI polish is implemented before destructive phases. The 445 x 520 scroll panel now follows the inventory panel's 12 px side padding, 10 px vertical padding, and 8 px row rhythm. It uses semantic local controls instead of one frame-heavy generic row: quiet 26 px summary lines, readable two-line estimate/preflight blocks, compact selectors, 22 px checkboxes, bounded steppers, 40 px collapsible headers, gold action buttons, and gold selected offer rows. Planner setting updates refresh in place so scroll position is preserved. These visual contracts are locally owned for future standalone extraction and do not import BetterInventory panel modules.
- The 2026-08-09 estimate/perk/scroll audit corrected three misleading UI contracts. Perks now use vanilla `Items.trait_description` text and tier-qualified saved identities; internal master-item paths are never presented as names. Search caps are shown only as budgets, while consecration, expertise, mastery fodder, and known crafting investment are separate live-derived rows with 24 px currency icons. Every deferred grid rebuild restores clamped absolute scroll offset, including numeric-cap changes and section collapse/expand.
- A follow-up mastery/perk audit confirmed vanilla derives maximum selectable perk rank from claimed mastery `perk_unlock` milestone rewards through `Mastery.get_max_perk_rarity_unlocked_level`. Auto Crafter now exposes only the highest metadata rank (currently Rank IV), requires mastery-to-20 before Change perks or either perk target becomes interactive, and mirrors these dependencies in DMF options. This prevents Tier I values such as `+10% Damage vs Carapace` from becoming final plans when Rank IV `+25%` is intended.
- Trait target UI offers synchronized grids beneath the existing arrow selectors. Perks use four columns and BetterInventory's injected heavy-compression adapter; blessings use three columns and native `Items.trait_textures` icons rendered through Darktide's `traits_container` material with icon/frame shader values. Both grids grow to the discovered catalogue size and contain only concrete compatible traits. Left click assigns target 1 with a yellow highlight; right click assigns target 2 with a green highlight. Right-click routing has priority because Darktide may expose both `on_pressed` and `on_right_pressed` on the same RMB frame. Grid clicks and arrows update the same persisted targets, and pair reconciliation prevents duplicate selections by moving the displaced target to the category default or first valid distinct option. Both grids default visible, obey the same mastery/workflow prerequisites as their target selectors, and preserve the panel's absolute scroll position across reflow. Icon and compact-label formatting enter the standalone panel through optional host adapters/data fields, preserving later extraction from BetterInventory.
- Dump-stat shortcut buttons use the same in-grid hotspot-state dispatcher proven by the working perk and blessing grids. Their hotspot passes are generated only for discovered stats and intentionally have no parent-content visibility predicate. Darktide's `UIWidget` passes nested hotspot content—not widget content—to a `content_id` pass visibility function; testing `stat_count` there makes the input pass permanently invisible while parent-content visual passes remain visible. A structural regression asserts all generated stat hotspots exist without this invalid predicate. The dispatcher captures the immutable stat entry directly, each unselected button exposes hover feedback, and panel setting writes notify DMF so the controller refreshes its plan immediately.
- Click-driven phase/status changes and structural option changes queue a coalesced next-frame panel rebuild. Reporter callbacks never call `present_grid_layout` inside a `ViewElementGrid` press stack, preventing the observed nil-widget/render-target crash when `Craft / purchase search` is clicked.
- The complete planned configuration surface is implemented across DMF settings and the Brunt panel: purchase search, inventory-base reuse, mastery-to-20, mastery-point allocation, Transcendent consecration, weapon level 500 (backend operation remains `addExpertise`), perk/blessing replacement and two contextual target slots each, favorite, rename, top crafting HUD, and request mode. Trait targets themselves are selected only in Brunt because their valid values depend on the live weapon catalog. Dependency-disabled children preserve their saved values and become interactive immediately when prerequisites are enabled. The current default profile mirrors the tested full workflow: helper, 500,000-Ordo cap, best-candidate fallback, inventory reuse including favorites, deferred bad-item processing, mastery/point allocation, Transcendent/500 upgrades, perk/blessing replacement, both trait grids, result favorite, notifications, and top HUD are enabled; max-purchase cap and rename remain disabled. Default-on checkboxes preserve an explicit saved `false`; settings adapters apply defaults only to `nil` or failed reads. Exact authoritative results use guarded `Items.set_item_id_as_favorite` plus immediate `Items.is_item_id_favorited` verification when favorite is enabled. Rename remains backend-inert; Phase 4 final crafting is always serialized, while Phase 3 alone owns the bounded rarity-worker exception.
- Phase 4 final crafting starts from the explicit Craft click. After Phase 3 (or immediately when mastery leveling is disabled), it freezes the final `gear_id`, family, projected level-500 dump stat, discovered trait category, selected Tier IV perks, selected blessing tiers, and enabled final operations. It consecrates one rarity step at a time to Transcendent, advances expertise at displayed 100-level milestones to 500, distributes mastery points across every valid blessing tier when authorized, and replaces perk/blessing slots one at a time. Every mutation is followed by a fresh authoritative gear or sticker-book read; missing identity, wrong family, projected-stat drift, unconfirmed rarity/level, unseen blessing, or unconfirmed replacement stops future dispatch. Compatible manual progress is adopted because each step recomputes from current state. Weapon-level notifications are emitted only for authoritative levels divisible by 100 (normally 400 and 500 from a 290-330 Brunt weapon).
- Inventory-base reuse is enabled by default. Before spending at Brunt, the controller searches the authoritative gear snapshot for the same weapon family and exact projected dump-stat target. Matching favorite and non-favorite weapons are eligible by default, while the explicit favorite-inclusion option can still be disabled for protection. A reused item enters the same favorite/mastery/Phase-4 pipeline and produces no purchase spend. It is never unfavorited and cannot bypass final identity/stat verification.
- Inventory-base reuse now supports partially completed weapons rather than only fresh Profane candidates. Mastery `parent_pattern` remains the strongest family identity; when that metadata is absent on both sides, matching weapon-template and then exact master-item identities provide guarded fallbacks. A known mastery-family mismatch never falls through to weaker aliases. When favorite inclusion is enabled, favorite-state read failure no longer blocks reuse because both favorite and non-favorite items are explicitly authorized; with inclusion disabled, state must still be known and false. Candidate ranking first prefers complete projected profiles (all known non-dump stats at 80), then catalogue completeness/stat quality, then fewest remaining rarity/expertise/favorite/perk/blessing operations, expertise, rarity, and stable gear ID. Level-500 items use their authoritative current base stats as projected values without depending on a zero-delta preview API response. The selected candidate records a bounded `resume_analysis` diagnostic explaining family source, projected-profile quality, and estimated remaining steps.
- Final trait replacement adopts compatible partial work and orders slot changes to avoid transient duplicate traits. For example, current `[Stamina, Carapace]` to desired `[Carapace, Unyielding]` replaces slot 2 first, then slot 1. A pure two-slot swap (`[A, B]` to `[B, A]`) has no duplicate-free one-step ordering; until an explicitly costed temporary-trait strategy exists, it stops before mutation with an actionable error instead of sending a likely rejected request.
- Mastery blessing allocation follows vanilla `MasteryService.purchase_traits(pattern, operations)`, not the convenience `purchase_trait` wrapper: the latter catches a rejected backend PUT and resolves with the error, which previously made a failed request look submitted. The batch method exposes failed trait operations and performs vanilla sticker-book cache reset/warm behavior. Before allocation, Phase 4 reads live `get_traits_mastery_costs()` data, totals the cost of every `seen` sticker-book tier exactly as vanilla `Mastery.get_spent_points()` does, and applies `tierThresholds` exactly as vanilla `get_max_blessing_rarity_unlocked_level_by_points_spent()` does. It prioritizes selected blessings when legal, serially satisfies spend prerequisites, then purchases every remaining valid unseen tier so a level-20 family finishes with its full tree allocated. After every accepted allocation, Phase 4 polls a freshly reset sticker book and proceeds only when that exact tier becomes `seen`. The dedicated poll starts at 50 ms and exponentially backs off to a one-second ceiling for 12 bounded reads; mutations never overlap. HUD status reports authoritative allocated/total mastery points. Already-seen tiers and already-matching item traits are adopted. Structured backend errors are reduced to their human-readable description instead of leaking Lua `table: 0x...` identities into notifications. Perks remain Tier IV catalogue targets, require the mastery-to-20 workflow gate, and use the native `replace_perk_in_weapon(gear_id, one-based_slot, perk_id, nil, tier)` service signature. Blessings use the corresponding native `replace_trait_in_weapon` signature.
- A self-owned top-center HUD element is enabled by default and reads controller snapshots without retaining the Brunt view. It can show multiple concurrent objectives (search, mastery, rarity, expertise, trait application), remains visible in normal Morningstar and hub store/inventory views, and hides when no run is active, outside `hub`/`hub_singleplay`, or while Immaterium mission matchmaking is active. Mission matchmaking also invalidates the mutation runtime, so a pre-mission countdown closes future dispatch instead of merely hiding its status. The HUD is optional and does not own controller state.
- HUD positioning has two render paths and both must remain aspect-safe. The registered hub HUD uses a `center`/`top` scenegraph child, so Darktide recenters it automatically on resolution changes. Store and inventory overlays calculate the same top-center position from the current physical resolution divided by that view's render scale on every draw; they must not read the static `{1920, 1080}` definition stored in `scenegraph.screen.size`. Resolution-matrix tests cover 1920x1080, 2560x1440, 3440x1440, 5120x1440, and 3840x2160 for panel right anchoring and both HUD centering paths.
- The HUD visibility checkbox is an always-visible Brunt summary control and a top-level Auto Crafter DMF option, not buried among final-crafting controls. Closing Brunt preserves frozen run settings, catalogue, target identity, and planner state. Background authoritative refreshes update inventory/mastery state without rebuilding a view-dependent planner. Delayed DMF or panel-teardown callbacks are compared against the frozen run values: unchanged-value callbacks are ignored, while a genuine user configuration change still stops future account requests.
- Each run records a monotonic start timestamp plus update-time fallback and an authoritative starting wallet snapshot. Every refreshed snapshot exposes the net wallet delta as `Invested: <Ordo Dockets> | <Plasteel> | <Diamantine>` in the top HUD. Completion freezes the final delta, keeps it visible beside `Crafting complete in ...`, and includes both elapsed time and total resources consumed in the final native notification. This measures start-to-finish wallet consumption; unrelated manual spending during an active run is therefore included by design.
- Sequential requests are the default. Parallel reads and experimental parallel mutations are visible as planning choices so the eventual state machine can preserve the documented policy, but Phase 1B still performs the existing sequential read probe and blocks all mutations. Planner setting changes refresh the plan without rebuilding the offer grid, preserving scroll position.
- Phase 1A diagnostic UI is now implemented: Auto Crafter owns a separate `ViewElementGrid` attached to `CreditsGoodsVendorView`, displays live wallet/gear totals, and mirrors the weapon selected in Brunt through a thin `_previewed_offer` adapter. Earlier duplicate Melee Weapons and Ranged Weapons offer sections were retired after validation because Brunt's native catalogue already owns weapon selection; removing them reduces panel length and eliminates a second navigation surface. It does not call purchase, crafting, mastery, sacrifice, perk, blessing, favorite, or rename operations until the explicit Craft action freezes a run.
- The implementation uses the actual Brunt class and a safe `on_enter` lifecycle seam. It intentionally does not install a competing `CreditsGoodsVendorView.on_exit` hook because Quick Level Mastery already owns that risky seam; context teardown and destroyed-view checks remain fail-closed.
- Phase 4 requires live validation with a disposable test weapon before broader use, especially service cost responses, direct displayed-target expertise behavior, sticker-book cache convergence, selected-tier mastery-point cost, replacement indices, background Morningstar execution, context cancellation, and interactions with Quick Level Mastery or other mutation mods. Parallel mutation mode and rename remain intentionally inert.

### 2026-08-08 Phase 1C/2/3 and widget audit

Full source-level audit found and corrected several blockers that prior structural tests could not detect:

- Planner exposes selected price as `plan.target.price`; mutation loop incorrectly read `price_amount`, causing every Craft run to stop as `search_blocked` before its first POST. Controller now accepts the canonical planner field and behavior tests execute the public start path.
- Each run now freezes selected raw Brunt offer, identity, family, and price once at Start. Later UI selection changes cannot retarget it, and closing Brunt cannot erase it; work continues in Morningstar without retaining a live view dependency. Planner-setting changes still close dispatch gate instead of silently changing a live run.
- `Buy until dump-stat target` is no longer a misleading inert checkbox. Disabling it blocks purchase-search start explicitly.
- Phase 2 previously fetched mastery after extraction, then passed both that post-extraction XP and returned sacrifice XP to `claim_levels_by_new_exp`; this could double-count claim calculations and set an unreachable poll target. Baseline is now read before mutation and reused for both claim and convergence arithmetic.
- Purchased-item Damage tie-break no longer assumes a literal `damage` stat ID. It resolves the template's `loc_stats_display_damage_stat` identity, with bounded name fallback for `dps`/`damage`, so weapon-specific canonical IDs still support the best-candidate policy.
- Default progress reporting is human-facing and coalesced: first purchase plus every tenth purchase, exact result, favorite confirmation, readable stop/failure reasons, and actual mastery level increases. Upgrade, sacrifice, claim, polling, unchanged mastery, and fodder bookkeeping remain panel/log state only. A mastery notification is emitted only after authoritative XP and claimed-level convergence reports `current.mastery_level > pre-sacrifice mastery_level`, and displays `current/max` (for example `Weapon mastery reached level 12/20`).
- Widget now has a guarded `Stop active run` action. It closes future dispatch immediately but does not pretend an already submitted account mutation can be cancelled; button text states that in-flight request settles first.
- Workflow scope copy distinguishes connected purchase/mastery behavior from saved-only future options. User-facing experimental parallel-mutation settings remain inert; the only runtime parallel mutation is the hard-coded, bounded two-worker Phase 3 rarity allowlist described above.
- New executable controller regressions cover pre-sacrifice mastery baseline, claim input, deletion reconciliation, already-20 preservation, frozen-target rejection, live fallback retention, configuration-change stop, and explicit user stop. Static token checks remain secondary.

### Phase 0: read-only probe

- Create neutral `auto_crafter/` package and thin BetterInventory bootstrap/capability adapters first.
- Enforce no BetterInventory imports/private-field references in portable package through static test.
- Add backend adapter reads for offer, wallets, gear, mastery, crafting costs, and sticker book.
- Add diagnostic command/widget that displays resolved IDs and proposed operations.
- Inject self-owned read-only Brunt widget without relying on BetterInventory Armoury panel.
- No spending or deletion.
- Verify exact representation of named base stats and displayed 60.

### Phase 1: safe purchase search

- Implement serialized Brunt purchase loop.
- Keep every failure item.
- Stop on exact dump-stat match or hard limits.
- Keep account mutations serialized and require an explicit Craft click plus current authoritative validation; do not add a second user-facing mutation gate.
- Refresh wallet/gear/store after each settled purchase before dispatching next purchase.
- Favorite an exact authoritative result immediately when enabled so later mastery work cannot confuse or lose the protected target; retain rename for a later optional integration.
- Live-validate cancellation and stale offers.

### Phase 2: one-item mastery operation

- For one explicitly selected purchased item: consecrate to Redeemed, sacrifice, claim tiers, poll convergence.
- No automatic repeat yet.
- Treat `extract_weapon_mastery` resolution as insufficient by itself: returned `gear_id` membership and positive `amount` are required.
- Poll fresh `get_mastery_by_pattern` state on a bounded schedule; timeout stops sync work without starting another purchase.
- Verify XP amount and claimed-point behavior from multiple starting mastery levels.

### Phase 3: mastery-to-20 loop

- Repeat Phase 2 one item at a time while the Phase 3 setting is enabled.
- Keep the exact dump-stat candidate and never use it as fodder.
- Re-read mastery before each sacrifice; skip fodder once level 20 is authoritative.
- Enforce currency/purchase caps and stop spending during sync timeout.
- Reconcile the protected candidate's identity, family, availability, and dump stat before declaring completion.
- Context exit or disabling the mutation/mastery setting invalidates the generation and leaves the protected candidate untouched.
- Resumable sync-only state remains a later recovery enhancement.

### Phase 4: final crafting

- **Implemented:** freeze final identity/configuration and refresh authoritative item.
- **Implemented:** consecrate one rarity step at a time to Transcendent, verifying monotonic rarity after every request.
- **Implemented:** advance displayed expertise through the next 100 boundary to 500 using the runtime expertise multiplier, verifying every milestone and notifying only at divisible-by-100 levels.
- **Implemented:** verify the full blessing sticker book; prioritize selected tiers, satisfy live spend thresholds, allocate every remaining valid tier at mastery 20, then re-read and require every submitted tier to become `seen`.
- **Implemented:** replace selected Tier IV perks and blessings one slot at a time and verify exact ID/tier in a fresh gear snapshot.
- **Implemented:** adopt compatible user progress, but fail closed if gear ID/family/projected dump stat changes or any backend postcondition is ambiguous.
- **Deferred:** rename through optional Name It/BetterInventory provider and persisted crash-recovery journal.

### Phase 5: optimization

- Small predictive batches.
- Review/auto-discard failures via existing discard transaction.
- Better cost forecast and XP calibration.
- Optional persisted recovery journal.

### Phase 6: existing-item continuation

- Add weapon-inventory detail action/widget.
- Start same controller with selected `gear_id` and search disabled.
- Reconcile current item into remaining-step plan and delta cost.
- Add explicit separation between new existing-item run and interrupted-run recovery.
- Validate inventory/equipment view lifecycle and controller navigation.

### Phase 7: standalone extraction rehearsal

- Copy/link neutral package into minimal temporary standalone mod bootstrap.
- Supply standalone settings, localization, reporter, persistence, operation gate, and lifecycle adapters.
- Run with BetterInventory absent; Brunt widget and features except BetterInventory naming must load.
- Run with Name It only, BetterInventory only, both, and neither; verify rename capability matrix and one-provider writes.
- Verify saved-state schema migration/import without requiring BetterInventory files at runtime.
- Treat extraction failure requiring core edits as architecture defect before public release.

Do not begin with a 37-item bulk loop. Phase ordering deliberately proves each destructive boundary before scaling volume.

## Testing requirements

### Pure policy tests

- exact dump stat 60 match;
- decimal/display normalization;
- wrong stat at 60 does not match;
- multiple possible dump stats obey selected ID;
- malformed/missing base stats fail closed;
- target family/mark validation;
- rarity progression and target completion;
- expertise target/cap validation;
- perk/blessing category and tier validation;
- resource and count stop limits;
- protected-item rules.
- lexicographic best-candidate scoring with and without canonical `damage`;
- best reserve replacement never exposes current best to sacrifice;
- exact target and best fallback remain separate protected identities;
- spend projection at exactly below/equal/above Docket cap;
- final-material reserve prevents fodder overspend;
- option dependencies for mastery allocation and blessing selectors;
- dynamically discovered new weapon/stat/perk/blessing fixtures require no code-list change.
- portable core loads with fake capabilities and no BetterInventory global/module present;
- missing optional naming capability disables only rename;
- naming resolver chooses exactly one provider when BetterInventory and Name It both exist;
- provider disappearance/failure skips rename without changing completed craft result;
- static dependency scan finds no `get_mod("BetterInventory")`, `BetterInventory_*` imports, or `_better_inventory_*` fields under neutral package.

### Controller/state-machine tests

- one request in flight;
- purchase -> inspect -> next purchase;
- found target stops immediately;
- cancellation during each mutation waits safely;
- view closes while backend operation continues/settles;
- character/account changes invalidate run;
- stale promise from old generation cannot mutate current run;
- mutation timeout with postcondition success advances once;
- ambiguous mutation halts;
- no mastery XP gain halts;
- polling converges after delayed claim state;
- polling timeout disables spending;
- final item never enters discard/sacrifice set.
- fast level-20 gate immediately stops all mastery-only spend;
- stale points continue reward polling without resuming fodder purchases;
- exact target found early transitions to fodder-only search;
- mastery complete early continues search without consecrating misses;
- cap exhaustion promotes best only when fallback is enabled;
- poll timer never schedules a second read while one is in flight;
- safe final step may interleave between polls, but mutations never overlap;
- every Promise failure path releases arbiter ownership.
- sequential mode dispatches exactly one backend request at a time;
- parallel-read mode never exceeds two allowlisted reads and never overlaps conflicting resource keys;
- Brunt purchases, same-gear mutations, sacrifices, claims, and shared-wallet mutations remain serialized in every initial release mode;
- stale read launched before mutation completion cannot satisfy a postcondition;
- first ambiguous/throttled/out-of-order parallel result closes parallel lane and reconciles sequentially;
- scheduling mode cannot change during active run.
- user changes expertise 300 -> 310: compatible policy adopts 310 and replans to 500;
- user completes selected rarity/perk/blessing step: controller skips already-satisfied mutation;
- user makes conflicting perk/blessing change: no silent overwrite; policy pauses/stops;
- vanilla manual mutation overlaps mod in-flight request: classify ambiguous and never auto-continue;
- final `gear_id` disappears or changes identity: immediate safe halt;
- `Stop safely` external-change policy dispatches nothing after drift detection;
- GameplayStateRun exit/mission/loading/operative-selection closes dispatch gate synchronously;
- in-flight purchase settles after context exit: result journals, but no consecrate/follow-up starts;
- returning to Morningstar does not auto-resume spending from cached state;
- notification event deduplicates/rate-limits and stale run emits nothing;
- notification/chat adapter failure cannot alter transaction state;
- chat mirror never invokes party/team/network send path;
- existing-item preflight disables search and computes only remaining work.
- Brunt widget setup is idempotent and teardown removes only Auto Crafter-owned elements;
- controller continues or stops correctly when self-owned widget is destroyed/recreated;
- BetterInventory host adapter and standalone fake adapter produce identical controller transitions for same fixtures.
- visual contract test requires local summary, selector, checkbox, stepper, section-header, action, and offer pass families plus 12/10/8 spacing constants;
- exact 445 px frame math uses a 421 px grid with centered 24 px edge padding; first glyph/control never touches the terminal border;
- formatted Docket cap values up to `10,000,000` fit inside the numeric value frame;
- request mode previous/next arrows both change and wrap the saved value without rebuilding the grid;
- every planned workflow/output/trait option appears in DMF settings and Brunt UI while remaining absent from controller/backend dispatch until its implementation phase;
- status/setting rows are not all wrapped in full-width frames; gold is limited to selected offers and enabled primary actions;
- changing a planner selector, checkbox, or stepper value does not reset current grid scroll;
- disabled action has disabled hotspot and cannot dispatch a controller operation;

### Performance and soak tests

- panel idle for 30 minutes: zero backend polling and no repeated catalogue/layout rebuild;
- long capped search: bounded journal/histogram memory and no growth from retained item snapshots;
- rapid open/close/reopen: no stale widget callback, timer, or Promise crash;
- 1,000 synthetic purchase evaluations: linear policy work and deterministic result;
- delayed mastery for full timeout window: bounded poll count/backoff and responsive UI;
- cancellation/unload at every state: no mutation starts afterward and ownership is released;
- profiler check on low-end supported hardware before enabling small batches.

### Backend adapter contract tests

Use fixtures shaped like actual 1.12.3 responses:

- purchase result `items[i]` with UUID/gear conversion;
- crafting result `{ items={}, traits={} }`;
- mastery extraction `details.amounts[track_id]`;
- track state with `state.xpTracked`, `state.rewarded`, `claims`;
- sticker-book bitmask conversion/status;
- wallet transaction ID and amount updates.

### Live-game validation matrix

Run on a test character with strict low limits:

1. One Brunt purchase; verify created gear and wallet.
2. Two serialized purchases; verify no transaction conflict.
3. Cancel after purchase response.
4. Exact named stat 60 detection.
5. One Profane -> Redeemed upgrade.
6. One Redeemed sacrifice; verify deletion and XP.
7. Sacrifice crossing one tier; verify claim and points.
8. Sacrifice crossing multiple tiers; verify sequential claims.
9. Reproduce delayed reward sync; verify bounded polling.
10. Reach level 20; verify claimed level and points without restart.
11. Empower directly from a lower level to cap in one request.
12. Consecrate through all rarity tiers.
13. Replace one perk and one blessing.
14. Unlock then apply an unowned blessing tier.
15. Favorite and rename final gear; reload mods/game and verify persistence.
16. Close Armoury during every operation type.
17. Disconnect/timeout during purchase, upgrade, and sacrifice; verify reconciliation.
18. Run alongside automatic curio acquisition and discard; verify arbiter exclusion.
19. Manually empower final item between mod steps; verify compatible replan and correct remaining cost.
20. Manually replace a configured perk/blessing; verify selected interference policy.
21. Start mission during each mutation type; verify no next request and later recovery report.
22. Enter Operative Selection/loading screen during mastery polling; verify timers/read promises stop.
23. Exercise native notifications at milestone/default detail and high-volume detail; verify no spam queue.
24. Enable local chat mirror; verify messages remain local and party receives nothing.
25. Start from existing inventory weapon at mixed rarity/expertise; verify no downgrade and delta-only plan.
26. Open Brunt with BetterInventory Armoury panel disabled/absent; Auto Crafter widget remains fully usable.
27. Test vanilla, common UI scales/resolutions, and adjacent BetterInventory panel; verify geometry/focus isolation.
28. Test rename with BetterInventory only, Name It only, both, and neither; absent provider shows gray disabled control.
29. Load extracted standalone rehearsal with no BetterInventory files available; complete read-only probe and one capped purchase.
30. Compare Auto Crafter beside BetterInventory inventory options at 16:9, ultrawide, windowed, and supported UI scales; verify matching padding, typography, control sizes, section rhythm, clipping, and scrollbar placement.
31. Exercise every control with mouse and controller; verify semantic hit targets, disabled-action inertness, section collapse, and no scroll jump after planner changes or offer selection.

## Known risks and unresolved live questions

These do not block feasibility, but implementation must answer them in-game:

1. Exact inventory-cap behavior and backend error shape during repeated Brunt purchases.
2. Exact raw identity/value format for every weapon base stat in current purchase responses.
3. Whether one `addExpertise` request from arbitrary low value directly to 500 is accepted for every weapon when cap is unlocked. Client design strongly indicates yes.
4. Whether blessing tier purchase requires sequential lower tiers for all current trait paths; use `purchase_traits` ordering and validate.
5. Exact backend lag distribution after multi-tier mastery claims.
6. Whether mastery extraction returns partial success when some IDs are invalid. Current service catches per-batch errors and continues, which can obscure failures; controller should compare submitted/returned IDs.
7. Cost changes, event modifiers, or patch-specific rarity requirements.
8. Conflicts with Quick Level Mastery, Weapon XP Farm, Buy Until Rating, AutoBruntRoller, Empower Until Limit, or other mods hooking the same views/services.
9. Controller navigation and panel geometry across BetterInventory’s supported resolutions.
10. Whether current Fatshark mod-policy interpretation permits this automation. Existing public mods perform the same normal backend operations, but this is not a guarantee of future policy.

## Compatibility policy

Detect known overlapping mods with `get_mod(...)` where possible. If another automation owns the same workflow:

- default Auto Crafter to the documented validated full-workflow profile while still requiring an explicit per-run Start click;
- explain conflict in panel;
- never hook and recursively trigger another mod’s purchase callback;
- avoid simulating `_cb_on_purchase_pressed` from vendor view;
- invoke service adapter directly under BetterInventory operation ownership.

Read-only display integrations can coexist. Concurrent wallet/gear mutation automations cannot.

## Logging and user recovery

Maintain bounded journal entries such as:

```text
12:04:01 preflight mastery=8 claimed=7 cap=320
12:04:03 purchase pending offer=<id>
12:04:04 purchase confirmed gear=<id> credits=-9200
12:04:04 inspect dump_stat=mobility value=64 match=false
12:04:05 consecrate pending gear=<id> Profane->Redeemed
12:04:06 consecrate confirmed gear=<id> rarity=Redeemed plasteel=-...
12:04:07 sacrifice pending gear=<id>
12:04:08 sacrifice confirmed gear=<id> xp=...
12:04:08 mastery poll stale attempt=1
12:04:10 mastery claim tier=8 confirmed
12:04:11 mastery converged level=9 claimed=8 cap=...
```

Never log account tokens or raw authenticated request headers. Gear IDs are acceptable for local diagnostics but should be easy to redact in shared reports.

On halt, show:

- last confirmed state;
- whether any mutation remains ambiguous;
- confirmed spend;
- retained/pending gear IDs;
- safe action: Refresh State, Resume Sync, Review Items, or End Run.

Do not offer Resume Spending until reconciliation succeeds.

## Final recommended product behavior

Default mode should be conservative:

- `Sequential (recommended)` request scheduling;
- one-item mastery loop;
- preserve current best fallback; use other failed rolls as fodder only after explicit sacrifice opt-in;
- explicit spend and purchase caps;
- explicit second confirmation for sacrifices;
- automatic tier claims and bounded mastery polling;
- stop mastery spending at fast level-20 gate even while reward points remain stale;
- native milestone notifications enabled; local-chat mirror disabled;
- compatible manual item progress reconciled from fresh gear; conflicting changes pause;
- immediate dispatch closure and graceful stop when leaving valid Morningstar context;
- self-owned Brunt widget independent from BetterInventory Armoury panel;
- rename disabled unless one tested BetterInventory/Name It provider is available;
- final verification before favorite/name;
- dry-run preview available.

Advanced users can enable allowlisted `Parallel reads`. `Experimental parallel mutations` remains warning-gated with an initially empty mutation allowlist; enable pairs only after current-version live tests prove them safe. Small batches and reviewed auto-discard remain separate advanced options.

### Hot-reload wallet reconciliation and view-layer status

Brunt purchases use optimistic wallet concurrency: `Offer.make_purchase` sends the cached wallet's `lastTransactionId`. A DMF hot reload, native purchase, or another wallet mutation can make that cache stale and produce `Transaction id mismatch`. Auto Crafter therefore invalidates and refetches the relevant wallet immediately before every serial purchase. It retries exactly once only when the backend explicitly reports a transaction-ID mismatch, because that response confirms rejection before item creation. Timeouts, transport errors, and other ambiguous failures are never retried automatically.

The normal player HUD renderer can sit behind full-screen vendor, inventory, and crafting views. Persistent status therefore has two render paths backed by the same read-only status bridge: the registered HUD element for free-roaming Morningstar and a post-view overlay for supported vendor/inventory/crafting views. Both retain the hub and matchmaking gates, so the status remains hidden in missions and mission countdown loadout screens.

Mastery synchronization uses a 50 ms initial poll with bounded exponential backoff capped at 500 ms. This removes the former half-second minimum between confirmed sacrifices while retaining authoritative XP/claim convergence. At mastery level 20, blessing allocation is submitted through vanilla's `MasteryService.purchase_traits` batch path: operations remain serial and prerequisite-ordered internally, but run immediately after each backend response and reset/refetch the sticker book only once for final confirmation instead of once per point.

Active-run HUD status always ends with `Elapsed: N seconds`, rebuilt from the controller's monotonic run timer every frame. Before target acquisition, purchase results still receive authoritative gear reconciliation. After target acquisition, fodder purchases skip per-item gear reads and retain one pre-extraction batch refresh. Full storefront probes remain reserved for discovery. Structured timing summaries record count, total and maximum duration per operation kind, including the independent fast-upgrade lane.

Quick Level Mastery demonstrates the throughput benefit of overlapping independent requests, but its click path launches purchases and upgrades without a synchronization barrier. Auto Crafter uses a bounded version: wallet purchases remain serial, two rarity workers may overlap them, and extraction waits for all workers plus one gear read. Confirmed extraction removes consumed IDs locally and advances projected XP without per-item mastery polling. Once projection reaches 20, the controller claims milestones once and polls authoritative XP/claim convergence before dependent crafting.

View-rendered status overlays use the same fixed 42 px top inset as the normal Morningstar HUD element. They must not derive a bottom offset from a view's scenegraph height, because vendor and inventory view roots use top-aligned widget coordinates.

## Bottom line for implementation agent

All requested operations are reachable from current client service APIs. Build this as a guarded account-mutation state machine, not as UI click automation.

Most important rule: use local/returned XP only as a conservative **stop-spending** signal when it reaches level 20. Never use it as proof that rewards are available. Fetch track state, claim every reachable tier, fetch again, and wait until required points/sticker-book/expertise-cap postconditions converge before dependent final crafting.

## Online references

- [Official Darktide Modding Policy](https://forums.fatsharkgames.com/t/darktide-modding-policy/75407)
- [Aussiemon/Darktide-Source-Code, current source snapshot index](https://github.com/Aussiemon/Darktide-Source-Code)
- [Buy Until Rating source](https://github.com/zombine04/darktide-mods/blob/main/buy_until_rating/scripts/mods/buy_until_rating/buy_until_rating.lua)
- [Buy Until Rating Nexus page and changelog](https://www.nexusmods.com/warhammer40kdarktide/mods/100)
- [Empower Until Limit source](https://github.com/zombine04/darktide-mods/blob/main/EmpowerUntilLimit/scripts/mods/EmpowerUntilLimit/EmpowerUntilLimit.lua)
- [Name It source](https://github.com/zombine04/darktide-mods/blob/main/name_it/scripts/mods/name_it/name_it.lua)
- [Quick Level Mastery, current 0.0.3 page and synchronization reports](https://www.nexusmods.com/warhammer40kdarktide/mods/395)
- [Weapon XP Farm, current 1.9 description and changelog](https://www.nexusmods.com/warhammer40kdarktide/mods/846)
- [AutoBruntRoller feature evidence](https://www.nexusmods.com/warhammer40kdarktide/mods/836)
- [Claim All Masteries feature evidence](https://www.nexusmods.com/warhammer40kdarktide/mods/681)
- [DumpStatFinder behavior and configurable dump-stat identities](https://www.nexusmods.com/warhammer40kdarktide/mods/368)
