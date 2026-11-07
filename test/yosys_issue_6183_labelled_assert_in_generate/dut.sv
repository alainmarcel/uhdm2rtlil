// YosysHQ/yosys#6183: a LABELLED immediate assertion inside an always_comb in a
// generate-for (`test_i: assert (...)`) made read_verilog report a name
// conflict between the loop iterations.  Every iteration must read and keep
// its own check; the datapath is the inversion the asserts guard.
module dut (input [3:0] in, output [3:0] out);
  assign out = ~in;
  genvar i;
  generate for (i = 0; i < 4; i = i + 1) begin : g
    always_comb begin
      test_i: assert (in[i] == ~out[i]);
    end
  end endgenerate
endmodule
