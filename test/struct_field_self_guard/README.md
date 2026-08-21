# struct_field_self_guard

A struct field **read in a guard** and **written inside that guard**, after the
whole field was copied from an input:

```systemverilog
p::areq_t o;                          // a struct declared as a NET
always_comb begin
  o.fexc = areq_i.fexc;               // whole-field copy
  if (areq_i.fvalid) begin
    if (o.fexc.cause != 8'hC) begin   // READ of o.fexc.cause
      o.fexc.cause = 8'h1;            // was lost
      o.fexc.valid = 1'b1;            // fine
      ...
```

`cause` came out driven by the wire itself, while its siblings (`valid`, `tval`,
`gva`) — none of which is read in the guard — were written correctly.

## Cause

Not a dropped write. The RTLIL process was always correct
(`assign $0\o [17:10] 8'00000001` is emitted). The bug was the **guard**, which
read the final wire instead of the in-flight value:

```
cell $ne   connect \A \o [17:10]     # should be \areq_i [17:10]
```

That closes a combinational loop — `\o` ← `$0\o` ← switch on `$ne` ← `\o` —
which yosys breaks by leaving the field driven by itself.

The read is resolved by `import_hier_path`'s member-chain branch, which prefers
the in-flight value precisely to avoid this loop. It bailed out because it could
not get the base's typespec: its cast list covered `logic_net`, `logic_var`,
`struct_var` and `union_var`, but **a struct declared as a net is a
`struct_net`** (UhdmType 2347), which was missing. With no typespec the member
walk gave up and the access fell through to the handlers below, which resolve
against the module wire.

## Fix

Add `struct_net` to that cast list. One line; the branch then resolves the
members and returns the in-flight slice.

## Two prerequisites that also had to be true

Both were already satisfied once traced, and are worth knowing if this area is
touched again:

1. `record_comb_partial_write()` only *splices* into an existing
   `current_comb_values` entry — it deliberately does not create one. A struct
   written solely through its fields never gets a full write, so it would never
   enter the map.
2. The `Process*` (unconditional) assignment path records only **full-wire**
   chunks, so the top-level `o.fexc = ...` was not recorded there either.

Neither needed changing for this DUT — the entry is created via the paths that
already run — but if a future case shows an empty map at the guard
(`ccp=1 keys=[]`), those two are where to look.

## Checking

The miter against `read_slang` PROVES it.

## CVA6

This is `pmp_data_if`'s

```systemverilog
icache_areq_o.fetch_exception = icache_areq_i.fetch_exception;
if (icache_areq_o.fetch_exception.cause != riscv::INSTR_PAGE_FAULT)
    icache_areq_o.fetch_exception.cause = riscv::INSTR_ACCESS_FAULT;
```

Before the fix its netlist wrote only `icache_areq_o[138:75]` (`tval`) and
`[0]` (`valid`); the 64-bit `cause` field `[202:139]` had no write at all. It
now does.

**`pmp_data_if` is still a counterexample.** The write is emitted but its
*value* still differs from slang (Verilator adjudication is unchanged at
377/2000), so that module has a second, independent defect above this one.
This fix stands on its own merits, with its own reproducer.
