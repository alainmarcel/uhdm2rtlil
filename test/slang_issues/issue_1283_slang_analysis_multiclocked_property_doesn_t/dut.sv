// MikePopoloski/slang#1283 (closed): [slang][analysis] Multiclocked property doesn't warned
// https://github.com/MikePopoloski/slang/issues/1283
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (input logic a, b, c, clk);
    property q1;
        $rose(a) |-> ##[1:5] b;
    endproperty

    property q2;
        @(posedge clk) q1;
    endproperty

    always @(negedge clk)
    begin
    a1: assert property ($fell(c) |=> q1);
        // illegal: multiclocked property with contextually
        // inferred leading clocking event
    end

endmodule

