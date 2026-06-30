# rp32 r5p_degu_soc_top — the complete Degu SoC: the r5p_degu core + the full TCB
# lite bus fabric (decoder/demux/arbiter/register) + GPIO/UART devices + SoC
# memory.  File list from jeras/rp32 sim/sources-degu.mk.  Hand-written.
# top: r5p_degu_soc_top
# mode: uhdm-only
# surelog: -top r5p_degu_soc_top

# --- TCB bus (jeras/TCB, imported into test/rp32/tcb/) ---
../rp32/tcb/tcb_lite_pkg.sv
../rp32/tcb/tcb_lite_if.sv
../rp32/tcb/lite_lib/tcb_lite_lib_passthrough.sv
../rp32/tcb/lite_lib/tcb_lite_lib_logsize2byteena.sv
../rp32/tcb/lite_lib/tcb_lite_lib_arbiter.sv
../rp32/tcb/lite_lib/tcb_lite_lib_multiplexer.sv
../rp32/tcb/lite_lib/tcb_lite_lib_decoder.sv
../rp32/tcb/lite_lib/tcb_lite_lib_demultiplexer.sv
../rp32/tcb/lite_lib/tcb_lite_lib_register_request.sv
../rp32/tcb/lite_lib/tcb_lite_lib_error.sv
../rp32/tcb/dev/gpio/tcb_dev_gpio_cdc__generic.sv
../rp32/tcb/dev/gpio/tcb_dev_gpio.sv
../rp32/tcb/lite_dev/gpio/tcb_lite_dev_gpio.sv
../rp32/tcb/dev/uart/tcb_dev_uart_ser.sv
../rp32/tcb/dev/uart/tcb_dev_uart_des.sv
../rp32/tcb/dev/uart/tcb_dev_uart_fifo.sv
../rp32/tcb/dev/uart/tcb_dev_uart.sv
../rp32/tcb/lite_dev/uart/tcb_lite_dev_uart.sv

# --- R5P core ---
../rp32/riscv/riscv_isa_pkg.sv
../rp32/riscv/riscv_priv_pkg.sv
../rp32/riscv/riscv_isa_i_pkg.sv
../rp32/riscv/riscv_isa_c_pkg.sv
../rp32/riscv/rv32_csr_pkg.sv
../rp32/riscv/rv64_csr_pkg.sv
../rp32/core/r5p_gpr_2r1w.sv
../rp32/degu/r5p_pkg.sv
../rp32/degu/r5p_bru.sv
../rp32/degu/r5p_alu.sv
../rp32/degu/r5p_mdu.sv
../rp32/degu/r5p_lsu.sv
../rp32/degu/r5p_wbu.sv
../rp32/degu/r5p_degu_pkg.sv
../rp32/degu/r5p_degu.sv

# --- SoC ---
../rp32/soc/r5p_soc_memory__gowin_inference.sv
../rp32/soc/r5p_degu_soc_top.sv
