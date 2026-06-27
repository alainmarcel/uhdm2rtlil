# rp32 r5p_mouse_soc_simple_top — the complete (self-contained) Mouse SoC:
# r5p_mouse core + internal memory ($readmemh mem_if.mem) + simple GPIO/UART.
# Hand-written (a SoC top instantiates a module, which import_design.py doesn't
# resolve).  mem_if.vh is only used under YOSYS_SLANG; the UHDM path uses a plain
# memory array + $readmemh.
# top: r5p_mouse_soc_simple_top
# mode: uhdm-only

../rp32/mouse/r5p_mouse.sv
../rp32/soc/r5p_mouse_soc_simple_top.sv
