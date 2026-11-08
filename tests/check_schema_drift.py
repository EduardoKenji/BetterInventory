import collections
import json
import re
from pathlib import Path
import sys

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from tools.schema_manifest import build_manifest


def assert_no_duplicate_locale_keys() -> None:
    """A key assigned twice in (or across) locale shards is silently shadowed."""
    runtime = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
    pattern = re.compile(r"^(?:\t|localization\.)([A-Za-z0-9_]+) = ", re.MULTILINE)
    seen: dict[str, str] = {}

    for shard in ("core", "features", "zh_cn", "zh_cn_search", "zh_cn_auto_crafter"):
        path = runtime / f"BetterInventory_localization_{shard}.lua"
        keys = pattern.findall(path.read_text(encoding="utf-8"))
        repeated = sorted(k for k, n in collections.Counter(keys).items() if n > 1)
        assert not repeated, f"{path.name} assigns keys twice: {repeated}"

        if shard.startswith("zh_cn"):
            shadowed = sorted(k for k in keys if k in seen)
            assert not shadowed, f"{path.name} re-assigns keys from {seen[shadowed[0]]}: {shadowed}"
            seen.update({k: path.name for k in keys})


def main() -> None:
    assert_no_duplicate_locale_keys()
    manifest_path = PROJECT_ROOT / "docs" / "generated-settings-manifest.json"
    expected = json.loads(manifest_path.read_text(encoding="utf-8"))
    actual = build_manifest()

    assert actual == expected, (
        "Generated settings/localization manifest is stale. Run "
        "py -3 tools/generate_schema_manifest.py"
    )
    print(
        "BetterInventory schema drift checks passed: "
        f"{actual['settings_count']} settings, "
        f"{actual['metadata_count']} metadata records, "
        f"{actual['localization_keys_count']} localization keys."
    )


if __name__ == "__main__":
    main()
