// A struct PORT whose member is a packed ARRAY OF STRUCTS, read as
// `port.arr[k].member[l:r]` -- iDMA's nd midend
// `nd_req_i.d_req[d-2].reps[RepWidth-1:0]`.  The chained-select path added
// the element offset and then applied the part-select to the element's LOW
// bits, i.e. to its LAST member (dst_strides), never to `reps` (the FIRST
// member, 64 bits up): every repetition count read a stride, and cheshire's
// idma_nd_midend_synth row was `differs`.  read_verilog cannot parse the
// type parameter, so the gates are the read_slang miter and the structural
// value check.
package p;
  typedef logic [31:0] reps_t;
  typedef logic [31:0] strides_t;
  typedef struct packed {
    reps_t    reps;
    strides_t src_strides;
    strides_t dst_strides;
  } d_req_t;
  typedef struct packed {
    logic [7:0]   burst;
    d_req_t [1:0] d_req;
  } nd_req_t;
endpackage

module mid #(parameter type nd_req_t = logic) (
  input  logic    valid_i,
  input  nd_req_t nd_req_i,
  output logic [63:0] rep_o
);
  for (genvar d = 2; d <= 3; d++) begin : gen_dim
    logic [31:0] local_rep;
    assign local_rep = valid_i ? nd_req_i.d_req[d-2].reps[31:0] : '0;
    assign rep_o[(d-2)*32 +: 32] = local_rep;
  end
endmodule

module dut (
  input  logic        valid_i,
  input  logic [199:0] req_i,
  output logic [63:0] rep_o
);
  mid #(.nd_req_t(p::nd_req_t)) u_m (.valid_i(valid_i), .nd_req_i(req_i), .rep_o(rep_o));
endmodule
