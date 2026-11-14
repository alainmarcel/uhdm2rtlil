// MikePopoloski/slang#1971 (closed): False positive: -Wuseless-cast on width cast whose target width depends on a parameter
// https://github.com/MikePopoloski/slang/issues/1971
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module width_adapter #(
    parameter int SRC_W = 1,
    parameter int DST_W = 1
) (
    input  logic [SRC_W-1:0] in,
    output logic [DST_W-1:0] out
);
    // Catch-22:
    // - With DST_W'(in): triggers -Wuseless-cast in `u_same`
    // - Without cast:   triggers -Wwidth-expand in `u_wide`
    assign out = DST_W'(in);
endmodule

module top (__i_a, __o_b, __o_c);
    logic [0:0] a;
    logic [0:0] b;
    logic [1:0] c;

    // DST_W == SRC_W (1 == 1): triggers -Wuseless-cast
    width_adapter #(.SRC_W(1), .DST_W(1)) u_same (
        .in  (a),
        .out (b)
    );

    // DST_W > SRC_W (2 > 1): removing the cast triggers -Wwidth-expand here
    width_adapter #(.SRC_W(1), .DST_W(2)) u_wide (
        .in  (a),
        .out (c)
    );

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_a;
  assign a = __i_a;
  output logic __o_b;
  assign __o_b = b;
  output logic [1:0] __o_c;
  assign __o_c = c;
endmodule

