// A `foreach` index variable is an `int` (LRM 12.7.3) and therefore SIGNED:
// `i + s_shift_amount` with a signed negative amount must sign-extend the
// amount.  Surelog types the index with the iterated array's element typespec
// (unsigned), so a negative shift was zero-extended to a large positive one and
// the barrel shifter of cheshire's serial-link stream chopper rotated the wrong
// way (`foreach(data_i[i]) ... s_shifted_input[i+s_shift_amount] = data_i[i]`).
// The same body under `for (int i ...)` was always right.  read_verilog cannot
// parse the type parameter, so the gates are the read_slang miter and a value proof.
module dut #(
  parameter type element_t = logic [3:0],
  parameter int signed Width = 4,
  localparam int Log2Width = $clog2(Width)
)(
  input  logic [Log2Width:0] fill_i, input logic [Log2Width:0] cons_i,
  input  element_t [Width-1:0] data_i,
  output element_t [Width-1:0] shifted_o,
  output logic signed [Log2Width:0] amt_o
);
  logic signed [Log2Width:0] s_shift_amount;
  element_t [Width-1:0] s_shifted_input;
  assign s_shift_amount = fill_i - cons_i;
  assign amt_o = s_shift_amount;
  always_comb begin
    s_shifted_input = data_i;
    foreach(data_i[i]) begin
      if (i+s_shift_amount >= Width) begin
        s_shifted_input[i+s_shift_amount-Width] = data_i[i];
      end else if (i+s_shift_amount < 0) begin
        s_shifted_input[i+s_shift_amount+Width] = data_i[i];
      end else begin
        s_shifted_input[i+s_shift_amount] = data_i[i];
      end
    end
  end
  assign shifted_o = s_shifted_input;
endmodule
