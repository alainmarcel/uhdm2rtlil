#!/usr/bin/env python3
"""vcd_first_diff.py a.vcd b.vcd [N]: earliest divergences between two VCDs
over the signals present (same hierarchical name, same width) in both.
Prints the N earliest (time, signal, a-value, b-value)."""
import sys, collections

def parse(path, keep=None):
    ids = {}          # id -> [names]
    widths = {}
    scope = []
    changes = collections.defaultdict(list)   # name -> [(t, val)]
    t = 0
    with open(path, errors="replace") as fh:
        for line in fh:
            if line.startswith("$scope"):
                scope.append(line.split()[2])
            elif line.startswith("$upscope"):
                scope.pop()
            elif line.startswith("$var"):
                p = line.split()
                name = ".".join(scope[1:] + [p[4]])
                if keep is None or name in keep:
                    ids.setdefault(p[3], []).append(name)
                    widths[name] = int(p[2])
            elif line.startswith("$enddefinitions"):
                break
        for line in fh:
            c = line[0]
            if c == "#":
                t = int(line[1:])
            elif c in "01xzXZ":
                for n in ids.get(line[1:].strip(), ()):
                    changes[n].append((t, c))
            elif c in "bBrR":
                v, i = line[1:].split()
                for n in ids.get(i, ()):
                    changes[n].append((t, v))
    return widths, changes

def value_at(ch, t):
    v = None
    for tt, vv in ch:
        if tt > t: break
        v = vv
    return v

wa, ca = parse(sys.argv[1])
wb, cb = parse(sys.argv[2], keep=set(wa))
N = int(sys.argv[3]) if len(sys.argv) > 3 else 40
common = [n for n in wa if n in wb and wa[n] == wb[n]]
print(f"signals a={len(wa)} b={len(wb)} common={len(common)}")
diffs = []
for n in common:
    times = sorted({t for t, _ in ca[n]} | {t for t, _ in cb[n]})
    for t in times:
        va, vb = value_at(ca[n], t), value_at(cb[n], t)
        if va is not None and vb is not None and va.lstrip("0") != vb.lstrip("0"):
            diffs.append((t, n, va, vb)); break
diffs.sort()
for t, n, va, vb in diffs[:N]:
    print(f"t={t} {n} a={va[:40]} b={vb[:40]}")
