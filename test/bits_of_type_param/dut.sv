// `$bits(T)` where T is a TYPE PARAMETER bound to a package struct.
// This is CVA6's hpdcache_mux/_fifo_reg/_sync_buffer shape:
//     parameter type hpdcache_req_t = hpdcache_pkg::hpdcache_req_t,
//     parameter int unsigned DATA_WIDTH = $bits(hpdcache_req_t),
//     localparam type data_t = logic [DATA_WIDTH-1:0]
// $bits() of the type parameter folded to 1, so every data port collapsed.
package pk;
  typedef struct packed {
    logic [31:0] addr;
    logic [63:0] data;
    logic        we;
  } req_t;                       // 97 bits
endpackage

module dut #(
    parameter  type      req_t      = pk::req_t,
    parameter  int       DATA_WIDTH = $bits(req_t),          // -> was 1
    localparam type      data_t     = logic [DATA_WIDTH-1:0],
    localparam int       DIRECT     = $bits(pk::req_t)       // direct: control
) (
    input  logic  clk_i,
    input  data_t d_i,
    input  logic [DIRECT-1:0] c_i,
    output logic  o
);
  assign o = ^{d_i, c_i};
endmodule
