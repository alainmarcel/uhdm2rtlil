// An interface member inside an EXPRESSION that is a child instance's port
// actual, in a module with TWO interface ports that both carry a member of
// that name (`.rst(pa.rst || flReset)` with `pa` and `pb` both declaring
// `rst` -- RSD IssueQueue's free-list reset `port.rst || freeListReset`, with
// its other interfaces also carrying rst).  The elaborated view spells the
// member as a bare logic_net named after the CHILD port, which no name lookup
// can attribute to one interface port; unpatched read_uhdm left the operand
// EMPTY and the counter never reset.  The definition view's expression
// (`pa.rst` as written) is imported instead.
interface ifa(input logic clk, rst); logic [1:0] pop; logic [7:0] count; modport m(input clk, rst, pop, output count); endinterface
interface ifb(input logic clk, rst); logic flag; modport m(input clk, rst, output flag); endinterface
module cnt(input logic clk, input logic rst, input logic pop, input logic [1:0] popCount, output logic [7:0] count);
  always_ff @(posedge clk) if (rst) count <= 8'd16; else if (pop) count <= count - popCount;
endmodule
module leaf(ifa.m pa, ifb.m pb);
  logic flReset;
  always_ff @(posedge pa.clk) if (pa.rst) flReset <= 1'b1; else flReset <= 1'b0;
  cnt c(.clk(pa.clk), .rst(pa.rst || flReset), .pop(pa.pop > 0), .popCount(pa.pop), .count(pa.count));
  always_comb pb.flag = flReset;
endmodule
module iface_member_expr_actual_two_ports(input logic clk, input logic rst, input logic [1:0] pop, output logic [7:0] y, output logic f);
  ifa a(.clk(clk), .rst(rst)); ifb b(.clk(clk), .rst(rst));
  leaf d(.pa(a.m), .pb(b.m));
  assign a.pop = pop; assign y = a.count; assign f = b.flag;
endmodule
