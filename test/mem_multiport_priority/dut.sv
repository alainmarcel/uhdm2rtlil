// Two memories written from ONE clocked process: proc_memwr accumulates all the
// sync's write ports into a single `prev_port_ids`, so each write's priority
// mask must set bits ONLY for prior writes to the SAME memory.  A bug that set
// an all-ones mask made proc_memwr index past the second memory's (independent,
// smaller) per-memid port range and SEGFAULT.  memA is written twice and memB
// once in the same always_ff — enough to reproduce (memB's write follows two
// memA ports, so its mask width would over-run without the fix).
module dut (
  input  logic        clk,
  input  logic        we,
  input  logic [3:0]  a1, a2, b1,
  input  logic [7:0]  d1, d2, d3,
  input  logic [3:0]  ra, rb,
  output logic [7:0]  qa, qb
);
  logic [7:0] memA [16];
  logic [7:0] memB [16];

  always_ff @(posedge clk) begin
    if (we) begin
      memA[a1] <= d1;
      memA[a2] <= d2;   // later write to memA wins over the earlier one
      memB[b1] <= d3;
    end
  end

  assign qa = memA[ra];
  assign qb = memB[rb];
endmodule
