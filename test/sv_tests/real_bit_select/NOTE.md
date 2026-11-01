NEGATIVE TEST -- not converted, and must not be.

Upstream declares `:should_fail_because: it is illegal to do bit select on real data type`

The construct under test is one a conforming tool must REJECT, so there is no
observable behaviour to synthesize: giving it a working `dut.sv` would invert the
test's meaning.  The local suite has no expect-rejection mode, so this directory
keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
