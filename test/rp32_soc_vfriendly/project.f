# Whole degu SoC — Verilator-friendly cosim.  Original RTL (test/rp32) + tests untouched.
# Only 4 files differ from the original (test/rp32_vfriendly): packed struct typedefs
# (riscv_isa_pkg, tcb_lite_pkg, tcb_lite_if) + decoder DAM as packed-2D — behaviourally
# identical, but lets Verilator fold the struct parameters and build the whole SoC.
# top: r5p_degu_soc_top
# surelog: -top r5p_degu_soc_top
# verilator: -DTOOL_VERILATOR -Wno-BLKANDNBLK -Wno-UNPACKED -Wno-WIDTHEXPAND -Wno-ENUMVALUE -Wno-WIDTHTRUNC -Wno-CASEINCOMPLETE
../rp32_vfriendly/tcb/tcb_lite_pkg.sv
../rp32_vfriendly/tcb/tcb_lite_if.sv
../rp32/tcb/lite_lib/tcb_lite_lib_passthrough.sv
../rp32/tcb/lite_lib/tcb_lite_lib_logsize2byteena.sv
../rp32/tcb/lite_lib/tcb_lite_lib_arbiter.sv
../rp32/tcb/lite_lib/tcb_lite_lib_multiplexer.sv
../rp32_vfriendly/tcb/lite_lib/tcb_lite_lib_decoder.sv
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
../rp32_vfriendly/riscv/riscv_isa_pkg.sv
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
../rp32/soc/r5p_soc_memory__gowin_inference.sv
../rp32/soc/r5p_degu_soc_top.sv
