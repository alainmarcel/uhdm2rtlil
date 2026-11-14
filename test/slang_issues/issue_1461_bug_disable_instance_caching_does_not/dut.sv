// MikePopoloski/slang#1461 (closed): [bug] `--disable-instance-caching` does not work
// https://github.com/MikePopoloski/slang/issues/1461
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module main (
    input wire clk,
    input wire reset
);
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : cores
            core core_instance (
                .clk(clk),
                .reset(reset)
            );
        end
    endgenerate
endmodule

module core(
    input wire clk,
    input wire reset);
endmodule

