import json
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

import run_tests


def main():
    with TemporaryDirectory(prefix="betterinventory-coverage-contract-") as directory:
        root = Path(directory)
        runtime = root / "runtime"
        for name in ("a/same.lua", "b/same.lua", "new.lua"):
            path = runtime / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("return true\n", encoding="utf-8")
        policy = root / "policy.json"
        policy.write_text(json.dumps({"modules": {
            "a/same.lua": {"minimum_percent": 100},
            "b/same.lua": {"minimum_percent": 100},
        }}), encoding="utf-8")
        parts = root / "parts"
        parts.mkdir()
        (parts / "test.json").write_text(json.dumps({"sources": {
            "@" + str(runtime / "a/same.lua"): [1],
            str(root / "foreign/same.lua"): [1],
        }}), encoding="utf-8")
        with patch.multiple(run_tests, PROJECT_ROOT=root, RUNTIME_ROOT=runtime):
            report = run_tests.build_coverage_report(parts, policy)
        modules = {entry["module"]: entry for entry in report["modules"]}
        assert set(modules) == {"a/same.lua", "b/same.lua", "new.lua"}
        assert modules["a/same.lua"]["gate_passed"]
        assert modules["b/same.lua"]["covered_lines"] == 0
        assert not modules["b/same.lua"]["gate_passed"]
        assert modules["new.lua"]["failure"] == "unassigned_non_declarative_runtime_module"
        assert len(report["policy_failures"]) == 1
    print("Recursive coverage identity and unassigned-module gates passed.")


if __name__ == "__main__":
    main()
