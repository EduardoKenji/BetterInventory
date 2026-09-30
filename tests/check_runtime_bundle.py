import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from tools.runtime_bundle_manifest import build_manifest, sha256


def main() -> None:
    with TemporaryDirectory() as temporary:
        source = Path(temporary) / "runtime.lua"
        source.write_bytes(b"return {}\r\n")
        try:
            sha256(source)
        except ValueError as error:
            assert "LF line endings" in str(error)
        else:
            raise AssertionError("CRLF runtime bytes must be rejected before generating a manifest")
    manifest_path = PROJECT_ROOT / "docs" / "generated-runtime-bundle-manifest.json"
    expected = json.loads(manifest_path.read_text(encoding="utf-8"))
    actual = build_manifest()

    assert actual == expected, (
        "Generated runtime bundle manifest is stale. Run "
        "py -3 tools/generate_runtime_bundle_manifest.py"
    )
    assert actual["archive_root"] == "BetterInventory"
    assert actual["file_count"] == len(actual["files"])
    assert actual["version"] == "3.7.4"
    assert all("\\" not in entry["archive_path"] for entry in actual["files"])
    metadata = json.loads((PROJECT_ROOT / "info.json").read_text(encoding="utf-8"))
    assert metadata["version"] == actual["version"]
    assert metadata["author"] == "dodaldo50 / Moarcakes"
    assert metadata["homepage"] == "https://www.nexusmods.com/warhammer40kdarktide/mods/1144"
    assert any(entry["archive_path"] == "BetterInventory/info.json" for entry in actual["files"])
    print(
        "BetterInventory runtime bundle manifest passed: "
        f"{actual['file_count']} files, version {actual['version']}."
    )


if __name__ == "__main__":
    main()
