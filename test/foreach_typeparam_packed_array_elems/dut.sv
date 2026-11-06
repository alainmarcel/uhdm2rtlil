// `foreach (data_i[i])` over a port declared `element_t [Width-1:0] data_i`
// where `element_t` is a TYPE PARAMETER bound to a 64-bit vector: the loop
// runs over the OUTER packed dimension (Width elements), not over the 64 bits
// of one element.  The elaborated port is a packed_array_var whose own range
// is `[Width-1:0]` and whose typespec is the ELEMENT type, so a reader that
// takes the dimension from the typespec iterates 64 times -- cheshire's
// serial-link stream chopper (slink_ch_alloc, NumChannels = 1) rotated its
// single 64-bit channel bit by bit and emitted zero (13 diverging co-simulated
// cycles, read_slang clean).  read_verilog cannot parse type parameters:
// UHDM-only, proven structurally and against read_slang.
package p;
  typedef logic [63:0] data_t;
endpackage

module chop #(
  parameter type element_t = logic [15:0],
  parameter int  Width     = 1
) (
  input  element_t [Width-1:0] data_i,
  output element_t [Width-1:0] data_o,
  output logic [7:0]           cnt_o
);
  always_comb begin
    data_o = '0;
    cnt_o  = '0;
    foreach (data_i[i]) begin
      cnt_o = cnt_o + 8'd1;
      data_o[Width-1-i] = data_i[i];   // element reversal
    end
  end
endmodule

module dut (
  input  p::data_t [0:0] d1,
  output p::data_t [0:0] y1,
  output logic [7:0]     cnt1,
  input  p::data_t [1:0] d2,
  output p::data_t [1:0] y2,
  output logic [7:0]     cnt2
);
  chop #(.element_t(p::data_t), .Width(1)) u1 (.data_i(d1), .data_o(y1), .cnt_o(cnt1));
  chop #(.element_t(p::data_t), .Width(2)) u2 (.data_i(d2), .data_o(y2), .cnt_o(cnt2));
endmodule
