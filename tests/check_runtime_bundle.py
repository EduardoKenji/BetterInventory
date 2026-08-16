import json
from pathlib import Path
import sys

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from tools.runtime_bundle_manifest import build_manifest


def main() -> None:
    manifest_path = PROJECT_ROOT / "docs" / "generated-runtime-bundle-manifest.json"
    expected = json.loads(manifest_path.read_text(encoding="utf-8"))
    actual = build_manifest()

    assert actual == expected, (
        "Generated runtime bundle manifest is stale. Run "
        "py -3 tools/generate_runtime_bundle_manifest.py"
    )
    assert actual["archive_root"] == "BetterInventory"
    assert actual["file_count"] == len(actual["files"])
    assert actual["version"] == "2.4.0"
    assert all("\\" not in entry["archive_path"] for entry in actual["files"])
    print(
        "BetterInventory runtime bundle manifest passed: "
        f"{actual['file_count']} files, version {actual['version']}."
    )


if __name__ == "__main__":
    main()
