// IEEE 1800-2023 12.5.3: unique0 case.  Like unique, but a selector that
// matches NO item is not a violation, so the pre-case default must survive.
module dut(input  logic [2:0] sel, input logic [7:0] a, b, c,
           output logic [7:0] y);
  always_comb begin
    y = c;
    unique0 case (sel)
      3'd1: y = a;
      3'd2: y = b;
      3'd4: y = a ^ b;
    endcase
  end
endmodule
