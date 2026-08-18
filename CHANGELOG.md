# BetterInventory changelog

## 2.6.3 - 2026-08-18

- Restores four- and five-column weapon layouts for inventories containing compound shields by replacing only their linked 3D card previews with Darktide's official static mastery textures at those densities.
- Covers both live-preview owners on the inventory screen—the scrolling grid and equipped Character Overview weapon card—while preserving native previews for ordinary weapons and one-to-three-column layouts.
- Adds critical lifecycle coverage for every current Ogryn and Arbites shield family, repeated bindings, teardown, and shield-to-ordinary transitions.

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
