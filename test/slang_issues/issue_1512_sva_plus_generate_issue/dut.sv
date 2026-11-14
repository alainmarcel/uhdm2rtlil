// MikePopoloski/slang#1512 (closed): SVA plus generate issue
// https://github.com/MikePopoloski/slang/issues/1512
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module main
  (
   input wire clk,
   input wire reset
   );

   wire a;
   
   property delay (int CYCLES);
      @(posedge clk) disable iff (reset) ($past(a, CYCLES));
   endproperty

   localparam int TICKS = 0;

   if (TICKS < 0) begin: ticks_lt_zero
      $warning("Property was given: %0d", -TICKS);
      p: assume property (delay(-TICKS));
   end   

endmodule

