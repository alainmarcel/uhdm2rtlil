// Converted from chipsalliance/sv-tests (unpacked-arrays-as-arguments-to-subroutines).
// Upstream passes an UNPACKED ARRAY to a task whose body is a `$display`.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input logic signed [31:0] x0, input logic signed [31:0] x1,
            input logic signed [31:0] x2, output logic signed [31:0] s);
task fun(input int a [2:0], output int r);
	r = a[0] + a[1] + a[2];
endtask
  always_comb begin
    int b [2:0];
    b[0] = x0; b[1] = x1; b[2] = x2;
    fun(b, s);
  end
endmodule
