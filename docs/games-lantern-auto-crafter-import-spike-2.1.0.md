# Games Lantern weapon-target import spike — BetterInventory 2.1.0

Date: 2026-08-10  
Branch: `research/2.1.0-games-lantern-import`  
Status: Batches 1-7 implemented and hardened; automated gates pass, live Windows/Proton/UI validation remains required before release
Target surface: Auto Crafter Helper in Brunt's Armoury

Handoff audit: 2026-08-10 against the current controller, planner, operation arbiter, mutation guard, panel, and regression suite
Runtime baseline: `44fbad1` (BetterInventory 2.1.0; imported queue is session-local and does not change persistent manual settings)
Specification baseline reviewed: `e2abbc3`
Verification baseline: 27 behavior suites / 100 cases plus architecture, schema, Lua structure, runtime bundle, ZIP parity, and static checks passed

## Executive decision

Yes. Importing a Games Lantern weapon target from a copied build URL is theoretically and practically feasible with high confidence for public builds.

The clipboard contains only a URL, so Ctrl+V cannot configure Auto Crafter from clipboard text alone. BetterInventory must extract the build UUID, fetch the public Games Lantern page, parse its weapon entries, resolve both the melee and ranged entries against Darktide's live weapon/stat/perk/blessing catalogues, and stage an atomic two-item queue.

The installed Lantern of the Omnissiah mod already proves the difficult platform primitives:

- Darktide exposes clipboard reads through the global `Clipboard.get` function.
- A slugged Games Lantern URL can be reduced to a canonical UUID URL.
- The public build page can be downloaded asynchronously on native Windows and Proton/Wine.
- Its rendered HTML contains weapon names, family/mark links, modifier values, perks, blessing names, and blessing image identifiers.
- The result can be stored and displayed inside Darktide.

Ctrl+V is a **read-only queue import**. It selects the imported melee weapon in Brunt and atomically configures planner targets, but it must never start crafting or spend resources. The existing CRAFT action remains the only account-mutating entry point and processes the validated queue serially: melee first, ranged second.

## Requested interaction

The intended workflow is:

1. Open a public Darktide build on Games Lantern.
2. Press its Copy button; the clipboard receives the build URL.
3. Open Armoury Exchange -> Brunt's Armoury.
4. With the Auto Crafter panel visible and idle, press Ctrl+V.
5. BetterInventory reads and validates the clipboard URL, fetches the build, and resolves both the build's melee and ranged weapons.
6. BetterInventory changes Brunt's selected family/offer to the imported melee weapon, atomically activates its dump stat, perks, and blessings, and queues the ranged target behind it.
7. The top summary changes from a single target to a queue summary such as `Queued (Arc Maul => Arc Rifle)`. Both `Target` and `Planner target` use this queue summary while two jobs remain.
8. The new `Active Queue` section shows one detailed row for melee and one for ranged. The active melee row is highlighted yellow.
9. The user reviews normal caps and workflow options, then presses CRAFT.
10. Auto Crafter completes or reuses the melee target first, then activates and completes or reuses the ranged target.

A visible `Paste Games Lantern build` action must accompany Ctrl+V for controller users, discoverability, and recovery when the keyboard shortcut is captured by another UI element.

## Owner-specified queue product contract

This section is authoritative when it differs from earlier single-target exploration in this spike.

### Queue composition and order

A valid Games Lantern import produces exactly two ordered jobs when the build exposes one valid melee and one valid ranged weapon:

```text
job 1: melee weapon
job 2: ranged weapon
```

Order is fixed to melee then ranged regardless of which weapon happened to be selected before Ctrl+V. Existing Auto Crafter workflow behavior inside each job remains unchanged. Queue orchestration must call the current single-item workflow rather than introduce a second crafting implementation.

Each job is a frozen target specification:

```text
QueueJob
  queue_id
  position
  slot_kind              -- melee | ranged
  weapon_family/mark
  resolved Brunt offer/master identity
  dump_stat_identity
  dump_target            -- retained Auto Crafter setting, normally 60
  perk_target_1
  perk_target_2
  blessing_target_1
  blessing_target_2
  state                   -- queued | active | completed | stopped | failed
  completion_kind         -- crafted | resumed | exact_existing
  final_gear_id           -- only after authoritative confirmation
```

The queue is valid only when every job has a unique compatible weapon, dump stat, two perks, and two blessings. If either weapon is malformed or unresolved, report which weapon and fields failed and do not install a partial queue. This is safer and less surprising than silently crafting only half of a pasted build.

### Planner activation

On successful import:

1. Save the current native manual weapon selection as a restorable identity; leave persistent manual target settings untouched.
2. Install the two immutable queue jobs atomically.
3. Select the melee weapon in Brunt's native view.
4. Activate a queue-owned planner overlay so the visible controls correspond to the melee job without persisting imported values through `mod:set`.
5. Rebuild and verify the normal plan.
6. Render the ranged job as queued without requiring it to be visible in Brunt.

When melee reaches an authoritative terminal success, activate ranged atomically:

1. mark melee completed with its final gear identity;
2. close dispatch and refresh authoritative inventory/resources;
3. select the ranged weapon family/offer in Brunt when the view is still available;
4. switch the queue-owned planner overlay to the ranged job;
5. run the full normal preflight for ranged;
6. dispatch ranged only if preflight succeeds.

Queue activation must not reinterpret settings edited for the active job as changes to the queued job. A queued job is frozen from import. If editing queue jobs is later desired, it needs an explicit Edit/Revalidate interaction rather than accidental coupling to global settings.

### Target and planner labels

Without a Games Lantern queue, existing single-target labels remain unchanged.

With two pending jobs:

```text
Target:         Queued (Arc Maul => Arc Rifle)
Planner target: Queued (Arc Maul => Arc Rifle)
```

Names are examples; use localized weapon display names. If the first job is complete and ranged is active, labels should communicate progress rather than imply both remain pending, for example:

```text
Target:         Active (Arc Rifle)
Planner target: Active (Arc Rifle)
Queue progress: 1/2 complete
```

If an exact finished melee weapon is reused, it still counts as completed job 1 and the queue advances to ranged without crafting or spending on melee.

### Active Queue section

Add a new expanded `Active Queue` section immediately above `Planner configuration`.

The section is always present while Auto Crafter is enabled:

- default/manual mode renders one detailed row for the current single weapon target;
- Games Lantern mode renders two detailed rows, melee first and ranged second;
- the active row uses the existing yellow selected/action visual language;
- queued rows remain neutral;
- completed rows use a restrained completed indicator/checkmark;
- failed or stopped rows use explicit status text and must not masquerade as completed.

Default mode includes a compact `Paste Games Lantern build` action inside Active Queue. Imported idle/completed mode replaces it with explicit `Replace Queue` and `Clear Queue` actions. Running, stopping, quarantined, or unresolved mode disables replacement/clear while leaving STOP available. Invalid paste/import errors appear in this section and a bounded notification without erasing the previously valid queue or overwriting an account-workflow failure.

Each larger row should show, without requiring the lower planner controls to be expanded:

- queue position and state;
- weapon icon and localized family/mark name;
- dump-stat label and target value;
- perk 1 and perk 2 labels;
- blessing 1 and blessing 2 labels/icons where practical;
- completion source (`new`, `resumed`, or `exact existing`) once known.

The row must be derived from the frozen queue job, not whichever global planner values happen to be active. Long names need wrapping/truncation rules and a tooltip; the row cannot silently clip a blessing or weapon identity.

### CRAFT and STOP semantics

CRAFT means `process the current validated queue serially`:

- run the existing preflight independently for melee;
- complete/reuse melee;
- refresh authoritative state;
- run a new preflight independently for ranged;
- complete/reuse ranged;
- report one queue summary plus per-job outcomes.

STOP / INTERRUPT remains graceful:

- never cancel or duplicate a request already dispatched;
- close dispatch immediately for the next request;
- settle and reconcile the in-flight request;
- retain completed jobs and current-job recovery identity;
- do not start the next queue job;
- leave a resumable stopped queue only after authoritative reconciliation.

Resuming must revalidate character, inventory, resources, mastery, current gear revision, target availability, and completed-job postconditions. It must never rely only on the previous local queue snapshot.

### Queue budget and confirmation semantics

Importing a second job must not silently double the user's understood spending authority.

- Existing acquisition/material limits retain their current meaning for each invariant single-item workflow; queue orchestration must not rewrite them.
- Before CRAFT, queue preflight presents melee maximum/projected cost, ranged maximum/projected cost, and the aggregate maximum/projected cost.
- Confirmation explicitly states that two weapons will be processed serially and that the displayed aggregate can be spent.
- If an exact-existing or resumable candidate lowers a job's forecast, refresh the aggregate from authoritative inventory before confirmation.
- Before ranged starts, refresh wallets and rerun ranged preflight. The earlier aggregate confirmation is not permission to dispatch when current resources are insufficient.
- Confirmed melee spending is never rolled back conceptually because ranged later blocks; the queue reports `1/2 complete` and the precise ranged shortfall.
- A queue-wide hard cap is out of initial scope; initial implementation must not ambiguously repurpose an existing per-weapon setting.

### Queue lifetime and clearing

The safe initial lifetime is session-local:

- an imported idle/stopped queue remains visible until completed, explicitly cleared/replaced, the character changes, or the mod/game reloads;
- a completed two-row result remains visible for review until the user selects a new manual target or presses `Clear Queue`;
- clearing/restoring removes the overlay and returns Active Queue to one row derived from persistent manual settings and a still-valid restored/current native target, or a `No target selected` row when none exists;
- clearing a queue is unavailable while a request is unresolved;
- clearing never discards, unfavorites, downgrades, or otherwise changes completed gear;
- no queue automatically resumes spending after reload.

### Imported target editing policy

The initial implementation must remove ambiguity by locking imported target fields while an imported queue exists:

- dump-stat identity and dump target;
- perk target 1/2;
- blessing target 1/2;
- native weapon target selection when it would replace the active queued family.

The rows remain readable. Attempting to change one must explain `Clear or replace the imported queue to edit weapon targets`. Do not repeatedly fight the native UI by silently restoring selections every frame; intercept the action or invalidate through an explicit confirmation.

The active overlay is read by panel display, planner composition, and `start_frozen_job`; it is not saved as the user's normal DMF settings. Queue clear/reload therefore reveals the exact persistent manual values that existed before import. Do not implement the overlay as persistent `mod:set` writes followed by best-effort restoration.

While the queue is idle or reconciled-stopped, workflow toggles, resume/favorite policy, request caps, and resource limits remain editable. Pressing CRAFT captures one immutable `QueueRunPolicy` from those controls for all still-pending jobs. While either job is active or unresolved, every setting that can alter account behavior is disabled in the panel; an external setting change follows the existing `run_configuration_changed` stop path.

After a safe stop, pressing CRAFT again performs a new aggregate confirmation and captures a new policy for pending jobs only. Completed jobs are never reopened merely because policy changed.

### Queue policy snapshot

The queue must distinguish immutable imported targets from user-controlled run policy:

```text
Imported target, frozen at successful Ctrl+V
  weapon identity
  slot kind
  dump-stat identity and target
  desired perk identity set
  desired blessing identity/tier-policy set
  source UUID/content fingerprint

QueueRunPolicy, frozen at each explicit CRAFT/Resume
  acquisition docket/max-purchase caps
  buy-until-target and fallback behavior
  resume and include-favorite policy
  defer/discard policy
  mastery leveling and allocation toggles
  consecrate/expertise/perk/blessing toggles
  favorite-result behavior
  request mode (current invariant behavior only)
```

Do not let job 2 reread mutable globals after job 1. Materialize job 2 using the same frozen `QueueRunPolicy`, then rerun authoritative resource and inventory preflight. This prevents a UI/mod setting mutation at the boundary from changing the queued contract without a stop and fresh confirmation.

### Completion terminology and exact-match contract

Use these terms consistently in code, logs, tests, and UI:

- **Exact base**: correct character, exact weapon mark/family, authoritative level-500 projected dump stat equals the frozen target. This is the current acquisition success condition, not proof that final crafting is done.
- **Final gear satisfied**: exact base plus every enabled final-item postcondition: required rarity, expertise 500, desired perk set, desired blessing set/tier policy, and favorite state when enabled.
- **Family progression satisfied**: enabled mastery level, claimed milestones, mastery-point allocation/sticker-book, and expertise-cap requirements are authoritative for that weapon family. These are not properties of one gear item.
- **Job complete**: one authoritative gear ID satisfies final gear, family progression satisfies all enabled dependent requirements, no request is unresolved, and final verification has succeeded.

Never label a dump-stat match alone as `exact finished`. In particular, the current controller's `_accept_exact_candidate` means exact acquisition base; Phase 3/4 may still need substantial work.

An imported Games Lantern queue is an exact-build target. Importing does not silently enable workflow toggles. At preflight:

- if a disabled step is unnecessary because authoritative state already satisfies its postcondition, continue;
- if a disabled step is required to reach the imported target, block and name the setting to enable;
- never report queue completion while imported perks/blessings are knowingly unenforced.

### Trait ordering and tier policy

Games Lantern card order is presentation data, not guaranteed Darktide slot identity. Store imported perks and blessings as two-element desired identity sets. For a selected/resumed item:

1. compare current and desired traits as sets before scheduling replacements;
2. if both sets already match, perform zero trait mutations even when slot order differs;
3. otherwise choose a deterministic slot assignment minimizing writes and avoiding duplicate/kept-slot conflicts;
4. then adapt that assignment to the existing slot-oriented Phase 4 API;
5. verify the final authoritative item as a set plus the selected tier policy.

Games Lantern currently does not prove a blessing tier. Resolve blessing identity and use Auto Crafter's existing highest-valid/import policy; record the resolved required tier in the frozen job before CRAFT. Lower-tier copies are not exact when the policy requires a higher tier.

### View closure and background behavior

The current single-item controller deliberately allows an active job to finish after Brunt closes while the character remains in a valid Morningstar context. Preserve that behavior.

For a two-job queue:

- the active job may finish in the background under existing context/mutation rules;
- if Brunt remains open, the queue may transition to job 2 after native selection, catalog refresh, and fresh preflight;
- if Brunt is closed when job 1 completes, do **not** invent a viewless start path for job 2 in the initial implementation;
- instead, mark the queue safely stopped at the boundary, release ownership after settlement, retain `1/2 complete`, and require Brunt reopen plus an explicit CRAFT/Resume;
- entering a mission, Psykanium/loading context, operative selection, or changing character remains a context exit and can never start job 2.

This preserves current background reliability without broadening where a new account-mutating workflow may begin.

## Evidence hierarchy and source limits

This spike used, in descending order:

1. The installed Lantern of the Omnissiah v2.1.0 runtime under `Content/mods/Lantern of the Omnissiah`.
2. BetterInventory's current 2.1.0 branch and live Auto Crafter catalog/planner code.
3. The supplied public Games Lantern build page, fetched on 2026-08-10.
4. Lantern's public GitHub repository and README.

The installed Lantern package and repository root expose no license file. Its behavior is valid implementation evidence, but BetterInventory must not copy substantial source code without author permission or a published compatible license. Implement the protocol independently, or establish an explicit narrow inter-mod API with Lantern's author.

## Supplied URL investigation

Input URL:

`https://darktide.gameslantern.com/builds/a0a667cd-4d49-4f68-8cf8-2f1ee57eab29/very-in-depth-h40-melee-psyker-guide-2-builds`

Canonical fetch URL:

`https://darktide.gameslantern.com/builds/a0a667cd-4d49-4f68-8cf8-2f1ee57eab29`

The slug is descriptive and unnecessary. The UUID is the stable locator.

The live response was approximately 296 KB and contained two unique weapon links, four blessing-image occurrences, and the supplied UUID. It did not expose a `__NEXT_DATA__` or Inertia `data-page` payload. The currently demonstrated path is therefore server-rendered HTML parsing, not a documented public JSON API.

The page exposes these structured weapon recommendations:

| Slot | Weapon | Lowest modifier | Perks | Blessings |
|---|---|---|---|---|
| Melee | Covenant Mk VI Blaze Force Greatsword | Warp Resistance `0/80` | Carapace Armoured damage; Unyielding damage | Unstable Power; Riposte |
| Ranged | Nomanus Mk VI Electrokinetic Force Staff | Charge Rate `60/80` | Maniac damage; ranged critical chance | Surge; Warp Nexus |

For the screenshot's melee target, importing must produce:

```text
weapon family/mark: Covenant Mk VI Blaze Force Greatsword
dump stat identity: Warp Resistance
dump target value: 60 (retain Auto Crafter default; do not import 0)
perk target 1: Damage vs Carapace Armoured Enemies
perk target 2: Damage vs Unyielding Enemies
blessing target 1: Unstable Power
blessing target 2: Riposte
```

The queued ranged target from the same page must produce:

```text
weapon family/mark: Nomanus Mk VI Electrokinetic Force Staff
dump stat identity: Charge Rate
dump target value: 60
perk target 1: Damage vs Maniacs
perk target 2: Ranged Critical Strike Chance
blessing target 1: Surge
blessing target 2: Warp Nexus
```

Games Lantern's `0/80` means “this is the allocated dump modifier” in a theoretical build distribution. A finished perfect-roll Darktide weapon normally targets 60 in that modifier. Treating the website's zero as an attainable purchase target would cause an endless or wasteful Brunt search. The importer must import the **stat identity**, not overwrite `auto_crafter_dump_stat_target` from the website value.

## Lantern of the Omnissiah analysis

### Clipboard contract

`modules/clipboard.lua` reads `_G.Clipboard.get`, recognizes `gameslantern.com/builds/<UUID>` anywhere in clipboard text, removes the optional slug/query by rebuilding the URL, and emits a canonical `https://darktide.gameslantern.com/builds/<UUID>` URL.

This proves that Games Lantern's Copy button output is sufficient. No browser extension or custom clipboard payload is required.

The production BetterInventory validator must be stricter than Lantern's current pattern:

- require an exact `https` URL;
- allow only `darktide.gameslantern.com` in the initial implementation;
- require a canonical UUID shape of 8-4-4-4-12 hexadecimal characters;
- rebuild the URL from the captured UUID before invoking any process;
- reject user info, ports, encoded host tricks, arbitrary paths, and non-URL clipboard text.

Canonical reconstruction is also the command-injection boundary. Never interpolate the raw clipboard string into a batch or shell command.

### Fetch contract

`modules/fetch.lua` demonstrates that there is no relied-upon native Lua HTTP client:

- Windows writes a short temporary batch script and launches the system `curl.exe` detached.
- Wine/Proton uses the `Z:` mapping to invoke host `curl` or `wget` through a shell script.
- Darktide polls a completion file and later reads the downloaded HTML and diagnostics.
- Lantern applies a 30-second application-level timeout and removes temporary artifacts.

The approach is viable, but BetterInventory's version must enforce:

- one fetch in flight per panel/import generation;
- connect and total timeouts at the transport layer as well as in Lua;
- HTTPS-only protocols with redirect following disabled initially; if Games Lantern later requires redirects, validate every `Location` as the same exact HTTPS host before a separate request;
- response-size cap before parsing, suggested initial limit 2 MiB;
- nonzero exit-code and HTTP-status validation;
- unique filenames containing a random/session component, not only a process-local sequence;
- owner-tagged cleanup that cannot delete another mod's temporary files;
- bounded diagnostics and no response body in routine logs;
- stale callbacks ignored after view exit, character switch, hot reload, or a newer paste;
- short bounded cache keyed by canonical UUID, with an explicit refresh option.

Native Windows `curl.exe` is broadly available on supported Windows versions but is still a runtime dependency that can be missing or blocked. Proton support depends on host `curl`/`wget` and the `Z:` mapping. Failure must remain a non-mutating panel error with manual retry instructions.

### Equipment parser contract

`modules/equipment_parser.lua` splits weapon cards from server-rendered HTML and extracts:

- display name and rarity;
- weapon family and mark slug from `/weapons/<family>/<mark>`;
- perk display strings;
- blessing display names/descriptions and numeric icon suffixes;
- stat display labels and percentage widths.

That is sufficient to build an Auto Crafter import candidate. It is not a durable API contract. The parser currently depends on exact Tailwind class strings and nearby HTML ordering, so any Games Lantern redesign can break it without changing visible content.

BetterInventory must use a versioned parser boundary returning either a complete typed result or an explicit unsupported-format error. Partial parser success must not silently modify planner settings.

### Stored equipment and BetterInventory's existing integration

Lantern stores parsed equipment under the active preset and exposes modules through `lantern_mod._modules`, including `equipment_parser`, `equipment_store`, `build_store`, and `equipment_overlay`. BetterInventory currently integrates only with `equipment_overlay` in `BetterInventory_feature_lantern.lua`; it hosts Lantern's recommendation display and suppresses the duplicate floating panel.

Those `_modules` tables are private implementation details rather than a stable public API. The initial implementation must not consume them, require Lantern, or call Lantern's normal import flow: that flow also parses and applies talents to the active preset.

Compatibility order:

1. A future explicit Lantern provider API such as `parse_gameslantern_equipment(url, callback)`.
2. BetterInventory's independent equipment-only importer.
3. No private-module adapter in the initial implementation. Any later adapter requires a separately reviewed compatibility contract.

If both mods are installed, BetterInventory owns Ctrl+V only while its Brunt panel is the active target. It must not trigger `/lantern`, overwrite talent presets, or launch duplicate fetches for the same gesture.

## BetterInventory integration points

### Brunt lifecycle

BetterInventory already attaches Auto Crafter specifically to `CreditsGoodsVendorView`, which is Brunt's Armoury. The panel is detached on view/context exit, and its update loop is guarded by `pcall` at the feature facade.

This gives the importer a precise lifecycle boundary:

- enabled only when Auto Crafter is enabled;
- active only while the Brunt panel is attached and visible;
- accepted only while the controller is idle and owns no mutation;
- an in-flight clipboard/fetch/parse import is cancelled when the panel detaches, the active character changes, or the import generation changes;
- an already installed idle queue lives in the core coordinator and can reappear when Brunt reopens;
- an active job follows the existing controller background/context rules described above.

### Keyboard gesture

Darktide exposes raw keyboard state through `_G.Keyboard`; installed DMF code uses `Keyboard.button_index` and `Keyboard.button`. The current Auto Crafter panel update receives `dt`, but not the view's `input_service`, so the clean implementation choices are:

1. add a tiny raw-key edge detector to the attached panel; or
2. pass the view input service into a dedicated importer input adapter from the Brunt update hook.

Use the view input service when it exposes a reliable unmapped keyboard event. Otherwise use the scoped raw-key edge detector. Do not install both active detectors simultaneously.

Required gesture semantics:

- detect a rising edge for `V` while either Ctrl key is held;
- debounce until V is released;
- ignore autorepeat and duplicate URL generations;
- ignore while a text-entry widget, popup, confirmation, or external overlay owns keyboard input;
- ignore while Auto Crafter is running, stopping, reconciling, quarantined, or has auxiliary operations;
- do not consume native input unless an eligible Games Lantern URL is actually recognized;
- never poll or parse the clipboard every frame—read only on the gesture/button action.

### Existing planner catalogues

The Auto Crafter backend already derives live, selected-weapon-specific catalogues:

- base-stat identities and localized labels;
- perk item IDs, labels, descriptions, and availability;
- blessing item IDs, labels, icon/material identity, tier ownership, and availability;
- Brunt offer/master-item identity.

The importer must resolve external data into these live IDs and then use the same panel/planner validation path as manual choices. It must not invent hardcoded Darktide trait IDs from English names.

## Resolution algorithm

### Step 1: parse without side effects

Produce an immutable external model:

```text
BuildImport
  source_uuid
  source_title
  source_author
  source_archetype
  fetched_at
  content_fingerprint
  parser_contract_version
  weapons[]
    external_family_slug
    external_mark_slug
    display_name
    stats[] { label, value }
    perks[] { label, optional_external_id }
    blessings[] { label, description, optional_icon_id }
```

Reject empty, oversized, malformed, login/challenge, and equipment-free pages before consulting the planner. Only structured weapon cards in the build's Weapons section are authoritative. Do not scrape prose alternatives such as “swap Riposte for Precognition,” images, comments, changelogs, linked secondary builds, or browser-visible guide text into the queue.

Capture a response fingerprint and parser contract version. A queued job uses the exact parsed response from the paste action; it does not silently refetch and change targets at CRAFT time. Pasting the same UUID with explicit Refresh bypasses cache, produces a new fingerprint, and requires queue replacement confirmation if targets differ.

### Step 2: resolve the weapon

Resolution priority is:

1. exact family/mark identity if a maintained Games Lantern-to-Darktide mapping exists;
2. exact normalized mark slug against the live Brunt offer/master-item catalog;
3. unique normalized localized/display-name match;
4. explicit user selection among compatible candidates;
5. fail closed.

Exact mark identity is mandatory before account mutation. Mastery-family equality alone is insufficient because one mastery family may contain several marks. If the live catalog cannot distinguish the Games Lantern mark by master item or weapon template, the job is unresolved even when its family name looks compatible.

The parsed Games Lantern archetype must resolve to the currently active Darktide archetype. Reject missing/unknown/different archetypes even when both recommended weapons happen to be shared across classes. Use a reviewed alias layer only to bridge known external/internal slug differences; final authorization still comes from the active character and live item availability. This check must rerun after InstantCharacterChange events.

Resolve slot kind for every candidate. A standard import requires exactly one uniquely resolvable melee candidate and one uniquely resolvable ranged candidate. The active Brunt offer is useful catalog context, but it does not filter either queue job away. After both resolve, select melee as job 1 and retain ranged as job 2 even though the ranged configuration is not yet represented by the lower native planner controls.

If the page contains multiple compatible candidates for one slot, show a slot-specific chooser before installing the queue. If either imported weapon is unavailable to the current class/character, report that and apply nothing. Never select the first HTML card merely because it appeared first.

The supplied page currently has exactly two unique weapon links: one melee Greatsword and one ranged Force Staff. It therefore forms an unambiguous two-job queue for a compatible Psyker.

### Step 3: resolve the dump stat

Normalize website stat labels and compare them against the selected weapon's live base-stat candidates. Preferred identity evidence is a live/internal mapping linked to the exact weapon mark; localized label matching is a fallback.

Rules:

- choose the unique lowest displayed modifier as the dump-stat identity;
- never import its website value as the Brunt target;
- retain the user's existing dump target, normally 60;
- if the minimum is tied, absent, or does not map uniquely, require manual selection;
- validate that the resolved stat belongs to its queue job's exact weapon before queue installation.

Also reject nonfinite, negative, over-100, duplicated-label, or incomplete stat data. If all displayed modifiers are equal, there is no inferable dump stat; require explicit user resolution rather than selecting the first stat. A tie remains ambiguous even when one tied stat happens to match the previous manual setting.

For the supplied Greatsword, `Warp Resistance 0` uniquely resolves to Warp Resistance; the other four stats are 80.

### Step 4: resolve perks

Games Lantern emits descriptive value ranges such as `10-25% Damage (Carapace Armoured Enemies)`, while Auto Crafter needs the internal perk target ID. Resolution must:

1. strip numeric ranges, markup, punctuation variance, and benign spelling variants;
2. compare semantic armor/category and melee/ranged scope against the selected weapon's live perk catalog;
3. require a unique match;
4. preserve page order only for UI display—execution assigns slots deterministically using the set/minimum-write policy;
5. reject duplicate or unavailable targets.

Games Lantern imports always produce two explicit perk identities and two explicit blessing identities. They never import Auto Crafter's `keep` sentinel. A card with fewer than two explicit perks or blessings is incomplete for this exact-build queue and is rejected, even if the currently selected inventory item could coincidentally keep a missing slot.

Do not assume English-only text. A public Games Lantern page may remain English while Darktide is localized. Maintain a small semantic external mapping keyed by Games Lantern slug/ID where possible, then resolve to live IDs; name normalization is the fallback, not the primary long-term contract.

### Step 5: resolve blessings

Lantern extracts numeric suffixes from `weapon_trait_<n>.webp`, but these image identifiers are not globally sufficient by themselves. In the supplied page, icon identifier `064` appears in more than one weapon context. Resolve blessing identity using the tuple:

```text
selected weapon family/mark + external icon ID + normalized blessing name
```

Then match only within the selected weapon's live blessing catalogue. Require a unique result. The imported recommendation expresses the blessing type; Auto Crafter must retain its existing highest-valid tier/mastery ownership rules.

If a recommended blessing is not currently selectable for that weapon, show it as unresolved and block queue installation rather than substituting a similarly named trait.

Games Lantern rarity text is informational. Import must never request a downgrade or weaken Auto Crafter's enabled rarity/expertise postconditions. Unknown rarity text does not authorize crafting; target trait/stat completeness and live workflow preflight remain authoritative.

### Step 6: stage and install the queue atomically

Ctrl+V must resolve a complete queue model before changing the visible planner. The validation result includes:

- source build title and UUID;
- resolved melee and ranged weapons and Brunt identities;
- both dump-stat identities and retained target values;
- both perk/blessing pairs for each weapon;
- warnings and unresolved fields;
- fetch age/cache status.

Install only when every required field on both jobs has a unique valid live ID. Before installation, capture the previous native target identity and any previous idle queue state. Store both frozen jobs, activate the nonpersistent melee overlay, select the melee offer, force the normal planner/catalog refresh, and verify the resulting plan. If any selection, overlay, or validation step fails, remove/restore the local queue state and native selection and report a bounded error. Persistent manual target settings remain untouched throughout.

The importer must not alter workflow toggles, resource caps, favoriting, inventory-resume policy, mastery behavior, or sequential request behavior.

## State machine

Recommended importer states:

```text
idle
  -> clipboard_validating
  -> fetching
  -> parsing
  -> resolving_melee
  -> resolving_ranged
  -> queue_validated
  -> queue_installing
  -> queue_ready
  -> melee_active
  -> melee_completed
  -> ranged_preflight
  -> ranged_active
  -> queue_completed

Any pre-install state -> cancelled (view/character/import generation changed)
Any pre-install state -> failed (bounded non-mutating error)
queue_installing -> rolled_back (atomic validation failed)
queue_ready + Brunt close -> retained_idle (no ownership held, no dispatch)
active job + Brunt close -> active job may settle; next boundary -> reconciled_stopped
Any crafting state -> stopping -> reconciled_stopped
Any installed state + character/context exit -> stopped/cleared per authoritative recovery state
Any job -> failed (bounded terminal error; later jobs remain undispatched)
```

Each asynchronous callback carries an import generation, canonical UUID, active character ID, Brunt view identity, and queue identity. A callback is ignored unless all still match. Once a queue is installed, manual native weapon selection must not silently rewrite its frozen jobs; either restore the active queued weapon selection or explicitly stop/invalidate the queue before accepting a new manual target.

### Queue transition table

Only the transitions below are permitted. Any unlisted event closes dispatch and reports an invariant violation.

| Current state | Event/guard | Next state | May dispatch account mutation? |
|---|---|---|---|
| idle | valid Ctrl+V, both jobs fully resolved | queue_ready | No |
| idle/importing | invalid URL/build/weapon/trait | failed import, then idle | No |
| queue_ready | explicit CRAFT + aggregate confirmation + melee preflight | melee_active | Yes, existing job workflow only |
| queue_ready | exact fully satisfied melee | melee_completed | No for melee |
| melee_active | request success but job postconditions incomplete | melee_active | Only next existing workflow step |
| melee_active | authoritative job completion | melee_completed | No until boundary guards pass |
| melee_active | STOP/failure/quarantine/context exit | stopping/failed/quarantined | No follow-up |
| melee_completed | Brunt open, same character, token owned, ranged selected/catalogued/preflight ready | ranged_active | Yes, existing job workflow only |
| melee_completed | Brunt closed or ranged blocked | reconciled_stopped/blocked at 1/2 | No |
| ranged_active | request success but job postconditions incomplete | ranged_active | Only next existing workflow step |
| ranged_active | authoritative job completion + final both-job verification | queue_completed | No |
| ranged_active | STOP/failure/quarantine/context exit | stopping/failed/quarantined at 1/2 | No follow-up |
| reconciled_stopped/blocked | explicit CRAFT/Resume + fresh confirmation/preflight | relevant pending job active | Yes |
| queue_completed | clear/new manual target | idle/manual one-row mode | No |

`Job complete` is a postcondition, never merely a Promise resolution or local phase label. The coordinator must consume a typed terminal outcome from the single-item controller instead of inferring success from HUD text.

## Non-negotiable implementation invariants

These are mandatory handoff constraints, not suggestions:

1. **No queue means no behavior change.** The existing manual one-item path, defaults, settings, CRAFT/STOP behavior, controller timings, request order, candidate ranking, HUD, and background behavior must remain byte-for-byte or behaviorally equivalent wherever practical.
2. **One workflow implementation.** Queue code orchestrates the existing single-item controller. It must not duplicate purchase, mastery, sacrifice, consecrate, expertise, trait replacement, favorite, retry, or reconciliation logic.
3. **Queue state is not panel state.** Store it in a core controller/coordinator owned by the Auto Crafter facade. Panel detach/rebuild must not destroy an active job or lose recovery identity.
4. **No new mutation parallelism.** Jobs and their requests remain serial under the current invariant request behavior.
5. **One queue-level ownership lease.** While transitioning automatically from job 1 to job 2 in an open valid Brunt view, retain the existing `auto_crafter` operation token so discard, Curio Buyer, native UI, Quick Level Mastery, and third-party mutations cannot enter the boundary.
6. **No ownership leak.** Release the token exactly once on queue complete, safe stop, terminal failure, context exit settlement, or view-closed boundary stop. Never release while a normal or auxiliary request is unresolved/quarantined.
7. **No next-job dispatch from local success.** Job 2 requires authoritative job-1 completion, zero unresolved operations, valid same character/context, confirmed native target selection, fresh catalog, fresh inventory/wallet/mastery reads, and passing preflight.
8. **No blind retries.** Preserve current mutation ambiguity/quarantine policy. A transport or backend timeout cannot trigger duplicate purchase/crafting/discard calls or advance the queue.
9. **No partial import.** Both jobs resolve completely before native selection/settings change. Roll back all local installation changes on failure.
10. **No hardcoded content catalogue.** Resolve live weapon/stat/perk/blessing identities. Static aliases may assist matching but cannot authorize an unavailable target.
11. **No hidden spending authority.** CRAFT/Resume is explicit, aggregate cost is disclosed, and job 2 re-preflights resources.
12. **No automatic post-reload spending.** Session/recovery state can explain what happened, but only a new explicit action may resume.
13. **No unsafe shell input.** Only a canonical UUID-derived HTTPS URL reaches an external process.
14. **No unbounded work.** Clipboard, fetch, body size, cache, filesystem polling, diagnostics, queue length, UI rows, retries, and logs are bounded.
15. **Every terminal state is visible.** Complete, stopped, blocked, failed, quarantined, and reconciliation-required are distinct; none may collapse into a vanished HUD/panel.
16. **Busy state includes queue transitions.** Facade `is_busy`, STOP, HUD, mutation interruption, Automatic Discard deferral, and Curio Buyer deferral must treat an ownership-held melee->ranged transition as active work even when the inner single-job controller is momentarily terminal.

### Operation ownership seam

Current controller ownership is scoped to one run and `release_account_operation_if_settled()` releases at `phase4_complete`. A lower-level agent must not overlook this. Add a narrowly tested queue hold/lease seam so first-job completion does not briefly release the `auto_crafter` token before an automatic second-job transition.

The existing single-job path must still release at the same point when no queue is active. Do not change `BetterInventory_operation_arbiter.lua` into a reentrant/general lock unless unavoidable; a queue-aware hold in Auto Crafter's current owner is lower risk. Tests must prove:

- manual run release behavior is unchanged;
- queue token remains identical across the open-view job boundary;
- another owner cannot acquire in that boundary;
- STOP/failure/context exit releases once after settlement;
- a closed Brunt boundary stops and releases instead of holding an idle account lock indefinitely.

The automatic boundary has a bounded deadline no longer than the existing read timeout. Selection, probe, or catalog work that cannot converge by the deadline stops at `1/2`, releases after settlement, and never leaves an invisible idle token.

Extend facade snapshots with explicit queue fields rather than overloading existing phase strings:

```text
queue.active
queue.id
queue.state
queue.current_index
queue.completed_count
queue.transition_inflight
queue.ownership_held
queue.jobs[]
```

`AutoCrafter.is_busy()` and mutation-guard integration must include `transition_inflight` and `ownership_held`. `STOP / INTERRUPT` must route to the queue coordinator first, which closes queue continuation and delegates settlement of any active inner job to the existing controller.

### Native selection and catalog barrier

Selecting the ranged offer is asynchronous and currently triggers selected-target/catalog refresh behavior. The queue must:

1. request selection using the existing panel/native selection adapter;
2. wait until native selected offer identity equals the frozen ranged master/offer identity;
3. refresh/probe the active character snapshot;
4. rebuild the ranged trait catalog and verify its parent pattern/mark identity;
5. materialize ranged targets and verify planner preflight;
6. only then call the existing start entry point.

Bound selection attempts/time. A failed or oscillating selection stops at `1/2` without spending on ranged. Suppress the normal `selected_weapon_changed` stop only for the exact queue-owned expected transition; all other selection changes retain current stop behavior.

## Safety and security requirements

This import occurs beside an account-mutating feature, so it must satisfy stronger boundaries than a normal URL preview:

- Import is unavailable whenever Auto Crafter's global mutation arbiter is owned.
- Import performs zero store, gear, mastery, wallet, crafting, discard, or favorite calls. Native offer selection and local planner/queue updates are allowed.
- CRAFT remains a separate explicit click and normal preflight/confirmation remains unchanged.
- No raw URL, HTML, cookies, account token, or authenticated headers are written to BetterInventory logs.
- Log UUID, stage, byte count, parser version, candidate counts, resolution result, and bounded errors.
- Never execute HTML, JavaScript, or JSON-derived code.
- Never pass unvalidated clipboard text to `cmd`, PowerShell, a batch file, or `/bin/sh`.
- Escape all generated file paths; do not share Lantern's filename namespace.
- Do not retry transport failures indefinitely. One manual retry is safer than hidden polling.
- A timeout, network loss, website challenge, parser drift, missing dependency, or one invalid weapon leaves planner and queue settings untouched.

## Failure and edge-case matrix

| Condition | Required behavior |
|---|---|
| Clipboard is empty or not a Games Lantern build URL | No fetch; concise local message; no setting changes. |
| URL has a slug/query | Extract UUID and canonicalize. |
| URL host is deceptive or protocol is not HTTPS | Reject before process launch. |
| Canonical request returns a redirect | Initial implementation rejects it; later support requires separately validated same-host HTTPS Location. |
| Private/deleted build or login page | Report unavailable; preserve planner. |
| Games Lantern is offline or stalls | Bounded timeout; clean temporary files; allow manual retry. |
| Network returns after timeout | Late completion is generation-stale and ignored/cleaned. |
| Response is very large | Abort at size cap; never parse unbounded data. |
| HTML classes/layout changed | Parser returns unsupported-format; never partially apply. |
| HTTP 200 contains a bot challenge, consent, login, or generic error page | Reject by expected build/UUID/equipment markers; do not treat status alone as success. |
| Cached UUID is stale after build author edits it | Show fetch age/fingerprint; explicit Refresh bypasses cache and requires replacement confirmation if targets changed. |
| Page prose mentions alternate weapons/traits or links another build | Ignore prose and linked builds; import only structured Weapons cards from this response. |
| No weapons | Report no equipment target. |
| Valid melee and ranged weapons | Install ordered melee -> ranged queue and activate melee. |
| One valid weapon and one invalid weapon | Name the invalid slot/fields and reject the entire imported queue; spend nothing. |
| Build contains only one weapon | Report missing melee/ranged slot and do not reinterpret it as a normal two-job import. |
| Multiple compatible weapons in either slot | Show a slot-specific chooser; do not pick first. |
| Build belongs to another class | Explain expected/current class and reject before changing native selection or planner settings. |
| Build archetype is missing or unknown | Reject as unsupported; do not infer class solely from its weapons. |
| Different-class build uses weapons shared with current class | Still reject on build archetype mismatch. |
| Imported mark unavailable to current operative | Explain incompatibility; no offer, queue, or planner mutation. |
| Weapon exists on Games Lantern but not in this installed Darktide version | Treat as unresolved content-version mismatch; never fall back to mastery family or nearest name. |
| Dump stat has a unique zero/minimum | Import identity; retain target 60/current setting. |
| Lowest stat is tied | Require manual dump-stat choice. |
| All modifier values are equal | No inferable dump stat; require explicit resolution. |
| Stat is duplicated, missing, nonnumeric, nonfinite, negative, or over 100 | Reject that weapon as malformed. |
| Perk/blessing cannot map uniquely | Identify weapon/field and block queue installation. |
| Same blessing icon ID appears in multiple families | Resolve with weapon context and name. |
| Imported trait order is reversed on an existing item | Compare desired sets, perform zero writes when identities/tier policy already match. |
| Imported page repeats the same perk or blessing twice | Reject malformed target rather than creating duplicate slot operations. |
| Weapon card has fewer than two explicit perks or blessings | Reject incomplete exact-build target; never synthesize `keep`. |
| User changes selected offer during fetch | Imported jobs remain source-driven; install only after revalidating both against the live catalog. |
| User presses Ctrl+V repeatedly | Debounce and deduplicate same canonical UUID. |
| User leaves Brunt during import | Cancel import generation and ignore/clean late fetch callbacks; preserve prior planner/queue. |
| User leaves Brunt with idle installed queue | Retain session-local queue with no ownership/dispatch; reconstruct it when Brunt reopens. |
| User leaves Brunt during active job | Existing background settlement applies; stop before the next job as specified. |
| User changes character | Cancel import or stop active work, clear character-scoped idle queue after reconciliation, and never reuse it on the new character. |
| User starts crafting before fetch completes | Cancel import; active workflow wins. |
| Existing Auto Crafter run is active/resumable | Reject import until controller is safely idle. |
| New melee and new ranged | Craft melee through normal workflow, reconcile, then craft ranged. |
| Resumable melee and new ranged | Reuse best valid melee base under existing resume policy, finish it, then craft ranged. |
| New melee and resumable ranged | Craft melee, refresh, then reuse and finish the ranged base. |
| Exact completed melee and new/resumable ranged | Verify exact melee, mark job 1 complete without spend, then activate ranged. |
| New/resumable melee and exact completed ranged | Finish melee, verify exact ranged, then mark job 2 complete without spend. |
| Both exact completed weapons exist | Verify both deterministically, perform no crafting spend, report queue complete and identify both gear IDs. |
| Multiple resumable candidates for one job | Use existing deterministic candidate ranking; log selected gear ID and preserve nonselected items. |
| Multiple fully complete copies exist | Select one deterministically for reporting; create no copy and mutate no nonselected item. |
| Fully complete copy is currently equipped | It satisfies the job after authoritative read-only verification; never unequip or duplicate it. |
| Equipped copy still needs crafting mutations | Do not mutate/unequip it automatically; choose another eligible base or block with an explicit explanation. |
| Favorited incomplete candidate while include-favorites is off | Preserve and ignore it under the existing resume policy. |
| Same gear appears eligible for both jobs | Impossible across distinct melee/ranged identities; treat duplicate identity as corrupted resolution and fail closed. |
| Missing resources before melee starts | Melee preflight fails; neither job dispatches; queue remains safely reviewable/resumable. |
| Resources run out during melee | Stop at existing per-step resource gate, reconcile melee, and never activate ranged. |
| Melee completes but ranged preflight lacks resources | Preserve confirmed melee completion, do not dispatch ranged, show exact ranged shortfall, retain resumable queue. |
| Resources run out during ranged | Preserve completed melee; stop/reconcile ranged using existing single-job recovery rules. |
| Inventory is full before either purchase loop | Fail that job's preflight before purchase and do not advance the queue. |
| Inventory fills between jobs | Ranged preflight catches it after melee reconciliation; ranged remains undispatched. |
| Mastery 20/all points already allocated | Skip mastery work independently per weapon family and continue normal job verification. |
| Mastery differs between melee and ranged families | Each job reads and preflights its own authoritative mastery/sticker-book state. |
| A workflow toggle needed for the imported result is disabled | Continue only if the postcondition is already satisfied; otherwise block and name the required toggle. |
| Imported perks/blessings are configured but their change toggles are disabled | Never claim exact-build completion unless authoritative gear already contains the desired sets. |
| CRAFT is pressed twice | First edge owns queue run; subsequent presses are inert while busy. |
| STOP during melee | Settle/reconcile current request, retain melee recovery state, and never start ranged. |
| STOP between jobs | Dispatch gate is already closed; ranged remains queued and untouched. |
| STOP during ranged | Preserve completed melee and reconcile only the ranged in-flight request. |
| Brunt closes after CRAFT | Active job may finish under existing background policy; stop at the next-job boundary and require reopen plus explicit Resume. |
| Character changes between jobs | Halt before ranged, invalidate character-scoped catalog, and require revalidation; never craft on the new character from stale jobs. |
| Active character ID temporarily becomes nil | Close dispatch; unresolved mutation settles into reconciliation-required state; never infer the previous/new character. |
| Native/manual/third-party inventory mutation occurs | Existing mutation guard interrupts between requests or quarantines unresolved work; next queue job cannot start. |
| Storefront rotates or offer ID/price changes before job 2 | Re-resolve exact frozen master identity from fresh store data, recalculate cost, and reconfirm if aggregate authority increases. |
| Wallet/materials change externally between jobs | Fresh preflight governs; never rely on reserved/projected resources. |
| Completed job's gear is manually discarded before queue completion | Final queue verification fails visibly; do not silently craft a replacement without a new explicit Resume confirmation. |
| Completed job's gear is equipped between jobs | Keep its gear ID and verify it normally; equipping alone is not failure. |
| Pending/resumed item is upgraded, discarded, favorited, or equipped manually | Fresh revision/identity check either replans compatible progress or stops; never mutate a stale gear revision. |
| Queue settings are manually edited | Active job changes require explicit revalidation; queued job remains frozen and cannot be silently mutated. |
| A second valid URL is pasted while an idle queue exists | Require explicit replacement confirmation or provide Replace Queue; never merge unrelated queues implicitly. |
| A second URL is pasted while queue is running/stopped-unreconciled | Reject until safely idle/reconciled. |
| Game/mod reload with idle imported queue | Default safe policy: do not auto-resume spending; restore only if queue persistence has complete versioned validation data. |
| Game/mod reload during run | Existing run recovery journal governs; no automatic next-job dispatch after reload. |
| Auto Crafter is disabled mid-run | Existing configuration-change stop/reconciliation applies; queue cannot keep dispatching. |
| Queue/controller/panel presentation throws | Existing facade containment must stop/detach the faulty presentation without losing unresolved mutation ownership; queue state reports recoverable fault. |
| Lantern is installed | Avoid talent import and duplicate fetch/input ownership. |
| Lantern is absent | Standalone BetterInventory importer still works. |
| Windows curl unavailable | Non-mutating transport diagnostic. |
| Proton lacks host curl/wget or Z mapping | Non-mutating platform diagnostic. |
| Hot reload occurs | Orphan cleanup; no callback can touch the new generation. |
| Clipboard API is unavailable or throws | Non-mutating diagnostic and visible paste-button failure; no per-frame retries. |
| Response uses unexpected encoding/compression | Transport must produce bounded decoded bytes or fail unsupported; parser never consumes an unbounded/partial stream. |

## Performance budget

The importer must add effectively zero idle-frame cost:

- no clipboard polling without a paste gesture;
- no URL parsing, catalog rebuilding, filesystem polling, or process checks while idle;
- while fetching, poll completion at 100-250 ms rather than every frame;
- parse once per downloaded body;
- cache only a small number of bounded responses or parsed models;
- release HTML after parsing and retain only the typed model/diagnostics;
- update the panel only on state transition or elapsed display cadence.

The existing Auto Crafter panel's 100 ms idle cadence is suitable for a small in-flight status check, but clipboard detection should still be edge-driven.

## Logging and diagnostics

Suggested bounded records:

```text
[GLImport] event=paste_detected generation=4 uuid=a0a667cd-... view=brunt
[GLImport] event=fetch_started transport=windows_curl timeout=30s
[GLImport] event=fetch_complete bytes=296277 elapsed=0.84s
[GLImport] event=parse_complete weapons=2 parser=html_v1
[GLImport] event=job_resolved slot=melee candidate=covenant-mk-vi-blaze-force-greatsword dump=warp_resistance perks=2 blessings=2
[GLImport] event=job_resolved slot=ranged candidate=nomanus-mk-vi-electrokinetic-force-staff dump=charge_rate perks=2 blessings=2
[GLImport] event=queue_installed queue=12 jobs=2 active=melee planner_valid=true
[GLQueue] event=job_started queue=12 job=1 slot=melee source=new
[GLQueue] event=job_completed queue=12 job=1 result=crafted gear=<id>
[GLQueue] event=job_preflight queue=12 job=2 slot=ranged result=blocked missing_plasteel=4200
[GLQueue] event=queue_stopped queue=12 complete=1/2 resumable=true
```

Failures must log stage, sanitized reason, response size/status, candidate count, and generation. Normal logs use a truncated/hashed build identifier and omit raw URL slug, title, author, guide prose, and HTML because users commonly upload logs and unlisted builds can be sensitive. Never dump the full HTML into the normal BetterInventory log. A debug-only fixture export may be offered separately with an explicit user action and prominent privacy/size warning.

## Test strategy

### Pure URL tests

- canonical URL with and without slug;
- uppercase/lowercase UUID;
- URL embedded in surrounding clipboard text;
- malformed UUID and missing segments;
- deceptive hosts, ports, credentials, encoded characters, non-HTTPS schemes;
- shell metacharacters after a valid-looking prefix;
- deduplication and V-key edge behavior.

### Parser fixture tests

Check in minimal, reviewed HTML fixtures rather than downloading during unit tests:

- supplied Greatsword/staff build and its exact two-slot ordering;
- melee-only and ranged-only builds;
- weapons with every supported stat label;
- missing perks/blessings and duplicate traits;
- apostrophes and HTML entities;
- reordered attributes and harmless whitespace;
- changed/unsupported CSS contract;
- login, 404, challenge, empty, truncated, and oversized pages;
- multiple compatible weapon cards;
- icon ID reused by different weapon families.

Expected results must assert exact family/mark, stat values, perk text, blessing name/icon tuple, and no executable content retention.

### Resolver tests

Use synthetic live Auto Crafter catalogs:

- exact slug and exact mark resolution;
- unique display-name fallback;
- localized game catalog versus English website labels;
- unsupported current class;
- one melee plus one ranged candidate producing a frozen melee -> ranged queue;
- missing or invalid melee with valid ranged rejects the whole import;
- valid melee with missing or invalid ranged rejects the whole import;
- different-class weapon pairs reject the whole import;
- ambiguous same-slot candidates;
- unique, tied, absent, and unmapped dump stats;
- exact, duplicate, unavailable, and renamed perk/blessing cases;
- same icon ID with different weapon context;
- website zero imports stat identity while target stays 60/current value.

### Queue state-machine and lifecycle tests

- paste while idle installs two validated local jobs and performs no account mutation;
- paste during every Auto Crafter phase is rejected;
- view exit, offer change, character change, hot reload, stop, and new paste invalidate stale callbacks;
- timeout followed by late success remains inert;
- queue installation creates both frozen jobs plus the active melee overlay atomically, while persistent manual settings remain unchanged;
- import, job transition, Clear Queue, Brunt close/reopen, and hot reload never persist the queue overlay into manual DMF target settings;
- planner validation failure restores old settings;
- CRAFT remains independent and receives the normal preflight;
- CRAFT activates melee first and cannot dispatch ranged before authoritative melee completion;
- exact-existing melee advances without spend; exact-existing ranged completes without spend;
- STOP during melee, between jobs, and during ranged never dispatches a later request;
- failed/blocked ranged preserves confirmed melee completion;
- repeated CRAFT and Ctrl+V edges are idempotent while owned;
- default/manual mode renders exactly one Active Queue row;
- imported mode renders two frozen rows and highlights only the active row yellow;
- completed, stopped, and failed row visual states match queue state;
- Lantern present/absent/disabled/unknown-version matrices;
- four sequential imports and four two-job crafts do not leak state across queues or jobs.

Add a table-driven transition test that iterates every row in the Queue transition table and rejects every unlisted transition. Assertions include queue/job state, generation, account-operation token, operation/auxiliary counters, dispatch count, active gear ID, current character ID, and terminal diagnostics.

### Regression-preservation tests

Before queue implementation, capture a baseline of the existing manual suite. After every implementation batch, prove:

- all existing tests remain present and pass; do not weaken assertions or recategorize critical cases;
- no-queue `start_purchase_search`, STOP, view-close background completion, configuration-change stop, mutation quarantine, candidate ranking, mastery, two-slot trait swap, and resource behavior are unchanged;
- operation owner token acquisition/release count is unchanged for a manual one-job run;
- panel layout and CPU tests remain at current budgets when no import is active;
- settings defaults/schema/localization counts change only for intentionally added UI strings/settings;
- Automatic Discard and Curio Buyer remain deferred only while Auto Crafter legitimately owns work and resume normally after release;
- installed runtime bundle, generated manifest, ZIP parity, and synchronization checks stay green;
- no test bypasses the public facade merely to make the queue pass when production uses a different path.

New queue tests must be additive. If a current invariant genuinely must change, stop the batch, document the exact reason and impact, and obtain owner approval before changing code/tests.

### Boundary fault-injection tests

Inject failure before dispatch, rejection, 5-7 second delay, timeout/quarantine, malformed success, stale success, and callback throw at every queue boundary:

- clipboard read;
- URL validation;
- process spawn;
- completion-file poll/read;
- HTML parse;
- melee resolution/catalog;
- atomic queue installation/native melee selection;
- queue CRAFT confirmation;
- melee preflight/start/every current mutation family/final verification;
- ownership hold at melee completion;
- native ranged selection;
- ranged probe/catalog/preflight/start/every mutation family/final verification;
- final both-item verification;
- STOP, clear, replace, view close, context exit, character switch, and hot reload.

For every injected fault assert: no duplicate mutation, no later-job dispatch, no token leak/premature release, no stale callback state write, no loss of confirmed job result, bounded log/UI output, and an explicit recovery action.

### UI and accessibility tests

- Active Queue remains above Planner configuration at supported resolutions/UI scales.
- One- and two-row modes preserve access to CRAFT and STOP through scrolling; buttons never disappear under the mask.
- Weapon/perk/blessing names do not overlap, wrap into neighboring rows, or spill outside the panel.
- Yellow active styling is readable but state is also conveyed by text/icon, not color alone.
- Mouse, keyboard, and controller focus order reaches Paste, queue rows, Clear/Replace, Planner, CRAFT, and STOP predictably.
- Disabled imported target controls are visibly disabled and cannot be activated by mouse, controller, or keyboard.
- Panel detach/reattach reconstructs rows from core queue state and does not create duplicate elements/hotspots.
- Localization expansion and missing localization keys degrade to bounded readable fallback text.

### Two-job integration matrix

Every row must assert job order, mutation counts, selected gear identities, spend ownership, terminal queue state, and absence of mutation calls after a blocked transition.

| Melee starting state | Ranged starting state | Expected result |
|---|---|---|
| new | new | craft melee, reconcile, craft ranged, complete 2/2 |
| resumable valid base | new | resume/finish melee, then craft ranged |
| new | resumable valid base | craft melee, then resume/finish ranged |
| resumable valid base | resumable valid base | deterministically resume each in order |
| exact finished | new | spend zero on melee, then craft ranged |
| new | exact finished | craft melee, verify ranged, spend zero on ranged |
| exact finished | resumable valid base | verify melee, then resume ranged |
| resumable valid base | exact finished | finish melee, then verify ranged |
| exact finished | exact finished | verify both, zero crafting mutations, complete 2/2 |
| insufficient resources at melee preflight | any | zero dispatches; queue blocked at 0/2 |
| resources exhausted mid-melee | any | reconcile melee; ranged never starts |
| melee completed | insufficient resources for ranged | preserve melee; ranged zero dispatches; queue resumable at 1/2 |
| melee completed | resources exhausted mid-ranged | preserve melee; reconcile ranged; stop at 1/2 unless ranged postcondition confirms completion |
| inventory full before melee | any | block melee; ranged never starts |
| melee fills inventory | new/resumable ranged | ranged preflight blocks before purchase |
| manual mutation during melee | any | service guard interrupts/quarantines; ranged never starts |
| melee completed | manual mutation before ranged | refresh/revalidate; block or safely continue according to authoritative state |
| STOP during melee | any | reconcile current request; ranged never starts |
| melee completed, STOP at boundary | any | close dispatch before ranged; retain 1/2 |
| melee completed | STOP during ranged | reconcile ranged only; retain melee completion |
| character changes after melee | any | invalidate queue context; ranged never starts on new character |
| network ambiguity during either job | any | quarantine that job; no retry or next-job dispatch until reconciled |

Repeat representative rows with mastery 0, mastery 20/unallocated, mastery 20/fully allocated, missing blessing ownership, mixed weapon level/rarity, multiple resume candidates, and capped/uncapped resource configurations.

Also repeat with imported trait order reversed, one/both workflow toggles disabled, equipped exact copies, favorited incomplete copies excluded, storefront price rotation, external wallet mutation, and completed job gear removed before final verification.

### Transport tests

Use a fake process/filesystem adapter for deterministic tests:

- success, HTTP error, process failure, timeout, partial file, oversized file;
- Windows paths containing spaces;
- Proton success and missing dependency;
- unique temp ownership and startup orphan cleanup;
- bounded redirect/protocol options;
- no raw clipboard value appears in generated command text.

### Live validation matrix

1. Windows, supplied URL, verify melee selection plus two Active Queue rows.
2. Press CRAFT and verify Greatsword completes before Force Staff activates.
3. Proton/Wine with host curl.
4. Lantern installed and recommendations enabled.
5. Lantern absent.
6. Every supported UI scale plus keyboard and controller action.
7. Paste while CRAFT is idle, active, stopping, failed, and reconciling.
8. Leave Brunt, switch operative with InstantCharacterChange, open mission board, and enter Psykanium during fetch.
9. Disconnect for 5-7 seconds during fetch, reconnect, and retry.
10. Verify no Ordo Dockets, Plasteel, Diamantine, mastery, inventory, favorites, or gear change until CRAFT is explicitly pressed.
11. Validate all nine new/resume/exact-existing combinations from the integration matrix.
12. Exhaust resources before melee, between jobs, and during ranged; verify confirmed first-job progress is retained.
13. STOP during every mutation kind in both jobs and at the job boundary.
14. Test invalid URL, deleted/private build, one invalid weapon, and wrong-class build.
15. Verify single-row default mode returns after clearing/completing the imported queue.

## Proposed module boundaries

### Current code seams and allowed changes

| Current file/domain | Handoff rule |
|---|---|
| `BetterInventory_auto_crafter.lua` | Own importer/queue wiring, typed presentation state, and fault containment. Do not put queue policy in HUD text generation. |
| `auto_crafter/core/controller.lua` | Remains the sole account-workflow executor. Add only narrow frozen-job, terminal-outcome, and queue-ownership-hold seams shared by manual and queued entry points. |
| `auto_crafter/core/planner.lua` | Reuse normal per-job preflight. Add pure aggregate composition outside existing single-job calculations unless a tested generic helper is clearly safer. |
| `auto_crafter/darktide/panel.lua` | Render/input only. It may request import/clear/CRAFT/STOP, but cannot own queue truth, advance jobs, or dispatch backend work. |
| `auto_crafter/darktide/backend.lua` | Continue to own Darktide reads/mutations. Games Lantern parsing never calls mutation adapters. Avoid changing existing mutation methods for queue support. |
| `BetterInventory_operation_arbiter.lua` | Preserve non-reentrant ownership semantics. Prefer an Auto Crafter queue hold over general lock redesign. |
| `BetterInventory_account_mutation_guard.lua` | Preserve current service-level exclusion; add tests, not queue-specific bypasses. |
| `BetterInventory_runtime.lua` | Reuse exact Brunt lifecycle hooks; do not broaden paste handling to unrelated views. |
| `BetterInventory_feature_lantern.lua` | Existing recommendation-overlay compatibility only. Do not make Games Lantern queue import depend on private Lantern modules. |

Recommended minimal controller contract:

```text
start_purchase_search()
  manual path: build FrozenJob + QueueRunPolicy from current validated UI
  then delegate to the same internal start_frozen_job(job, policy)

start_frozen_job(job, policy)
  validate generation/character/native target/catalog/preflight/ownership
  initialize the existing _search/_phase3/_phase4 workflow

terminal_outcome()
  typed: complete | stopped | blocked | failed | quarantined
  includes authoritative gear ID, character ID, unresolved-operation flag

set_queue_ownership_hold(queue_id, enabled)
  prevents release only for the exact active queue token and only across a
  guarded open-Brunt automatic boundary
```

Do not have the queue coordinator infer completion by polling `_phase == "phase4_complete"`, parsing logs, or inspecting HUD strings. Expose/consume a typed terminal result with a monotonic sequence so one completion can advance at most once.

Manual planner controls must mirror the active imported job for user visibility, while execution reads the frozen job/policy object. This prevents a global-setting race from altering job 2 at the boundary.

### New modules

```text
auto_crafter/games_lantern/
  clipboard.lua       -- strict extraction and canonicalization
  transport.lua       -- async platform adapter interface
  transport_win.lua   -- bounded system curl invocation
  transport_wine.lua  -- bounded host curl/wget invocation
  parser.lua          -- versioned HTML-to-external-model parser
  resolver.lua        -- external model to live planner IDs
  import_controller.lua -- import generation/lifecycle state machine
  queue.lua           -- immutable jobs, transition policy, resume journal

auto_crafter/darktide/
  panel.lua            -- Brunt action, Ctrl+V edge, chooser, Active Queue rows
```

Keep parser/resolver/controller pure enough to run outside Darktide tests. Inject clipboard, transport, clock, filesystem, active context, and planner catalog dependencies.

### Forbidden shortcuts for an implementation agent

- Do not call or simulate native purchase/crafting button callbacks.
- Do not call Lantern's `/lantern` command or talent pipeline.
- Do not copy Lantern source without a compatible license/permission.
- Do not parse weapon identity solely from localized display names.
- Do not map “first card = melee” or “second card = ranged.”
- Do not map “first stat/minimum tie = dump stat.”
- Do not store only one global set of perk/blessing targets for both jobs.
- Do not treat Promise resolution, local XP projection, or a missing item as authoritative completion.
- Do not release/reacquire operation ownership in an automatic open-view job boundary.
- Do not start ranged from a closed/destroyed Brunt view in the initial implementation.
- Do not auto-clear failed/stopped/quarantined queue state or hide its diagnostic row.
- Do not weaken existing tests, timeouts, mutation guards, or candidate protections to make queue tests pass.
- Do not regenerate/package/synchronize from a dirty or failing runtime without inspecting unrelated user changes.

## Implementation sequence and commit batches

### Batch 1 — contracts and offline fixtures

- Add strict URL canonicalizer and pure tests.
- Add external model and parser with the supplied page fixture.
- Add parser drift/size/entity tests.
- No UI, network, settings, or account operations.

### Batch 2 — live catalogue resolver

- Adapt current Auto Crafter catalog snapshots into a pure resolver input.
- Resolve weapon, dump stat, perks, and blessings with explicit ambiguity results.
- Add complete resolver matrix, especially localization and reused blessing icon IDs.
- No settings or crafting changes; asynchronous catalogue reads are required before queue installation.

### Batch 3 — read-only Brunt queue UI

- Add visible paste action and scoped Ctrl+V handling.
- Initially accept fixture/injected data or clipboard URL parsing only.
- Render the always-present Active Queue section: one manual row or two imported rows.
- Render slot-specific chooser and queue-validation errors.
- Highlight the current job yellow and prove completed/stopped/failed states.
- Assert zero backend mutation calls; manual CRAFT is guarded while an imported queue is staged.

### Batch 4 — bounded transport

- Implement native Windows and Proton adapters independently of Lantern.
- Add timeout, size, protocol, diagnostics, generation cancellation, and temp cleanup.
- Integrate live fetch into queue validation only; reject non-canonical URLs before any process launch.

### Batch 5 — atomic queue installation

- Preserve persistent manual settings, install both frozen jobs, activate the melee overlay, rebuild plan, verify, and rollback local/native selection changes on failure.
- Preserve dump target and all workflow/resource-cap settings.
- Keep CRAFT as a separate action; Ctrl+V stages only after both live catalogues resolve, and native melee selection plus queue installation fail closed.

### Batch 6 — serial queue orchestration

- Reuse the current invariant single-item workflow for each job.
- Add authoritative melee-complete -> ranged-preflight transition with one account-operation owner across the boundary.
- Add exact-existing, resume, resource-block, STOP, failure, view-loss, and character-change recovery semantics.
- Preserve completed-job position when Brunt closes at the boundary; a resumed queue starts only the next job.
- Never dispatch ranged until melee terminal success is authoritative.

### Batch 7 — compatibility and soak validation

- Keep Games Lantern and InstantCharacterChange optional: BetterInventory does not call either mod's private API, does not install a second global shortcut hook, and reads the shared `Clipboard` surface only after a Ctrl+V rising edge while Brunt is attached.
- Gate import admission on the Auto Crafter controller: a normal search, mastery, phase 4 mutation, quarantined request, auxiliary mutation, or active imported queue rejects paste before transport/process launch. Staged/recoverable imports remain replaceable while no account mutation is active.
- Reset shortcut and queue-signature state whenever the Brunt panel is attached or detached. This prevents a held Ctrl+V or stale queue snapshot from crossing view instances.
- Reuse the existing lifecycle gates for gameplay-state exit, operative-selection entry/exit, Brunt view creation/destruction, shutdown, and InstantCharacterChange character identity changes. A character change cancels fetch/catalog work, fails the active queue, and clears imported planner state.
- Run four complete imports followed by four complete two-job queues (eight ordered job executions) and reject late callbacks/events from prior generations.
- Synchronize `Content/mods/BetterInventory` with `tools/sync_deployed_mod.ps1` after every runtime change before live evidence is accepted; the command verifies the descriptor/runtime file set and hashes without deleting unrelated managed files.

Batch 7 is automated compatibility evidence, not proof that every optional mod version is safe. Live review must still include Lantern installed and absent, InstantCharacterChange switching before paste and during fetch, Brunt close/reopen, and a normal single-item run with no imported queue.

### Post-implementation hardening closure

The final audit added the following release-critical behavior without changing the no-queue workflow:

- Queue terminal events now require queue ID, job ID, character ID, operation sequence, and a strictly monotonic terminal sequence. Duplicate, stale, wrong-character, and wrong-job events are inert.
- Every job boundary performs a fresh character-scoped inventory probe, fresh selected-weapon catalogue read, and planner preflight before dispatch. Resource/capacity failures become visible blocked state with zero next-job dispatches.
- CRAFT uses a backend-generated aggregate cost signature covering both frozen jobs, all applicable run-policy values, and projected docket/plasteel/diamantine ranges. Any change after the first click requires a new confirmation; the backend independently rejects stale signatures.
- One queue-owned account-operation token spans both jobs. STOP during a request remains unresolved until settlement/reconciliation; STOP during preflight invalidates/cancels read continuations before releasing ownership.
- Closing Brunt while job 1 finishes accepts only its typed terminal result, preserves `1/2`, and stops before ranged dispatch. Reopening never spends until explicit CRAFT/Resume and a fresh confirmation.
- Final queue success revalidates both exact gear IDs, weapon marks/families, dump stats, enabled rarity/expertise postconditions, and perk/blessing sets in the authoritative current-character snapshot.
- Parser scope is restricted to the Weapons section. Canonical UUID metadata, unique class identity, duplicate targets, login/challenge pages, ambiguous weapon cards, and unsupported drift fail closed.
- Windows and Proton fetchers use unique owner-tagged files, bounded poll cadence, MIME/status/size/time checks, explicit child termination on cancellation, and cleanup. Raw URL slugs, HTML, and guide prose are not logged.

Automated evidence is additive and recorded in `tests/case_manifest.json` and `tests/branch_matrix.json`. `tests/run_tests.py` currently reports 28 scripts / 105 cases passing. Critical imported-queue gates are:

| Contract | Executable evidence |
|---|---|
| Typed terminal identity, duplicate rejection, final authoritative reconciliation | `test_games_lantern_safety.py::typed_terminal_identity_and_final_reconciliation` |
| Fresh/resume/exact 3x3 ordering, resource blocks, view loss, STOP, quarantine | `test_games_lantern_safety.py::two_job_state_resource_and_quarantine_matrix` |
| Frozen policy, signed cost authority, locked targets, bounded polling/process cancellation | `test_games_lantern_safety.py::games_lantern_release_contract_seams` |
| Ambiguous multi-card selection and atomic continuation | `test_games_lantern_import_controller.py::explicit_ambiguous_weapon_choice` |
| MIME/status/size/timeout/cancellation transport behavior | `test_games_lantern_transport.py::bounded_transport_timeout_status_size_and_cancel` |
| Optional Lantern/InstantCharacterChange admission and four-run isolation | `test_games_lantern_compatibility.py::optional_mod_lifecycle_admission_and_four_run_soak` |

Live-only rows remain pending: native Windows and Proton fetch/process cancellation, controller navigation and supported UI scales, Lantern installed/absent, InstantCharacterChange during fetch and before paste, Brunt close/reopen during a real mutation, and real-account spend/postcondition evidence. Do not describe those rows as validated from the automated suite.

## Release gates

Do not enable this feature by default until all are true:

- URL/process injection tests pass.
- Supplied build resolves the exact Greatsword targets listed above.
- Supplied build also resolves the exact Force Staff targets and installs melee -> ranged order.
- Dump target remains 60/current after importing website value 0.
- Ambiguous weapon/stat/trait fixtures fail closed.
- One invalid weapon prevents partial queue installation and reports the failing slot.
- Import path proves zero account mutations in automated tests.
- Atomic queue installation rollback is proven.
- The default/manual UI renders one Active Queue row; imported UI renders two detailed rows.
- Current row highlighting and completed/stopped/failed states are verified across supported scales.
- The complete new/resume/exact-existing two-job matrix passes.
- Resource exhaustion before melee and between jobs never dispatches an invalid next request.
- STOP is proven at every job phase and at the queue boundary.
- Stale callbacks are inert across view and character changes.
- Windows and Proton failures are bounded and recoverable.
- Lantern compatibility does not alter talents or duplicate network work.
- Existing full Auto Crafter integration suite remains unchanged and green.
- Installed mod is synchronized and the live matrix is recorded.

Additional no-regression gates from the handoff audit:

- Manual/no-queue behavior has a before/after baseline and no observed semantic delta.
- The supplied page resolves both documented jobs, exact targets, and melee-first order from a checked fixture.
- Structured card parsing ignores prose alternatives and linked builds.
- Exact master/mark identity is proven; mastery-family fallback alone cannot authorize either job.
- Imported target controls are locked; pending jobs use frozen targets and one confirmed run-policy snapshot.
- Trait completion is set-based and reversed slot order causes zero unnecessary mutations.
- Exact-base, final-gear, family-progression, and job-complete states are independently tested.
- One operation token spans the automatic open-view boundary; manual one-job token lifecycle is unchanged.
- Closed Brunt after job 1 produces a safe 1/2 stop, release, and explicit-resume requirement.
- A typed monotonic terminal outcome advances each job no more than once.
- Every current mutation family has queue-boundary STOP/failure/timeout/stale-callback coverage.
- Final queue completion re-verifies both authoritative gear IDs; removed/changed completed gear is visible failure, not silent recreation.
- Idle CPU/memory remain effectively unchanged; no clipboard or filesystem polling occurs without input/in-flight work.
- Frame-hot status checks are constant-time. The panel consumes a compact queue/import presentation model at a bounded 10 Hz; it never deep-copies build catalogues, HTML, resolver models, or full controller snapshots per widget/frame.
- Aggregate two-weapon cost authority is computed on the confirmation click, cached for display, and recomputed only on the confirming click to retain the stale-signature safety barrier.
- Scoped Ctrl+V detection reads held key state and debounces the complete chord; it does not require Ctrl and V to become pressed on the same frame.
- Windows transport follows only HTTPS redirects, escapes curl write-out placeholders through the generated batch file, and preserves adapter start failures in import diagnostics.
- The parser requires a Weapons anchor but accepts either current `div` or legacy `section` containers. A Cloudflare loader embedded in a complete page is not treated as an interstitial; challenge-only pages still fail closed.
- Class safety compares canonical identities rather than display/public names: Games Lantern `skitarii`, `arbites`, and `hive-scum` map to Darktide `cryptic`, `adamant`, and `broker`. True mismatches report both raw and canonical IDs.
- UI is usable at supported scale/resolution/input/localization matrices and state is not color-only.

## Owner requirement traceability

| Owner requirement/scenario | Normative contract | Minimum automated/live evidence |
|---|---|---|
| Games Lantern Copy -> Ctrl+V | Strict clipboard/fetch/parser and Requested interaction | Canonical/slug URL fixtures plus supplied live URL |
| Select imported melee and queue ranged | Planner activation; Native selection barrier | Exact native melee identity, two rows, frozen ranged job |
| `Queued (melee => ranged)` labels | Target and planner labels | UI snapshot/assertion before and after job 1 |
| Active Queue above Planner | Active Queue section | Resolution/UI-scale/controller navigation matrix |
| One normal row, two imported rows | Active Queue section | Manual/imported/clear/reattach tests |
| Yellow current job | Active Queue section | Visual state plus textual/icon active indicator |
| CRAFT melee then ranged | Queue transition table | Dispatch trace proves no ranged call before authoritative melee completion |
| Invalid URL/build | Failure matrix | Zero process/mutation/settings writes as applicable |
| One bad weapon | No partial import invariant | Both slot directions reject atomically with field-specific error |
| Wrong class | Resolver/class gate | No native selection/planner mutation |
| New/new | Two-job integration matrix | Complete 2/2 with ordered gear IDs/costs |
| Resume/new and new/resume | Two-job integration matrix | Deterministic existing gear identity and no duplicate purchase |
| Finished/new and new/finished | Completion contract/matrix | Zero account mutations on satisfied job; other job normal |
| Both finished | Completion contract/matrix | Zero crafting mutations and deterministic reporting |
| Missing melee resources | Queue budget/preflight | Zero job dispatches |
| Missing ranged resources after melee | Boundary preflight | Melee retained, ranged zero dispatches, 1/2 resumable |
| STOP anywhere | CRAFT/STOP and transition table | Every request family and boundary closes follow-up dispatch |
| No regression | Non-negotiable invariants | Full preexisting suite, behavior baseline, package/sync parity |

An implementation handoff is incomplete if any owner row lacks an executable test ID or recorded live-validation row.

## Implementation-agent completion report template

The implementing agent must finish with a concise report containing:

```text
Branch and commits:
Runtime files changed:
Existing behavior intentionally changed: none / approved list
Existing tests before/after:
New queue tests and case count:
Fault-injection transitions covered:
Windows live matrix:
Proton live matrix:
Lantern installed/absent matrix:
Operation-token boundary evidence:
No-mutation import evidence:
Resource spend evidence per job and aggregate:
STOP/recovery evidence:
Installed mod sync/hash result:
ZIP/runtime manifest result:
Known limitations/open live-only items:
```

Do not describe the feature as complete while a required live row, fault boundary, or owner traceability row is untested. Mark it explicitly pending instead.

## Open questions requiring implementation-time confirmation

1. Whether Games Lantern offers an undocumented stable JSON endpoint or embedded structured model. Prefer it only after its contract and availability are demonstrated; HTML remains the proven fallback.
2. Whether Games Lantern's external UUIDs can be mapped to Darktide master-item IDs from a stable exported dataset, reducing localization dependence.
3. Whether a future Lantern release will expose a supported equipment-only provider API.
4. Whether Brunt's current view/input service exposes a clean unconsumed Ctrl+V event on every supported keyboard layout; otherwise use scoped raw keyboard edges.
5. Exact row height/collapse policy needed to present two detailed jobs in the existing 445 px panel without hiding the CRAFT/STOP actions.
6. Whether a recommended blessing's tier is ever encoded distinctly. Until proven, import blessing identity and retain Auto Crafter's existing tier policy.
7. Future persistence format, if session-local queues are later expanded to survive a full restart. Initial implementation is session-local and requires repasting after reload.

None of these questions blocks the feasibility decision. They determine which resolver/transport adapter is preferred.

## Final recommendation

Proceed, but split the feature into two trust boundaries:

```text
Ctrl+V URL -> fetch -> parse -> resolve both weapons -> install frozen queue
                                                            |
                                                            v
                     CRAFT -> melee single-item workflow -> reconcile
                                                            |
                                                            v
                              ranged preflight/workflow -> reconcile -> done
```

This makes the feature useful without weakening the stability work already completed in Auto Crafter. The URL-only clipboard format is not an obstacle; it is a normal locator. The important constraints are strict URL canonicalization, fail-closed validation of both weapons, immutable queue jobs, preserving attainable dump targets, reusing the existing single-item workflow, authoritative transition barriers, and never allowing the import gesture itself to spend resources.

## References

- [Supplied Games Lantern build](https://darktide.gameslantern.com/builds/a0a667cd-4d49-4f68-8cf8-2f1ee57eab29/very-in-depth-h40-melee-psyker-guide-2-builds)
- [Covenant Mk VI Blaze Force Greatsword database entry](https://darktide.gameslantern.com/weapons/blaze-force-greatsword/covenant-mk-vi-blaze-force-greatsword)
- [Nomanus Mk VI Electrokinetic Force Staff database entry](https://darktide.gameslantern.com/weapons/electrokinetic-force-staff/nomanus-mk-vi-electrokinetic-force-staff)
- [Lantern of the Omnissiah repository](https://github.com/Wobin/Lantern-of-the-Omnissiah)
- Installed Lantern modules: `clipboard.lua`, `fetch.lua`, `equipment_parser.lua`, `build.lua`, `build_store.lua`, and `equipment_overlay.lua`
- BetterInventory integration: `scripts/mods/BetterInventory/BetterInventory_feature_lantern.lua`
- BetterInventory Auto Crafter planner UI: `scripts/mods/BetterInventory/auto_crafter/darktide/panel.lua`
- Existing foundation: `docs/auto-crafter-helper-feasibility.md`
- Existing safety invariants: `docs/auto-crafter-safety-audit-2.0.2.md`
