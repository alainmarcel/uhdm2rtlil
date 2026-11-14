// MikePopoloski/slang#1725 (closed): Clocking event control rejects iff condition: @(cb iff expr)
// https://github.com/MikePopoloski/slang/issues/1725
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
interface intf_t(input logic clk);
  logic ready;
  clocking cb @(posedge clk);
    input ready;
  endclocking
endinterface

module top;
  logic clk;
  intf_t intf(clk);

  initial begin
    @(intf.cb iff intf.cb.ready);
  end
endmodule

