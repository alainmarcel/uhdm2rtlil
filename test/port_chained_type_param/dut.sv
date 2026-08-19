module dut #(
    parameter type noc_req_t = struct packed { logic [31:0] a; logic [15:0] b; logic c; },
    parameter type req_t     = noc_req_t      // type param defaulted to ANOTHER type param
) (
    input  logic clk_i,
    input  req_t in_i,
    output req_t out_o
);
  assign out_o = in_i;
endmodule
