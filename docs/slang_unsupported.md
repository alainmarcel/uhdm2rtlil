# Designs `read_slang` cannot read

**360** modules across the nightly IP sweeps cannot be elaborated by
`read_slang` at all.  They carry no formal verdict for a plain reason: the
sweeps prove `read_uhdm` against `read_slang`, and there is nothing to prove
against.  They are not failures of this frontend — `read_uhdm` reads them —
and they are the part of the corpus the other report cannot see, because a
divergence needs two netlists.

Until 2026-09-29 the sweep abandoned such a row entirely: no undriven check,
no co-simulation, nothing recorded either way.  The behavioural RTL is still
there and neither measurement needs slang, so each row now carries a
`read_uhdm` verdict: whether every net is driven, and whether our netlist
tracks the RTL under Verilator.

Of the 360: **28** are confirmed read and elaborated by
`read_uhdm` with every net driven, and **8** of those also
co-simulate the RTL cleanly.  The rest are still being measured, or their
RTL cannot be built standalone by Verilator (a vendor primitive, an
interface port no port-by-port testbench can drive) — a harness limit, not
a verdict.


## What slang is missing, by construct

| Construct `read_slang` declines | Modules | Sweeps |
|---|---|---|
| refuses the module as a top level (usually an unbound interface or an unresolved parameter) | 147 | caliptra-ss, common_cells, cvw, hdmi |
| an interface port on the top module | 40 | axi, caliptra-ss, rp32 |
| other | 23 | axi, caliptra-ss, verilog-ethernet, verilog-pcie, xiangshan |
| a module it cannot find in the closure the sweep gives it | 22 | caliptra-ss, cvw, hdmi |
| a dimension it evaluates as non-positive | 20 | axi, hdmi, verilog-pcie |
| a file the sweep's closure does not hand it | 14 | caliptra-ss |
| an out-of-range select in code a parameter makes dead | 12 | axi, verilog-ethernet |
| a generate/for construct past its unroll limit | 12 | axi, verilog-ethernet, verilog-pcie |
| an implicit struct/vector conversion it rejects | 11 | axi, cve2 |
| a package or class it cannot resolve | 11 | axi, caliptra-ss |
| an elaboration-time `$error`/`$fatal` the design guards with parameters | 9 | axi, caliptra-ss, common_cells, cve2 |
| a macro the sweep's include set does not define for it | 8 | caliptra-ss |
| an identifier it does not resolve in that scope | 6 | axi, caliptra-ss |
| a parameter whose default carries `x` bits | 4 | axi |
| a non-blocking assignment in an initial block | 4 | verilog-ethernet, verilog-pcie |
| a net-declaration initialiser it does not lower | 3 | ibex |
| nothing to compare (the upstream RTL is incomplete, or the module is empty) | 3 | rp32 |
| `$readmemh` / `$readmemb` | 3 | rp32 |
| a hierarchical reference in a constant expression (`$bits(iface.member)`) | 3 | caliptra-ss |
| an assignment pattern it judges incomplete | 2 | axi |
| a port it does not find on a child module | 2 | xiangshan |
| an sv-elab construct marked unimplemented | 1 | cvfpu |

## Every row

`read_uhdm` columns are blank where the row has not been re-measured yet.

| Sweep | Module | `read_slang` says | read_uhdm: undriven | read_uhdm vs RTL | Report |
|---|---|---|---|---|---|
| axi | `axi_atop_filter_intf` | top-level module 'axi_atop_filter_intf' has unconnected interface port 'slv' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_cdc_dst` | no implicit conversion from 'logic[1167:0]' to 'async_data_slave_aw_data_i_t' (aka 'axi_aw_chan_t$[15:0]' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_cdc_dst_intf` | top-level module 'axi_cdc_dst_intf' has unconnected interface port 'src' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_cdc_intf` | top-level module 'axi_cdc_intf' has unconnected interface port 'src' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_cdc_src` | no implicit conversion from 'async_data_master_aw_data_o_t' (aka 'axi_aw_chan_t$[15:0]' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_cdc_src_intf` | top-level module 'axi_cdc_src_intf' has unconnected interface port 'src' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_chan_logger` | Assert `vbit.variable.kind == Variable::Static' failed in /home/runner/work/uhdm2rtlil/uhdm2rtlil/third_party/ | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_cut_intf` | top-level module 'axi_cut_intf' has unconnected interface port 'in' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_delayer_intf` | top-level module 'axi_delayer_intf' has unconnected interface port 'slv' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_demux` | no implicit conversion from 'mst_reqs_o_t' (aka 'axi_req_t$[1:0]' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_demux_id_counters` | unknown class or package 'axi_pkg' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_demux_intf` | top-level module 'axi_demux_intf' has unconnected interface port 'slv' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_demux_simple` | no implicit conversion from 'mst_reqs_o_t' (aka 'axi_req_t$[1:0]' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_dw_converter_intf` | top-level module 'axi_dw_converter_intf' has unconnected interface port 'slv' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_fifo_delay_dyn` | $fatal encountered: Delay unit is not made for synthesis | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_fifo_delay_dyn_intf` | top-level module 'axi_fifo_delay_dyn_intf' has unconnected interface port 'slv' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_fifo_intf` | top-level module 'axi_fifo_intf' has unconnected interface port 'slv' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_id_prepend` | unknown class or package 'axi_pkg' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_id_remap_intf` | value must be positive | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_id_serialize_intf` | value must be positive | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_interleaved_xbar_intf` | top-level module 'axi_interleaved_xbar_intf' has unconnected interface port 's | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_inval_filter` | unknown class or package 'axi_pkg' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_isolate_intf` | top-level module 'axi_isolate_intf' has unconnected interface port 'slv' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_iw_converter_intf` | top-level module 'axi_iw_converter_intf' has unconnected interface port 'slv' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_join_intf` | top-level module 'axi_join_intf' has unconnected interface port 'in' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_cdc_dst_intf` | top-level module 'axi_lite_cdc_dst_intf' has unconnected interface port 'src' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_cdc_intf` | top-level module 'axi_lite_cdc_intf' has unconnected interface port 'src' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_cdc_src_intf` | top-level module 'axi_lite_cdc_src_intf' has unconnected interface port 'src' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_cut_intf` | top-level module 'axi_lite_cut_intf' has unconnected interface port 'in' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_demux` | no implicit conversion from 'mst_reqs_o_t' (aka 'axi_req_t$[1:0]' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_demux_intf` | top-level module 'axi_lite_demux_intf' has unconnected interface port 'slv' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_dw_converter_intf` | top-level module 'axi_lite_dw_converter_intf' has unconnected interface port | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_join_intf` | top-level module 'axi_lite_join_intf' has unconnected interface port 'in' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_mailbox` | no implicit conversion from 'logic[293:0]' to 'slv_reqs_i_t' (aka 'axi_lite_req_t$[1:0]' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_mailbox_intf` | cannot select range of 8 elements from 'data_t' (aka 'logic[-1:0]' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_multicut_intf` | top-level module 'axi_lite_multicut_intf' has unconnected interface port 'in' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_mux` | no implicit conversion from 'logic[439:0]' to 'slv_reqs_i_t' (aka 'axi_req_t$[1:0]' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_mux_intf` | top-level module 'axi_lite_mux_intf' has unconnected interface port 'slv' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_regs` | no implicit conversion from 'logic[31:0]' to 'reg_d_i_t' (aka 'logic[7:0]$[3:0]' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_regs_intf` | cannot select range of 8 elements from 'data_t' (aka 'logic[-1:0]' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_to_apb` | not all elements of array are covered by an assignment pattern key | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_to_axi_intf` | top-level module 'axi_lite_to_axi_intf' has unconnected interface port 'in' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_lite_xbar_intf` | top-level module 'axi_lite_xbar_intf' has unconnected interface port 'slv_ports' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_modify_address_intf` | top-level module 'axi_modify_address_intf' has unconnected interface port 'slv' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_multicut_intf` | top-level module 'axi_multicut_intf' has unconnected interface port 'in' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_mux` | cannot select range of [4:4] from 'id_t' (aka 'logic[3:0]' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_mux_intf` | value must be positive | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_opt_lfsr` | unroll limit of 4000 exhausted [--unroll-limit=] | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_rw_join` | unknown class or package 'axi_pkg' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_rw_split` | unknown class or package 'axi_pkg' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_serializer_intf` | top-level module 'axi_serializer_intf' has unconnected interface port 'slv' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_throttle` | unknown class or package 'axi_pkg' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_apb` | not all elements of array are covered by an assignment pattern key | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_axi_lite_intf` | value must be positive | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_detailed_mem` | use of undeclared identifier 'addr_t' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_detailed_mem_intf` | value must not have any unknown bits | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_mem` | use of undeclared identifier 'addr_t' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_mem_banked` | cannot select range of [36:5] from 'axi_addr_t' (aka 'logic[31:0]' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_mem_banked_intf` | value must not have any unknown bits | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_mem_interleaved` | no implicit conversion from 'mem_addr_o_t' (aka 'logic[31:0]$[1:0]' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_mem_intf` | value must not have any unknown bits | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_mem_split` | no implicit conversion from 'mem_addr_o_t' (aka 'logic[31:0]$[1:0]' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_to_mem_split_intf` | value must not have any unknown bits | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_xbar_intf` | top-level module 'axi_xbar_intf' has unconnected interface port 'slv_ports' | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_xp` | implicit named port 'addr_map_i' of type 'rule_t[3:0]' connects to value of inequivalent type | — (not measured yet) | — (not measured yet) | — |
| axi | `axi_xp_intf` | top-level module 'axi_xp_intf' has unconnected interface port 'slv_ports' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `adc` | unknown macro or compiler directive '`ASSERT' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `and` | 'and' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `aon_clk` | unknown module 'prim_clock_buf' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `aon_osc` | unknown module 'prim_clock_buf' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `ast` | unknown macro or compiler directive '`ASSERT' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `ast_clks_byp` | 'prim_assert.sv': No such file or directory | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `ast_dft` | 'prim_assert.sv': No such file or directory | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `ast_entropy` | unknown module 'prim_flop_2sync' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `ast_pulse_sync` | 'prim_assert.sv': No such file or directory | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `ast_reg_top` | 'prim_assert.sv': No such file or directory | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `axi2tlul` | top-level module 'axi2tlul' has unconnected interface port 's_axi_w_if | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `axi_adapter` | top-level module 'axi_adapter_flat' has unconnected interface port 's_axi_r_if' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `axi_mem` | top-level module 'axi_mem' has unconnected interface port 's_axi_w_if' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `axi_mem_if` | 'axi_mem_if' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `axi_to_ahb` | top-level module 'axi_to_ahb' has unconnected in | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `axilite_to_ahb` | top-level module 'axilite_to_ahb' has unconn | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `bus_rx_flow` | unknown macro or compiler directive '`I3C_ASSERT' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `caliptra_ss_top` | top-level module 'caliptra_ss_top' has unconnected interface | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `caliptra_ss_top_w_stub` | hierarchical references are not allowed in calls to '$bits' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `cif_if` | 'cif_if' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `controller` | unknown macro or compiler directive '`I3C_ASSERT' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `controller_standby` | unknown macro or compiler directive '`I3C_ASSERT' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `controller_standby_i3c` | unknown macro or compiler directive '`I3C_ASSERT' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `counter_template` | unknown package 'i3c_ctrl_pkg' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_EL2_IC_DATA` | top-level module 'css_mcu0_EL2_I | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_EL2_IC_TAG` | top-level module 'css_mcu0_EL2_I | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_el2_ifu_ic_mem` | top-level module 'css_mcu0_el2_if | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_el2_ifu_iccm_mem` | top-level module 'css_mcu0_el2_ | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_el2_ifu_tb_memread` | failed to open file 'left64k' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_el2_lsu_dccm_mem` | top-level module 'css_mcu0_el2_ | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_el2_mem` | top-level module 'css_mcu0_el2_mem' has unco | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_el2_mem_if` | 'css_mcu0_el2_mem_if' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_el2_veer_wrapper` | top-level module 'css_mcu0_el2_vee | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_ram_` | 'css_mcu0_ram_' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_ram_be_` | 'css_mcu0_ram_be_' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_rvdffe` | $error encountered: css_mcu0_rvdffe.gen_ | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_rvdffie` | $error encountered: css_mcu0_rvdffie.gen | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `css_mcu0_rvdffiee` | $error encountered: css_mcu0_rvdffiee.ge | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `dev_entropy` | unknown module 'prim_flop_2sync' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `gfr_clk_mux2` | unknown module 'prim_clock_gating' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `i3c` | top-level module 'i3c_flat' has unconnected interface port 's_axi_r_if' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `i3c_wrapper` | top-level module 'i3c_wrapper_flat' has unconnected interface port 's_axi_r_if' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `io_clk` | unknown module 'prim_clock_buf' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `io_osc` | unknown module 'prim_clock_buf' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `ip_xxx_3511_hs_mem_compound_wrapper` | top-level module 'ip_xx | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `ip_xxx_3516_hs_mem_wrapper` | unknown module 'ip_xxx_3516_hs_m | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `mci_axi_sub_decode` | top-level module 'mci_axi_sub_decode' has unconnected interface p | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `mci_axi_sub_top` | hierarchical references are not allowed in calls to '$bits' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `mci_lcc_st_trans` | use of undeclared identifier 'MuBi4True' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `mci_mcu_sram_ctrl` | top-level module 'mci_mcu_sram_ctrl' has unconnected interface por | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `mci_mcu_sram_if` | 'mci_mcu_sram_if' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `mci_mcu_trace_buffer` | top-level module 'mci_mcu_trace_buffer' has unconnected interfa | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `mci_reg_top` | top-level module 'mci_reg_top' has unconnected interface port 'cif_resp | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `mci_top` | hierarchical references are not allowed in calls to '$bits' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `mcu_mbox` | top-level module 'mcu_mbox' has unconnected interface port 'cif_resp_if' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `otp_ctrl_dai` | use of undeclared identifier 'mubi8_t' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `otp_ctrl_part_buf` | use of undeclared identifier 'mubi8_t' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `otp_ctrl_part_unbuf` | use of undeclared identifier 'mubi8_t' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `pwrmgr` | 'prim_assert.sv': No such file or directory | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `pwrmgr_cdc` | 'prim_assert.sv': No such file or directory | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `pwrmgr_cdc_pulse` | 'prim_assert.sv': No such file or directory | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `pwrmgr_fsm` | 'prim_assert.sv': No such file or directory | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `pwrmgr_slow_fsm` | 'prim_assert.sv': No such file or directory | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `pwrmgr_wake_info` | 'prim_assert.sv': No such file or directory | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `recovery_handler` | unknown macro or compiler directive '`I3C_A | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `recovery_receiver` | unknown macro or compiler directive '`I3C_A | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `rglts_pdm_3p3v` | 'prim_assert.sv': No such file or directory | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `rng` | 'prim_assert.sv': No such file or directory | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `serializer` | unknown package 'i3c_ctrl_pkg' | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+serializer&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+unknown+package+%27i3c_ctrl_pkg%27%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| caliptra-ss | `spi_host_axi` | top-level module 'spi_host_axi' has unconnected interface port 's_ | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `sys_clk` | unknown module 'prim_clock_buf' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `sys_osc` | unknown module 'prim_clock_buf' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `tlul_adapter_dmi` | 'prim_assert.sv': No such file or directory | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `tlul_jtag_dtm` | unknown class or package 'prim_mubi_pkg' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `uart_axi` | top-level module 'uart_axi' has unconnected interface port 's_axi_w_if' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `usb_clk` | 'prim_assert.sv': No such file or directory | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `usb_osc` | unknown module 'prim_clock_buf' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `vcaon_pgd` | unknown class or package 'prim_pkg' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `vcc_pgd` | unknown class or package 'prim_pkg' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `vcmain_pgd` | unknown class or package 'prim_pkg' | — (not measured yet) | — (not measured yet) | — |
| caliptra-ss | `vio_pgd` | unknown class or package 'prim_pkg' | — (not measured yet) | — (not measured yet) | — |
| common_cells | `cc_cdc_2phase_clearable_dst` | $error encountered: The clearable 2-phase CDC with async resetsynch | ✅ 0 undriven | ✅ PASS (201 cycles, 34 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+cc_cdc_2phase_clearable_dst&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+%24error+encountered%3A+The+clearable+2-phase+CDC+with+async+resetsynch%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| common_cells | `cc_cdc_2phase_clearable_src` | $error encountered: The clearable 2-phase CDC with async resetsynch | ✅ 0 undriven | ✅ PASS (201 cycles, 0 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+cc_cdc_2phase_clearable_src&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+%24error+encountered%3A+The+clearable+2-phase+CDC+with+async+resetsynch%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| common_cells | `cc_cdc_fifo_gray_clearable_dst` | $error encountered: The clearable CDC FIFO with async reset sync | ✅ 0 undriven | ✅ PASS (201 cycles, 2 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+cc_cdc_fifo_gray_clearable_dst&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+%24error+encountered%3A+The+clearable+CDC+FIFO+with+async+reset+sync%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| common_cells | `cc_cdc_fifo_gray_clearable_src` | $error encountered: The clearable CDC FIFO with async reset sync | ✅ 0 undriven | ✅ PASS (201 cycles, 0 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+cc_cdc_fifo_gray_clearable_src&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+%24error+encountered%3A+The+clearable+CDC+FIFO+with+async+reset+sync%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| common_cells | `cc_clk_or_tree` | 'cc_clk_or_tree' is not a valid top-level module | — | — | — |
| common_cells | `cc_stream_dv` | 'cc_stream_dv' is not a valid top-level module | — | — | — |
| common_cells | `tc_clk_delay` | 'tc_clk_delay' is not a valid top-level module | — | — | — |
| cve2 | `cve2_pmp` | no implicit conversion from 'logic[1:0]' to 'priv_lvl_e'; explicit conversion exists, are you missing a cast? | ✅ 0 undriven | ✅ PASS (201 cycles, 93 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+cve2_pmp&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+no+implicit+conversion+from+%27logic%5B1%3A0%5D%27+to+%27priv_lvl_e%27%3B+explicit+conversion+exists%2C+are+you+missing+a+cast%3F%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cve2 | `cve2_top_tracing` | $fatal encountered: Fatal error: RVFI needs to be defined globally. | ✅ 0 undriven (1 never assigned in the source) | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+cve2_top_tracing&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+%24fatal+encountered%3A+Fatal+error%3A+RVFI+needs+to+be+defined+globally.%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%281+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cvfpu | `fpnew_top` | Feature unimplemented at /home/runner/work/uhdm2rtlil/uhdm2rtlil/third_party/yosys/frontends/slang/lib/src/sla | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+fpnew_top&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+Feature+unimplemented+at+%2Fhome%2Frunner%2Fwork%2Fuhdm2rtlil%2Fuhdm2rtlil%2Fthird_party%2Fyosys%2Ffrontends%2Fslang%2Flib%2Fsrc%2Fsla%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| cvw | `RASPredictor` | 'RASPredictor' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `adrdec` | 'adrdec' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `adrdecs` | 'adrdecs' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `ahbapbbridge` | 'ahbapbbridge' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `ahbcacheinterface` | 'ahbcacheinterface' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `ahbinterface` | 'ahbinterface' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `align` | 'align' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `alu` | 'alu' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `amoalu` | 'amoalu' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `atomic` | 'atomic' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `binarytogray` | 'binarytogray' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `bitmanipalu` | 'bitmanipalu' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `bmuctrl` | 'bmuctrl' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `bpred` | 'bpred' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `btb` | 'btb' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `buscachefsm` | 'buscachefsm' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `busfsm` | 'busfsm' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `cache` | 'cache' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `cacheway` | 'cacheway' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `clint_apb` | 'clint_apb' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `controller` | 'controller' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `controllerinput` | 'controllerinput' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `csr` | 'csr_flat' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `csrc` | 'csrc' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `csri` | 'csri' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `csrm` | 'csrm_flat' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `csrs` | 'csrs' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `csrsr` | 'csrsr' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `csru` | 'csru' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `cvtshiftcalc` | 'cvtshiftcalc' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `datapath` | 'datapath' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `decompress` | 'decompress' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `div` | 'div' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `divshiftcalc` | 'divshiftcalc' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `divstep` | 'divstep' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `dtim` | 'dtim' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `ebu` | 'ebu' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `endianswap` | 'endianswap' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `extend` | 'extend' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fclassify` | 'fclassify' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fcmp` | 'fcmp' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fctrl` | 'fctrl' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fcvt` | 'fcvt' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fdivsqrt` | 'fdivsqrt' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fdivsqrtcycles` | 'fdivsqrtcycles' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fdivsqrtexpcalc` | 'fdivsqrtexpcalc' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fdivsqrtfgen2` | 'fdivsqrtfgen2' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fdivsqrtfgen4` | 'fdivsqrtfgen4' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fdivsqrtfsm` | 'fdivsqrtfsm' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fdivsqrtiter` | 'fdivsqrtiter' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fdivsqrtpostproc` | 'fdivsqrtpostproc' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fdivsqrtpreproc` | 'fdivsqrtpreproc' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fdivsqrtstage2` | 'fdivsqrtstage2' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fdivsqrtstage4` | 'fdivsqrtstage4' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fdivsqrtuotfc2` | 'fdivsqrtuotfc2' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fdivsqrtuotfc4` | 'fdivsqrtuotfc4' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `flags` | 'flags' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fli` | 'fli' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fma` | 'fma' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fmaadd` | 'fmaadd' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fmaalign` | 'fmaalign' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fmaexpadd` | 'fmaexpadd' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fmalza` | 'fmalza' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fmamult` | 'fmamult' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fmashiftcalc` | 'fmashiftcalc' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fmtparams` | 'fmtparams' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fpu` | 'fpu' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fregfile` | 'fregfile' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fround` | 'fround' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `fsgninj` | 'fsgninj' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `gpio_apb` | 'gpio_apb' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `graytobinary` | 'graytobinary' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `gshare` | 'gshare' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `gsharebasic` | 'gsharebasic' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `hptw` | 'hptw' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `icpred` | 'icpred' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `ieu` | 'ieu' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `ifu` | 'ifu_flat' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `irom` | 'irom' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `localaheadbp` | 'localaheadbp' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `localbpbasic` | 'localbpbasic' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `localrepairbp` | 'localrepairbp' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `lrsc` | 'lrsc' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `lsu` | 'lsu_flat' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `mdu` | 'mdu' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `mmu` | 'mmu_flat' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `mul` | 'mul' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `negateintres` | 'negateintres' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `normshift` | 'normshift' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `packetizer` | 'packetizer' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `packoutput` | 'packoutput' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `plic_apb` | 'plic_apb' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `pmachecker` | 'pmachecker' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `pmpadrdec` | 'pmpadrdec' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `pmpchecker` | 'pmpchecker_flat' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `postprocess` | 'postprocess' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `privdec` | 'privdec' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `privileged` | 'privileged_flat' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `privmode` | 'privmode' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `pwm_apb` | 'pwm_apb' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `ram1p1rwbe_64x128` | unknown module 'TS1N28HPCPSVTB64X128M4SW' | — (not measured yet) | — (not measured yet) | — |
| cvw | `ram1p1rwbe_64x22` | unknown module 'TS1N28HPCPSVTB64X44M4SW' | — (not measured yet) | — (not measured yet) | — |
| cvw | `ram1p1rwbe_64x44` | unknown module 'TS1N28HPCPSVTB64X44M4SW' | — (not measured yet) | — (not measured yet) | — |
| cvw | `ram2p1r1wbe_1024x36` | unknown module 'TSDN28HPCPA1024X68M4MW' | — (not measured yet) | — (not measured yet) | — |
| cvw | `ram2p1r1wbe_1024x68` | unknown module 'TSDN28HPCPA1024X68M4MW' | — (not measured yet) | — (not measured yet) | — |
| cvw | `ram2p1r1wbe_128x64` | unknown module 'TSDN28HPCPA128X64M4FW' | — (not measured yet) | — (not measured yet) | — |
| cvw | `ram2p1r1wbe_2048x64` | unknown module 'TSDN28HPCPA2048X64MMFW' | — (not measured yet) | — (not measured yet) | — |
| cvw | `ram2p1r1wbe_64x32` | unknown module 'TSDN28HPCPA64X32M4MW' | — (not measured yet) | — (not measured yet) | — |
| cvw | `ram_ahb` | 'ram_ahb' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `regfile` | 'regfile' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `rom1p1r_128x32` | unknown module 'generic64x128ROM' | — (not measured yet) | — (not measured yet) | — |
| cvw | `rom1p1r_128x64` | unknown module 'ts3n28hpcpa128x64m8m' | — (not measured yet) | — (not measured yet) | — |
| cvw | `rom_ahb` | 'rom_ahb' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `round` | 'round' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `rvvisynth` | 'rvvisynth_flat' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `shiftcorrection` | 'shiftcorrection' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `shifter` | 'shifter' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `specialcase` | 'specialcase' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `spi_apb` | 'spi_apb' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `spill` | 'spill' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `subcachelineread` | 'subcachelineread' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `subwordread` | 'subwordread' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `subwordwrite` | 'subwordwrite' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `swbytemask` | 'swbytemask' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `timereg` | 'timereg' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `timeregsync` | 'timeregsync' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `tlb` | 'tlb' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `tlbcam` | 'tlbcam' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `tlbcamline` | 'tlbcamline' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `tlbcontrol` | 'tlbcontrol' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `tlbmixer` | 'tlbmixer' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `tlbram` | 'tlbram' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `tlbramline` | 'tlbramline' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `trap` | 'trap' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `twoBitPredictor` | 'twoBitPredictor' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `uartPC16550D` | 'uartPC16550D' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `uart_apb` | 'uart_apb' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `uncore` | 'uncore' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `unpack` | 'unpack' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `unpackinput` | 'unpackinput' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `vm64check` | 'vm64check' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `wallypipelinedcore` | 'wallypipelinedcore' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `wallypipelinedsoc` | 'wallypipelinedsoc' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `zbc` | 'zbc' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `zknde32` | 'zknde32' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| cvw | `zknde64` | 'zknde64' is not a valid top-level module | — (not measured yet) | — (not measured yet) | — |
| hdmi | `hdmi` | unknown module 'OSERDESE2' | — | — | — |
| hdmi | `packet_picker` | value must be positive | ✅ 0 undriven (62000 never assigned in the source) | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+packet_picker&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+value+must+be+positive%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%2862000+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| hdmi | `serializer` | 'serializer_flat' is not a valid top-level module | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+serializer&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+%27serializer_flat%27+is+not+a+valid+top-level+module%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| ibex | `ibex_top` | slang net-init | — (not measured yet) | — (not measured yet) | — |
| ibex | `ibex_top_tracing` | slang net-init | — (not measured yet) | — (not measured yet) | — |
| ibex | `ibex_tracer` | slang net-init | — (not measured yet) | — (not measured yet) | — |
| rp32 | `rp32_r5p_csr` | upstream RTL incomplete | — (not measured yet) | — (not measured yet) | — |
| rp32 | `rp32_r5p_degu` | iface port at top | — (not measured yet) | — (not measured yet) | — |
| rp32 | `rp32_r5p_degu_soc_top` | slang $readmemh | — (not measured yet) | — (not measured yet) | — |
| rp32 | `rp32_r5p_hamster` | upstream RTL incomplete | — (not measured yet) | — (not measured yet) | — |
| rp32 | `rp32_r5p_mdu` | empty module | — (not measured yet) | — (not measured yet) | — |
| rp32 | `rp32_r5p_mouse_soc_top` | slang $readmemh | — (not measured yet) | — (not measured yet) | — |
| rp32 | `rp32_soc_vfriendly` | slang $readmemh | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `axis_baser_rx_64` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `axis_baser_tx_64` | unroll limit of 4000 exhausted [--unroll-limit=] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `axis_eth_fcs_check_64` | unroll limit of 4000 exhausted [--unroll-limit=] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `axis_eth_fcs_insert_64` | unroll limit of 4000 exhausted [--unroll-limit=] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `axis_srl_fifo` | non-blocking assignments unsupported in design initialization | ✅ 0 undriven | ❌ 174 div | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axis_srl_fifo&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+non-blocking+assignments+unsupported+in+design+initialization%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-ethernet | `axis_srl_register` | non-blocking assignments unsupported in design initialization | — | — | — |
| verilog-ethernet | `axis_xgmii_rx_32` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `axis_xgmii_rx_64` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `axis_xgmii_tx_64` | unroll limit of 4000 exhausted [--unroll-limit=] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `eth_mac_10g` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `eth_mac_10g_fifo` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `eth_mac_phy_10g` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `eth_mac_phy_10g_fifo` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `eth_mac_phy_10g_rx` | cannot select range of 96 elements from 'reg[0:0]' [-Wrange-width-oob] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `eth_mac_phy_10g_tx` | unroll limit of 4000 exhausted [--unroll-limit=] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `eth_phy_10g` | unroll limit of 4000 exhausted [--unroll-limit=] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `eth_phy_10g_rx` | unroll limit of 4000 exhausted [--unroll-limit=] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `eth_phy_10g_rx_if` | unroll limit of 4000 exhausted [--unroll-limit=] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `eth_phy_10g_tx` | unroll limit of 4000 exhausted [--unroll-limit=] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `eth_phy_10g_tx_if` | unroll limit of 4000 exhausted [--unroll-limit=] | — (not measured yet) | — (not measured yet) | — |
| verilog-ethernet | `ssio_sdr_in_diff` | parameter 'IODDR_STYLE' does not exist in 'ssio_sdr_in' [-Wundefined-pa | — (not measured yet) | — (not measured yet) | — |
| verilog-pcie | `axis_srl_fifo` | non-blocking assignments unsupported in design initialization | ✅ 0 undriven | ❌ 174 div | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+axis_srl_fifo&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+non-blocking+assignments+unsupported+in+design+initialization%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `axis_srl_register` | non-blocking assignments unsupported in design initialization | — | — | — |
| verilog-pcie | `dma_if_axi` | blocking assignment to variable 'm_axis_read_desc_status_error_reg' is not su | ✅ 0 undriven | ✅ PASS (201 cycles, 200 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+dma_if_axi&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+blocking+assignment+to+variable+%27m_axis_read_desc_status_error_reg%27+is+not+su%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `dma_if_axi_rd` | blocking assignment to variable 'm_axis_read_desc_status_error_reg' is not su | ✅ 0 undriven | ✅ PASS (201 cycles, 168 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+dma_if_axi_rd&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+blocking+assignment+to+variable+%27m_axis_read_desc_status_error_reg%27+is+not+su%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_msix` | unroll limit of 4000 exhausted [--unroll-limit=] | ✅ 0 undriven | ✅ PASS (201 cycles, 168 active) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+pcie_msix&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+unroll+limit+of+4000+exhausted+%5B--unroll-limit%3D%5D%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_ptile_if` | value must be positive | ✅ 0 undriven (14 never assigned in the source) | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+pcie_ptile_if&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+value+must+be+positive%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%2814+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_ptile_if_rx` | value must be positive | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+pcie_ptile_if_rx&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+value+must+be+positive%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_ptile_if_tx` | value must be positive | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+pcie_ptile_if_tx&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+value+must+be+positive%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_s10_if` | value must be positive | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+pcie_s10_if&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+value+must+be+positive%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_s10_if_rx` | value must be positive | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+pcie_s10_if_rx&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+value+must+be+positive%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_s10_if_tx` | value must be positive | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+pcie_s10_if_tx&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+value+must+be+positive%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_tlp_demux` | value must be positive | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+pcie_tlp_demux&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+value+must+be+positive%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_tlp_demux_bar` | value must be positive | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+pcie_tlp_demux_bar&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+value+must+be+positive%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_tlp_fifo` | value must be positive | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+pcie_tlp_fifo&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+value+must+be+positive%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_tlp_fifo_mux` | value must be positive | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+pcie_tlp_fifo_mux&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+value+must+be+positive%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_tlp_fifo_raw` | value must be positive | — (not comparable) | — | — |
| verilog-pcie | `pcie_us_if` | value must be positive | — | — | — |
| verilog-pcie | `pcie_us_if_cc` | value must be positive | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+pcie_us_if_cc&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+value+must+be+positive%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_us_if_cq` | value must be positive | ✅ 0 undriven | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+pcie_us_if_cq&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+value+must+be+positive%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| verilog-pcie | `pcie_us_if_rq` | value must be positive | — | — | — |
| xiangshan | `fpdiv_r64_block` | could not find connection for implicit named port 'divisor_i' | ✅ 0 undriven (1 never assigned in the source) | skip (sim build) | [file an issue](https://github.com/YosysHQ/yosys/issues/new?title=read_slang%3A+cannot+elaborate+fpdiv_r64_block&body=%60read_slang%60+cannot+read+this+design%3B+%60read_uhdm%60+does.%0A%0ADiagnostic%3A+could+not+find+connection+for+implicit+named+port+%27divisor_i%27%0A%0Aread_uhdm+on+the+same+sources%3A+%E2%9C%85+0+undriven+%281+never+assigned+in+the+source%29%0A%0AYosys+0.69%2C+read_slang+from+the+vendored+sv-elab+%28povik%2Fsv-elab+%40+b4fd362%29.) |
| xiangshan | `int_div_radix_4_v1` | port 'quot_o' does not exist in 'radix_4_sign_coder' | — | — | — |
| xiangshan | `radix_4_qds_v1` | port 'quot_o' does not exist in 'radix_4_sign_coder' | — | — | — |

---

Regenerate with `test/slang_unsupported_report.py` after a sweep cycle.
A row leaves this file the moment `read_slang` can read the design.

