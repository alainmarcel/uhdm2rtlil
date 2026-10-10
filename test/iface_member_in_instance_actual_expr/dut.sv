// An interface member used inside an EXPRESSION that is a child instance's
// port actual (`.popHead(port.popHeadNum > 0)`, RSD ActiveList's queue
// pointer; StoreQueue's `setTail(port.toRecoveryPhase)`).  Surelog hands the
// member over as the bare elaborated logic_var named after the CHILD port
// (`...ptr.popHeadCount.popHeadNum`), not as a hier_path through the
// parent's interface port, and unpatched read_uhdm resolved nothing: the
// comparison got an EMPTY operand and the pointer never popped.
interface ifc(input logic clk, rst);
  logic [2:0] popHeadNum; logic [2:0] popTailNum; logic [2:0] pushNum;
  logic [7:0] count; logic empty;
  modport m(input clk, rst, popHeadNum, popTailNum, pushNum, output count, empty);
endinterface
module qp #(parameter SIZE = 128, PUSH_WIDTH = 2, POP_WIDTH = 2)(
  input logic clk, input logic rst, input logic pushTail, input logic popTail, input logic popHead,
  input logic [$clog2(PUSH_WIDTH):0] pushTailCount, input logic [$clog2(POP_WIDTH):0] popTailCount, input logic [$clog2(POP_WIDTH):0] popHeadCount,
  output logic [$clog2(SIZE):0] count);
  logic [$clog2(SIZE):0] regCount, nextCount;
  always_ff @(posedge clk) if (rst) regCount <= 0; else regCount <= nextCount;
  always_comb begin
    nextCount = regCount;
    if (pushTail) nextCount += pushTailCount;
    else if (popTail) nextCount -= popTailCount;
    if (popHead) nextCount -= popHeadCount;
    count = regCount;
  end
endmodule
module leaf(ifc.m port);
  logic [7:0] count;
  qp #(128, 2, 2) ptr(.clk(port.clk), .rst(port.rst),
    .popHead(port.popHeadNum > 0), .popHeadCount(port.popHeadNum),
    .pushTail(port.pushNum > 0), .pushTailCount(port.pushNum),
    .popTail(port.popTailNum > 0), .popTailCount(port.popTailNum),
    .count(count));
  always_comb begin
    port.count = count;
    port.empty = count == 0;
  end
endmodule
module iface_member_in_instance_actual_expr(input logic clk, input logic rst, input logic [2:0] ph, input logic [2:0] pt, input logic [2:0] pu, output logic [7:0] y, output logic e);
  ifc i(.clk(clk), .rst(rst));
  leaf d(.port(i.m));
  assign i.popHeadNum = ph; assign i.popTailNum = pt; assign i.pushNum = pu;
  assign y = i.count; assign e = i.empty;
endmodule
