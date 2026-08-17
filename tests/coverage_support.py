"""Small Lua line-event collector used by the CI behavior runner."""

from __future__ import annotations

import atexit
import json
import os
from pathlib import Path

from lupa import LuaRuntime as _LuaRuntime


_RUNTIMES: list["InstrumentedLuaRuntime"] = []
_HOOK = r"""
__better_inventory_coverage = {}

debug.sethook(function(_, line)
    local info = debug.getinfo(2, "S")
    local source = info and info.source

    if source then
        local source_lines = __better_inventory_coverage[source]

        if not source_lines then
            source_lines = {}
            __better_inventory_coverage[source] = source_lines
        end

        source_lines[tostring(line)] = true
    end
end, "l")
"""


class InstrumentedLuaRuntime:
    def __init__(self, *args, **kwargs):
        self._runtime = _LuaRuntime(*args, **kwargs)
        self._runtime.execute(_HOOK, name="betterinventory-coverage-hook")
        _RUNTIMES.append(self)

    def coverage_snapshot(self) -> dict[str, set[int]]:
        snapshot = self._runtime.execute(
            "debug.sethook(); return __better_inventory_coverage",
            name="betterinventory-coverage-snapshot",
        )
        sources: dict[str, set[int]] = {}

        for source, lines in snapshot.items():
            sources[str(source)] = {int(line) for line in lines.keys()}

        return sources

    def __getattr__(self, name):
        return getattr(self._runtime, name)


def merge_runtime_coverage(
    runtimes: list[InstrumentedLuaRuntime],
) -> tuple[dict[str, set[int]], list[str]]:
    merged_sources: dict[str, set[int]] = {}
    errors: list[str] = []

    for runtime in runtimes:
        try:
            for source, lines in runtime.coverage_snapshot().items():
                merged_sources.setdefault(source, set()).update(lines)
        except Exception as error:  # pragma: no cover - process-exit safety net
            errors.append(str(error))

    return merged_sources, errors


@atexit.register
def _write_all_coverage() -> None:
    output_path = os.environ.get("BETTERINVENTORY_COVERAGE_FILE")

    if not output_path:
        return

    merged_sources, errors = merge_runtime_coverage(_RUNTIMES)

    destination = Path(output_path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "sources": {
            source: sorted(lines) for source, lines in sorted(merged_sources.items())
        }
    }

    if errors:
        payload["errors"] = errors

    destination.write_text(
        json.dumps(payload, indent=2, sort_keys=True),
        encoding="utf-8",
    )
