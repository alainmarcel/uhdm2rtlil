#!/usr/bin/env python3
"""Verilator co-sim adjudication for a pavona (hardened-Ibex) module.

The pavona sweep's formal column mitres read_uhdm vs read_slang; it says the two
frontends agree or differ but cannot say whether they match the *behavioural
RTL*.  This runs three instances under identical random stimulus:

    the behavioural RTL   (the reference — the same .sv, param-baked)
    the read_uhdm netlist (gold)
    the read_slang netlist (gate)

and reports how many cycles each netlist diverges from the RTL.  It reuses the
per-module elaboration already produced by run_pavona_equiv.sh
(work/<mod>/slpp_all/surelog.uhdm) and the same source list + parameter set.

Pavona configs use enum-typed parameters (RV32M=ibex_pkg::RV32MSingleCycle) that
Verilator's `-G` cannot parse, so the parameter values are BAKED into the RTL
instantiation inside the testbench (enum references are legal SV there) instead
of being passed on the command line.

Usage: adjudicate.py <module> [cycles] [seed]
"""
import re, sys, os, subprocess, glob

mod    = sys.argv[1]
CYCLES = int(sys.argv[2]) if len(sys.argv) > 2 else 300
SEED   = int(sys.argv[3]) if len(sys.argv) > 3 else 1
HERE   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))   # pavona_equiv
_ROOT  = os.environ.get("UHDM2RTLIL_ROOT", os.path.abspath(
    os.path.join(HERE, "..", "..")))
YOSYS  = os.path.join(_ROOT, "out", "current", "bin", "yosys")
PLUGIN = os.path.join(_ROOT, "build", "uhdm2rtlil.so")
IBEX   = f"{HERE}/rtl/ibex"
PRIM   = f"{HERE}/rtl/prim"
WORK   = f"{HERE}/work/{mod}"
FLAT   = f"{HERE}/wrappers/flat_{mod}.sv"
PFILE  = f"{HERE}/wrappers/params_{mod}.txt"
has_flat = os.path.exists(FLAT)
TOP    = f"{mod}_flat" if has_flat else mod

if not os.path.isdir(WORK) or not os.path.exists(f"{WORK}/slpp_all/surelog.uhdm"):
    print(f"{mod}: NO_RUN (no elaboration; run run_pavona_equiv.sh first)")
    sys.exit(2)
os.chdir(WORK)

def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)

# ---------------------------------------------------------------- source list
def srcs():
    out = [f"{IBEX}/ibex_pkg.sv"]
    for p in ("prim_pkg", "prim_util_pkg", "prim_count_pkg", "prim_mubi_pkg",
              "prim_secded_pkg", "prim_cipher_pkg", "prim_ram_1p_pkg"):
        f = f"{PRIM}/{p}.sv"
        if os.path.exists(f): out.append(f)
    for f in sorted(glob.glob(f"{PRIM}/prim_*.sv")):
        if not re.search(r"_pkg\.sv$|_macros\.sv$", f): out.append(f)
    for f in sorted(glob.glob(f"{IBEX}/ibex_*.sv")):
        if not re.search(r"_pkg\.sv$|tracer|top_tracing", f): out.append(f)
    return out

FLIST = f"{WORK}/cosim.f"
with open(FLIST, "w") as fh:
    fh.write(f"+incdir+{PRIM}\n+incdir+{IBEX}\n")
    for f in srcs():
        fh.write(f + "\n")

# ---------------------------------------------------------------- parameters
# (name, slang -G value, RTL-instantiation value).  For pavona the -G value and
# the SV value are identical (numeric literals or enum refs like
# ibex_pkg::RV32MSingleCycle); the latter is baked into the RTL instance.
gparams, bake = [], []
if os.path.exists(PFILE):
    for line in open(PFILE):
        parts = line.split()
        if len(parts) >= 3 and not parts[0].startswith("#"):
            name, gval = parts[0], parts[2]
            gparams.append(f"-G{name}={gval}")
            bake.append(f".{name}({gval})")
bake_str = f" #({', '.join(bake)})" if bake else ""

# ---------------------------------------------------------------- netlists
slang_wrap = FLAT if has_flat else ""
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
read_slang --ignore-assertions -DSYNTHESIS {' '.join(gparams)} -I {PRIM} -I {IBEX} -f {FLIST} {slang_wrap} --top {TOP}
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
has_clk_rst = set()
CLK_NAMES  = ("clk_i", "clk", "clock", "clock_i")
RSTL_NAMES = ("rst_ni", "rst_n", "resetn", "rstn", "rst_l")
RSTH_NAMES = ("rst", "rst_i", "reset", "reset_i")
for dirn, rng, name in re.findall(r"^  (input|output)\s+(\[\d+:\d+\]\s+)?(\w+);",
                                  mtxt, re.M):
    w = 1
    if rng:
        hi, lo = map(int, re.findall(r"\d+", rng))
        w = hi - lo + 1
    if dirn == "input" and name in CLK_NAMES:  has_clk_rst.add(("clk", name));  continue
    if dirn == "input" and name in RSTL_NAMES: has_clk_rst.add(("rstl", name)); continue
    if dirn == "input" and name in RSTH_NAMES: has_clk_rst.add(("rsth", name)); continue
    (ins if dirn == "input" else outs).append((name, w))
if not outs:
    print(f"{mod}: no outputs to compare"); sys.exit(2)

def rnd(n, w):
    return " ".join(f"{n}[{min(b+31, w-1)}:{b}] <= $random;" for b in range(0, w, 32))

# Unpacked-array ports.  A flat-shim module already flattens them, so nothing to
# do.  A whole-core module (ibex_core/top/lockstep) has NO shim and still
# declares e.g. `ic_tag_rdata_i [IC_NUM_WAYS]` as an array, while the netlists
# flatten it to one wide vector — Verilator rejects connecting the flat wire to
# the array port.  read_uhdm and read_slang flatten it the SAME way here (the
# formal miter PROVES these modules, so the two orders agree), so gold and gate
# share the flat vector; only the RTL instance needs an array-shaped view
# (element 0 at the LSBs, the read_uhdm convention).
unpacked = {}     # port name -> element count
if not has_flat:
    syms = {}
    if os.path.exists(PFILE):
        for line in open(PFILE):
            p = line.split()
            if len(p) >= 2 and p[1].lstrip('-').isdigit():
                syms[p[0]] = int(p[1])
    for nm, val in re.findall(
            r"parameter\s+int(?:\s+unsigned)?\s+(\w+)\s*=\s*(\d+)\b",
            open(f"{IBEX}/ibex_pkg.sv").read()):
        syms.setdefault(nm, int(val))
    def _resolve(expr):
        try:
            return int(eval(expr, {"__builtins__": {}}, dict(syms)))
        except Exception:
            return None
    hdr = ""
    for f in srcs():
        t = open(f).read()
        m = re.search(rf"\bmodule\s+{re.escape(mod)}\b.*?\)\s*;", t, re.S)
        if m:
            hdr = m.group(0); break
    allw = {n: w for n, w in ins + outs}
    for nm, dim in re.findall(
            r"\b(\w+)\s*\[([^\]:]+)\]\s*(?:,|\n)", hdr):
        if nm in allw:
            c = _resolve(dim)
            if c and c > 1 and allw[nm] % c == 0:
                unpacked[nm] = c

arr_decl, arr_glue = [], []
for n, w in ins:
    if n not in unpacked:
        continue
    c = unpacked[n]; ew = w // c
    arr_decl.append(f"  wire [{ew-1}:0] a_{n} [0:{c-1}];")
    for k in range(c):
        arr_glue.append(f"  assign a_{n}[{k}] = {n}[{(k+1)*ew-1}:{k*ew}];")
for n, w in outs:
    if n not in unpacked:
        continue
    c = unpacked[n]; ew = w // c
    arr_decl.append(f"  wire [{ew-1}:0] a_r_{n} [0:{c-1}];")
    arr_glue.append("  assign r_%s = {%s};" %
                    (n, ", ".join(f"a_r_{n}[{k}]" for k in range(c-1, -1, -1))))
arrays = "\n".join(arr_decl + arr_glue)

decl  = "\n".join(f"  reg [{w-1}:0] {n};" for n, w in ins)
wires = "\n".join(f"  wire [{w-1}:0] r_{n}, g_{n}, s_{n};" for n, w in outs)
conn  = ", ".join(f".{n}({n})" for n, _ in ins)                       # gold/gate ins
rtl_conn = ", ".join(f".{n}(a_{n})" if n in unpacked else f".{n}({n})"
                     for n, _ in ins)
def bind(p): return ", ".join(f".{n}({p}_{n})" for n, _ in outs)
def bind_rtl():
    return ", ".join(f".{n}(a_r_{n})" if n in unpacked else f".{n}(r_{n})"
                     for n, _ in outs)
# Optional per-module input constraint spliced in AFTER the random drive each
# cycle: legalises `unique case (1'b1)` one-hot select groups the free random
# stimulus otherwise violates (e.g. ibex_alu's `multdiv_sel_i` vs the SHxADD
# adder-shift selects — illegal multi-hot makes behavioural priority and the
# synthesised netlists diverge on both frontends, a shared non-bug).  Without a
# file the stimulus is unconstrained (previous behaviour).
constr = ""
_cf = f"{HERE}/wrappers/cosim_constr_{mod}.sv"
if os.path.exists(_cf):
    constr = "\n      " + open(_cf).read().strip()
drive = "\n      ".join(rnd(n, w) for n, w in ins) + constr
gbad = " || ".join(f"((r_{n} === r_{n}) && (g_{n} !== r_{n}))" for n, _ in outs)
sbad = " || ".join(f"((r_{n} === r_{n}) && (s_{n} !== r_{n}))" for n, _ in outs)
seen  = "\n".join(f"  reg repg_{n}, reps_{n};" for n, _ in outs)
seeni = "\n    ".join(f"repg_{n} = 0; reps_{n} = 0;" for n, _ in outs)
def _report_line(n):
    return (
        f'      if (!repg_{n} && (r_{n} === r_{n}) && (g_{n} !== r_{n})) '
        f'begin repg_{n} = 1; $display("FIRST-UHDM %0d {n} rtl=%h uhdm=%h", i, r_{n}, g_{n}); end\n'
        f'      if (!reps_{n} && (r_{n} === r_{n}) && (s_{n} !== r_{n})) '
        f'begin reps_{n} = 1; $display("FIRST-SLANG %0d {n} rtl=%h slang=%h", i, r_{n}, s_{n}); end')
report = "\n".join(_report_line(n) for n, _ in outs)

ck = "".join(
    f".{name}(clk), " if kind == "clk" else
    f".{name}(rst_ni), " if kind == "rstl" else
    f".{name}(~rst_ni), "
    for kind, name in sorted(has_clk_rst))
tb = f"""`timescale 1ns/1ps
module tb;
  reg clk = 0, rst_ni = 0;
{decl}
{wires}
{arrays}
  integer i, seed_r, g_err = 0, s_err = 0;
{seen}
  {TOP}{bake_str} rtl ({ck}{rtl_conn}, {bind_rtl()});
  gold_{TOP} gold({ck}{conn}, {bind('g')});
  gate_{TOP} gate({ck}{conn}, {bind('s')});
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
rtl_wrap = [FLAT] if has_flat else []
def run_verilator():
    # -DSYNTHESIS: the netlists were elaborated with it (surelog + read_slang),
    # so the behavioural RTL must match — it drops the `ifndef SYNTHESIS
    # translate_off debug blocks, some of which read UPWARD hierarchical paths
    # (ibex_controller's `$display(... u_ibex_core.hart_id_i ...)`) that only
    # resolve inside the full core hierarchy and otherwise fail the whole-core
    # Verilator build ("Can't find scope 'u_ibex_core'").
    r = sh(["verilator", "--binary", "-j", "0", "-Wno-lint", "-Wno-style",
            "-Wno-fatal", "--timing", "--no-assert", "-DSYNTHESIS", "-o", "adjsim",
            "-f", FLIST, f"+incdir+{HERE}/wrappers"] + rtl_wrap +
           ["adj_gold.v", "adj_gate.v", "adj_tb.sv", "--top-module", "tb"])
    if r.returncode:
        return None, r.stderr[-600:]
    r = sh(["./obj_dir/adjsim"])
    return r.stdout, r.stderr[-600:]

def run_iverilog():
    inc = [f"-I{PRIM}", f"-I{IBEX}", f"-I{HERE}/wrappers"]
    src = [l.strip() for l in open(FLIST)
           if l.strip() and not l.strip().startswith(("+", "-"))]
    r = sh(["iverilog", "-g2012", "-DSYNTHESIS", "-o", "adjsim.vvp", "-s", "tb"] + inc + src +
           rtl_wrap + ["adj_gold.v", "adj_gate.v", "adj_tb.sv"])
    if r.returncode:
        return None, r.stderr[-600:]
    r = sh(["vvp", "adjsim.vvp"])
    return r.stdout, r.stderr[-600:]

if os.environ.get("ADJ_TOOL") == "iverilog":
    out, err = run_iverilog(); tool = "iverilog"
else:
    out, err = run_verilator(); tool = "verilator"
if out is None or "ADJUDICATION" not in (out or ""):
    print(f"{mod}: verilator could not adjudicate; falling back to iverilog")
    if err: print("   " + (err.strip().splitlines() or [""])[-1][:150])
    out, err = run_iverilog(); tool = "iverilog"

if out is None or "ADJUDICATION" not in (out or ""):
    print(f"{mod}: NO VERDICT (both simulators failed)")
    if err: print("   " + (err.strip().splitlines() or [""])[-1][:150])
    sys.exit(1)

for line in out.splitlines():
    if line.startswith(("ADJUDICATION", "VERDICT", "FIRST")):
        print(f"{mod} [{tool}] {line}")
