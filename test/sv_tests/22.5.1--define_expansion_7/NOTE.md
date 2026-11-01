NEGATIVE TEST -- not converted, and must not be.

Upstream declares `:should_fail_because: To use a macro defined with arguments, the name of the text macro shall be followed by a list of actual arguments in parentheses, separated by commas.`

The construct under test is one a conforming tool must REJECT, so there is no
observable behaviour to synthesize: giving it a working `dut.sv` would invert the
test's meaning.  The local suite has no expect-rejection mode, so this directory
keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
