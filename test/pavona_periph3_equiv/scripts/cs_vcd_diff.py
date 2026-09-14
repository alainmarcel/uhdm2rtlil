#!/usr/bin/env python3
"""Earliest-internal-divergence between the behavioural RTL instance (tb.rtl.*)
and the read_uhdm netlist instance (tb.gold.*) in a CS_TRACE=1 co-sim VCD.

The flattened netlist keeps hierarchical names as dotted flat identifiers
(`u_aes.u_aes_core.x`), the RTL instance has real scopes; both normalise to the
same dotted path.  For every path present on both sides, report the first
sample time at which the values differ (X on either side is ignored), sorted by
time — the earliest entries localise the frontend bug.

Usage: cs_vcd_diff.py <vcd> [N]
"""
import sys, re, collections
import json, os
vcd = sys.argv[1]; N = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 40
TRMAP = json.load(open('trace_map.json')) if os.path.exists('trace_map.json') else {}
TRMAP_G = json.load(open('trace_map_gate.json')) if os.path.exists('trace_map_gate.json') else {}
sig = {}          # code -> list of full names
scope = []
with open(vcd) as f:
    it = iter(f)
    for line in it:
        t = line.split()
        if not t: continue
        if t[0] == '$scope': scope.append(t[2])
        elif t[0] == '$upscope': scope.pop()
        elif t[0] == '$var':
            code = t[3]; name = t[4]
            full = '.'.join(scope + [name])
            sig.setdefault(code, []).append(full)
        elif t[0] == '$enddefinitions': break
    # value change section
    vals = collections.defaultdict(dict)   # code -> {time: value}  (last value at time)
    cur = {}
    first_at = {}
    t = 0
    for line in it:
        line = line.rstrip('\n')
        if not line: continue
        c = line[0]
        if c == '#':
            t = int(line[1:])
        elif c in '01xzXZ':
            cur[line[1:]] = c; vals[line[1:]][t] = c
        elif c in 'bB':
            v, code = line[1:].split()
            cur[code] = v; vals[code][t] = v
def norm(n):
    # restore the hierarchical path of a renamed netlist identifier
    head = n.split('.')[0] if '.' in n else n
    for mp in (TRMAP, TRMAP_G):
        if n in mp: return mp[n]
        if head in mp: return mp[head] + n[len(head):]
    return n
# --ref gate : compare the read_uhdm netlist (gold) against the read_slang
# netlist (gate) instead of the behavioural RTL — same yosys naming on both
# sides, so netlist-only artefacts (opt_dff hold don't-cares) cancel out.
REFSIDE = 'gate' if '--ref' in sys.argv and sys.argv[sys.argv.index('--ref') + 1] == 'gate' else 'rtl'
rtl, gold = {}, {}
for code, names in sig.items():
    for n in names:
        if n.startswith('tb.' + REFSIDE + '.'): rtl[norm(n[len(REFSIDE) + 4:])] = code
        elif n.startswith('tb.gold.'): gold[norm(n[8:])] = code
common = sorted(set(rtl) & set(gold))
print(f"rtl signals {len(rtl)}, gold signals {len(gold)}, common {len(common)}")
def series(code):
    return sorted(vals[code].items())
def norm_v(v):
    v = v.lstrip('0') or '0'
    return v
# --at T --grep RE : print both sides' values of matching signals at time T
if '--at' in sys.argv:
    T = int(sys.argv[sys.argv.index('--at') + 1])
    RE = re.compile(sys.argv[sys.argv.index('--grep') + 1]) if '--grep' in sys.argv else None
    def val_at(code, T):
        v = None
        for tt, x in series(code):
            if tt <= T: v = x
            else: break
        return v
    names = sorted(gold) if '--gold-only' in sys.argv else common
    for n in names:
        if RE and not RE.search(n): continue
        va = val_at(rtl[n], T) if n in rtl else None
        vb = val_at(gold[n], T) if n in gold else None
        flag = '' if (va == vb or va is None or vb is None) else '   <== DIFF'
        print(f"{n:90s} rtl={str(va)[-48:]:>48s} uhdm={str(vb)[-48:]:>48s}{flag}")
    sys.exit(0)
# --sample STRIDE PHASE : compare only at t = PHASE + k*STRIDE (e.g. just before
# each posedge) so intra-timestep evaluation-order glitches are ignored.
SAMPLE = None
if '--sample' in sys.argv:
    i = sys.argv.index('--sample'); SAMPLE = (int(sys.argv[i+1]), int(sys.argv[i+2]))
divs = []
for n in common:
    a, b = series(rtl[n]), series(gold[n])
    if not a or not b: continue
    times = sorted(set(x for x, _ in a) | set(x for x, _ in b))
    if SAMPLE:
        tmax = times[-1]
        times = list(range(SAMPLE[1], tmax + SAMPLE[0], SAMPLE[0]))
    ia = ib = 0; va = vb = None
    for tt in times:
        while ia < len(a) and a[ia][0] <= tt: va = a[ia][1]; ia += 1
        while ib < len(b) and b[ib][0] <= tt: vb = b[ib][1]; ib += 1
        if va is None or vb is None: continue
        if any(ch in 'xzXZ' for ch in va) or any(ch in 'xzXZ' for ch in vb): continue
        if norm_v(va) != norm_v(vb):
            divs.append((tt, n, va, vb)); break
divs.sort()
for tt, n, va, vb in divs[:N]:
    print(f"t={tt:>8} {n:70s} rtl={va[-40:]} uhdm={vb[-40:]}")
print(f"{len(divs)} diverging signals of {len(common)} common")
