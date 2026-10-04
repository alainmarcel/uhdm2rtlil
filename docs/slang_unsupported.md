# Designs `read_slang` cannot read

**49** modules across the nightly IP sweeps cannot be elaborated by
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
project setup declines.  Only the first group is a report about slang,
and a row reaches it on one condition: Verilator builds the module and
`read_uhdm` co-simulates it cleanly, so two tools handle what read_slang
declines.  A row no tool has yet built and co-simulated proves nothing
about slang -- it is a module nobody supports, or a harness gap -- and it
stays in the third group until it does.

**49** of the 49 are read and elaborated by `read_uhdm` with every
net driven, and **18** also co-simulate the RTL cleanly.  (read_uhdm now
refuses an instance of a module that has no definition, so a design missing
its sources fails on both sides.)  For the
rest Verilator cannot build a testbench standalone — a vendor primitive, an
interface port no port-by-port testbench can drive — which is a harness
limit, not a verdict on either frontend.


## What read_slang declines

These are read_slang's own limits: every one of them is a construct the
other two frontends accept, and each row below carries a pre-filled issue
link.

| Construct | Modules | Sweeps |
|---|---|---|
| an out-of-range select in code a parameter makes dead -- yet Verilator builds it and read_uhdm co-simulates it cleanly | 3 | verilog-ethernet |
| an elaboration-time `$error`/`$fatal` the design guards with parameters -- yet Verilator builds it and read_uhdm co-simulates it cleanly | 2 | axi |
| a non-blocking assignment in an initial block | 2 | verilog-ethernet, verilog-pcie |
| a blocking assignment to a variable a non-blocking one already wrote | 2 | verilog-pcie |
| a memory image the checkout does not contain (`$readmemh` of a missing file) -- yet Verilator builds it and read_uhdm co-simulates it cleanly | 1 | rp32 |

## What the design, the checkout, or our own project setup declines

Not read_slang's doing.  A module the repository never shipped (OpenTitan
primitives vendored without their `prim_*` library), a configuration the
design itself rejects, RTL the upstream left unfinished -- and, where a
row still shows a package, macro, unroll limit or interface port, a gap
in the project WE hand the tools, which is ours to close and never an
issue to file.  read_uhdm used to read several of these only because
Surelog is quieter about a missing file; it now refuses an instance of a
module that has no definition and names the module, so such a row shows
a read failure on both sides until the source is supplied.

| Construct | Modules | Sweeps |
|---|---|---|
| no answer inside the sweep's time budget (a read_slang performance limit) -- and no tool has yet built and co-simulated it | 5 | verilog-ethernet |
| a memory image the checkout does not contain (`$readmemh` of a missing file) | 3 | caliptra-ss, rp32 |
| an assignment pattern it judges incomplete -- and no tool has yet built and co-simulated it | 2 | axi |
| an out-of-range select in code a parameter makes dead | 2 | verilog-ethernet |
| nothing to compare (the upstream RTL is incomplete, or the module is empty) | 2 | rp32 |
| an internal assertion inside read_slang (a crash, not a rejection) -- and no tool has yet built and co-simulated it | 1 | axi |
| a macro the sweep's include set does not define for it | 1 | caliptra-ss |
| a module it cannot find in the closure the sweep gives it | 1 | caliptra-ss |
| an elaboration-time `$error`/`$fatal` the design guards with parameters | 1 | cve2 |
| an sv-elab construct marked unimplemented -- and no tool has yet built and co-simulated it | 1 | cvfpu |
| a blocking assignment to a variable a non-blocking one already wrote -- and no tool has yet built and co-simulated it | 1 | hdmi |
| an interface port on the top module | 1 | rp32 |

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
| other | 8 | caliptra-ss, cvw, verilog-ethernet |

## Every row

`read_uhdm` columns are blank where the row has not been re-measured yet.

| Sweep | Module | `read_slang` says | read_uhdm: undriven | read_uhdm vs RTL | Report |
|---|---|---|---|---|---|
| axi | `axi_chan_logger` | Assert `vbit.variable.kind == Variable::Static' failed in /home/runner/work/uhdm2rtlil/uhdm2rtlil/third_party/yosys/frontends/slang/lib/src/slang_frontend.cc:515. | ✅ 0 undriven | skip (no run) | — |
| axi | `axi_fifo_delay_dyn` | $fatal encountered: Delay unit is not made for synthesis | ✅ 0 undriven | ✅ PASS (301 cycles, 11 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axi_fifo_delay_dyn&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+%24fatal+encountered%3A+Delay+unit+is+not+made+for+synthesis%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| axi | `axi_fifo_delay_dyn_intf` | $fatal encountered: Delay unit is not made for synthesis | ✅ 0 undriven | ✅ PASS (301 cycles, 276 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axi_fifo_delay_dyn_intf&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+%24fatal+encountered%3A+Delay+unit+is+not+made+for+synthesis%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| axi | `axi_lite_to_apb` | not all elements of array are covered by an assignment pattern key | ✅ 0 undriven | skip (sim build) | — |
| axi | `axi_to_apb` | not all elements of array are covered by an assignment pattern key | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `adc` | unknown macro or compiler directive '`ASSERT' | ✅ 0 undriven | skip (sim build) | — |
| caliptra-ss | `counter_template` | unknown package 'i3c_ctrl_pkg' | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+counter_template&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+unknown+package+%27i3c_ctrl_pkg%27%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| caliptra-ss | `css_mcu0_el2_ifu_tb_memread` | failed to open file 'left64k' | ✅ 0 undriven | skip (no run) | — |
| caliptra-ss | `ip_xxx_3511_hs_mem_compound_wrapper` | hierarchical references are not allowed in calls to '$bits' | ✅ 0 undriven (449 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `ip_xxx_3516_hs_mem_wrapper` | unknown module 'ip_xxx_3516_hs_mem' | ✅ 0 undriven (328 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `kmac_ss_reduced` | implicit named port 'mode_i' of type 'sha3_pkg::sha3_mode_e' connects to value of inequivalent type 'caliptra_ss_sha3_pkg::sha3_mode_e' [-Wimpli | ✅ 0 undriven (2 never assigned in the source) | ✅ PASS (301 cycles, 46 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+kmac_ss_reduced&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+implicit+named+port+%27mode_i%27+of+type+%27sha3_pkg%3A%3Asha3_mode_e%27+connects+to+value+of+inequivalent+type+%27caliptra_ss_sha3_pkg%3A%3Asha3_mode_e%27+%5B-Wimpli%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%282+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| caliptra-ss | `mci_axi_sub_decode` | hierarchical references are not allowed in calls to '$bits' | ✅ 0 undriven | ✅ PASS (301 cycles, 300 active) | — |
| caliptra-ss | `mci_axi_sub_top` | hierarchical references are not allowed in calls to '$bits' | ✅ 0 undriven | ✅ PASS (301 cycles, 295 active) | — |
| caliptra-ss | `mci_mcu_sram_ctrl` | hierarchical references are not allowed in calls to '$bits' | ✅ 0 undriven | ✅ PASS (301 cycles, 225 active) | — |
| caliptra-ss | `mci_mcu_trace_buffer` | hierarchical references are not allowed in calls to '$bits' | ✅ 0 undriven | ✅ PASS (301 cycles, 123 active) | — |
| caliptra-ss | `mcu_mbox` | hierarchical references are not allowed in calls to '$bits' | ✅ 0 undriven (580 never assigned in the source) | skip (sim build) | — |
| caliptra-ss | `serializer` | unknown package 'i3c_ctrl_pkg' | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+serializer&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+unknown+package+%27i3c_ctrl_pkg%27%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cve2 | `cve2_pmp` | no implicit conversion from 'logic[1:0]' to 'priv_lvl_e'; explicit conversion exists, are you missing a cast? | ✅ 0 undriven | ✅ PASS (301 cycles, 148 active) | — |
| cve2 | `cve2_top_tracing` | $fatal encountered: Fatal error: RVFI needs to be defined globally. | ✅ 0 undriven (1 never assigned in the source) | skip (sim build) | — |
| cvfpu | `fpnew_top` | Feature unimplemented at /home/runner/work/uhdm2rtlil/uhdm2rtlil/third_party/yosys/frontends/slang/lib/src/slang_frontend.cc:2993, see AST and code line dump above | ✅ 0 undriven | skip (sim build) | — |
| cvw | `ieu` | could not find connection for implicit named port 'CSRReadValW' | ✅ 0 undriven (13 never assigned in the source) | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+ieu&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+could+not+find+connection+for+implicit+named+port+%27CSRReadValW%27%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%2813+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cvw | `irom` | Exception: std::bad_alloc | ✅ 0 undriven | ✅ PASS (301 cycles, 0 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+irom&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+Exception%3A+std%3A%3Abad_alloc%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cvw | `uncore` | Exception: std::bad_alloc | ✅ 0 undriven (33 never assigned in the source) | ✅ PASS (301 cycles, 53 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+uncore&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+Exception%3A+std%3A%3Abad_alloc%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%2833+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cvw | `wallypipelinedsoc` | Exception: std::bad_alloc | ✅ 0 undriven (33 never assigned in the source) | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+wallypipelinedsoc&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+Exception%3A+std%3A%3Abad_alloc%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%2833+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| hdmi | `packet_picker` | blocking assignment to variable 'frame_counter' is not supported after previous non-blocking assignment | ✅ 0 undriven (62000 never assigned in the source) | skip (sim build) | — |
| ibex | `ibex_top` | slang net-init | ✅ 0 undriven | ⚠ known (25 div, baselined) | — |
| ibex | `ibex_top_tracing` | slang net-init | ✅ 0 undriven (2 never assigned in the source) | error | — |
| ibex | `ibex_tracer` | slang net-init | ✅ 0 undriven (2 never assigned in the source) | skip | — |
| rp32 | `rp32_r5p_degu` | iface port at top | ✅ 0 undriven (4 never assigned in the source) | skip | — |
| rp32 | `rp32_r5p_degu_soc_top` | slang $readmemh | ✅ 0 undriven (4 never assigned in the source) | skip | — |
| rp32 | `rp32_r5p_hamster` | upstream RTL incomplete | ✅ 0 undriven | skip | — |
| rp32 | `rp32_r5p_mdu` | empty module | ✅ 0 undriven | skip (config) | — |
| rp32 | `rp32_r5p_mouse_soc_top` | slang $readmemh | ✅ 0 undriven (6 never assigned in the source) | skip | — |
| rp32 | `rp32_soc_vfriendly` | slang $readmemh | ✅ 0 undriven (4 never assigned in the source) | ✅ PASS (300 cycles, 300 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+rp32_soc_vfriendly&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+slang+%24readmemh%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%284+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `axis_baser_rx_64` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | ✅ 0 undriven | ✅ PASS (301 cycles, 299 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axis_baser_rx_64&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+cannot+select+range+of+96+elements+from+%27reg%5B0%3A0%5D%27+%5B-Wrange-width-oob%5D%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `axis_eth_fcs_insert_64` | no reference (read_slang fails) (read_slang did not finish within the sweep's 600 s budget) | ✅ 0 undriven | skip (sim build) | — |
| verilog-ethernet | `axis_srl_fifo` | non-blocking assignments unsupported in design initialization | ✅ 0 undriven | ✅ PASS (301 cycles, 212 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axis_srl_fifo&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+non-blocking+assignments+unsupported+in+design+initialization%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `axis_xgmii_rx_32` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | ✅ 0 undriven | ✅ PASS (301 cycles, 293 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axis_xgmii_rx_32&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+cannot+select+range+of+96+elements+from+%27reg%5B0%3A0%5D%27+%5B-Wrange-width-oob%5D%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `eth_mac_phy_10g` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | ✅ 0 undriven (2 never assigned in the source) | skip (sim build) | — |
| verilog-ethernet | `eth_mac_phy_10g_fifo` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | ✅ 0 undriven (2 never assigned in the source) | skip (sim build) | — |
| verilog-ethernet | `eth_mac_phy_10g_rx` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | ✅ 0 undriven (2 never assigned in the source) | ✅ PASS (301 cycles, 299 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+eth_mac_phy_10g_rx&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+cannot+select+range+of+96+elements+from+%27reg%5B0%3A0%5D%27+%5B-Wrange-width-oob%5D%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%282+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `eth_mac_phy_10g_tx` | no reference (read_slang fails) (read_slang did not finish within the sweep's 600 s budget) | ✅ 0 undriven | skip (sim build) | — |
| verilog-ethernet | `eth_phy_10g` | no reference (read_slang fails) (read_slang did not finish within the sweep's 600 s budget) | ✅ 0 undriven | error | — |
| verilog-ethernet | `eth_phy_10g_rx_if` | no reference (read_slang fails) (read_slang did not finish within the sweep's 600 s budget) | ✅ 0 undriven | skip (sim build) | — |
| verilog-ethernet | `eth_phy_10g_tx` | no reference (read_slang fails) (read_slang did not finish within the sweep's 600 s budget) | ✅ 0 undriven | skip (sim build) | — |
| verilog-ethernet | `ssio_sdr_in_diff` | parameter 'IODDR_STYLE' does not exist in 'ssio_sdr_in' [-Wundefined-param-override] | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+ssio_sdr_in_diff&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+parameter+%27IODDR_STYLE%27+does+not+exist+in+%27ssio_sdr_in%27+%5B-Wundefined-param-override%5D%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `axis_srl_fifo` | non-blocking assignments unsupported in design initialization | ✅ 0 undriven | ✅ PASS (301 cycles, 212 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axis_srl_fifo&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+non-blocking+assignments+unsupported+in+design+initialization%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `dma_if_axi` | blocking assignment to variable 'm_axis_read_desc_status_error_reg' is not supported after previous non-blocking assignment | ✅ 0 undriven | ✅ PASS (301 cycles, 300 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+dma_if_axi&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+blocking+assignment+to+variable+%27m_axis_read_desc_status_error_reg%27+is+not+supported+after+previous+non-blocking+assignment%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `dma_if_axi_rd` | blocking assignment to variable 'm_axis_read_desc_status_error_reg' is not supported after previous non-blocking assignment | ✅ 0 undriven | ✅ PASS (301 cycles, 260 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+dma_if_axi_rd&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+blocking+assignment+to+variable+%27m_axis_read_desc_status_error_reg%27+is+not+supported+after+previous+non-blocking+assignment%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |

---

Regenerate with `test/slang_unsupported_report.py` after a sweep cycle.
A row leaves this file the moment `read_slang` can read the design.

