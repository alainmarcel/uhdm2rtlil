RATCHET -- a struct member with a `rand`/`randc` QUALIFIER and an unpacked
dimension is DROPPED.

`typedef struct { rand bit i; randc integer b[K:0]; } randstruct;` with K = 9 is
1 + 10*32 = 321 bits.  read_slang gives 321; read_uhdm gives **1** -- the
`randc integer b[9:0]` member is lost entirely, so the type collapses to its
first field.  The `rand`/`randc` qualifiers are simulation-only and must be
IGNORED for synthesis, not taken as a reason to drop the member.

read_verilog cannot parse the qualifiers, so read_slang is the oracle.  Listed in
structural_expected_fail.txt; remove it there in the commit that keeps the
member.
