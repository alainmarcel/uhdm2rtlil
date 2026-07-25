// A combinational "next-state" unpacked array that is (a) copied whole from the
// registered array, then (b) written at a DYNAMIC index, and finally registered
// back conditionally: the cva6_fifo_v3 `mem_n`/`mem_q` shape.
//
// extract_assigned_signals expands the whole-array copy `mem_n = mem_q` into
// per-element sigs that all kept the whole-array ref_obj as their lhs_expr, so
// import_expression() returned the full element concat for every element and
// import_always_comb built ONE oversized `$0\mem_n[0]` temp shared by all
// elements — conflicting with the per-element wires the dynamic-write path
// drives.  proc_dlatch then SEGFAULTED on the malformed process.  Fixed by
// using the concrete element wire as the LHS for such expanded sigs.
module comb_array_next_state #(parameter int unsigned DEPTH = 4, parameter int unsigned DW = 32)(
    input  logic          clk_i, rst_ni, push_i,
    input  logic [$clog2(DEPTH)-1:0] write_pointer_q, read_pointer_q,
    input  logic [DW-1:0] data_i,
    output logic [DW-1:0] data_o
);
  logic [DW-1:0] mem_n [DEPTH-1:0];
  logic [DW-1:0] mem_q [DEPTH-1:0];
  logic gate_clock;
  always_comb begin
    data_o     = mem_q[read_pointer_q];
    mem_n      = mem_q;
    gate_clock = 1'b1;
    if (push_i) begin
      mem_n[write_pointer_q] = data_i;
      gate_clock = 1'b0;
    end
  end
  always_ff @(posedge clk_i or negedge rst_ni)
    if (~rst_ni) begin
      for (int i = 0; i < DEPTH; i++) mem_q[i] <= '0;
    end else if (~gate_clock) mem_q <= mem_n;
endmodule
