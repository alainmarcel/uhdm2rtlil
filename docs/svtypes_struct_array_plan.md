# svtypes/struct_array.sv — PR breakdown plan

Source: `third_party/yosys/tests/svtypes/struct_array.sv`.

Initial run on `main` shows the full test failing across **all** struct
variants (`s`, `s_s`, `s2`, `s3`, `s3_b`, `s3_lll`, `s3_lbl`, `s3_lbl_s`,
`s3_llb`, `s3_off`, `s4`, `s5`, `s5_b`, `s6`).  Two distinct categories:

| Variant   | gate width | gold width | symptom                                        |
| --------- | ----------:| ----------:| ---------------------------------------------- |
| `s_s`     |         24 |         64 | typedef'd packed-array element width wrong     |
| `s3_lbl_s`|         20 |         80 | same — typedef'd inner-packed-array element    |
| all others| correct    | correct    | struct stays at `'0` — partial writes vanish   |

We attack this as a sequence of small, independent PRs.  Each PR has a
self-contained minimal test that we land before tackling the next sub-
problem.  The umbrella `svtypes_struct_array` test is added in the final
PR after every sub-problem is fixed.

## PR 1 — `struct_init_partial_write`

**Minimal repro**: bulk struct init followed by a single named-field write.

```systemverilog
module top;
    struct packed {
        bit [7:0] a;
        bit [7:0] b;
    } s;
    initial begin
        s = '0;
        s.a = 8'h42;
    end
    always_comb assert(s == 16'h4200);
endmodule
```

**Symptom**: gold drives `s` via `$0\s[15:0]` temp wire and emits the
final value; our `import_initial_sync` path stamps the bulk `s = '0`
as an `\init` attribute and drops the subsequent hier-path field
write.

**Fix area**: route initial blocks with hier_path / bit_select /
part_select LHS through `import_initial_comb` (the temp-wire path)
instead of `import_initial_sync` (the one-driver-per-SigSpec path).
Also size the `$0\s` temp wire to the FULL base wire so multiple
slice writes can coexist (matches `import_always_comb`).

## PR 2 — `struct_part_select_write`

**Minimal repro**: bit-range write into a struct field.

```systemverilog
module top;
    struct packed {
        bit [15:0] b;
    } s;
    initial begin
        s.b = '1;
        s.b[1:0] = '0;
    end
    always_comb assert(s == 16'hFFFC);
endmodule
```

**Symptom**: like PR 1, but exercises `vpiPartSelect` on a struct
field (`s.b[1:0]`) instead of a bare hier_path.  Once PR 1 lands,
verify that the part-select branch in the comb path does the temp-
wire slice remap too.

## PR 3 — `struct_array_indexed_write`

**Minimal repro**: writing a range / single index of a packed-array
struct field.

```systemverilog
module top;
    struct packed {
        bit [3:0][7:0] a;
    } s;
    initial begin
        s = '0;
        s.a[1:0] = 16'h1234;
        s.a[3]   = 8'h42;
    end
    always_comb assert(s == 32'h4200_1234);
endmodule
```

**Fix area**: hier_path with embedded `bit_select` / `part_select` on
the array dimension.  The LHS is `s.a[3]` — a one-element slice of
the multi-dim packed array — which must resolve to bits `[31:24]` of
`s` and route through `$0\s`.

## PR 4 — `struct_negative_index`

**Minimal repro**: out-of-bound / negative array indices.

```systemverilog
module top;
    struct packed {
        bit [3:0][7:0] a;
    } s;
    initial begin
        s = '0;
        s.a[-1] = '0;            // no-op write (out of bounds)
    end
    always_comb assert(s.a[0][3:-4] === 8'h0x);  // partial X read
    always_comb assert(s == 32'h0);
endmodule
```

**Fix area**: bounds-checking on index expressions.  An out-of-bound
write should be a silent no-op (matching gold), and an out-of-bound
read should produce `x` for the missing bits.

## PR 5 — `struct_typedef_packed_array`

**Minimal repro**: typedef-based packed array dimension.

```systemverilog
module top;
    typedef bit [7:0] bit8_t;
    struct packed {
        bit8_t [3:0] a;        // 4 × 8 = 32 bits
        bit [15:0]   b;
    } s;
    initial s = '0;
    always_comb assert($bits(s) == 48);
endmodule
```

**Symptom**: `s` currently gets width 24 instead of 48.  Surelog
represents `bit8_t [3:0]` as a `logic_typespec` with `Elem_typespec()`
pointing to the `bit8_t` (8-bit) typespec plus a redundant outer
range that we're folding into the wrong total.

**Fix area**: `get_width_from_typespec` / struct-field width path.
Already partially handled for the `reg2dim1_t` typedef case (see
CLAUDE.md "Packed Multidimensional Array Typespec Variants"); extend
to cover the `bit8_t [N:0]` shape used here.

## PR 6 — `struct_little_endian_bit_array`

**Minimal repro**: ascending range packed array (`bit [0:7]`).

```systemverilog
module top;
    struct packed {
        bit [0:7][7:0] a;       // ascending outer dim
    } s;
    initial begin
        s = '0;
        s.a[2] = 8'h42;
        s.a[5:6] = 16'h1234;
    end
    always_comb assert(s == 64'h00_42_00_00_00_12_34_00);
endmodule
```

**Fix area**: ascending-range arrays change which element ends up in
which bit position; PR 3 only exercises the descending form.

## PR 7 — `struct_3d_packed_array`

**Minimal repro**: 3D packed array with mixed endianness.

```systemverilog
module top;
    struct packed {
        bit [0:7][1:0][0:3] a;  // lbl
    } s;
    initial begin
        s = '0;
        s.a[0]    = '1;          // 8-bit slice
        s.a[0][1] = '0;          // 4-bit slice
    end
    always_comb assert(s == 64'h0F00_0000_0000_0000);
endmodule
```

**Fix area**: bit-offset arithmetic for nested packed-array indexing
with mixed endianness (`s3_lll`, `s3_lbl`, `s3_llb` in the umbrella
test).

## PR 8 — `struct_unpacked_array_member`

**Minimal repro**: a packed struct containing an unpacked array
(Yosys-specific extension; Surelog parses it).

```systemverilog
module top;
    struct packed {
        bit [7:0] a [4];        // unpacked array inside packed struct
        bit [7:0] b;
    } s;
    initial begin
        s = '0;
        s.a[2] = 8'h42;
        s.b    = 8'hFF;
    end
    always_comb assert(s == 40'h00_42_00_00_FF);
endmodule
```

**Fix area**: covers the `s5`, `s5_b`, `s6` variants in the umbrella
test.

## PR 9 — umbrella `svtypes_struct_array`

After PRs 1–8 land, drop the full Yosys test in and confirm 100%
equivalence.

---

## Order of attack

1. **PR 1** (struct field write) is foundational — fixes the most
   common symptom (everything stuck at `'0`).
2. **PR 5** (typedef'd packed array width) is independent and unlocks
   `s_s` / `s3_lbl_s`.
3. Remaining PRs build on the temp-wire pattern PR 1 establishes.

## Tracking

- [ ] PR 1 — struct_init_partial_write
- [ ] PR 2 — struct_part_select_write
- [ ] PR 3 — struct_array_indexed_write
- [ ] PR 4 — struct_negative_index
- [ ] PR 5 — struct_typedef_packed_array
- [ ] PR 6 — struct_little_endian_bit_array
- [ ] PR 7 — struct_3d_packed_array
- [ ] PR 8 — struct_unpacked_array_member
- [ ] PR 9 — svtypes_struct_array (umbrella)
