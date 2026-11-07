// YosysHQ/yosys#4476 (closed): Variable Part Selects
// https://github.com/YosysHQ/yosys/issues/4476
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module part_select3 (
    input logic clk,
    input logic rst,
    input logic [1:0] data_in,
    input logic [1:0] select,
    output logic [10:0] data_out
);
 
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      data_out <= '0;
    end else begin
      data_out[select * 3 + 3 +: 2] <= data_in;
    end
  end
endmodule

