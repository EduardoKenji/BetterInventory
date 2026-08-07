"""AST-backed checks for source-structure policies that must survive formatting refactors."""

from __future__ import annotations

import sys
from pathlib import Path

from luaparser import ast


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"


def node_type(node: object) -> str:
    return type(node).__name__


def path_for(node: object) -> str | None:
    if node_type(node) == "Name":
        return getattr(node, "id", None)

    if node_type(node) == "Index":
        parent = path_for(getattr(node, "value", None))
        child = path_for(getattr(node, "idx", None))

        if parent and child:
            return f"{parent}.{child}"

    return None


def string_value(node: object) -> str | None:
    if node_type(node) != "String":
        return None

    raw = getattr(node, "s", None)

    if isinstance(raw, bytes):
        return raw.decode("utf-8")

    return str(raw) if raw is not None else None


def call_path(node: object) -> str | None:
    kind = node_type(node)

    if kind == "Call":
        return path_for(getattr(node, "func", None))

    if kind == "Invoke":
        source = path_for(getattr(node, "source", None))
        function = path_for(getattr(node, "func", None))

        if source and function:
            return f"{source}.{function}"

    return None


def require_target_names(tree: object) -> set[str]:
    names: set[str] = set()

    for node in ast.walk(tree):
        if node_type(node) not in {"Assign", "LocalAssign"}:
            continue

        values = list(getattr(node, "values", []) or [])
        has_forbidden_require = any(
            call_path(value) == "require"
            and string_value((getattr(value, "args", []) or [None])[0])
            in {
                "scripts/ui/views/credits_goods_vendor_view/credits_goods_vendor_view",
                "scripts/ui/views/crafting_mechanicus_barter_items_view/crafting_mechanicus_barter_items_view",
            }
            for value in values
        )

        if has_forbidden_require:
            for target in getattr(node, "targets", []) or []:
                target_name = path_for(target)

                if target_name:
                    names.add(target_name)

    return names


def run() -> None:
    main_path = RUNTIME_ROOT / "BetterInventory.lua"
    layout_path = RUNTIME_ROOT / "BetterInventory_layout.lua"
    main_tree = ast.parse(main_path.read_text(encoding="utf-8"))
    layout_tree = ast.parse(layout_path.read_text(encoding="utf-8"))

    direct_assignments = {
        "InventoryWeaponsView.present_grid_layout",
    }
    actual_assignments = set()

    for node in ast.walk(main_tree):
        if node_type(node) == "Assign":
            actual_assignments.update(
                path_for(target) for target in getattr(node, "targets", []) or []
            )

    violations = sorted(direct_assignments.intersection(actual_assignments))

    if violations:
        raise SystemExit(
            "Forbidden direct class assignments: " + ", ".join(violations)
        )

    forbidden_requires = require_target_names(main_tree)

    if forbidden_requires:
        raise SystemExit(
            "Forbidden vendor/view requires: " + ", ".join(sorted(forbidden_requires))
        )

    forbidden_calls = {
        "Managers.ui.load_item_icon",
        "Managers.ui.unload_item_icon",
        "Renderer.create_resource",
        "Renderer.destroy_resource",
    }
    found_calls = {
        call_path(node)
        for node in ast.walk(layout_tree)
        if node_type(node) in {"Call", "Invoke"}
    }
    forbidden_layout_calls = sorted(forbidden_calls.intersection(found_calls))

    if forbidden_layout_calls:
        raise SystemExit(
            "Forbidden direct render-resource calls: "
            + ", ".join(forbidden_layout_calls)
        )

    print(
        "BetterInventory AST structure checks passed "
        f"(main assignments={len(actual_assignments)}, layout calls={len(found_calls)})."
    )


if __name__ == "__main__":
    run()
