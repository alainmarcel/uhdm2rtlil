// In-place SLICE writes to a function local (part-select, indexed
// part-select, compound operators), also inside if/case arms and unrolled
// for loops.  The slice write used to target the mapped wire in place, so its
// RHS — reading the same local — saw the process's final value: a
// combinational loop (OpenTitan prim_cipher_pkg present_update_key*: 264
// `check` loops in the Egret top's otp_ctrl, Verilator DIDNOTCONVERGE) that
// the SAT miter still "proved".
package func_local_slice_write_ssa_pkg;
  parameter logic [15:0][3:0] SBOX4 = {4'h2, 4'h1, 4'h7, 4'h4, 4'h8, 4'hF, 4'hE, 4'h3,
                                       4'hD, 4'hA, 4'h0, 4'h9, 4'hB, 4'h6, 4'h5, 4'hC};
  function automatic logic [15:0] key_update(logic [15:0] key_in, logic [3:0] rnd);
    logic [15:0] key_out;
    key_out = {key_in[4:0], key_in[15:5]};
    key_out[15 -: 4] = SBOX4[key_out[15 -: 4]];
    key_out[11 -: 4] = SBOX4[key_out[11 -: 4]];
    key_out[6:3] ^= rnd;
    return key_out;
  endfunction
endpackage

module func_local_slice_write_ssa (
  input  logic        clk_i,
  input  logic [15:0] a_i,
  input  logic [3:0]  b_i,
  input  logic [1:0]  sel_i,
  input  logic        en_i,
  output logic [15:0] key_o,
  output logic [15:0] mix_o,
  output logic [15:0] loop_o,
  output logic [15:0] key_q
);
  function automatic logic [15:0] mix(logic [15:0] v, logic [3:0] k, logic [1:0] s, logic e);
    logic [15:0] t;
    t = v;
    if (e) begin
      t[3:0] = t[3:0] + k;
      t[7:4] = t[3:0] ^ t[7:4];
    end else begin
      t[15:12] -= k;
    end
    unique case (s)
      2'd0: t[11 -: 4] = t[15 -: 4];
      2'd1: t[8 +: 4] |= t[4 +: 4];
      2'd2: t[1:0] = t[15:14];
      default: t[9:2] = t[9:2] << 1;
    endcase
    return t;
  endfunction

  function automatic logic [15:0] rot_nibbles(logic [15:0] v);
    logic [15:0] t;
    t = v;
    for (int i = 0; i < 3; i++)
      t[i*4 +: 4] = t[i*4 +: 4] ^ t[(i+1)*4 +: 4];
    return t;
  endfunction

  assign key_o  = func_local_slice_write_ssa_pkg::key_update(a_i, b_i);
  assign mix_o  = mix(a_i, b_i, sel_i, en_i);
  assign loop_o = rot_nibbles(a_i);
  always_ff @(posedge clk_i) key_q <= func_local_slice_write_ssa_pkg::key_update(key_q ^ a_i, b_i);
endmodule
