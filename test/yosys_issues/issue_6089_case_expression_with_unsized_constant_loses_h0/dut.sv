// YosysHQ/yosys#6089 (closed): Case expression with unsized constant loses output LSB
// https://github.com/YosysHQ/yosys/issues/6089
// Code block(s) from the issue (variant h0); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top (
  input  logic [1:0] in_2,
  output logic [1:0] out_1
);
  always @* begin
    out_1 = 2'd0;
    case ('d1 & in_2)
      2'd0: out_1 = 2'd0;
      2'd1: out_1 = in_2;
      2'd2: out_1 = 2'd1;
      2'd3: out_1 = 2'd3;
      default: out_1 = 2'd0;
    endcase
  end
endmodule

