CONVERTED, with the `neither condition holds` case left out.

As for priority_if: `unique`/`unique0` without a final else is a user assertion a
tool may exploit, so the hold case is tool-defined and is not proven, and the
uhdm-vs-verilog formal comparison is skipped.  What is proven is each arm.
