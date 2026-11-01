// Converted from chipsalliance/sv-tests (structure-arrays).
// Upstream initialises an ARRAY OF STRUCTS with a nested pattern and never reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] a0, output logic signed [31:0] b0,
           output logic signed [31:0] a1, output logic signed [31:0] b1);
  typedef struct {
    int a;
    int b;
  } ms_t;
  ms_t ms[1:0] = '{'{0, 0}, '{1, 1}};
  // The outer pattern fills index 1 FIRST, so ms[1] is '{0,0} and ms[0] is '{1,1}.
  assign a0 = ms[0].a; assign b0 = ms[0].b;
  assign a1 = ms[1].a; assign b1 = ms[1].b;
endmodule
