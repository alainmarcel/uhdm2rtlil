// A part-select of a PACKED MULTI-DIM function local selects along the OUTER
// dimension (LRM 7.4.5): `m[S-1:1] = '0` clears S-1 whole W-bit elements.
// The reader scaled a bit-select index by the element width but took the
// part-select bounds as BIT positions, so this cleared bits [3:1] of
// element 0 -- the seed staged in m[0] one statement earlier -- and left
// elements 1..S-1 untouched.  OpenTitan prim_gf_mult's gen_matrix is this
// shape (300 diverging co-simulated cycles, read_slang clean).  The
// indexed form `m[k +: n]` selects elements the same way.
module dut (
  input  logic [7:0] seed,
  output logic [7:0] o0,
  output logic [7:0] o1,
  output logic [7:0] o2,
  output logic [7:0] o3,
  output logic [7:0] p0,
  output logic [7:0] p1,
  output logic [7:0] p2,
  output logic [7:0] p3
);
  localparam int S = 4, W = 8;

  function automatic logic [S-1:0][W-1:0] gen(input logic [W-1:0] s);
    logic [S-1:0][W-1:0] m;
    m[0]     = s;
    m[S-1:1] = '0;            // elements 3..1, NOT bits 3..1 of element 0
    m[1]     = m[0] << 1;
    return m;
  endfunction

  function automatic logic [S-1:0][W-1:0] gen_idx(input logic [W-1:0] s);
    logic [S-1:0][W-1:0] m;
    m        = '0;
    m[0]     = s;
    m[2 +: 2] = {s ^ 8'hff, ~s};  // elements 3 and 2
    return m;
  endfunction

  logic [S-1:0][W-1:0] mm, mi;
  assign mm = gen(seed);
  assign mi = gen_idx(seed);
  assign o0 = mm[0];
  assign o1 = mm[1];
  assign o2 = mm[2];
  assign o3 = mm[3];
  assign p0 = mi[0];
  assign p1 = mi[1];
  assign p2 = mi[2];
  assign p3 = mi[3];
endmodule
