// YosysHQ/yosys#3329 (open): submod command introduces 'inout' ports which results in simulation failures
// https://github.com/YosysHQ/yosys/issues/3329
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module dut (
    input clk,
    input [7:0] a, b,
    output logic [7:0] out);

reg [7:0] data;
generate
genvar i;
for(i = 0; i <= 7; i = i + 1)
begin
    always @ (posedge clk)
        data[i] <= a[i] & b[i];
end
endgenerate

always @(posedge clk)
    out <= ~data;

endmodule

