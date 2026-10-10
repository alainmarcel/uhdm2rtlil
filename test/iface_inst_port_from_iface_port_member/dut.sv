// An interface INSTANCE declared inside a module with its own inputs bound
// (positionally) to another interface port's members (RSD DCache:
// `DCacheIF port(lsu.clk, lsu.rst, lsu.rstStart);`).  Unpatched read_uhdm
// leaves port.clk / port.rst / port.rstStart undriven.
interface A(input logic clk, input logic rst, input logic rstStart);
  logic [3:0] y;
  modport m(input clk, rst, rstStart, output y);
endinterface
interface B(input logic clk, input logic rst, input logic rstStart);
  logic [3:0] q;
  modport c(input clk, rst, rstStart, output q);
endinterface
module leaf(B.c p);
  always_ff @(posedge p.clk) begin
    if (p.rst) p.q <= 4'd0;
    else if (p.rstStart) p.q <= 4'd1;
    else p.q <= p.q + 4'd1;
  end
endmodule
module mid(A.m lsu);
  B port(lsu.clk, lsu.rst, lsu.rstStart);
  leaf l(port);
  assign lsu.y = port.q;
endmodule
module iface_inst_port_from_iface_port_member(input logic clk, input logic rst, input logic rstStart, output logic [3:0] y);
  A a_i(.clk(clk), .rst(rst), .rstStart(rstStart));
  mid dut(.lsu(a_i.m));
  assign y = a_i.y;
endmodule
