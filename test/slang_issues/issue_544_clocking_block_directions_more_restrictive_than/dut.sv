// MikePopoloski/slang#544 (closed): Clocking block directions more restrictive than other tools
// https://github.com/MikePopoloski/slang/issues/544
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
interface I;
    logic clk;

    logic a;
    logic b;

    clocking cb_fabric @(posedge clk);
        output a;
        input  b;
    endclocking

    clocking cb_device @(posedge clk);
        input  a;
        output b;
    endclocking

endinterface

module dut_device(
    input  logic a,
    output logic b
);
endmodule

module top;
    logic a;
    logic b;

    I intf();

    dut_device dut(
        .a (intf.a),
        .b (intf.b)
    );
endmodule

