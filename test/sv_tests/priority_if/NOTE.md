CONVERTED, with one case deliberately left unproven.

`priority if` without a final `else` is the user ASSERTING that one of the
conditions always holds, and a tool may exploit that.  Measured 2026-11-01 at
a = 4'b0011, where both conditions are false:

    read_verilog : 2'10  (takes the second arm -- exploiting the hint)
    read_slang   : 2'11  (holds the previous value)
    read_uhdm    : 2'11  (holds the previous value)

Both readings are defensible, so that vector is NOT part of the proof: it would
fail on read_verilog, not on us.  What the test does prove is the part `priority`
actually specifies and all three agree on -- the FIRST true condition wins, which
a 0 selector exercises because both conditions hold there.
