"""Build a deterministic manifest for the packaged BetterInventory runtime tree."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
DESCRIPTOR_PATH = PROJECT_ROOT / "BetterInventory.mod"
VERSION_PATTERN = re.compile(r"MOD_VERSION\s*=\s*[\"']([^\"']+)[\"']")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def runtime_version() -> str:
    data_path = RUNTIME_ROOT / "BetterInventory_data.lua"
    match = VERSION_PATTERN.search(data_path.read_text(encoding="utf-8"))

    if not match:
        raise RuntimeError(f"Could not find MOD_VERSION in {data_path}")

    return match.group(1)


def runtime_files() -> list[dict[str, object]]:
    files = [
        DESCRIPTOR_PATH,
        *sorted(RUNTIME_ROOT.rglob("*.lua"), key=lambda path: path.relative_to(RUNTIME_ROOT).as_posix()),
    ]
    records = []

    for path in files:
        if not path.is_file():
            raise RuntimeError(f"Missing runtime bundle source: {path}")

        relative = path.relative_to(PROJECT_ROOT).as_posix()
        archive_path = (
            "BetterInventory/BetterInventory.mod"
            if path == DESCRIPTOR_PATH
            else "BetterInventory/scripts/mods/BetterInventory/" + path.relative_to(RUNTIME_ROOT).as_posix()
        )
        records.append({
            "archive_path": archive_path,
            "bytes": path.stat().st_size,
            "source_path": relative,
            "sha256": sha256(path),
        })

    return records


def build_manifest() -> dict[str, object]:
    files = runtime_files()
    file_digest = hashlib.sha256(
        json.dumps(files, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode("utf-8")
    ).hexdigest()

    return {
        "archive_root": "BetterInventory",
        "file_count": len(files),
        "files": files,
        "runtime_tree_sha256": file_digest,
        "version": runtime_version(),
    }


def write_manifest(output_path: Path) -> dict[str, object]:
    manifest = build_manifest()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


if __name__ == "__main__":
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else PROJECT_ROOT / "docs" / "generated-runtime-bundle-manifest.json"
    print(json.dumps(write_manifest(output), indent=2, sort_keys=True))
