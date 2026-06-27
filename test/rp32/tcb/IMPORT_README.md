# TCB (Tightly Coupled Bus) — imported dependency

`tcb_lite_pkg.sv` and `tcb_lite_if.sv` imported from jeras/TCB
(https://github.com/jeras/TCB, hdl/rtl/) — the bus package + SystemVerilog
interface that rp32's r5p_degu / r5p_lsu use for their instruction/data ports.
Only the lite package + interface are needed for the degu core (the lite_lib and
device files are for full SoCs).
