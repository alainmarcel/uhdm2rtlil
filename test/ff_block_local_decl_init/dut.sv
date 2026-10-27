// A block-local DECLARED WITH AN INITIALISER inside a clocked always block,
// read by the non-blocking updates in the same block.
//
//     always @(posedge clk) begin
//       automatic logic _GEN = ready & valid;
//       q0 <= _GEN ? d : q0;
//       ...
//
// This is how firtool stages every shared sub-expression of a register
// update, and it has NO assignment STATEMENT: the initialiser lives on the
// variable's vpiExpr, exactly as a generate-scope `integer x = -1;` does.
// The temp-wire path that records a blocking value therefore never ran, so
// every read of `_GEN` resolved to the scoped wire `\<block>._GEN`, which
// nothing drives.  Undriven, it reads as X -- and under the sweeps'
// `setundef -undriven -init -zero` as a constant 0 -- so every update took
// the else arm forever and the registers never loaded.
//
// BOOM's DivUnit held io_resp_bits_uop_* at 0 from cycle 2 this way, 299 of
// 301 co-simulated cycles, with read_slang clean; the same shape is behind
// the ALUExeUnit, BranchKillableQueue, FetchBuffer, ITLB, BTB, CSRFile and
// Frontend rows of both the boom and rocket-chip families.
//
// The second always block covers the ASYNC-RESET arm of the same shape, and
// `_GEN2` covers a local whose initialiser reads another local declared
// before it.
module ff_block_local_decl_init (
  input        clk,
  input        rst_n,
  input        ready,
  input        valid,
  input  [7:0] d,
  output [7:0] q0,
  output [7:0] q1,
  output [7:0] q2
);
  reg [7:0] r0, r1, r2;

  always @(posedge clk) begin
    automatic logic _GEN = ready & valid;
    automatic logic _GEN2 = _GEN & (d != 8'h00);
    r0 <= _GEN ? d : r0;
    r1 <= _GEN2 ? (d + 8'd1) : r1;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      r2 <= 8'h00;
    else begin
      automatic logic _GEN3 = ready | valid;
      r2 <= _GEN3 ? (d ^ 8'hff) : r2;
    end
  end

  assign q0 = r0;
  assign q1 = r1;
  assign q2 = r2;
endmodule
