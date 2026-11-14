// MikePopoloski/slang#1798 (closed): Unused output / inout modport can suppress `-Wundriven-net` on interface signals
// https://github.com/MikePopoloski/slang/issues/1798
// Code block(s) from the issue (variant v0); harvested by test/slang_issues/harvest.py

// ---- b0.sv
interface status_if;
    wire status;
    modport reader (input status);
endinterface

module status_consumer(
    status_if.reader intf,
    output wire observed_status
);
    assign observed_status = intf.status;
endmodule

module top (__o_observed_status);
    status_if intf();
    wire observed_status;

    status_consumer u_consumer(
        .intf(intf),
        .observed_status(observed_status)
    );

    // Expected and actual:
    // warning: status is never driven (-Wundriven-net)

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o_observed_status;
  assign __o_observed_status = observed_status;
endmodule

