# rp32 r5p_degu — hierarchical RISC-V core (needs the external TCB submodule's
# bus interface + several r5p submodules).  Hand-written.  CSR is disabled
# (ENABLE_CSR not defined; the `import riscv_csr_pkg` in the source is commented
# out — the generator's riscv_csr_pkg "dep" was a false match on that comment).
# top: r5p_degu
# mode: uhdm-only

../rp32/tcb/tcb_lite_pkg.sv
../rp32/tcb/tcb_lite_if.sv
../rp32/riscv/riscv_isa_pkg.sv
../rp32/riscv/riscv_priv_pkg.sv
../rp32/riscv/riscv_isa_i_pkg.sv
../rp32/riscv/riscv_isa_c_pkg.sv
../rp32/riscv/rv32_csr_pkg.sv
../rp32/riscv/rv64_csr_pkg.sv
../rp32/degu/r5p_pkg.sv
../rp32/degu/r5p_degu_pkg.sv
../rp32/core/r5p_gpr_2r1w.sv
../rp32/degu/r5p_bru.sv
../rp32/degu/r5p_alu.sv
../rp32/degu/r5p_mdu.sv
../rp32/degu/r5p_lsu.sv
../rp32/degu/r5p_wbu.sv
../rp32/degu/r5p_degu.sv
