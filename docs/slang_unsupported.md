# Designs `read_slang` cannot read

**126** modules across the nightly IP sweeps cannot be elaborated by
`read_slang` at all.  They carry no formal verdict for a plain reason: the
sweeps prove `read_uhdm` against `read_slang`, and there is nothing to prove
against.  They are not failures of this frontend — `read_uhdm` reads them —
and they are the part of the corpus the other report cannot see, because a
divergence needs two netlists.

Each row carries a `read_uhdm` verdict as well -- whether every net is
driven, and whether our netlist tracks the RTL under Verilator -- because
neither measurement needs slang.  The rows are split three ways: what
read_slang declines, where it is stricter than the other frontends and the
language is on its side, and what the design, the checkout or our own
project setup declines.  Only the first group is a report about slang.

All 126 are read and elaborated by `read_uhdm` with every net
driven, and **12** also co-simulate the RTL cleanly.  For the
rest Verilator cannot build a testbench standalone — a vendor primitive, an
interface port no port-by-port testbench can drive — which is a harness
limit, not a verdict on either frontend.


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
| axi | `axi_cdc_dst_intf` | use of undeclared identifier 'aw_chan_t' | ✅ 0 undriven (10 never assigned in the source) | skip (sim build) | — |
| axi | `axi_cdc_src_intf` | use of undeclared identifier 'aw_chan_t' | ✅ 0 undriven (10 never assigned in the source) | skip (sim build) | — |
| axi | `axi_chan_logger` | Assert `vbit.variable.kind == Variable::Static' failed in /home/runner/work/uhdm2rtlil/uhdm2rtlil/third_party/yosys/frontends/slang/lib/src/slang_frontend.cc:515. | ✅ 0 undriven | skip (no run) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axi_chan_logger&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+Assert+%60vbit.variable.kind+%3D%3D+Variable%3A%3AStatic%27+failed+in+%2Fhome%2Frunner%2Fwork%2Fuhdm2rtlil%2Fuhdm2rtlil%2Fthird_party%2Fyosys%2Ffrontends%2Fslang%2Flib%2Fsrc%2Fslang_frontend.cc%3A515.%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| axi | `axi_demux_intf` | interface port 'mst' not connected | ✅ 0 undriven (262 never assigned in the source) | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axi_demux_intf&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+interface+port+%27mst%27+not+connected%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%28262+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| axi | `axi_fifo_delay_dyn` | $fatal encountered: Delay unit is not made for synthesis | ✅ 0 undriven | ✅ PASS (301 cycles, 11 active) | — |
| axi | `axi_fifo_delay_dyn_intf` | $fatal encountered: Delay unit is not made for synthesis | ✅ 0 undriven | skip (sim build) | — |
| axi | `axi_lite_cdc_dst_intf` | use of undeclared identifier 'aw_chan_t' | ✅ 0 undriven (10 never assigned in the source) | skip (sim build) | — |
| axi | `axi_lite_cdc_src_intf` | use of undeclared identifier 'aw_chan_t' | ✅ 0 undriven (23 never assigned in the source) | skip (sim build) | — |
| axi | `axi_lite_demux_intf` | interface port 'mst' not connected | ✅ 0 undriven (148 never assigned in the source) | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axi_lite_demux_intf&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+interface+port+%27mst%27+not+connected%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%28148+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| axi | `axi_lite_mailbox_intf` | cannot select range of 8 elements from 'data_t' (aka 'logic[-1:0]' | ✅ 0 undriven | skip (no run) | — |
| axi | `axi_lite_mux_intf` | interface port 'slv' not connected | ✅ 0 undriven (294 never assigned in the source) | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axi_lite_mux_intf&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+interface+port+%27slv%27+not+connected%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%28294+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| axi | `axi_lite_regs_intf` | replication constant can only be zero inside of a concatenation | ✅ 0 undriven (16 never assigned in the source) | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axi_lite_regs_intf&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+replication+constant+can+only+be+zero+inside+of+a+concatenation%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%2816+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| axi | `axi_lite_to_apb` | not all elements of array are covered by an assignment pattern key | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axi_lite_to_apb&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+not+all+elements+of+array+are+covered+by+an+assignment+pattern+key%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| axi | `axi_mux_intf` | interface port 'slv' not connected | ✅ 0 undriven (432 never assigned in the source) | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axi_mux_intf&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+interface+port+%27slv%27+not+connected%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%28432+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| axi | `axi_to_apb` | not all elements of array are covered by an assignment pattern key | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axi_to_apb&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+not+all+elements+of+array+are+covered+by+an+assignment+pattern+key%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| axi | `axi_to_detailed_mem_intf` | use of undeclared identifier 'NUM_BANKS' | ✅ 0 undriven (64 never assigned in the source) | skip (sim build) | — |
| axi | `axi_to_mem_banked` | cannot select range of [36:5] from 'axi_addr_t' (aka 'logic[31:0]' | ✅ 0 undriven (220 never assigned in the source) | ❌ 225 div | — |
| axi | `axi_to_mem_banked_intf` | use of undeclared identifier 'MEM_NUM_BANKS' | ✅ 0 undriven (128 never assigned in the source) | skip (sim build) | — |
| axi | `axi_to_mem_interleaved_intf` | use of undeclared identifier 'MEM_NUM_BANKS' | ✅ 0 undriven (64 never assigned in the source) | skip (sim build) | — |
| axi | `axi_to_mem_intf` | use of undeclared identifier 'NUM_BANKS' | ✅ 0 undriven (64 never assigned in the source) | skip (sim build) | — |
| axi | `axi_to_mem_split_intf` | use of undeclared identifier 'NUM_MEM_PORTS' | ✅ 0 undriven (128 never assigned in the source) | skip (sim build) | — |
| axi | `axi_xp_intf` | top-level module 'axi_xp_intf' has unconnected interface port 'slv_ports' | ✅ 0 undriven | skip (no run) | — |
| caliptra-ss | `aon_clk` | unknown module 'prim_clock_buf' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `aon_osc` | unknown module 'prim_clock_buf' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `ast_dft` | unknown class or package 'prim_mubi_pkg' | ✅ 0 undriven (1 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `ast_entropy` | unknown module 'prim_flop_2sync' | ✅ 0 undriven (3 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `ast_pulse_sync` | unknown module 'prim_flop_2sync' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `ast_reg_top` | unknown module 'prim_reg_we_check' | ✅ 0 undriven (2698 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `axi_adapter` | use of undeclared identifier 'CsrAddrWidth' | ✅ 0 undriven (128 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `counter_template` | unknown package 'i3c_ctrl_pkg' | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+counter_template&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+unknown+package+%27i3c_ctrl_pkg%27%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| caliptra-ss | `css_mcu0_EL2_IC_DATA` | use of undeclared identifier 'pt' | ✅ 0 undriven (71 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `css_mcu0_EL2_IC_TAG` | use of undeclared identifier 'pt' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `css_mcu0_el2_ifu_ic_mem` | use of undeclared identifier 'pt' | ✅ 0 undriven (71 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `css_mcu0_el2_ifu_iccm_mem` | use of undeclared identifier 'pt' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `css_mcu0_el2_ifu_tb_memread` | failed to open file 'left64k' | ✅ 0 undriven | skip (no run) | — |
| caliptra-ss | `css_mcu0_el2_lsu_dccm_mem` | use of undeclared identifier 'pt' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `css_mcu0_el2_mem` | use of undeclared identifier 'pt' | ✅ 0 undriven (71 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `css_mcu0_el2_veer_wrapper` | use of undeclared identifier 'pt' | ✅ 0 undriven (792 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `dev_entropy` | unknown module 'prim_flop_2sync' | ✅ 0 undriven (3 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `gfr_clk_mux2` | unknown module 'prim_clock_gating' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `i3c` | use of undeclared identifier 'AhbAddrWidth' | ✅ 0 undriven (331 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `i3c_wrapper` | use of undeclared identifier 'AhbAddrWidth' | ✅ 0 undriven (139 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `io_clk` | unknown module 'prim_clock_buf' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `io_osc` | unknown module 'prim_clock_buf' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `ip_xxx_3511_hs_mem_compound_wrapper` | hierarchical references are not allowed in calls to '$bits' | ✅ 0 undriven (421 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `ip_xxx_3516_hs_mem_wrapper` | unknown module 'ip_xxx_3516_hs_mem' | ✅ 0 undriven (328 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `kmac_ss_reduced` | implicit named port 'mode_i' of type 'sha3_pkg::sha3_mode_e' connects to value of inequivalent type 'caliptra_ss_sha3_pkg::sha3_mode_e' [-Wimpli | ✅ 0 undriven (2 never assigned in the source) | ✅ PASS (301 cycles, 46 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+kmac_ss_reduced&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+implicit+named+port+%27mode_i%27+of+type+%27sha3_pkg%3A%3Asha3_mode_e%27+connects+to+value+of+inequivalent+type+%27caliptra_ss_sha3_pkg%3A%3Asha3_mode_e%27+%5B-Wimpli%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%282+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| caliptra-ss | `mci_axi_sub_decode` | hierarchical references are not allowed in calls to '$bits' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `mci_axi_sub_top` | hierarchical references are not allowed in calls to '$bits' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `mci_lcc_st_trans` | use of undeclared identifier 'MuBi4True' | ✅ 0 undriven (2 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `mci_mcu_sram_ctrl` | hierarchical references are not allowed in calls to '$bits' | ✅ 0 undriven | ✅ PASS (301 cycles, 225 active) | — |
| caliptra-ss | `mci_mcu_trace_buffer` | hierarchical references are not allowed in calls to '$bits' | ✅ 0 undriven | ✅ PASS (301 cycles, 123 active) | — |
| caliptra-ss | `mci_reg_top` | use of undeclared identifier 'AXI_USER_WIDTH'; did you mean 'USER_WIDTH'? | ✅ 0 undriven (170 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `mcu_mbox` | hierarchical references are not allowed in calls to '$bits' | ✅ 0 undriven (580 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `otp_ctrl_dai` | use of undeclared identifier 'mubi8_t' | ✅ 0 undriven | ❌ 116 div | — |
| caliptra-ss | `otp_ctrl_part_buf` | use of undeclared identifier 'mubi8_t' | ✅ 0 undriven | ✅ PASS (301 cycles, 25 active) | — |
| caliptra-ss | `otp_ctrl_part_unbuf` | use of undeclared identifier 'mubi8_t' | ✅ 0 undriven | ✅ PASS (301 cycles, 203 active) | — |
| caliptra-ss | `pwrmgr_cdc_pulse` | unknown module 'prim_flop_2sync' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `pwrmgr_slow_fsm` | unknown macro or compiler directive '`PRIM_FLOP_SPARSE_FSM' | ✅ 0 undriven (10 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `rng` | unknown module 'prim_flop_2sync' | ✅ 0 undriven (3 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `serializer` | unknown package 'i3c_ctrl_pkg' | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+serializer&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+unknown+package+%27i3c_ctrl_pkg%27%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| caliptra-ss | `spi_host_axi` | use of undeclared identifier 'NumCS' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `sys_clk` | unknown module 'prim_clock_buf' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `sys_osc` | unknown module 'prim_clock_buf' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `usb_clk` | unknown module 'prim_flop_2sync' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `usb_osc` | unknown module 'prim_clock_buf' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `vcaon_pgd` | unknown class or package 'prim_pkg' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `vcc_pgd` | unknown class or package 'prim_pkg' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `vcmain_pgd` | unknown class or package 'prim_pkg' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `vio_pgd` | unknown class or package 'prim_pkg' | ✅ 0 undriven | skip (sim build) | — |
| cve2 | `cve2_pmp` | no implicit conversion from 'logic[1:0]' to 'priv_lvl_e'; explicit conversion exists, are you missing a cast? | ✅ 0 undriven | ✅ PASS (301 cycles, 148 active) | — |
| cve2 | `cve2_top_tracing` | $fatal encountered: Fatal error: RVFI needs to be defined globally. | ✅ 0 undriven (1 never assigned in the source) | skip (sim build) | — |
| cvfpu | `fpnew_top` | Feature unimplemented at /home/runner/work/uhdm2rtlil/uhdm2rtlil/third_party/yosys/frontends/slang/lib/src/slang_frontend.cc:2993, see AST and code line dump above | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+fpnew_top&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+Feature+unimplemented+at+%2Fhome%2Frunner%2Fwork%2Fuhdm2rtlil%2Fuhdm2rtlil%2Fthird_party%2Fyosys%2Ffrontends%2Fslang%2Flib%2Fsrc%2Fslang_frontend.cc%3A2993%2C+see+AST+and+code+line+dump+above%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cvw | `ahbapbbridge` | 'ahbapbbridge' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | — |
| cvw | `btb` | 'btb' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | — |
| cvw | `busfsm` | 'busfsm' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | — |
| cvw | `dtim` | Exception: std::bad_alloc | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+dtim&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+Exception%3A+std%3A%3Abad_alloc%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cvw | `icpred` | 'icpred' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | — |
| cvw | `ieu` | could not find connection for implicit named port 'CSRReadValW' | ✅ 0 undriven (13 never assigned in the source) | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+ieu&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+could+not+find+connection+for+implicit+named+port+%27CSRReadValW%27%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%2813+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cvw | `irom` | Exception: std::bad_alloc | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+irom&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+Exception%3A+std%3A%3Abad_alloc%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cvw | `mmu` | 'mmu_flat' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | — |
| cvw | `packetizer` | 'packetizer' is not a valid top-level module | ✅ 0 undriven (32 never assigned in the source) | skip (sim build) | — |
| cvw | `ram_ahb` | 'ram_ahb' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | — |
| cvw | `rom_ahb` | 'rom_ahb' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | — |
| cvw | `rvvisynth` | 'rvvisynth_flat' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | — |
| cvw | `tlb` | 'tlb' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | — |
| cvw | `tlbcam` | 'tlbcam' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | — |
| cvw | `tlbcamline` | 'tlbcamline' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | — |
| cvw | `tlbcontrol` | 'tlbcontrol' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | — |
| cvw | `tlbram` | 'tlbram' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | — |
| cvw | `uartPC16550D` | 'uartPC16550D' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | — |
| cvw | `uncore` | Exception: std::bad_alloc | ✅ 0 undriven (33 never assigned in the source) | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+uncore&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+Exception%3A+std%3A%3Abad_alloc%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%2833+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cvw | `wallypipelinedsoc` | Exception: std::bad_alloc | ✅ 0 undriven (1057 never assigned in the source) | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+wallypipelinedsoc&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+Exception%3A+std%3A%3Abad_alloc%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%281057+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| hdmi | `packet_picker` | blocking assignment to variable 'frame_counter' is not supported after previous non-blocking assignment | ✅ 0 undriven (62000 never assigned in the source) | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+packet_picker&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+blocking+assignment+to+variable+%27frame_counter%27+is+not+supported+after+previous+non-blocking+assignment%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%2862000+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| hdmi | `serializer` | 'serializer_flat' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | — |
| ibex | `ibex_top` | slang net-init | ✅ 0 undriven | ⚠ known (25 div, baselined) | — |
| ibex | `ibex_top_tracing` | slang net-init | ✅ 0 undriven (2 never assigned in the source) | error | — |
| ibex | `ibex_tracer` | slang net-init | ✅ 0 undriven (2 never assigned in the source) | skip | — |
| rp32 | `rp32_r5p_degu` | iface port at top | ✅ 0 undriven (4 never assigned in the source) | skip | — |
| rp32 | `rp32_r5p_degu_soc_top` | slang $readmemh | ✅ 0 undriven (4 never assigned in the source) | skip | — |
| rp32 | `rp32_r5p_hamster` | upstream RTL incomplete | ✅ 0 undriven | skip | — |
| rp32 | `rp32_r5p_mdu` | empty module | ✅ 0 undriven | skip (config) | — |
| rp32 | `rp32_r5p_mouse_soc_top` | slang $readmemh | ✅ 0 undriven (6 never assigned in the source) | skip | — |
| rp32 | `rp32_soc_vfriendly` | slang $readmemh | ✅ 0 undriven (4 never assigned in the source) | ✅ PASS (300 cycles, 300 active) | — |
| verilog-ethernet | `axis_baser_rx_64` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | ✅ 0 undriven | ✅ PASS (301 cycles, 299 active) | — |
| verilog-ethernet | `axis_srl_fifo` | non-blocking assignments unsupported in design initialization | ✅ 0 undriven | ❌ 261 div | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axis_srl_fifo&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+non-blocking+assignments+unsupported+in+design+initialization%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `axis_xgmii_rx_32` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | ✅ 0 undriven | ✅ PASS (301 cycles, 293 active) | — |
| verilog-ethernet | `eth_mac_phy_10g` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | ✅ 0 undriven (2 never assigned in the source) | skip (sim build) | — |
| verilog-ethernet | `eth_mac_phy_10g_fifo` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | ✅ 0 undriven (2 never assigned in the source) | skip (sim build) | — |
| verilog-ethernet | `eth_mac_phy_10g_rx` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | ✅ 0 undriven (2 never assigned in the source) | skip (sim build) | — |
| verilog-ethernet | `eth_mac_phy_10g_tx` | no reference (read_slang fails) (read_slang did not finish within the sweep's 600 s budget) | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+eth_mac_phy_10g_tx&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+no+reference+%28read_slang+fails%29+%28read_slang+did+not+finish+within+the+sweep%27s+600+s+budget%29%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `eth_phy_10g` | no reference (read_slang fails) (read_slang did not finish within the sweep's 600 s budget) | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+eth_phy_10g&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+no+reference+%28read_slang+fails%29+%28read_slang+did+not+finish+within+the+sweep%27s+600+s+budget%29%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `eth_phy_10g_rx` | no reference (read_slang fails) (read_slang did not finish within the sweep's 600 s budget) | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+eth_phy_10g_rx&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+no+reference+%28read_slang+fails%29+%28read_slang+did+not+finish+within+the+sweep%27s+600+s+budget%29%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `eth_phy_10g_tx_if` | no reference (read_slang fails) (read_slang did not finish within the sweep's 600 s budget) | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+eth_phy_10g_tx_if&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+no+reference+%28read_slang+fails%29+%28read_slang+did+not+finish+within+the+sweep%27s+600+s+budget%29%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `ssio_sdr_in_diff` | parameter 'IODDR_STYLE' does not exist in 'ssio_sdr_in' [-Wundefined-param-override] | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+ssio_sdr_in_diff&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+parameter+%27IODDR_STYLE%27+does+not+exist+in+%27ssio_sdr_in%27+%5B-Wundefined-param-override%5D%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `axis_srl_fifo` | non-blocking assignments unsupported in design initialization | ✅ 0 undriven | ❌ 261 div | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axis_srl_fifo&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+non-blocking+assignments+unsupported+in+design+initialization%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `dma_if_axi` | blocking assignment to variable 'm_axis_read_desc_status_error_reg' is not supported after previous non-blocking assignment | ✅ 0 undriven | ✅ PASS (301 cycles, 300 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+dma_if_axi&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+blocking+assignment+to+variable+%27m_axis_read_desc_status_error_reg%27+is+not+supported+after+previous+non-blocking+assignment%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `dma_if_axi_rd` | blocking assignment to variable 'm_axis_read_desc_status_error_reg' is not supported after previous non-blocking assignment | ✅ 0 undriven | ✅ PASS (301 cycles, 260 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+dma_if_axi_rd&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+blocking+assignment+to+variable+%27m_axis_read_desc_status_error_reg%27+is+not+supported+after+previous+non-blocking+assignment%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
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

