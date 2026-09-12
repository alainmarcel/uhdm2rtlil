# rp32 r5p_hamster — flat RISC-V core (like r5p_mouse; no TCB interface / no
# submodules).  Hand-written.  CSR disabled (ENABLE_CSR undefined; the
# riscv_csr_pkg / r5p_pkg imports are commented out — the generator's
# riscv_csr_pkg "dep" was a false match on the comment).
# NOTE: r5p_hamster is v0.5 WIP upstream (jeras/rp32 README) — it references
# nested decode-struct members (`dec_t.alu/.bru/.uiu`, `gpr_ena_t.adr`) that are
# defined NOWHERE upstream, and there is no sim/sources-hamster.mk (only degu/
# mouse are buildable).  read_uhdm imports it (missing members -> X); read_slang
# rejects it ("upstream RTL incomplete").  uhdm-only import test only.
# top: r5p_hamster
# mode: uhdm-only
# surelog: -top r5p_hamster

../rp32/riscv/riscv_isa_pkg.sv
../rp32/riscv/riscv_priv_pkg.sv
../rp32/riscv/riscv_isa_i_pkg.sv
../rp32/riscv/riscv_isa_c_pkg.sv
../rp32/core/r5p_gpr_1r1w.sv
../rp32/hamster/r5p_hamster.sv
