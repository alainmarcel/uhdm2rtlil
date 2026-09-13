#!/usr/bin/env python3
"""Diff a yosys `sat -show-public` counterexample of a gold/gate miter.
usage: cex_diff.py <sat log> [--all]   (default: top-level signals only)"""
import re, sys
log = open(sys.argv[1]).read().splitlines()
show_all = "--all" in sys.argv
vals = {}   # (step, side, sig) -> bin
trig = {}
for l in log:
    m = re.match(r"\s+(\d+)\s+\\(gold|gate)\.(\S+)\s+\S+\s+\S+\s+([01x]+)", l)
    if m:
        vals[(int(m.group(1)), m.group(2), m.group(3))] = m.group(4); continue
    m = re.match(r"\s+(\d+)\s+\\trigger\s+(\d+)", l)
    if m: trig[int(m.group(1))] = m.group(2)
steps = sorted({k[0] for k in vals})
print("trigger per step:", trig)
for st in steps:
    sigs = sorted({k[2] for k in vals if k[0] == st and k[1] == "gold"})
    diffs = []
    for s in sigs:
        if not show_all and "." in s: continue
        g = vals.get((st, "gold", s)); t = vals.get((st, "gate", s))
        if t is not None and g != t: diffs.append((s, g, t))
    print(f"step {st}: {len(diffs)} top-level diffs")
    for s, g, t in diffs[:40]:
        print(f"  {s}\n    gold={g}\n    gate={t}")
