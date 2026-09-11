module fsyncwrap (
  input logic clk_i, rst_ni, clr_i, wvalid_i, rready_i,
  input logic [7:0] wdata_i,
  output logic wready_o, rvalid_o, full_o, err_o,
  output logic [7:0] rdata_o
);
  prim_fifo_sync #(.Width(8), .Pass(1), .Depth(9), .Secure(1)) u (
    .clk_i,.rst_ni,.clr_i,.wvalid_i,.wready_o,.wdata_i,
    .rvalid_o,.rready_i,.rdata_o,.full_o,.depth_o(),.err_o);
endmodule
