// IEEE 1800-2023 11.4.14.3: a streaming concatenation as an assignment TARGET
// unpacks the right-hand side into its operands, left to right ({>>}) or with
// its slices reversed ({<<N}).
module dut(input  logic [15:0] in,
           output logic [3:0] a, b, c, d,
           output logic [7:0] hi, lo,
           output logic [15:0] rev);
  always_comb begin
    {>>{a, b, c, d}} = in;
    {<<8{hi, lo}} = in;
    {<<{rev}} = in;
  end
endmodule
