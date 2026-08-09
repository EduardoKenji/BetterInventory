"""AST-backed checks for source-structure policies that must survive formatting refactors."""

from __future__ import annotations

import re
import sys
from pathlib import Path

from luaparser import ast


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
GAME_SOURCE_FONT_DEFINITIONS = (
    PROJECT_ROOT.parent.parent
    / "Darktide-Source-Code"
    / "scripts"
    / "managers"
    / "ui"
    / "ui_fonts_definitions.lua"
)


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


def local_io_dofile_targets(tree: object) -> set[str]:
    targets: set[str] = set()

    for node in ast.walk(tree):
        if node_type(node) not in {"Call", "Invoke"}:
            continue

        if call_path(node) not in {"mod.io_dofile", "self.io_dofile"}:
            continue

        arguments = list(getattr(node, "args", []) or [])
        target = string_value(arguments[0]) if arguments else None

        if target and target.startswith("BetterInventory/scripts/mods/BetterInventory/"):
            targets.add(target)

    return targets


def validate_panel_font_types() -> int:
    panel_path = RUNTIME_ROOT / "auto_crafter" / "darktide" / "panel.lua"

    if not panel_path.is_file() or not GAME_SOURCE_FONT_DEFINITIONS.is_file():
        return 0

    font_definitions = GAME_SOURCE_FONT_DEFINITIONS.read_text(encoding="utf-8")
    valid_fonts = set(
        re.findall(r"^\s+([a-z0-9_]+)\s*=\s*FONT_TYPES\.", font_definitions, re.MULTILINE)
    )
    panel_source = panel_path.read_text(encoding="utf-8")
    panel_fonts = set(
        re.findall(r'font_type\s*=\s*"([^"]+)"', panel_source)
    )
    unknown_fonts = sorted(panel_fonts - valid_fonts)

    if unknown_fonts:
        raise SystemExit(
            "Unknown Auto Crafter panel font type(s): " + ", ".join(unknown_fonts)
        )

    return len(panel_fonts)


def validate_auto_crafter_mutation_boundaries() -> int:
    """Keep mutation calls behind the guarded controller/backend boundary."""

    auto_crafter_root = RUNTIME_ROOT / "auto_crafter"
    lua_paths = sorted(auto_crafter_root.rglob("*.lua"))
    mutation_tokens = (
        "purchase_item",
        "upgrade_weapon_rarity",
        "add_weapon_expertise",
        "extract_weapon_mastery",
        "replace_trait_in_weapon",
        "replace_perk_in_weapon",
    )

    for path in lua_paths:
        source = path.read_text(encoding="utf-8")
        ast.parse(source)

        if path.name == "planner.lua":
            forbidden = [token for token in mutation_tokens if token in source]

            if forbidden:
                raise SystemExit(
                    f"Auto Crafter planner contains mutation token(s): {', '.join(forbidden)}"
                )

    planner_source = (auto_crafter_root / "core" / "planner.lua").read_text(encoding="utf-8")
    required_contract = (
        "function Planner.build",
        'status = preflight.ok and "ready" or "blocked"',
        'request_mode = "sequential"',
        "materials deferred",
        "STAT_INDEX_BY_DISPLAY_NAME",
        "dump_stat_candidates",
        "configured stat selected by user",
        "resolved_dump_stat",
        "function Planner.default_dump_stat",
        '"defaulted to dump-stat index 0"',
    )
    missing = [token for token in required_contract if token not in planner_source]

    if missing:
        raise SystemExit("Auto Crafter planner contract missing: " + ", ".join(missing))

    panel_source = (auto_crafter_root / "darktide" / "panel.lua").read_text(encoding="utf-8")
    visual_contract = (
        "frame_tile_2px",
        "Color.terminal_frame(255, true)",
        "selected_mark",
        "chevron",
        "local ROW_SPACING = 8",
        "local CONTENT_HORIZONTAL_PADDING = 12",
        "local CONTENT_VERTICAL_PADDING = 10",
        "local COMPACT_ROW_HEIGHT = 26",
        "local function summary_line_passes",
        "local function status_block_passes",
        "local function section_header_passes",
        "local function compact_selector_passes",
        "local function compact_checkbox_passes",
        "local function compact_stepper_passes",
        "local function enum_stepper_passes",
        "function self:_planner_dump_stat_options",
        "function self:_planner_dump_stat_buttons",
        "function self:_planner_selected_dump_stat",
        "function self:_planner_dump_stat_label",
        "function self:_step_planner_dump_stat",
        "local function stat_grid_passes",
        'variant == "stat_grid"',
        '"stat_hotspot_" .. tostring(index)',
        "selected_stat_index",
        "localized_game_text",
        "local function action_button_passes",
        "local function offer_row_passes",
        "edge_padding = CONTENT_HORIZONTAL_PADDING * 2",
        "PANEL_WIDTH - CONTENT_HORIZONTAL_PADDING * 2",
    )
    missing_visual = [token for token in visual_contract if token not in panel_source]

    if missing_visual:
        raise SystemExit("Auto Crafter visual contract missing: " + ", ".join(missing_visual))

    future_ui_settings = (
        "auto_crafter_buy_until_target",
        "auto_crafter_allocate_mastery_points",
        "auto_crafter_consecrate_transcendent",
        "auto_crafter_upgrade_expertise_500",
        "auto_crafter_change_perks",
        "auto_crafter_change_blessings",
        "auto_crafter_perk_1_target",
        "auto_crafter_perk_2_target",
        "auto_crafter_blessing_1_target",
        "auto_crafter_blessing_2_target",
        "auto_crafter_favorite_result",
        "auto_crafter_rename_result",
    )
    data_source = (RUNTIME_ROOT / "BetterInventory_data.lua").read_text(encoding="utf-8")
    controller_source = (auto_crafter_root / "core" / "controller.lua").read_text(encoding="utf-8")
    missing_future_ui = [
        token for token in future_ui_settings if token not in data_source or token not in panel_source
    ]
    wired_future_backend = [token for token in future_ui_settings if token in controller_source]

    if missing_future_ui:
        raise SystemExit("Auto Crafter future UI contract missing: " + ", ".join(missing_future_ui))

    if wired_future_backend:
        raise SystemExit(
            "Auto Crafter future UI options must remain backend-inert: "
            + ", ".join(wired_future_backend)
        )

    backend_source = (auto_crafter_root / "darktide" / "backend.lua").read_text(encoding="utf-8")
    backend_contract = (
        "function backend:purchase_offer",
        "function backend:upgrade_weapon_rarity",
        "function backend:extract_weapon_mastery",
        "function backend:get_mastery_by_pattern",
        "MasterItems.get_store_item_instance",
        "summarize_base_stats",
        "summarize_weapon_template_stats",
        "WeaponTemplate.weapon_template_from_item",
        "display_name_key",
        "base_stat_labels",
        "base_stats = base_stats",
        "discover_weapon_catalog",
        "get_item_crafting_metadata",
        "trait_sticker_book",
        "GEAR_SUMMARY_LIMIT",
        "master_id = safe_member(item, \"name\")",
    )
    missing_backend = [token for token in backend_contract if token not in backend_source]

    if missing_backend:
        raise SystemExit("Auto Crafter backend mutation contract missing: " + ", ".join(missing_backend))

    controller_source = (auto_crafter_root / "core" / "controller.lua").read_text(encoding="utf-8")
    controller_contract = (
        'setting("auto_crafter_allow_mutations", false)',
        "_operation_inflight",
        "MAX_MASTERY_POLL_ATTEMPTS",
        "extraction_contains_gear_id",
        "plan.resolved_dump_stat",
        'setting("auto_crafter_target_dump_stat", "damage")',
        "_schedule_catalog",
        "catalog_discovery_complete",
        "auto_crafter_level_mastery_20",
        "self._planner.default_dump_stat(plan)",
        "target_changed or config.dump_stat == \"auto\"",
        "_phase3_check_mastery",
        "_phase3_start_fodder",
        "phase3_complete",
    )
    missing_controller = [token for token in controller_contract if token not in controller_source]

    if missing_controller:
        raise SystemExit("Auto Crafter controller guard contract missing: " + ", ".join(missing_controller))

    trait_catalog_contract = (
        "_trait_catalog_text",
        "auto_crafter_target_auto_discovered",
        "trait_catalog",
    )
    missing_trait_catalog = [token for token in trait_catalog_contract if token not in panel_source]

    if missing_trait_catalog:
        raise SystemExit("Auto Crafter trait catalogue UI contract missing: " + ", ".join(missing_trait_catalog))

    return len(lua_paths)


def validate_auto_crafter_brunt_route() -> None:
    runtime_source = (RUNTIME_ROOT / "BetterInventory_runtime.lua").read_text(encoding="utf-8")
    lifecycle_call = 'AutoCrafter.on_brunt_view_ready(view)'

    if runtime_source.count(lifecycle_call) != 1:
        raise SystemExit(
            "Auto Crafter Brunt lifecycle must have exactly one runtime call site"
        )

    credits_vendor_hook_start = runtime_source.find(
        'if ensure_class_method(CreditsVendorView, "_setup_sort_options") then'
    )
    brunt_hook_start = runtime_source.find("-- Brunt's Armoury uses CreditsGoodsVendorView")

    if credits_vendor_hook_start < 0 or brunt_hook_start <= credits_vendor_hook_start:
        raise SystemExit("Could not locate vendor lifecycle route boundaries")

    credits_vendor_hook = runtime_source[credits_vendor_hook_start:brunt_hook_start]

    if lifecycle_call in credits_vendor_hook:
        raise SystemExit(
            "Auto Crafter must not attach to the Armoury Exchange Requisition route"
        )


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

    missing_modules = []

    for lua_path in sorted(RUNTIME_ROOT.glob("BetterInventory*.lua")):
        tree = ast.parse(lua_path.read_text(encoding="utf-8"))

        for target in local_io_dofile_targets(tree):
            relative = target.removeprefix("BetterInventory/")
            module_path = PROJECT_ROOT / relative

            if module_path.suffix != ".lua":
                module_path = module_path.with_suffix(".lua")

            if not module_path.is_file():
                missing_modules.append(f"{lua_path.name} -> {target}")

    if missing_modules:
        raise SystemExit(
            "Missing AST-discovered local module(s): " + ", ".join(sorted(missing_modules))
        )

    panel_font_count = validate_panel_font_types()
    auto_crafter_file_count = validate_auto_crafter_mutation_boundaries()
    validate_auto_crafter_brunt_route()

    print(
        "BetterInventory AST structure checks passed "
        f"(main assignments={len(actual_assignments)}, layout calls={len(found_calls)}, "
        f"local module references checked={len(missing_modules) + len(local_io_dofile_targets(main_tree))}, "
        f"Auto Crafter panel fonts checked={panel_font_count}, "
        f"Phase 1C/2 files checked={auto_crafter_file_count})."
    )


if __name__ == "__main__":
    run()
