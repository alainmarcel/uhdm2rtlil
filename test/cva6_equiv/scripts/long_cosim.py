#!/usr/bin/env python3
"""Long random co-simulation of the UHDM netlist vs the read_slang netlist.

BMC only proves a module to a bounded depth; for a module whose SAT blows up
(cva6_ptw) this covers thousands of cycles instead.  Regenerates both netlists,
builds a TB that drives every input with random data each cycle and compares
every output, and reports the first mismatching cycle plus an activity check so
a vacuous all-quiet pass can't masquerade as a result.

Usage: long_cosim.py <module> [cycles] [seed]
"""
import re, sys, os, subprocess

mod    = sys.argv[1]
CYCLES = int(sys.argv[2]) if len(sys.argv) > 2 else 20000
SEED   = int(sys.argv[3]) if len(sys.argv) > 3 else 1
HERE   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK   = f"{HERE}/work/{mod}"
# Paths are derived from this file's location so the script works from any
# checkout; override with UHDM2RTLIL_ROOT if the build lives elsewhere.
_ROOT  = os.environ.get("UHDM2RTLIL_ROOT", os.path.abspath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..")))
YOSYS  = os.path.join(_ROOT, "out", "current", "bin", "yosys")
PLUGIN = os.path.join(_ROOT, "build", "uhdm2rtlil.so")
FLIST  = os.environ.get("CVA6_FLIST", f"{HERE}/work/cva6.f")
TOP    = f"{mod}_equiv"
os.chdir(WORK)

if not (os.path.exists("goldv.v") and os.path.exists("gatev.v")):
    open('cos.ys','w').write(f"""read_uhdm slpp_all/surelog.uhdm
hierarchy -check -top {TOP}
flatten; proc; opt -fast; setundef -undriven -zero
write_rtlil goldr.il
design -reset
read_slang -f {FLIST} ../wrapper_{mod}.sv --top {TOP}
hierarchy -check -top {TOP}
flatten; proc; opt -fast; setundef -undriven -zero
write_rtlil gater.il
""")
    subprocess.run([YOSYS, "-q", "-m", PLUGIN, "cos.ys"], check=True)
    subprocess.run([YOSYS, "-q", "-p", "read_rtlil goldr.il; write_verilog -noattr goldv.v"], check=True)
    subprocess.run([YOSYS, "-q", "-p",
                    "read_rtlil gater.il; simplemap t:$bwmux; write_verilog -noattr gatev.v"], check=True)

gv = open('goldv.v').read()
mtxt = gv[gv.find(f"module {TOP}"):]
mtxt = mtxt[:mtxt.find("endmodule")]
fcut = mtxt.find('function')
if fcut > 0: mtxt = mtxt[:fcut]
ins, outs = [], []
for dirn, rng, name in re.findall(r'^  (input|output)\s+(\[\d+:\d+\]\s+)?(\w+);', mtxt, re.M):
    w = 1
    if rng:
        hi, lo = map(int, re.findall(r'\d+', rng))
        w = hi - lo + 1
    if name in ('clk_i', 'rst_ni'):
        continue
    (ins if dirn == 'input' else outs).append((name, w))

def rnd(n, w):
    # $random gives 32 bits; stitch enough of them for wide ports
    return " ".join(f"{n}[{min(b+31,w-1)}:{b}] <= $random;" for b in range(0, w, 32))

decl  = "\n".join(f"  reg [{w-1}:0] {n};" for n, w in ins)
owire = "\n".join(f"  wire [{w-1}:0] g_{n}, s_{n};" for n, w in outs)
conn  = ", ".join(f".{n}({n})" for n, _ in ins)
gout  = ", ".join(f".{n}(g_{n})" for n, _ in outs)
sout  = ", ".join(f".{n}(s_{n})" for n, _ in outs)
cmp_  = " || ".join(f"(g_{n} !== s_{n})" for n, _ in outs)
show  = ", ".join(f'"{n}", g_{n}, s_{n}' for n, _ in outs)
fmt   = " ".join("%s=%h/%h" for _ in outs)
drive = "\n      ".join(rnd(n, w) for n, w in ins)
acc   = "\n".join(f"  reg [{w-1}:0] acc_{n};" for n, w in outs)
accup = "\n      ".join(f"acc_{n} <= acc_{n} | g_{n};" for n, _ in outs)
accin = "\n    ".join(f"acc_{n} = 0;" for n, _ in outs)
accrep= " + ".join(f"$countones(acc_{n})" for n, _ in outs)

tb = f"""`timescale 1ns/1ps
module tb;
  reg clk = 0, rst_ni = 0;
{decl}
{owire}
{acc}
  integer i, bad = 0;\n  integer seed_r;
  {TOP} gold(.clk_i(clk), .rst_ni(rst_ni), {conn}, {gout});
  gate_{TOP} gate(.clk_i(clk), .rst_ni(rst_ni), {conn}, {sout});
  initial begin
    seed_r = {SEED}; i = $random(seed_r);
    {accin}
    rst_ni = 0;
    for (i = 0; i < 4; i = i + 1) begin clk=1; #1; clk=0; #1; end
    rst_ni = 1;
    for (i = 0; i < {CYCLES}; i = i + 1) begin
      {drive}
      // hold reset low occasionally to exercise the reset path
      if (i % 977 == 0) rst_ni <= 0; else rst_ni <= 1;
      #1;
      if ({cmp_}) begin
        bad = bad + 1;
        if (bad <= 3)
          $display("MISMATCH cycle=%0d {fmt}", i, {show});
      end
      {accup}
      clk = 1; #1; clk = 0; #1;
    end
    $display("CYCLES=%0d MISMATCHES=%0d ACTIVITY_BITS=%0d", {CYCLES}, bad, {accrep});
    $finish;
  end
endmodule
"""
open('tb_long.v','w').write(tb)
subprocess.run(f"sed 's/^module {TOP}/module gate_{TOP}/' gatev.v > gatev_r.v", shell=True, check=True)
r = subprocess.run(["iverilog","-g2012","-o","tb_long","tb_long.v","goldv.v","gatev_r.v"],
                   capture_output=True, text=True)
if r.returncode:
    print(r.stderr[:1500]); sys.exit(1)
r = subprocess.run(["./tb_long"], capture_output=True, text=True, timeout=5400)
print(r.stdout[-2000:])
