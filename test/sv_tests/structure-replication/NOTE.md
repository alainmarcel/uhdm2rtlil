RATCHET -- a REPLICATION pattern into a STRUCT drops the middle member.

`struct {int X,Y,Z;} XYZ = '{3{1}};` must set all three to 1.  read_slang gives
1/1/1; read_uhdm gives X = 1, **Y = 0**, Z = 1.  Same family as the unpacked-array
replication defect (`arrays`, `arrays-replication`).  read_verilog cannot parse an
unpacked struct.  Listed in structural_expected_fail.txt and
slang_miter_expected_fail.txt.
