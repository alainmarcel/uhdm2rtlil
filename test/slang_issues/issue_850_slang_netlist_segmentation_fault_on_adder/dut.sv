// MikePopoloski/slang#850 (closed): slang-netlist: Segmentation fault on adder example
// https://github.com/MikePopoloski/slang/issues/850
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module adder
  #(parameter p_width = 32)(
    input  logic [p_width-1:0] i_a,
    input  logic [p_width-1:0] i_b,
    output logic [p_width-1:0] o_sum,
    output logic               o_co
  );
  logic [p_width-1:0] sum;
  logic co;
  assign {co, sum} = i_a + i_b;
  assign o_sum = sum;
  assign o_co = co;
endmodule

