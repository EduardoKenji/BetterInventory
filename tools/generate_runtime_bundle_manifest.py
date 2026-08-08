"""Regenerate the checked-in deterministic runtime bundle manifest."""

from runtime_bundle_manifest import PROJECT_ROOT, write_manifest


if __name__ == "__main__":
    print(write_manifest(PROJECT_ROOT / "docs" / "generated-runtime-bundle-manifest.json"))
