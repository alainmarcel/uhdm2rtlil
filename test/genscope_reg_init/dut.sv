// hdl-util/hdmi serializer.sv: `logic internal_reset = 1'b1;` declared INSIDE a
// generate block and cleared by an always_ff -- the initializer is the
// register's power-up value (an `init` attribute), the module holds reset for
// exactly one clk_pixel.
module dut #(parameter int N = 3) (input logic clk_pixel, input logic reset, output logic rst_o, output logic rst_plain_o);
  logic plain_reset = 1'b1;
  always_ff @(posedge clk_pixel) plain_reset <= 1'b0;
  assign rst_plain_o = reset || plain_reset;
  generate
    if (N > 0) begin : g
      logic internal_reset = 1'b1;
      always_ff @(posedge clk_pixel) internal_reset <= 1'b0;
      assign rst_o = reset || internal_reset;
    end
  endgenerate
endmodule
