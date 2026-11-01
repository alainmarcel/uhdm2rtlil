CONVERTED, and gated on the netlist SHAPE plus read_verilog.

Upstream's claim is a write-then-read round trip through one element of a
1024-entry array, inside a single `initial` block.  Two things make a VALUE proof
the wrong gate here:

* With `we` held low the element is never written, so `sat` reads it as a free
  value and `-prove a 8'd125` succeeds VACUOUSLY -- measured on read_verilog too,
  so it is not a reader artefact.
* `sat -seq N -prove` checks the property in every step, including step 1 before
  any clock edge, where the element is still unwritten; it fails on read_verilog
  and read_slang as well.

So the claim is structural: exactly ONE enabled register (opt correctly reduces
the array, since only element 123 is ever touched -- a memory would be wrong
here, unlike in `array_addressing` where the address is a port), carrying `wd` to
`a` under `we`.  read_verilog produces the same shape, and the uhdm-vs-verilog
comparison covers the logic.
