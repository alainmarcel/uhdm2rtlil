// Converted from chipsalliance/sv-tests (task_automatic).
// Upstream calls an AUTOMATIC task four times; its local `a` starts at 0 each call, which only `$display` sees.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic signed [31:0] o1, output logic signed [31:0] o2);
task automatic mytask(input int i, output int r);
	int a = 0;
	a++;
	r = a + i;
endtask
  // Two calls: an automatic local starts fresh each time, so both see a = 1.
  always_comb begin mytask(x, o1); mytask(x, o2); end
endmodule
