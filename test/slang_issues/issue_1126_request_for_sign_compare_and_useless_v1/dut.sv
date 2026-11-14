// MikePopoloski/slang#1126 (closed): Request for sign-compare and useless-cast warning relaxation involving genvar type
// https://github.com/MikePopoloski/slang/issues/1126
// Code block(s) from the issue (variant v1); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top;
    localparam width=32;
    logic [1:0][width-1:0] a;

    for (genvar i = 0; i < 2; i++) begin
        always_comb a[i] = $bits(a[i])'(i);
    end
endmodule

