# Multi-file SystemVerilog project — imported from jeras/UHDM-tests
# (test_union.sv).  Exercises a packed union of complex packed
# structs (the RISC-V op32 instruction format with seven variants:
# R4, R, I, S, B, U, J) referenced from a separate package via
# `import riscv_isa_pkg::*` and accessed through field paths like
# `dec.r.rd`, `dec.i.imm_11_0`.

# top: test_union
# mode: uhdm-only

riscv_isa_pkg.sv
test_union.sv
