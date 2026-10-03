# Where `read_slang` does not match Verilator

Every nightly IP sweep co-simulates three things against each other with one
testbench and one random stimulus: the behavioural RTL, the netlist
`read_uhdm` produces, and the netlist `read_slang` produces.  The left-most
column of every sweep table is the last of those — how the reference
frontend's own netlist tracks the RTL under Verilator.  This file collects
every row where it does not.

A row is evidence of a `read_slang` defect when the `read_uhdm` netlist
matches the RTL on every cycle and the `read_slang` netlist does not: same
testbench, same stimulus, same RTL, one netlist right and one wrong.  When
BOTH netlists diverge the cause is almost always the co-simulation itself —
an un-reset register reads X out of reset in the RTL and 0 in a netlist —
so those rows are listed separately and are not reported.

`read_slang` is a Yosys built-in since v0.67; the code is vendored from
[povik/sv-elab](https://github.com/povik/sv-elab) at `b4fd362`.  Measured on
Yosys 0.69.

> **A correction.** Until 2026-09-29 this list was much longer, and wrongly
> so.  All three co-simulation harnesses flattened an unpacked-array port
> with element 0 at the least significant bits whatever the declared
> direction, which matched `read_uhdm` alone.  `read_slang` follows the
> language — the left index of the dimension takes the most significant
> bits, which is what the stream operator `{>>{x}}` computes (LRM 11.4.14)
> and what Verilator prints for it — so every module with an ascending
> `x [N]` port looked like a slang defect.  The reader and the harnesses
> were corrected to the language's order; `ibex_id_stage` went from 52
> divergences to none, `otbn_reg_top` from 19 to none, `ibex_ex_block` from
> 447 to 58 (and those 58 are shared with `read_uhdm`, so the row is an
> artefact, not a defect).  The rows below are what survived.


## Report to Yosys

The `read_uhdm` netlist matches the RTL cycle for cycle; the
`read_slang` netlist does not.

| Sweep | Module | Diverging cycles | First divergence | Report |
|---|---|---|---|---|
| aes | `aes_prng_masking` | 300 | — | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+aes_prng_masking+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28aes+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+see+report%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| caliptra-ss | `recovery_handler` | 6 | — | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+recovery_handler+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28caliptra-ss+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+see+report%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| caliptra-ss | `width_converter_8toN` | 58 | cycle 26, `source_data_o` rtl=`0000073f` slang=`0000003f` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+width_converter_8toN+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28caliptra-ss+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+26%2C+%60source_data_o%60+rtl%3D%600000073f%60+slang%3D%600000003f%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cv32e40p | `cv32e40p_register_file` | 230 | cycle 27, `rdata_a_o` rtl=`82b7c5e0` slang=`00000000` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cv32e40p_register_file+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28cv32e40p+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+27%2C+%60rdata_a_o%60+rtl%3D%6082b7c5e0%60+slang%3D%6000000000%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cva6 | `macro_decoder` | 1 | cycle 6, `instr_o` rtl=`ff313823` slang=`c172ff1c` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+macro_decoder+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28cva6+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+6%2C+%60instr_o%60+rtl%3D%60ff313823%60+slang%3D%60c172ff1c%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cvfpu | `fpnew_fma_multi` | 19 | cycle 16, `result_o` rtl=`…ffff7fc0` slang=`…ffff5ae0` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+fpnew_fma_multi+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28cvfpu+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+16%2C+%60result_o%60+rtl%3D%60%E2%80%A6ffff7fc0%60+slang%3D%60%E2%80%A6ffff5ae0%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| kmac | `kmac_reduced` | 62 | — | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+kmac_reduced+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28kmac+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+see+report%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| opentitan | `otbn_rnd` | 296 | cycle 4, `ispr_urnd_state_rdata_o` (slang zeroes the low limb) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+otbn_rnd+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28opentitan+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+4%2C+%60ispr_urnd_state_rdata_o%60+%28slang+zeroes+the+low+limb%29%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `axis_ram_switch` | 176 | cycle 40, `m_axis_tdata` rtl=`00630000` slang=`00000000` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+axis_ram_switch+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28verilog-ethernet+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+40%2C+%60m_axis_tdata%60+rtl%3D%6000630000%60+slang%3D%6000000000%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `axis_ram_switch` | 206 | cycle 40, `m_axis_tdata` rtl=`00630000` slang=`00000000` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+axis_ram_switch+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28verilog-pcie+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+40%2C+%60m_axis_tdata%60+rtl%3D%6000630000%60+slang%3D%6000000000%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_axil_master` | 219 | cycle 55, `tx_cpl_tlp_data` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+pcie_axil_master+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28verilog-pcie+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+55%2C+%60tx_cpl_tlp_data%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_s10_cfg` | 103 | cycle 198, `cfg_msi_address` rtl=`c2af88347c3321e0` slang=`000000007c3321e0` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+pcie_s10_cfg+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28verilog-pcie+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+198%2C+%60cfg_msi_address%60+rtl%3D%60c2af88347c3321e0%60+slang%3D%60000000007c3321e0%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| xiangshan-core-full | `Queue2_TLBundleB_2` | 1 | — | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+Queue2_TLBundleB_2+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28xiangshan-core-full+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+see+report%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| xiangshan-core-full | `Queue2_TLBundleD_21` | 1 | — | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+Queue2_TLBundleD_21+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28xiangshan-core-full+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+see+report%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| xiangshan-core-full | `TLBuffer_14` | 6 | — | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+TLBuffer_14+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28xiangshan-core-full+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+see+report%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |

## Both netlists diverge, but not equally

Both frontends drift from the RTL, so the co-simulation's own X-initial
state explains most of it, but the counts differ — worth adjudicating
before either reporting or dismissing.

| Sweep | Module | slang | read_uhdm | First slang divergence |
|---|---|---|---|---|
| axi | `axi_demux_simple` | 4 | 2 | — |
| cv32e40p | `cv32e40p_cs_registers` | 200 | 136 | — |
| cva6 | `axi_adapter` | 53 | 33 | — |
| cva6 | `hpdcache_ctrl` | 151 | 154 | — |
| cva6 | `hpdcache_memctrl` | 160 | 140 | — |
| cva6 | `wt_dcache_mem` | 63 | 25 | — |
| ibex | `ibex_cs_registers` | 61 | 51 | cycle 206, `csr_mepc_o` rtl=`0` slang=`548c3846` |
| rp32 | `rp32_r5p_alu` | 519 | 493 | — |
| rp32 | `rp32_r5p_mouse` | 438 | 499 | — |
| verilog-pcie | `pcie_tlp_demux` | 141 | 244 | — |
| verilog-pcie | `pcie_tlp_demux_bar` | 210 | 219 | — |
| verilog-pcie | `pcie_tlp_fifo` | 261 | 265 | — |
| verilog-pcie | `pcie_tlp_fifo_raw` | 271 | 276 | — |
| verilog-pcie | `pcie_us_if_rc` | 238 | 272 | — |

## Shared divergence — a co-simulation artefact, not a defect

Both netlists diverge from the RTL on exactly the same cycles.  A netlist
has no X state, so an un-reset register reads 0 where the RTL reads X;
the SAT miter, which starts from a defined state, proves these modules
equivalent.  Listed for completeness.

| Sweep | Module | Diverging cycles (both) |
|---|---|---|
| common_cells | `cc_clk_int_div` | 5 |
| cv32e40p | `cv32e40p_controller` | 92 |
| cv32e40p | `cv32e40p_fifo` | 30 |
| cv32e40p | `cv32e40p_prefetch_buffer` | 9 |
| cva6 | `hpdcache_amo` | 171 |
| cva6 | `hpdcache_cmo` | 298 |
| cva6 | `hpdcache_uncached` | 300 |
| cva6 | `issue_stage` | 3 |
| cva6 | `miss_handler` | 1 |
| cva6 | `wt_dcache_wbuffer` | 216 |
| cve2 | `cve2_alu` | 18 |
| cve2 | `cve2_ex_block` | 14 |
| cvw | `uart_apb` | 213 |
| dragonfly | `u_keymgr_dpe` | 301 |
| dragonfly | `u_lc_ctrl` | 301 |
| dragonfly | `u_rv_core_ibex` | 258 |
| egret | `u_flash_ctrl` | 301 |
| egret | `u_keymgr` | 301 |
| egret | `u_lc_ctrl` | 301 |
| egret | `u_otp_ctrl` | 301 |
| ibex | `ibex_alu` | 38 |
| ibex | `ibex_ex_block` | 58 |
| opentitan | `otbn_reg_top` | 19 |
| pavona | `ibex_cs_registers` | 256 |
| periph5 | `spid_status` | 15 |
| rp32 | `rp32_r5p_wbu` | 181 |
| verilog-ethernet | `ptp_td_rel2tod` | 2 |
| verilog-pcie | `pcie_ptile_cfg` | 189 |

## The other direction: read_slang clean, OUR netlist wrong

The same measurement, read the other way round.  These rows are defects in
THIS frontend, not in read_slang, and they belong in the same document: a
file that only ever lists the other tool's mistakes is not a measurement,
it is advocacy.

The 2026-09-30 round is the case in point.  Binding cvw's configuration
made 234 rows comparable for the first time and 68 of them landed here at
once — one cause, and ours: the generated wrapper put the configuration in
the compilation unit, where Surelog drops the instance's binding, so
`read_uhdm` imported every module with `P` unbound and `P.XLEN` one bit
wide.  Two rows survive the fix.

| Sweep | Module | read_uhdm diverging cycles | formal vs slang |
|---|---|---|---|
| axi | `axi_id_remap_intf` | 275 | ❌ differs |
| verilog-pcie | `dma_client_axis_sink` | 268 | ✅ equivalent |

---

Regenerate with `test/slang_cosim_report.py` after a sweep cycle.  A row moves
out of this file the moment its sweep reports the slang column clean.


## The test suites

Both suites already carry what the measurement needs — a wrapper, a
testbench and stimulus — and a known-good `read_uhdm` baseline.  Until
2026-09-29 the co-simulation was only ever run with the `read_uhdm`
netlist, so the reference frontend went unmeasured over 1650 tests.  It is
now a soft-warn column of the regression (`run_slang_cosim_softwarn`).

| Suite | Co-simulated | `read_slang` diverges | of those: slang-only | both, unequal | shared |
|---|---|---|---|---|---|
| local `test/<name>` | 1139 | 41 | 9 | 9 | 23 |
| upstream `test/run/**` | 511 | 42 | 5 | 15 | 22 |

Three tests appear in both suites — the internal copies of upstream
reproducers — so the distinct slang-only set is eleven.


### Report to Yosys — test-suite reproducers

These are the most useful reports in this file: the `read_uhdm` netlist
matches the RTL, the `read_slang` netlist does not, and the design is a few
lines that already live in a repository Yosys itself ships or vendors.

| Suite | Test | Diverging cycles | First divergence | Report |
|---|---|---|---|---|
| local | `ArrayInit` | 200 | `a` rtl=`1` slang=`0` — 2-D unpacked array, nested `'{'{0,1,2},'{4,4,4}}` initialiser | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+ArrayInit+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28test+suite+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+%60a%60+rtl%3D%601%60+slang%3D%600%60+%E2%80%94+2-D+unpacked+array%2C+nested+%60%27%7B%27%7B0%2C1%2C2%7D%2C%27%7B4%2C4%2C4%7D%7D%60+initialiser%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| local | `UnionParameter` | 200 | `o` rtl=`6` slang=`8` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+UnionParameter+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28test+suite+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+%60o%60+rtl%3D%606%60+slang%3D%608%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| local | `case_expr_extend` | 200 | `out` rtl=`3f` slang=`0` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+case_expr_extend+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28test+suite+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+%60out%60+rtl%3D%603f%60+slang%3D%600%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| local | `const_fold_func` | 200 | `out6` rtl=`2` slang=`0` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+const_fold_func+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28test+suite+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+%60out6%60+rtl%3D%602%60+slang%3D%600%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| local | `counter_dual_xbranch` | 108 | `count_instr` rtl=`0` slang=`2` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+counter_dual_xbranch+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28test+suite+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+%60count_instr%60+rtl%3D%600%60+slang%3D%602%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| local | `dyn_packed_multidim` | 89 | `o_dyn_both` rtl=`0` slang=`1eb` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+dyn_packed_multidim+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28test+suite+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+%60o_dyn_both%60+rtl%3D%600%60+slang%3D%601eb%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| local | `hana_test_parse2synthtrans` | inert | the slang netlist is inert — no output activity at all | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+hana_test_parse2synthtrans+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28test+suite+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+the+slang+netlist+is+inert+%E2%80%94+no+output+activity+at+all%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| local | `nested_full_case` | 13 | `q` rtl=`eb` slang=`49` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+nested_full_case+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28test+suite+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+%60q%60+rtl%3D%60eb%60+slang%3D%6049%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| local | `param_dyn_elem_select` | 124 | `ut_out` rtl=`0` slang=`1` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+param_dyn_elem_select+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28test+suite+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+%60ut_out%60+rtl%3D%600%60+slang%3D%601%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| upstream | `run/arch/common/tribuf` | 46 | `o` rtl=`0` slang=`1` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+run%2Farch%2Fcommon%2Ftribuf+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28test+suite+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+%60o%60+rtl%3D%600%60+slang%3D%601%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| upstream | `run/simple/task_func` | 200 | `w` rtl=`54` slang=`a8` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+run%2Fsimple%2Ftask_func+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28test+suite+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+%60w%60+rtl%3D%6054%60+slang%3D%60a8%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |

The other rows split the same way as the sweeps: where both netlists
diverge identically the co-simulation's X-initial state explains it, and
where the counts merely differ the row needs adjudicating before anyone
reports or dismisses it.  `case_expr_const`, `case_expr_non_const`,
`wandwor`, `latch_002`, `ibex_cs_registers`, `rp32_r5p_alu`,
`rp32_r5p_mouse`, `full_case_latch` and the `dynamic_part_select` family
are in that middle group on both sides.


## Designs `read_slang` cannot read at all

A further **88** sweep rows never reach this comparison at all:
`read_slang` cannot elaborate the design, so there is no second netlist to
co-simulate.  They are counted here only so this file is not mistaken for
the whole picture — [docs/slang_unsupported.md](slang_unsupported.md) lists
every one with its diagnostic and what `read_uhdm` makes of it.

**Most of them are not read_slang's doing.**  That list was 360 rows on
2026-09-29, and an audit of every class found the usual suspects were ours:
a configuration the design forbids at its own defaults, a package or macro
our closure withheld, an interface port nobody wrapped, slang's unroll limit
left at 4000, a header the repository never vendored.  Of what remains,
**13** rows in 6 classes are genuinely read_slang limits, **10** are places
where read_slang is stricter than the other frontends and the language is on
its side (Verilator rejects the enum case too, IEEE 1800 6.19.3), and the
rest belong to the design, the checkout, or still to our own project setup —
25 rows whose diagnostic points at our closure are the next round of that
work, not a report about slang.

| Sweep | Rows |
|---|---|
| caliptra-ss | 36 |
| verilog-pcie | 11 |
| cvw | 10 |
| verilog-ethernet | 10 |
| rp32 | 7 |
| axi | 6 |
| ibex | 3 |
| cve2 | 2 |
| hdmi | 2 |
| cvfpu | 1 |

Measured on CI runs: acc `37119830739`, aes `37119830739`, axi `37113055862`, caliptra `37116358358`, caliptra-ss `37113055862`, common_cells `37113055862`, csrng `37119830739`, cv32e40p `37113055862`, cva6 `37111948525`, cva6-chip `37111948525`, cve2 `37113055862`, cvfpu `37113055862`, cvw `37113055862`, dragonfly `37119830739`, edn `37119830739`, egret `37119830739`, entropy_src `37119830739`, hdmi `37113055862`, hmac `37119830739`, ibex `37108557724`, keymgr `37119830739`, kmac `37119830739`, opentitan `37010906543`, pavona `37119830739`, periph `37119830739`, periph2 `37119830739`, periph3 `37119830739`, periph4 `37119830739`, periph5 `37119830739`, rp32 `37110119476`, tlul `37119830739`, verilog-ethernet `37113055862`, verilog-pcie `37113055862`, xiangshan `37113055862`, xiangshan-core-full `37115206169`.

