// YosysHQ/yosys#6433 (open): `read_verilog -sv`: a procedural `for` loop with a 2^32 - 1 (or 2^64 - 1) iteration bound is unrolled without a limit or a diagnostic; without `-defer` the default parameters are enough to trigger it
// https://github.com/YosysHQ/yosys/issues/6433
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
// unroll.sv
module unroll_at_default #(parameter int unsigned PIPE = 0) (input logic [3:0] a, output logic [3:0] y);
  always_comb begin
    int i;
    logic done;
    y = a;
    i = 0;
    done = (PIPE == 0);
    if (!done)
      for (i = 0; i < PIPE - 1; i = i + 1)   // PIPE - 1 is unsigned 32-bit: 2^32 - 1 iterations at PIPE = 0
        y = y + 4'd1;
  end
endmodule
module top (input logic [3:0] a, output logic [3:0] y);
  unroll_at_default #(.PIPE(1)) u (.a(a), .y(y));   // 0 iterations here
endmodule

