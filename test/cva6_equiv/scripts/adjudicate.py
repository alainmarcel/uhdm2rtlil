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
flatten; proc; memory; opt -fast; async2sync; setundef -undriven -zero
delete t:$check t:$assert t:$assume t:$print
simplemap t:$bwmux
rename {TOP} gold_{TOP}
write_verilog -noattr adj_gold.v
design -reset
read_slang --ignore-assertions -f {FLIST} {WRAP} --top {TOP}
hierarchy -check -top {TOP}
flatten; proc; memory; opt -fast; async2sync; setundef -undriven -zero
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
# A purely COMBINATIONAL module (fpnew_classifier) has no clk_i/rst_ni.
# The testbench used to connect them unconditionally, so Verilator
# rejected the whole build with 'Pin not found' and the run was reported
# as 'both simulators failed' — indistinguishable from a design problem.
has_clk_rst = set()
for dirn, rng, name in re.findall(r"^  (input|output)\s+(\[\d+:\d+\]\s+)?(\w+);",
                                  mtxt, re.M):
    w = 1
    if rng:
        hi, lo = map(int, re.findall(r"\d+", rng))
        w = hi - lo + 1
    if name in ("clk_i", "rst_ni"):
        has_clk_rst.add(name)
        continue
    (ins if dirn == "input" else outs).append((name, w))
if not outs:
    print(f"{mod}: no outputs to compare"); sys.exit(2)

def rnd(n, w):
    return " ".join(f"{n}[{min(b+31, w-1)}:{b}] <= $random;" for b in range(0, w, 32))

# The netlists flatten an UNPACKED-array port to one wide vector, but the
# behavioural RTL still declares it as an array -- connecting the flat wire to
# it is a hard Verilator error ("mismatch between port which is an array, and
# expression which is not"), which used to surface as an unexplained
# "both simulators failed".  Find those ports in the wrapper and give the RTL
# instance its own array-shaped nets, packed to/from the flat vector.
unpacked = {}          # port name -> element count
try:
    wtxt = open(WRAP).read()
    wtxt = re.sub(r"//[^\n]*", "", wtxt)
    params = dict(re.findall(r"\bparameter\s+(?:int|int\s+unsigned)\s+(\w+)\s*=\s*(\d+)",
                             wtxt))
    for pname, dim in re.findall(
            r"^\s*(?:input|output|inout)\s+\w+\s+(\w+)\s*\[([^\]]+)\]\s*,?\s*$",
            wtxt, re.M):
        m = re.fullmatch(r"\s*(\w+)\s*-\s*1\s*:\s*0\s*", dim)
        cnt = None
        if m:
            cnt = int(params[m.group(1)]) if m.group(1) in params else None
            if m.group(1).isdigit():
                cnt = int(m.group(1))
        elif re.fullmatch(r"\s*\d+\s*:\s*0\s*", dim):
            cnt = int(dim.split(":")[0]) + 1
        elif re.fullmatch(r"\s*\d+\s*", dim):
            cnt = int(dim)
        if cnt:
            unpacked[pname] = cnt
except OSError:
    pass

_allports = {n: w for n, w in ins + outs}
_bad = [n for n, c in unpacked.items()
        if n in _allports and (c <= 0 or _allports[n] % c)]
for n in _bad:
    del unpacked[n]
if _bad:
    print(f"{mod}: unpacked ports not evenly divisible, left flat: {_bad}")
_unres = [n for n in re.findall(
              r"^\s*(?:input|output|inout)\s+\w+\s+(\w+)\s*\[[^\]]+\]\s*,?\s*$",
              re.sub(r"//[^\n]*", "", open(WRAP).read()), re.M)
          if n in _allports and n not in unpacked]
if _unres:
    # Say so rather than let the simulator fail with a port-shape error that
    # reads like a design problem.
    print(f"{mod}: WARNING cannot size unpacked port(s) {_unres}; "
          f"the RTL connection will fail to elaborate")

decl  = "\n".join(f"  reg [{w-1}:0] {n};" for n, w in ins)
wires = "\n".join(f"  wire [{w-1}:0] r_{n}, g_{n}, s_{n};" for n, w in outs)

# Array-shaped views for the RTL instance only; the netlists stay flat.
arr_decl, arr_glue = [], []
for n, w in ins:
    if n not in unpacked: continue
    c = unpacked[n]; ew = w // c
    arr_decl.append(f"  wire [{ew-1}:0] a_{n} [0:{c-1}];")
    for k in range(c):
        _kk = k if os.environ.get("ADJ_ELEM_ORDER","hi") == "lo" else (c-1-k)
        arr_glue.append(f"  assign a_{n}[{k}] = {n}[{(_kk+1)*ew-1}:{_kk*ew}];")
for n, w in outs:
    if n not in unpacked: continue
    c = unpacked[n]; ew = w // c
    arr_decl.append(f"  wire [{ew-1}:0] a_r_{n} [0:{c-1}];")
    _order = range(c-1, -1, -1) if os.environ.get("ADJ_ELEM_ORDER","hi") == "lo" \
             else range(0, c)
    arr_glue.append("  assign r_%s = {%s};" %
                    (n, ", ".join(f"a_r_{n}[{k}]" for k in _order)))
arrays = "\n".join(arr_decl + arr_glue)

conn  = ", ".join(f".{n}({n})" for n, _ in ins)
# The RTL sees the array views where a port is unpacked; the netlists never do.
rtl_conn = ", ".join(f".{n}(a_{n})" if n in unpacked else f".{n}({n})"
                     for n, _ in ins)
def bind(p): return ", ".join(f".{n}({p}_{n})" for n, _ in outs)
def bind_rtl():
    return ", ".join(f".{n}(a_r_{n})" if n in unpacked else f".{n}(r_{n})"
                     for n, _ in outs)
drive = "\n      ".join(rnd(n, w) for n, w in ins)
# Compare each netlist against the RTL, not against each other.  An X on the
# RTL side is not a divergence -- it is the reference declining to say.
gbad = " || ".join(f"((r_{n} === r_{n}) && (g_{n} !== r_{n}))" for n, _ in outs)
sbad = " || ".join(f"((r_{n} === r_{n}) && (s_{n} !== r_{n}))" for n, _ in outs)
# Name the first output that diverges, per side -- "they differ" is not a
# diagnosis, and with a dozen ports the count alone does not say where to look.
# Track the two sides SEPARATELY.  A single per-output flag is claimed by
# whichever side diverges first, so if slang breaks at cycle 0 the uhdm
# divergence is never printed and the run looks like "slang only" even when
# both are counted as differing.
seen  = "\n".join(f"  reg repg_{n}, reps_{n};" for n, _ in outs)
seeni = "\n    ".join(f"repg_{n} = 0; reps_{n} = 0;" for n, _ in outs)
report = "\n".join(
    f'      if (!repg_{n} && (r_{n} === r_{n}) && (g_{n} !== r_{n})) '
    f'begin repg_{n} = 1; $display("FIRST-UHDM %0d {n} rtl=%h uhdm=%h", i, '
    f'r_{n}, g_{n}); end\n'
    f'      if (!reps_{n} && (r_{n} === r_{n}) && (s_{n} !== r_{n})) '
    f'begin reps_{n} = 1; $display("FIRST-SLANG %0d {n} rtl=%h slang=%h", i, '
    f'r_{n}, s_{n}); end' for n, _ in outs)

ck = "".join((".clk_i(clk), " if "clk_i" in has_clk_rst else "",
               ".rst_ni(rst_ni), " if "rst_ni" in has_clk_rst else ""))
tb = f"""`timescale 1ns/1ps
module tb;
  reg clk = 0, rst_ni = 0;
{decl}
{wires}
{arrays}
  integer i, seed_r, g_err = 0, s_err = 0;
{seen}
  {TOP}      rtl ({ck}{rtl_conn}, {bind_rtl()});
  gold_{TOP} gold({ck}{conn}, {bind('g')});
  gate_{TOP} gate({ck}{conn}, {bind('s')});
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
