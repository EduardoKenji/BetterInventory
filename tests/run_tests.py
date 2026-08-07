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


def discover_tests() -> list[Path]:
    return sorted(TEST_ROOT.glob("test_*.py"))


def tail(value: str) -> str:
    if len(value) <= OUTPUT_LIMIT:
        return value

    return value[-OUTPUT_LIMIT:]


def run_test(
    test_path: Path,
    timeout_seconds: float,
    coverage_directory: Path | None,
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
            "stdout_tail": tail(error.stdout or ""),
            "stderr_tail": tail(error.stderr or ""),
        }
    except OSError as error:
        return {
            "name": test_path.name,
            "status": "runner_error",
            "returncode": None,
            "duration_seconds": round(time.perf_counter() - started_at, 3),
            "error": str(error),
        }


def count_source_lines(path: Path) -> int:
    return sum(
        1
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("--")
    )


def build_coverage_report(coverage_directory: Path) -> dict[str, object]:
    covered_by_name: dict[str, set[int]] = {}

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
        modules.append(
            {
                "module": runtime_path.name,
                "source_lines": total_lines,
                "covered_lines": covered_count,
                "coverage_percent": round(covered_count * 100 / total_lines, 2)
                if total_lines
                else 100.0,
            }
        )

    total_source_lines = sum(module["source_lines"] for module in modules)
    total_covered_lines = sum(module["covered_lines"] for module in modules)

    return {
        "method": "Lua debug.sethook line events",
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
    args = parser.parse_args()

    if args.timeout_seconds <= 0:
        parser.error("--timeout-seconds must be positive")

    tests = discover_tests()
    temporary_coverage_directory = None

    if args.coverage_output:
        temporary_coverage_directory = Path(
            tempfile.mkdtemp(prefix="betterinventory-coverage-")
        )

    try:
        results = [
            run_test(test_path, args.timeout_seconds, temporary_coverage_directory)
            for test_path in tests
        ]
        failures = [result for result in results if result["status"] != "passed"]
        summary = {
            "runner": "BetterInventory behavior suite",
            "timeout_seconds_per_test": args.timeout_seconds,
            "tests_discovered": len(results),
            "tests_passed": len(results) - len(failures),
            "tests_failed": len(failures),
            "results": results,
        }

        if args.coverage_output and temporary_coverage_directory:
            coverage_report = build_coverage_report(temporary_coverage_directory)
            args.coverage_output.parent.mkdir(parents=True, exist_ok=True)
            args.coverage_output.write_text(
                json.dumps(coverage_report, indent=2, sort_keys=True),
                encoding="utf-8",
            )
            summary["coverage_report"] = str(args.coverage_output)
    finally:
        if temporary_coverage_directory:
            shutil.rmtree(temporary_coverage_directory, ignore_errors=True)

    print(json.dumps(summary, indent=2, sort_keys=True))

    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
