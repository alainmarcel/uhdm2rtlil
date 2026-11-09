// YosysHQ/yosys#1369 (closed): SV interfaces fail to synthesize depending on module order
// https://github.com/YosysHQ/yosys/issues/1369
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): output o observes the interface member iface_inst.x (the snippet had no output)

// ---- b0.sv
module top(input clk, output logic o);
    assign o = iface_inst.x;
    iface #(.YOSYS_BUG_KEEP_IFACE(1)) iface_inst();
    submod submod_inst(.clk, .ifaceport(iface_inst));
endmodule

// ---- b1.sv
module submod(input clk, iface ifaceport);
    assign ifaceport.x = 1;
endmodule

// ---- b2.sv
// We need a dummy parameter when instantiating interfaces or they fail to synthetize
interface iface #(YOSYS_BUG_KEEP_IFACE = 0) ();
    logic x;
endinterface

