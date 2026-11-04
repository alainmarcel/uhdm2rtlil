// A CONSTANT part-select of a DYNAMICALLY indexed element of an unpacked
// array as a write target: `n[idx][3:0] = t; n[idx][7:4] = m;` -- the shape of
// OpenPiton noc1buffer's per-field command writes
// (`command_buffer_next[command_wrindex][`L15_NOC1BUFFER_REQTYPE] = ...`).
// Only the `+:` form was recognised; this one was imported as a READ of the
// element and the field was assigned into the anonymous read result.
module dut(input logic v, input logic idx, input logic [3:0] t, input logic [3:0] m,
           input logic [7:0] b0, input logic [7:0] b1,
           output logic [7:0] q0, output logic [7:0] q1);
  logic [7:0] n [0:1];
  always @* begin
    n[0] = b0;
    n[1] = b1;
    if (v) begin
      n[idx][3:0] = t;
      n[idx][7:4] = m;
    end
  end
  assign q0 = n[0];
  assign q1 = n[1];
endmodule
