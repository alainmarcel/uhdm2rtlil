#!/usr/bin/env python3
"""Verilator/iverilog co-sim adjudication for a TL-UL module.

The TL-UL sweep's formal column mitres read_uhdm vs read_slang.  For a
dual-clock CDC module (tlul_fifo_async) the SAT miter times out — sat -seq
cannot reason across two independent clocks — so formal alone cannot say
whether read_uhdm matches the behavioural RTL.  This runs three instances
under identical random stimulus and identical clock/reset waveforms:

    the behavioural RTL   (the reference — same .sv sources)
    the read_uhdm netlist (gold)
    the read_slang netlist (gate)

and reports how many cycles each netlist diverges from the RTL.  It is
MULTI-CLOCK aware: every input whose name matches clk_*  / *clk* gets its own
free-running clock (distinct periods so a CDC design actually crosses
domains); every rst_*_ni / *rst*n* input is an active-low reset released after
a few cycles.  All three instances see the SAME waveforms, so an equivalent
trio matches bit-for-bit at every sample point regardless of CDC timing.

Reuses the per-module elaboration produced by run_tlul_equiv.sh
(work/<mod>/slpp_all/surelog.uhdm) and the same closure source list.

Usage: tlul_cosim.py <module> [cycles] [seed]
"""
import re, sys, os, subprocess

mod    = sys.argv[1]
CYCLES = int(sys.argv[2]) if len(sys.argv) > 2 else 400
SEED   = int(sys.argv[3]) if len(sys.argv) > 3 else 1
HERE   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # pavona_tlul_equiv
_ROOT  = os.environ.get("UHDM2RTLIL_ROOT", os.path.abspath(
    os.path.join(HERE, "..", "..")))
YOSYS  = os.path.join(_ROOT, "out", "current", "bin", "yosys")
PLUGIN = os.path.join(_ROOT, "build", "uhdm2rtlil.so")
PRIM   = f"{HERE}/rtl/prim"
TLUL   = f"{HERE}/rtl/tlul"
PKG    = f"{HERE}/rtl/pkg"
WORK   = f"{HERE}/work/{mod}"
TOP    = mod

if not os.path.isdir(WORK) or not os.path.exists(f"{WORK}/slpp_all/surelog.uhdm"):
    print(f"{mod}: NO_RUN (no elaboration; run run_tlul_equiv.sh first)")
    sys.exit(2)
os.chdir(WORK)

def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)

# ---------------------------------------------------------------- source list
SR = sh([sys.executable, f"{HERE}/scripts/tlul_srcs.py", mod]).stdout.split()
FLIST = f"{WORK}/cosim.f"
with open(FLIST, "w") as fh:
    fh.write(f"+incdir+{PRIM}\n+incdir+{TLUL}\n+incdir+{PKG}\n")
    for f in SR:
        fh.write(f + "\n")

# ---------------------------------------------------------------- netlists
# Regenerate the netlists when either is missing OR older than the frontend
# plugin / the UHDM it reads — a cached cs_gold.v silently kept adjudicating a
# PRE-fix read_uhdm netlist (keccak_round showed UHDM_WRONG after the fix).
def _stale(path):
    if not os.path.exists(path):
        return True
    m = os.path.getmtime(path)
    return any(os.path.exists(d) and os.path.getmtime(d) > m
               for d in (PLUGIN, "slpp_all/surelog.uhdm"))
if _stale("cs_gold.v") or _stale("cs_gate.v"):
    open("cs.ys", "w").write(f"""
read_uhdm slpp_all/surelog.uhdm
hierarchy -check -top {TOP}
flatten; proc; memory; opt -fast; setundef -undriven -zero
delete t:$check t:$assert t:$assume t:$print
simplemap t:$bwmux
rename {TOP} gold_{TOP}
write_verilog -noattr cs_gold.v
design -reset
read_slang --ignore-assertions -DSYNTHESIS -I {PRIM} -I {TLUL} -I {PKG} {' '.join(SR)} --top {TOP}
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

# A purely COMBINATIONAL module has no clock port: pace the random stimulus with
# a synthetic clock and connect the DUTs by data ports only, so a comb DUT (with
# or without a benign don't-care latch) is still exercised across all inputs.
comb = not clks
SAMPLE = clks[0] if clks else "cs_vclk"

def rnd(n, w):
    return " ".join(f"{n}[{min(b+31, w-1)}:{b}] <= $random;" for b in range(0, w, 32))

decl  = "\n".join(f"  reg [{w-1}:0] {n};" for n, w in ins)
wires = "\n".join(f"  wire [{w-1}:0] r_{n}, g_{n}, s_{n};" for n, w in outs)
# distinct clock periods so a CDC design crosses domains (host 5ns half, dev 7ns)
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
allck = ", ".join(f".{c}({c})" for c in clks) + \
        ("," if clks and rsts else "") + \
        ", ".join(f".{n}({n})" for n, _ in rsts)
head  = (allck + ", ") if allck else ""   # empty for a comb DUT (cs_vclk is tb-only)
conn  = ", ".join(f".{n}({n})" for n, _ in ins)
def bind(p): return ", ".join(f".{n}({p}_{n})" for n, _ in outs)
drive = "\n      ".join(rnd(n, w) for n, w in ins)
# only compare where RTL output is fully defined (=== itself)
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

# Comb DUTs settle within a sample cycle; the reset preamble only applies to a
# clocked module.
preamble = "" if comb else (rst_assert + "\n    " + drive +
                            f"\n    repeat (6) @(negedge {SAMPLE});\n    " + rst_release)

tb = f"""`timescale 1ns/1ps
module tb;
{clkdecl}
{rstdecl}
{decl}
{wires}
  integer i, seed_r, g_err = 0, s_err = 0;
{seen}
  {TOP} rtl ({head}{conn}, {bind('r')});
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
            "-f", FLIST, f"+incdir+{HERE}/wrappers",
            "cs_gold.v", "cs_gate.v", "cs_tb.sv", "--top-module", "tb"])
    if r.returncode:
        return None, r.stderr[-800:]
    r = sh(["./obj_dir/cssim"])
    return r.stdout, r.stderr[-800:]

def run_iverilog():
    inc = [f"-I{PRIM}", f"-I{TLUL}", f"-I{PKG}"]
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
