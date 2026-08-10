# Games Lantern weapon-target import spike — BetterInventory 2.1.0

Date: 2026-08-10  
Branch: `research/2.1.0-games-lantern-import`  
Status: research complete; implementation not started  
Target surface: Auto Crafter Helper in Brunt's Armoury

## Executive decision

Yes. Importing a Games Lantern weapon target from a copied build URL is theoretically and practically feasible with high confidence for public builds.

The clipboard contains only a URL, so Ctrl+V cannot configure Auto Crafter from clipboard text alone. BetterInventory must extract the build UUID, fetch the public Games Lantern page, parse its weapon entries, resolve both the melee and ranged entries against Darktide's live weapon/stat/perk/blessing catalogues, and stage an atomic two-item queue.

The installed Lantern of the Omnissiah mod already proves the difficult platform primitives:

- Darktide exposes clipboard reads through the global `Clipboard.get` function.
- A slugged Games Lantern URL can be reduced to a canonical UUID URL.
- The public build page can be downloaded asynchronously on native Windows and Proton/Wine.
- Its rendered HTML contains weapon names, family/mark links, modifier values, perks, blessing names, and blessing image identifiers.
- The result can be stored and displayed inside Darktide.

Ctrl+V is a **read-only queue import**. It may select the imported melee weapon in Brunt and atomically configure planner targets, but it must never start crafting or spend resources. The existing CRAFT action remains the only account-mutating entry point and processes the validated queue serially: melee first, ranged second.

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

A visible `Paste Games Lantern build` action should accompany Ctrl+V for controller users, discoverability, and recovery when the keyboard shortcut is captured by another UI element.

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

1. Save the current manual single-item planner state as a restorable snapshot.
2. Install the two immutable queue jobs atomically.
3. Select the melee weapon in Brunt's native view.
4. Copy the melee job's frozen targets into the current Auto Crafter planner controls.
5. Rebuild and verify the normal plan.
6. Render the ranged job as queued without requiring it to be visible in Brunt.

When melee reaches an authoritative terminal success, activate ranged atomically:

1. mark melee completed with its final gear identity;
2. close dispatch and refresh authoritative inventory/resources;
3. select the ranged weapon family/offer in Brunt when the view is still available;
4. load the ranged job's frozen target settings;
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
- A future queue-wide hard cap may be added, but initial implementation must not ambiguously repurpose an existing per-weapon setting.

### Queue lifetime and clearing

The safe initial lifetime is session-local:

- an imported idle/stopped queue remains visible until completed, explicitly cleared/replaced, the character changes, or the mod/game reloads;
- a completed two-row result may remain visible for review until the user selects a new manual target or presses a future Clear Queue action;
- clearing/restoring returns Active Queue to one row derived from the current manual target, or a `No target selected` row when none exists;
- clearing a queue is unavailable while a request is unresolved;
- clearing never discards, unfavorites, downgrades, or otherwise changes completed gear;
- no queue automatically resumes spending after reload.

## Evidence hierarchy and source limits

This spike used, in descending order:

1. The installed Lantern of the Omnissiah v2.1.0 runtime under `Content/mods/Lantern of the Omnissiah`.
2. BetterInventory's current 2.1.0 branch and live Auto Crafter catalog/planner code.
3. The supplied public Games Lantern build page, fetched on 2026-08-10.
4. Lantern's public GitHub repository and README.

The installed Lantern package and repository root expose no license file. Its behavior is valid implementation evidence, but BetterInventory should not copy substantial source code without author permission or a published compatible license. Implement the protocol independently, or establish an explicit narrow inter-mod API with Lantern's author.

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

Games Lantern's `0/80` means “this is the allocated dump modifier” in a theoretical build distribution. A finished perfect-roll Darktide weapon normally targets 60 in that modifier. Treating the website's zero as an attainable purchase target would cause an endless or wasteful Brunt search. The importer must import the **stat identity**, not overwrite `auto_crafter_dump_stat_target` from the website value.

## Lantern of the Omnissiah analysis

### Clipboard contract

`modules/clipboard.lua` reads `_G.Clipboard.get`, recognizes `gameslantern.com/builds/<UUID>` anywhere in clipboard text, removes the optional slug/query by rebuilding the URL, and emits a canonical `https://darktide.gameslantern.com/builds/<UUID>` URL.

This proves that Games Lantern's Copy button output is sufficient. No browser extension or custom clipboard payload is required.

The production BetterInventory validator should be stricter than Lantern's current pattern:

- require an exact `https` URL;
- allow only `darktide.gameslantern.com` (and optionally a deliberately reviewed alias);
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

The approach is viable, but BetterInventory's version should tighten it:

- one fetch in flight per panel/import generation;
- connect and total timeouts at the transport layer as well as in Lua;
- HTTPS-only protocols and a small redirect limit;
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

BetterInventory should use a versioned parser boundary returning either a complete typed result or an explicit unsupported-format error. Partial parser success must not silently modify planner settings.

### Stored equipment and BetterInventory's existing integration

Lantern stores parsed equipment under the active preset and exposes modules through `lantern_mod._modules`, including `equipment_parser`, `equipment_store`, `build_store`, and `equipment_overlay`. BetterInventory currently integrates only with `equipment_overlay` in `BetterInventory_feature_lantern.lua`; it hosts Lantern's recommendation display and suppresses the duplicate floating panel.

Those `_modules` tables are private implementation details rather than a stable public API. BetterInventory may optionally consume an already-stored Lantern recommendation when a tested compatible Lantern version is installed, but it must not require Lantern and should not call Lantern's normal import flow: that flow also parses and applies talents to the active preset.

Preferred compatibility order:

1. A future explicit Lantern provider API such as `parse_gameslantern_equipment(url, callback)`.
2. BetterInventory's independent equipment-only importer.
3. A version-gated private adapter only as an experimental fallback, disabled on unknown Lantern versions.

If both mods are installed, BetterInventory owns Ctrl+V only while its Brunt panel is the active target. It must not trigger `/lantern`, overwrite talent presets, or launch duplicate fetches for the same gesture.

## BetterInventory integration points

### Brunt lifecycle

BetterInventory already attaches Auto Crafter specifically to `CreditsGoodsVendorView`, which is Brunt's Armoury. The panel is detached on view/context exit, and its update loop is guarded by `pcall` at the feature facade.

This gives the importer a precise lifecycle boundary:

- enabled only when Auto Crafter is enabled;
- active only while the Brunt panel is attached and visible;
- accepted only while the controller is idle and owns no mutation;
- cancelled when the panel detaches, the active character changes, or the run generation changes.

### Keyboard gesture

Darktide exposes raw keyboard state through `_G.Keyboard`; installed DMF code uses `Keyboard.button_index` and `Keyboard.button`. The current Auto Crafter panel update receives `dt`, but not the view's `input_service`, so the clean implementation choices are:

1. add a tiny raw-key edge detector to the attached panel; or
2. pass the view input service into a dedicated importer input adapter from the Brunt update hook.

The second is preferable when a reliable unmapped keyboard event is available. Raw keyboard fallback is acceptable if heavily scoped.

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

The importer should resolve external data into these live IDs and then use the same panel/planner validation path as manual choices. It must not invent hardcoded Darktide trait IDs from English names.

## Resolution algorithm

### Step 1: parse without side effects

Produce an immutable external model:

```text
BuildImport
  source_uuid
  source_title
  source_author
  fetched_at
  weapons[]
    external_family_slug
    external_mark_slug
    display_name
    stats[] { label, value }
    perks[] { label, optional_external_id }
    blessings[] { label, description, optional_icon_id }
```

Reject empty, oversized, malformed, login/challenge, and equipment-free pages before consulting the planner.

### Step 2: resolve the weapon

Resolution priority should be:

1. exact family/mark identity if a maintained Games Lantern-to-Darktide mapping exists;
2. exact normalized mark slug against the live Brunt offer/master-item catalog;
3. unique normalized localized/display-name match;
4. explicit user selection among compatible candidates;
5. fail closed.

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

For the supplied Greatsword, `Warp Resistance 0` uniquely resolves to Warp Resistance; the other four stats are 80.

### Step 4: resolve perks

Games Lantern emits descriptive value ranges such as `10-25% Damage (Carapace Armoured Enemies)`, while Auto Crafter needs the internal perk target ID. Resolution should:

1. strip numeric ranges, markup, punctuation variance, and benign spelling variants;
2. compare semantic armor/category and melee/ranged scope against the selected weapon's live perk catalog;
3. require a unique match;
4. preserve page order only for UI display—Auto Crafter may assign either valid slot;
5. reject duplicate or unavailable targets.

Do not assume English-only text. A public Games Lantern page may remain English while Darktide is localized. Maintain a small semantic external mapping keyed by Games Lantern slug/ID where possible, then resolve to live IDs; name normalization is the fallback, not the primary long-term contract.

### Step 5: resolve blessings

Lantern extracts numeric suffixes from `weapon_trait_<n>.webp`, but these image identifiers are not globally sufficient by themselves. In the supplied page, icon identifier `064` appears in more than one weapon context. Resolve blessing identity using the tuple:

```text
selected weapon family/mark + external icon ID + normalized blessing name
```

Then match only within the selected weapon's live blessing catalogue. Require a unique result. The imported recommendation expresses the blessing type; Auto Crafter should continue using its existing highest valid tier/mastery ownership rules.

If a recommended blessing is not currently selectable for that weapon, show it as unresolved and block queue installation rather than substituting a similarly named trait.

### Step 6: stage and install the queue atomically

Ctrl+V should resolve a complete queue model before changing the visible planner. The validation result includes:

- source build title and UUID;
- resolved melee and ranged weapons and Brunt identities;
- both dump-stat identities and retained target values;
- both perk/blessing pairs for each weapon;
- warnings and unresolved fields;
- fetch age/cache status.

Install only when every required field on both jobs has a unique valid live ID. Before installation, capture the manual planner and any previous idle queue state. Store both frozen jobs and write the active melee target settings together, select the melee offer, force the normal planner/catalog refresh, and verify the resulting plan. If any write, selection, or validation fails, restore the old planner/queue state and report a bounded error.

The importer should not alter workflow toggles, resource caps, favoriting, inventory-resume policy, mastery behavior, or sequential request behavior.

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

Any state -> cancelled (view/character/generation changed)
Any pre-install state -> failed (bounded non-mutating error)
queue_installing -> rolled_back (atomic validation failed)
Any crafting state -> stopping -> reconciled_stopped
Any job -> failed (bounded terminal error; later jobs remain undispatched)
```

Each asynchronous callback carries an import generation, canonical UUID, active character ID, Brunt view identity, and queue identity. A callback is ignored unless all still match. Once a queue is installed, manual native weapon selection must not silently rewrite its frozen jobs; either restore the active queued weapon selection or explicitly stop/invalidate the queue before accepting a new manual target.

## Safety and security requirements

This import occurs beside an account-mutating feature, so it should satisfy stronger boundaries than a normal URL preview:

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
| Private/deleted build or login page | Report unavailable; preserve planner. |
| Games Lantern is offline or stalls | Bounded timeout; clean temporary files; allow manual retry. |
| Network returns after timeout | Late completion is generation-stale and ignored/cleaned. |
| Response is very large | Abort at size cap; never parse unbounded data. |
| HTML classes/layout changed | Parser returns unsupported-format; never partially apply. |
| No weapons | Report no equipment target. |
| Valid melee and ranged weapons | Install ordered melee -> ranged queue and activate melee. |
| One valid weapon and one invalid weapon | Name the invalid slot/fields and reject the entire imported queue; spend nothing. |
| Build contains only one weapon | Report missing melee/ranged slot and do not reinterpret it as a normal two-job import. |
| Multiple compatible weapons in either slot | Show a slot-specific chooser; do not pick first. |
| Build belongs to another class | Explain expected/current class and reject before changing native selection or planner settings. |
| Imported mark unavailable to current operative | Explain incompatibility; no offer, queue, or planner mutation. |
| Dump stat has a unique zero/minimum | Import identity; retain target 60/current setting. |
| Lowest stat is tied | Require manual dump-stat choice. |
| Perk/blessing cannot map uniquely | Identify weapon/field and block queue installation. |
| Same blessing icon ID appears in multiple families | Resolve with weapon context and name. |
| User changes selected offer during fetch | Imported jobs remain source-driven; install only after revalidating both against the live catalog. |
| User presses Ctrl+V repeatedly | Debounce and deduplicate same canonical UUID. |
| User leaves Brunt or changes character | Cancel generation and ignore callbacks. |
| User starts crafting before fetch completes | Cancel import; active workflow wins. |
| Existing Auto Crafter run is active/resumable | Reject import until controller is safely idle. |
| New melee and new ranged | Craft melee through normal workflow, reconcile, then craft ranged. |
| Resumable melee and new ranged | Reuse best valid melee base under existing resume policy, finish it, then craft ranged. |
| New melee and resumable ranged | Craft melee, refresh, then reuse and finish the ranged base. |
| Exact completed melee and new/resumable ranged | Verify exact melee, mark job 1 complete without spend, then activate ranged. |
| New/resumable melee and exact completed ranged | Finish melee, verify exact ranged, then mark job 2 complete without spend. |
| Both exact completed weapons exist | Verify both deterministically, perform no crafting spend, report queue complete and identify both gear IDs. |
| Multiple resumable candidates for one job | Use existing deterministic candidate ranking; log selected gear ID and preserve nonselected items. |
| Same gear appears eligible for both jobs | Impossible across distinct melee/ranged identities; treat duplicate identity as corrupted resolution and fail closed. |
| Missing resources before melee starts | Melee preflight fails; neither job dispatches; queue remains safely reviewable/resumable. |
| Resources run out during melee | Stop at existing per-step resource gate, reconcile melee, and never activate ranged. |
| Melee completes but ranged preflight lacks resources | Preserve confirmed melee completion, do not dispatch ranged, show exact ranged shortfall, retain resumable queue. |
| Resources run out during ranged | Preserve completed melee; stop/reconcile ranged using existing single-job recovery rules. |
| Inventory is full before either purchase loop | Fail that job's preflight before purchase and do not advance the queue. |
| Inventory fills between jobs | Ranged preflight catches it after melee reconciliation; ranged remains undispatched. |
| Mastery 20/all points already allocated | Skip mastery work independently per weapon family and continue normal job verification. |
| Mastery differs between melee and ranged families | Each job reads and preflights its own authoritative mastery/sticker-book state. |
| CRAFT is pressed twice | First edge owns queue run; subsequent presses are inert while busy. |
| STOP during melee | Settle/reconcile current request, retain melee recovery state, and never start ranged. |
| STOP between jobs | Dispatch gate is already closed; ranged remains queued and untouched. |
| STOP during ranged | Preserve completed melee and reconcile only the ranged in-flight request. |
| Brunt closes after CRAFT | Existing background-run policy applies to active job; queue transition still requires valid lifecycle/context gates. |
| Character changes between jobs | Halt before ranged, invalidate character-scoped catalog, and require revalidation; never craft on the new character from stale jobs. |
| Native/manual/third-party inventory mutation occurs | Existing mutation guard interrupts between requests or quarantines unresolved work; next queue job cannot start. |
| Queue settings are manually edited | Active job changes require explicit revalidation; queued job remains frozen and cannot be silently mutated. |
| A second valid URL is pasted while an idle queue exists | Require explicit replacement confirmation or provide Replace Queue; never merge unrelated queues implicitly. |
| A second URL is pasted while queue is running/stopped-unreconciled | Reject until safely idle/reconciled. |
| Game/mod reload with idle imported queue | Default safe policy: do not auto-resume spending; restore only if queue persistence has complete versioned validation data. |
| Game/mod reload during run | Existing run recovery journal governs; no automatic next-job dispatch after reload. |
| Lantern is installed | Avoid talent import and duplicate fetch/input ownership. |
| Lantern is absent | Standalone BetterInventory importer still works. |
| Windows curl unavailable | Non-mutating transport diagnostic. |
| Proton lacks host curl/wget or Z mapping | Non-mutating platform diagnostic. |
| Hot reload occurs | Orphan cleanup; no callback can touch the new generation. |

## Performance budget

The importer should add effectively zero idle-frame cost:

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

Failures should log stage, sanitized reason, response size/status, candidate count, and generation. Never dump the full HTML into the normal BetterInventory log. A debug-only fixture export may be offered separately with an explicit user action and prominent privacy/size warning.

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
- queue installation updates both frozen jobs plus active melee settings or rolls all of them back;
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

```text
auto_crafter/games_lantern/
  clipboard.lua       -- strict extraction and canonicalization
  transport.lua       -- async platform adapter interface
  transport_win.lua   -- bounded system curl invocation
  transport_wine.lua  -- bounded host curl/wget invocation
  parser.lua          -- versioned HTML-to-external-model parser
  resolver.lua        -- external model to live planner IDs
  controller.lua      -- import generation/lifecycle state machine
  queue.lua           -- immutable jobs, transition policy, resume journal
  diagnostics.lua     -- bounded structured events

auto_crafter/darktide/
  games_lantern_ui.lua -- Brunt action, Ctrl+V edge, chooser, Active Queue rows
```

Keep parser/resolver/controller pure enough to run outside Darktide tests. Inject clipboard, transport, clock, filesystem, active context, and planner catalog dependencies.

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
- No settings or crafting changes.

### Batch 3 — read-only Brunt queue UI

- Add visible paste action and scoped Ctrl+V handling.
- Initially accept fixture/injected data or clipboard URL parsing only.
- Render the always-present Active Queue section: one manual row or two imported rows.
- Render slot-specific chooser and queue-validation errors.
- Highlight the current job yellow and prove completed/stopped/failed states.
- Assert zero backend mutation calls.

### Batch 4 — bounded transport

- Implement native Windows and Proton adapters independently of Lantern.
- Add timeout, size, protocol, diagnostics, generation cancellation, and temp cleanup.
- Integrate live fetch into queue validation only.

### Batch 5 — atomic queue installation

- Snapshot settings, install both frozen jobs, activate melee IDs together, rebuild plan, verify, and rollback on failure.
- Preserve dump target and all workflow/resource-cap settings.
- Keep CRAFT as a separate action.

### Batch 6 — serial queue orchestration

- Reuse the current invariant single-item workflow for each job.
- Add authoritative melee-complete -> ranged-preflight transition.
- Add exact-existing, resume, resource-block, STOP, failure, and recovery semantics.
- Never dispatch ranged until melee terminal success is authoritative.

### Batch 7 — compatibility and soak validation

- Validate Lantern present/absent and avoid duplicate shortcut ownership.
- Exercise InstantCharacterChange and all Auto Crafter lifecycle gates.
- Run four imports followed by eight ordered job executions without state leakage.
- Sync `Content/mods/BetterInventory` after every runtime change before live evidence is accepted.

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

## Open questions requiring implementation-time confirmation

1. Whether Games Lantern offers an undocumented stable JSON endpoint or embedded structured model. Prefer it only after its contract and availability are demonstrated; HTML remains the proven fallback.
2. Whether Games Lantern's external UUIDs can be mapped to Darktide master-item IDs from a stable exported dataset, reducing localization dependence.
3. Whether a future Lantern release will expose a supported equipment-only provider API.
4. Whether Brunt's current view/input service exposes a clean unconsumed Ctrl+V event on every supported keyboard layout; otherwise use scoped raw keyboard edges.
5. Exact row height/collapse policy needed to present two detailed jobs in the existing 445 px panel without hiding the CRAFT/STOP actions.
6. Whether a recommended blessing's tier is ever encoded distinctly. Until proven, import blessing identity and retain Auto Crafter's existing tier policy.
7. Whether an idle imported queue should persist across a full game restart. The safe initial implementation may keep it session-local and require repasting after reload.

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
