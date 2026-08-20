// The CVA6 hpdcache_mem_resp_demux shape: a child whose type parameter
// DEFAULTS to `logic` (1 bit) and is OVERRIDDEN at the instantiation, with a
// localparam type built from it carrying a packed dimension.
//
//   parameter type resp_id_t = logic,                    // default 1 bit
//   localparam int RT_DEPTH  = (1 << $bits(resp_id_t)),
//   localparam type rt_t     = resp_id_t [RT_DEPTH-1:0]
//   ...
//   assign sel = rt_i[int'(id_i)];
//
// If rt_t's element type is resolved from the DEFAULT rather than the bound
// type, the element is 1 bit and the select degenerates to an unscaled BIT
// select -- reading bit `id` instead of the element at `id*ELEM_W`.
module child #(
    parameter type id_t     = logic,                 // default: 1 bit
    localparam int DEPTH    = (1 << $bits(id_t)),
    localparam type rt_t    = id_t [DEPTH-1:0],
    localparam type sel_t   = logic [0:0]
) (
    input  rt_t  rt_i,
    input  id_t  id_i,
    output sel_t sel_o
);
  assign sel_o = rt_i[int'(id_i)];
endmodule

module dut (
    input  logic [7:0] rt_i,      // 4 elements x 2 bits
    input  logic [1:0] id_i,
    output logic       sel_o
);
  child #(.id_t(logic [1:0])) u (   // OVERRIDE: element becomes 2 bits
      .rt_i (rt_i),
      .id_i (id_i),
      .sel_o(sel_o)
  );
endmodule
