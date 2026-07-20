#!/bin/bash
# ============================================================================
# Functional (boot-and-check-GPIO) simulation of an rp32 SoC test.
#
# Boots the test's memory image (mem_if.mem) on the uhdm2rtlil-synthesised
# netlist using Yosys' built-in `sim`, and checks that the GPIO output reaches
# the values the boot program writes (0x5a then 0xff).  Unlike formal
# equivalence, this needs NO Verilog-frontend reference, so it validates the
# full TCB-interface SoCs (r5p_mouse_soc_top / r5p_degu_soc_top) that the native
# Verilog/Verilator flow can't elaborate (they can't unroll the
# `for (genvar i=1; i<=CFG.HSK.DLY; i++)` interface delay line).
#
#   ./soc_functional_sim.sh <test_dir> [cycles]
#   e.g.  ./soc_functional_sim.sh rp32_r5p_degu_soc_top 800
#
# The test dir must have a project.f (with `# top:`) and a mem_if.mem boot image.
#
# Boot program (mem_if.mem):
#   lui x1,0x80020; li x2,0x5a; sw x2,0(x1); li x2,0xff; sw x2,0(x1); j .
# GPIO register 0 is the OUTPUT-ENABLE reg on the TCB tcb_dev_gpio peripheral
# (offset 3'h0 -> gpio_oe -> gpio_e) and the OUTPUT-DATA reg on the discrete
# mouse_soc_simple GPIO (-> gpio_o).  PASS = gpio_e OR gpio_o takes 0x5a then
# 0xff (same program landing in that SoC's GPIO register map).
#
# Two non-obvious requirements (see inline notes in the yosys script):
#   * a write_verilog round-trip re-derives the imem $meminit with the memory's
#     own address width so memory_collect folds it into the $mem_v2 INIT
#     (the direct read path leaves INIT all-x -> the CPU fetches x);
#   * `sim -zinit` powers the FFs up at 0, else the CPU state stays x (a sim
#     artefact that also hits the cosim-proven mouse_soc_simple).
set -euo pipefail
cd "$(dirname "$0")"

TESTDIR="${1:?usage: soc_functional_sim.sh <test_dir> [cycles]}"
CYCLES="${2:-800}"
[ -d "$TESTDIR" ] || { echo "ERROR: test dir '$TESTDIR' not found" >&2; exit 1; }

ROOT="$(cd .. && pwd)"
YOSYS="$ROOT/out/current/bin/yosys"
PLUGIN="$ROOT/build/uhdm2rtlil.so"
for f in "$YOSYS" "$PLUGIN"; do
    [ -e "$f" ] || { echo "ERROR: $f not found (build uhdm2rtlil first)" >&2; exit 1; }
done

cd "$TESTDIR"
[ -f project.f ]   || { echo "ERROR: $TESTDIR/project.f missing" >&2; exit 1; }
[ -f mem_if.mem ]  || { echo "ERROR: $TESTDIR/mem_if.mem (boot image) missing" >&2; exit 1; }

TOP=$(grep -iE '^#\s*top:' project.f | head -1 | sed -E 's/^#\s*top:\s*//' | tr -d '[:space:]')
[ -n "$TOP" ] || { echo "ERROR: project.f has no '# top:' line" >&2; exit 1; }
SRCS=$(grep -vE '^\s*#|^\s*$' project.f | tr '\n' ' ')

echo "== functional sim: $TESTDIR (top $TOP), $CYCLES cycles"
"$YOSYS" -m "$PLUGIN" -q -p "
    read_sv -parse -nobuiltin -top $TOP $SRCS
    hierarchy -check -top $TOP
    proc; flatten; memory_collect
    opt -full; techmap; opt
    write_verilog -noattr fsim_net.v
    design -reset
    read_verilog -sv fsim_net.v
    hierarchy -top $TOP
    proc; flatten; memory_collect; opt_clean
    sim -clock clk -reset rst -rstlen 8 -n $CYCLES -zinit -vcd fsim.vcd
"

python3 - fsim.vcd <<'PY'
import re, sys
vcd = open(sys.argv[1]).read()
defs = re.findall(r'\$var \w+ (\d+) (\S+) (\S+)(?: \[[\d:]+\])? \$end', vcd)
sig = {s: n for w, s, n in defs if n in ('gpio_o', 'gpio_e')}
time = 0; last = {}; seq = {'gpio_o': [], 'gpio_e': []}
for line in vcd.splitlines():
    if line.startswith('#'):
        time = int(line[1:])
    else:
        m = re.match(r'b([01xz]+) (\S+)', line)
        if m and m.group(2) in sig and last.get(m.group(2)) != m.group(1):
            last[m.group(2)] = m.group(1)
            v = m.group(1)
            if 'x' not in v and 'z' not in v:
                seq[sig[m.group(2)]].append((time, int(v, 2)))
for name in ('gpio_e', 'gpio_o'):
    vals = [v for _, v in seq[name]]
    if 0x5a in vals and 0xff in vals and vals.index(0x5a) < vals.index(0xff):
        for t, v in seq[name]:
            print(f"   {name} = 0x{v:02x} @ t={t}")
        print(f"PASS: {name} took 0x5a then 0xff (boot program ran to completion)")
        sys.exit(0)
print("FAIL: neither gpio_o nor gpio_e reached 0x5a -> 0xff")
for name in ('gpio_o', 'gpio_e'):
    s = ", ".join(f"0x{v:02x}@{t}" for t, v in seq[name])
    print(f"   {name}: {s if s else '(never defined)'}")
sys.exit(1)
PY