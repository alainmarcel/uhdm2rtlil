// A later non-blocking write to PART of a register wins over the earlier
// conditional whole-register writes in the same always block (LRM 9.4.2: the
// last NBA scheduled in a time step).  ZipCPU's pffifo aligns its program
// counter that way:
//
//     if (i_reset) o_pc <= 0; else if (i_new_pc) o_pc <= i_pc; else ...
//     o_pc[$clog2(INSN_WIDTH/8)-1:0] <= 0;
//
// read_verilog trims the conditional writes to the bits the later one does
// not cover.  The reader did that for a whole-wire late write but kept an
// always_ff guard on the part-select branch, so the switch's full-width
// writes stayed and -- RTLIL applies a case's actions BEFORE its switches --
// won: the low bits followed i_pc / the incremented pc, 103 co-simulated
// divergences on pffifo.  A `$clog2` bound on the select is incidental; the
// shape is the late partial write.
module dut #(parameter INSN_WIDTH = 32, parameter AW = 12) (
  input i_clk, input i_reset, input i_new_pc, input [AW-1:0] i_pc, input i_step,
  output reg [AW-1:0] o_pc
);
  always @(posedge i_clk) begin
    if (i_reset)        o_pc <= 0;
    else if (i_new_pc)  o_pc <= i_pc;
    else if (i_step)    o_pc <= o_pc + INSN_WIDTH/8;
    o_pc[$clog2(INSN_WIDTH/8)-1:0] <= 0;
  end
endmodule
