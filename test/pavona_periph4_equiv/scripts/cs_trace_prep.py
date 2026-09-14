#!/usr/bin/env python3
"""Verilator --trace chokes (V3String reverse-hash assert) on the long
bracketed escaped identifiers a flattened yosys netlist carries
(`\\u_aes.u_aes_core.x[15:8] `).  Rewrite every escaped identifier of the
netlist to a short plain name and keep the map so cs_vcd_diff.py can restore
the hierarchical path.  Usage: cs_trace_prep.py cs_gold.v cs_gold_t.v map.json [prefix]  (use distinct prefixes for gold/gate)"""
import re, sys, json
src, dst, mp = sys.argv[1:4]
PFX = sys.argv[4] if len(sys.argv) > 4 else "tr_"
t = open(src).read()
names = {}
def rep(m):
    n = m.group(1)
    if n not in names: names[n] = f"{PFX}{len(names)}"
    return names[n] + " "
t = re.sub(r'\\(\S+) ', rep, t)
open(dst, 'w').write(t)
json.dump({v: k for k, v in names.items()}, open(mp, 'w'))
print(f"{len(names)} escaped identifiers renamed")
