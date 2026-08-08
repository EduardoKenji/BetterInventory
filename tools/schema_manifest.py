"""Build a deterministic manifest for the DMF settings/localization contract."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
DATA_PATH = RUNTIME_ROOT / "BetterInventory_data.lua"
LOCALIZATION_PATH = RUNTIME_ROOT / "BetterInventory_localization.lua"
REGISTRY_PATH = RUNTIME_ROOT / "BetterInventory_settings.lua"
LOCALIZATION_SHARD_PATHS = tuple(
    RUNTIME_ROOT / f"BetterInventory_localization_{suffix}.lua"
    for suffix in ("core", "features", "zh_cn")
)


def load_schema() -> tuple[object, object, object]:
    lua = LuaRuntime(unpack_returned_tuples=True)
    localization_shards = {
        path.stem: lua.execute(
            path.read_text(encoding="utf-8"), name=str(path)
        )
        for path in LOCALIZATION_SHARD_PATHS
    }
    lua.globals().better_inventory_localization_shards = lua.table_from(
        localization_shards
    )
    lua.execute(
        "function get_mod(name) "
        "if name == 'BetterInventory' then "
        "return {localize = function(_, id) return id end, "
        "io_dofile = function(_, path) "
        "local shard_name = string.match(path, '([^/]+)$'); "
        "return better_inventory_localization_shards[shard_name] end} "
        "end; "
        "return {localize = function(_, id) return id end} end; "
        "function require(_) return {max_num_characters = 10} end"
    )
    data = lua.execute(DATA_PATH.read_text(encoding="utf-8"), name=str(DATA_PATH))
    localization = lua.execute(
        LOCALIZATION_PATH.read_text(encoding="utf-8"), name=str(LOCALIZATION_PATH)
    )
    registry = lua.execute(REGISTRY_PATH.read_text(encoding="utf-8"), name=str(REGISTRY_PATH))

    return data, localization, registry


def collect_settings(entries: object) -> list[dict[str, object]]:
    collected: list[dict[str, object]] = []

    if entries is None:
        return collected

    for _, entry in entries.items():
        if entry is None:
            continue

        setting_id = entry["setting_id"]

        if setting_id is not None:
            collected.append(
                {
                    "setting_id": str(setting_id),
                    "type": str(entry["type"] or ""),
                    "text": str(entry["text"] or ""),
                    "tooltip": str(entry["tooltip"] or ""),
                }
            )

        collected.extend(collect_settings(entry["sub_widgets"]))

    return collected


def digest(value: object) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def metadata_records(registry: object, settings: object, localization: object) -> list[dict[str, object]]:
    ok, _, duplicates = registry.register(settings["options"]["widgets"])

    if not ok:
        raise RuntimeError("Duplicate settings metadata IDs: " + ", ".join(str(value) for value in duplicates))

    audit = registry.audit(localization)

    if len(audit.orphan_metadata) > 0 or len(audit.unregistered_active_settings) > 0 or len(audit.missing_localization) > 0:
        raise RuntimeError("Settings metadata audit failed: " + json.dumps({
            "metadata_issues": [str(value) for value in audit.metadata_issues.values()],
            "missing_localization": [str(value) for value in audit.missing_localization.values()],
            "orphan_metadata": [str(value) for value in audit.orphan_metadata.values()],
            "unregistered_active_settings": [str(value) for value in audit.unregistered_active_settings.values()],
        }, sort_keys=True))

    records = []

    for _, metadata in registry.metadata_manifest().items():
        default_value = metadata.default_value

        if not isinstance(default_value, (bool, int, float, str)):
            default_value = None

        records.append({
            "default_value": default_value,
            "migration_key": False if metadata.migration_key is False else str(metadata.migration_key),
            "owner": str(metadata.owner),
            "refresh_domains": {
                str(key): bool(value)
                for key, value in (metadata.refresh_domains or {}).items()
            },
            "setting_id": str(metadata.setting_id),
            "test_id": str(metadata.test_id),
            "title_id": False if metadata.title_id is False else str(metadata.title_id),
            "tooltip_id": False if metadata.tooltip_id is False else str(metadata.tooltip_id),
            "type": str(metadata.type),
            "visibility": str(metadata.visibility),
        })

    return records


def build_manifest() -> dict[str, object]:
    data, localization, registry = load_schema()
    settings = collect_settings(data["options"]["widgets"])
    metadata = metadata_records(registry, data, localization)
    localization_keys = sorted(str(key) for key, _ in localization.items())
    missing_localization = []

    for setting in settings:
        for field in ("setting_id", "text", "tooltip"):
            localization_id = setting[field]

            if localization_id and localization[localization_id] is None:
                missing_localization.append(localization_id)

    if missing_localization:
        raise RuntimeError(
            "Missing localization IDs: " + ", ".join(sorted(set(missing_localization)))
        )

    return {
        "schema_version": 1,
        "metadata_count": len(metadata),
        "metadata_sha256": digest(metadata),
        "settings_count": len(settings),
        "setting_ids_sha256": digest(settings),
        "localization_keys_count": len(localization_keys),
        "localization_keys_sha256": digest(localization_keys),
    }


def write_manifest(output_path: Path) -> dict[str, object]:
    manifest = build_manifest()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return manifest


if __name__ == "__main__":
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else PROJECT_ROOT / "docs" / "generated-settings-manifest.json"
    print(json.dumps(write_manifest(output), indent=2, sort_keys=True))
