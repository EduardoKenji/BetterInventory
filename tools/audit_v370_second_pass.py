"""Read-only reproductions for the 2026-09-09 audit; no game/account access.

Run from any directory: python tools/audit_v370_second_pass.py
Assertions verify the resolver remediation against the original baseline.
"""
from pathlib import Path
import re
import statistics
import subprocess
import sys
import time

from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
BASE = "991312c"
RUNTIME = "scripts/mods/BetterInventory/auto_crafter/games_lantern/"


def baseline(name):
    return subprocess.check_output(
        ["git", "show", f"{BASE}:{RUNTIME}{name}.lua"], cwd=ROOT, text=True
    )


def parser_probe():
    html = (ROOT / "tests/fixtures/games_lantern_weapon_cards.html").read_text()
    for name, source in ((BASE, baseline("parser")),
                         ("working tree", (ROOT / (RUNTIME + "parser.lua")).read_text())):
        lua = LuaRuntime(unpack_returned_tuples=True)
        parser = lua.execute(source)
        for spaces in (1000, 4000, 16000):
            malformed, replacements = re.subn(
                r'style="width:\s*\d+%',
                lambda _: 'style="width:' + ' ' * spaces + 'x', html, count=1,
            )
            assert replacements == 1 and len(malformed) < parser.MAX_HTML_BYTES
            samples = []
            for _ in range(3):
                start = time.perf_counter()
                parser.parse(malformed)
                samples.append(1000 * (time.perf_counter() - start))
            print(f"parser {name}: {spaces} spaces, {statistics.median(samples):.3f} ms median", flush=True)


def resolver_probe():
    # Reuse the existing native-family fixture setup instead of duplicating it.
    # This diagnostic executes only its prefix, ending before the malformed-total case.
    sys.path.insert(0, str(ROOT / "tests"))
    path = ROOT / "tests/test_games_lantern_workflow.py"
    source = path.read_text(encoding="utf-8")
    marker = '    ogryn_model["weapons"][1]["stats"][5]["value"] = 79'
    assert marker in source
    namespace = {"__file__": str(path), "__name__": "audit_fixture"}
    exec(compile(source[:source.index(marker)] + "    return locals()\n", str(path), "exec"), namespace)
    fixture = namespace["main"]()
    model, context = fixture["ogryn_model"], fixture["ogryn_context"]
    model["weapons"][1]["stats"][2]["label"] = "Future Stat A!"
    model["weapons"][1]["stats"][5]["value"] = 79
    old = fixture["lua"].execute(baseline("resolver"))
    rejected, reason = old.resolve_identities(model, context)
    assert rejected is None and reason == "custom_stats_invalid_total"
    accepted, reason = fixture["resolver"].resolve_identities(model, context)
    assert accepted is None and reason == "custom_stats_invalid"
    print("resolver: duplicate-normalized 379 profile correctly rejected")


if __name__ == "__main__":
    parser_probe()
    resolver_probe()
