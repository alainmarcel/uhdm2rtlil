// YosysHQ/yosys#862 (closed): Can't put assert inside case statement
// https://github.com/YosysHQ/yosys/issues/862
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module test(input wire A);
  localparam TEST = 1;
  always_comb begin
    case (A)
      TEST: assert(1);
    endcase
  end
endmodule

