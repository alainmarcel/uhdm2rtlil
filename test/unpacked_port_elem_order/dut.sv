// The flat layout of an UNPACKED-ARRAY PORT follows the DECLARED direction of
// the dimension: its LEFT index takes the most significant bits.  That is what
// the LRM's stream operator computes (`{>>{x}}` sends the first element left,
// 11.4.14 -- Verilator prints a0a1a2a3 for x[0]=a0..x[3]=a3) and what
// read_slang emits.  So:
//
//   a [0:3]  ascending   -> a[0] at the TOP    (bits [31:24] of the flat port)
//   b [3:0]  descending  -> b[0] at the BOTTOM (bits [7:0])
//   c [4]    shorthand   -> same as [0:3], c[0] at the TOP
//
// read_uhdm used to put element 0 at the LSB for EVERY direction, so an
// ascending port came out element-reversed against read_slang and against a
// Verilator testbench -- every `x [N]` port showed up as "differs" in the
// sweeps until a flat shim hid it, and the co-sim harness (which had the same
// assumption) reported 52 phantom divergences on ibex_id_stage's
// `imd_val_q_ex_o [2]`.  reverse_unpacked_array_ports() now flips the PUBLIC
// face of an ascending port; read_verilog cannot parse these ports at all, so
// test_slang_equiv.ys is the real gate.
module unpacked_port_elem_order (
  input  logic [7:0] a [0:3],
  input  logic [7:0] b [3:0],
  input  logic [7:0] c [4],
  input  logic [1:0] sel,
  output logic [7:0] a0, b0, c0,
  output logic [7:0] a_sel, b_sel, c_sel,
  output logic [7:0] q [0:3]
);
  assign a0 = a[0];
  assign b0 = b[0];
  assign c0 = c[0];
  assign a_sel = a[sel];
  assign b_sel = b[sel];
  assign c_sel = c[sel];
  // an ascending OUTPUT array: its public face must reverse the same way
  always_comb for (int i = 0; i < 4; i++) q[i] = a[i] ^ b[i] ^ c[i];
endmodule
