// IEEE 1800-2023 23.4: nested module declarations.  An inner module is
// visible only inside its parent, and may be instantiated there.
module dut(input logic [7:0] a, b, output logic [7:0] y, z);
  module adder(input logic [7:0] p, q, output logic [7:0] s);
    assign s = p + q;
  endmodule
  module mixer(input logic [7:0] p, output logic [7:0] s);
    assign s = {p[3:0], p[7:4]};
  endmodule
  adder u_a(.p(a), .q(b), .s(y));
  mixer u_m(.p(a ^ b), .s(z));
endmodule
