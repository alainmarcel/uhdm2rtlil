// RSD DCacheArray: an instance inside NESTED generate loops whose clock actual
// is an interface-port member (`.clk(port.clk)`); every RAM cell lost its
// clock connection ("Port clk has empty connection").
interface ifc(input logic clk);
  logic [3:0] d [2][2];
  logic [3:0] q [2][2];
  modport m(input clk, d, output q);
endinterface
module ram(input logic clk, input logic [3:0] wv, output logic [3:0] rv);
  always_ff @(posedge clk) rv <= wv;
endmodule
module arr(ifc.m p);
  logic [3:0] dd [2][2];
  logic [3:0] qq [2][2];
  always_comb begin
    for (int w = 0; w < 2; w++)
      for (int k = 0; k < 2; k++) begin
        dd[w][k] = p.d[w][k];
        p.q[w][k] = qq[w][k];
      end
  end
  for (genvar w = 0; w < 2; w++) begin : gw
    for (genvar i = 0; i < 2; i++) begin : gi
      ram r(.clk(p.clk), .wv(dd[w][i]), .rv(qq[w][i]));
    end
  end
endmodule
module gen_scope_iface_member_clk_actual(input logic clk, input logic [15:0] d_flat, output logic [15:0] q_flat);
  ifc i(.clk(clk));
  arr a(.p(i.m));
  for (genvar w = 0; w < 2; w++) begin : gw
    for (genvar k = 0; k < 2; k++) begin : gk
      assign i.d[w][k] = d_flat[(w*2+k)*4 +: 4];
      assign q_flat[(w*2+k)*4 +: 4] = i.q[w][k];
    end
  end
endmodule
