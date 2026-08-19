# port_chained_type_param — KNOWN FAILING frontend limitation

A port whose type is a type parameter **defaulted to another type parameter**
comes out ONE BIT wide:

    parameter type noc_req_t = struct packed { ... 49 bits ... },
    parameter type req_t     = noc_req_t     // chained
    ...
    input req_t in_i

    read_uhdm :  wire input 2 \in_i            <- 1 bit   WRONG
    read_slang:  wire width 49 input 2 \in_i   <- correct

A type parameter defaulted DIRECTLY to a struct (or to a package-qualified
struct) resolves correctly — only the chain fails.

Cause: Surelog attaches no typespec to such a port (`vpiTypedef` is absent
where a normal port has one), and the port's LowConn resolves to a bare
`logic_var`, so there is nothing for the importer to size from.  Fixing it
properly means resolving the type-parameter chain during elaboration, which is
Surelog-side work.

## Why it mattered

This is why 29 CVA6 modules reported

    ERROR: No matching port in gate module was found for \<port>!

which reads like a wrapper bug but is really a width mismatch: gold had the
port at 1 bit, gate at its true width (`axi_shim`: 32 vs 470).  The per-module
wrapper generator now inlines the referenced parameter's definition instead of
naming it, which sidesteps the chain — see `inlined chained type param` in
scripts/gen_wrapper.py.  That is a workaround in generated code, NOT a fix for
this limitation, which still affects hand-written RTL.
