# Minimal regression guard for generate/struct-returning-function support.
# The Yosys Verilog frontend can't synthesize the struct-returning function,
# so this is verified uhdm-only via the Verilator co-sim (UHDM netlist vs RTL).
# top: func_struct_repro
# mode: uhdm-only

dut.sv
