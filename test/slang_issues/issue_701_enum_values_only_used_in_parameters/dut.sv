// MikePopoloski/slang#701 (closed): Enum values only used in parameters result in unused-warning for enum typedef
// https://github.com/MikePopoloski/slang/issues/701
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module DUT #(
    parameter int p = 0
) (
    output logic a
);
    if (p) begin
        assign a = 1'b0;
    end else begin
        assign a = 1'b1;
    end
endmodule

module top (__o_a);
    typedef enum int {
        E0 = 0,
        E1 = 1,
        E2 = 2
    } my_enum_t;

    parameter int p = E0;

    logic a;
    DUT #(
        .p (p)
    ) dut(
        .a (a)
    );

    always_comb begin
        if (a) begin
            $display("a is 1");
        end
    end

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o_a;
  assign __o_a = a;
endmodule

