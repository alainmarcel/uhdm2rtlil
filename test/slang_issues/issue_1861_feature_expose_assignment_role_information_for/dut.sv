// MikePopoloski/slang#1861 (closed): [feature] Expose assignment-role information for logic variables
// https://github.com/MikePopoloski/slang/issues/1861
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module ContinuousLogic (
    input logic a,
    output logic q
);
    assign q = a;
endmodule

// ---- b1.sv
module CombinationalLogic (
    input logic a,
    input logic b,
    output logic q
);
    always_comb begin
        q = a & b;
    end
endmodule

// ---- b2.sv
module LatchLogic (
    input logic en,
    input logic d,
    output logic q
);
    always_latch begin
        if (en)
            q = d;
    end
endmodule

// ---- b3.sv
module InferredLatchLogic (
    input logic en,
    input logic d,
    output logic q
);
    always_comb begin
        if (en)
            q = d;
        // q is not assigned when en is false
    end
endmodule

// ---- b4.sv
module RegisterLogic (
    input logic clk,
    input logic d,
    output logic q
);
    always_ff @(posedge clk) begin
        q <= d;
    end
endmodule

