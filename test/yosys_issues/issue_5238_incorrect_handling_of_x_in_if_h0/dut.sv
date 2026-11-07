// YosysHQ/yosys#5238 (closed): Incorrect handling of `x` in if blocks (`if (x) else` ) ?
// https://github.com/YosysHQ/yosys/issues/5238
// Code block(s) from the issue (variant h0); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module minimal_repro (
    input logic clk,
    output logic out
);
    logic condition;
    logic q1 = 1'bx; // Start with x
    
    always @(posedge clk) begin
        q1 <= 0;
    end

    assign condition = ~q1;

    always @(posedge clk) begin
        if (condition) begin
            // Do nothing: out retains its previous value
        end else begin
            out <= 1'b1;
        end
    end
endmodule

