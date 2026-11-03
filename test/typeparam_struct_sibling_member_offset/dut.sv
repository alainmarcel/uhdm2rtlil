// A struct member declared over a `parameter type` sits BELOW the member being
// read: its width is part of that member's OFFSET.  The reader measured such a
// sibling at the declaration default (`logic`, 1 bit) while the wire itself
// was already the bound width, so `req.dp` was taken from [11:1] of a 74-bit
// request instead of [73:63] (PULP idma's `idma_r_req_t`, `read_meta_channel_t
// ar_req` bound to the AXI AR channel by the synth wrapper; cheshire's six
// idma_backend_synth rows).  read_verilog cannot parse type parameters, so
// the gates are the read_slang miter and the structural value check.
module mid #(
  parameter type meta_t = logic
) (
  input  logic [7:0] a_i,
  input  meta_t      m_i,
  output logic [7:0] dp_o,
  output meta_t      m_o
);
  typedef struct packed {
    logic [7:0] dp;      // MSB member: its offset is the width of `ar` below
    meta_t      ar;      // type-parameter member, 1 bit by default, 11 bound
  } req_t;
  req_t req;
  assign req.dp = a_i;
  assign req.ar = m_i;
  // The reads go through CHILD INSTANCE PORTS, as idma's do
  // (`.data_i(r_req.r_dp_req)`): a port actual is imported without the
  // instance scope a body expression has.
  leaf #(.W(8))  u_dp (.d_i(req.dp), .d_o(dp_o));
  leaf #(.W($bits(meta_t))) u_ar (.d_i(req.ar), .d_o(m_o));
endmodule

module leaf #(parameter int W = 1) (input logic [W-1:0] d_i, output logic [W-1:0] d_o);
  assign d_o = d_i;
endmodule

module dut (
  input  logic [7:0]  a_i,
  input  logic [10:0] m_i,
  output logic [7:0]  dp_o,
  output logic [10:0] m_o
);
  typedef struct packed {
    logic [1:0] id;
    logic [7:0] addr;
    logic       valid;
  } ar_t;
  mid #(.meta_t(ar_t)) u_mid (.a_i(a_i), .m_i(m_i), .dp_o(dp_o), .m_o(m_o));
endmodule
