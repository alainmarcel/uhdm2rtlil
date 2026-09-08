// Auto-generated onehot-save + array-flatten shim for ibex_cs_registers.
// (1) csr_save_{if,id,wb}_i are onehot-when-csr_save_cause_i per the RTL exception-PC
//     `unique case (1'b1)` selector -- a design contract the free-input miter otherwise
//     violates with illegal zero/multi-hot save vectors.  save_sel_i picks the save.
// (2) csr_pmp_{cfg,addr}_o are UNPACKED-ARRAY outputs; read_uhdm packs element 0 at the
//     LSBs, read_slang at the MSBs, so a direct miter feeds swapped elements.  Flatten
//     them to an explicit elem0@LSB bus so both frontends agree.
module ibex_cs_registers_flat import ibex_pkg::*; #(

  parameter bit                     DbgTriggerEn                = 0,
  parameter int unsigned            DbgHwBreakNum               = 1,
  parameter bit                     DataIndTiming               = 1'b0,
  parameter bit                     DummyInstructions           = 1'b0,
  parameter bit                     ShadowCSR                   = 1'b0,
  parameter bit                     ICache                      = 1'b0,
  parameter int unsigned            MHPMCounterNum              = 10,
  parameter int unsigned            MHPMCounterWidth            = 40,
  parameter bit                     PMPEnable                   = 0,
  parameter int unsigned            PMPGranularity              = 0,
  parameter int unsigned            PMPNumRegions               = 4,
  parameter ibex_pkg::pmp_cfg_t     PMPRstCfg[PMP_MAX_REGIONS]  = ibex_pkg::PmpCfgRst,
  parameter logic [PMP_ADDR_MSB:0]  PMPRstAddr[PMP_MAX_REGIONS] = ibex_pkg::PmpAddrRst,
  parameter ibex_pkg::pmp_mseccfg_t PMPRstMsecCfg               = ibex_pkg::PmpMseccfgRst,
  parameter bit                     RV32E                       = 0,
  parameter ibex_pkg::rv32m_e RV32M                             = ibex_pkg::RV32MFast,
  parameter ibex_pkg::rv32b_e RV32B                             = ibex_pkg::RV32BNone,
  // mvendorid: encoding of manufacturer/provider
  parameter logic [31:0]            CsrMvendorId                = 32'b0,
  // mimpid: encoding of processor implementation version
  parameter logic [31:0]            CsrMimpId                   = 32'b0
) (
  input logic clk_i,
  input logic rst_ni,
  input logic [31:0] hart_id_i,
  output ibex_pkg::priv_lvl_e priv_mode_id_o,
  output ibex_pkg::priv_lvl_e priv_mode_lsu_o,
  output logic csr_mstatus_tw_o,
  output logic [31:0] csr_mtvec_o,
  input logic csr_mtvec_init_i,
  input logic [31:0] boot_addr_i,
  input logic csr_access_i,
  input ibex_pkg::csr_num_e csr_addr_i,
  input logic [31:0] csr_wdata_i,
  input ibex_pkg::csr_op_e csr_op_i,
  input csr_op_en_i,
  output logic [31:0] csr_rdata_o,
  input logic irq_software_i,
  input logic irq_timer_i,
  input logic irq_external_i,
  input logic [14:0] irq_fast_i,
  input logic nmi_mode_i,
  output logic irq_pending_o,
  output ibex_pkg::irqs_t irqs_o,
  output logic csr_mstatus_mie_o,
  output logic [31:0] csr_mepc_o,
  output logic [31:0] csr_mtval_o,
  output ibex_pkg::pmp_mseccfg_t csr_pmp_mseccfg_o,
  input logic debug_mode_i,
  input logic debug_mode_entering_i,
  input ibex_pkg::dbg_cause_e debug_cause_i,
  input logic debug_csr_save_i,
  output logic [31:0] csr_depc_o,
  output logic debug_single_step_o,
  output logic debug_ebreakm_o,
  output logic debug_ebreaku_o,
  output logic trigger_match_o,
  input logic [31:0] pc_if_i,
  input logic [31:0] pc_id_i,
  input logic [31:0] pc_wb_i,
  output logic data_ind_timing_o,
  output logic dummy_instr_en_o,
  output logic [2:0] dummy_instr_mask_o,
  output logic dummy_instr_seed_en_o,
  output logic [31:0] dummy_instr_seed_o,
  output logic icache_enable_o,
  output logic csr_shadow_err_o,
  input logic ic_scr_key_valid_i,
  input logic csr_restore_mret_i,
  input logic csr_restore_dret_i,
  input logic csr_save_cause_i,
  input ibex_pkg::exc_cause_t csr_mcause_i,
  input logic [31:0] csr_mtval_i,
  output logic illegal_csr_insn_o,
  output logic double_fault_seen_o,
  input logic instr_ret_i,
  input logic instr_ret_compressed_i,
  input logic instr_ret_spec_i,
  input logic instr_ret_compressed_spec_i,
  input logic iside_wait_i,
  input logic jump_i,
  input logic branch_i,
  input logic branch_taken_i,
  input logic mem_load_i,
  input logic mem_store_i,
  input logic dside_wait_i,
  input logic mul_wait_i,
  input logic div_wait_i,
  output logic [PMPNumRegions*($bits(ibex_pkg::pmp_cfg_t))-1:0] csr_pmp_cfg_o_flat,
  output logic [PMPNumRegions*((PMP_ADDR_MSB+1))-1:0] csr_pmp_addr_o_flat,
  input logic [1:0] save_sel_i
);
  ibex_pkg::pmp_cfg_t csr_pmp_cfg_o [PMPNumRegions];
  logic [PMP_ADDR_MSB:0] csr_pmp_addr_o [PMPNumRegions];
  genvar gi;
  generate
    for (gi=0; gi<PMPNumRegions; gi++) begin : g_csr_pmp_cfg_o
      assign csr_pmp_cfg_o_flat[gi*($bits(ibex_pkg::pmp_cfg_t)) +: ($bits(ibex_pkg::pmp_cfg_t))] = csr_pmp_cfg_o[gi];
    end
    for (gi=0; gi<PMPNumRegions; gi++) begin : g_csr_pmp_addr_o
      assign csr_pmp_addr_o_flat[gi*((PMP_ADDR_MSB+1)) +: ((PMP_ADDR_MSB+1))] = csr_pmp_addr_o[gi];
    end
  endgenerate
  logic csr_save_if_i, csr_save_id_i, csr_save_wb_i;
  always_comb begin
    csr_save_if_i = 1'b0; csr_save_id_i = 1'b0; csr_save_wb_i = 1'b0;
    if (csr_save_cause_i) unique case (save_sel_i)
      2'd0:    csr_save_if_i = 1'b1;
      2'd1:    csr_save_id_i = 1'b1;
      default: csr_save_wb_i = 1'b1;
    endcase
  end
  ibex_cs_registers #(
    .DbgTriggerEn(DbgTriggerEn),
    .DbgHwBreakNum(DbgHwBreakNum),
    .DataIndTiming(DataIndTiming),
    .DummyInstructions(DummyInstructions),
    .ShadowCSR(ShadowCSR),
    .ICache(ICache),
    .MHPMCounterNum(MHPMCounterNum),
    .MHPMCounterWidth(MHPMCounterWidth),
    .PMPEnable(PMPEnable),
    .PMPGranularity(PMPGranularity),
    .PMPNumRegions(PMPNumRegions),
    .PMPRstCfg(PMPRstCfg),
    .PMPRstAddr(PMPRstAddr),
    .PMPRstMsecCfg(PMPRstMsecCfg),
    .RV32E(RV32E),
    .RV32M(RV32M),
    .RV32B(RV32B),
    .CsrMvendorId(CsrMvendorId),
    .CsrMimpId(CsrMimpId)
  ) u_dut (.*);
endmodule
