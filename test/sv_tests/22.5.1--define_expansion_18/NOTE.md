NEGATIVE TEST -- not converted, and must not be.

Upstream declares `:should_fail_because: For a macro with arguments, the parentheses are always required in the macro call, even if all the arguments have defaults.`

The construct under test is one a conforming tool must REJECT, so there is no
observable behaviour to synthesize: giving it a working `dut.sv` would invert the
test's meaning.  The local suite has no expect-rejection mode, so this directory
keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
