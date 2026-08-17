// AUTO-GENERATED per-module equivalence wrapper for hpdcache_ctrl
// Parameter environment copied verbatim from cva6.sv (build_config-computed
// CVA6Cfg + shared type params) = the values used in the real hierarchy.
`include "rvfi_types.svh"
`include "cvxif_types.svh"
`include "hpdcache_equiv_pkg.svh"

module hpdcache_ctrl_equiv
  import ariane_pkg::*;
  import hpdcache_pkg::*;
  import config_pkg::*;
#(

    // CVA6 config
    parameter config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(
        cva6_config_pkg::cva6_cfg
    ),

    // RVFI PROBES
    parameter type rvfi_probes_instr_t = `RVFI_PROBES_INSTR_T(CVA6Cfg),
    parameter type rvfi_probes_csr_t = `RVFI_PROBES_CSR_T(CVA6Cfg),
    parameter type rvfi_probes_t = struct packed {
      rvfi_probes_csr_t   csr;
      rvfi_probes_instr_t instr;
    },

    // branchpredict scoreboard entry
    // this is the struct which we will inject into the pipeline to guide the various
    // units towards the correct branch decision and resolve
    localparam type branchpredict_sbe_t = struct packed {
      cf_t                     cf;               // type of control flow prediction
      logic [CVA6Cfg.VLEN-1:0] predict_address;  // target address at which to jump, or not
    },

    parameter type exception_t = struct packed {
      logic [CVA6Cfg.XLEN-1:0] cause;  // cause of exception
      logic [CVA6Cfg.XLEN-1:0] tval;  // additional information of causing exception (e.g.: instruction causing it),
      // address of LD/ST fault
      logic [CVA6Cfg.GPLEN-1:0] tval2;  // additional information when the causing exception in a guest exception
      logic [31:0] tinst;  // transformed instruction information
      logic gva;  // signals when a guest virtual address is written to tval
      logic valid;
    },

    // cache request ports
    // I$ address translation requests
    localparam type icache_areq_t = struct packed {
      logic                    fetch_valid;      // address translation valid
      logic [CVA6Cfg.PLEN-1:0] fetch_paddr;      // physical address in
      exception_t              fetch_exception;  // exception occurred during fetch
    },
    localparam type icache_arsp_t = struct packed {
      logic                    fetch_req;    // address translation request
      logic [CVA6Cfg.VLEN-1:0] fetch_vaddr;  // virtual address out
    },

    // I$ data requests
    localparam type icache_dreq_t = struct packed {
      logic                    req;      // we request a new word
      logic                    kill_s1;  // kill the current request
      logic                    kill_s2;  // kill the last request
      logic                    spec;     // request is speculative
      logic [CVA6Cfg.VLEN-1:0] vaddr;    // 1st cycle: 12 bit index is taken for lookup
    },
    localparam type icache_drsp_t = struct packed {
      logic                                ready;  // icache is ready
      logic                                valid;  // signals a valid read
      logic [CVA6Cfg.FETCH_WIDTH-1:0]      data;   // 2+ cycle out: tag
      logic [CVA6Cfg.FETCH_USER_WIDTH-1:0] user;   // User bits
      logic [CVA6Cfg.VLEN-1:0]             vaddr;  // virtual address out
      exception_t                          ex;     // we've encountered an exception
    },

    // IF/ID Stage
    // store the decompressed instruction
    localparam type fetch_entry_t = struct packed {
      logic [CVA6Cfg.VLEN-1:0] address;  // the address of the instructions from below
      logic [31:0] instruction;  // instruction word
      branchpredict_sbe_t     branch_predict; // this field contains branch prediction information regarding the forward branch path
      exception_t             ex;             // this field contains exceptions which might have happened earlier, e.g.: fetch exceptions
    },
    //JVT struct{base,mode}
    localparam type jvt_t = struct packed {
      logic [CVA6Cfg.XLEN-7:0] base;
      logic [5:0] mode;
    },

    // ID/EX/WB Stage
    localparam type scoreboard_entry_t = struct packed {
      logic [CVA6Cfg.VLEN-1:0] pc;  // PC of instruction
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;      // this can potentially be simplified, we could index the scoreboard entry
      // with the transaction id in any case make the width more generic
      fu_t fu;  // functional unit to use
      fu_op op;  // operation to perform in each functional unit
      logic [REG_ADDR_SIZE-1:0] rs1;  // register source address 1
      logic [REG_ADDR_SIZE-1:0] rs2;  // register source address 2
      logic [REG_ADDR_SIZE-1:0] rd;  // register destination address
      logic [CVA6Cfg.XLEN-1:0] result;  // for unfinished instructions this field also holds the immediate,
      // for unfinished floating-point that are partly encoded in rs2, this field also holds rs2
      // for unfinished floating-point fused operations (FMADD, FMSUB, FNMADD, FNMSUB)
      // this field holds the address of the third operand from the floating-point register file
      logic valid;  // is the result valid
      logic use_imm;  // should we use the immediate as operand b?
      logic use_zimm;  // use zimm as operand a
      logic use_pc;  // set if we need to use the PC as operand a, PC from exception
      exception_t ex;  // exception has occurred
      branchpredict_sbe_t bp;  // branch predict scoreboard data structure
      logic                     is_compressed; // signals a compressed instructions, we need this information at the commit stage if
                                               // we want jump accordingly e.g.: +4, +2
      logic is_macro_instr;  // is an instruction executed as predefined sequence of instructions called macro definition
      logic is_last_macro_instr;  // is last decoded 32bit instruction of macro definition
      logic is_double_rd_macro_instr;  // is double move decoded 32bit instruction of macro definition
      logic vfp;  // is this a vector floating-point instruction?
      logic is_zcmt;  //is a zcmt instruction
    },
    localparam type writeback_t = struct packed {
      logic valid;  // wb data is valid
      logic [CVA6Cfg.XLEN-1:0] data;  //wb data
      logic ex_valid;  // exception from WB
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;  //transaction ID
    },

    // branch-predict
    // this is the struct we get back from ex stage and we will use it to update
    // all the necessary data structures
    // bp_resolve_t
    localparam type bp_resolve_t = struct packed {
      logic                    valid;           // prediction with all its values is valid
      logic [CVA6Cfg.VLEN-1:0] pc;              // PC of predict or mis-predict
      logic [CVA6Cfg.VLEN-1:0] target_address;  // target address at which to jump, or not
      logic                    is_mispredict;   // set if this was a mis-predict
      logic                    is_taken;        // branch is taken
      cf_t                     cf_type;         // Type of control flow change
    },

    // All information needed to determine whether we need to associate an interrupt
    // with the corresponding instruction or not.
    localparam type irq_ctrl_t = struct packed {
      logic [CVA6Cfg.XLEN-1:0] mie;
      logic [CVA6Cfg.XLEN-1:0] mip;
      logic [CVA6Cfg.XLEN-1:0] mideleg;
      logic [CVA6Cfg.XLEN-1:0] hideleg;
      logic                    sie;
      logic                    global_enable;
    },

    localparam type lsu_ctrl_t = struct packed {
      logic                             valid;
      logic [CVA6Cfg.VLEN-1:0]          vaddr;
      logic [31:0]                      tinst;
      logic                             hs_ld_st_inst;
      logic                             hlvx_inst;
      logic                             overflow;
      logic                             g_overflow;
      logic [CVA6Cfg.XLEN-1:0]          data;
      logic [(CVA6Cfg.XLEN/8)-1:0]      be;
      fu_t                              fu;
      fu_op                             operation;
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;
      logic                             is_speculative_load;
      logic                             is_speculative_load_miss;
    },


    localparam type cbo_t = logic [7:0],

    localparam type fu_data_t = struct packed {
      fu_t                              fu;
      fu_op                             operation;
      logic [CVA6Cfg.XLEN-1:0]          operand_a;
      logic [CVA6Cfg.XLEN-1:0]          operand_b;
      logic [CVA6Cfg.XLEN-1:0]          imm;
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;
    },

    localparam type icache_req_t = struct packed {
      logic [CVA6Cfg.ICACHE_SET_ASSOC_WIDTH-1:0] way;  // way to replace
      logic [CVA6Cfg.PLEN-1:0] paddr;  // physical address
      logic nc;  // noncacheable
      logic [CVA6Cfg.MEM_TID_WIDTH-1:0] tid;  // thread id (used as transaction id in Ariane)
    },
    localparam type icache_rtrn_t = struct packed {
      wt_cache_pkg::icache_in_t rtype;  // see definitions above
      logic [CVA6Cfg.ICACHE_LINE_WIDTH-1:0] data;  // full cache line width
      logic [CVA6Cfg.ICACHE_USER_LINE_WIDTH-1:0] user;  // user bits
      struct packed {
        logic                                      vld;  // invalidate only affected way
        logic                                      all;  // invalidate all ways
        logic [CVA6Cfg.ICACHE_INDEX_WIDTH-1:0]     idx;  // physical address to invalidate
        logic [CVA6Cfg.ICACHE_SET_ASSOC_WIDTH-1:0] way;  // way to invalidate
      } inv;  // invalidation vector
      logic [CVA6Cfg.MEM_TID_WIDTH-1:0] tid;  // thread id (used as transaction id in Ariane)
    },

    // D$ data requests
    localparam type dcache_req_i_t = struct packed {
      logic [CVA6Cfg.DCACHE_INDEX_WIDTH-1:0] address_index;
      logic [CVA6Cfg.DCACHE_TAG_WIDTH-1:0]   address_tag;
      logic [CVA6Cfg.XLEN-1:0]               data_wdata;
      logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0]  data_wuser;
      logic                                  data_req;
      logic                                  data_we;
      logic [(CVA6Cfg.XLEN/8)-1:0]           data_be;
      logic [1:0]                            data_size;
      logic [CVA6Cfg.DcacheIdWidth-1:0]      data_id;
      logic                                  kill_req;
      logic                                  tag_valid;
      cbo_t                                  cbo_op;
    },

    localparam type dcache_req_o_t = struct packed {
      logic                                 data_gnt;
      logic                                 data_rvalid;
      logic [CVA6Cfg.DcacheIdWidth-1:0]     data_rid;
      logic [CVA6Cfg.XLEN-1:0]              data_rdata;
      logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0] data_ruser;
    },

    // Accelerator - CVA6
    parameter type accelerator_req_t  = logic,
    parameter type accelerator_resp_t = logic,

    // Accelerator - CVA6's MMU
    parameter type acc_mmu_req_t  = logic,
    parameter type acc_mmu_resp_t = logic,

    // AXI types
    parameter type axi_ar_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
      axi_pkg::len_t                   len;
      axi_pkg::size_t                  size;
      axi_pkg::burst_t                 burst;
      logic                            lock;
      axi_pkg::cache_t                 cache;
      axi_pkg::prot_t                  prot;
      axi_pkg::qos_t                   qos;
      axi_pkg::region_t                region;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type axi_aw_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
      axi_pkg::len_t                   len;
      axi_pkg::size_t                  size;
      axi_pkg::burst_t                 burst;
      logic                            lock;
      axi_pkg::cache_t                 cache;
      axi_pkg::prot_t                  prot;
      axi_pkg::qos_t                   qos;
      axi_pkg::region_t                region;
      axi_pkg::atop_t                  atop;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type axi_w_chan_t = struct packed {
      logic [CVA6Cfg.AxiDataWidth-1:0]     data;
      logic [(CVA6Cfg.AxiDataWidth/8)-1:0] strb;
      logic                                last;
      logic [CVA6Cfg.AxiUserWidth-1:0]     user;
    },
    parameter type b_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      axi_pkg::resp_t                  resp;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type r_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiDataWidth-1:0] data;
      axi_pkg::resp_t                  resp;
      logic                            last;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type noc_req_t = struct packed {
      axi_aw_chan_t aw;
      logic         aw_valid;
      axi_w_chan_t  w;
      logic         w_valid;
      logic         b_ready;
      axi_ar_chan_t ar;
      logic         ar_valid;
      logic         r_ready;
    },
    parameter type noc_resp_t = struct packed {
      logic    aw_ready;
      logic    ar_ready;
      logic    w_ready;
      logic    b_valid;
      b_chan_t b;
      logic    r_valid;
      r_chan_t r;
    },
    //
    parameter type acc_cfg_t = logic,
    parameter acc_cfg_t AccCfg = '0,
    // CVXIF Types
    parameter type readregflags_t = `READREGFLAGS_T(CVA6Cfg),
    parameter type writeregflags_t = `WRITEREGFLAGS_T(CVA6Cfg),
    parameter type id_t = `ID_T(CVA6Cfg),
    parameter type hartid_t = `HARTID_T(CVA6Cfg),
    parameter type x_compressed_req_t = `X_COMPRESSED_REQ_T(CVA6Cfg, hartid_t),
    parameter type x_compressed_resp_t = `X_COMPRESSED_RESP_T(CVA6Cfg),
    parameter type x_issue_req_t = `X_ISSUE_REQ_T(CVA6Cfg, hartid_t, id_t),
    parameter type x_issue_resp_t = `X_ISSUE_RESP_T(CVA6Cfg, writeregflags_t, readregflags_t),
    parameter type x_register_t = `X_REGISTER_T(CVA6Cfg, hartid_t, id_t, readregflags_t),
    parameter type x_commit_t = `X_COMMIT_T(CVA6Cfg, hartid_t, id_t),
    parameter type x_result_t = `X_RESULT_T(CVA6Cfg, hartid_t, id_t, writeregflags_t),
    parameter type cvxif_req_t =
    `CVXIF_REQ_T(CVA6Cfg, x_compressed_req_t, x_issue_req_t, x_register_t, x_commit_t),
    parameter type cvxif_resp_t =
    `CVXIF_RESP_T(CVA6Cfg, x_compressed_resp_t, x_issue_resp_t, x_result_t)
,

  parameter hpdcache_cfg_t HPDcacheCfg = hpdcache_equiv_pkg::HPDcacheCfg,
  parameter type hpdcache_nline_t = hpdcache_equiv_pkg::hpdcache_nline_t,
  parameter type hpdcache_tag_t = hpdcache_equiv_pkg::hpdcache_tag_t,
  parameter type hpdcache_set_t = hpdcache_equiv_pkg::hpdcache_set_t,
  parameter type hpdcache_word_t = hpdcache_equiv_pkg::hpdcache_word_t,
  parameter type hpdcache_data_word_t = hpdcache_equiv_pkg::hpdcache_data_word_t,
  parameter type hpdcache_data_be_t = hpdcache_equiv_pkg::hpdcache_data_be_t,
  parameter type hpdcache_dir_entry_t = logic,
  parameter type hpdcache_way_vector_t = hpdcache_equiv_pkg::hpdcache_way_vector_t,
  parameter type hpdcache_way_t = hpdcache_equiv_pkg::hpdcache_way_t,
  parameter type wbuf_addr_t = hpdcache_equiv_pkg::wbuf_addr_t,
  parameter type wbuf_data_t = hpdcache_equiv_pkg::wbuf_data_t,
  parameter type wbuf_be_t = hpdcache_equiv_pkg::wbuf_be_t,
  parameter type hpdcache_access_data_t = hpdcache_equiv_pkg::hpdcache_access_data_t,
  parameter type hpdcache_access_be_t = hpdcache_equiv_pkg::hpdcache_access_be_t,
  parameter type hpdcache_req_addr_t = hpdcache_equiv_pkg::hpdcache_req_addr_t,
  parameter type hpdcache_req_offset_t = hpdcache_equiv_pkg::hpdcache_req_offset_t,
  parameter type hpdcache_req_tid_t = hpdcache_equiv_pkg::hpdcache_req_tid_t,
  parameter type hpdcache_req_sid_t = hpdcache_equiv_pkg::hpdcache_req_sid_t,
  parameter type hpdcache_req_data_t = hpdcache_equiv_pkg::hpdcache_req_data_t,
  parameter type hpdcache_req_be_t = hpdcache_equiv_pkg::hpdcache_req_be_t,
  parameter type hpdcache_req_t = hpdcache_equiv_pkg::hpdcache_req_t,
  parameter type hpdcache_rsp_t = hpdcache_equiv_pkg::hpdcache_rsp_t
) (

    input  logic                  clk_i,
    input  logic                  rst_ni,

    //      Core request interface
    input  logic                  core_req_valid_i,
    output logic                  core_req_ready_o,
    input  hpdcache_req_t         core_req_i,
    input  logic                  core_req_abort_i,
    input  hpdcache_tag_t         core_req_tag_i,
    input  hpdcache_pma_t         core_req_pma_i,

    //      Core response interface
    output logic                  core_rsp_valid_o,
    output hpdcache_rsp_t         core_rsp_o,

    //      Force the write buffer to send all pending writes
    input  logic                  wbuf_flush_i,

    //      Global control signals
    output logic                  cachedir_hit_o,

    //      Miss handler interface
    output logic                  st0_mshr_check_o,
    output hpdcache_req_offset_t  st0_mshr_check_offset_o,
    output hpdcache_nline_t       st1_mshr_check_nline_o,
    input  logic                  st1_mshr_hit_i,
    input  logic                  st1_mshr_alloc_ready_i,
    input  logic                  st1_mshr_alloc_full_i,
    input  logic                  st1_mshr_alloc_cbuf_full_i,
    output logic                  st2_mshr_alloc_o,
    output logic                  st2_mshr_alloc_cs_o,
    output hpdcache_nline_t       st2_mshr_alloc_nline_o,
    output hpdcache_req_tid_t     st2_mshr_alloc_tid_o,
    output hpdcache_req_sid_t     st2_mshr_alloc_sid_o,
    output hpdcache_word_t        st2_mshr_alloc_word_o,
    output hpdcache_req_data_t    st2_mshr_alloc_wdata_o,
    output hpdcache_req_be_t      st2_mshr_alloc_be_o,
    output hpdcache_way_vector_t  st2_mshr_alloc_victim_way_o,
    output logic                  st2_mshr_alloc_need_rsp_o,
    output logic                  st2_mshr_alloc_is_prefetch_o,
    output logic                  st2_mshr_alloc_wback_o,
    output logic                  st2_mshr_alloc_dirty_o,

    //      Refill interface
    input  logic                  refill_req_valid_i,
    output logic                  refill_req_ready_o,
    input  logic                  refill_is_error_i,
    input  logic                  refill_busy_i,
    input  logic                  refill_updt_sel_victim_i,
    input  hpdcache_set_t         refill_set_i,
    input  hpdcache_way_vector_t  refill_way_i,
    input  hpdcache_dir_entry_t   refill_dir_entry_i,
    input  logic                  refill_write_dir_i,
    input  logic                  refill_write_data_i,
    input  hpdcache_word_t        refill_word_i,
    input  hpdcache_access_data_t refill_data_i,
    input  logic                  refill_core_rsp_valid_i,
    input  hpdcache_rsp_t         refill_core_rsp_i,
    input  hpdcache_nline_t       refill_nline_i,
    input  logic                  refill_updt_rtab_i,

    //      Flush interface
    input  logic                  flush_busy_i,
    output hpdcache_nline_t       flush_check_nline_o,
    input  logic                  flush_check_hit_i,
    output logic                  flush_alloc_o,
    input  logic                  flush_alloc_ready_i,
    output hpdcache_nline_t       flush_alloc_nline_o,
    output hpdcache_way_vector_t  flush_alloc_way_o,
    input  logic                  flush_data_read_i,
    input  hpdcache_set_t         flush_data_read_set_i,
    input  hpdcache_word_t        flush_data_read_word_i,
    input  hpdcache_way_vector_t  flush_data_read_way_i,
    output hpdcache_access_data_t flush_data_read_data_o,
    input  logic                  flush_ack_i,
    input  hpdcache_nline_t       flush_ack_nline_i,

    //      Invalidate interface
    input  logic                  inval_check_dir_i,
    input  logic                  inval_write_dir_i,
    input  hpdcache_nline_t       inval_nline_i,
    output logic                  inval_hit_o,

    //      Write buffer interface
    input  logic                  wbuf_empty_i,
    output logic                  wbuf_flush_all_o,
    output logic                  wbuf_write_o,
    input  logic                  wbuf_write_ready_i,
    output wbuf_addr_t            wbuf_write_addr_o,
    output wbuf_data_t            wbuf_write_data_o,
    output wbuf_be_t              wbuf_write_be_o,
    output logic                  wbuf_write_uncacheable_o,
    input  logic                  wbuf_read_hit_i,
    output logic                  wbuf_read_flush_hit_o,
    output hpdcache_req_addr_t    wbuf_rtab_addr_o,
    output logic                  wbuf_rtab_is_read_o,
    input  logic                  wbuf_rtab_hit_open_i,
    input  logic                  wbuf_rtab_hit_pend_i,
    input  logic                  wbuf_rtab_hit_sent_i,
    input  logic                  wbuf_rtab_not_ready_i,

    //      Uncacheable request handler
    input  logic                  uc_busy_i,
    output logic                  uc_lrsc_snoop_o,
    output hpdcache_req_addr_t    uc_lrsc_snoop_addr_o,
    output hpdcache_req_size_t    uc_lrsc_snoop_size_o,
    output logic                  uc_req_valid_o,
    output hpdcache_uc_op_t       uc_req_op_o,
    output hpdcache_req_addr_t    uc_req_addr_o,
    output hpdcache_req_size_t    uc_req_size_o,
    output hpdcache_req_data_t    uc_req_data_o,
    output hpdcache_req_be_t      uc_req_be_o,
    output logic                  uc_req_uc_o,
    output hpdcache_req_sid_t     uc_req_sid_o,
    output hpdcache_req_tid_t     uc_req_tid_o,
    output logic                  uc_req_need_rsp_o,
    output hpdcache_way_vector_t  uc_req_dir_hit_way_o,
    output hpdcache_req_data_t    uc_req_old_data_o,
    input  logic                  uc_wbuf_flush_all_i,
    input  logic                  uc_data_amo_write_i,
    input  logic                  uc_data_amo_write_enable_i,
    input  hpdcache_set_t         uc_data_amo_write_set_i,
    input  hpdcache_req_size_t    uc_data_amo_write_size_i,
    input  hpdcache_word_t        uc_data_amo_write_word_i,
    input  hpdcache_way_vector_t  uc_data_amo_write_way_i,
    input  hpdcache_req_data_t    uc_data_amo_write_data_i,
    input  hpdcache_req_be_t      uc_data_amo_write_be_i,
    output logic                  uc_core_rsp_ready_o,
    input  logic                  uc_core_rsp_valid_i,
    input  hpdcache_rsp_t         uc_core_rsp_i,

    //      Cache Management Operation (CMO)
    input  logic                  cmo_busy_i,
    input  logic                  cmo_wait_i,
    output logic                  cmo_req_valid_o,
    output hpdcache_cmoh_op_t     cmo_req_op_o,
    output hpdcache_req_addr_t    cmo_req_addr_o,
    output hpdcache_req_data_t    cmo_req_wdata_o,
    output hpdcache_req_sid_t     cmo_req_sid_o,
    output hpdcache_req_tid_t     cmo_req_tid_o,
    output logic                  cmo_req_need_rsp_o,
    output logic                  cmo_dirty_set_en_o,
    output hpdcache_set_t         cmo_dirty_min_set_o,
    output hpdcache_set_t         cmo_dirty_max_set_o,
    output logic                  cmo_valid_set_en_o,
    output hpdcache_set_t         cmo_valid_min_set_o,
    output hpdcache_set_t         cmo_valid_max_set_o,
    input  logic                  cmo_wbuf_flush_all_i,
    input  logic                  cmo_flush_all_i,
    input  logic                  cmo_inval_all_i,
    input  logic                  cmo_dir_check_nline_i,
    input  hpdcache_set_t         cmo_dir_check_nline_set_i,
    input  hpdcache_tag_t         cmo_dir_check_nline_tag_i,
    output hpdcache_way_vector_t  cmo_dir_check_nline_hit_way_o,
    output logic                  cmo_dir_check_nline_wback_o,
    output logic                  cmo_dir_check_nline_dirty_o,
    input  logic                  cmo_dir_check_entry_i,
    input  hpdcache_set_t         cmo_dir_check_entry_set_i,
    input  hpdcache_way_vector_t  cmo_dir_check_entry_way_i,
    output logic                  cmo_dir_check_entry_valid_o,
    output logic                  cmo_dir_check_entry_wback_o,
    output logic                  cmo_dir_check_entry_dirty_o,
    output hpdcache_tag_t         cmo_dir_check_entry_tag_o,
    input  logic                  cmo_dir_updt_i,
    input  hpdcache_set_t         cmo_dir_updt_set_i,
    input  hpdcache_way_vector_t  cmo_dir_updt_way_i,
    input  logic                  cmo_dir_updt_valid_i,
    input  logic                  cmo_dir_updt_wback_i,
    input  logic                  cmo_dir_updt_dirty_i,
    input  logic                  cmo_dir_updt_fetch_i,
    input  hpdcache_tag_t         cmo_dir_updt_tag_i,
    output logic                  cmo_core_rsp_ready_o,
    input  logic                  cmo_core_rsp_valid_i,
    input  hpdcache_rsp_t         cmo_core_rsp_i,

    input  logic                  mshr_empty_i,
    input  logic                  flush_empty_i,

    output logic                  rtab_empty_o,
    output logic                  ctrl_empty_o,

    //   Configuration signals
    input  logic                  cfg_enable_i,
    input  logic                  cfg_prefetch_updt_plru_i,
    input  logic                  cfg_rtab_single_entry_i,
    input  logic                  cfg_default_wb_i,
    input  logic                  cfg_scrub_enable_i,
    input  logic unsigned [5:0]   cfg_scrub_period_i,
    input  logic                  cfg_scrub_restart_i,

    //   Performance events
    output logic                  evt_cache_write_miss_o,
    output logic                  evt_cache_read_miss_o,
    output logic                  evt_cache_dir_unc_err_o,
    output logic                  evt_cache_dir_cor_err_o,
    output logic                  evt_cache_dat_unc_err_o,
    output logic                  evt_cache_dat_cor_err_o,
    output logic                  evt_scrub_complete_o,
    output logic                  evt_uncached_req_o,
    output logic                  evt_cmo_req_o,
    output logic                  evt_write_req_o,
    output logic                  evt_read_req_o,
    output logic                  evt_prefetch_req_o,
    output logic                  evt_req_on_hold_o,
    output logic                  evt_rtab_rollback_o,
    output logic                  evt_stall_refill_o,
    output logic                  evt_stall_o

);

  localparam type interrupts_t = struct packed {
    logic [CVA6Cfg.XLEN-1:0] S_SW;
    logic [CVA6Cfg.XLEN-1:0] VS_SW;
    logic [CVA6Cfg.XLEN-1:0] M_SW;
    logic [CVA6Cfg.XLEN-1:0] S_TIMER;
    logic [CVA6Cfg.XLEN-1:0] VS_TIMER;
    logic [CVA6Cfg.XLEN-1:0] M_TIMER;
    logic [CVA6Cfg.XLEN-1:0] S_EXT;
    logic [CVA6Cfg.XLEN-1:0] VS_EXT;
    logic [CVA6Cfg.XLEN-1:0] M_EXT;
    logic [CVA6Cfg.XLEN-1:0] HS_EXT;
  };
  localparam interrupts_t INTERRUPTS = '{
      S_SW: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_S_SOFT),
      VS_SW: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_VS_SOFT),
      M_SW: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_M_SOFT),
      S_TIMER: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_S_TIMER),
      VS_TIMER: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_VS_TIMER),
      M_TIMER: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_M_TIMER),
      S_EXT: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_S_EXT),
      VS_EXT: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_VS_EXT),
      M_EXT: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_M_EXT),
      HS_EXT: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_HS_EXT)
  };
  localparam NumPorts = 4;
  localparam PC_QUEUE_DEPTH = 16;

  hpdcache_ctrl #(
      .HPDcacheCfg(HPDcacheCfg),
      .hpdcache_nline_t(hpdcache_nline_t),
      .hpdcache_tag_t(hpdcache_tag_t),
      .hpdcache_set_t(hpdcache_set_t),
      .hpdcache_word_t(hpdcache_word_t),
      .hpdcache_data_word_t(hpdcache_data_word_t),
      .hpdcache_data_be_t(hpdcache_data_be_t),
      .hpdcache_dir_entry_t(hpdcache_dir_entry_t),
      .hpdcache_way_vector_t(hpdcache_way_vector_t),
      .hpdcache_way_t(hpdcache_way_t),
      .wbuf_addr_t(wbuf_addr_t),
      .wbuf_data_t(wbuf_data_t),
      .wbuf_be_t(wbuf_be_t),
      .hpdcache_access_data_t(hpdcache_access_data_t),
      .hpdcache_access_be_t(hpdcache_access_be_t),
      .hpdcache_req_addr_t(hpdcache_req_addr_t),
      .hpdcache_req_offset_t(hpdcache_req_offset_t),
      .hpdcache_req_tid_t(hpdcache_req_tid_t),
      .hpdcache_req_sid_t(hpdcache_req_sid_t),
      .hpdcache_req_data_t(hpdcache_req_data_t),
      .hpdcache_req_be_t(hpdcache_req_be_t),
      .hpdcache_req_t(hpdcache_req_t),
      .hpdcache_rsp_t(hpdcache_rsp_t)
  ) dut (.*);

endmodule
