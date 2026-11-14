// MikePopoloski/slang#1986 (closed): Bug in attribute value evaluation for a specific syntax of attributes
// https://github.com/MikePopoloski/slang/issues/1986
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (__i_VDD_net, __i_VSS_net);
    logic VDD_net;
    logic VSS_net;

    design_top topt (
        .VDD(VDD_net),
        .VSS(VSS_net)
    );

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_VDD_net;
  assign VDD_net = __i_VDD_net;
  input logic __i_VSS_net;
  assign VSS_net = __i_VSS_net;
endmodule

module design_top(
    (* UPF_pg_type = "primary_power" *) input VDD,
    (* UPF_pg_type = "primary_ground" *) input VSS
);
    logic net1, net2;
endmodule

