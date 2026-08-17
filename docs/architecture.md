# BetterInventory architecture and ownership

## Runtime boundaries

| Area | Current owner | Contract boundary |
| --- | --- | --- |
| Bootstrap/hooks | `BetterInventory.lua` | DMF hook chain, view lifecycle, settings notifications |
| Card geometry/content | `BetterInventory_layout.lua` | native blueprints, item/card content, icon ownership |
| Settings schema | `BetterInventory_data.lua` + `BetterInventory_settings.lua` | stable IDs, nested DMF widgets, dependency refresh metadata |
| Optional integrations and operations | `BetterInventory_features.lua` | guarded capability calls, discard ownership, sorting ownership |
| Curio acquisition | `BetterInventory_curio_acquisition.lua` | serialized reads/purchases, generations, account context |
| Feature domain policies | `BetterInventory_feature_domains.lua` | marker generations, sorting signatures, panel composition keys |
| Curio domain policies | `BetterInventory_curio_domains.lua` | operation snapshots, bounded report queues, retry timing |
| Character Overview model | `BetterInventory_character_overview.lua` | item identity/revision, complete rebuilt card inputs, derived-content reset |
| Customization persistence | `BetterInventory_item_customization.lua` | dirty state and explicit DMF save outcomes |
| Equipment persistence | `BetterInventory_equipment_persistence.lua` | native equip outcome observation, bounded idempotent retry, authoritative profile reconciliation |
| Localization | `BetterInventory_localization.lua` | DMF localization map, generated character-slot keys |
| Auto Crafter Helper | `BetterInventory_auto_crafter.lua` | Explicit core/workflow/Darktide/Games Lantern composition; see [Auto Crafter architecture](auto-crafter-architecture.md) |

## Generated-contract workflow

`tools/schema_manifest.py` loads the actual data and localization Lua tables, validates referenced localization IDs, and produces `docs/generated-settings-manifest.json`. The verifier runs `tests/check_schema_drift.py`; any setting/schema/localization edit must regenerate and review the manifest in the same change.

`tools/runtime_bundle_manifest.py` records the descriptor and every discovered runtime Lua source in `docs/generated-runtime-bundle-manifest.json`. B38 intentionally keeps DMF's fixed data/localization entry points until a clean-install generator smoke test proves source splitting safe.

`tests/case_manifest.json` names the risk cases represented by each behavior script. `tests/run_tests.py` rejects zero-test or manifest drift, reports case-level status, and applies `tests/coverage_policy.json` to behavior-bearing runtime modules. Declarative data/localization files remain visible without a line threshold. A runtime integration facade that cannot execute independently may use `static_modules` only while at least one passing branch-matrix contract explicitly owns that module.

## Refactoring rules

- Extract pure helpers and adapters before moving behavior-bearing state machines.
- Preserve native icon/resource ownership and DMF hook chaining.
- Keep destructive workflows fail closed and preserve generation/account guards.
- Add a behavior test before changing a lifecycle or async contract.
- Treat the audit ledger as the source of truth for staged architecture work.
