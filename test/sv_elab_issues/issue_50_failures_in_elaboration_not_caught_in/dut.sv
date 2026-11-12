// povik/sv-elab#50 (closed): Failures in elaboration not caught in time
// https://github.com/povik/sv-elab/issues/50
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top;
initial begin
$t(1 + 1);
end
endmodule

