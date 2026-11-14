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

module top (__i_intf_a, __o_intf_b);
    logic a;
    logic b;

    I intf();

    dut_device dut(
        .a (intf.a),
        .b (intf.b)
    );

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_intf_a;
  output logic __o_intf_b;
  assign intf.a = __i_intf_a;
  assign __o_intf_b = intf.b;
endmodule

