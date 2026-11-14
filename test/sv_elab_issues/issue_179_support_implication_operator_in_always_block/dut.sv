// povik/sv-elab#179 (closed): Support implication operator `->` in `always` block
// https://github.com/povik/sv-elab/issues/179
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module test (__o_countA, __o_countB, __o_o1, __o_o2, __o_o3);

reg i1, i2, o1, o2, o3;

event triggerA, triggerB;

integer countA = 0, countB = 0;

always_comb begin
  $display("%0t: A", $time);
  o1 = i1;
  -> triggerA;
end

always @(triggerA) begin
  countA = countA + 1;
end

always_comb begin
  $display("%0t: B", $time);
  o2 = i1;
  o3 = i2;
  -> triggerB;
end

always @(triggerB) begin
  countB = countB + 1;
end

initial begin
  #1 i1 = 1;
  #1 i2 = 1;
  #1;
  if (countA === 2 && countB === 3)
    $display("PASSED");
  else
    $display("FAILED");
end


  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic [31:0] __o_countA;
  assign __o_countA = countA;
  output logic [31:0] __o_countB;
  assign __o_countB = countB;
  output logic __o_o1;
  assign __o_o1 = o1;
  output logic __o_o2;
  assign __o_o2 = o2;
  output logic __o_o3;
  assign __o_o3 = o3;
endmodule

