// MikePopoloski/slang#874 (closed): Unexpected StatementBlock Member in Syntax Tree for Simple SystemVerilog Module Using slang --ast-json
// https://github.com/MikePopoloski/slang/issues/874
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top;
    logic a [4];

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            a[2'(i)] = i;
        end
    end
endmodule

