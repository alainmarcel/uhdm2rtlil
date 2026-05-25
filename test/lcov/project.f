# Yosys `tests/various/lcov.v` is a formal-mode test (uses
# `read_verilog -formal` upstream): the always-block `assert (out1 ==
# 8'h42)` must be preserved as a `$check` cell so the `linecoverage`
# pass can compute which lines are exercised by the property's
# input cone.

# formal: 1
dut.sv
