// YosysHQ/yosys#5871 (closed): always_latch incorrectly tries to latch address of an array
// https://github.com/YosysHQ/yosys/issues/5871
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module examplename(input[3:0] addr, input we, input[31:0] data);
logic[31:0] register[0:15];
always_latch
    if (we)
         register[addr] = data;
endmodule

