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

    def write_coverage(self) -> None:
        output_path = os.environ.get("BETTERINVENTORY_COVERAGE_FILE")

        if not output_path:
            return

        try:
            snapshot = self._runtime.execute(
                "debug.sethook(); return __better_inventory_coverage",
                name="betterinventory-coverage-snapshot",
            )
            sources: dict[str, list[int]] = {}

            for source, lines in snapshot.items():
                sources[str(source)] = sorted(int(line) for line in lines.keys())

            destination = Path(output_path)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(
                json.dumps({"sources": sources}, indent=2, sort_keys=True),
                encoding="utf-8",
            )
        except Exception as error:  # pragma: no cover - process-exit safety net
            destination = Path(output_path)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(
                json.dumps({"error": str(error), "sources": {}}, indent=2),
                encoding="utf-8",
            )

    def __getattr__(self, name):
        return getattr(self._runtime, name)


@atexit.register
def _write_all_coverage() -> None:
    for runtime in _RUNTIMES:
        runtime.write_coverage()
