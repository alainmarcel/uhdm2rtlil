# Designs `read_slang` cannot read

**126** modules across the nightly IP sweeps cannot be elaborated by
`read_slang` at all.  They carry no formal verdict for a plain reason: the
sweeps prove `read_uhdm` against `read_slang`, and there is nothing to prove
against.  They are not failures of this frontend — `read_uhdm` reads them —
and they are the part of the corpus the other report cannot see, because a
divergence needs two netlists.

It was **360** on 2026-09-29, before an audit of every class in this file
asked which of them were OUR project setup rather than a limitation of
read_slang.  Most were: a configuration the design forbids at its own
defaults, a package or macro the closure withheld, an interface port nobody
wrapped, slang's unroll limit left at 4000, a header the repository never
vendored.  Those are fixed (#996, #997, #999, #1002), and what is left below
is split three ways so the distinction survives the next reader.

Until 2026-09-29 the sweep abandoned such a row entirely: no undriven check,
no co-simulation, nothing recorded either way.  The behavioural RTL is still
there and neither measurement needs slang, so each row now carries a
`read_uhdm` verdict: whether every net is driven, and whether our netlist
tracks the RTL under Verilator.

Of the 126: **28** are confirmed read and elaborated by
`read_uhdm` with every net driven, and **5** of those also
co-simulate the RTL cleanly.  The rest are still being measured, or their
RTL cannot be built standalone by Verilator (a vendor primitive, an
interface port no port-by-port testbench can drive) — a harness limit, not
a verdict.


## What read_slang declines

These are read_slang's own limits: every one of them is a construct the
other two frontends accept, and each row below carries a pre-filled issue
link.

| Construct | Modules | Sweeps |
|---|---|---|
| no answer inside the sweep's time budget (a read_slang performance limit) | 4 | verilog-ethernet |
| a blocking assignment to a variable a non-blocking one already wrote | 3 | hdmi, verilog-pcie |
| an assignment pattern it judges incomplete | 2 | axi |
| a non-blocking assignment in an initial block | 2 | verilog-ethernet, verilog-pcie |
| an internal assertion inside read_slang (a crash, not a rejection) | 1 | axi |
| an sv-elab construct marked unimplemented | 1 | cvfpu |

## What the design, the checkout, or our own project setup declines

Not read_slang's doing.  A module the repository never shipped (OpenTitan
primitives vendored without their `prim_*` library), a configuration the
design itself rejects, RTL the upstream left unfinished -- and, where a
row still shows a package, macro, unroll limit or interface port, a gap
in the project WE hand the tools, which is ours to close and never an
issue to file.  read_uhdm reads several of these only because Surelog is
quieter about a missing file, which is not an advantage.

| Construct | Modules | Sweeps |
|---|---|---|
| an identifier it does not resolve in that scope | 25 | axi, caliptra-ss |
| a module it cannot find in the closure the sweep gives it | 16 | caliptra-ss |
| refuses the module as a top level (usually an unbound interface or an unresolved parameter) | 16 | cvw, hdmi |
| a dimension it evaluates as non-positive | 8 | verilog-pcie |
| an out-of-range select in code a parameter makes dead | 7 | axi, verilog-ethernet |
| a package or class it cannot resolve | 5 | caliptra-ss |
| a memory image the checkout does not contain (`$readmemh` of a missing file) | 4 | caliptra-ss, rp32 |
| an elaboration-time `$error`/`$fatal` the design guards with parameters | 3 | axi, cve2 |
| an interface port on the top module | 2 | axi, rp32 |
| nothing to compare (the upstream RTL is incomplete, or the module is empty) | 2 | rp32 |
| a macro the sweep's include set does not define for it | 1 | caliptra-ss |

## Where read_slang is stricter than the other frontends

read_slang refuses these; `read_verilog`, Surelog and sv2v accept them.
The language is on read_slang's side -- Verilator rejects the enum case
too and cites IEEE 1800 6.19.3 -- and what the lenient tools build is not
always meaningful: `read_verilog` takes an `initial` block that reads a
net and silently drops it, leaving the target undriven.  Recorded so the
RTL can be fixed; not filed against slang.

| Construct | Modules | Sweeps |
|---|---|---|
| a hierarchical reference in a constant expression (`$bits(iface.member)`) | 6 | caliptra-ss |
| a net-declaration initialiser it does not lower | 3 | ibex |
| an implicit conversion to an enum without a cast (IEEE 1800 6.19.3) | 1 | cve2 |

## Unclassified

One-off diagnostics; read the rows.

| Construct | Modules | Sweeps |
|---|---|---|
| other | 14 | axi, caliptra-ss, cvw, verilog-ethernet |

## Every row

`read_uhdm` columns are blank where the row has not been re-measured yet.

| Sweep | Module | `read_slang` says | read_uhdm: undriven | read_uhdm vs RTL | Report |
|---|---|---|---|---|---|
| axi | `axi_cdc_dst_intf` | use of undeclared identifier 'aw_chan_t' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_cdc_src_intf` | use of undeclared identifier 'aw_chan_t' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_chan_logger` | Assert `vbit.variable.kind == Variable::Static' failed in /home/runner/work/uhdm2rtlil/uhdm2rtlil/third_party/yosys/frontends/slang/lib/src/slang_frontend.cc:515. | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_demux_intf` | interface port 'mst' not connected | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_fifo_delay_dyn` | $fatal encountered: Delay unit is not made for synthesis | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_fifo_delay_dyn_intf` | $fatal encountered: Delay unit is not made for synthesis | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_cdc_dst_intf` | use of undeclared identifier 'aw_chan_t' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_cdc_src_intf` | use of undeclared identifier 'aw_chan_t' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_demux_intf` | interface port 'mst' not connected | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_mailbox_intf` | cannot select range of 8 elements from 'data_t' (aka 'logic[-1:0]' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_mux_intf` | interface port 'slv' not connected | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_regs_intf` | replication constant can only be zero inside of a concatenation | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_to_apb` | not all elements of array are covered by an assignment pattern key | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_mux_intf` | interface port 'slv' not connected | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_apb` | not all elements of array are covered by an assignment pattern key | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_detailed_mem_intf` | use of undeclared identifier 'NUM_BANKS' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_mem_banked` | cannot select range of [36:5] from 'axi_addr_t' (aka 'logic[31:0]' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_mem_banked_intf` | use of undeclared identifier 'MEM_NUM_BANKS' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_mem_interleaved_intf` | use of undeclared identifier 'MEM_NUM_BANKS' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_mem_intf` | use of undeclared identifier 'NUM_BANKS' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_mem_split_intf` | use of undeclared identifier 'NUM_MEM_PORTS' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_xp_intf` | top-level module 'axi_xp_intf' has unconnected interface port 'slv_ports' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `aon_clk` | unknown module 'prim_clock_buf' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `aon_osc` | unknown module 'prim_clock_buf' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `ast_dft` | unknown class or package 'prim_mubi_pkg' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `ast_entropy` | unknown module 'prim_flop_2sync' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `ast_pulse_sync` | unknown module 'prim_flop_2sync' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `ast_reg_top` | unknown module 'prim_reg_we_check' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `axi_adapter` | use of undeclared identifier 'CsrAddrWidth' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `counter_template` | unknown package 'i3c_ctrl_pkg' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_EL2_IC_DATA` | use of undeclared identifier 'pt' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_EL2_IC_TAG` | use of undeclared identifier 'pt' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_el2_ifu_ic_mem` | use of undeclared identifier 'pt' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_el2_ifu_iccm_mem` | use of undeclared identifier 'pt' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_el2_ifu_tb_memread` | failed to open file 'left64k' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_el2_lsu_dccm_mem` | use of undeclared identifier 'pt' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_el2_mem` | use of undeclared identifier 'pt' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_el2_veer_wrapper` | use of undeclared identifier 'pt' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `dev_entropy` | unknown module 'prim_flop_2sync' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `gfr_clk_mux2` | unknown module 'prim_clock_gating' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `i3c` | use of undeclared identifier 'AhbAddrWidth' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `i3c_wrapper` | use of undeclared identifier 'AhbAddrWidth' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `io_clk` | unknown module 'prim_clock_buf' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `io_osc` | unknown module 'prim_clock_buf' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `ip_xxx_3511_hs_mem_compound_wrapper` | hierarchical references are not allowed in calls to '$bits' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `ip_xxx_3516_hs_mem_wrapper` | unknown module 'ip_xxx_3516_hs_mem' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `kmac_ss_reduced` | implicit named port 'mode_i' of type 'sha3_pkg::sha3_mode_e' connects to value of inequivalent type 'caliptra_ss_sha3_pkg::sha3_mode_e' [-Wimpli | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `mci_axi_sub_decode` | hierarchical references are not allowed in calls to '$bits' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `mci_axi_sub_top` | hierarchical references are not allowed in calls to '$bits' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `mci_lcc_st_trans` | use of undeclared identifier 'MuBi4True' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `mci_mcu_sram_ctrl` | hierarchical references are not allowed in calls to '$bits' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `mci_mcu_trace_buffer` | hierarchical references are not allowed in calls to '$bits' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `mci_reg_top` | use of undeclared identifier 'AXI_USER_WIDTH'; did you mean 'USER_WIDTH'? | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `mcu_mbox` | hierarchical references are not allowed in calls to '$bits' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `otp_ctrl_dai` | use of undeclared identifier 'mubi8_t' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `otp_ctrl_part_buf` | use of undeclared identifier 'mubi8_t' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `otp_ctrl_part_unbuf` | use of undeclared identifier 'mubi8_t' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `pwrmgr_cdc_pulse` | unknown module 'prim_flop_2sync' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `pwrmgr_slow_fsm` | unknown macro or compiler directive '`PRIM_FLOP_SPARSE_FSM' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `rng` | unknown module 'prim_flop_2sync' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `serializer` | unknown package 'i3c_ctrl_pkg' | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+serializer&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+unknown+package+%27i3c_ctrl_pkg%27%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| caliptra-ss | `spi_host_axi` | use of undeclared identifier 'NumCS' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `sys_clk` | unknown module 'prim_clock_buf' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `sys_osc` | unknown module 'prim_clock_buf' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `usb_clk` | unknown module 'prim_flop_2sync' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `usb_osc` | unknown module 'prim_clock_buf' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `vcaon_pgd` | unknown class or package 'prim_pkg' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `vcc_pgd` | unknown class or package 'prim_pkg' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `vcmain_pgd` | unknown class or package 'prim_pkg' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `vio_pgd` | unknown class or package 'prim_pkg' | — (not measured yet) | — (not measured yet) | — |
| cve2 | `cve2_pmp` | no implicit conversion from 'logic[1:0]' to 'priv_lvl_e'; explicit conversion exists, are you missing a cast? | ✅ 0 undriven | ✅ PASS (201 cycles, 93 active) | — |
| cve2 | `cve2_top_tracing` | $fatal encountered: Fatal error: RVFI needs to be defined globally. | ✅ 0 undriven (1 never assigned in the source) | skip (sim build) | — |
| cvfpu | `fpnew_top` | Feature unimplemented at /home/runner/work/uhdm2rtlil/uhdm2rtlil/third_party/yosys/frontends/slang/lib/src/slang_frontend.cc:2993, see AST and code line dump above | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+fpnew_top&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+Feature+unimplemented+at+%2Fhome%2Frunner%2Fwork%2Fuhdm2rtlil%2Fuhdm2rtlil%2Fthird_party%2Fyosys%2Ffrontends%2Fslang%2Flib%2Fsrc%2Fslang_frontend.cc%3A2993%2C+see+AST+and+code+line+dump+above%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cvw | `ahbapbbridge` | 'ahbapbbridge' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `btb` | 'btb' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `busfsm` | 'busfsm' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `dtim` | Exception: std::bad_alloc | — (not measured yet) | — (not measured yet) | — |
| cvw | `icpred` | 'icpred' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `ieu` | could not find connection for implicit named port 'CSRReadValW' | — (not measured yet) | — (not measured yet) | — |
| cvw | `irom` | Exception: std::bad_alloc | — (not measured yet) | — (not measured yet) | — |
| cvw | `mmu` | 'mmu_flat' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `packetizer` | 'packetizer' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `ram_ahb` | 'ram_ahb' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `rom_ahb` | 'rom_ahb' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `rvvisynth` | 'rvvisynth_flat' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `tlb` | 'tlb' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `tlbcam` | 'tlbcam' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `tlbcamline` | 'tlbcamline' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `tlbcontrol` | 'tlbcontrol' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `tlbram` | 'tlbram' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `uartPC16550D` | 'uartPC16550D' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `uncore` | Exception: std::bad_alloc | — (not measured yet) | — (not measured yet) | — |
| cvw | `wallypipelinedsoc` | Exception: std::bad_alloc | — (not measured yet) | — (not measured yet) | — |
| hdmi | `packet_picker` | blocking assignment to variable 'frame_counter' is not supported after previous non-blocking assignment | ✅ 0 undriven (62000 never assigned in the source) | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+packet_picker&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+blocking+assignment+to+variable+%27frame_counter%27+is+not+supported+after+previous+non-blocking+assignment%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%2862000+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| hdmi | `serializer` | 'serializer_flat' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | — |
| ibex | `ibex_top` | slang net-init | — (not measured yet) | — (not measured yet) | — |
| ibex | `ibex_top_tracing` | slang net-init | — (not measured yet) | — (not measured yet) | — |
| ibex | `ibex_tracer` | slang net-init | — (not measured yet) | — (not measured yet) | — |
| rp32 | `rp32_r5p_degu` | iface port at top | — (not measured yet) | — (not measured yet) | — |
| rp32 | `rp32_r5p_degu_soc_top` | slang $readmemh | — (not measured yet) | — (not measured yet) | — |
| rp32 | `rp32_r5p_hamster` | upstream RTL incomplete | — (not measured yet) | — (not measured yet) | — |
| rp32 | `rp32_r5p_mdu` | empty module | — (not measured yet) | — (not measured yet) | — |
| rp32 | `rp32_r5p_mouse_soc_top` | slang $readmemh | — (not measured yet) | — (not measured yet) | — |
| rp32 | `rp32_soc_vfriendly` | slang $readmemh | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `axis_baser_rx_64` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | ✅ 0 undriven | ✅ PASS (201 cycles, 199 active) | — |
| verilog-ethernet | `axis_srl_fifo` | non-blocking assignments unsupported in design initialization | ✅ 0 undriven | ❌ 174 div | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axis_srl_fifo&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+non-blocking+assignments+unsupported+in+design+initialization%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `axis_xgmii_rx_32` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | ✅ 0 undriven | ✅ PASS (201 cycles, 194 active) | — |
| verilog-ethernet | `eth_mac_phy_10g` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | ✅ 0 undriven (2 never assigned in the source) | skip (sim build) | — |
| verilog-ethernet | `eth_mac_phy_10g_fifo` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | ✅ 0 undriven (2 never assigned in the source) | skip (sim build) | — |
| verilog-ethernet | `eth_mac_phy_10g_rx` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | ✅ 0 undriven (2 never assigned in the source) | skip (sim build) | — |
| verilog-ethernet | `eth_mac_phy_10g_tx` | no reference (read_slang fails) (read_slang did not finish within the sweep's 600 s budget) | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+eth_mac_phy_10g_tx&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+no+reference+%28read_slang+fails%29+%28read_slang+did+not+finish+within+the+sweep%27s+600+s+budget%29%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `eth_phy_10g` | no reference (read_slang fails) (read_slang did not finish within the sweep's 600 s budget) | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+eth_phy_10g&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+no+reference+%28read_slang+fails%29+%28read_slang+did+not+finish+within+the+sweep%27s+600+s+budget%29%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `eth_phy_10g_rx` | no reference (read_slang fails) (read_slang did not finish within the sweep's 600 s budget) | ✅ 0 undriven | ❌ 104 div | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+eth_phy_10g_rx&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+no+reference+%28read_slang+fails%29+%28read_slang+did+not+finish+within+the+sweep%27s+600+s+budget%29%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `eth_phy_10g_tx_if` | no reference (read_slang fails) (read_slang did not finish within the sweep's 600 s budget) | ✅ 0 undriven | ❌ 201 div | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+eth_phy_10g_tx_if&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+no+reference+%28read_slang+fails%29+%28read_slang+did+not+finish+within+the+sweep%27s+600+s+budget%29%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `ssio_sdr_in_diff` | parameter 'IODDR_STYLE' does not exist in 'ssio_sdr_in' [-Wundefined-param-override] | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+ssio_sdr_in_diff&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+parameter+%27IODDR_STYLE%27+does+not+exist+in+%27ssio_sdr_in%27+%5B-Wundefined-param-override%5D%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `axis_srl_fifo` | non-blocking assignments unsupported in design initialization | ✅ 0 undriven | ❌ 174 div | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axis_srl_fifo&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+non-blocking+assignments+unsupported+in+design+initialization%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `dma_if_axi` | blocking assignment to variable 'm_axis_read_desc_status_error_reg' is not supported after previous non-blocking assignment | ✅ 0 undriven | ✅ PASS (201 cycles, 200 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+dma_if_axi&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+blocking+assignment+to+variable+%27m_axis_read_desc_status_error_reg%27+is+not+supported+after+previous+non-blocking+assignment%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `dma_if_axi_rd` | blocking assignment to variable 'm_axis_read_desc_status_error_reg' is not supported after previous non-blocking assignment | ✅ 0 undriven | ✅ PASS (201 cycles, 168 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+dma_if_axi_rd&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+blocking+assignment+to+variable+%27m_axis_read_desc_status_error_reg%27+is+not+supported+after+previous+non-blocking+assignment%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_ptile_if` | value must be positive | ✅ 0 undriven (14 never assigned in the source) | skip (sim build) | — |
| verilog-pcie | `pcie_ptile_if_rx` | value must be positive | ✅ 0 undriven | skip (sim build) | — |
| verilog-pcie | `pcie_ptile_if_tx` | value must be positive | ✅ 0 undriven | skip (sim build) | — |
| verilog-pcie | `pcie_s10_if` | value must be positive | ✅ 0 undriven | skip (sim build) | — |
| verilog-pcie | `pcie_s10_if_rx` | value must be positive | ✅ 0 undriven | skip (sim build) | — |
| verilog-pcie | `pcie_s10_if_tx` | value must be positive | ✅ 0 undriven | skip (sim build) | — |
| verilog-pcie | `pcie_us_if_cc` | value must be positive | ✅ 0 undriven | skip (sim build) | — |
| verilog-pcie | `pcie_us_if_cq` | value must be positive | ✅ 0 undriven | skip (sim build) | — |

---

Regenerate with `test/slang_unsupported_report.py` after a sweep cycle.
A row leaves this file the moment `read_slang` can read the design.

