// MikePopoloski/slang#1126 (closed): Request for sign-compare and useless-cast warning relaxation involving genvar type
// https://github.com/MikePopoloski/slang/issues/1126
// Code block(s) from the issue (variant v0); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top;
    logic valid;
    logic [7:0] a;
    logic [7:0] b;

    for (genvar i = 0; i < 8; i++) begin
        always_comb a[i] = valid && i == b;
    end
endmodule

