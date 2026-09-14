// A package table parameter declared with an assignment pattern
// (`logic [15:0][3:0] SH = '{...}`) passed as a FUNCTION-CALL ACTUAL inside a
// narrower assignment (OpenTitan prim_cipher_pkg::prince_shiftrows_32bit(
// state, PRINCE_SHIFT_ROWS64) assigned to a 32-bit state): the assignment
// pattern fold preferred the surrounding 32-bit context width over the
// parameter's OWN typespec and re-folded the 16-entry table at 32/16 = 2 bits
// per entry, so every shift index was truncated (the 32-bit PRINCE datapath
// wrong; the 64-bit one happened to match its context).  The pattern's own
// declared type now wins; only an anonymous pattern is sized by context.
package ppw_pkg;
  parameter logic [15:0][3:0] SH = '{4'hF, 4'hA, 4'h5, 4'h0, 4'h3, 4'hE, 4'h9, 4'h4,
                                     4'h7, 4'h2, 4'hD, 4'h8, 4'hB, 4'h6, 4'h1, 4'hC};
  function automatic logic [31:0] shiftrows_32bit(logic [31:0] state_in, logic [15:0][3:0] shifts);
    logic [31:0] state_out;
    for (int k = 0; k < 16; k++) begin
      state_out[k*2 +: 2] = state_in[shifts[k]*2 +: 2];
    end
    return state_out;
  endfunction
  function automatic logic [63:0] shiftrows_64bit(logic [63:0] state_in, logic [15:0][3:0] shifts);
    logic [63:0] state_out;
    for (int k = 0; k < 16; k++) begin
      state_out[k*4 +: 4] = state_in[shifts[k]*4 +: 4];
    end
    return state_out;
  endfunction
endpackage
module pkg_pattern_param_func_actual_width (
  input  logic [31:0] d_i,
  input  logic [63:0] d64_i,
  output logic [31:0] o32,
  output logic [63:0] o64,
  output logic [7:0]  o8
);
  always_comb o32 = ppw_pkg::shiftrows_32bit(d_i, ppw_pkg::SH);
  always_comb o64 = ppw_pkg::shiftrows_64bit(d64_i, ppw_pkg::SH);
  // the table read directly in an 8-bit context must still be the 64-bit table
  always_comb o8  = ppw_pkg::SH[1] ^ ppw_pkg::SH[14] ^ d_i[7:0];
endmodule
