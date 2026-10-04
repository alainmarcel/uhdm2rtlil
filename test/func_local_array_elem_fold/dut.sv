// A constant function that stages values in a LOCAL UNPACKED ARRAY and
// combines the elements, called as the WHOLE right-hand side so Surelog's
// ExprEval folds the call before the reader ever sees it.  ExprEval stored
// the array as its element vector, one bit per index, and `st[0] ^ st[1]`
// folded to 1 instead of 58'h300_0000_0000_0001 (verilog-ethernet's
// lfsr_mask; chipsalliance/UHDM#1161).  read_slang folds it correctly, so
// the slang miter is the gate; `^ a` on y_mix keeps one call on the
// reader's own evaluator as a control.
module dut (input [63:0] a, output [63:0] y_direct, output [63:0] y_loop, output [63:0] y_mix);
  function [63:0] f_direct(input [31:0] dummy);
    reg [57:0] st [0:1];
    begin
      st[0] = 58'h200_0000_0000_0001;
      st[1] = 58'h100_0000_0000_0000;
      f_direct = st[0] ^ st[1];
    end
  endfunction
  function [63:0] f_loop(input [31:0] dummy);
    reg [57:0] st [0:1];
    integer k;
    begin
      st[0] = 58'h200_0000_0000_0001;
      st[1] = 58'h100_0000_0000_0000;
      f_loop = 0;
      for (k = 0; k < 2; k = k + 1) f_loop = f_loop ^ st[k];
    end
  endfunction
  assign y_direct = f_direct(0);
  assign y_loop   = f_loop(0);
  assign y_mix    = f_direct(0) ^ a;
endmodule
