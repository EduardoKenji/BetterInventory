"""Regenerate the checked-in DMF schema drift manifest."""

from pathlib import Path

from schema_manifest import PROJECT_ROOT, write_manifest


if __name__ == "__main__":
    output_path = PROJECT_ROOT / "docs" / "generated-settings-manifest.json"
    print(write_manifest(output_path))
