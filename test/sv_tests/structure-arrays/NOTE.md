RATCHET -- an ARRAY-OF-STRUCTS initialiser loses a member.

`ms_t ms[1:0] = '{'{0, 0}, '{1, 1}};` fills index 1 first, so ms[0] is '{1,1}.
read_uhdm gives ms[0].a = **0**, ms[0].b = 1, ms[1] = '{0,0}: one member of one
element is wrong.  read_verilog cannot parse an unpacked struct and read_slang
reads the file but emits no outputs for it, so the reference is the LRM.
Listed in structural_expected_fail.txt.
