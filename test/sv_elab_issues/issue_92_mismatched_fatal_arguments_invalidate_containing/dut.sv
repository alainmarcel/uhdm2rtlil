// povik/sv-elab#92 (closed): Mismatched `$fatal` arguments invalidate containing procedural block
// https://github.com/povik/sv-elab/issues/92
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top(input clk);
    always @(posedge clk) begin
        // ... long procedure
        $fatal("foo");
    end
endmodule

