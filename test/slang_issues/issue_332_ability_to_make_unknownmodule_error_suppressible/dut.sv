// MikePopoloski/slang#332 (closed): Ability to make "UnknownModule" error suppressible and include those instances in --ast-json output
// https://github.com/MikePopoloski/slang/issues/332
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- c0.sv
// top.sv

`ifndef MISSING_MODULE2
module my_module2 (
  input  logic i_clk,
  output logic o_clk
);
endmodule
`endif

module my_module (
  input  logic i_clk,
  output logic o_clk
);

  my_module2 my_module2_inst (
    .i_clk(i_clk),
    .o_clk(o_clk)
  );

endmodule

module my_module3 (
  input  logic i_clk,
  output logic o_clk
);
  my_module my_module_inst (
    .i_clk(i_clk),
    .o_clk(o_clk)
  );
endmodule


module top (
  input logic i_clk,
  output logic [15:0] o_clks
);

  my_module3 my_module3_inst (
    .i_clk(i_clk),
    .o_clk(o_clks[15])
  );

  genvar i;
  generate
    for (i=0; i < 2; i++) begin : generate_test
      my_module my_module_inst (
        .i_clk(i_clk),
        .o_clk(o_clks[i])
      );
    end : generate_test
    for (i=0; i < 2; i++) begin : generate_test2
      my_module2 my_module2_inst (
        .i_clk(i_clk),
        .o_clk(o_clks[i])
      );
    end : generate_test2
  endgenerate

endmodule

