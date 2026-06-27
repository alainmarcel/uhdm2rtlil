# Regression guard: 3-level union/struct member reads of a function param
# (op.r.rd) inside a struct-returning function — the legacy inline path must
# resolve the base via input_mapping.  uhdm-only (Yosys Verilog frontend can't
# synthesize the struct-returning function); verified via Verilator co-sim.
# top: union_param_repro
# mode: uhdm-only

dut.sv
