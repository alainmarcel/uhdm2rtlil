INCLUDE PAYLOAD -- not a test, and not converted.

Upstream carries this file as a `:description: Utility for testing `include
directive`: it exists only to be included by the 22.4 cases.  It declares no
module and has nothing observable of its own, so it stays `orig.sv`-only and
inert in discovery (no `dut.sv`).  The 22.4 tests that include it keep their own
copy at the path their directive names, so each converted test is self-contained.
