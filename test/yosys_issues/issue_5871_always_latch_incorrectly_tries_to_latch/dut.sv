// YosysHQ/yosys#5871 (closed): always_latch incorrectly tries to latch address of an array
// https://github.com/YosysHQ/yosys/issues/5871
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): read port added: q = register[raddr] over a new input raddr (the latched array was unobservable); the always_latch write is unchanged

// ---- b0.sv
module examplename(input[3:0] addr, input we, input[31:0] data, input[3:0] raddr, output[31:0] q);
logic[31:0] register[0:15];
assign q = register[raddr];
always_latch
    if (we)
         register[addr] = data;
endmodule

