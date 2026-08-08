# B40 live-engine validation record

Status: **not run — awaiting owner practical testing**  
Branch: `audit/v2.0.0`  
Package: `BetterInventory.zip`  
Package SHA-256: `B6987E8CDC9BF876A1B470067E1E5B6BF9D2F1A99C02C464D82F21E24E8DFEAD`

This is the final live gate for B22–B39. Run it with the packaged/deployed
2.0.0 runtime, record the result for every row, and attach screenshots or log
timestamps for failures. Do not treat a missing reproduction as a pass until
the stated repetitions are complete.

## Environment record

| Field | Value |
| --- | --- |
| Darktide build | pending owner entry |
| BetterInventory commit/package | `26314df` / SHA above |
| DMF and load order | pending owner entry |
| Resolution and UI scale | pending owner entry |
| Input mode | pending owner entry |
| Optional integrations enabled | pending owner entry |
| Diagnostics | off normally; controlled sample only when stated |
| Start/end time | pending owner entry |

## Required scenarios

| ID | Scenario and repetitions | Pass condition | Result |
| --- | --- | --- | --- |
| B40-01 | Cold start, enter Morningstar, open inventory, vendor, and Character Overview | No BetterInventory error, missing module, stale card, or native UI damage | Not run |
| B40-02 | Swap weapon X→Y; leave inventory; ESC overview; reopen overview/inventory; repeat 20 rapid cycles | Y remains authoritative everywhere; equipped icon never reverts to X | Not run |
| B40-03 | Swap Curio with one secondary line to Curio with 2+ lines; repeat with different rarity/background | Current background, rarity, name, stats, and every secondary line belong to current Curio | Not run |
| B40-04 | Empty Curio slot → populated Curio → empty slot → different Curio | No old background, stat line, fit cache, or equipped marker survives | Not run |
| B40-05 | Open/close inventory and Character Overview 100 times; include ESC, back button, and view transition | No stale focus, duplicate panels, leaked markers, warnings, or progressive UI degradation | Not run |
| B40-06 | Scroll melee/ranged/Curio inventories continuously for 10 minutes; change columns/layouts repeatedly | No crash, visible hitch growth, resource warning, or unexplained post-GC memory trend | Not run |
| B40-07 | Use controller navigation through inventory options, vendor sorting, collapse/expand, and return to grid | Focus, legend, selection, and row navigation remain correct | Not run |
| B40-08 | Manual discard Confirm/Cancel/ESC/view exit; automatic discard; cancel during in-flight deletion | No overlap, duplicate deletion, stale popup, or lock that survives settlement | Not run |
| B40-09 | Automatic Curio Buyer with all characters/classes selected and known valid offers | Valid offers are purchased once with correct target wallet; no premature pass consumes a rotation | Not run |
| B40-10 | Trigger/observe store refresh before reset, during reset, and after actual reset; remain idle for second pass | Stale storefront waits; exactly one post-refresh pass occurs; no duplicate purchase | Not run |
| B40-11 | Switch account/character during Curio profile fetch, store fetch, wallet fetch, and deferred report delivery | Late results cannot mutate the new account/context; reports remain ordered and isolated | Not run |
| B40-12 | Operative Selection purchase → leave menu → enter Morningstar; repeat for two reports | Each report appears once, oldest-first, on the matching account | Not run |
| B40-13 | Disable/re-enable BetterInventory and use `Ctrl+Shift+R` while inventory/vendor views are open | Native ownership is restored; re-enable does not duplicate hooks, panels, wrappers, or markers | Not run |
| B40-14 | Test integrations alone and in combinations: MyFavorites + Equipped Icon+, Lantern + panel, ItemSorting + vendor, Name It + customization, Visible Equipment | No overlap, missing callbacks, stale ownership, or optional-mod crash | Not run |

## Controlled diagnostic sample

Keep `debug_enable_hot_path_diagnostics` disabled for ordinary play. For one
repeatable B40-05/B40-06 sample only, enable it before the run and capture the
diagnostic counters at cold start, after 50 cycles, and after 100 cycles. Note
active views/panels, marker scans, panel rebuilds, async read age, operation
generation, and Lua memory. Disable it afterward and repeat a short smoke test.

## Failure record

For every failure, record: scenario ID, exact action sequence, character and
account, item gear IDs if visible, settings, optional-mod list, timestamp,
screenshot/video, and relevant Darktide/DMF log lines. Classify as `P0`
(equip/purchase persistence or destructive overlap), `P1` (crash/stale UI), or
`P2` (visual/performance/integration). A failure reopens the smallest hotfix
batch; it must not be silently marked as a B41 release pass.

## Completion rule

B40 passes only when all required rows are `Pass` or have an explicitly
accepted, documented external limitation. Any `Not run` row keeps the 2.0.0
release status at **release candidate pending live validation**.
