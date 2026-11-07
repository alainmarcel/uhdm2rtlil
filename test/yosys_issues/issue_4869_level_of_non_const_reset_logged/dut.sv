// YosysHQ/yosys#4869 (closed): level of non-const reset logged incorrectly? after #4569
// https://github.com/YosysHQ/yosys/issues/4869
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module non_const_reset(
    input clk,
    input rstn,
    input rstval,
    output reg value
);
    wire value_next = ~value;

    always_ff @ (posedge clk or negedge rstn)
        if (!rstn)
            value <= rstval;
        else
            value <= value_next;
endmodule

