// YosysHQ/yosys#6183 (open): Name conflict when using labels inside generate blocks with read_verilog
// https://github.com/YosysHQ/yosys/issues/6183
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top (
    input [3:0] in,
    output [3:0] out
);
    assign out = ~in;

    genvar i;
    generate for (i = 0; i < 4 ; i = i+1) begin
        always_comb begin
            test_i:  assert (in[i] == ~out[i]);
        end
    end
        
    endgenerate
endmodule

