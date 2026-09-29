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
| caliptra-ss | `width_converter_8toN` | 58 | cycle 26, `source_data_o` rtl=`0000073f` slang=`0000003f` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+width_converter_8toN+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28caliptra-ss+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+26%2C+%60source_data_o%60+rtl%3D%600000073f%60+slang%3D%600000003f%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cv32e40p | `cv32e40p_register_file` | 230 | cycle 27, `rdata_a_o` rtl=`82b7c5e0` slang=`00000000` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cv32e40p_register_file+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28cv32e40p+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+27%2C+%60rdata_a_o%60+rtl%3D%6082b7c5e0%60+slang%3D%6000000000%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cva6 | `macro_decoder` | 1 | cycle 6, `instr_o` rtl=`ff313823` slang=`c172ff1c` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+macro_decoder+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28cva6+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+6%2C+%60instr_o%60+rtl%3D%60ff313823%60+slang%3D%60c172ff1c%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cvfpu | `fpnew_fma_multi` | 19 | cycle 16, `result_o` rtl=`…ffff7fc0` slang=`…ffff5ae0` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+fpnew_fma_multi+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28cvfpu+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+16%2C+%60result_o%60+rtl%3D%60%E2%80%A6ffff7fc0%60+slang%3D%60%E2%80%A6ffff5ae0%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| kmac | `kmac_reduced` | 62 | — | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+kmac_reduced+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28kmac+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+see+report%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| opentitan | `otbn_rnd` | 296 | cycle 4, `ispr_urnd_state_rdata_o` (slang zeroes the low limb) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+otbn_rnd+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28opentitan+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+4%2C+%60ispr_urnd_state_rdata_o%60+%28slang+zeroes+the+low+limb%29%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `axis_ram_switch` | 176 | cycle 40, `m_axis_tdata` rtl=`00630000` slang=`00000000` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+axis_ram_switch+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28verilog-ethernet+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+40%2C+%60m_axis_tdata%60+rtl%3D%6000630000%60+slang%3D%6000000000%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `axis_ram_switch` | 206 | cycle 40, `m_axis_tdata` rtl=`00630000` slang=`00000000` (same module, vendored twice) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+axis_ram_switch+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28verilog-pcie+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+40%2C+%60m_axis_tdata%60+rtl%3D%6000630000%60+slang%3D%6000000000%60+%28same+module%2C+vendored+twice%29%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_axil_master` | 219 | cycle 55, `tx_cpl_tlp_data` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+pcie_axil_master+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28verilog-pcie+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+55%2C+%60tx_cpl_tlp_data%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_s10_cfg` | 103 | cycle 198, `cfg_msi_address` rtl=`c2af88347c3321e0` slang=`000000007c3321e0` | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+pcie_s10_cfg+netlist+does+not+match+the+RTL+in+simulation&body=%60read_slang%60+%28verilog-pcie+sweep%29+produces+a+netlist+whose+simulation+diverges+from+the+behavioural+RTL.%0A%0AFirst+divergence%3A+cycle+198%2C+%60cfg_msi_address%60+rtl%3D%60c2af88347c3321e0%60+slang%3D%60000000007c3321e0%60%0A%0AMethod%3A+one+Verilator+testbench+drives+the+behavioural+RTL%2C+the+%60read_slang%60+netlist+and+the+%60read_uhdm%60+netlist+with+identical+stimulus.+The+%60read_uhdm%60+netlist+matches+the+RTL+on+every+cycle%3B+the+%60read_slang%60+netlist+does+not.%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |

## Both netlists diverge, but not equally

Both frontends drift from the RTL, so the co-simulation's own X-initial
state explains most of it, but the counts differ — worth adjudicating
before either reporting or dismissing.

| Sweep | Module | slang | read_uhdm | First slang divergence |
|---|---|---|---|---|
| cv32e40p | `cv32e40p_cs_registers` | 200 | 136 | — |
| cva6 | `axi_adapter` | 53 | 33 | — |
| cva6 | `hpdcache_ctrl` | 151 | 154 | — |
| cva6 | `hpdcache_memctrl` | 160 | 140 | — |
| cva6 | `wt_dcache_mem` | 63 | 25 | — |
| ibex | `ibex_cs_registers` | 61 | 51 | cycle 206, `csr_mepc_o` rtl=`0` slang=`548c3846` |
| rp32 | `rp32_r5p_alu` | 519 | 493 | — |
| rp32 | `rp32_r5p_mouse` | 438 | 499 | — |
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
| ibex | `ibex_alu` | 38 |
| ibex | `ibex_ex_block` | 58 |
| pavona | `ibex_cs_registers` | 256 |
| rp32 | `rp32_r5p_wbu` | 181 |
| verilog-ethernet | `ptp_td_rel2tod` | 2 |
| verilog-pcie | `pcie_ptile_cfg` | 189 |

## Not yet re-measured

Carried from the last CI report; the `read_uhdm` side has not been run
since the harness correction, so these are not yet classified.

| Sweep | Module | slang divergences | Source |
|---|---|---|---|
| dragonfly | `u_keymgr_dpe` | 301 | pavona nightly 36421592007 |
| dragonfly | `u_lc_ctrl` | 301 | pavona nightly 36421592007 |
| dragonfly | `u_rv_core_ibex` | 258 | pavona nightly 36421592007 |
| egret | `u_flash_ctrl` | 301 | pavona run 36346999995 |
| egret | `u_keymgr` | 301 | pavona run 36346999995 |
| egret | `u_lc_ctrl` | 301 | pavona run 36346999995 |
| egret | `u_otp_ctrl` | 301 | pavona run 36346999995 |
| periph5 | `spid_status` | 15 | pavona nightly 36421592007 |
| xiangshan-core | `Queue2_TLBundleB_2` | 1 | xiangshan run 36421602760 |
| xiangshan-core | `Queue2_TLBundleD_21` | 1 | xiangshan run 36421602760 |
| xiangshan-core | `TLBuffer_14` | 6 | xiangshan run 36421602760 |

## Cleared by the harness correction

| Sweep | Module | Was | Now |
|---|---|---|---|
| ibex | `ibex_id_stage` | 52 divergences | 0 |
| opentitan | `otbn_reg_top` | 19 divergences | 0 |

---

Regenerate with `test/slang_cosim_report.py` after a sweep cycle.  A row moves
out of this file the moment its sweep reports the slang column clean.

