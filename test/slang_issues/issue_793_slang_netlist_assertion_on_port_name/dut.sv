// MikePopoloski/slang#793 (closed): slang-netlist assertion on port name collision with unused modules
// https://github.com/MikePopoloski/slang/issues/793
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module test (
             input i1,
             input i2,

             output o1
             );

   cell_a i_cell_a(
                   .d1(i1),
                   .d2(i2),
                   .c(o1)
                   );
endmodule


module cell_a(
              input  d1,
              input  d2,

              output c);

   assign c = d1 + d2;
endmodule

// unused
module cell_b(
              input  a,
              input  b,

              output z);

   assign z = a || b;
endmodule

// unused
module cell_c(
              input  a,
              input  b,

              output z);

   assign z = (!a) && b;
endmodule

