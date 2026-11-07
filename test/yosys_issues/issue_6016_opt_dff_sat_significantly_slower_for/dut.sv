// YosysHQ/yosys#6016 (closed): opt_dff -sat significantly slower for certain design patterns
// https://github.com/YosysHQ/yosys/issues/6016
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
// yosys -p "read_verilog -sv repro.v; hierarchy -top repro; prep; opt_dff -sat"
module repro (
  input wire clk,
  input wire rst_n,
  input wire [43:0] in,
  output reg [99:0] q
);
  function automatic satisfied(input [43:0] in_val);
    integer i, j;
    reg [3:0] p[0:10];
    reg valid, no_coll;
    begin
      for (i = 0; i < 11; i = i + 1)
        p[i] = in_val[i*4 +: 4];
      valid = 1'b1;
      for (i = 0; i < 11; i = i + 1)
        if (p[i] >= 10) valid = 1'b0;
      no_coll = 1'b1;
      for (i = 0; i < 11; i = i + 1)
        for (j = i + 1; j < 11; j = j + 1)
          if (p[i] == p[j]) no_coll = 1'b0;
      satisfied = valid && no_coll;
    end
  endfunction
  genvar i;
  generate
    for (i = 0; i < 100; i = i + 1) begin : g_
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
          q[i] <= 1'b0;
        else
          q[i] <= satisfied(in ^ i);
      end
    end
  endgenerate
endmodule

