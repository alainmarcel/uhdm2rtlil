# The 54 "read_slang netlist diverges" rows, re-measured on 2026-11-10

[slang_unsupported.md](slang_unsupported.md#netlist-diverges-from-the-rtl-under-verilator-read_uhdms-does-not----54)
listed 54 sweep rows on 2026-11-09 whose `read_slang` netlist diverged from the RTL
under Verilator while `read_uhdm`'s tracked it.  Martin Povišer (povik) triaged a sample
of ten on [YosysHQ/yosys#6464](https://github.com/YosysHQ/yosys/issues/6464): five were
Verilator misreading `x[$signed(b) +: W]` in the `write_verilog` output
([verilator#8657](https://github.com/verilator/verilator/issues/8657)), one a slang bug
([MikePopoloski/slang#2106](https://github.com/MikePopoloski/slang/pull/2106)), and four
he could not reproduce.  Both findings were carried into this tree on 2026-11-10 --
#1542 lowers signed-amount `$shift`/`$shiftx` cells to logic before `write_verilog`
in every co-sim script, #1541 applies the PR 2106 patch to the vendored slang -- and every
one of the 54 rows was then re-run **individually, locally, on `main`** (03e4a6ec7),
on three toolchains:

| column | toolchain |
|---|---|
| **pinned + patches** | the tree's own build: Yosys v0.70 (+ proc_dlatch memo patch), sv-elab 2026-10-13, slang v12.0 + PR 2106 patch, Surelog pin, Verilator 5.048; the co-sim harness with the #1542 lowering |
| **newest sv-elab + slang** | the same Yosys v0.70 core with only the two frontend submodules moved to what upstream yosys `main` pins: sv-elab `2cfcfbe38` (release 2026-11-09) and slang `42710c788` (v12.1), + PR 2106 patch.  Same kernel ABI, so the read_uhdm plugin and every harness step are unchanged -- this is the pin bump candidate |
| **upstream yosys main** | YosysHQ/yosys `0865903d9` (0.70+370, 2026-11-10) built as-is with `-DYOSYS_ENABLE_SLANG=ON` (+ PR 2106 patch): only the `read_slang` netlist is produced with it (the harness's `YOSYS` / `YOSYS_FRONTEND` overrides), the testbench and the read_uhdm side stay on the pin.  Run only where the newest sv-elab column still diverged |

Each cell is the sweep's `slang co-sim vs RTL` verdict (`N div` = diverging cycles of 301,
`uhdm ✅` = read_uhdm's netlist tracked the RTL in the same run, `shared` = both netlists
diverged identically).  The **class** column is the conclusion per row:

| class | rows | meaning |
|---|---|---|
| closed | 15 | closed by the two patches (Verilator #8657 lowering + slang PR 2106) |
| chisel-mem-const | 15 | read of a never-written queue-memory entry before reset: yosys folds the always-constant data bit, Verilator reads 0 (X by LRM); adjudicated, not a read_slang defect |
| shared | 12 | both netlists diverge identically from the RTL after the signed-shift lowering: the Verilator #8657 class on both sides, not a read_slang defect |
| upstream-repro | 6 | still diverges with the newest sv-elab/slang AND upstream yosys main: a candidate read_slang defect to report with the repro |
| fixed-upstream | 3 | diverges on our pin, PASSES with sv-elab 2026-11-09 / slang v12.1: version drift, closes with the pin bump |
| pending | 2 |  |
| single | 1 | one diverging cycle, no recorded cause: listed as adjudicated (lone-cycle rule) |

Recipes: a sweep row is `cd test && python3 core_sweep.py <family> --filter '^<module>$'`
(external IP families need the manifest's repositories under `$EXT_IP_ROOT`); the
newest-sv-elab column is the same command in a checkout whose `out/current` points at a
Yosys built with those two submodule revisions; the upstream column re-reads the module's
`slang.ys` with the upstream binary and feeds the result to `test/netlist_cosim.py` with
`YOSYS=<upstream yosys>` (ext rows) or runs `test_sim_equivalence.py --frontend slang`
with `YOSYS_FRONTEND=<upstream yosys>` (sv-synth rows).

## Per-row results

| # | family | module | 11-09 nightly | pinned + Verilator/slang patches | newest sv-elab 11-09 + slang 12.1 (v0.70 core) | upstream yosys main | class |
|---|---|---|---|---|---|---|---|
| 1 | aes | `aes_prng_masking` | ❌ 300 div | ✅ PASS | n/a (passes on pin) | n/a (passes on pin) | closed |
| 2 | aib-protocols | `axi_st_h2h_patchkr_top` | ❌ 5 div | ❌ 5 div (shared: uhdm too) | ❌ 5 div (shared: uhdm too) | n/a (shared divergence, both netlists) | shared |
| 3 | black-parrot | `bp_be_issue_queue` | ❌ 3 div | ❌ 3 div (shared: uhdm too) | ❌ 3 div (shared: uhdm too) | n/a (shared divergence, both netlists) | shared |
| 4 | black-parrot | `bp_cce_src_sel` | ❌ 28 div | ❌ 28 div (shared: uhdm too) | ❌ 28 div (shared: uhdm too) | n/a (shared divergence, both netlists) | shared |
| 5 | black-parrot | `bp_io_tile` | ❌ 2 div | ❌ 2 div (uhdm ✅) | ❌ 2 div (uhdm ✅) | ❌ 2 div (cosim FIRST-SLANG cycle 26 mem_fwd_link_o rtl=100000000000000000000000000000000 ) | upstream-repro |
| 6 | boom | `AXI4Buffer_1` | ❌ 2 div | ❌ 2 div (uhdm ✅) | ❌ 2 div (uhdm ✅) | ❌ 2 div (cosim FIRST-SLANG cycle 0 auto_in_r_bits_last rtl=0 slang=1) | chisel-mem-const |
| 7 | boom | `AXI4Buffer_2` | ❌ 2 div | ❌ 2 div (uhdm ✅) | ❌ 2 div (uhdm ✅) | ❌ 2 div (cosim FIRST-SLANG cycle 0 auto_in_r_bits_last rtl=0 slang=1) | chisel-mem-const |
| 8 | boom | `ErrorDeviceWrapper` | ❌ 28 div | ❌ 28 div (uhdm ✅) | ❌ 28 div (uhdm ✅) | ❌ 28 div (cosim FIRST-SLANG cycle 0 auto_buffer_in_d_bits_denied rtl=0 slang=1) | chisel-mem-const |
| 9 | boom | `TLBuffer_a32d64s4k2z4c_2` | ❌ 3 div | ❌ 3 div (uhdm ✅) | ❌ 3 div (uhdm ✅) | ❌ 3 div (cosim FIRST-SLANG cycle 0 auto_in_b_bits_opcode rtl=0 slang=6) | chisel-mem-const |
| 10 | caliptra-ss | `recovery_handler` | ❌ 6 div | ✅ PASS | n/a (passes on pin) | n/a (passes on pin) | closed |
| 11 | caliptra-ss | `width_converter_8toN` | ❌ 58 div | ✅ PASS | n/a (passes on pin) | n/a (passes on pin) | closed |
| 12 | core-v-mcu | `cv32e40p_register_file` | ❌ 230 div | ❌ 230 div (shared: uhdm too) | ❌ 230 div (shared: uhdm too) | n/a (shared divergence, both netlists) | shared |
| 13 | core-v-mcu | `dm_sba` | ❌ 6 div | ✅ PASS | n/a (passes on pin) | n/a (passes on pin) | closed |
| 14 | core-v-mcu | `fpnew_fma_multi` | ❌ 14 div | ❌ 14 div (uhdm ✅) | ❌ 14 div (uhdm ✅) | ❌ 14 div (cosim FIRST-SLANG cycle 41 result_o rtl=7ff8000000000000 slang=ba1d000000000000) | upstream-repro |
| 15 | cv32e40p | `cv32e40p_register_file` | ❌ 230 div | ❌ 230 div (shared: uhdm too) | ❌ 230 div (shared: uhdm too) | n/a (shared divergence, both netlists) | shared |
| 16 | cva6-rv32 | `cache_ctrl` | ❌ 4 div | ✅ PASS | n/a (passes on pin) | n/a (passes on pin) | closed |
| 17 | cva6-rv32 | `cva6_ptw` | ❌ 300 div | ✅ PASS | n/a (passes on pin) | n/a (passes on pin) | closed |
| 18 | cva6-rv32 | `std_cache_subsystem` | ❌ 30 div | ⏳ | ⏳ | ⏳ | pending |
| 19 | cva6-rv32 | `std_nbdcache` | ❌ 100 div | ❌ 1 div (uhdm ✅) | ❌ 1 div (uhdm ✅) | TODO custom (core family cva6-rv32) | single |
| 20 | cvfpu | `fpnew_fma_multi` | ❌ 19 div | ❌ 19 div (uhdm ✅) | ❌ 19 div (uhdm ✅) | ❌ 19 div (cosim FIRST-SLANG cycle 16 result_o rtl=ffffffffffff7fc0 slang=ffffffffffff5ae0) | upstream-repro |
| 21 | gemmini | `AXI4Buffer_1` | ❌ 2 div | ❌ 2 div (uhdm ✅) | ❌ 2 div (uhdm ✅) | ❌ 2 div (cosim FIRST-SLANG cycle 0 auto_in_r_bits_last rtl=0 slang=1) | chisel-mem-const |
| 22 | gemmini | `AXI4Buffer_2` | ❌ 2 div | ❌ 2 div (uhdm ✅) | ❌ 2 div (uhdm ✅) | ❌ 2 div (cosim FIRST-SLANG cycle 0 auto_in_r_bits_last rtl=0 slang=1) | chisel-mem-const |
| 23 | gemmini | `ErrorDeviceWrapper` | ❌ 28 div | ❌ 28 div (uhdm ✅) | ❌ 28 div (uhdm ✅) | ❌ 28 div (cosim FIRST-SLANG cycle 0 auto_buffer_in_d_bits_denied rtl=0 slang=1) | chisel-mem-const |
| 24 | gemmini | `ExecuteController` | ❌ 301 div | ❌ 301 div (uhdm ✅) | ❌ 301 div (uhdm ✅) | ❌ 301 div (cosim FIRST-SLANG cycle 0 io_counter_event_signal_36 rtl=0 slang=1) | chisel-mem-const |
| 25 | gemmini | `Queue5_ComputeCntlSignals` | ❌ 4 div | ❌ 4 div (uhdm ✅) | ❌ 4 div (uhdm ✅) | ❌ 4 div (cosim FIRST-SLANG cycle 0 io_deq_bits_b_garbage rtl=0 slang=1) | chisel-mem-const |
| 26 | gemmini | `TLBuffer_a32d128s7k2z4u_2` | ❌ 3 div | ❌ 3 div (uhdm ✅) | ❌ 3 div (uhdm ✅) | ❌ 3 div (cosim FIRST-SLANG cycle 0 auto_in_1_b_bits_opcode rtl=0 slang=6) | chisel-mem-const |
| 27 | hazard3 | `hazard3_core` | ❌ 278 div | ❌ 278 div (uhdm ✅) | ✅ PASS | ✅ 0 div (301 cycles) | fixed-upstream |
| 28 | hazard3 | `hazard3_cpu_2port` | ❌ 278 div | ❌ 278 div (uhdm ✅) | ✅ PASS | n/a (passes with newest sv-elab/slang) | fixed-upstream |
| 29 | kmac | `kmac_reduced` | ❌ 62 div | ✅ PASS | n/a (passes on pin) | n/a (passes with newest sv-elab/slang) | closed |
| 30 | opentitan | `otbn_rnd` | ❌ 296 div | ✅ PASS | n/a (passes on pin) | n/a (passes on pin) | closed |
| 31 | opentitan-ip | `aes_prng_masking` | ❌ 277 div | ✅ PASS | n/a (passes on pin) | n/a (passes on pin) | closed |
| 32 | opentitan-ip | `otbn` | ❌ 197 div | ✅ PASS | n/a (passes on pin) | n/a (passes on pin) | closed |
| 33 | opentitan-ip | `otbn_core` | ❌ 276 div | ✅ PASS | n/a (passes on pin) | n/a (passes on pin) | closed |
| 34 | opentitan-ip | `otbn_rnd` | ❌ 275 div | ✅ PASS | n/a (passes on pin) | n/a (passes on pin) | closed |
| 35 | opentitan-ip | `otp_ctrl_dai` | ❌ 277 div | ❌ 277 div (uhdm ✅) | ❌ 277 div (uhdm ✅) | ❌ 277 div (cosim FIRST-SLANG cycle 0 otp_size_o rtl=3 slang=1) | upstream-repro |
| 36 | opentitan-ip | `tlul_adapter_vh` | ❌ 161 div | ❌ 161 div (uhdm ✅) | ❌ 161 div (uhdm ✅) | ❌ 161 div (cosim FIRST-SLANG cycle 2 tl_o rtl=023bd00000075dc8ae9a1904c7d9 slang=023bd00000) | upstream-repro |
| 37 | pulpissimo | `apb_to_fll` | ❌ 20 div | ❌ 20 div (shared: uhdm too) | ❌ 20 div (shared: uhdm too) | n/a (shared divergence, both netlists) | shared |
| 38 | pulpissimo | `asic_autogen_rom` | ❌ 300 div | ❌ 300 div (shared: uhdm too) | ❌ 300 div (shared: uhdm too) | n/a (shared divergence, both netlists) | shared |
| 39 | pulpissimo | `dm_sba` | ❌ 7 div | ✅ PASS | n/a (passes on pin) | n/a (passes on pin) | closed |
| 40 | pulpissimo | `fpga_autogen_rom` | ❌ 300 div | ❌ 300 div (shared: uhdm too) | ❌ 300 div (shared: uhdm too) | n/a (shared divergence, both netlists) | shared |
| 41 | pulpissimo | `hwpe_ctrl_regfile` | ❌ 2 div | ❌ 2 div (shared: uhdm too) | ❌ 2 div (shared: uhdm too) | n/a (shared divergence, both netlists) | shared |
| 42 | rocket-chip | `AXI4Buffer_1` | ❌ 2 div | ❌ 2 div (uhdm ✅) | ❌ 2 div (uhdm ✅) | ❌ 2 div (cosim FIRST-SLANG cycle 0 auto_in_r_bits_last rtl=0 slang=1) | chisel-mem-const |
| 43 | rocket-chip | `AXI4Buffer_2` | ❌ 2 div | ❌ 2 div (uhdm ✅) | ❌ 2 div (uhdm ✅) | ❌ 2 div (cosim FIRST-SLANG cycle 0 auto_in_r_bits_last rtl=0 slang=1) | chisel-mem-const |
| 44 | rocket-chip | `ErrorDeviceWrapper` | ❌ 28 div | ❌ 28 div (uhdm ✅) | ❌ 28 div (uhdm ✅) | ❌ 28 div (cosim FIRST-SLANG cycle 0 auto_buffer_in_d_bits_denied rtl=0 slang=1) | chisel-mem-const |
| 45 | rocket-chip | `TLBuffer_a32d64s2k2z4c_1` | ❌ 4 div | ❌ 4 div (uhdm ✅) | ❌ 4 div (uhdm ✅) | ❌ 4 div (cosim FIRST-SLANG cycle 0 auto_in_b_bits_opcode rtl=0 slang=6) | chisel-mem-const |
| 46 | rsd | `ReadyBitTable` | ❌ 40 div | ❌ 40 div (uhdm ✅) | ❌ 40 div (uhdm ✅) | ❌ 40 div (same first div: cycle 1 dispatchedSrcReady) | upstream-repro |
| 47 | rsd | `StoreQueue` | ❌ 29 div | ❌ 29 div (uhdm ✅) | ❌ 29 div (uhdm ✅) | error (see up/rsd__StoreQueue.log) | pending |
| 48 | rsd | `WakeupLogic` | ❌ 5 div | ❌ 5 div (shared: uhdm too) | ❌ 5 div (shared: uhdm too) | n/a (shared divergence, both netlists) | shared |
| 49 | sv-synth-tests | `unpacked-structures-members-default-value` | ❌ 300 div | ❌ 300 div (uhdm ✅) | ✅ PASS | ✅ PASS (300 cycles, 0 mismatches) | fixed-upstream |
| 50 | veer-eh2 | `eh2_dec_tlu_top` | ❌ 46 div | ❌ 46 div (shared: uhdm too) | ❌ 46 div (shared: uhdm too) | n/a (shared divergence, both netlists) | shared |
| 51 | veer-eh2 | `eh2_veer` | ❌ 2 div | ❌ 2 div (shared: uhdm too) | ❌ 2 div (shared: uhdm too) | n/a (shared divergence, both netlists) | shared |
| 52 | verilog-pcie | `pcie_axil_master` | ❌ 219 div | ✅ PASS | n/a (passes on pin) | n/a (passes on pin) | closed |
| 53 | verilog-pcie | `pcie_s10_cfg` | ❌ 103 div | ✅ PASS | n/a (passes on pin) | n/a (passes on pin) | closed |
| 54 | xiangshan-core-full | `TLBuffer_14` | ❌ 6 div | ❌ 6 div (uhdm ✅) | ❌ 6 div (uhdm ✅) | ❌ 6 div (cosim FIRST-SLANG cycle 0 auto_in_3_b_bits_size rtl=0 slang=6) | chisel-mem-const |
