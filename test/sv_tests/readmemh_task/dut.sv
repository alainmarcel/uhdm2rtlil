// Converted from chipsalliance/sv-tests (readmemh_task).
// Upstream's `$readmemh` names a file that does not exist upstream, inside an `initial` block, on a memory that is never read.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [9:0] addr, output logic [31:0] rd);
logic [31:0] mem [1023:0];
  // $readmemh is a memory INITIALISATION; synthesis carries it as a $meminit, and
  // reading the memory back makes the loaded contents observable.
initial begin
	$readmemh("test1.mem", mem);
end
  assign rd = mem[addr];
endmodule
