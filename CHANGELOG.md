# BetterInventory changelog

## 3.4.0 - 2026-08-29

- Adds an independent default-on Equipment Text Search option for both Sire Melk grids, plus separate top and bottom padding sliders for Limited Time Acquisitions and GlobalStore Multi-Operative Supply.
- Adds BetterInventory's responsive, maximum-three-column Armoury card layout to Sire Melk's native Limited Time Acquisitions.
- Adds the matching character-footer card layout to Sire Melk's GlobalStore Multi-Operative Supply.
- Adds separate default-on controls for both Melk routes under Additional inventory views > Sire Melk's Requisitorium.
- Gives native Limited Time Acquisition cards a Melk-specific footer profile: blessing rows clear the footer divider while item level and dump-stat labels sit slightly lower; GlobalStore and Armoury geometry remain unchanged.
- Detects GlobalStore's Marks route from initialization context as well as the live view, preserving correct geometry regardless of hook order.
- Uses a scoped shared-grid fallback for GlobalStore's direct Marks presentation while leaving unknown custom Marks services native.
- Reuses existing Armoury sizing, image, price, item-level, character-footer, divider, search, and resource-retirement paths instead of introducing a second card implementation.

## 3.3.1 - 2026-08-29

- Adds independent top and bottom Equipment Text Search spacing sliders for Hadron's Entreat Item view.
- Positions the default Hadron search field from the native tab-frame boundary instead of stacking it below the unrelated 80-pixel grid-title reserve.
- Uses `34 / 50` as Hadron's default top/bottom spacing while preserving native title and tab geometry.
- Leaves Inventory, Armoury Exchange, GlobalStore, Brunt's Armoury, Melk, and Hadron's Sacrifice Item geometry unchanged.

## 3.3.0 - 2026-08-28

- Adds three Curio naming formats: the original Darktide item name, the resolved primary stat, or the primary stat followed by the three perk-category labels.
- Reuses BetterInventory's already-resolved stable trait identities and localized compact labels, including mission experience, so generated names remain compatible with standard/heavy compression without a second MasterItems or trait-description pass.
- Applies the existing Curio stat simplification and plus-sign preferences to generated titles while omitting secondary numeric rolls to limit visual clutter.
- Adds a compact title-only Curio profile that removes all stat-row passes and their reserved height; title-only cards with original names perform no trait lookups.
- Preserves saved BetterInventory and Name It Curio names by default, with an explicit option allowing generated names to override them.
- Avoids a global `Items.display_name` hook, repeated localization substitutions, per-frame work, and retained trait caches; weapon semantic renaming remains out of scope.
- Adds profile geometry, localization, custom-name precedence, generated-label, bounded lookup-count, and zero-lookup title-only regressions.

## 3.2.6 - 2026-08-28

- Keeps Brunt's native weapon-selection reconciliation on its bounded twice-per-second schedule while trait discovery is in flight, so a stalled request can no longer freeze the Auto Crafter queue on the previously selected weapon for 45 seconds.
- Retires the previous discovery generation as soon as another weapon is selected, refreshes the manual plan and queue immediately, and prevents canceled or late callbacks from replacing the new weapon's catalogue.
- Records the frozen request target and current backend stage (`crafting_metadata`, `mastery`, `sticker_book`, or `summarizing`) for discovery failures and timeouts, while distinguishing the currently selected weapon when it changed mid-request.
- Reports resolved-but-unavailable catalogue responses as trait-discovery failures instead of displaying a misleading `probe_complete` status.
- Adds stalled-request, rapid target-change, late-callback, stage-order, unavailable-catalogue, timeout-attribution, and bounded in-flight polling regressions.

## 3.2.5 - 2026-08-28

- Completes the Simplified Chinese localization audit, removes two retired generic-column translation IDs, and gives both Equipment Text Search examples functional Chinese query terms.
- Retires GlobalStore's outgoing asynchronous character-portrait loads before Darktide destroys a category's card generation, preventing repeated melee/ranged/Curio tab changes from retaining every old 100-150-card generation.
- Resets Better Inventory's weak favorite-marker generation only for destructive GlobalStore main-grid rebuilds; auxiliary grids and identity-preserving Equipment Text Search reorders remain untouched.
- Makes inactive Equipment Text Search cache warming monotonic per authoritative offer layout, so repeated category presentations continue a bounded 16-item pass instead of repeatedly restarting at item one.
- Adds a 40-generation, 150-card tab-switch stress regression that holds portrait resources to the current generation, plus hook-scope, missing-service, same-layout, bounded-cache, full behavior-suite, and package verification coverage.

## 3.2.4 - 2026-08-28

- Gives focused Armoury and GlobalStore search fields temporary visibility ownership of both the vendor view and its background input legend, preventing typed `G`/`V` characters from also triggering Compare or Inspect.
- Preserves every native/third-party input action and dynamic visibility callback, then restores only Better Inventory-owned state when text entry loses focus, is disabled, is released, or survives a hot reload.
- Hides the existing Armoury sorting panel while native weapon or Curio comparison is active and restores that same panel when comparison closes, without rebuilding its rows or allocating a replacement element.
- Releases controller focus before hiding the sorting panel and suppresses its controller legend action until the comparison view closes.
- Adds native-parent legend, Inspect/Compare, comparison visibility, no-rebuild, restoration, and 2,000-cycle retained-memory regressions; the full 52-file behavior suite passes.

## 3.2.3 - 2026-08-28

- Removes the temporary live Curio-ranking trace from Equipment Text Search, including its query-specific per-item string construction, logging, and reordered-result dump.
- Evaluates search match status and relevance rank in one bounded clause pass while preserving the public `matches`/`rank` contracts and every Curio, weapon, equipped, item-level, fail-open, and partial-match ordering rule.
- Caches one shared negative customization sentinel for ordinary cards, eliminating repeated customization-store lookups from their native frame updates; customization and relevant setting events invalidate the weak cache immediately.
- Reuses search and sort view-session cleanup callbacks instead of allocating replacement closures on repeated presentations/configuration.
- Releases fallback source-order entry references as soon as a native/ItemSorting comparator becomes available, rather than retaining the last bounded generation until view closure.
- Reduces dynamic material validation from two calls to one on the common texture-pass path with no native/third-party change callback; delegated callbacks retain the required before-and-after containment.
- Re-audits all runtime hooks, recurring subsystem gates, weak/view-owned registries, search projection/result/grid buffers, asynchronous ownership, Auto Crafter queues, and teardown; no additional unbounded collection or account-operation defect was found.
- Adds equivalence and 120-frame negative-cache regressions. The full 52-file, 178-case suite and deterministic package verifier pass.

## 3.2.2 - 2026-08-27

- Repairs Darktide's reused mission-ready `UIProfileSpawner` after loadout weapon presentation teardown, preventing later talent/profile synchronization from dereferencing a nil single-item loader while preserving native and Valkyrie hook execution.
- Preserves `BaseView.init`'s dynamic level-package argument through Equipment Text Search's Hadron decoration hook, preventing mission-ready `LobbyView` from opening before `content/levels/ui/lobby/lobby` is loaded and crashing at `ScriptWorld.spawn_level`.
- Makes shared `ViewElementGrid` hooks exact pass-throughs for profile-preset, cosmetic, lobby-preview, and unknown third-party grids, preventing Better Inventory state, callback wrappers, blueprint clones, markers, material guards, or clipping from leaking into unrelated menu mods.
- Retires destroyed, closing, and replaced Character Overview generations before delayed Curio/icon reconciliation can rebuild stale loadout widgets during loadout, gear, or cosmetic transitions.
- Keeps transient view activation fail-open, scopes detection to Darktide's native UI manager, and adds no polling beyond the existing bounded Character Overview update.
- Audits the supplied BetterLoadouts, Loadout Previews, LoadoutMoveButtons, LoadoutNames, Character Cosmetics View Improved, More Characters and Loadouts, VLCCP, and Guarantee Weapon Swap builds against current Darktide source.
- Separates Archnium's still-unlogged report from FirstFleet's proven v2.9.8 missing-material crash; the latter remains covered by inventory-package-safe highlight materials and targeted stale-widget repair.

## 3.2.1 - 2026-08-27

- Makes Equipment Text Search in Brunt's Armoury independently opt-in and disabled by default. A newly opened Brunt view receives no search widget, padding, search state, or input handling unless the option is enabled.
- Reorders Brunt's native weapon-family buttons through a retained in-place fallback comparator when search is enabled. Because Brunt deliberately exposes no native sort option, this avoids the previous full presentation fallback that destroyed and recreated its buttons after each settled query.
- Preserves canonical Brunt button order as the tie-breaker, reuses two bounded layout buffers and one source-position map, retains selected widget identity, and refreshes only the comparator closure after a mod hot reload.
- Adds an enabled-by-default God Stat Checker integration option that anchors Armoury Exchange and GlobalStore's shared Acquire row below an extended detail panel. Shorter panels retain the fixed vanilla position; disabling the option or GSC restores it live.

## 3.2.0 - 2026-08-27

- Fixes live weapon perk indexing by resolving backend master-item paths to gameplay trait IDs and indexing all perk identities/compact aliases before optional long Enhanced Descriptions text, making `flak` and `unyielding` reliable within the bounded record.
- Adds controller navigation from any first-row card to search with Up, native text-entry activation with Confirm, and return to the current first result with Down.
- Verifies Simplified Chinese weapon/Curio names, perks, blessings, rarity labels, partial queries, and UTF-8 caret handling; sets spacing defaults to Inventory `14/46` and Armoury `22/34`.
- Clips scrolled equipment cards below the text-search field and flushes deferred search sorting in Armoury Requisition and GlobalStore Multi-Operative Supply views.
- Adds original standalone search to inventory, Armoury/other supported vendors, Hadron modify, and Hadron sacrifice views through current native presentation seams.
- Searches custom and native names, weapon families and marks, blessings, perks, item types, ratings, state flags, effective rarity, and underlying native rarity with bounded literal parsing.
- Keeps Better Inventory's visible `Sainted` tier distinct from native `Transcendent`; `native-rarity:` can deliberately include both stored rarity-5 groups.
- Supports quoted phrases, explicit `&`, and field-qualified text, boolean, numeric comparison, and range clauses through one compact text field.
- Defaults to promoting matches and dimming unmatched cards while preserving Better Inventory priorities and the selected native or ItemSorting comparator within each group; optional hide mode composes with native filtering.
- Coalesces rapid edits, reuses bounded weak projection/result caches, restores owned alpha values, fails open when a view contract is unavailable, and releases per-view state on close or hot reload.
- Defocuses search without clearing it when a card is selected. Query memory is optional, bounded by character and logical view family, and disabled by default.
- Warns once when legacy Stuff Searcher is also enabled and avoids invoking GodRolls' decorated-name/stat projection while indexing.
- Restores the `InventoryWeaponsView` runtime dependency accidentally omitted during search-adapter extraction and guards its optional hook targets, preventing the four startup `hook_safe`/`hook` nil-object errors.
- Validates search focus and Escape actions against each view's input service before reading them, preventing the instant textbox-focus crash caused by the unavailable `cancel_pressed` action in vendor views.
- Removes the redundant expandable quick-filter controls and their dead chip state, and reserves the single search row through native content padding so grid titles such as `Primary Weapon` retain their original position.
- Places the text field fully below titled grid headers and indexes both Darktide's canonical perk descriptions and Better Inventory's standard/heavy abbreviations, so searches such as `flak` match regardless of card compression.
- Gives Curio line searches an equipped-aware relevance hierarchy: primary+secondary matches, primary-only matches, then secondary-only matches, with partial terms supported and every non-match retaining the existing sort order.
- Adds final view-specific search-field clearance below inventory headers and the deeper shared Armoury Requisition/Multi-Operative Supply tab row without moving native titles.
- Renames the dedicated Mod Options tab to `Equipment Text Search` and clarifies that its master switch hides the field, clears session state, and disables filtering and ranking.
- Finalizes search spacing by raising Armoury cards 32 pixels and inventory cards 12 pixels from the initial layout while adding two pixels of clearance above both fields.
- Exposes independent Inventory and Armoury top/bottom search-field padding sliders, preserving the finalized geometry as their defaults while leaving other supported views unchanged.
- Fixes match promotion after ItemSorting replaces sort options: settled searches rebind once and enter one native filter/sort/presentation transaction after the quiet interval, restoring weapon-name, perk, and blessing ordering without any per-frame rebuild.
- Makes rapid typing allocation-free inside the search runtime, parses and scans only after the 80 ms quiet interval, warms cold rich projections in bounded 16-item slices, removes redundant normalization/protected reads and the duplicate match map, and leaves fully settled idle updates allocation-free with all projection memory reclaimed on close.
- Removes global per-frame `ViewElementGrid.update` and `ItemGridViewBase.update` search wrappers; Inventory reuses Better Inventory's existing update/input hooks, runtime updates run only while warming or settling, inactive native filters/comparators bypass search entirely, the legend guard reads the existing widget state once, and focus owns only the main grid's native input-disabled state without overriding discard/options ownership.
- Fixes the optimized dim-search no-op by restoring Darktide's native indexed presentation transaction after coalescing, resolving the current comparator instead of a stale convenience pointer, and applying unmatched-card alpha once to newly presented `content.element` widgets without restoring a frame scan.

## 3.1.0 - 2026-08-26

- Blocks enabled crafting mutations before the first purchase when native Hadron progression is locked, including the reported level-1 Auto Crafter path.
- Requires affirmative selected-family mastery discovery for mastery automation on characters below level 30 while preserving valid low-level and Psych Ward workflows.
- Preserves the configured Ordo-docket and optional maximum-purchase limits as the only Auto Crafter acquisition ceilings; exact matches after purchase 40 remain reachable.
- Processes pre-target misses in rolling 30-item mastery-fodder batches, reserving only the current closest fallback when enabled, so long searches no longer accumulate every purchase in inventory without excessive cleanup pauses.
- When fallback is disabled, consumes only current-run misses toward mastery 20, discards verified run-owned excess, and stops at the configured acquisition boundary without selecting, favoriting, or crafting a fallback weapon.
- Reuses the native weapon card's already-decorated family name, preserving GodRolls stars/colours while avoiding BetterInventory's redundant second GodRolls `WeaponStats` projection per compatible card.
- Confirms the supplied crash at Hadron card 163 exhausted Darktide's fixed 1 GiB Lua heap while BetterInventory and GodRolls were both in the eager per-card allocation path; no infinite loop, independent retention leak, or mass favoriting was present.

## 3.0.0 - 2026-08-26

- Adds a dedicated God Stat Checker 1.1.2 integration section and a mirrored control in Custom legendary tier for selecting one exclusive weapon/Curio background-colour owner.
- Defaults to Custom legendary tier ownership across item cards and the right detail panel while retaining God Stat Checker's name-text grading.
- Saves God Stat Checker's preferred background card style while Custom Tier owns backgrounds, restores it when God Stat Checker is selected, and remembers later GSC style changes without recursive setting callbacks.
- Makes Custom Tier defer its rarity-colour wrapper when God Stat Checker owns backgrounds while preserving the Sainted rarity name; existing per-item custom backgrounds retain their higher priority over Custom Tier.
- Falls back to Custom Tier when God Stat Checker is absent, display-disabled, or mod-disabled; disabling Better Inventory restores any GSC style it temporarily suppressed.
- Reuses God Stat Checker's live repaint callback and captured native rarity seam, adding no per-frame scan, item registry, backend work, or account mutation.

## 2.9.9 - 2026-08-24

- Fixes the post-v2.9.8 `Repaired unsafe UI material` warning burst reported for generated fields such as `value_id_36`, `value_id_48`, and `value_id_60`.
- Restores `frame_tile_1px` as a valid native/DMF material instead of rewriting unrelated widget frames to `frame_tile_2px`.
- Limits the retired dashed-material migration to Better Inventory's own equipped/new-item highlight style IDs and keeps that expected upgrade repair silent.
- Retains the v2.9.1/v2.9.7 numeric and malformed dynamic-material containment, including one-time warnings for genuine invalid values, without adding a renderer hook, widget scan, registry, or package load.
- Documents the reporter's 105-mod compatibility audit, including EWC pass-number shifts, resource-loader boundaries, the unverified `smaller_grid` seam, and overlapping Lua garbage-collection tools without broadening the runtime rewrite.

## 2.9.8 - 2026-08-22

- Uses FirstFleet's full crash locals to identify `128` as renderer material flags, not the requested material name; the missing material was Better Inventory's equipped-highlight frame.
- Removes the crafting-package-only animated dashed frame from equipped and newly acquired item cards, replacing it with the frame already owned by Darktide's inventory package.
- Rewrites stale hot-reload widgets that still contain either the old dashed frame or the uncertain one-pixel frame before rendering, while preserving unrelated native and custom material strings.
- Retains saved highlight mode IDs and bounded layer/colour/pulse behavior, updates English and Simplified Chinese labels, and adds exact static/dynamic missing-package regressions without loading a large crafting package globally.

## 2.9.7 - 2026-08-22

- Extends invalid dynamic-material containment to equipped loadout-slot widgets created directly by `InventoryView`, covering the asynchronous icon refresh used after switching weapons.
- Protects secondary grids owned by `InventoryWeaponsView` instead of limiting repair to the primary item grid.
- Keeps the fix local to widget construction and normal texture-pass validation: no global renderer hook, frame-wide scan, retained widget registry, backend work, or account mutation is added.
- Adds regression coverage for numeric atlas-index corruption on primary grids, secondary grids, and equipped slots while preserving valid custom material references and one-time warning behavior.

## 2.9.6 - 2026-08-22

- Fixes simultaneous use with Red Weapons At Home no longer honoring that mod's saved colour and Curio Power requirements.
- On first detection, imports Red Weapons At Home's three RGB channels and four per-Curio Power thresholds into untouched matching Better Inventory settings.
- Preserves Better Inventory fields the user has already customized, records a one-time migration marker, and then keeps Better Inventory authoritative without stacking both classifiers.
- Keeps migration at the all-mods-loaded boundary, with no new frame callback, item cache, or per-card framework lookup; disabling Better Inventory's tier still restores the other mod.

## 2.9.5 - 2026-08-22

- Audits all 79 runtime Lua sources for DMF compatibility, crashes, asynchronous ownership, account-operation races, retained state, allocation hot paths, and teardown without changing established feature behavior.
- Verifies both installed legacy/current DMF and Alf generations: shared mod APIs and baseline options must exist everywhere, while native colour and retained-template seams are required only from current DMF.
- Fixes opt-in performance diagnostics under-reporting Automatic Curio Buyer reads because the sampler used an obsolete counter name.
- Makes deferred customization persistence compatible with receiver-free and method-style DMF save functions while preserving bounded retry/delegation behavior.
- Documents fixed findings, reviewed non-findings, regression evidence, and remaining live-soak limits in the v2.9.5 audit record.

## 2.9.4 - 2026-08-22

- Restores startup on older DMF releases that do not recognize the newer `color` Mod Options widget type.
- Detects colour-widget support once while constructing the settings schema: current DMF keeps the live custom-tier picker, while legacy DMF safely omits only that optional preview.
- Keeps custom-tier presets, RGB sliders, classification rules, and stored colours available on both framework generations.
- Adds modern/legacy schema regression coverage so one unsupported optional widget cannot make BetterInventory fail to load again.

## 2.9.3 - 2026-08-22

- Adds a default +3 minimum primary-roll setting for Automatic Curio Buyer's Stamina Curios.
- Adds a default target of three qualifying owned Curios per operative and primary-stat type; after the target is filled, candidates must strictly improve the lowest Power in the current best-three set.
- Keeps higher-Power upgrades eligible until all three retained slots reach the same cap, while equal/lower duplicates are rejected before wallet lookup or purchase dispatch.
- Reuses Darktide's authoritative profile/gear snapshot and retains only bounded per-pass Power lists; no additional backend request, persistent item cache, or idle work is introduced.
- Explains the owned-Curio target in a panel-native hover tooltip whose widget data is released with the inventory view.
- Limits ownership materialization to selected operatives, reads Curio filters once per scan, and maintains each bounded best set with allocation-free insertion instead of repeated sorting.
- Completes a v2.9.0-v2.9.3 performance/lifetime pass: custom-tier modifier filtering no longer allocates per item or queries DMF enabled state per card, Curio offer filters are snapshotted once per pass, and unchanged Mod Options disabled-reason lists are reused.
- Confirms the new v2.9 English UI has complete Simplified Chinese coverage and standardizes the new custom-tier Stamina labels on `体力`.

## 2.9.2 - 2026-08-22

- Adds a live, directly editable colour preview that stays synchronized with the custom-tier preset and RGB sliders.
- Adds a standalone custom legendary tier for qualifying Transcendent melee weapons, ranged weapons, and all four Curio primary-stat types; Red Weapons At Home is not required.
- Defaults reproduce Red Weapons At Home 1.2.6: RGB `210/30/40`, weapon Power 500, maximum Curio primary rolls, and zero minimum Curio Power.
- Adds independent melee/ranged Power, base-stat-total, per-modifier, and high-stat-count filters plus per-type Curio roll and Power filters.
- Makes BetterInventory's criteria authoritative when Red Weapons At Home is also enabled, while restoring that mod's behavior whenever BetterInventory's feature is disabled.
- Uses bounded event-refreshed settings and shared colour tables without per-frame scans, per-item retained state, or account mutations.

## 2.9.1 - 2026-08-22

- Prevents numeric or malformed dynamic texture values from reaching Darktide's UI material loader during weapon changes, including the reported `Error loading material '128'` failure shape.
- Protects BetterInventory-transformed Inventory and Character Overview cards plus native `InventoryWeaponsView` cards without a global renderer hook or per-frame widget scan.
- Preserves valid native/third-party materials, render-target atlas data, and async icon ownership; invalid references fall back to the pass's native material and emit at most one warning per widget field.
- Rejects malformed blessing and Auto Crafter trait texture metadata before it reaches material parameters.

## 2.9.0 - 2026-08-21

- Gives the Better Inventory name in Mod Options an always-on per-character gradient from bright green `#AEEF69` to aqua-blue `#62EFD8`, distinct from Alf's warm yellow-to-magenta branding.
- Uses DMF's native rich-text color markup, remains UTF-8 safe, and does not require Alf's DMF Extensions.
- Revalidates the full runtime against the updated DMF options rewrite and Alf's DMF Extensions 2.0.4, including automated external constructor, setting-identity, visibility, persistence, and reset contract checks.
- Keeps DMF's retained Mod Options template synchronized when delayed operative discovery finishes, using weak template ownership and event-driven dependency refresh without adding an idle-frame poll.
- Prefers stable setting IDs over localized titles, avoids unchanged roster writes that dirty DMF settings, and deterministically reconciles dependency, animation, diagnostic, and preset/RGB state after bulk reset.

## 2.8.6 - 2026-08-21

- Defaults Automatic Curio Buyer's Operative Selection scanning, once-per-store-rotation throttle, and idle store-refresh rescan options to On while keeping the master purchasing toggle Off.
- Updates the English and Simplified Chinese tooltips to match the new defaults.
- Translates all 46 generated weapon and Curio image-layout labels that previously fell back to English in Simplified Chinese.

## 2.8.5 - 2026-08-21

- Preserves an explicitly selected Auto Crafter dump stat when changing weapon Mark, including weapons whose Marks use different internal IDs for the same displayed stat.
- Falls back to the new Mark's first valid stat only when the saved selection is automatic or unavailable, preventing a hidden reset to Damage and wrong-weapon crafting.
- Places Mark selection before Dump stat in the Auto Crafter Helper so the final Mark is chosen before its stat target.

## 2.8.4 - 2026-08-21

- Adds a Character Overview setting for long weapon blessing names with three modes: two-line wrapping, shrink-to-one-line, and the default one-line ellipsis.
- Keeps the new policy isolated to mirrored Character Overview weapons, leaving inventory, Hadron, Armoury, and GlobalStore blessing-name controls unchanged.
- Rebuilds an already-open Character Overview when the mode changes and disables the option when mirrored weapon details or blessing text are unavailable.

## 2.8.3 - 2026-08-21

- Defers equipped/favorite-priority re-sorting until `InventoryWeaponsView` finishes its native update, preventing an equip click from replacing the item-grid widget array while Darktide is still traversing it.
- Coalesces repeated same-frame re-sort requests and quarantines a throwing third-party sort hook to the affected view instead of repeating the error every frame.
- Binds equipment-persistence state to the loadout view's stable presentation character, so InstantCharacterChange-style swaps, delayed profile events, and late backend promise settlements cannot write into a stale character view.
- Confirms Automatic Discard and Automatic Curio Buyer remain Morningstar-only, while Auto Crafter remains gated by its live Brunt/context checks; none can start account mutations from a mission lobby or Psykanium weapon switch.

## 2.8.2 - 2026-08-18

- Completes and refreshes Simplified Chinese localization using lershu's community-provided translation, replacing 212 distinct stale or English values while retaining translated coverage for 34 newer settings introduced after the reference was prepared.

## 2.8.1 - 2026-08-18

- Replaces Auto Crafter's tall phase-cost blocks with compact one-line currency rows for current resources, generous and unlucky total-cost estimates, and the resources remaining after each estimate; negative balances are highlighted in red.
- Adds the previously omitted acquisition and perk/blessing replacement costs. Target searches use transparent 100,000/300,000-docket planning heuristics bounded by the configured acquisition cap, while replacement costs come from Darktide's live recipes.
- Reduces idle Auto Crafter overhead in Brunt's Armoury by separating responsive clipboard input from slower native-selection, pivot, runtime-context, and character reconciliation; stable staged queues now perform expensive checks twice per second instead of every frame or ten times per second.
- Stops Psych Ward's queue-removal preview coordinator as soon as the remaining weapon is observably selected, even when Darktide's deferred preview adapter returns a false-negative result, avoiding redundant retries after the card is gone.
- Cancels stale native trait discovery when a Games Lantern queue is staged, preventing an unrelated 45-second timeout or late callback from replacing the imported catalogue and failure status.
- Documents a bounded six-card Games Lantern multi-import proposal and its duplicate-input, lifecycle, authority, and queue-identity requirements without changing the proven single-build runtime behavior.

## 2.8.0 - 2026-08-18

- Shows Auto Crafter's top status overlay in Psych Ward's live Brunt view while retaining the exact-view, destroyed-view, and matchmaking safety gates.
- Converts Psych Ward context loss into a bounded queue stop: no new mutations are dispatched, late backend responses settle inertly, Games Lantern ownership is released, and a retry reselects and reconfigures the interrupted job.
- Makes Craft and Stop / Interrupt mutually exclusive across manual runs, imported queues, in-flight work, quarantine, and reconciliation, with immediate panel rebuilding when workflow activity changes.
- Coalesces repeated account-mutation warnings while an interrupted backend request settles, preventing Morningstar mastery initialization from producing a notification storm without weakening the overlap guard.
- Refreshes MyFavorites' live color cache when Auto Crafter assigns its selected group, so the crafted weapon uses the chosen icon color immediately and after restart.
- Adds a working bottom-right red X to each two-weapon Games Lantern queue card, including Psych Ward; removing either card recomputes authority and runs the remaining melee or ranged weapon as a valid one-weapon queue.

## 2.7.0 - 2026-08-18

- Colours secondary Curio lines by related perk category by default, with shared Health/Toughness primary colours and a shared Max Stamina colour for all stamina and efficiency perks.
- Adds customisable categories for enemy damage resistance, corruption resistance, ability regeneration, mission rewards, and revive speed. Enemy resistance defaults to pink, corruption shares Wound purple, mission rewards use a custom soft peach, and Revive Speed uses a neutral tone distinct from Toughness; untouched preview-build colours migrate once without overwriting custom RGB choices.
- Retains the previous single-colour mode and uses its colour as a fail-safe fallback for unknown future Curio perks; regression coverage enumerates every current Darktide Curio trait.

## 2.6.3 - 2026-08-18

- Detects an equipped compound shield before the weapon-inventory base view is initialized and keeps the complete view on Darktide's known-safe three-column geometry.
- Rechecks the fetched inventory before presentation so unequipped Slab Shields and current Arbites shield families receive the same protection; ordinary weapon inventories retain their configured four- or five-column layouts.
- Adds regression coverage for both early equipped-item and later fetched-layout guards after static card-preview substitution proved insufficient to prevent the engine stall.

## 2.6.2 - 2026-08-18

- Prevents the Slab Shield engine crash/long empty-grid stall by automatically limiting an affected weapon inventory to three columns when a compound shield is present; inventories without shields retain their configured four- or five-column layout.
- Covers all four current Ogryn and Arbites shield marks across the Slab Shield, power-maul shield, and shotpistol shield families while preserving Darktide's native icon and selected-item preview ownership.
- Contains draw-time modifier projection behind a per-card error boundary and negative cache so malformed or future expertise/template records fail once instead of retrying every rendered frame.

## 2.6.1 - 2026-08-18

- Fixes Ogryn Slab Shield inventory crashes and long empty-grid stalls by resolving card modifier identities directly from bounded item/template base-stat data instead of instantiating Darktide's full action-heavy `WeaponStats` calculator for every visible weapon.
- Audits all 142 shipped weapon templates (five modifiers each, 37 display identities, no missing or duplicate identities) and adds critical regression coverage for Slab Shield plus ordered sparse, malformed, and failed future-template records.

## 2.6.0 - 2026-08-17

- Allows Auto Crafter through Psych Ward's character-selection Brunt route only while its live vendor view remains valid, retaining matchmaking and unrelated-context guards.
- Promotes the closest valid weapon at acquisition-cap or wallet exhaustion when fallback is enabled, carries immutable stat-distance proof through Phase 3/4 and Games Lantern, and rejects drifted or forged completion results.
- Scopes Ordo-docket and maximum-purchase caps to target acquisition so a frozen weapon can continue below-20 mastery fodder purchases until real wallet or inventory limits; a Damage 60-to-80 target change is not itself a failure condition.
- Replaces the base-acquisition checkbox with Disabled, buy-first-and-proceed, and target-search modes (safely migrating existing saves), and adds an exact versus lower-or-equal dump-target selector while keeping five-stat profiles exact.

## 2.5.1 - 2026-08-17

- Reduces WKC's kill-count font from 20 px to 14 px and icon from 22 px to 16 px on Brunt's native two-column weapon cards, aligns the counter's lower-left edge with the weapon-name inset, reapplies the geometry after WKC style refreshes, and leaves other listing and weapon-detail profiles unchanged.

## 2.5.0 - 2026-08-17

- Adds default-off Health (21%) and Toughness (17%) Curio roll thresholds: each enabled threshold takes precedence over item level for its matching primary type, while enabled Wound and Stamina Curios continue to use the minimum item-level rule.
- Adds independent, default-off automatic-favorite settings for confirmed Automatic Curio Buyer purchases, Armoury Exchange purchases, Sire Melk Limited Time Acquisitions, and Sire Melk Mystery Acquisitions; GlobalStore purchases inherit the corresponding Armoury or Limited Time setting, including cross-character ownership, while Brunt's Armoury and Auto Crafter purchases remain isolated.
- Adds MyFavorites color selection directly below **Automatically favorite crafted weapon** when MyFavorites is installed, previews all five configured colors, and assigns successful crafted favorites to the selected color without protecting rejected Auto Crafter rolls.
- Preserves inventory-options scroll position across conditional-row rebuilds, restores the Auto Crafter **Active Queue** collapse control, and removes duplicate WKC listing counters from weapon-information stat rows while retaining the intended detail and inventory-card counters.

## 2.4.1 - 2026-08-17

- Adds responsive Weapon Kill Counter totals to three-column, single-column, Hadron, and Character Overview weapon cards, plus an off-by-default 1,000-kill visual test that never modifies WKC statistics.

## 2.4.0 - 2026-08-16

- Perfect rolls rank fifth stats 62 > 61 > 60.
- Auto Crafter was refactored into safer, fail-closed modules.
- Weapon actions fit 7 rows, then scroll with padding.
- Tests cover marks, mastery, stat IDs, timeouts and HUD cleanup.

## 2.3.2 - 2026-08-15

- Split Auto Crafter candidate/mastery policies, Phase 3/4 workflows, inventory and imported-queue workflows, and Darktide panel blueprints out of the two oversized controller/UI files without changing their public behavior.
- Added explicit fail-closed module composition so the core can be hosted independently of BetterInventory and Darktide-specific UI modules can remain optional.
- Kept workflow generations, account-operation serialization, authoritative reconciliation, and lifecycle cleanup under the existing controller while avoiding retention of transient installer service tables.
- Enforced the 100 KB module limit across every nested Auto Crafter runtime file and documented ownership, standalone host ports, performance rules, and lifecycle invariants.

## 2.3.1 - 2026-08-14

- Counted `80/80/80/80/61` and `80/80/80/80/62` weapons as perfect rolls when **Perfect-roll weapons at the top** is enabled.
- Ordered perfect-roll weapons by their fifth attribute, placing `62` ahead of `61` and `61` ahead of `60`, while preserving the higher equipped and favorite priorities.

## 2.2.5 - 2026-08-13

- Removed the redundant runtime duplicate-setting scan from Mod Options, preventing post-processed settings from other mods being reported as BetterInventory errors. DMF startup and release verification still validate BetterInventory's source schema.

## 2.2.4 - 2026-08-13

- Fixed Alf's DMF Extensions render-time ID reconstruction being mistaken for source-schema duplicates by validating DMF's canonical per-mod settings data instead of the post-processed shared render tree.

## 2.2.3 - 2026-08-13

- Fixed foreign setting IDs from DMF's shared options template being misreported as duplicate BetterInventory settings; diagnostics now inspect only BetterInventory's category and list each genuine duplicate once.

## 2.2.2 - 2026-08-13

- Added a separate **Newly acquired item highlight** subsection at the bottom of **Card content**.
- Replaced the hard-to-see native corner dot with a green Pulsing animated dashed border at width 2 by default; Native dot only, Soft glow, Animated dashed border, and Solid border modes remain selectable.
- Added independent intensity/width controls plus shared colour presets and RGB sliders for newly acquired item highlights.
- Added configurable acknowledgement: selecting a new item clears its marker by default, while Hover mode clears it as soon as the card is hovered; controller focus also acknowledges in Hover mode.
- Reused Darktide's authoritative persisted new-item state and native removal callback, covering mission rewards, Brunt purchases, and Hadron upgrades without a second acquisition database.
- Kept drawing bounded and allocation-free during normal frames: one pass checks acknowledgement, native GPU materials animate dashes, and optional callback failures are contained.
- Added **Pulsing animated dashed border** to newly acquired and equipped item highlights. It fades from 15% to 100% opacity and back over a slow four-second cycle while retaining the existing dashed-width and colour controls.
- Used Darktide's global UI clock for synchronized pulsing, with no retained per-card timer state or per-frame allocation; new-item acknowledgement remains once-only on the first pass.
- Fixed live highlight-mode changes so only the applicable glow-intensity or border-width slider remains enabled without reopening the options menu, using one event-driven refresh per dropdown change with no per-frame polling.
- Tuned the equipped-item default to a gold Animated dashed border at width 2 while preserving existing saved choices.

## 2.2.1 - 2026-08-13

- Replaced the equipped-card highlight checkbox with Off, Soft glow, Animated dashed border, and Solid border modes while preserving existing enabled/disabled choices.
- Added shared colour presets and RGB sliders for every equipped-card highlight mode; editing any channel selects Custom colour automatically.
- Added mode-aware defaults: white for Soft glow and the Auto Crafter terminal gold for both border modes.
- Defaulted equipped cards to a gold Animated dashed border at width 3; legacy enabled checkboxes migrate to this mode while disabled checkboxes remain Off.
- Grouped all controls in a final **Equipped item highlight** subsection at the bottom of **Card content**.
- Added a 0-100% Soft glow intensity slider plus independent 1-5 width sliders for Animated dashed border and Solid border; only the control for the selected mode remains active.
- Used Darktide's native GPU-animated dashed-frame material with no Lua timer, retained animation state, or per-frame allocation.
- Bounded thicker borders to five native frame layers and replace owned layers on blueprint recomposition so repeated integrations cannot accumulate highlight passes.

## 2.2.0 - 2026-08-13

- Added independent weapon and Curio image X/Y/width/height percentage controls for Character Overview, Inventory/Hadron, Armoury Exchange, and GlobalStore.
- Added separate single-column and 2-5-column image profiles with resolution-independent card-relative scaling and zero-impact defaults.
- Replaced repeated column-profile subsections with one dropdown-driven four-slider editor while preserving five independent saved layouts per view.
- Defaulted profile editors to 3-column mode and added tuned Armoury/GlobalStore image geometry for weapons and Curios without overwriting saved settings.
- Added tuned 3-column weapon and Curio image defaults for Inventory and Hadron while preserving existing saved profiles.

## 2.1.6 - 2026-08-12

- Enabled the single-line weapon-name policy by default, with bounded font reduction, mark-preserving truncation, and strict three-column overflow protection for long standard and customized names.

## 2.1.5 - 2026-08-12

- Added optional exact five-stat Auto Crafter targets with contextual two-column controls for every selected weapon stat.
- Enforced 60-80 per-stat bounds and a hard 380 total; invalid totals are highlighted and cannot dispatch account mutations.
- Applied exact custom allocations to Brunt purchases, family-equivalent inventory resume, mastery reconciliation, and final verification.
- Games Lantern imports now preserve exact five-stat profiles; staged queue cards can be selected and edited without changing melee-first execution order.
- Closest-fallback selection now minimizes the summed absolute difference across all five requested stats, rejects incomplete profiles, and keeps the earliest equal-distance roll.
- Games Lantern queue-card selection now follows the matching melee/ranged weapon in Brunt while preserving execution order; Clear Queue restores the pre-import selection when available.
- Filtered non-displayable weapon-family prototypes and malformed localization records out of the Marks catalogue, preventing phantom `<unlocalized>` rows while preserving real marks.

## 2.1.4 - 2026-08-12

- Automatically reduce long Character Overview Curio title font sizes until titles fit within their configured two-line area.
- Removed obsolete planned/phase labels from Auto Crafter sections and experimental labels from the two Automatic Curio Buyer scheduling options.

## 2.1.3 - 2026-08-11

- Fixed Games Lantern UUID-to-slug HTTP 302 imports on Wine/Proton.
- Bounded redirects to three HTTPS hops and reject final URLs outside the original Games Lantern build UUID.
- Improved transport failure diagnostics with request generation, HTTP status, response size, and content type.

## 2.1.2 - 2026-08-11

- Released closed inventory, Character Overview, vendor, Brunt, Hadron, popup, panel, grid, and persistence references through idempotent exit/destroy paths.
- Added repeated open/close lifecycle coverage while preserving post-draw/update CPU ownership fixes.

## 2.1.0 - 2026-08-11

- Began research into importing Games Lantern build weapon targets into Auto Crafter Helper.

## 2.0.3 - 2026-08-10

- Prevented Auto Crafter from overlapping native, manual, or third-party account mutations.
- Deferred Automatic Discard and Curio Buyer passes until Auto Crafter releases ownership.
- Added critical regression coverage for purchases, upgrades, mastery, favorites, and discards.

## 2.0.2 - 2026-08-10

- Fixed Auto Crafter losing purchased weapons when inventories exceeded 1,024 records.
- Added bounded post-purchase visibility reconciliation without repeating purchase requests.
- Added large-inventory, malformed-record, delayed-visibility and interruption regression coverage.
- Quarantined timed-out/ambiguous mutations until their original promises settle, preventing overlapping retries and silent continuation after character or context changes.
- Added one shared account-operation gate across Auto Crafter, discard and Automatic Curio Buyer workflows.
- Deferred scheduled automatic discard and Curio purchases until Auto Crafter fully releases account-operation ownership.
- Guarded native/manual purchases, crafting, mastery, deletion and favorite changes: manual actions stop Auto Crafter between requests and fail closed while a request is unresolved.
- Hardened inventory reuse with exact-mark identity, equipped-item exclusion, deterministic selection and live minimum-material preflight.
- Added bounded read timeouts, frame-update crash containment, and integration coverage for resource exhaustion, full inventory, network stalls and loading transitions.

## 2.0.1 - 2026-08-09

- Added optional Character Overview dump-stat-only weapon display.
- Added horizontal offset, font scale, colour preset and RGB controls.
- Centered dump-stat labels and fixed live enable/disable states.

## 2.0.0 - Unreleased

### Fixed / Added

- Fixed Armoury Exchange/GlobalStore card construction crashing after the layout split because independently evaluated card modules could call an unset `columns_provider`. Column policy is now owned directly by the shared content domain, and customization-provider wiring is forwarded to every independently loaded layout collaborator.
- Fixed Automatic Curio Buyer showing the same successful Operative Selection purchase report again in white during the transition to the Morningstar. Dispatch status is persisted with each report so module/VM recreation cannot lose the acknowledgement, while failed notification dispatches remain eligible for Morningstar fallback.
- P0 hotfix `665801b`: prevent Character Overview composition probes from reading absent optional `window`/`canvas` scenegraph nodes through Darktide strict tables. This removes the reported `table.lua:1204` crash when opening a melee weapon card and adds a strict-scenegraph regression test.
- B42/B43 remediation: production-facing harnesses now execute the real extracted Character Overview, feature, and Curio domain modules. Automatic Curio scan continuations carry an account/context/read-generation snapshot, and mixed or missing multi-character store boundaries wait without evaluating or purchasing offers.
- B44-B46 remediation: settings metadata/localization audits are authoritative; the verifier now attributes failures to one named case, gates critical async/destructive outcomes, and rejects unassigned runtime modules; composition invalidation moved into its own production-loaded module and the unused Character Overview config-model attachment was removed.
- B48 first architecture slice: ItemSorting integration state and native-option assembly now live behind a dedicated production-loaded adapter; remaining panel, optional-integration, and discard extraction is tracked as B49.
- B50/B51: owner live testing showed that rebuilding only one empty/equipped Curio widget was incomplete. The replacement fix triggers Darktide's native complete individual-layout rebuild on a Curio presence/type mismatch, restoring coupled registrations, navigation, callbacks, and icon lifecycle in both directions. Owner testing confirms the reported empty-slot→equipped regression is fixed in-game.
- B52/B53: manual discard ownership now survives popup removal until native deletion settles; equipment persistence retries now fail closed and retry as one unit when an Items call throws or returns an invalid promise.
- B54: every Python assertion must map to exactly one named risk case. The suite now passes 14 tests, 45 cases, and 12 critical async/destructive outcome gates.
- Finalized the B40/B41 release-candidate handoff with a repeatable live stress/compatibility matrix, deterministic release fingerprint, and explicit documentation that live-engine validation remains the final release blocker.
- Fixed Automatic Curio Buyer consuming a predicted new rotation while Darktide's backend still returned the expired storefront. Rotation-triggered passes now require storefront boundary advancement and poll stale responses as a nonterminal wait without evaluating offers, showing a false failure, or suppressing the real refresh pass. A one-time ledger migration invalidates potentially poisoned pre-hotfix boundaries while preserving pending reports and account metadata.
- Hardened weapon and Curio equip persistence across rapid Character Overview exits. BetterInventory observes Darktide's native request, retries only confirmed idempotent failures with account/character guards, preserves uncommitted Y previews from delayed authoritative-X events when reopening the child inventory, and refreshes the overview after confirmed persistence.
- Fixed DMF customization-save handling: normal non-throwing no-return saves are treated as delegated instead of retried forever, while unavailable/throwing/rejected paths use bounded attempts. Manual discard now retains the shared destructive-operation lock until the native deletion promise settles, and same-gear Character Overview revisions invalidate stale detailed-card content.
- Added repository-only clean-checkout verification plus optional explicit DMF/Darktide compatibility paths. Added opt-in sampled hot-path diagnostics for UI counters, async read age, active promises, and Lua memory; diagnostics remain disabled by default.
- Reduced idle MyFavorites marker scans and panel geometry writes with dirty-generation invalidation, bounded compatibility probes, and weak-key lifecycle ownership.
- Added scoped ViewSession teardown and a generation-owned destructive-operation arbiter for discard popup/backend settlement lifecycles.
- Replaced the single pending Automatic Curio report with a bounded, deduplicated, account-scoped queue delivered oldest-first.
- Added typed guarded capability outcomes for optional integrations and conservative settings-registry refresh fallback when lookup or invocation fails.
- Extracted Character Overview item models and complete derived-content reset policy, explicit feature/Curio domain adapters, and auditable metadata for all active settings.
- Added deterministic runtime bundle manifests with source hashes and a documented DMF-safe deferral for authoring-file splitting.
- Behavior verification now reports named risk cases, checks AST-discovered local module references, and enforces risk-weighted coverage thresholds for behavior-bearing runtime modules.
- Bumped active release metadata to 2.0.0 and added the full-project audit, prioritized findings, phased remediation plan, and release gates in `docs/v2.0.0-full-project-audit.md`.
- Added bounded account-scoped Automatic Curio Buyer report history for Operative Selection, delivered oldest-first once on the matching account's next Morningstar readiness.
- Release packaging now removes unresolved temporary build archives after verification failures.
- Fixed Curio rarity colour strips on native/hybrid card lifecycles while preserving per-item custom background colours.
- Added the default-off **Use native Curio overlay** option for detailed Character Overview cards. It restores Darktide's ornate frame and portrait geometry while retaining BetterInventory's title and stat lines. See `docs/v1.9.4-curio-card-visuals-plan.md` for validation details.
- Corrected native-overlay Curio coordinate handling: the centered title now uses its width for the 19 px inset and an additive 1 px left shift, the favorite/checkmark marker stays below the full title band after runtime synchronization, and bottom-aligned item levels move higher with the correct negative Y delta.
- Fixed reused Character Overview cards retaining the previously equipped weapon/Curio background or the previous Curio's fitted secondary-stat rows after returning from equipment selection.
- Fixed manual discard transactions remaining locked when Darktide removes their confirmation popup without invoking an option callback; popup IDs are now reconciled and lifecycle cleanup is token-aware.
- Fixed sort comparators remaining wrapped after disable or hot reload; GlobalStore/vendor views without an optional sorting panel are now tracked, restored, and rebound safely.
- Fixed Automatic Discard releasing shared workflow ownership when canceled or disabled during an in-flight backend deletion; Curio Buyer and manual discard remain blocked until settlement.
- Reduced idle UI allocation churn by preserving fixed update return contracts and limiting MyFavorites marker synchronization to active marked grids and changed offsets.
- Fixed disabling BetterInventory with an open inventory/vendor view leaving controller focus ownership or Armoury input-legend actions attached to the live native view.
- Added explicit read-request ownership metrics and cancellation for Automatic Discard; Curio Buyer reports active and oldest read-only request state while purchase POSTs remain non-cancelable.
- Made customization persistence outcomes explicit: confirmed saves clear dirty state, thrown failures remain retryable as errors, and DMF-swallowed failures remain marked unknown instead of being reported durable.
- Added comparator antisymmetry coverage so malformed equipped/favorite compatibility calls degrade to ordinary priority without destabilizing native sorting.
- Extracted a small guarded capability-contract adapter used by sorting compatibility calls, establishing a behavior-neutral seam for future integration/domain extraction.
- Added a recursive active-settings registry with duplicate-ID diagnostics and declarative dependency-refresh routing, including generated character-slot settings.
- Added timeout-bounded test discovery, machine-readable JSON results, GitHub Actions verification, and module-by-module Lua line coverage reporting.
- Replaced representative implementation-text safety checks with Lua AST validation for forbidden direct class assignments, unsupported vendor requires, and render-resource ownership.
- Added focused user/architecture documentation and a reproducible settings/localization manifest with drift verification.
- Cached Character Overview Curio title/stat normalization by raw source identity so unchanged frames avoid repeated string allocations.
- Added deterministic failed-package cleanup coverage that verifies the outer packager `finally` removes temporary build archives before destination replacement.

## 1.9.3 - 2026-08-07

### Implemented

- Added optional Operative Selection scanning, default-on account-scoped Armoury rotation throttling, backend-boundary timing, and optional idle refresh rescans for the Automatic Curio Buyer. See `docs/v1.9.3-automatic-curio-buyer-plan.md` for the implementation handoff and in-game validation matrix.

## 1.9.2 - 2026-08-06

### Fixed

- Fixed Change Name silently doing nothing when Darktide's global popup handler was created before BetterInventory added its text field.
- Repair the live popup scenegraph when necessary and resolve its active text widget when opening or closing the name editor.
- Hardened failed persistence writes, Name It map reads, editor shutdown, and repeated input-legend rebuilds; expanded lifecycle regression coverage and maintenance documentation.

## 1.9.1 - 2026-08-06

### Fixed

- Added RT controller focus switching and directional navigation to BetterInventory's Armoury Exchange and GlobalStore sorting panels, including a matching input-legend entry.

## 1.9.0 - 2026-08-06

### Added

- Added controller navigation for the scalable inventory-options widget, with RT switching focus between the item grid and widget, directional navigation between rows and controls, and the normal confirm action activating the selected option.
- Added a collapsible Darktide Native Sorting section to the discard-mode widget, placed after ItemSorting when that integration is active.

### Fixed

- Positioned the scalable options widget directly below and left-aligned with Darktide's native discard-filter window, preventing overlap with item information and the Discard Items button across resolutions.
- Fixed controller right-navigation in multi-column melee and ranged inventories so it selects the next item in the current row before transferring focus to Darktide's Marks/Cosmetics/Inspect options at the row edge.
- Moved Background Color's default controller binding from R3 to LT so it no longer conflicts with Darktide's native Discard Items action, including migration of the previous default binding.
- Kept controller handling action-based and device-agnostic for Xbox, PlayStation and custom controllers mapped through Darktide's normal navigation inputs.
- Consolidated inventory update handling into one DMF hook so Ctrl+Shift+R hot reload no longer warns about rehooking `InventoryWeaponsView.update` with a different hook type.

## 1.8.0 - 2026-08-06

### Added

- Added a default-on Lantern of the Omnissiah integration that hosts Lantern's weapon recommendation window as the top section of BetterInventory's scalable inventory-options panel and suppresses the duplicate floating panel while active.
- Added a default-on option that keeps Lantern's Recommended Curios panel in its native standalone placement instead of hosting it inside BetterInventory's panel.
- Added automatic ItemSorting integration to the melee, ranged, Curio, Armoury Exchange and GlobalStore sorting panels.
- Added a collapsible `ItemSorting mod` section with its complete custom method set, including Family + Mark and both Base Rating directions, while preserving every vanilla-style method under `Darktide Native Sorting`.
- Kept ItemSorting's comparator ownership, ordering and callbacks intact without changing its saved Mod Options, and kept the expanded store panels bounded and scrollable.

### Fixed

- Moved the equipped marker lower on Character Overview cards so it no longer collides with Lantern's recommendation icon.
- Made the Character Overview marker offset follow Lantern's live enabled/recommendations state, and restore each card's original placement when inactive.
- Hid hosted Lantern recommendations during item comparison and discard management, and released stale hosted content when Lantern is disabled at runtime.

## 1.7.4 - 2026-08-06

### Added

- Added a default-on option to show or hide the complete inventory options widget without changing its saved sorting or item-management settings.
- Added signed inventory and GlobalStore width stress controls for validating responsive cards and sibling-panel positioning.

### Fixed

- Anchored the inventory options widget to the live weapon-information right edge and native button-section bottom edge across centered ultrawide workspaces.

## 1.7.3 - 2026-08-06

### Added

- Added a default-off Armoury geometry stress test with a configurable 10-100% store-width increase and proportionally resized equipment cards.

### Fixed

- Centered the combined Acquire and Quick Level Mastery Sacrifice actions on the rendered weapon-information panel, independent of the store-grid width.
- Anchored the Armoury Sorting panel to the weapon-information panel and kept it below the Ordo Dockets frame with consistent padding.
- Corrected the weapon-information scenegraph API used by the Quick Level Mastery compatibility path.

## 1.7.2 - 2026-08-05

### Added

- Added Character Overview weapon and Curio cards with configurable Curio title modes and text scaling.
- Added Visible Equipment, MyFavorites, Name It and standalone **Custom Item Names and Colors** integrations.
- Added GlobalStore Multi-Operative Supply cards and sorting controls.
- Added supported-vendor single-column mirrors for Entreat Hadron and Requisition Weapons & Curios.

### Improved

- Stabilized DMF options cardinality for Alf's DMF Extensions and fixed operative-slot discovery across cold starts.
- Added Armoury sorting, store-card footer layout, native sorting controls and safe two-to-three-column vendor limits.
- Hardened discard revalidation, Automatic Curio Buyer character targeting, wallet selection and transaction sequencing.

### Fixed

- Release packaging now discovers every runtime Lua module and independently verifies the complete archive, including `BetterInventory_item_customization.lua`.

## 1.3.0 - 2026-08-04

### Added

- Added individual saved-character targeting to the Automatic Curio Buyer, with safe fallback to class targeting when character data is unavailable.
- Added built-in maximum-potential weapon modifier stats without requiring Quick Look Card: all five modifiers in single-column mode and the lowest modifier in grid mode.
- Added a dedicated **Single-column layout** options section with controls for weapon-name font size and blessing tier-symbol placement.
- Added single-column modifier controls for font size and horizontal and vertical positioning.

### Improved

- Curio Buyer notifications now identify the character receiving each purchase, and purchases use that character's wallet.
- Reused and normalized Quick Look Card passes when that mod is installed, avoiding duplicate weapon modifier displays.
- Improved fitting of long blessing names on weapon cards.
- Refined Curio Buyer labels and character-selection behavior.

### Fixed

- Normalized Curio primary-stat roll values across localized and rich-text descriptions so valid Health, Toughness, Stamina, and Wound rolls are evaluated consistently.
- Kept Curio Buyer character selections valid after settings reloads and hot reloads.

## 1.2.0 - 2026-08-04

### Added

- Added the Automatic Curio Buyer: cross-character scans for Curios meeting configurable criteria and automatic purchase of desirable Curios.
- Added complete Simplified Chinese (`zh-cn`) localization.

### Improved

- Improved Enhanced Descriptions mod integration.
