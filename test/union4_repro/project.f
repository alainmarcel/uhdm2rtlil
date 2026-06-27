# Regression guard: 4-level packed union/struct member read of a function param
# (op.r.opcode.opc) — union -> struct -> struct -> field chain — in a struct-
# returning function (legacy inline path).  uhdm-only; verified via co-sim.
# top: union4_repro
# mode: uhdm-only

dut.sv
