# mem_packed_2d_byte_write

A memory whose element is a **packed 2-D array**, written **per byte** under two
nested loop variables — CVA6's behavioural byte-enable SRAM
(`hpdcache_sram_wbyteenable`):

```systemverilog
typedef logic [NDATA-1:0][DATA_SIZE-1:0] mem_t [DEPTH];
mem_t mem;
...
for (int j = 0; j < NDATA; j++)
  for (int i = 0; i < DATA_SIZE/8; i++)
    if (wbyteenable[j][i]) mem[addr][j][i*8 +: 8] <= wdata[j][i*8 +: 8];
```

This **aborted yosys outright**:

```
ERROR: Assert `offset + length <= size()' failed in kernel/rtlil.cc:5285
```

## Three bugs, and the order matters

**1. The memory word width collapsed** (`memory_analysis.cpp`).
For `typedef logic [NDATA-1:0][DATA_SIZE-1:0] mem_t [DEPTH]` only
`Ranges()[0]` was consulted, so the word took the **outer dimension alone** —
the memory came out **1 bit** wide instead of `NDATA*DATA_SIZE`. Any per-byte
write then indexed past the word and hit the assert. Two separate causes:
all packed dimensions are now multiplied, *and* the typedef path passes
`current_instance`, without which parameter-based bounds
(`[NDATA-1:0]`) do not resolve and the width silently falls back to 1.
Both `create_memory_from_array` overloads (`array_net` and `array_var`) had
the identical defect.

**2. The middle index was parsed and then dropped**
(`process_helper.cpp`). `parse_mem_partial_select` assumed `mem[addr][sel]`.
Given `mem[addr][j][i*8 +: 8]` it bound `j` to its `second` local and never
used it, so **every element wrote at element 0's byte offset**. It now folds
`j` in as `j * (word_width / NDATA)`, using the outer dimension recorded on
the memory at creation, and returns false rather than guessing when that
geometry is unknown or the index is dynamic.

**3. `import_bit_select` had no `vpiIndexedPartSelect` case**
(`expression.cpp`). In the var_select dispatch, `wdata[j][i*8 +: 8]` fell
through to the generic branch, which re-imports the selector against the
**full base** wire instead of the element.

## Why fixing only the crash would have been worse

After bug 1 alone the design read cleanly — no assert, no warning — but the
slang miter still reported **FAIL**: a hard error had become a *silent wrong
answer*, every word's bytes landing in word 0. Bug 2 is what makes it correct.
Do not treat "it no longer crashes" as done here.

## Checking

`read_verilog` cannot parse this shape, so this is a **slang-miter-only** test.
Note it needs a **sequential** miter, unlike the other type-parameter tests:
the design is clocked and contains a memory, so `test_slang_equiv.ys` runs
`memory` (satgen has no `$memwr_v2`/`$memrd` model) and `async2sync` before
`sat -prove-asserts -seq 4 -set-init-zero`.

## CVA6 effect

| module | before | after |
|---|---|---|
| `hpdcache_sram` | cex | **proven** |
| `hpdcache_sram_1rw` | cex | **proven** |
| `hpdcache_sram_wbyteenable` | error (abort) | elaborates + miters; SAT budget |
| `hpdcache_sram_wbyteenable_1rw` | error (abort) | elaborates + miters; SAT budget |

The two `wbyteenable` modules remain `timeout` at 1800 s — a SAT capacity
limit, not a frontend defect.
