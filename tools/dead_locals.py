"""Find (and optionally remove) dead single-line Lua locals using the Lua AST.

A local is dead when its Name appears exactly once in the file's AST (the
declaration itself; member/field names excluded). Only single-line
`local NAME = RHS` statements with side-effect-free RHS are removed: dotted
aliases, literals, or require("scripts/...").
usage (repo root): python tools/dead_locals.py scripts/mods/BetterInventory [--apply]

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
