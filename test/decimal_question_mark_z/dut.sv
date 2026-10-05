// IEEE 1800-2017 5.7.1: in a sized literal `?` is an alternative spelling of
// z, so `16'sd?` is `16'sbz` (the LRM's own example).  Surelog stores it as
// the decimal value "?" and read_uhdm stopped with "Failed to parse decimal
// constant" (chipsalliance/sv-tests 5.7.1--integers-signed).
module dut (
    input  logic [15:0] a,
    output logic [15:0] y,
    output logic [15:0] z16,
    output logic [3:0]  z4
);
  assign z16 = 16'sd?;          // all z
  assign z4  = 4'd?;            // all z
  assign y   = a ^ 16'sd 6;     // an ordinary signed decimal still folds
endmodule
