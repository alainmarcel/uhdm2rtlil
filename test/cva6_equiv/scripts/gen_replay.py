#!/usr/bin/env python3
"""Generate + run an iverilog gold-vs-gate replay of the miter counterexample.

Usage: gen_replay.py <module> [extra_random_cycles]

Reads work_<mod>/miter.log's last cex, dumps goldr/gater netlists (setundef'd),
write_verilog's them, builds a TB that applies the cex input sequence
cycle-by-cycle to BOTH netlists and prints the first differing output.
"""
import re, sys, os, subprocess, json

mod = sys.argv[1]
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = f"{HERE}/work/{mod}"
# Paths are derived from this file's location so the script works from any
# checkout; override with UHDM2RTLIL_ROOT if the build lives elsewhere.
_ROOT  = os.environ.get("UHDM2RTLIL_ROOT", os.path.abspath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..")))
YOSYS  = os.path.join(_ROOT, "out", "current", "bin", "yosys")
PLUGIN = os.path.join(_ROOT, "build", "uhdm2rtlil.so")
FLIST = os.environ.get("CVA6_FLIST", f"{HERE}/work/cva6.f")
TOP = f"{mod}_equiv"
os.chdir(WORK)

# 1. cex inputs
txt = open('miter.log').read()
tail = txt[txt.rfind('model found: FAIL'):]
rows = re.findall(r'^\s+(\d+) \\(in_\S+)\s+\S+\s+\S+\s+([01xz]+)\s*$', tail, re.M)
by_t = {}
for t, name, b in rows:
    by_t.setdefault(int(t), {})[name[3:]] = b
assert by_t, "no cex rows found"

# 2. netlists
ys = f"""read_uhdm slpp_all/surelog.uhdm
hierarchy -check -top {TOP}
flatten; proc; opt -fast; setundef -undriven -zero
write_rtlil goldr.il
design -reset
read_slang -f {FLIST} ../wrapper_{mod}.sv --top {TOP}
hierarchy -check -top {TOP}
flatten; proc; opt -fast; setundef -undriven -zero
write_rtlil gater.il
"""
open('rep.ys', 'w').write(ys)
subprocess.run([YOSYS, "-q", "-m", PLUGIN, "rep.ys"], check=True)
subprocess.run([YOSYS, "-q", "-p", "read_rtlil goldr.il; write_verilog -noattr goldv.v"], check=True)
subprocess.run([YOSYS, "-q", "-p",
                "read_rtlil gater.il; simplemap t:$bwmux; write_verilog -noattr gatev.v"], check=True)

# 3. port lists from goldv.v
gv = open('goldv.v').read()
mtxt = gv[gv.find(f"module {TOP}"):]
mtxt = mtxt[:mtxt.find("endmodule")]
ins, outs = [], []
fcut = mtxt.find('function')
if fcut > 0: mtxt = mtxt[:fcut]
for dirn, rng, name in re.findall(r'^  (input|output)\s+(\[\d+:\d+\]\s+)?(\w+);', mtxt, re.M):
    w = 1
    if rng:
        hi, lo = map(int, re.findall(r'\d+', rng))
        w = hi - lo + 1
    if name in ('clk_i', 'rst_ni'):
        continue
    (ins if dirn == 'input' else outs).append((name, w))

decl = "\n".join(f"  reg [{w-1}:0] {n};" for n, w in ins)
conn = ", ".join(f".{n}({n})" for n, w in ins)
gout = ", ".join(f".{n}(g_{n})" for n, w in outs)
sout = ", ".join(f".{n}(s_{n})" for n, w in outs)
owires = "\n".join(f"  wire [{w-1}:0] g_{n}, s_{n};" for n, w in outs)
cmp = " || ".join(f"(g_{n} !== s_{n})" for n, w in outs)
percy = " ".join(f"{n}=%h/%h" for n, w in outs)
showv = ", ".join(f"g_{n}, s_{n}" for n, w in outs)
steps = ""
for t in sorted(by_t):
    d = by_t[t]
    sets = "".join(f"      {n} = {w}'b{d[n]};\n" for n, w in ins if n in d)
    steps += (f"    begin\n{sets}      rst_ni = {d.get('rst_ni','1')};\n      #1;\n"
              f"      if ({cmp}) $display(\"t={t} DIFF {percy}\", {showv});\n"
              f"      else $display(\"t={t} ok\");\n      clk=1; #1; clk=0; #1;\n    end\n")
tb = f"""`timescale 1ns/1ps
module tb;
  reg clk=0, rst_ni=0;
{decl}
{owires}
  {TOP} gold(.clk_i(clk), .rst_ni(rst_ni), {conn}, {gout});
  gate_{TOP} gate(.clk_i(clk), .rst_ni(rst_ni), {conn}, {sout});
  initial begin
    rst_ni=0; clk=0; #1; clk=1; #1; clk=0; rst_ni=1; #1;
{steps}
    $finish;
  end
endmodule
"""
open('tb.v', 'w').write(tb)
subprocess.run(f"sed 's/^module {TOP}/module gate_{TOP}/' gatev.v > gatev_r.v", shell=True, check=True)
r = subprocess.run(["iverilog", "-g2012", "-o", "tbx", "tb.v", "goldv.v", "gatev_r.v"],
                   capture_output=True, text=True)
if r.returncode:
    print(r.stderr[:2000]); sys.exit(1)
r = subprocess.run(["./tbx"], capture_output=True, text=True, timeout=120)
for line in r.stdout.splitlines():
    if 'DIFF' in line:
        print(line[:600])
        break
    print(line[:120])
