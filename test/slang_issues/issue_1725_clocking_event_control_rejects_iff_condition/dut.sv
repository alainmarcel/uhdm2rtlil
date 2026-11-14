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

module top (__i_clk, __i_intf_clk);
  logic clk;
  intf_t intf(clk);

  initial begin
    @(intf.cb iff intf.cb.ready);
  end

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_clk;
  input logic __i_intf_clk;
  assign clk = __i_clk;
  assign intf.clk = __i_intf_clk;
endmodule

