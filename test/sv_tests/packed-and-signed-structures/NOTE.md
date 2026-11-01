RATCHET -- `struct packed signed` LOSES its signedness.

`struct packed signed { bit [3:0] lo; bit [3:0] hi; } p1; p1 = 8'd200;` read into a
32-bit signed context must sign-extend: -56.  read_verilog and read_slang give
-56; read_uhdm gives **200**, i.e. it treats the struct as unsigned.  The
`unsigned` twin (`packed-and-unsigned-structures`) gives 200 on all three, which
is what localises the gap to the `signed` qualifier on a packed struct type.

Listed in structural_expected_fail.txt and slang_miter_expected_fail.txt.
