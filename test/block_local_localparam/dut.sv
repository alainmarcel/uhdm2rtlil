// A `localparam` declared INSIDE a block (a for-loop body), used in that
// block's statements:
//
//     for (int k = 0; k < NumScrmblKeys; k++) begin
//       localparam logic [4:0] NumRounds = 5'(unsigned'(NumPresentRounds));
//       otp_dec_key_lut[k] = prim_cipher_pkg::present_get_dec_key128(
//                                rnd_cnst_key_anchor[k], NumRounds);
//     end
//
// OpenTitan's otp_ctrl_scrmbl writes its PRESENT key schedule that way.
//
// Surelog keeps the real parameter as a `param_assign` in the block's
// STATEMENT list (not in the enclosing scope's Param_assigns()) AND fabricates
// a same-named 1-bit implicit `logic_net` on the module.  Importing that net
// left an UNDRIVEN bit, so the reference read X and the value could not be
// computed at all -- `eval` reported "Missing value for \NumRounds" where
// read_slang evaluates it fine.  Same class as the $unit enum constant that
// `is_unit_enum_const_net()` already drops.
//
// This one was a REAL defect, not a noisy warning: the constant was missing,
// not merely unannounced.
module dut #(parameter int NumPresentRounds = 31)
  (input logic [31:0] a, output logic [31:0] o);
  logic [31:0] r;
  always_comb begin
    r = '0;
    for (int k = 0; k < 2; k++) begin
      localparam logic [4:0] NumRounds = 5'(unsigned'(NumPresentRounds));
      r = r | (a ^ {27'h0, NumRounds});
    end
  end
  assign o = r;
endmodule
