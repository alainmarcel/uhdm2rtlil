NOT SYNTHESIZABLE -- classified, not converted.

Class: tagged union
`union tagged` and the `matches` pattern forms over it are supported by NONE of
the three frontends, so a converted test would fail on all of them rather than on
ours.  Measured 2026-10-31 on a minimal `union tagged packed` with `un = tagged
v1 (x)` driving a real output:

    read_verilog : syntax error, unexpected TOK_ID, expecting TOK_PACKED or '{'
    read_slang   : unsupported language feature
    read_uhdm    : Warning: Assignment RHS is not an expression (type=668)
                   (accepted, then the output proves nothing -- silently wrong)

read_uhdm is the only one that accepts the file and then gets it wrong, which is
worth fixing on its own; recorded here rather than converted, because until it IS
fixed there is no frontend to compare against.  If `union tagged` gains support,
re-triage by grepping NOTE.md for this class.
