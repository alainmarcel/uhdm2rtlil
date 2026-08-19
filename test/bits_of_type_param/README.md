# bits_of_type_param

`$bits(T)` where `T` is a **type parameter** folded to 1.

```systemverilog
module dut #(
    parameter  type req_t      = pk::req_t,
    parameter  int  DATA_WIDTH = $bits(req_t),        // -> was 1
    localparam type data_t     = logic [DATA_WIDTH-1:0],
    localparam int  DIRECT     = $bits(pk::req_t)     // direct: always worked
) (...);
```

This is the shape CVA6's hpdcache modules are built on:

```systemverilog
parameter type         hpdcache_req_t = hpdcache_pkg::hpdcache_req_t,
parameter int unsigned DATA_WIDTH     = $bits(hpdcache_req_t),
localparam type        data_t         = logic [DATA_WIDTH-1:0]
```

`hpdcache_mux`'s `data_o` came out **1 bit instead of 147**, and `data_i`
(`data_t [NINPUT-1:0]`) 5 instead of 735 — the miter could not even pair the
ports (`No matching port in gate module was found for \data_o!`).

## Root cause

Surelog **folds** `$bits(pkg::struct_t)` to a constant during elaboration, so
the direct form never reaches the frontend as a call.  The type-parameter form
is left as an unevaluated `sys_func_call` whose argument is a bare `ref_obj`
naming the parameter — usually with no `Actual_group` binding.  Importing that
ref as an ordinary expression yields a 1-bit signal, and `$bits` reported
`args[0].size()` == 1.

The fix (`src/frontends/uhdm/expression.cpp`, the array/range-query handler)
resolves the argument to the type parameter's **bound** typespec — via
`Actual_group()` when present, else by name among the elaborated instance's
type parameters — and measures that with `get_width_from_typespec`.

## Related

`port_chained_type_param` is the same family: a type parameter whose default is
*another type parameter*.  Both are needed for the hpdcache modules.

Still open (documented, not fixed here): `type X = <type_param> [range]` — a
chained type parameter carrying a **packed dimension** — compiles to a bare
`integer_typespec` in Surelog, so it measures 32 bits regardless of the element
type.  Seen on `hpdcache_mem_resp_demux`'s `rt_t = resp_id_t [RT_DEPTH-1:0]`
(32 vs slang's 8).

## Checking

`read_verilog` cannot parse `$bits` of a type parameter in a parameter default,
so this is a **slang-miter-only** test (`test_slang_equiv.ys`).
