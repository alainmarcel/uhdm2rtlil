// MikePopoloski/slang#798 (closed): Wrong type printed for type-mismatch error on wildcard connection
// https://github.com/MikePopoloski/slang/issues/798
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
interface intf (
    input bit [4:0] a
);
endinterface

module top;
    logic [4:0] a;

    intf intf_i(
        .*
    );
endmodule

