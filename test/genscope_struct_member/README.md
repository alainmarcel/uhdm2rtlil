# genscope_struct_member

A struct declared **inside a generate block**, read field-wise in the same
`always_comb`:

```systemverilog
for (genvar op = 0; op < 1; op++) begin : gen_op
  fp_t value;                       // registered as \gen_op[0].value
  always_comb begin
    value    = operand_i;
    exp_o    = value.exponent;      // looked up as bare "value" -> MISS
    exp_nz_o = (value.exponent != '0);
  end
end
```

`exp_o` came out `5'0000x` where slang gives `operand_i[14:10]`. Moving the
same code out of the generate block made it work.

## Cause

`import_hier_path` splits a struct access into a base name and a member path
and looks the base up in `name_map`. A struct declared inside a generate block
is registered under its **gen-scope-qualified** name (`gen_op[0].value`), but
the member path carries only the bare name, so the lookup missed and the whole
access resolved to X:

```
Detected struct member access: base='value', member='exponent'
Warning: UHDM: Could not resolve struct member access 'value.exponent'
    Importing ref_obj: exp_nz_o (current_gen_scope: gen_op[0])
```

Both lookup sites (the single-level member path and the offset/width resolver)
now retry with `<gen_scope>.<name>`. This is the same class as the round-1
`lzc` gen-scope prefix fix, at the struct-member site.

**Implementation note:** the qualified name is used as the *lookup key* only.
`struct_name` doubles as a path prefix — later code slices `path_name` by its
length — so reassigning it threw
`basic_string::substr: __pos > this->size()` on the real design. Key and
prefix are kept separate.

## Why an X here is dangerous

In CVA6 `fpnew_classifier` the X did not surface as an X. Every classification
(`is_normal`, `is_zero`, `is_inf`, `is_nan`) compares `value.exponent` against
`'0`/`'1`, so an X base let the whole expression **constant-fold**: `info_o`
became the literal `8'b00010001` with no logic at all. A silently constant
output is much harder to notice than a propagated X.

## Scope — what this does NOT fix

`fpnew_classifier` remains a counterexample. Re-adjudicating after this fix
gives byte-identical numbers (uhdm_vs_rtl 1497/3000, same first divergence
`info_o` rtl=0x81 uhdm=0x0b), so that module's `value` does not take this path.
This fix is kept on its own merits, with its own repro.

## Checking

`read_verilog` cannot parse this shape, so this is a **slang-miter-only** test.
The miter PROVES it, so the field read selects the same bits slang selects.
