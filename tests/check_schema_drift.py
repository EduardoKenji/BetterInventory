import json
from pathlib import Path
import sys

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from tools.schema_manifest import build_manifest


def main() -> None:
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
