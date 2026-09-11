# fifo_secure_cnt_multilevel — kmac_msgfifo err_o residual root cause + fix

`prim_fifo_sync #(.Width(8),.Pass(1),.Depth(9),.Secure(1))` (`wrap.sv`).  Before
the fix, the UHDM-synth netlist raised a spurious secure-counter integrity error
(`err_o=1`) that the original RTL never asserts — from ~cycle 21, after the write
pointer wraps and the FIFO is cleared.  The DATA path (`rdata_o`/`full_o`/
`rvalid_o`/`wready_o`) is CORRECT; only `err_o` diverged.

Run `./run_cosim.sh` — co-simulates the original RTL against the UHDM-synth
netlist for 400 random cycles and checks `NO_DIVERGENCE`.  (A read_uhdm-vs-
read_slang SAT miter is SAT-HARD here: the secure counter's `up+down==2^W-1`
sum-invariant makes `sat -set-init-zero` time out, and a free `rst_ni` yields a
false 2-cycle cex — cosim from a real reset is the reliable adjudication.)

## Root cause — MULTI-LEVEL packed-array-localparam element folding

`prim_count` (Secure=1's redundant counter) keeps two counters that must always
sum to `2**Width-1`, resetting/clearing to `ResetValues[k]`:

    localparam logic [NumCnt-1:0][Width-1:0] ResetValues =
        {{Width{1'b1}} - ResetValue, ResetValue};      // {31, 0} for Width=5
    ...
    assign cnt_d[k] = clr_i ? ResetValues[k] : ...;    // k = genvar 0 | 1

`ResetValues` is a computed localparam that Surelog leaves as the SYMBOLIC concat
`{{Width{1'b1}}-ResetValue, ResetValue}` (never folded), so the frontend folds it
when evaluating the element select `ResetValues[k]` (import_bit_select).  The
element width is `total_bits / outer_dim_count`, and `total_bits` is the folded
concat's width.

The concat's width is set by the replication `{Width{1'b1}}`.  When `prim_count`
is instantiated **two or more levels deep** through parameter pass-through
(`prim_fifo_sync` → `prim_fifo_sync_cnt` → `prim_count`, where `Width` is bound to
the computed `WrapPtrW`), `import_operation`'s ExprEval fast-path folds
`{Width{1'b1}}` against the wrong UHDM `inst` context and resolves `Width` to
prim_count's DEFAULT (`parameter int Width = 2`) — or an ancestor's same-named
`Width` (the top-level data width 8) — instead of the elaborated `Width=5`.  So
`ResetValues` came out 4 (or 13) bits instead of 10; `total % NumCnt` then made
`elem_w` collapse to 1, and `ResetValues[1]` read a single bit = 0 instead of the
5-bit `31`.  The secure down-counter cleared to 0 → `up+down != 31` → `err_o`.

A **directly-instantiated** (single-level) `prim_fifo_sync_cnt #(.Depth(9))`
already works because there ExprEval could not fold `{Width{1'b1}}` and fell
through to the operand-wise import, which resolves the replication count via
`import_ref_obj` → `module->parameter_default_values` — the ELABORATED `Width=5`.

## Fix (frontend, uhdm2rtlil)

`import_operation` (`expression.cpp`): skip the ExprEval reduce-to-constant
fast-path for any operation that (transitively) contains a `vpiMultiConcatOp`
whose replication COUNT is a `ref_obj` naming a module parameter present in
`module->parameter_default_values`.  Such a replication must be sized from the
parameter's elaborated value, so it now takes the same operand-wise fall-through
the single-level case already used — resolving `Width=5` and producing the
correct 10-bit `ResetValues` → `ResetValues[1]=31`.

This is the same multi-level-instance parameter-resolution class as the WrapPtrW
replication count first suspected here; the actual failing site is the downstream
packed-array element width, not the `{(WrapPtrW-1){1'b0}}` count (whose "Invalid
replication count 0" warning comes from a DEAD base-definition module and is
benign — the live paramod resolves it correctly).
