# struct_array_member_partsel

A trailing bit range applied to an **array element of a struct member**:

```systemverilog
assign hi_o = rsp_i.rdata[0][32 +: 32];   // rdata is logic [1:0][63:0]
```

This is CVA6 `cva6_hpdcache_if_adapter`'s AMO response forwarding
(`hpdcache_rsp_i.rdata[0][32 +: 32]`), and it **aborted yosys**:

```
ERROR: Assert `chunk_.offset + chunk_.width <= chunk_.wire->width' failed
```

## Cause

`import_hier_path` splits a struct access into a base and a member path, then
asks `calculate_struct_member_offset` for the member's bit offset and width.
The trailing range was left inside the member NAME:

```
Detected struct member access: base='hpdcache_rsp_i', member='rdata[0][32+:32]'
Calculated struct member '…rdata[0][32+:32]' offset=2054, width=64
```

The resolver matched `rdata[0]` and returned that element's **full 64-bit**
width — the `[32 +: 32]` was silently dropped. The resulting 64-bit chunk at
that offset ran past the end of the struct wire, and yosys aborted.

## Fix

Split the trailing range off the member path, resolve the member without it,
then apply the range to the member's slice (`offset += lsb; width = w`).
Handles `[a +: w]`, `[a -: w]` and `[hi:lo]`.

A bounds guard was added alongside: a slice that still exceeds the wire now
**warns and leaves the path unresolved** instead of aborting the whole run. An
abort gives no diagnosis and takes the rest of the design with it.

## Checking

`read_verilog` cannot parse this package/struct shape, so this is a
**slang-miter-only** test. The miter PROVES it, so the slice lands on the same
bits slang selects — not merely "no longer crashes". Coverage:

| expression | checks |
|---|---|
| `rdata[0][32 +: 32]` | the failing case — upper half of element 0 |
| `rdata[0][0 +: 32]`  | lower half, same element |
| `rdata[1][32 +: 32]` | a non-zero element index |
| `rdata[0]`           | whole element, control (no trailing range) |

## CVA6

`cva6_hpdcache_wrapper` and `cva6_hpdcache_subsystem` get past this abort and
now stop at the **async-reset** error instead — a separate, documented issue
(`evalFunc` returns a value-less `struct_var` for a function that builds its
result by assigning members). This fix removed a blocker in front of that one;
it does not resolve it, and both modules remain `error`.
