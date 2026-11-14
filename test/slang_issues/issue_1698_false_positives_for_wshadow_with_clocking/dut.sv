// MikePopoloski/slang#1698 (closed): False positives for -Wshadow with clocking-blocks
// https://github.com/MikePopoloski/slang/issues/1698
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
interface intf;

    logic clk;
    logic a;

    clocking cb @(posedge clk);
        default input #1step;
        input a;
    endclocking

endinterface

module top;
    intf i();
endmodule

