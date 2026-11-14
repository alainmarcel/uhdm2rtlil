// MikePopoloski/slang#863 (closed): Nested Module Definition Not Reflected in slang --ast-json Output
// https://github.com/MikePopoloski/slang/issues/863
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top(input logic CLK, output logic RST);

    module nested(input logic CLK, output logic RST);
    endmodule

endmodule

