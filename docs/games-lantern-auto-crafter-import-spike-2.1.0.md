# Games Lantern weapon-target import spike — BetterInventory 2.1.0

Date: 2026-08-10  
Branch: `research/2.1.0-games-lantern-import`  
Status: research complete; implementation not started  
Target surface: Auto Crafter Helper in Brunt's Armoury

## Executive decision

Yes. Importing a Games Lantern weapon target from a copied build URL is theoretically and practically feasible with high confidence for public builds.

The clipboard contains only a URL, so Ctrl+V cannot configure Auto Crafter from clipboard text alone. BetterInventory must extract the build UUID, fetch the public Games Lantern page, parse its weapon entries, resolve one entry against Darktide's live weapon/stat/perk/blessing catalogues, and stage an atomic planner update.

The installed Lantern of the Omnissiah mod already proves the difficult platform primitives:

- Darktide exposes clipboard reads through the global `Clipboard.get` function.
- A slugged Games Lantern URL can be reduced to a canonical UUID URL.
- The public build page can be downloaded asynchronously on native Windows and Proton/Wine.
- Its rendered HTML contains weapon names, family/mark links, modifier values, perks, blessing names, and blessing image identifiers.
- The result can be stored and displayed inside Darktide.

This should be implemented as a **read-only import and preview feature**. Ctrl+V must never start crafting, spend resources, select an ambiguous weapon, or alter an active Auto Crafter run. The existing CRAFT action remains the only account-mutating entry point.

## Requested interaction

The intended workflow is:

1. Open a public Darktide build on Games Lantern.
2. Press its Copy button; the clipboard receives the build URL.
3. Open Brunt's Armoury and select a melee or ranged weapon family.
4. With the Auto Crafter panel visible and idle, press Ctrl+V.
5. BetterInventory reads and validates the clipboard URL, fetches the build, and resolves the weapon matching the active Brunt context.
6. The panel displays a preview of the imported weapon, dump stat, two perks, and two blessings.
7. The user applies the preview, which updates planner controls together.
8. The user reviews normal caps and workflow options, then separately presses CRAFT if desired.

A visible `Paste Games Lantern build` action should accompany Ctrl+V for controller users, discoverability, and recovery when the keyboard shortcut is captured by another UI element.

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

Use the active Brunt offer as context, not as permission to guess. If the user has selected a melee weapon and the page contains one melee and one ranged weapon, select the unique melee candidate. If the page contains multiple compatible melee recommendations or variants, show a chooser. If the imported weapon is unavailable to the current class/character, report that and apply nothing.

The supplied page currently has exactly two unique weapon links and only one melee candidate, so its Greatsword is unambiguous in a melee Brunt context.

### Step 3: resolve the dump stat

Normalize website stat labels and compare them against the selected weapon's live base-stat candidates. Preferred identity evidence is a live/internal mapping linked to the exact weapon mark; localized label matching is a fallback.

Rules:

- choose the unique lowest displayed modifier as the dump-stat identity;
- never import its website value as the Brunt target;
- retain the user's existing dump target, normally 60;
- if the minimum is tied, absent, or does not map uniquely, require manual selection;
- validate that the resolved stat belongs to the selected weapon before Apply.

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

If a recommended blessing is not currently selectable for that weapon, show it as unresolved and block Apply rather than substituting a similarly named trait.

### Step 6: stage and apply atomically

Ctrl+V should create a preview, not immediately call `mod:set` repeatedly. The preview includes:

- source build title and UUID;
- resolved weapon and active Brunt offer;
- dump stat identity and retained target value;
- both perks and blessings;
- warnings and unresolved fields;
- fetch age/cache status.

Apply only when every required field has a unique valid live ID. Before applying, capture old settings. Write all five target identities together, force the normal planner/catalog refresh, and verify the resulting plan. If any write or validation fails, restore all old settings and report a bounded error.

The importer should not alter workflow toggles, resource caps, favoriting, inventory-resume policy, mastery behavior, or sequential request behavior.

## State machine

Recommended importer states:

```text
idle
  -> clipboard_validating
  -> fetching
  -> parsing
  -> resolving_weapon
  -> resolving_traits
  -> preview_ready
  -> applying
  -> applied

Any state -> cancelled (view/character/generation changed)
Any pre-Apply state -> failed (bounded non-mutating error)
applying -> rolled_back (atomic validation failed)
```

Each asynchronous callback carries an import generation, canonical UUID, active character ID, Brunt view identity, and selected-offer signature. A callback is ignored unless all still match. Selecting another Brunt weapon after parsing invalidates the resolution and requires re-resolution before Apply.

## Safety and security requirements

This import occurs beside an account-mutating feature, so it should satisfy stronger boundaries than a normal URL preview:

- Import is unavailable whenever Auto Crafter's global mutation arbiter is owned.
- Import performs zero store, gear, mastery, wallet, crafting, discard, or favorite calls.
- CRAFT remains a separate explicit click and normal preflight/confirmation remains unchanged.
- No raw URL, HTML, cookies, account token, or authenticated headers are written to BetterInventory logs.
- Log UUID, stage, byte count, parser version, candidate counts, resolution result, and bounded errors.
- Never execute HTML, JavaScript, or JSON-derived code.
- Never pass unvalidated clipboard text to `cmd`, PowerShell, a batch file, or `/bin/sh`.
- Escape all generated file paths; do not share Lantern's filename namespace.
- Do not retry transport failures indefinitely. One manual retry is safer than hidden polling.
- A timeout, network loss, website challenge, parser drift, or missing dependency leaves planner settings untouched.

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
| One melee and one ranged weapon | Filter by active Brunt slot/context. |
| Multiple compatible weapons | Show chooser; do not pick first. |
| Imported mark unavailable to current operative | Explain incompatibility; no offer/settings mutation. |
| Dump stat has a unique zero/minimum | Import identity; retain target 60/current setting. |
| Lowest stat is tied | Require manual dump-stat choice. |
| Perk/blessing cannot map uniquely | Preview unresolved and block Apply. |
| Same blessing icon ID appears in multiple families | Resolve with weapon context and name. |
| User changes selected offer during fetch | Re-resolve against new offer or invalidate preview. |
| User presses Ctrl+V repeatedly | Debounce and deduplicate same canonical UUID. |
| User leaves Brunt or changes character | Cancel generation and ignore callbacks. |
| User starts crafting before fetch completes | Cancel import; active workflow wins. |
| Existing Auto Crafter run is active/resumable | Reject import until controller is safely idle. |
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
[GLImport] event=weapon_resolved context=melee candidate=covenant-mk-vi-blaze-force-greatsword
[GLImport] event=targets_resolved dump=warp_resistance perks=2 blessings=2 unresolved=0
[GLImport] event=preview_ready settings_changed=false
[GLImport] event=apply_complete planner_valid=true settings_changed=5
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

- supplied Greatsword/staff build;
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
- one melee plus one ranged candidate;
- ambiguous same-slot candidates;
- unique, tied, absent, and unmapped dump stats;
- exact, duplicate, unavailable, and renamed perk/blessing cases;
- same icon ID with different weapon context;
- website zero imports stat identity while target stays 60/current value.

### State-machine and lifecycle tests

- paste while idle reaches preview without any mutation adapter call;
- paste during every Auto Crafter phase is rejected;
- view exit, offer change, character change, hot reload, stop, and new paste invalidate stale callbacks;
- timeout followed by late success remains inert;
- Apply updates all settings or rolls all of them back;
- planner validation failure restores old settings;
- CRAFT remains independent and receives the normal preflight;
- Lantern present/absent/disabled/unknown-version matrices;
- four sequential imports and four subsequent crafts do not leak state across targets.

### Transport tests

Use a fake process/filesystem adapter for deterministic tests:

- success, HTTP error, process failure, timeout, partial file, oversized file;
- Windows paths containing spaces;
- Proton success and missing dependency;
- unique temp ownership and startup orphan cleanup;
- bounded redirect/protocol options;
- no raw clipboard value appears in generated command text.

### Live validation matrix

1. Windows, supplied URL, melee Brunt selection.
2. Windows, supplied URL, ranged Brunt selection.
3. Proton/Wine with host curl.
4. Lantern installed and recommendations enabled.
5. Lantern absent.
6. Every supported UI scale plus keyboard and controller action.
7. Paste while CRAFT is idle, active, stopping, failed, and reconciling.
8. Leave Brunt, switch operative with InstantCharacterChange, open mission board, and enter Psykanium during fetch.
9. Disconnect for 5-7 seconds during fetch, reconnect, and retry.
10. Verify no Ordo Dockets, Plasteel, Diamantine, mastery, inventory, favorites, or gear change until CRAFT is explicitly pressed.

## Proposed module boundaries

```text
auto_crafter/games_lantern/
  clipboard.lua       -- strict extraction and canonicalization
  transport.lua       -- async platform adapter interface
  transport_win.lua   -- bounded system curl invocation
  transport_wine.lua  -- bounded host curl/wget invocation
  parser.lua          -- versioned HTML-to-external-model parser
  resolver.lua        -- external model to live planner IDs
  controller.lua      -- generation/lifecycle state machine
  diagnostics.lua     -- bounded structured events

auto_crafter/darktide/
  games_lantern_ui.lua -- Brunt action, Ctrl+V edge, chooser, preview
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

### Batch 3 — read-only Brunt preview

- Add visible paste action and scoped Ctrl+V handling.
- Initially accept fixture/injected data or clipboard URL parsing only.
- Render candidate chooser and preview.
- Assert zero backend mutation calls.

### Batch 4 — bounded transport

- Implement native Windows and Proton adapters independently of Lantern.
- Add timeout, size, protocol, diagnostics, generation cancellation, and temp cleanup.
- Integrate live fetch into preview only.

### Batch 5 — atomic planner apply

- Snapshot settings, apply resolved IDs together, rebuild plan, verify, and rollback on failure.
- Preserve dump target and all workflow/resource-cap settings.
- Keep CRAFT as a separate action.

### Batch 6 — compatibility and soak validation

- Validate Lantern present/absent and avoid duplicate shortcut ownership.
- Exercise InstantCharacterChange and all Auto Crafter lifecycle gates.
- Run four-import/four-craft integration scenarios.
- Sync `Content/mods/BetterInventory` after every runtime change before live evidence is accepted.

## Release gates

Do not enable this feature by default until all are true:

- URL/process injection tests pass.
- Supplied build resolves the exact Greatsword targets listed above.
- Dump target remains 60/current after importing website value 0.
- Ambiguous weapon/stat/trait fixtures fail closed.
- Import path proves zero account mutations in automated tests.
- Atomic Apply rollback is proven.
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
5. How to present multiple same-slot recommendations compactly in the existing 445 px panel.
6. Whether a recommended blessing's tier is ever encoded distinctly. Until proven, import blessing identity and retain Auto Crafter's existing tier policy.

None of these questions blocks the feasibility decision. They determine which resolver/transport adapter is preferred.

## Final recommendation

Proceed, but split the feature into two trust boundaries:

```text
Ctrl+V URL -> fetch -> parse -> resolve -> PREVIEW/APPLY SETTINGS
                                                    |
                                                    v
                                      separate existing CRAFT action
```

This makes the feature useful without weakening the stability work already completed in Auto Crafter. The URL-only clipboard format is not an obstacle; it is a normal locator. The important constraints are strict URL canonicalization, fail-closed HTML parsing, context-aware weapon/trait resolution, preserving the attainable dump target, and never allowing an import gesture to spend resources.

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
