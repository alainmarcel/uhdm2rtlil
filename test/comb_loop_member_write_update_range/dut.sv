// An always_comb that writes struct fields one by one — including a packed
// array-of-struct member indexed by a FOR-LOOP variable
// (`hw2reg.sha2_digest[i].d = …`, OpenTitan dma's hw2reg block) — while a
// submodule instance drives another field of the same struct
// (`.hw2reg_intr_state_d_o(hw2reg.intr_state.d)`, prim_intr_hw).  The
// written-bits scan cannot resolve the loop index, and its fallback was a
// FULL-WIDTH update of hw2reg: a second driver of intr_state.d ("Driver-driver
// conflict … resolved using constant") — the dma error / done interrupts
// never fired.  A loop-indexed struct member is now bounded to the whole
// member's bits, so the update leaves the instance-driven field alone.
package clm_pkg;
  typedef struct packed { logic [31:0] d; logic de; } wr_t;
  typedef struct packed { logic d; } st_t;
  typedef struct packed {
    wr_t       go;
    wr_t [3:0] sha2_digest;
    st_t       intr_state;
    wr_t       status;
  } hw2reg_t;
endpackage
module clm_intr (input logic clk_i, input logic rst_ni, input logic ev_i, input logic q_i, output logic d_o, output logic intr_o);
  assign d_o = ev_i | q_i;
  always_ff @(posedge clk_i or negedge rst_ni) if (!rst_ni) intr_o <= 1'b0; else intr_o <= d_o;
endmodule
module comb_loop_member_write_update_range import clm_pkg::*; (
  input  logic clk_i, input logic rst_ni,
  input  logic [3:0][31:0] dig_i, input logic dig_we_i, input logic go_i, input logic ev_i, input logic q_i,
  output hw2reg_t hw2reg, output logic intr_o);
  always_comb begin
    hw2reg.go.de     = go_i;
    hw2reg.go.d      = 32'd0;
    hw2reg.status.d  = {31'd0, go_i};
    hw2reg.status.de = 1'b1;
    for (int i = 0; i < 4; i++) begin
      hw2reg.sha2_digest[i].d  = dig_i[i];
      hw2reg.sha2_digest[i].de = dig_we_i;
    end
  end
  clm_intr u_intr (.clk_i, .rst_ni, .ev_i, .q_i, .d_o(hw2reg.intr_state.d), .intr_o);
endmodule
