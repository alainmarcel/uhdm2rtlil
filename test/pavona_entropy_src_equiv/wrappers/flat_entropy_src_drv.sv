// Self-driving entropy_src (the deep test, modelled on OpenTitan's aes_wrap):
// a TL-UL master FSM programs CONF (fips_enable, entropy_data_reg_enable),
// ENTROPY_CONTROL (es_type = bypass the SHA-3 conditioner, es_route = to
// software), then MODULE_ENABLE, and polls ENTROPY_DATA forever.  The noise
// source is the co-sim's random stimulus on rng_bits_i (rng_valid_i is forced
// high by scripts/entropy_src_cosim.py's DIRECTED table so a 96-sample bypass
// window fills every ~100 cycles); the health tests run at their default
// (never-failing) bypass thresholds.  es_data_o = the last non-zero entropy
// word read, words_o = how many.  Wrapper-only top: entropy_src_srcs.py seeds
// the closure from this file's references.
module entropy_src_drv_flat
  import tlul_pkg::*;
  import entropy_src_reg_pkg::*;
  import entropy_src_pkg::*;
  import prim_mubi_pkg::*;
(
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        rng_valid_i,
  input  logic  [3:0] rng_bits_i,
  output logic [31:0] es_data_o,
  output logic [15:0] words_o,
  output logic        entropy_valid_o,
  output logic        rng_enable_o,
  output logic        alert_recov_o,
  output logic        alert_fatal_o
);
  localparam int NumAlerts = 2;
  tl_h2d_t h2d, h2d_intg;
  tl_d2h_t d2h;
  prim_alert_pkg::alert_rx_t [NumAlerts-1:0] alert_rx;
  prim_alert_pkg::alert_tx_t [NumAlerts-1:0] alert_tx;
  for (genvar a = 0; a < NumAlerts; a++) begin : g_alert
    assign alert_rx[a].ping_p = 1'b0;
    assign alert_rx[a].ping_n = 1'b1;
    assign alert_rx[a].ack_p  = 1'b0;
    assign alert_rx[a].ack_n  = 1'b1;
  end
  assign alert_recov_o = alert_tx[0].alert_p | ~alert_tx[0].alert_n;
  assign alert_fatal_o = alert_tx[1].alert_p | ~alert_tx[1].alert_n;

  tlul_cmd_intg_gen #(.EnableDataIntgGen(1'b1)) u_intg (.tl_i(h2d), .tl_o(h2d_intg));

  entropy_src_hw_if_rsp_t   unused_hw_if_rsp;
  cs_aes_halt_req_t         unused_halt_req;
  logic                     unused_xht_valid;
  logic [3:0]               unused_xht_bits;
  logic [1:0]               unused_xht_sel;
  logic [17:0]              unused_xht_win;
  entropy_src_xht_meta_req_t unused_xht_meta;
  logic unused_rng_fips, unused_intr_ht, unused_intr_obs, unused_intr_fatal;

  entropy_src u_es (
    .clk_i, .rst_ni,
    .tl_i                         (h2d_intg),
    .tl_o                         (d2h),
    .otp_en_entropy_src_fw_read_i (MuBi8True),
    .otp_en_entropy_src_fw_over_i (MuBi8False),
    .rng_fips_o                   (unused_rng_fips),
    .entropy_src_hw_if_i          ('{es_req: 1'b0}),
    .entropy_src_hw_if_o          (unused_hw_if_rsp),
    .entropy_src_rng_enable_o     (rng_enable_o),
    .entropy_src_rng_valid_i      (rng_valid_i),
    .entropy_src_rng_bits_i       (rng_bits_i),
    .cs_aes_halt_o                (unused_halt_req),
    .cs_aes_halt_i                ('{cs_aes_halt_ack: 1'b0}),
    .entropy_src_xht_valid_o      (unused_xht_valid),
    .entropy_src_xht_bits_o       (unused_xht_bits),
    .entropy_src_xht_bit_sel_o    (unused_xht_sel),
    .entropy_src_xht_health_test_window_o (unused_xht_win),
    .entropy_src_xht_meta_o       (unused_xht_meta),
    .entropy_src_xht_meta_i       ('{default: '0}),
    .alert_rx_i                   (alert_rx),
    .alert_tx_o                   (alert_tx),
    .intr_es_entropy_valid_o      (entropy_valid_o),
    .intr_es_health_test_failed_o (unused_intr_ht),
    .intr_es_observe_fifo_ready_o (unused_intr_obs),
    .intr_es_fatal_err_o          (unused_intr_fatal)
  );

  // CONF: rng_bit_sel=0, entropy_data_reg_enable=True, threshold_scope=False,
  // rng_bit_enable=False, rng_fips=False, fips_flag=False, fips_enable=True.
  localparam logic [31:0] ConfVal    = {8'h00, MuBi4True, MuBi4False, MuBi4False, MuBi4False, MuBi4False, MuBi4True};
  localparam logic [31:0] ControlVal = {24'h0, MuBi4True, MuBi4True};   // es_type=bypass, es_route=sw
  localparam logic [31:0] EnableVal  = {28'h0, MuBi4True};

  typedef enum logic [2:0] { S_CONF, S_CONTROL, S_ENABLE, S_READ } drv_state_e;
  drv_state_e state_q, state_d;
  logic        sent_q, sent_d;     // request accepted, waiting for the response
  logic [31:0] es_data_q, es_data_d;
  logic [15:0] words_q, words_d;

  always_comb begin
    h2d.a_valid           = 1'b0;
    h2d.a_opcode          = PutFullData;
    h2d.a_param           = 3'h0;
    h2d.a_size            = 2'h2;
    h2d.a_source          = 8'h0;
    h2d.a_address         = 32'h0;
    h2d.a_mask            = 4'hF;
    h2d.a_data            = 32'h0;
    h2d.a_user.rsvd       = '0;
    h2d.a_user.instr_type = MuBi4False;
    h2d.a_user.cmd_intg   = '0;
    h2d.a_user.data_intg  = '0;
    h2d.d_ready           = 1'b1;
    state_d   = state_q;
    sent_d    = sent_q;
    es_data_d = es_data_q;
    words_d   = words_q;
    unique case (state_q)
      S_CONF: begin
        h2d.a_address = {{(32-BlockAw){1'b0}}, ENTROPY_SRC_CONF_OFFSET};
        h2d.a_data    = ConfVal;
      end
      S_CONTROL: begin
        h2d.a_address = {{(32-BlockAw){1'b0}}, ENTROPY_SRC_ENTROPY_CONTROL_OFFSET};
        h2d.a_data    = ControlVal;
      end
      S_ENABLE: begin
        h2d.a_address = {{(32-BlockAw){1'b0}}, ENTROPY_SRC_MODULE_ENABLE_OFFSET};
        h2d.a_data    = EnableVal;
      end
      default: begin
        h2d.a_opcode  = Get;
        h2d.a_address = {{(32-BlockAw){1'b0}}, ENTROPY_SRC_ENTROPY_DATA_OFFSET};
      end
    endcase
    h2d.a_valid = ~sent_q;
    if (h2d.a_valid && d2h.a_ready) sent_d = 1'b1;
    if (sent_q && d2h.d_valid) begin
      sent_d = 1'b0;
      unique case (state_q)
        S_CONF:    state_d = S_CONTROL;
        S_CONTROL: state_d = S_ENABLE;
        S_ENABLE:  state_d = S_READ;
        default: begin
          if (d2h.d_data != 32'h0) begin
            es_data_d = d2h.d_data;
            words_d   = words_q + 16'h1;
          end
        end
      endcase
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q   <= S_CONF;
      sent_q    <= 1'b0;
      es_data_q <= '0;
      words_q   <= '0;
    end else begin
      state_q   <= state_d;
      sent_q    <= sent_d;
      es_data_q <= es_data_d;
      words_q   <= words_d;
    end
  end
  assign es_data_o = es_data_q;
  assign words_o   = words_q;
endmodule
