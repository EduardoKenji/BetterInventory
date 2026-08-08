# Runtime bundle generation

`BetterInventory.mod` deliberately keeps fixed DMF entry points for
`BetterInventory_data`, `BetterInventory_localization`, and the main script.
Those entry points are part of the loader contract, so splitting authoring
sources into feature/locale files is deferred until a real DMF descriptor
compatibility test proves that generated concatenation preserves load order,
localization shape, and cold-start character-slot generation.

The safe B38 deliverable is deterministic runtime-bundle accounting:

```powershell
py -3 tools/generate_runtime_bundle_manifest.py
py -3 tests/check_runtime_bundle.py
```

`docs/generated-runtime-bundle-manifest.json` records every descriptor and
`BetterInventory*.lua` source, its archive path, byte size, SHA-256, version,
and a tree digest. The release packager independently discovers the same
runtime files and verifies each ZIP entry against its source hash. A source
split may proceed later only when the manifest, schema drift, archive parity,
and a clean-install DMF smoke test all remain green.
