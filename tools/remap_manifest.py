"""Remap tests/case_manifest.json line ranges for one test file after edits.

run_tests.py requires every assertion line to fall inside exactly one named
case range, so inserting lines into a test shifts every later range. This maps
old ranges (from the file at git HEAD) onto the edited file with difflib and
optionally claims new case blocks.

usage (repo root): python tools/remap_manifest.py . <test_file.py>     ["case_name::start marker text::text of first line AFTER the case" ...]

Run it once per test file after editing, BEFORE committing (baseline is HEAD).
Each case ends right before the next one starts; verify the printed ranges.
"""
import difflib, json, subprocess, sys
from pathlib import Path

repo, name = Path(sys.argv[1]), sys.argv[2]
old = subprocess.run(["git", "-C", str(repo), "show", f"HEAD:tests/{name}"], capture_output=True, text=True, encoding="utf-8", check=True).stdout.splitlines()
new = (repo / "tests" / name).read_text(encoding="utf-8").splitlines()
mapping = {}
for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, old, new, autojunk=False).get_opcodes():
    if tag == "equal":
        for k in range(i2 - i1):
            mapping[i1 + k + 1] = j1 + k + 1

def remap(line, forward):
    probe = line
    while probe not in mapping and 0 < probe <= len(old):
        probe += 1 if forward else -1
    return mapping.get(probe)

path = repo / "tests" / "case_manifest.json"
text = path.read_text(encoding="utf-8")
manifest = json.loads(text)
cases = manifest[name]
# Adjacent ranges: each case ends where the next one starts, so new inserted
# lines between them are absorbed by the preceding case unless claimed below.
for case in cases:
    case["start_line"] = remap(case["start_line"], True)
    case["end_line"] = remap(case["end_line"], False)
for spec in sys.argv[3:]:
    cname, start_marker, end_marker = spec.split("::")
    start = next(i for i, l in enumerate(new, 1) if start_marker in l)
    # end_marker names the first line AFTER the new case (next case's comment).
    end = next(i for i, l in enumerate(new, 1) if i > start and end_marker in l) - 1
    cases.append({"name": cname, "risk": "critical", "start_line": start, "end_line": end})
cases.sort(key=lambda c: c["start_line"])
for a, b in zip(cases, cases[1:]):
    a["end_line"] = min(a["end_line"], b["start_line"] - 1)
for a, b in zip(cases, cases[1:]):
    assert a["end_line"] < b["start_line"], (a, b)
# Rewrite only this file's entry to keep the manifest's hand formatting elsewhere.
lines = text.splitlines(keepends=True)
start = next(i for i, l in enumerate(lines) if l.strip().startswith(f'"{name}"'))
end = next(i for i in range(start, len(lines)) if lines[i].strip().startswith("]"))
body = ",\n".join("    " + json.dumps(c) for c in cases)
lines[start:end + 1] = [f'  "{name}": [\n', body + "\n", lines[end]]
path.write_text("".join(lines), encoding="utf-8", newline="")
for c in cases:
    print(c["name"], c["start_line"], c["end_line"])
