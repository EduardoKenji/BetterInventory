from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
AUTO_CRAFTER_ROOT = (
    PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter"
)
CONTROLLER_PATH = AUTO_CRAFTER_ROOT / "core" / "controller.lua"
PANEL_PATH = AUTO_CRAFTER_ROOT / "darktide" / "panel.lua"
HOST_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_auto_crafter.lua"


def first_result(value):
    return value[0] if isinstance(value, tuple) else value


def main() -> None:
    nested_modules = sorted(AUTO_CRAFTER_ROOT.rglob("*.lua"))
    assert nested_modules
    assert all(path.stat().st_size <= 100_000 for path in nested_modules)

    lua = LuaRuntime(unpack_returned_tuples=True)
    controller_module = lua.execute(
        CONTROLLER_PATH.read_text(encoding="utf-8"), name=str(CONTROLLER_PATH)
    )
    assert first_result(controller_module.new(lua.table_from({}))) is None
    assert first_result(controller_module.configure(lua.table_from({}))) is False
    partial_modules = lua.table_from(
        {
            "candidate_policy": lua.table_from({}),
            "mastery_policy": lua.table_from({}),
            "phase3_workflow": lua.table_from({"install": lua.eval("function() return true end")}),
            "phase4_workflow": lua.table_from({"install": lua.eval("function() return true end")}),
            "inventory_workflow": lua.table_from({"install": lua.eval("function() return true end")}),
            "imported_queue_workflow": lua.table_from({"install": lua.eval("function() return true end")}),
        }
    )
    assert first_result(controller_module.configure(partial_modules)) is False
    assert first_result(controller_module.new(lua.table_from({"modules": partial_modules}))) is None

    panel_module = lua.execute(PANEL_PATH.read_text(encoding="utf-8"), name=str(PANEL_PATH))
    assert first_result(panel_module.configure(lua.table_from({}))) is False
    assert first_result(panel_module.new(lua.table_from({}))) is None

    composed_controller_module = __import__("auto_crafter_test_support").load_controller(lua)
    controller = composed_controller_module.new(lua.table_from({}))
    assert controller is not None
    for method_name in (
        "_phase3_start_fodder",
        "_phase4_step",
        "_find_inventory_base",
        "begin_queue_operation",
    ):
        assert controller[method_name] is not None

    controller["_snapshot"] = lua.table_from({"gear": lua.table_from({})})
    controller["_phase3"] = lua.table_from({"running": True})
    controller["_phase4"] = lua.table_from({"running": True})
    controller["_imported_job"] = lua.table_from({"job_id": "job"})
    controller.shutdown(controller)
    assert controller["_snapshot"] is None
    assert controller["_phase3"] is None
    assert controller["_phase4"] is None
    assert controller["_imported_job"] is None

    for workflow_path in (AUTO_CRAFTER_ROOT / "core").glob("*_workflow.lua"):
        workflow_source = workflow_path.read_text(encoding="utf-8")
        installed_methods = workflow_source.split("\tfunction self:", 1)[1]
        assert "services." not in installed_methods

    host_source = HOST_PATH.read_text(encoding="utf-8")
    assert "modules = controller_modules" in host_source
    assert "blueprints = PanelBlueprints" in host_source
    assert "core/candidate_policy" in host_source
    assert "core/mastery_policy" in host_source
    assert "darktide/panel_blueprints" in host_source


if __name__ == "__main__":
    main()
