# DMF options architecture and Alf's DMF Extensions compatibility

Date: 2026-08-04

Status: adopted on `fix/alfs-dmf-tabs-compatibility` in commit `d054567`

## Decision

BetterInventory uses a stable options schema: once DMF has created the final settings template, option rows remain present in the same order. A setting that is not currently applicable is disabled and greyed out; it is not removed by a conditional `validation_function`.

This follows the pattern used successfully by PlayerAssist and is the supported architecture for BetterInventory's DMF settings from this point forward.

## Why this is required

Alf's DMF Extensions 1.2.02 assigns generalized tabs by collecting the complete settings-template array for a mod category and pairing it with DMF's rendered-widget array by numeric index.

DMF omits an entry from the rendered-widget array when its `validation_function` returns `false`, while the complete settings-template array can still contain that entry. Every omitted entry therefore shifts the positional pairing for all later controls. The consequences observed in BetterInventory included:

- section titles appearing at the end of the preceding tab;
- controls being displayed under the wrong section;
- selected tabs missing their section title;
- nearly empty tabs and duplicated or detached headings;
- runtime repair attempts making the layout dependent on localization and hook order.

PlayerAssist does not exhibit this problem because its settings retain stable cardinality and order. It changes `disabled` and `disabled_by` state without conditionally removing rows.

## Implementation

BetterInventory now applies option dependencies through `set_option_enabled` in `BetterInventory.lua`. This updates `disabled` and the explanatory `disabled_by` tooltip without changing the schema.

The following previously conditional controls now remain rendered:

- the Automatic Curio Buyer's Classes subsection and class checkboxes;
- the Automatic Curio Buyer's Characters subsection and fixed operative-slot checkboxes;
- the automated-discard Curio protection level threshold.

Only the controls relevant to the current mode are enabled. Character rows are created in `BetterInventory_data.lua` as part of DMF's initial static schema; runtime discovery only updates their labels, availability metadata and backend-ID bindings. No character row is inserted into or removed from the final options template.

BetterInventory no longer hooks Alf's `filter_settings` function or rewrites tab assignments at runtime. Alf can derive tabs normally because the settings-template and rendered-widget sequences remain aligned.

## Functional impact

No gameplay or automation functionality was removed:

| Capability | Result |
| --- | --- |
| Class-based Curio acquisition | Preserved |
| Character-based Curio acquisition | Preserved |
| Cross-character discovery and selection | Preserved |
| Curio type and minimum-value filters | Preserved |
| Automated-discard Curio protection | Preserved |
| Dependency explanations | Preserved through `disabled_by` tooltips |
| Compatibility without Alf's extension | Preserved |

The intentional UI tradeoff is that inactive controls remain visible but greyed out. For example, Characters mode disables the Classes subsection instead of hiding it, unused operative slots remain visible as disabled `Character N` rows, and disabling high-level Curio protection leaves its threshold visible but disabled. This is slightly less compact, but it is deterministic, discoverable, hot-reload-safe, and compatible with Alf's tab implementation.

## Stable operative-slot registry

Character-target settings use a fixed row pool rather than inserting one DMF row per currently discovered profile. `BetterInventory_data.lua` reads Darktide's `MainMenuViewSettings.max_num_characters` while DMF initializes the mod data and falls back to ten when that setting is unavailable. Consequently the correct number of `Character N` checkboxes exists on a cold start, before BetterInventory's runtime script or profile request runs. Future native capacity changes are picked up on the next full game start; BetterInventory never resizes an already initialized schema or rendered view.

This static-data requirement is critical. A previous 1.3.3 implementation kept only one `Discovering characters...` checkbox in the data file and attempted to replace it with slot rows from a late `create_mod_options_settings` hook. On a normal cold start, hook/wrapper ordering could leave that single placeholder intact even though discovery and the inventory-panel controls worked. Version 1.3.4 removes that timing dependency.

Each row is a presentation slot. Its persisted binding contains the backend `character_id` plus mutable name and class metadata, while the enabled/disabled selection remains keyed directly by `character_id`. The inventory panel and Mod Options therefore operate on the same authoritative selection without treating a character name, class or display position as identity.

Roster reconciliation follows these rules:

1. A matching `character_id` retains its slot and selection while name or class labels are refreshed.
2. A new ID receives the lowest unoccupied slot and defaults enabled.
3. An absent ID remains as a disabled tombstone after the first complete successful response.
4. Only a second consecutive complete successful absence reclaims the slot and prunes that deleted ID's explicit exclusion.
5. Discovery failures never mutate the registry.
6. Duplicate display labels receive a short character-ID suffix.
7. Operatives beyond the defensive row cap remain functional and selectable in the inventory panel instead of crashing Mod Options.

Discovery is armed when BetterInventory is enabled as well as on every Morningstar entry, so a first-time install does not depend on a particular game-state event ordering. The pending request waits until the player reaches the hub, then refreshes every five minutes while the player remains there. Requests are serialized, failures use a bounded retry delay, and stale promise completions from an earlier Morningstar generation are ignored. If Mod Options was already open when discovery completed, its rendered labels update the next time the user closes and reopens that view; the inventory panel follows the profile revision live.

## Rules for future settings work

1. Do not use a state-dependent `validation_function` that can remove a BetterInventory option row from DMF's final rendered list.
2. Express dependencies with `disabled` and `disabled_by` through `set_option_enabled`.
3. Define any setting whose presence affects tab cardinality in `BetterInventory_data.lua`; do not rely on a runtime hook to create it.
4. Keep runtime presentation updates cardinality-neutral: labels, disabled state, tooltips and backend bindings may change, but rows and ordering may not.
5. Do not patch Alf's tab state, filter function, or rendered widgets. Fix schema alignment at the BetterInventory boundary.
6. Treat the settings-template/rendered-widget one-to-one ordering as a compatibility invariant.
7. If conditional hiding becomes a hard requirement, first confirm that the installed Alf version resolves entries by stable setting ID rather than positional index. Otherwise use a dedicated custom view instead of destabilizing DMF's shared options view.

## Regression coverage

`tests/test_settings.py` verifies that the class/character groups and Curio protection threshold are not assigned filtering validation functions and that their enabled state follows the selected mode.

`tests/test_curio_acquisition.py` verifies fixed slot cardinality, capacity discovery, rename preservation, delayed deletion, new-ID defaults and the shared character-ID selection path.

The full `tests/verify.ps1` suite must pass before changes to the settings schema are deployed or packaged.
