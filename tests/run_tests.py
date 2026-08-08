"""Timeout-bounded, machine-readable runner for the Lua/Lupa behavior suite."""

from __future__ import annotations

import argparse
import json
import os
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


def discover_tests() -> list[Path]:
    return sorted(TEST_ROOT.glob("test_*.py"))


def tail(value: str) -> str:
    if len(value) <= OUTPUT_LIMIT:
        return value

    return value[-OUTPUT_LIMIT:]


def load_case_manifest() -> dict[str, list[dict[str, str]]]:
    manifest = json.loads(CASE_MANIFEST_PATH.read_text(encoding="utf-8"))

    if not isinstance(manifest, dict):
        raise ValueError("case manifest must be an object")

    normalized: dict[str, list[dict[str, str]]] = {}

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
                }
            )

        normalized[test_name] = normalized_cases

    return normalized


def case_results(cases: list[dict[str, str]], status: str) -> list[dict[str, str]]:
    return [
        {
            "name": case["name"],
            "risk": case["risk"],
            "status": "passed" if status == "passed" else "failed",
        }
        for case in cases
    ]


def run_test(
    test_path: Path,
    timeout_seconds: float,
    coverage_directory: Path | None,
    cases: list[dict[str, str]],
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
        record: dict[str, object] = {
            "name": test_path.name,
            "status": status,
            "returncode": result.returncode,
            "duration_seconds": round(time.perf_counter() - started_at, 3),
            "cases": case_results(cases, status),
        }

        if status == "failed":
            record["stdout_tail"] = tail(result.stdout)
            record["stderr_tail"] = tail(result.stderr)

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
    coverage_directory: Path, policy_path: Path
) -> dict[str, object]:
    covered_by_name: dict[str, set[int]] = {}
    policy = json.loads(policy_path.read_text(encoding="utf-8"))
    policy_modules = policy.get("modules", {})
    declarative_modules = set(policy.get("declarative_modules", []))

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

    for runtime_path in sorted(runtime_root.glob("BetterInventory*.lua")):
        total_lines = count_source_lines(runtime_path)
        covered_lines = covered_by_name.get(runtime_path.name, set())
        covered_count = len(covered_lines)
        policy_entry = policy_modules.get(runtime_path.name, {})
        minimum_percent = float(policy_entry.get("minimum_percent", 0.0))
        coverage_percent = round(covered_count * 100 / total_lines, 2) if total_lines else 100.0
        modules.append(
            {
                "module": runtime_path.name,
                "source_lines": total_lines,
                "covered_lines": covered_count,
                "coverage_percent": coverage_percent,
                "declarative": runtime_path.name in declarative_modules,
                "minimum_percent": minimum_percent,
                "risk": policy_entry.get("risk", "declarative" if runtime_path.name in declarative_modules else "unassigned"),
                "gate_passed": coverage_percent >= minimum_percent,
            }
        )

    total_source_lines = sum(module["source_lines"] for module in modules)
    total_covered_lines = sum(module["covered_lines"] for module in modules)

    return {
        "method": "Lua debug.sethook line events",
        "policy": str(policy_path.relative_to(PROJECT_ROOT)),
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
            if case["status"] != "passed"
        )
        summary = {
            "runner": "BetterInventory behavior suite",
            "timeout_seconds_per_test": args.timeout_seconds,
            "tests_discovered": len(results),
            "tests_passed": len(results) - len(failures),
            "tests_failed": len(failures),
            "cases_discovered": total_cases,
            "cases_passed": total_cases - failed_cases,
            "cases_failed": failed_cases,
            "results": results,
        }

        if args.coverage_output and temporary_coverage_directory:
            coverage_report = build_coverage_report(
                temporary_coverage_directory, args.coverage_policy
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
            summary["coverage_failures"] = coverage_failures
    finally:
        if temporary_coverage_directory:
            shutil.rmtree(temporary_coverage_directory, ignore_errors=True)

    print(json.dumps(summary, indent=2, sort_keys=True))

    return 1 if failures or coverage_failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
