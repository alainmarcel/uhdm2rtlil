// A DYNAMIC bit-select on a packed multi-dimensional FUNCTION FORMAL bound to
// a constant table (OpenTitan prim_cipher_pkg::sbox4_8bit:
// `state_out[k*4 +: 4] = sbox4[state_in[k*4 +: 4]]` with
// `logic [15:0][3:0] sbox4` = PRINCE_SBOX4).  The function-parameter branch
// of the bit_select handler only sliced a CONSTANT index; for a dynamic one it
// returned the WHOLE mapped value, which the caller truncated to the low
// element — every S-box nibble folded to sbox4[0] (0xB) and the PRINCE cipher
// output (rom_ctrl / sram_ctrl scrambling) was a constant.  A dynamic index
// now extracts the element with a $shiftx sized by the formal's outer dim.
package ffp_pkg;
  parameter logic [15:0][3:0] SBOX4 = {4'h4, 4'hD, 4'h5, 4'hE, 4'h0, 4'h8, 4'h7, 4'h6,
                                       4'h1, 4'h9, 4'hC, 4'hA, 4'h2, 4'h3, 4'hF, 4'hB};
  function automatic logic [7:0] sbox4_8bit(logic [7:0] state_in, logic [15:0][3:0] sbox4);
    logic [7:0] state_out;
    for (int k = 0; k < 2; k++) begin
      state_out[k*4 +: 4] = sbox4[state_in[k*4 +: 4]];
    end
    return state_out;
  endfunction
  function automatic logic [31:0] sbox4_32bit(logic [31:0] state_in, logic [15:0][3:0] sbox4);
    logic [31:0] state_out;
    for (int k = 0; k < 4; k++) begin
      state_out[k*8 +: 8] = sbox4_8bit(state_in[k*8 +: 8], sbox4);
    end
    return state_out;
  endfunction
  function automatic logic [3:0] sbox4_4bit(logic [3:0] n, logic [15:0][3:0] sbox4);
    return sbox4[n];
  endfunction
  // plain vector formal with a dynamic bit index (elem_w = 1)
  function automatic logic pick_bit(logic [7:0] v, logic [2:0] i);
    return v[i];
  endfunction
endpackage
module func_formal_packed_dyn_bitselect (
  input  logic [31:0] d_i,
  input  logic [2:0]  i_i,
  output logic [31:0] o32,
  output logic [7:0]  o8,
  output logic [3:0]  o4,
  output logic        ob
);
  always_comb o32 = ffp_pkg::sbox4_32bit(d_i, ffp_pkg::SBOX4);
  always_comb o8  = ffp_pkg::sbox4_8bit(d_i[7:0], ffp_pkg::SBOX4);
  always_comb o4  = ffp_pkg::sbox4_4bit(d_i[3:0], ffp_pkg::SBOX4);
  always_comb ob  = ffp_pkg::pick_bit(d_i[15:8], i_i);
endmodule
