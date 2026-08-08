"""Validate the staged runtime ownership and dependency contract."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
OWNERSHIP_PATH = PROJECT_ROOT / "docs" / "runtime-module-ownership.json"
LOCAL_DOFWILE_PATTERN = re.compile(
    r'io_dofile\(\s*"BetterInventory/scripts/mods/BetterInventory/([^"/]+)"\s*\)'
)
HOOK_PATTERN = re.compile(
    r'mod:hook(?:_safe)?\(\s*([^,\n]+?)\s*,\s*"([^"]+)"'
)


def fail(message: str) -> None:
    raise AssertionError(message)


def load_contract() -> dict[str, object]:
    return json.loads(OWNERSHIP_PATH.read_text(encoding="utf-8"))


def validate_modules(contract: dict[str, object]) -> None:
    module_records = contract["modules"]
    runtime_files = {path.name for path in RUNTIME_ROOT.glob("BetterInventory*.lua")}
    declared_files = set(module_records)

    if runtime_files != declared_files:
        fail(
            "Runtime ownership drift: "
            f"missing={sorted(runtime_files - declared_files)}, "
            f"extra={sorted(declared_files - runtime_files)}"
        )

    max_bytes = int(contract["max_bytes"])
    exceptions = contract["temporary_size_exceptions"]
    for module_name in sorted(runtime_files):
        byte_count = (RUNTIME_ROOT / module_name).stat().st_size
        if byte_count > max_bytes and module_name not in exceptions:
            fail(
                f"Module exceeds {max_bytes} bytes without an exception: "
                f"{module_name}={byte_count}"
            )


def actual_dependencies(module_name: str) -> set[str]:
    source = (RUNTIME_ROOT / module_name).read_text(encoding="utf-8")
    return {match.group(1) + ".lua" for match in LOCAL_DOFWILE_PATTERN.finditer(source)}


def validate_dependencies(contract: dict[str, object]) -> None:
    records = contract["modules"]
    declared_graph = {}
    for module_name, record in records.items():
        declared = set(record.get("dependencies", []))
        actual = actual_dependencies(module_name)
        if actual != declared:
            fail(
                f"Dependency declaration drift in {module_name}: "
                f"declared={sorted(declared)}, actual={sorted(actual)}"
            )
        declared_graph[module_name] = declared

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(module_name: str, path: list[str]) -> None:
        if module_name in visiting:
            cycle_start = path.index(module_name)
            fail("Local module dependency cycle: " + " -> ".join(path[cycle_start:] + [module_name]))
        if module_name in visited:
            return

        visiting.add(module_name)
        for dependency in declared_graph[module_name]:
            if dependency not in declared_graph:
                fail(f"Unknown local module dependency: {module_name} -> {dependency}")
            visit(dependency, path + [module_name])
        visiting.remove(module_name)
        visited.add(module_name)

    for module_name in sorted(declared_graph):
        visit(module_name, [])


def validate_hooks(contract: dict[str, object]) -> None:
    hook_modules = contract["hook_modules"]
    actual_hook_owners: dict[str, str] = {}
    for module_path in sorted(RUNTIME_ROOT.glob("BetterInventory*.lua")):
        source = module_path.read_text(encoding="utf-8")
        hooks = [f"{target.strip()}:{method}" for target, method in HOOK_PATTERN.findall(source)]
        if hooks and module_path.name not in hook_modules:
            fail(f"Hook-bearing module is missing an owner declaration: {module_path.name}")
        for hook_id in hooks:
            previous = actual_hook_owners.get(hook_id)
            if previous and previous != module_path.name:
                fail(f"Duplicate hook owner: {hook_id} in {previous} and {module_path.name}")
            actual_hook_owners[hook_id] = module_path.name

    for module_name in hook_modules:
        if module_name not in contract["modules"]:
            fail(f"Hook owner references unknown module: {module_name}")


def main() -> None:
    contract = load_contract()
    validate_modules(contract)
    validate_dependencies(contract)
    validate_hooks(contract)
    print(
        "BetterInventory architecture checks passed: "
        f"{len(contract['modules'])} modules, "
        f"{len(contract['hook_modules'])} hook owners, "
        f"max={contract['max_bytes']} bytes."
    )


if __name__ == "__main__":
    sys.exit(main())
