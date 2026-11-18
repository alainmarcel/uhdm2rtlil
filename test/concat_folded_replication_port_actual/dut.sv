// A replication folded into a constant inside a concatenation that is an
// INSTANCE PORT ACTUAL -- OpenTitan cheriot_rmw_filter's ECC check:
//
//   localparam int unsigned RspIntgPadding = tlul_pkg::D2HRspMaxWidth -
//                                            $bits(tlul_pkg::tl_d2h_rsp_intg_t);
//   prim_secded_inv_64_57_dec u_dec (
//     .data_i({tl_d_i.d_user.rsp_intg, {RspIntgPadding{1'b0}}, rsp_intg}), ...
//
// In the elaborated actual Surelog folds `{Pad{1'b0}}` to a 51-bit BIN
// constant whose decompile is just its digits.  The concatenation's
// "unsized integer literal is 32 bits" rule (LRM 5.7.1, slang#2082) took it
// for an unsized decimal and cut it to 32 bits, so data_i was 45 bits and
// hierarchy zero-padded it at the TOP: every field moved down by 19 bits.
package p;
  parameter int MaxW = 57;
  typedef struct packed {
    logic [2:0] opcode;
    logic [1:0] size;
    logic       error;
  } rsp_t;
endpackage
module dut(input  logic [5:0]  r,
           input  logic [6:0]  i,
           output logic [63:0] o);
  localparam int unsigned Pad = p::MaxW - $bits(p::rsp_t);
  child u_c (.data_i({i, {Pad{1'b0}}, r}), .data_o(o));
endmodule
module child(input logic [63:0] data_i, output logic [63:0] data_o);
  assign data_o = data_i;
endmodule
