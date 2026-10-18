// A dynamic element index WIDER than 32 bits (a 64-bit GPR indexing a
// 2-element array, black-parrot bp_cce_src_sel's
// `sharers_coh_states_i[gpr_i[src_b_i.gpr]]`) must keep every bit: an
// out-of-range index reads X (LRM 7.4.6), it must not wrap onto a real
// element through 32-bit arithmetic.
module top(input logic [7:0][63:0] gpr_i, input logic [2:0] sel, input logic [1:0][2:0] sh,
           output logic [2:0] y, output logic [2:0] y2, output logic y3);
  always_comb begin
    y = '0;
    y[0+:3] = sh[gpr_i[sel]];
  end
  assign y2 = sh[gpr_i[sel][7:0]];
  assign y3 = sel > 1 ? 1'b0 : sh[sel][0];
endmodule
