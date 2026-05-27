#!/usr/bin/env python3
"""Sort VHDL files in dependency order for GHDL -a.

Usage:  python3 vhdl_topo_sort.py file1.vhd file2.vhd ...
Output: files in topological order (dependencies first), space-separated.
"""
import re, sys
from collections import defaultdict

files = sys.argv[1:]

# Map design unit name (lowercase) -> file path
unit_file = {}
# Map file -> set of unit names it depends on
file_deps = defaultdict(set)

for f in files:
    try:
        text = open(f).read()
    except Exception:
        continue

    # Entity definitions:  entity XXX is
    for m in re.finditer(r'\bentity\s+(\w+)\s+is\b', text, re.I):
        unit_file[m.group(1).lower()] = f

    # Package definitions:  package XXX is  (skip "package body")
    for m in re.finditer(r'\bpackage\s+(\w+)\s+is\b', text, re.I):
        name = m.group(1).lower()
        if name != 'body':
            unit_file[name] = f

    # Dependencies:  entity work.XXX
    for m in re.finditer(r'\bentity\s+work\.(\w+)', text, re.I):
        file_deps[f].add(m.group(1).lower())

    # Dependencies:  use work.XXX.all
    for m in re.finditer(r'\buse\s+work\.(\w+)', text, re.I):
        file_deps[f].add(m.group(1).lower())

# Topological sort (DFS, cycle-safe)
visited = set()
visiting = set()
result = []
file_set = set(files)

def visit(f):
    if f in visited:
        return
    if f in visiting:
        return  # break cycle
    visiting.add(f)
    for dep_name in file_deps.get(f, set()):
        dep_file = unit_file.get(dep_name)
        if dep_file and dep_file != f and dep_file in file_set:
            visit(dep_file)
    visiting.discard(f)
    visited.add(f)
    result.append(f)

for f in sorted(files):
    visit(f)

print(' '.join(result))
