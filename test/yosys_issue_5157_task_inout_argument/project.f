# top: dut
# Verilator 5.048 hits an internal error ("V3DfgSynthesize.cpp:358: Non-ReadOnly
# reference") on the task call with an inout actual inside always_comb; its DFG
# pass is the culprit, not the RTL, so disable it for the co-sim build.
# verilator: -fno-dfg
dut.sv
