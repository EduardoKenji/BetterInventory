# BetterInventory architecture and ownership

## Runtime boundaries

| Area | Current owner | Contract boundary |
| --- | --- | --- |
| Bootstrap/hooks | `BetterInventory.lua` | DMF hook chain, view lifecycle, settings notifications |
| Card geometry/content | `BetterInventory_layout.lua` | native blueprints, item/card content, icon ownership |
| Settings schema | `BetterInventory_data.lua` + `BetterInventory_settings.lua` | stable IDs, nested DMF widgets, dependency refresh metadata |
| Optional integrations and operations | `BetterInventory_features.lua` | guarded capability calls, discard ownership, sorting ownership |
| Curio acquisition | `BetterInventory_curio_acquisition.lua` | serialized reads/purchases, generations, account context |
| Customization persistence | `BetterInventory_item_customization.lua` | dirty state and explicit DMF save outcomes |
| Localization | `BetterInventory_localization.lua` | DMF localization map, generated character-slot keys |

## Generated-contract workflow

`tools/schema_manifest.py` loads the actual data and localization Lua tables, validates referenced localization IDs, and produces `docs/generated-settings-manifest.json`. The verifier runs `tests/check_schema_drift.py`; any setting/schema/localization edit must regenerate and review the manifest in the same change.

## Refactoring rules

- Extract pure helpers and adapters before moving behavior-bearing state machines.
- Preserve native icon/resource ownership and DMF hook chaining.
- Keep destructive workflows fail closed and preserve generation/account guards.
- Add a behavior test before changing a lifecycle or async contract.
- Treat the audit ledger as the source of truth for staged architecture work.
