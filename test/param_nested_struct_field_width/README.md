# param_nested_struct_field_width

The module-parameter variant of [`pkg_nested_struct_param_width`](../pkg_nested_struct_param_width):
a width expression that reads a **nested** field of a struct **module
parameter** whose default comes from a package localparam built by a function.
This is the shape CVA6's hpdcache modules use — `parameter hpdcache_cfg_t
HPDcacheCfg = hpdcache_equiv_pkg::HPDcacheCfg` indexed as
`HPDcacheCfg.u.accessWords`.

```systemverilog
module dut #(
    parameter  pk::cfg_t CFG    = pk::CFG,
    localparam int       SID_W  = CFG.u.sidWidth,       // NESTED    -> was 0
    localparam int       DATA_W = CFG.derived,          // one level -> ok
    localparam int       NOUT   = CFG.u.dataWidth /
                                  CFG.u.sidWidth,       // nested / nested
    localparam int       NLOG   = $clog2(NOUT),
    ...
```

Covers three things the package-level test does not: the base is a *parameter*
rather than a package localparam, two nested reads feed a **division**, and the
result flows through `$clog2` into a further width.  Before the fix `NOUT`
divided by zero and the whole chain collapsed; `sel_i` and `sid_i` came out
zero-width while `data_i` (single-level) was correct.

## Root cause

UHDM `ExprEval::hierarchicalSelector` returned a matched struct member's value
without checking `lastElem` or recursing, so a two-level path stopped at the
first member.  See `pkg_nested_struct_param_width/README.md` for the full
analysis — fixed in
`third_party/Surelog/third_party/UHDM/templates/ExprEval.cpp`
(chipsalliance/UHDM#1140).

Because the bad range is stored *in* the elaborated `.uhdm`, Surelog must be
re-run to observe the fix; a cached `slpp_all/surelog.uhdm` keeps reproducing
the old width.

## Checking

`read_verilog` cannot parse a function-built struct localparam, so this is a
**slang-miter-only** test (`test_slang_equiv.ys`).

```
wire width 3  input \sid_i     # was width 0
wire width 64 input \data_i
wire width 4  input \sel_i     # was width 0
```
