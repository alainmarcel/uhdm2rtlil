#!/usr/bin/env python3
"""Append an assumption to a flattened miter RTLIL module: no two of the named
clock inputs TOGGLE in the same global step (clk2fflogic flow).

A dual-clock RAM whose two write ports hit the same address in one global
step is a race in the RTL; the memory_map model resolves it by port ORDER,
which differs between frontends -> false counterexample.  Forbidding
simultaneous clock edges removes exactly that race (each step then carries at
most one clock event) and nothing else.

Usage: add_clk_excl.py miter.il clkA clkB [clkC ...] [--module NAME]"""
import sys, re
args = [a for a in sys.argv[1:] if not a.startswith('--')]
opts = [a for a in sys.argv[1:] if a.startswith('--')]
il, clks = args[0], args[1:]
mod = next((o.split('=', 1)[1] for o in opts if o.startswith('--module=')), 'miter')
assert len(clks) >= 2, 'need at least two clock names'
txt = open(il).read()
m = re.search(r'^module \\%s\n' % re.escape(mod), txt, re.M)
assert m, 'module %s not found' % mod
end = txt.index('\nend\n', m.end())
add = []
for c in clks:
    add.append(f"""
  attribute \\init 1'1
  wire width 1 \\_cx_past_{c}
  wire width 1 \\_cx_tog_{c}
  cell $ff \\_cx_ff_{c}
    parameter \\WIDTH 1
    connect \\D \\{c}
    connect \\Q \\_cx_past_{c}
  end
  cell $_XOR_ \\_cx_x_{c}
    connect \\A \\{c}
    connect \\B \\_cx_past_{c}
    connect \\Y \\_cx_tog_{c}
  end""")
pairs = [(a, b) for i, a in enumerate(clks) for b in clks[i + 1:]]
oks = []
for a, b in pairs:
    oks.append(f"\\_cx_ok_{a}_{b}")
    add.append(f"""
  wire width 1 \\_cx_ok_{a}_{b}
  cell $_NAND_ \\_cx_nand_{a}_{b}
    connect \\A \\_cx_tog_{a}
    connect \\B \\_cx_tog_{b}
    connect \\Y \\_cx_ok_{a}_{b}
  end""")
# AND all pair conditions into one assumption.
cur = oks[0]
for i, o in enumerate(oks[1:]):
    add.append(f"""
  wire width 1 \\_cx_and{i}
  cell $_AND_ \\_cx_a{i}
    connect \\A {cur}
    connect \\B {o}
    connect \\Y \\_cx_and{i}
  end""")
    cur = f"\\_cx_and{i}"
add.append(f"""
  cell $assume \\_cx_assume
    connect \\A {cur}
    connect \\EN 1'1
  end
""")
open(il, 'w').write(txt[:end] + ''.join(add) + txt[end:])
print(f'add_clk_excl: assumed no simultaneous edge of {"/".join(clks)} in {mod}')
