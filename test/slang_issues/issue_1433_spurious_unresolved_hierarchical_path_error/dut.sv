// MikePopoloski/slang#1433 (closed): Spurious unresolved hierarchical path error
// https://github.com/MikePopoloski/slang/issues/1433
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module inner(
             input logic clk,
             input logic resetn);
   // Simple module, inner wire declaration which we will reference from top.
   wire innermost = '1;

endmodule; // inner

module example(
               input logic clk,
               input logic resetn
               );

   // Module with a silly generate loop that includes an generate-time `if`.
   generate
      for (genvar g_inner=0; g_inner<2; g_inner++) begin : gg_inner
           if (g_inner == 0) begin
              inner i(.*);
           end else if (g_inner == 1) begin
              inner i(.*);
           end;
       end : gg_inner
   endgenerate;
endmodule; // example

module top(__i_clk, __i_resetn, __o_reference);

    wire clk;
    wire  resetn;

   example dut(.*);

   // The reference to this hierarchial path fails.
   wire reference = top.dut.gg_inner[0].genblk1.i.innermost;



  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_clk;
  assign clk = __i_clk;
  input logic __i_resetn;
  assign resetn = __i_resetn;
  output logic __o_reference;
  assign __o_reference = reference;
endmodule; // top

