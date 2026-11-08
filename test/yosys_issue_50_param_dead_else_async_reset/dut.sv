// YosysHQ/yosys#50 (bram_initialization): a parameter-guarded if/else inside
// an async-reset block.  With HL == 0 the else arm is DEAD, so `qr` is assigned
// nowhere live: it must not become a register (a dead arm used to keep it in
// the process, its reset arm then held it, and proc_arst aborted with
// "Async reset yields non-constant value 1'm").  With HL != 0 both registers
// exist and `qr` resets to 0.
module child #(parameter HL = 0) (input logic clock, reset, a,
                                  output logic q, output logic r);
  reg qr;
  always @(posedge clock or negedge reset)
  begin
    if (!reset) begin
      q <= 1'b0;
      if (HL != 0) qr <= 1'b0;
    end else begin
      if (HL == 0) q <= a;
      else begin qr <= a & !qr; q <= qr; end
    end
  end
  assign r = qr;
endmodule

module dut(input logic clock, reset, a, output logic q0, q1, r1);
  logic r0_unused;
  child #(.HL(0)) c0 (.clock(clock), .reset(reset), .a(a), .q(q0), .r(r0_unused));
  child #(.HL(1)) c1 (.clock(clock), .reset(reset), .a(a), .q(q1), .r(r1));
endmodule
