// YosysHQ/yosys#1400 (open): Warn on mixing non-blocking and blocking assignments to the same variable
// https://github.com/YosysHQ/yosys/issues/1400
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- c0.sv
module nonblock2;
  logic a, b;

  initial begin
    a = 0;
    b = 1;
    a <= b; // evaluates, schedules,
    b <= a; // and executes in two steps
  end

  initial begin
    $monitor ($time, ,"a = %b b = %b", a, b);
    #100 $finish;
  end
endmodule

