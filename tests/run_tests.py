"""Timeout-bounded, machine-readable runner for the Lua/Lupa behavior suite."""

from __future__ import annotations

import argparse
import ast
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


TEST_ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = TEST_ROOT.parent
OUTPUT_LIMIT = 4000
CASE_MANIFEST_PATH = TEST_ROOT / "case_manifest.json"
COVERAGE_POLICY_PATH = TEST_ROOT / "coverage_policy.json"
BRANCH_MATRIX_PATH = TEST_ROOT / "branch_matrix.json"


def discover_tests() -> list[Path]:
    return sorted(TEST_ROOT.glob("test_*.py"))


def tail(value: str) -> str:
    if len(value) <= OUTPUT_LIMIT:
        return value

    return value[-OUTPUT_LIMIT:]


def load_case_manifest() -> dict[str, list[dict[str, object]]]:
    manifest = json.loads(CASE_MANIFEST_PATH.read_text(encoding="utf-8"))

    if not isinstance(manifest, dict):
        raise ValueError("case manifest must be an object")

    normalized: dict[str, list[dict[str, object]]] = {}

    for test_name, cases in manifest.items():
        if not isinstance(test_name, str) or not isinstance(cases, list) or not cases:
            raise ValueError(f"case manifest entry is invalid: {test_name!r}")

        normalized_cases = []

        for case in cases:
            if not isinstance(case, dict) or not case.get("name"):
                raise ValueError(f"case manifest case is invalid: {test_name!r}")

            normalized_cases.append(
                {
                    "name": str(case["name"]),
                    "risk": str(case.get("risk", "medium")),
                    "start_line": int(case["start_line"]),
                    "end_line": int(case["end_line"]),
                }
            )

        normalized[test_name] = normalized_cases

    return normalized


def load_branch_matrix(
    case_manifest: dict[str, list[dict[str, object]]],
) -> list[dict[str, object]]:
    matrix = json.loads(BRANCH_MATRIX_PATH.read_text(encoding="utf-8"))

    if not isinstance(matrix, dict) or not isinstance(matrix.get("required"), list):
        raise ValueError("branch matrix must contain a required list")

    normalized = []
    runtime_names = {
        path.name
        for path in (PROJECT_ROOT / "scripts" / "mods" / "BetterInventory").glob(
            "BetterInventory*.lua"
        )
    }

    for entry in matrix["required"]:
        if not isinstance(entry, dict):
            raise ValueError("branch matrix entry is invalid")

        test_name = str(entry.get("test", ""))
        case_name = str(entry.get("case", ""))
        outcome = str(entry.get("outcome", ""))
        modules = entry.get("modules", [])

        if not test_name or not case_name or not outcome or not isinstance(modules, list) or not modules:
            raise ValueError(f"branch matrix entry is incomplete: {entry!r}")

        unknown_modules = sorted(set(str(module) for module in modules) - runtime_names)
        if unknown_modules:
            raise ValueError(
                f"branch matrix references unknown runtime module(s): {unknown_modules}"
            )

        manifest_cases = case_manifest.get(test_name, [])
        if not any(case["name"] == case_name for case in manifest_cases):
            raise ValueError(
                f"branch matrix references unknown case {test_name}:{case_name}"
            )

        normalized.append(
            {
                "name": str(entry.get("name", f"{test_name}:{case_name}")),
                "test": test_name,
                "case": case_name,
                "outcome": outcome,
                "modules": [str(module) for module in modules],
            }
        )

    if not normalized:
        raise ValueError("branch matrix must contain at least one required outcome")

    return normalized


def validate_case_ranges(
    case_manifest: dict[str, list[dict[str, object]]], tests: list[Path]
) -> None:
    test_by_name = {test.name: test for test in tests}

    for test_name, cases in case_manifest.items():
        test_path = test_by_name[test_name]
        source = test_path.read_text(encoding="utf-8")
        line_count = len(source.splitlines())

        for case in cases:
            start_line = case["start_line"]
            end_line = case["end_line"]

            if not isinstance(start_line, int) or not isinstance(end_line, int):
                raise ValueError(f"case range is not numeric: {test_name}:{case['name']}")

            if start_line < 1 or end_line < start_line or end_line > line_count:
                raise ValueError(
                    f"case range is outside {test_name}: {case['name']} "
                    f"({start_line}-{end_line}, lines={line_count})"
                )

        assertion_lines = sorted(
            node.lineno for node in ast.walk(ast.parse(source, filename=str(test_path)))
            if isinstance(node, ast.Assert)
        )

        for assertion_line in assertion_lines:
            matches = [
                case for case in cases
                if case["start_line"] <= assertion_line <= case["end_line"]
            ]

            if len(matches) != 1:
                names = ", ".join(str(case["name"]) for case in matches) or "none"
                raise ValueError(
                    f"assertion must map to exactly one case: {test_name}:{assertion_line} "
                    f"(matches={names})"
                )


def failure_line(test_path: Path, stdout: str, stderr: str) -> int | None:
    pattern = re.compile(r'File ["\']([^"\']+)["\'], line (\d+)')

    for stream in (stderr, stdout):
        for source, line in reversed(pattern.findall(stream)):
            if Path(source).name == test_path.name:
                return int(line)

    return None


def case_results(
    cases: list[dict[str, object]], status: str, failed_line: int | None = None
) -> list[dict[str, object]]:
    results = []

    for case in cases:
        case_status = "passed" if status == "passed" else "not_run"

        if (
            status == "failed"
            and failed_line is not None
            and case["start_line"] <= failed_line <= case["end_line"]
        ):
            case_status = "failed"

        results.append(
            {
                "name": case["name"],
                "risk": case["risk"],
                "status": case_status,
                "source_range": f"{case['start_line']}-{case['end_line']}",
            }
        )

    return results


def case_for_line(
    cases: list[dict[str, object]], line: int | None
) -> dict[str, object] | None:
    if line is None:
        return None

    matches = [
        case for case in cases if case["start_line"] <= line <= case["end_line"]
    ]
    return min(matches, key=lambda case: case["end_line"] - case["start_line"]) if matches else None


def run_test(
    test_path: Path,
    timeout_seconds: float,
    coverage_directory: Path | None,
    cases: list[dict[str, object]],
) -> dict[str, object]:
    started_at = time.perf_counter()
    command = [sys.executable, str(test_path)]
    environment = os.environ.copy()

    if coverage_directory is not None:
        environment["BETTERINVENTORY_COVERAGE_FILE"] = str(
            coverage_directory / f"{test_path.stem}.json"
        )

    try:
        result = subprocess.run(
            command,
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
            check=False,
            env=environment,
        )
        status = "passed" if result.returncode == 0 else "failed"
        failed_line = failure_line(test_path, result.stdout, result.stderr)
        record: dict[str, object] = {
            "name": test_path.name,
            "status": status,
            "returncode": result.returncode,
            "duration_seconds": round(time.perf_counter() - started_at, 3),
            "cases": case_results(cases, status, failed_line),
        }

        if status == "failed":
            record["stdout_tail"] = tail(result.stdout)
            record["stderr_tail"] = tail(result.stderr)
            record["failure_line"] = failed_line
            failed_case = case_for_line(cases, failed_line)
            record["failure_case"] = failed_case["name"] if failed_case else None

        return record
    except subprocess.TimeoutExpired as error:
        return {
            "name": test_path.name,
            "status": "timeout",
            "returncode": None,
            "duration_seconds": round(time.perf_counter() - started_at, 3),
            "cases": case_results(cases, "timeout"),
            "stdout_tail": tail(error.stdout or ""),
            "stderr_tail": tail(error.stderr or ""),
        }
    except OSError as error:
        return {
            "name": test_path.name,
            "status": "runner_error",
            "returncode": None,
            "duration_seconds": round(time.perf_counter() - started_at, 3),
            "cases": case_results(cases, "runner_error"),
            "error": str(error),
        }


def count_source_lines(path: Path) -> int:
    return sum(
        1
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("--")
    )


def build_coverage_report(
    coverage_directory: Path,
    policy_path: Path,
    passed_branch_modules: set[str] | None = None,
) -> dict[str, object]:
    covered_by_name: dict[str, set[int]] = {}
    policy = json.loads(policy_path.read_text(encoding="utf-8"))
    policy_modules = policy.get("modules", {})
    static_modules = policy.get("static_modules", {})
    declarative_modules = set(policy.get("declarative_modules", []))
    passed_branch_modules = passed_branch_modules or set()

    if not isinstance(policy_modules, dict) or not isinstance(static_modules, dict):
        raise ValueError("coverage modules and static_modules must be objects")

    for part_path in coverage_directory.glob("*.json"):
        try:
            part = json.loads(part_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue

        for source, lines in part.get("sources", {}).items():
            source_name = Path(str(source).removeprefix("@"))
            covered_by_name.setdefault(source_name.name, set()).update(lines)

    modules = []
    runtime_root = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
    runtime_names = {path.name for path in runtime_root.glob("BetterInventory*.lua")}
    policy_names = set(policy_modules)
    static_names = set(static_modules)
    policy_failures = [
        {
            "policy_module": name,
            "reason": "policy_references_missing_runtime_module",
        }
        for name in sorted(policy_names - runtime_names)
    ]
    policy_failures.extend(
        {
            "policy_module": name,
            "reason": "static_policy_references_missing_runtime_module",
        }
        for name in sorted(static_names - runtime_names)
    )
    policy_failures.extend(
        {
            "policy_module": name,
            "reason": "module_has_both_line_and_static_coverage_policy",
        }
        for name in sorted(policy_names & static_names)
    )

    for runtime_path in sorted(runtime_root.glob("BetterInventory*.lua")):
        total_lines = count_source_lines(runtime_path)
        covered_lines = covered_by_name.get(runtime_path.name, set())
        covered_count = len(covered_lines)
        policy_entry = policy_modules.get(runtime_path.name)
        static_entry = static_modules.get(runtime_path.name)
        declarative = runtime_path.name in declarative_modules
        static_verified = static_entry is not None and runtime_path.name in passed_branch_modules
        unassigned = policy_entry is None and static_entry is None and not declarative
        minimum_percent = (
            float(policy_entry.get("minimum_percent", 0.0))
            if policy_entry is not None
            else None
        )
        coverage_percent = round(covered_count * 100 / total_lines, 2) if total_lines else 100.0
        gate_passed = (
            declarative
            or static_verified
            or (
                policy_entry is not None
                and coverage_percent >= minimum_percent
            )
        )

        if unassigned:
            policy_failures.append(
                {
                    "module": runtime_path.name,
                    "reason": "unassigned_non_declarative_runtime_module",
                }
            )

        modules.append(
            {
                "module": runtime_path.name,
                "source_lines": total_lines,
                "covered_lines": covered_count,
                "coverage_percent": coverage_percent,
                "declarative": declarative,
                "verification_mode": (
                    "declarative"
                    if declarative
                    else "static_branch_contract"
                    if static_entry is not None
                    else "line_coverage"
                ),
                "minimum_percent": minimum_percent,
                "risk": (
                    policy_entry.get("risk")
                    if policy_entry
                    else static_entry.get("risk")
                    if static_entry
                    else "declarative"
                    if declarative
                    else "unassigned"
                ),
                "gate_passed": gate_passed,
                "failure": (
                    "unassigned_non_declarative_runtime_module"
                    if unassigned
                    else "static_module_has_no_passing_branch_contract"
                    if static_entry is not None and not static_verified
                    else None
                ),
            }
        )

    total_source_lines = sum(module["source_lines"] for module in modules)
    total_covered_lines = sum(module["covered_lines"] for module in modules)

    return {
        "method": "Lua debug.sethook line events",
        "policy": str(policy_path.relative_to(PROJECT_ROOT)),
        "policy_failures": policy_failures,
        "modules": modules,
        "source_lines": total_source_lines,
        "covered_lines": total_covered_lines,
        "coverage_percent": round(
            total_covered_lines * 100 / total_source_lines, 2
        )
        if total_source_lines
        else 100.0,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--timeout-seconds",
        type=float,
        default=45.0,
        help="Maximum runtime for each behavior script.",
    )
    parser.add_argument(
        "--coverage-output",
        type=Path,
        help="Write a module-by-module Lua line coverage JSON report.",
    )
    parser.add_argument(
        "--coverage-policy",
        type=Path,
        default=COVERAGE_POLICY_PATH,
        help="Risk-weighted module coverage policy used when coverage is requested.",
    )
    args = parser.parse_args()

    if args.timeout_seconds <= 0:
        parser.error("--timeout-seconds must be positive")

    tests = discover_tests()

    if not tests:
        print("No BetterInventory behavior scripts discovered.", file=sys.stderr)
        return 2

    try:
        case_manifest = load_case_manifest()
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"Invalid case manifest: {error}", file=sys.stderr)
        return 2

    discovered_names = {test_path.name for test_path in tests}
    manifest_names = set(case_manifest)
    if discovered_names != manifest_names:
        missing = sorted(discovered_names - manifest_names)
        stale = sorted(manifest_names - discovered_names)
        print(
            f"Case manifest mismatch; missing={missing}, stale={stale}",
            file=sys.stderr,
        )
        return 2

    try:
        validate_case_ranges(case_manifest, tests)
        branch_matrix = load_branch_matrix(case_manifest)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"Invalid case/branch contract: {error}", file=sys.stderr)
        return 2

    temporary_coverage_directory = None
    coverage_report = None
    coverage_failures: list[dict[str, object]] = []

    if args.coverage_output:
        temporary_coverage_directory = Path(
            tempfile.mkdtemp(prefix="betterinventory-coverage-")
        )

    try:
        results = [
            run_test(
                test_path,
                args.timeout_seconds,
                temporary_coverage_directory,
                case_manifest[test_path.name],
            )
            for test_path in tests
        ]
        failures = [result for result in results if result["status"] != "passed"]
        total_cases = sum(len(result["cases"]) for result in results)
        failed_cases = sum(
            1
            for result in results
            for case in result["cases"]
            if case["status"] == "failed"
        )
        not_run_cases = sum(
            1
            for result in results
            for case in result["cases"]
            if case["status"] == "not_run"
        )
        result_by_name = {result["name"]: result for result in results}
        branch_results = []

        for required in branch_matrix:
            test_result = result_by_name[required["test"]]
            matching_case = next(
                case
                for case in test_result["cases"]
                if case["name"] == required["case"]
            )
            branch_results.append(
                {
                    **required,
                    "status": matching_case["status"],
                    "gate_passed": matching_case["status"] == "passed",
                }
            )

        branch_failures = [
            result for result in branch_results if not result["gate_passed"]
        ]
        summary = {
            "runner": "BetterInventory behavior suite",
            "timeout_seconds_per_test": args.timeout_seconds,
            "tests_discovered": len(results),
            "tests_passed": len(results) - len(failures),
            "tests_failed": len(failures),
            "cases_discovered": total_cases,
            "cases_passed": total_cases - failed_cases,
            "cases_failed": failed_cases,
            "cases_not_run": not_run_cases,
            "branch_matrix": branch_results,
            "branch_matrix_failures": branch_failures,
            "results": results,
        }

        if args.coverage_output and temporary_coverage_directory:
            coverage_report = build_coverage_report(
                temporary_coverage_directory,
                args.coverage_policy,
                {
                    module
                    for result in branch_results
                    if result["gate_passed"]
                    for module in result["modules"]
                },
            )
            args.coverage_output.parent.mkdir(parents=True, exist_ok=True)
            args.coverage_output.write_text(
                json.dumps(coverage_report, indent=2, sort_keys=True),
                encoding="utf-8",
            )
            summary["coverage_report"] = str(args.coverage_output)
            coverage_failures = [
                module
                for module in coverage_report["modules"]
                if not module["gate_passed"] and not module["declarative"]
            ]
            coverage_failures.extend(coverage_report["policy_failures"])
            summary["coverage_failures"] = coverage_failures
    finally:
        if temporary_coverage_directory:
            shutil.rmtree(temporary_coverage_directory, ignore_errors=True)

    print(json.dumps(summary, indent=2, sort_keys=True))

    return 1 if failures or coverage_failures or branch_failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
