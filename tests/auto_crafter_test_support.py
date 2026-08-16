"""Shared composition helpers for Auto Crafter Lua behavior tests."""

from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
AUTO_CRAFTER_ROOT = (
    PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter"
)

CORE_MODULES = (
    "candidate_policy",
    "mastery_policy",
    "phase3_workflow",
    "phase4_workflow",
    "inventory_workflow",
    "imported_queue_workflow",
)


def _succeeded(result) -> bool:
    return result is True or isinstance(result, tuple) and result[0] is True


def load_controller(lua):
    controller_path = AUTO_CRAFTER_ROOT / "core" / "controller.lua"
    controller = lua.execute(
        controller_path.read_text(encoding="utf-8"), name=str(controller_path)
    )
    modules = {
        module_name: lua.execute(
            (AUTO_CRAFTER_ROOT / "core" / f"{module_name}.lua").read_text(
                encoding="utf-8"
            ),
            name=str(AUTO_CRAFTER_ROOT / "core" / f"{module_name}.lua"),
        )
        for module_name in CORE_MODULES
    }
    configured = controller.configure(lua.table_from(modules))
    assert _succeeded(configured), configured

    return controller


def load_panel(lua):
    lua.execute(
        '''
        package.preload["scripts/settings/ui/ui_sound_events"] = function()
            return {default_mouse_hover = "hover", default_click = "click"}
        end
        '''
    )
    blueprint_path = AUTO_CRAFTER_ROOT / "darktide" / "panel_blueprints.lua"
    panel_path = AUTO_CRAFTER_ROOT / "darktide" / "panel.lua"
    blueprints = lua.execute(
        blueprint_path.read_text(encoding="utf-8"), name=str(blueprint_path)
    )
    panel = lua.execute(panel_path.read_text(encoding="utf-8"), name=str(panel_path))
    configured = panel.configure(blueprints)
    assert _succeeded(configured), configured

    return panel
