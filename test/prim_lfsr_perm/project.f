# ibex prim_lfsr with the dummy-instr parameterization: StatePermEn with the
# 32x5 packed RndCnstLfsrPermDefault — repro for the permuted-state divergence.
# top: prim_lfsr_perm_wrap
# mode: uhdm-only
# surelog: -I../ibex/prim -I../ibex/rtl
# verilator: +incdir+../../ibex/prim +incdir+../../ibex/rtl --no-assert
# slang: --ignore-assertions -I../ibex/prim -I../ibex/rtl

../ibex/prim/prim_cipher_pkg.sv
../ibex/rtl/ibex_pkg.sv
../ibex/prim/prim_lfsr.sv
wrap.sv
