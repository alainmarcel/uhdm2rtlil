# port_chained_type_param

A port whose type is a type parameter **defaulted to another type parameter**
came out ONE BIT wide:

    parameter type noc_req_t = struct packed { ... 49 bits ... },
    parameter type req_t     = noc_req_t     // chained
    ...
    input req_t in_i

    read_uhdm :  wire input 2 \in_i            <- 1 bit   WRONG
    read_slang:  wire width 49 input 2 \in_i   <- correct

A type parameter defaulted DIRECTLY to a struct (or to a package-qualified
struct) always resolved — only the chain failed.

## Root cause — Surelog `CompileHelper::compileParameterDeclaration`

Surelog attached **no typespec at all** to the chained parameter (`vpiTypespec`
absent, where the non-chained one has `ref_typespec → struct_typespec`), so the
port had nothing to size from and fell back to 1 bit.

The `paTYPE` branch compiles the parameter's default with

    compileTypespec(component, fC, Data_type, compileDesign, Reduce::No,
                    p, /*instance=*/nullptr, false)

and `compileTypespec`'s `paExpression` case can only resolve a *named* type via
`bindTypespec(name, instance, s)` — which it skips entirely when `instance` is
null.  So the call returned null and the parameter was left untyped.

The referenced parameter is already in the same `parameters` vector being
built, so the fix resolves the chain directly against that list — no instance
needed.  NOTE the borrowed typespec still belongs to the parameter it was
declared on: it is referenced **without re-parenting**, otherwise the original
loses its owner and the chain breaks in the other direction.

## Why it mattered

CVA6's hpdcache modules chain their types this way — e.g.
`parameter type fifo_data_t = hpdcache_mem_req_t` in `hpdcache_fifo_reg` and
`hpdcache_sync_buffer`, whose data ports were 1 bit instead of 84.  The wrapper
generator used to sidestep this by inlining the referenced definition into
generated code (PR #614); that workaround is no longer load-bearing.

## Still open — chained type parameter WITH a packed dimension

`type X = <type_param> [range]` (e.g. `hpdcache_mem_resp_demux`'s
`localparam type rt_t = resp_id_t [RT_DEPTH-1:0]`) compiles to a bare
`integer_typespec`, so it measures 32 bits regardless of the element type
(32 vs slang's 8).  That is a separate Surelog defect in the same family and is
not fixed here.

## Checking

`read_verilog` cannot parse a type parameter defaulted to another type
parameter, so this is a **slang-miter-only** test (`test_slang_equiv.ys`).
