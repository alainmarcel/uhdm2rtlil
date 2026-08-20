// An UNPACKED array port whose element type is a TYPE PARAMETER, on a module
// that only PASSES IT THROUGH to a child instance:
//
//     output resp_t mem_resp_o [N-1:0]
//
// This is CVA6 hpdcache_mem_resp_demux's shape (as seen from its equivalence
// wrapper).  Surelog presents such a port as an array_VAR rather than an
// array_net, and import_port's unpacked-dimension recovery only searched
// Array_nets() — so the port kept the width of a SINGLE ELEMENT (69 bits
// instead of 138 in CVA6; 36 instead of 72 here).
//
// NOTE a version of this test that drives the port from a local always_comb
// instead of a child instance does NOT reproduce: that shape presents as an
// array_net and was already recovered correctly.  The pass-through is the
// part that matters.
package pk;
  typedef struct packed {
    logic [31:0] data;
    logic [2:0]  id;
    logic        err;
  } resp_t;                       // 36 bits
endpackage

module child #(
    parameter type resp_t = pk::resp_t,
    parameter int  N      = 2
) (
    input  resp_t in_i  [N-1:0],
    output resp_t out_o [N-1:0]
);
  always_comb begin
    for (int i = 0; i < N; i++) out_o[i] = in_i[i];
  end
endmodule

module dut #(
    parameter type base_resp_t = pk::resp_t,
    parameter type resp_t      = base_resp_t,   // chained, as in CVA6
    parameter int  N           = 2
) (
    input  logic  clk_i,
    input  resp_t in_i  [N-1:0],   // 2*36 = 72
    output resp_t out_o [N-1:0],   // 2*36 = 72
    output resp_t single_o         // control: one element = 36
);
  child #(
      .resp_t(resp_t),
      .N(N)
  ) u_child (
      .in_i (in_i),
      .out_o(out_o)
  );

  assign single_o = in_i[0];
endmodule
