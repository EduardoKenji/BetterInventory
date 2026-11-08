"""Find (and optionally remove) dead single-line Lua locals using the Lua AST.

A local is dead when its Name appears exactly once in the file's AST (the
declaration itself; member/field names excluded). Only single-line
`local NAME = RHS` statements with side-effect-free RHS are removed: dotted
aliases, literals, or require("scripts/...").
usage (repo root): python tools/dead_locals.py scripts/mods/BetterInventory [--apply]
       python tools/dead_locals.py scripts/mods/BetterInventory --exports

--exports (report only) lists module-table exports (`Mod.name = ...`,
`function Mod.name`) whose name appears in no other file of scripts/, tests/,
tools/, docs/runtime-module-ownership.json or tests/verify.ps1. Matching is by
whole word, so it over-approximates references (never flags a used name). A
hit is only a candidate: check string-keyed lookups before deleting.

Dry-run first; after --apply run the full suite and verify.ps1. Rerun until
it reports total 0 (removing one local can orphan another). Dead local
functions and multi-line tables are not removed here; list them with
name_counts() and delete by AST token range.
"""
import collections
import glob
import re
import sys

from luaparser import ast

root = sys.argv[1]
apply = "--apply" in sys.argv
SAFE_RHS = re.compile(
    r"^(?:[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*"
    r"|-?\d+(?:\.\d+)?(?:\s*[*/+-]\s*-?\d+(?:\.\d+)?)*"
    r"|\"[^\"\n]*\"|'[^'\n]*'|true|false|nil"
    r"|require\(\"scripts/[\w/]+\"\))$"
)
DECL = re.compile(r"^(\s*)local ([A-Za-z_]\w*) = (.+?)\s*$")


def name_counts(tree):
    members = set()
    for node in ast.walk(tree):
        kind = type(node).__name__
        if kind == "Index" and type(node.idx).__name__ == "Name" and str(node.notation).endswith("DOT"):
            members.add(id(node.idx))
        elif kind == "Field" and type(node.key).__name__ == "Name" and not getattr(node, "between_brackets", False):
            members.add(id(node.key))
        elif kind in ("Method", "Invoke") and type(getattr(node, "name", None) or getattr(node, "func", None)).__name__ == "Name":
            target = node.name if kind == "Method" else node.func
            members.add(id(target))
    counts = collections.Counter()
    for node in ast.walk(tree):
        if type(node).__name__ == "Name" and id(node) not in members:
            counts[node.id] += 1
    return counts


def report_exports():
    files = {}
    for base in ("scripts", "tests", "tools"):
        for p in glob.glob(base + "/**/*", recursive=True):
            if p.endswith((".lua", ".py", ".ps1", ".json")):
                files[p.replace("\\", "/")] = open(p, encoding="utf-8", errors="replace").read()
    files["docs/runtime-module-ownership.json"] = open("docs/runtime-module-ownership.json", encoding="utf-8").read()
    total = 0
    for path in sorted(glob.glob(root + "/**/*.lua", recursive=True)):
        key = path.replace("\\", "/")
        text = files[key]
        module = re.findall(r"^return (\w+)\s*$", text, re.M)
        if not module:
            continue
        pattern = r"^(?:function %s[.:](\w+)|%s\.(\w+)\s*=)" % (module[-1], module[-1])
        names = dict.fromkeys(a or b for a, b in re.findall(pattern, text, re.M))
        others = [t for p, t in files.items() if p != key]
        for name in names:
            word = re.compile(r"\b%s\b" % re.escape(name))
            if not any(word.search(t) for t in others):
                total += 1
                print(f"{key[len(root) + 1:]}: {module[-1]}.{name}")
    print("total", total)


if "--exports" in sys.argv:
    report_exports()
    sys.exit(0)

total = 0
for path in sorted(glob.glob(root + "/**/*.lua", recursive=True)):
    text = open(path, encoding="utf-8", newline="").read()
    counts = name_counts(ast.parse(text))
    lines = text.split("\n")
    dead = []
    for index, line in enumerate(lines):
        match = DECL.match(line)
        if match and SAFE_RHS.match(match.group(3)) and counts[match.group(2)] == 1:
            dead.append(index)
    if dead:
        total += len(dead)
        print(f"{path[len(root) + 1:]}: {len(dead)} -> " + ", ".join(DECL.match(lines[i]).group(2) for i in dead))
        if apply:
            for i in reversed(dead):
                del lines[i]
            open(path, "w", encoding="utf-8", newline="").write("\n".join(lines))
print("total", total)
