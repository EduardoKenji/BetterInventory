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
- the Automatic Curio Buyer's Characters subsection and discovered-character checkboxes;
- the automated-discard Curio protection level threshold.

Only the controls relevant to the current mode are enabled. Dynamic character rows are inserted into the final options template before dependency binding and do not receive filtering validation functions.

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

The intentional UI tradeoff is that inactive controls remain visible but greyed out. For example, Characters mode disables the Classes subsection instead of hiding it, and disabling high-level Curio protection leaves its threshold visible but disabled. This is slightly less compact, but it is deterministic, discoverable, hot-reload-safe, and compatible with Alf's tab implementation.

## Rules for future settings work

1. Do not use a state-dependent `validation_function` that can remove a BetterInventory option row from DMF's final rendered list.
2. Express dependencies with `disabled` and `disabled_by` through `set_option_enabled`.
3. Insert dynamic settings before dependency binding and before the options view constructs its rendered widgets.
4. Keep dynamic entries in a deterministic order and give them stable setting identifiers or stable internal metadata.
5. Do not patch Alf's tab state, filter function, or rendered widgets. Fix schema alignment at the BetterInventory boundary.
6. Treat the settings-template/rendered-widget one-to-one ordering as a compatibility invariant.
7. If conditional hiding becomes a hard requirement, first confirm that the installed Alf version resolves entries by stable setting ID rather than positional index. Otherwise use a dedicated custom view instead of destabilizing DMF's shared options view.

## Regression coverage

`tests/test_settings.py` verifies that the class/character groups and Curio protection threshold are not assigned filtering validation functions and that their enabled state follows the selected mode.

`tests/test_curio_acquisition.py` verifies the same invariant for both the character-discovery placeholder and dynamically discovered character options.

The full `tests/verify.ps1` suite must pass before changes to the settings schema are deployed or packaged.
