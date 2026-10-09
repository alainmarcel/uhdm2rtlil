// An unpacked dimension sized by a $unit localparam from ANOTHER file -- on a
// port and on a local array.
//
// Surelog classified `[W]` here as an ASSOCIATIVE array: compileDimensions
// compiles a dimension name that did not reduce to a value as a typespec and,
// because an unknown name compiles to an unsupported_typespec rather than to
// nothing, took that as "the name is a type".  A $unit localparam from
// another file is not visible to the reduce at that point, so the dimension
// became `range { 0 .. "associative" }` with no size anywhere; read_uhdm read
// the marker's bytes as the element count and asked yosys for a
// 1,953,068,646-bit wire (`Assert width >= 0 && width < RTLIL::WIDTH_LIMIT`).
// Declared in the same file, in a package, or as a module parameter the same
// `[W]` was fine.  RSD's SourceCAM, DecodedBranchResolver and ReadyBitTable
// were the three rows.  Fixed in Surelog #4210 (bumped here).
module unit_param_unpacked_port_dim
  (input  logic [W-1:0]     xin,
   input  logic [W*K*2-1:0] yin,
   input  logic             x [W],      // the RSD shape: a PORT with the $unit dim
   output logic             o,
   output logic [1:0]       s,
   output logic             p);
  logic [1:0] y [W][K];
  always_comb
    for (int i = 0; i < W; i++)
      for (int j = 0; j < K; j++)
        y[i][j] = yin[(i*K + j)*2 +: 2];
  assign o = xin[0] ^ xin[W-1] ^ y[1][1][0];
  assign s = y[0][0] + y[W-1][K-1];
  assign p = x[0] ^ x[W-1];
endmodule
