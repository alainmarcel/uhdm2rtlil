module dut(input clock, input reset, input io_repeat, input io_enq_valid, input io_deq_ready, input [2:0] io_enq_bits_opcode,
           output io_full, output io_enq_ready, output io_deq_valid, output [2:0] io_deq_bits_opcode);
  reg full;
  reg [2:0] saved_opcode;
  wire io_deq_valid_0 = io_enq_valid | full;
  wire io_enq_ready_0 = io_deq_ready & ~full;
  always @(posedge clock) begin
    automatic logic _GEN;
    _GEN = io_enq_ready_0 & io_enq_valid & io_repeat;
    if (reset)
      full <= 1'h0;
    else
      full <= ~(io_deq_ready & io_deq_valid_0 & ~io_repeat) & (_GEN | full);
    if (_GEN)
      saved_opcode <= io_enq_bits_opcode;
  end
  assign io_full = full;
  assign io_enq_ready = io_enq_ready_0;
  assign io_deq_valid = io_deq_valid_0;
  assign io_deq_bits_opcode = full ? saved_opcode : io_enq_bits_opcode;
endmodule
