#!/usr/bin/env python3
"""Verilator/iverilog co-sim adjudication for a Pavona ACC module.

The ACC sweep's formal column mitres read_uhdm vs read_slang.  For a module the
SAT miter cannot close (unified_mul: a 256-bit multi-mode combinational
multiplier — SAT-hard), formal alone cannot say whether read_uhdm matches the
behavioural RTL.  This runs three instances under identical random stimulus:

    the behavioural RTL   (the reference — same .sv sources)
    the read_uhdm netlist (gold)
    the read_slang netlist (gate)

and reports how many samples each netlist diverges from the RTL.

Multi-clock aware (like tlul_cosim.py): clk_* inputs get free-running clocks,
rst_*_ni inputs an active-low reset.  ALSO handles a purely COMBINATIONAL module
(no clock port — unified_mul): a synthetic clock paces the random stimulus and
samples the outputs, so a comb DUT (with or without a benign don't-care latch)
is exercised across all input modes.

Reuses the per-module elaboration produced by run_acc_equiv.sh
(work/<mod>/slpp_all/surelog.uhdm) and the same kmac_srcs.py closure.

Usage: acc_cosim.py <module> [cycles] [seed]
"""
import re, sys, os, subprocess

mod    = sys.argv[1]
CYCLES = int(sys.argv[2]) if len(sys.argv) > 2 else 400
SEED   = int(sys.argv[3]) if len(sys.argv) > 3 else 1
HERE   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # pavona_kmac_equiv
_ROOT  = os.environ.get("UHDM2RTLIL_ROOT", os.path.abspath(
    os.path.join(HERE, "..", "..")))
TLUL   = os.path.normpath(os.path.join(HERE, "..", "pavona_tlul_equiv"))
YOSYS  = os.path.join(_ROOT, "out", "current", "bin", "yosys")
PLUGIN = os.path.join(_ROOT, "build", "uhdm2rtlil.so")
# ACC shares the prim library + base pkgs with the TL-UL campaign.
ACCD   = os.path.normpath(os.path.join(HERE, '..', 'pavona_acc_equiv'))
INCS   = [f"{HERE}/rtl/kmac", f"{HERE}/rtl/pkg", f"{ACCD}/rtl/pkg",
          f"{TLUL}/rtl/prim", f"{TLUL}/rtl/tlul", f"{TLUL}/rtl/pkg"]
WORK   = f"{HERE}/work/{mod}"
TOP    = mod

if not os.path.isdir(WORK) or not os.path.exists(f"{WORK}/slpp_all/surelog.uhdm"):
    print(f"{mod}: NO_RUN (no elaboration; run run_acc_equiv.sh first)")
    sys.exit(2)
os.chdir(WORK)

def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)

# ---------------------------------------------------------------- source list
SR = sh([sys.executable, f"{HERE}/scripts/kmac_srcs.py", mod]).stdout.split()
incdir = "\n".join(f"+incdir+{d}" for d in INCS)
inc_ys = " ".join(f"-I {d}" for d in INCS)
FLIST = f"{WORK}/cosim.f"
with open(FLIST, "w") as fh:
    fh.write(incdir + "\n")
    for f in SR:
        fh.write(f + "\n")

# ---------------------------------------------------------------- netlists
if not (os.path.exists("cs_gold.v") and os.path.exists("cs_gate.v")):
    open("cs.ys", "w").write(f"""
read_uhdm slpp_all/surelog.uhdm
hierarchy -check -top {TOP}
flatten; proc; memory; opt -fast; setundef -undriven -zero
delete t:$check t:$assert t:$assume t:$print
simplemap t:$bwmux
rename {TOP} gold_{TOP}
write_verilog -noattr cs_gold.v
design -reset
read_slang --ignore-assertions -DSYNTHESIS {inc_ys} {' '.join(SR)} --top {TOP}
hierarchy -check -top {TOP}
flatten; proc; memory; opt -fast; setundef -undriven -zero
delete t:$check t:$assert t:$assume t:$print
simplemap t:$bwmux
rename {TOP} gate_{TOP}
write_verilog -noattr cs_gate.v
""")
    r = sh([YOSYS, "-q", "-m", PLUGIN, "cs.ys"])
    if r.returncode:
        print(f"{mod}: netlist generation FAILED\n{r.stderr[-800:]}"); sys.exit(2)

# ---------------------------------------------------------------- ports
gv = open("cs_gold.v").read()
mtxt = gv[gv.find(f"module gold_{TOP}"):]
mtxt = mtxt[:mtxt.find("endmodule")]
cut = mtxt.find("function")
if cut > 0:
    mtxt = mtxt[:cut]
ins, outs, clks, rsts = [], [], [], []
for dirn, rng, name in re.findall(r"^  (input|output)\s+(\[\d+:\d+\]\s+)?(\w+);",
                                  mtxt, re.M):
    w = 1
    if rng:
        hi, lo = map(int, re.findall(r"\d+", rng))
        w = hi - lo + 1
    if dirn == "input" and w == 1 and re.search(r"clk|clock", name):
        clks.append(name); continue
    if dirn == "input" and w == 1 and re.search(r"rst|reset", name):
        rsts.append((name, not re.search(r"(_ni|_n|n_i|resetn|rstn)$", name)))
        continue  # (name, active_high?)
    (ins if dirn == "input" else outs).append((name, w))
if not outs:
    print(f"{mod}: no outputs to compare"); sys.exit(2)

# Unpacked-ARRAY ports (`logic [W-1:0] name [Share]`, e.g. keccak_round data_i/
# state_o, msgfifo fifo_*_i / msg_*_o) are FLATTENED to one [N*W-1:0] vector in
# the synth netlist (gold/gate) but stay arrays in the behavioural RTL (the `rtl`
# instance read from source), so a flat actual cannot bind the rtl port.  Detect
# them by the per-element internal wires yosys emits for the flattened port
# (`wire [W-1:0] \name[k] ;` — an ESCAPED id, unlike a `name[k]` part-select),
# deriving N = distinct element count and W = flat_width / N.  The rtl instance
# is then bound through an array-shaped intermediate; element [0] occupies the
# MSB slice of the flat vector (verified: yosys writes `y[0]`->`y[N*W-1 -: W]`).
def _arr_n(name):
    return len(set(re.findall(rf"\\{re.escape(name)}\[(\d+)\]", gv)))
arr = {}   # port name -> (N elements, W element-width) for unpacked-array ports
for _n, _w in ins + outs:
    _N = _arr_n(_n)
    if _N >= 1 and _w % _N == 0:
        arr[_n] = (_N, _w // _N)

# A purely combinational module (unified_mul) has no clock port.  Pace the
# stimulus with a synthetic clock and connect the DUTs by data ports only.
comb = not clks
SAMPLE = clks[0] if clks else "cs_vclk"

def rnd(n, w):
    return " ".join(f"{n}[{min(b+31, w-1)}:{b}] <= $random;" for b in range(0, w, 32))

decl  = "\n".join(f"  reg [{w-1}:0] {n};" for n, w in ins)
wires = "\n".join(f"  wire [{w-1}:0] r_{n}, g_{n}, s_{n};" for n, w in outs)
# Array-shaped intermediates for the rtl instance's unpacked-array ports.  Inputs
# slice the flat driver vector into elements; outputs re-concatenate the rtl's
# array output back into the flat r_<name> compared against gold/gate.  Element
# [0] = MSB slice, [N-1] = LSB (yosys flatten order).
_outset = {n for n, _ in outs}
arr_lines = []
for _n, (_N, _W) in arr.items():
    if _n in _outset:
        arr_lines.append(f"  wire [{_W-1}:0] r_{_n}__ra [0:{_N-1}];")
        _cat = "{" + ", ".join(f"r_{_n}__ra[{k}]" for k in range(_N)) + "}"
        arr_lines.append(f"  assign r_{_n} = {_cat};")
    else:
        arr_lines.append(f"  wire [{_W-1}:0] {_n}__ra [0:{_N-1}];")
        for k in range(_N):
            _lo = (_N - 1 - k) * _W
            arr_lines.append(f"  assign {_n}__ra[{k}] = {_n}[{_lo + _W - 1}:{_lo}];")
arr_decl = "\n".join(arr_lines)
periods = [5, 7, 9, 11]
clkdecl = "\n".join(f"  reg {c} = 0;" for c in clks)
if comb:
    clkdecl += "\n  reg cs_vclk = 0;"
clkgen  = "\n".join(f"  always #{periods[i % len(periods)]} {c} = ~{c};"
                    for i, c in enumerate(clks))
if comb:
    clkgen += "\n  always #5 cs_vclk = ~cs_vclk;"
rstdecl = "\n".join(f"  reg {n} = {'1' if ah else '0'};" for n, ah in rsts)
rst_assert  = "\n    ".join(f"{n} = {'1' if ah else '0'};" for n, ah in rsts)
rst_release = "\n    ".join(f"{n} = {'0' if ah else '1'};" for n, ah in rsts)
# DUT clock/reset port binding (empty for a comb module: cs_vclk is tb-only).
allck = ", ".join(f".{c}({c})" for c in clks) + \
        ("," if clks and rsts else "") + \
        ", ".join(f".{n}({n})" for n, _ in rsts)
# Input connections: gold/gate take the flat driver; the rtl instance takes the
# array-shaped view (name__ra) for its unpacked-array ports.
conn      = ", ".join(f".{n}({n})" for n, _ in ins)                 # gold/gate (flat)
conn_rtl  = ", ".join(f".{n}({n + '__ra' if n in arr else n})" for n, _ in ins)
head  = (allck + ", ") if allck else ""
# Output binding: gold/gate flat (g_/s_); the rtl instance's array outputs bind
# to the array intermediate r_<name>__ra (whose concat drives flat r_<name>).
def bind(p):
    if p == "r":
        return ", ".join(f".{n}(r_{n}__ra)" if n in arr else f".{n}(r_{n})"
                         for n, _ in outs)
    return ", ".join(f".{n}({p}_{n})" for n, _ in outs)
drive = "\n      ".join(rnd(n, w) for n, w in ins)
gbad = " || ".join(f"((r_{n} === r_{n}) && (g_{n} !== r_{n}))" for n, _ in outs)
sbad = " || ".join(f"((r_{n} === r_{n}) && (s_{n} !== r_{n}))" for n, _ in outs)
seen  = "\n".join(f"  reg repg_{n}, reps_{n};" for n, _ in outs)
seeni = "\n    ".join(f"repg_{n} = 0; reps_{n} = 0;" for n, _ in outs)
def _rep(n):
    return (
      f'      if (!repg_{n} && (r_{n}===r_{n}) && (g_{n}!==r_{n})) '
      f'begin repg_{n}=1; $display("FIRST-UHDM %0d {n} rtl=%h uhdm=%h", i, r_{n}, g_{n}); end\n'
      f'      if (!reps_{n} && (r_{n}===r_{n}) && (s_{n}!==r_{n})) '
      f'begin reps_{n}=1; $display("FIRST-SLANG %0d {n} rtl=%h slang=%h", i, r_{n}, s_{n}); end')
report = "\n".join(_rep(n) for n, _ in outs)

# Comb DUTs settle within a sample cycle; a reset preamble only applies to
# clocked modules.
preamble = "" if comb else (rst_assert + "\n    " + drive +
                            f"\n    repeat (6) @(negedge {SAMPLE});\n    " + rst_release)

tb = f"""`timescale 1ns/1ps
module tb;
{clkdecl}
{rstdecl}
{decl}
{wires}
{arr_decl}
  integer i, seed_r, g_err = 0, s_err = 0;
{seen}
  {TOP} rtl ({head}{conn_rtl}, {bind('r')});
  gold_{TOP} gold({head}{conn}, {bind('g')});
  gate_{TOP} gate({head}{conn}, {bind('s')});
{clkgen}
  initial begin
    seed_r = {SEED}; i = $random(seed_r);
    {seeni}
    {preamble}
    for (i = 0; i < {CYCLES}; i = i + 1) begin
      @(negedge {SAMPLE});
      {drive}
      @(posedge {SAMPLE});
      #1;
      if ({gbad}) g_err = g_err + 1;
      if ({sbad}) s_err = s_err + 1;
{report}
    end
    $display("ADJUDICATION %0d cycles: uhdm_vs_rtl=%0d slang_vs_rtl=%0d",
             {CYCLES}, g_err, s_err);
    if (g_err > 0 && s_err == 0) $display("VERDICT UHDM_WRONG");
    else if (s_err > 0 && g_err == 0) $display("VERDICT SLANG_WRONG");
    else if (g_err > 0 && s_err > 0) $display("VERDICT BOTH_DIFFER");
    else $display("VERDICT NO_DIVERGENCE");
    $finish;
  end
endmodule
"""
open("cs_tb.sv", "w").write(tb)

# ---------------------------------------------------------------- run
def run_verilator():
    r = sh(["verilator", "--binary", "-j", "0", "-Wno-lint", "-Wno-style",
            "-Wno-fatal", "--timing", "--no-assert", "-DSYNTHESIS", "-o", "cssim",
            "-f", FLIST,
            "cs_gold.v", "cs_gate.v", "cs_tb.sv", "--top-module", "tb"])
    if r.returncode:
        return None, r.stderr[-800:]
    r = sh(["./obj_dir/cssim"])
    return r.stdout, r.stderr[-800:]

def run_iverilog():
    inc = [f"-I{d}" for d in INCS]
    r = sh(["iverilog", "-g2012", "-DSYNTHESIS", "-o", "cssim.vvp", "-s", "tb"]
           + inc + SR + ["cs_gold.v", "cs_gate.v", "cs_tb.sv"])
    if r.returncode:
        return None, r.stderr[-800:]
    r = sh(["vvp", "cssim.vvp"])
    return r.stdout, r.stderr[-800:]

if os.environ.get("ADJ_TOOL") == "iverilog":
    out, err = run_iverilog(); tool = "iverilog"
else:
    out, err = run_verilator(); tool = "verilator"
if out is None or "ADJUDICATION" not in (out or ""):
    if err: sys.stderr.write("verilator: " + err.strip().splitlines()[-1][:200] + "\n")
    out, err = run_iverilog(); tool = "iverilog"
if out is None or "ADJUDICATION" not in (out or ""):
    print(f"{mod}: NO VERDICT (both simulators failed)")
    if err: print("   " + (err.strip().splitlines() or [""])[-1][:150])
    sys.exit(1)

for line in out.splitlines():
    if line.startswith(("ADJUDICATION", "VERDICT", "FIRST")):
        print(f"{mod} [{tool}] {line}")
