#!/usr/bin/env python3
"""Decide WHICH frontend is wrong when a module reports `cex`.

The miter says read_uhdm and read_slang disagree; it cannot say which one is
right, and this suite's rule is never to change the frontend on that evidence
alone.  So run three things side by side under identical stimulus:

    the behavioural RTL   (the reference)
    the read_uhdm netlist (gold)
    the read_slang netlist (gate)

and report which netlist diverges from the RTL.  Verilator first; iverilog when
Verilator cannot build the case (it is 2-state and stricter about the netlists
write_verilog emits, while iverilog is 4-state and more forgiving).

Usage: adjudicate.py <module> [cycles] [seed]
"""
import re, sys, os, subprocess

mod    = sys.argv[1]
CYCLES = int(sys.argv[2]) if len(sys.argv) > 2 else 2000
SEED   = int(sys.argv[3]) if len(sys.argv) > 3 else 1
HERE   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK   = f"{HERE}/work/{mod}"
_ROOT  = os.environ.get("UHDM2RTLIL_ROOT", os.path.abspath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..")))
YOSYS  = os.path.join(_ROOT, "out", "current", "bin", "yosys")
PLUGIN = os.path.join(_ROOT, "build", "uhdm2rtlil.so")
FLIST  = os.environ.get("CVA6_FLIST", f"{HERE}/work/cva6.f")
WRAP   = f"{HERE}/wrappers/wrapper_{mod}.sv"
TOP    = f"{mod}_equiv"
os.chdir(WORK)

def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)

# ---------------------------------------------------------------- netlists
if not (os.path.exists("adj_gold.v") and os.path.exists("adj_gate.v")):
    open("adj.ys", "w").write(f"""
read_uhdm slpp_all/surelog.uhdm
hierarchy -check -top {TOP}
flatten; proc; memory; opt -fast; setundef -undriven -zero
delete t:$check t:$assert t:$assume t:$print
simplemap t:$bwmux
rename {TOP} gold_{TOP}
write_verilog -noattr adj_gold.v
design -reset
read_slang --ignore-assertions -f {FLIST} {WRAP} --top {TOP}
hierarchy -check -top {TOP}
flatten; proc; memory; opt -fast; setundef -undriven -zero
delete t:$check t:$assert t:$assume t:$print
simplemap t:$bwmux
rename {TOP} gate_{TOP}
write_verilog -noattr adj_gate.v
""")
    r = sh([YOSYS, "-q", "-m", PLUGIN, "adj.ys"])
    if r.returncode:
        print(f"{mod}: netlist generation FAILED\n{r.stderr[-800:]}"); sys.exit(2)

# ---------------------------------------------------------------- ports
gv = open("adj_gold.v").read()
mtxt = gv[gv.find(f"module gold_{TOP}"):]
mtxt = mtxt[:mtxt.find("endmodule")]
cut = mtxt.find("function")
if cut > 0:
    mtxt = mtxt[:cut]
ins, outs = [], []
for dirn, rng, name in re.findall(r"^  (input|output)\s+(\[\d+:\d+\]\s+)?(\w+);",
                                  mtxt, re.M):
    w = 1
    if rng:
        hi, lo = map(int, re.findall(r"\d+", rng))
        w = hi - lo + 1
    if name in ("clk_i", "rst_ni"):
        continue
    (ins if dirn == "input" else outs).append((name, w))
if not outs:
    print(f"{mod}: no outputs to compare"); sys.exit(2)

def rnd(n, w):
    return " ".join(f"{n}[{min(b+31, w-1)}:{b}] <= $random;" for b in range(0, w, 32))

decl  = "\n".join(f"  reg [{w-1}:0] {n};" for n, w in ins)
wires = "\n".join(f"  wire [{w-1}:0] r_{n}, g_{n}, s_{n};" for n, w in outs)
conn  = ", ".join(f".{n}({n})" for n, _ in ins)
def bind(p): return ", ".join(f".{n}({p}_{n})" for n, _ in outs)
drive = "\n      ".join(rnd(n, w) for n, w in ins)
# Compare each netlist against the RTL, not against each other.  An X on the
# RTL side is not a divergence -- it is the reference declining to say.
gbad = " || ".join(f"((r_{n} === r_{n}) && (g_{n} !== r_{n}))" for n, _ in outs)
sbad = " || ".join(f"((r_{n} === r_{n}) && (s_{n} !== r_{n}))" for n, _ in outs)
# Name the first output that diverges, per side -- "they differ" is not a
# diagnosis, and with a dozen ports the count alone does not say where to look.
seen  = "\n".join(f"  reg rep_{n};" for n, _ in outs)
seeni = "\n    ".join(f"rep_{n} = 0;" for n, _ in outs)
report = "\n".join(
    f'      if (!rep_{n} && (r_{n} === r_{n}) && (g_{n} !== r_{n} || s_{n} !== r_{n})) '
    f'begin rep_{n} = 1; $display("FIRST %0d {n} rtl=%h uhdm=%h slang=%h", i, '
    f'r_{n}, g_{n}, s_{n}); end' for n, _ in outs)

tb = f"""`timescale 1ns/1ps
module tb;
  reg clk = 0, rst_ni = 0;
{decl}
{wires}
  integer i, seed_r, g_err = 0, s_err = 0;
{seen}
  {TOP}      rtl (.clk_i(clk), .rst_ni(rst_ni), {conn}, {bind('r')});
  gold_{TOP} gold(.clk_i(clk), .rst_ni(rst_ni), {conn}, {bind('g')});
  gate_{TOP} gate(.clk_i(clk), .rst_ni(rst_ni), {conn}, {bind('s')});
  // Free-running clock, inputs driven on the FALLING edge and outputs sampled
  // after the rising one.  Driving inputs in the same statement sequence that
  // toggles the clock races the three instances against each other and reports
  // ~40% "divergence" on both sides -- a testbench artefact, not a finding.
  always #5 clk = ~clk;
  initial begin
    seed_r = {SEED}; i = $random(seed_r);
    {seeni}
    rst_ni = 0;
    {drive}
    repeat (4) @(negedge clk);
    rst_ni = 1;
    for (i = 0; i < {CYCLES}; i = i + 1) begin
      @(negedge clk);
      {drive}
      @(posedge clk);
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
open("adj_tb.sv", "w").write(tb)

# ---------------------------------------------------------------- run
def run_verilator():
    r = sh(["verilator", "--binary", "-j", "0", "-Wno-lint", "-Wno-style",
            "-Wno-fatal", "--timing", "-o", "adjsim",
            "-f", FLIST, f"+incdir+{HERE}/wrappers", WRAP,
            "adj_gold.v", "adj_gate.v", "adj_tb.sv", "--top-module", "tb"])
    if r.returncode:
        return None, r.stderr[-600:]
    r = sh(["./obj_dir/adjsim"])
    return r.stdout, r.stderr[-600:]

def run_iverilog():
    # iverilog spells include paths -I<dir>; passing the flist's `+incdir+<dir>`
    # through verbatim makes it treat them as source FILE names, and the build
    # then fails with the misleading "Unable to find the root module tb".
    inc = [f"-I{l.strip()[len('+incdir+'):]}" for l in open(FLIST)
           if l.strip().startswith("+incdir+")]
    src = [l.strip() for l in open(FLIST)
           if l.strip() and not l.strip().startswith(("+", "-"))]
    r = sh(["iverilog", "-g2012", "-o", "adjsim.vvp", "-s", "tb",
            f"-I{HERE}/wrappers"] + inc + src +
           [WRAP, "adj_gold.v", "adj_gate.v", "adj_tb.sv"])
    if r.returncode:
        return None, r.stderr[-600:]
    r = sh(["vvp", "adjsim.vvp"])
    return r.stdout, r.stderr[-600:]

# Verilator is 2-state: an X on the reference side becomes 0, which can both
# hide a divergence and invent one.  ADJ_TOOL=iverilog forces the 4-state
# simulator, which is the tie-breaker whenever the Verilator verdict is mixed.
if os.environ.get("ADJ_TOOL") == "iverilog":
    out, err = run_iverilog()
    tool = "iverilog"
else:
    out, err = run_verilator()
    tool = "verilator"
if out is None or "ADJUDICATION" not in (out or ""):
    print(f"{mod}: verilator could not adjudicate; falling back to iverilog")
    if err: print("   " + err.strip().splitlines()[-1][:150] if err.strip() else "")
    out, err = run_iverilog()
    tool = "iverilog"

if out is None or "ADJUDICATION" not in (out or ""):
    print(f"{mod}: NO VERDICT (both simulators failed)")
    if err: print("   " + (err.strip().splitlines() or [""])[-1][:150])
    sys.exit(1)

for line in out.splitlines():
    if line.startswith(("ADJUDICATION", "VERDICT", "FIRST")):
        print(f"{mod} [{tool}] {line}")
