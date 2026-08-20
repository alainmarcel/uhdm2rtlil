# type_param_unpacked_port

An **unpacked** array port whose element type is a type parameter:

```systemverilog
parameter type resp_t = base_resp_t,     // chained, as in CVA6
parameter int  N      = 2
...
output resp_t out_o [N-1:0]              // 2 * 36 = 72 bits
```

## The bug

`import_port`'s unpacked-dimension recovery searched only the instance's
`Array_nets()`.  Surelog presents some unpacked-array ports as an **array_var**
instead, and for those the recovery never ran, so the port kept the width of a
**single element**.

In CVA6 `hpdcache_mem_resp_demux` that made
`output resp_t mem_resp_o [N-1:0]` **69 bits instead of 138**, while its
sibling `output logic mem_resp_valid_o [N-1:0]` — an array_net — was recovered
correctly.  Two ports, same declaration shape, only one wrong: that asymmetry
is the fingerprint.

The fix adds the matching `Variables()` / `array_var` search, forcing the
const-fold of the dimension bound (`[N-1:0]` is an operation over a parameter,
which `import_operation` does not fold outside loop/function/generate contexts
— the same guard the `array_typespec`, `packed_array_typespec` and
`import_port` range paths already use).

## ⚠️ What this test does and does NOT cover

**This test does not exercise the array_var branch.**  Tracing it shows both
its unpacked ports resolve through the pre-existing `Array_nets` path:

```
UHDM: Port 'out_o' recovered unpacked dims from Array_nets: 36 * 2 = 72 bits
```

Four variants were tried to force Surelog to emit an `array_var` here — a
direct type parameter, a two-level chain, a pass-through to a child instance
(the CVA6 shape), and an explicit `output var` — and Surelog classified every
one of them as an `array_net`.  The trigger for the array_var form in CVA6 is
not understood.

So the array_var fix itself is verified **only** by the CVA6 module
(`hpdcache_mem_resp_demux`, 69 -> 138 bits, `error` -> measurable `cex`), not
by anything in this repository.  This test is kept as regression coverage for
the sibling `Array_nets` path and for unpacked type-parameter ports generally
— do not read it as proof that the array_var branch works.

If you touch that branch, verify against the CVA6 sweep, not this test.

## Checking

`read_verilog` cannot parse a chained type parameter, so this is a
**slang-miter-only** test (`test_slang_equiv.ys`).

```
wire width 72 input  \in_i
wire width 72 output \out_o
wire width 36 output \single_o     # control: one element
```
