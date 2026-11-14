// MikePopoloski/slang#1883 (closed): Unexpected error when connecting packed struct to port of array instance
// https://github.com/MikePopoloski/slang/issues/1883
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
package pkg;
   typedef struct packed {
     logic a, b;
   } st_t;
endpackage

module sub (
  input wire en,
  input wire iv,
  output wire ov
);
   assign ov = en && iv;
endmodule
   
module top (
  input wire en,
  input wire pkg::st_t iv,
  output pkg::st_t ov
);
  sub u_sub [$bits(pkg::st_t)-1:0] (
    .en(en),
    .iv(iv),
    .ov(ov)
  ); 
endmodule

