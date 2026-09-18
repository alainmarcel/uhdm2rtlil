// Regression for Caliptra sha3_reg's 26 driver-driver conflicts.
//
// Each always_comb declares its OWN `automatic` local.  They were promoted to
// one module wire named after the variable, so every block drove it; the block
// whose write is unconditional then collapsed that wire onto its own source
// and the other blocks' latches drove THAT signal — in sha3_reg they ended up
// driving the register block's `hwif_in` input port.
module dut (
  input  logic clk,
  input  logic sel,
  input  logic a_i,
  input  logic b_i,
  output logic a_o,
  output logic b_o,
  output logic c_o
);
  logic a_q, b_q, c_q;

  always_comb begin
    automatic logic next_c;
    next_c = a_i;          // unconditional: this block's local folds to a_i
    a_o    = next_c ^ a_q;
  end

  always_comb begin
    automatic logic next_c;
    automatic logic load_next_c;
    next_c      = b_q;
    load_next_c = 1'b0;
    if (sel) begin
      next_c      = b_i;
      load_next_c = 1'b1;
    end
    b_o = next_c & load_next_c;
  end

  always_comb begin
    automatic logic next_c;
    next_c = c_q;
    if (!sel) next_c = a_i ^ b_i;
    c_o = next_c;
  end

  always_ff @(posedge clk) begin
    a_q <= a_o;
    b_q <= b_o;
    c_q <= c_o;
  end
endmodule
