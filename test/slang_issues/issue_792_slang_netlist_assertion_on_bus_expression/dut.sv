// MikePopoloski/slang#792 (closed): slang-netlist assertion on bus expression in ports
// https://github.com/MikePopoloski/slang/issues/792
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module test (
             input [1:0] in_i,
             output [1:0] out_o
             );

   wire [1:0]             in_s;

   assign in_s = in_i;

   nop i_nop(
               .in_i(in_s[1:0]), // ok: in_s, in_i, {in_i[1], in_i[0]}
               .out_o(out_o)
               );
endmodule

module nop (
             input [1:0]  in_i,
             output [1:0] out_o
             );

   // individual bits access; ok: out_o = in_i;
   assign out_o[0] = in_i[0];
   assign out_o[1] = in_i[1];
endmodule

