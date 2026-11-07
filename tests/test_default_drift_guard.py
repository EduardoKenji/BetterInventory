"""Drift guard: literal-ID setting fallbacks in runtime Lua must match data.lua.

Scans `<recv>:get("id") ==/~= true|false|"str"|number`, `<recv>:get("id") or <literal>`
and `*setting(mod, "id", <literal>...)` calls. Dynamic IDs (`mod:get(prefix .. "_x")`,
IDs held in variables) are NOT covered; only literal IDs can be checked mechanically.

`== L` and `~= L` both treat an unset value as "not L", so the default must differ from
L; `or L` and `setting(.., L)` substitute L, so the default must equal L.
"""
import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from tools.schema_manifest import RUNTIME_ROOT, load_schema

SKIP_FILES = ("BetterInventory_data.lua",)
LITERAL = r'(true|false|-?\d+(?:\.\d+)?|"[^"\n]*")'
COMPARE = re.compile(r'\b\w+:get\("(\w+)"\)\s*(==|~=)\s*' + LITERAL)
OR_FALLBACK = re.compile(r'\b\w+:get\("(\w+)"\)\s*or\s*' + LITERAL + r'(?![\w.(])')
HELPER = re.compile(r'\b(?!set_|import_)\w*setting\(\s*(?:\w+\s*,\s*)?"(\w+)"\s*,\s*' + LITERAL + r'\s*[,)]')

# (file, setting_id, literal) -> reason an unset value intentionally differs from data.lua.
SPENDING_GATE = (
    "Curio buying spends credits: an unset value must not enable the scan "
    "(documented fail-closed gate; the panel-state key mirrors it)"
)
ALLOWLIST: dict[tuple[str, str, str], str] = {
    ("BetterInventory_curio_acquisition.lua", "automatic_curio_scan_operative_selection", "true"): SPENDING_GATE,
    ("BetterInventory_curio_acquisition.lua", "automatic_curio_rescan_on_store_refresh", "true"): SPENDING_GATE,
    ("BetterInventory_curio_profiles.lua", "automatic_curio_scan_operative_selection", "true"): SPENDING_GATE,
    ("BetterInventory_feature_panel_state.lua", "automatic_curio_scan_operative_selection", "true"): SPENDING_GATE,
    ("BetterInventory_feature_panel_state.lua", "automatic_curio_rescan_on_store_refresh", "true"): SPENDING_GATE,
}


def literal_value(text: str):
    if text in ("true", "false"):
        return text == "true"
    return text[1:-1] if text.startswith('"') else float(text)


def defaults() -> dict[str, object]:
    data, _, _ = load_schema()
    found: dict[str, object] = {}

    def walk(widgets) -> None:
        if widgets is None:
            return
        for _, widget in widgets.items():
            setting_id, default = widget["setting_id"], widget["default_value"]
            if setting_id is not None and isinstance(default, (bool, int, float, str)):
                found[str(setting_id)] = default
            walk(widget["sub_widgets"])

    walk(data["options"]["widgets"])
    return found


def main() -> None:
    known = defaults()
    problems, used, checked = [], set(), 0

    for path in sorted(RUNTIME_ROOT.rglob("*.lua")):
        if path.name in SKIP_FILES or "localization" in path.name:
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            code = line.split("--", 1)[0]
            for pattern, kind in ((COMPARE, "cmp"), (OR_FALLBACK, "or"), (HELPER, "or")):
                for match in pattern.finditer(code):
                    setting_id = match.group(1)
                    if setting_id not in known:
                        continue
                    literal = match.group(3 if kind == "cmp" else 2)
                    default, value = known[setting_id], literal_value(literal)
                    if isinstance(default, bool) != isinstance(value, bool):
                        continue
                    checked += 1
                    same = default == value
                    if (kind == "cmp" and not same) or (kind == "or" and same):
                        continue
                    key = (path.name, setting_id, literal)
                    if key in ALLOWLIST:
                        used.add(key)
                        continue
                    problems.append(
                        f"{path.name}:{number}: {setting_id} {kind} {literal}; data.lua default is {default!r}"
                    )

    stale = sorted(set(ALLOWLIST) - used)
    assert not problems, "code fallback drifts from data.lua:\n" + "\n".join(problems)
    assert not stale, f"stale drift allowlist entries: {stale}"
    assert checked > 100, f"drift guard matched only {checked} sites; patterns are broken"
    print(f"BetterInventory default drift guard passed: {checked} literal-ID sites checked.")


if __name__ == "__main__":
    main()
