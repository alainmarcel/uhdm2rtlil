#!/usr/bin/env bash
# Cosim adjudication for the multi-level secure-FIFO ResetValues[k] fix.
# The read_uhdm-vs-read_slang SAT miter is SAT-HARD on the secure counter's
# sum-invariant (times out), so equivalence is checked by co-simulating the
# original RTL against the UHDM-synth netlist under 400 random cycles.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="$ROOT/test/pavona_tlul_equiv/rtl/prim"
YS="$ROOT/out/current/bin/yosys"
PLUG="$ROOT/build/uhdm2rtlil.so"
SL="$ROOT/build/third_party/Surelog/bin/surelog"
SRCS="$P/prim_util_pkg.sv $P/prim_count_pkg.sv $P/prim_secded_pkg.sv \
$P/prim_flop.sv $P/prim_count.sv $P/prim_fifo_sync_cnt.sv $P/prim_fifo_sync.sv wrap.sv"
cd "$HERE"
$SL -parse -sverilog -top fsyncwrap -I$P $SRCS > surelog.log 2>&1
$YS -q -m $PLUG -p "read_uhdm slpp_all/surelog.uhdm; hierarchy -top fsyncwrap; \
  proc; flatten; memory; opt; async2sync; pmuxtree; simplemap; dffunmap; \
  rename fsyncwrap dut_netlist; write_verilog -noattr dut_netlist.v" > yosys.log 2>&1
verilator --binary --timing -Wno-fatal -Wno-WIDTH -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE \
  -Wno-SELRANGE -I$P --top-module fcosim_tb $SRCS dut_netlist.v cosim_tb.sv \
  -o cosim >/dev/null 2>&1
./obj_dir/cosim | tee cosim.log | grep -qi NO_DIVERGENCE && echo "PASS: NO_DIVERGENCE" || { echo "FAIL: divergence"; grep -i "c=" cosim.log | head; exit 1; }
