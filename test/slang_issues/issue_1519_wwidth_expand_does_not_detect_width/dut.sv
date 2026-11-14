// MikePopoloski/slang#1519 (closed): -Wwidth-expand does not detect width mismatches in packed-variable assignments
// https://github.com/MikePopoloski/slang/issues/1519
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (__o_b);

    localparam bit [4:0][7:0] A = {
        6'd2,
        6'd4,
        6'd9,
        6'd24,
        6'd24
    };

    logic [4:0][7:0] b;

    always_comb begin
        b = {
            6'd2,
            6'd4,
            6'd9,
            6'd24,
            6'd24
        };

    end


  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic [39:0] __o_b;
  assign __o_b = b;
endmodule

