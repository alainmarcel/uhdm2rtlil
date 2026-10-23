// `cond ? signal : {W{1'b1}}` with a CONSTANT condition, inside a generate
// loop, as one operand of a concatenation (OpenTitan prim_sram_arbiter's
// per-requester packing).  In a generate scope the reader hands every
// operation to UHDM's ExprEval first; with the condition constant it returns
// the selected arm -- the replication -- as a 64-bit integer, not the arm's
// 32 bits, so the concat gained 32 bits at the bottom and every field above
// it was shifted and truncated: sram_addr_o read write-data bits on every
// cycle (286 diverging co-simulated cycles, read_slang clean).
module dut #(parameter bit EnMask = 1'b0) (
  input  logic [1:0]  w,
  input  logic [11:0] a [2],
  input  logic [31:0] d [2],
  input  logic [31:0] m [2],
  output logic [76:0] o0, o1
);
  typedef struct packed { logic write; logic [11:0] addr; logic [31:0] wdata; logic [31:0] wmask; } req_t;
  req_t p [2];
  for (genvar i = 0; i < 2; i++) begin : g
    assign p[i] = { w[i], a[i], d[i], (EnMask) ? m[i] : {32{1'b1}} };
  end
  assign o0 = p[0];
  assign o1 = p[1];
endmodule
