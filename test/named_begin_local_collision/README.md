# named_begin_local_collision

The **same named begin block** appearing in several always blocks of one
module, each declaring its own block-local:

```systemverilog
always_comb begin : blk_x
  begin : special_results
    logic [3:0] special_res;   // -> \special_results.special_res
    ...
always_comb begin : blk_y
  begin : special_results
    logic [3:0] special_res;   // -> the SAME name: collision
```

CVA6's `fpnew_cast_multi` has three `begin : special_results`, each with a
`special_res`. All three block-locals were named
`\special_results.special_res`, so the second `addWire` **aborted yosys**:

```
ERROR: Assert `count_id(wire->name) == 0' failed in kernel/rtlil.cc:2...
```

## Fix

`import_begin_block_comb` uniquifies the hierarchical name when it is already
taken (`\special_results.special_res$2`, `$3`, …), keeping the `$0\<hier>`
temp in step with its target wire.

**Uniquify, not reuse.** Reusing the existing wire would be *worse than the
crash*: two unrelated block-locals in different always blocks would merge into
one net, silently tying the blocks together — a wrong answer instead of a loud
failure. Reuse is correct only in the `block_local_promoted` case handled
above it, where the enclosing always-block's `$0`-temp machinery already owns
that wire.

An **unnamed** begin never hit this: it already gets a per-block counter
(`$unnamed_block$N`). Only the named case used `VpiName()` verbatim.

## Checking

Slang-miter only. The three blocks compute different functions (`&`, `|`, a
mux), so a merge of any two shows up as a counterexample rather than silently
passing — the test would fail if the collision were ever "fixed" by reuse.

## CVA6

`fpnew_cast_multi`: error (abort) → **proven**.

`fpnew_fma_multi` clears this assert too, but still errors for an unrelated
reason: the module `fmalza` it instantiates is **not vendored** in
`test/cva6_equiv/rtl` and appears nowhere in the flist. That is a
harness/vendoring gap, the same class as `amo_alu` and `acc_dispatcher`, not a
frontend defect.
