// `bind` of a monitor interface to an adder/subtractor DUT.  The
// original snippet declared the clocking block's a/b/doAdd as
// `output`, but the interface receives them via `input` ports — so
// the clocking block can't drive them.  Verilator rightly flagged
// the contradiction; the monitor intent is preserved by making the
// clocking block sample (all `input`).

module ADD_SUB(
  input            clk,
  input [7:0]      a0,
  input [7:0]      b0,
  input            doAdd0,
  output reg [8:0] result0
);

  always @ (posedge clk)
    begin
      if (doAdd0)
        result0 <= a0 + b0;
      else
        result0 <= a0 - b0;
    end

endmodule: ADD_SUB

interface add_sub_if(
  input bit clk,
  input [7:0] a,
  input [7:0] b,
  input       doAdd,
  input [8:0] result
);

  clocking cb @(posedge clk);
    input    a;
    input    b;
    input    doAdd;
    input    result;
  endclocking

endinterface: add_sub_if

bind ADD_SUB add_sub_if add_sub_if0(
  .clk(clk),
  .a(a0),
  .b(b0),
  .doAdd(doAdd0),
  .result(result0)
);
