# Multi-file SystemVerilog project: half-/full-adder built around an
# interface that exports a function (`summ2`).  Reduced reproducer
# from a synlig-style report: the UHDM frontend aborted with
# "Encountered unhandled object 'summ2' of type 'method_func_call'"
# because `obj.method(...)` calls had no handler in expression.cpp.
#
# top: adders
# mode: uhdm-only

./intfce.sv
./ha_mod.sv
./adders.sv
