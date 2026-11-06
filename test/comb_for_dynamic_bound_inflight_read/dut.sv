// A comb `for` loop whose bound is a RUNTIME signal is unrolled to the bound's
// maximum with a `(i <= bound)` guard on every iteration.  The body's writes
// must reach the in-flight values MUXED under that guard: a later read of the
// written signal in the same block (`y = d & mask`) saw every iteration's
// write as unconditional and read the constant 8'hFF -- cheshire obi_uart_tx's
// word-length mask (`for (int i = 0; i <= word_len_bits; i++)
// word_len_mask[i] = 1'b1; ... fifo_data_i = char_tx & word_len_mask`), which
// then masked nothing (8 diverging co-simulated cycles, read_slang clean).
// read_verilog cannot unroll a non-constant bound at all, so the test is
// UHDM-only: the values are proven structurally and against read_slang.
module dut (
  input  logic [1:0] wl,
  input  logic [7:0] d,
  output logic [7:0] y,
  output logic [7:0] mask_o,
  output logic [7:0] y2
);
  logic [2:0] bits;
  logic [7:0] mask;
  always_comb begin
    mask = '0;
    case (wl)
      2'b00:   bits = 3'd4;
      2'b01:   bits = 3'd5;
      2'b10:   bits = 3'd6;
      default: bits = 3'd7;
    endcase
    for (int i = 0; i <= bits; i = i + 1) begin
      mask[i] = 1'b1;
    end
    y      = d & mask;    // same-block read of the guarded writes
    mask_o = mask;
    // A second guarded read, through a later conditional, to pin the mux
    // and not only the final value.
    y2 = '0;
    if (wl != 2'b11) y2 = d & mask;
  end
endmodule
