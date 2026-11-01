RATCHET -- a SELECT APPLIED TO A CONCATENATION takes the wrong bits.

`{b, c}[9:6]` with b = 8'b10101100 and c = 8'b01010011 must be 4'b0001: bits 9
and 8 are b[1:0] = 00 and bits 7 and 6 are c[7:6] = 01.  read_slang gives
4'b0001; read_uhdm gives 4'b0011.

`read_verilog` cannot parse a select on a concatenation at all
(`dut.sv:9: ERROR: syntax error, unexpected '['`), so read_slang is the only
oracle and the slang miter plus this proof are the gates.  Listed in
structural_expected_fail.txt and slang_miter_expected_fail.txt; both entries must
go in the commit that fixes it.
