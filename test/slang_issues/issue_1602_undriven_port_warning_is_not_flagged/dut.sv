// MikePopoloski/slang#1602 (open): undriven-port warning is not flagged when the signal is driven in one of the if condition
// https://github.com/MikePopoloski/slang/issues/1602
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module testing #(
    parameter COND_A = 0
) (
    output logic a
);

generate
    if (COND_A) begin : cond_a
        assign a = 0;
    end
    else begin : default_case

    end
endgenerate

endmodule

