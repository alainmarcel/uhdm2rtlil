// MikePopoloski/slang#1150 (closed): warning "vector literal too large" issued improperly when using signed constants
// https://github.com/MikePopoloski/slang/issues/1150
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module test (__o_a1, __o_a2);
localparam logic signed [3:0] a0=4'sb1000;
logic signed [3:0]  a1, a2;
assign a1=4'shf;
assign a2=-4'sb0001; // this is OK
initial begin
    $display("a0=%b [%d]",a0,a0);
    $display("a1=%b [%d]",a1,a1);
    $display("a2=%b [%d]",a2,a2);
    $finish;
end

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic [3:0] __o_a1;
  assign __o_a1 = a1;
  output logic [3:0] __o_a2;
  assign __o_a2 = a2;
endmodule

