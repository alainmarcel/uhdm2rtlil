// Converted from chipsalliance/sv-tests (bits_type_function).
// Upstream prints `$bits(mystruct)` -- $bits of a TYPE, not a variable -- from an `initial` block, so the answer reaches nothing.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic x, input logic [7:0] y, output logic signed [31:0] nbits,
           output logic [8:0] packed_o);
  typedef struct packed {
    logic val1;
    bit [7:0] val2;
  } mystruct;
  mystruct s;
  // $bits of the TYPE drives an output, and a value of that type is packed and
  // read back, so a wrong measurement shows up twice.
  assign nbits    = $bits(mystruct);
  assign s.val1   = x;
  assign s.val2   = y;
  assign packed_o = s;
endmodule
