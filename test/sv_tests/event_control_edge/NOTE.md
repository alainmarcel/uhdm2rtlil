RATCHET -- `@(edge clk)` becomes a COMBINATIONAL LOGIC LOOP.

Measured 2026-10-31:

* `read_verilog` cannot parse it: `syntax error, unexpected TOK_ID`.
* `read_slang` REFUSES it explicitly:
  `@(edge) will not be synthesized (override with '--allow-dual-edge-ff')`.
* `read_uhdm` accepts it and emits a plain `$not` driving `a` from `a`, so
  `check` reports FOUR logic loops (one per bit) and `check -assert` fails.

So no frontend synthesizes a dual-edge flop -- that part is a shared ceiling --
but read_uhdm is the only one that silently produces a BROKEN netlist instead of
refusing, and a logic loop is never an acceptable lowering.  Either emitting a
dual-edge register or refusing the construct would close this; until then the
assertion above pins the current state.  Listed in structural_expected_fail.txt,
and it must be removed from it in the commit that fixes this.
