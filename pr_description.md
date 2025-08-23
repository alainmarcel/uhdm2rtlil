# Fix asym_ram_sdp_write_wider test by restructuring memory write generation

## Summary
This PR fixes the failing `asym_ram_sdp_write_wider` test by implementing proper for-loop unrolling with variable substitution for complex memory write patterns. The test now passes and all 52 tests in the suite are working correctly.

## Problem
The `asym_ram_sdp_write_wider` test was failing because it contains a for-loop that writes to memory with dynamically computed addresses and data slices:

```systemverilog
for (i=0; i< RATIO; i= i+ 1) begin : write1
    lsbaddr = i;
    if (enaA) begin
        if (weA)
            RAM[{addrA, lsbaddr}] <= diA[(i+1)*minWIDTH-1 -: minWIDTH];
    end
end
```

The UHDM frontend was not correctly handling:
1. Loop variable substitution in concatenated addresses `{addrA, lsbaddr}`
2. Indexed part select with loop variable expressions `diA[(i+1)*minWIDTH-1 -: minWIDTH]`
3. Generation of proper RTLIL structure matching what the Verilog frontend produces

## Solution
### 1. Added Loop Variable Substitution Support
- Implemented `import_indexed_part_select_with_substitution()` function to handle indexed part selects with loop variable substitution
- Added `ProcessMemoryWrite` structure to collect memory writes during loop unrolling
- Properly substitute loop variables in both addresses and data expressions

### 2. Restructured Memory Write Generation
- Changed from generating external combinational cells to keeping everything in the process body
- Generate `$memwr$` temporary wires matching the Verilog frontend pattern
- Added priority values to memwr statements for correct write ordering
- The proc_memwr pass now correctly processes these patterns

### 3. Correct Unrolling
The loop now correctly unrolls to 4 memory writes:
```
Memory write 0: addr={ \addrA 2'00 }, data=\diA [3:0]
Memory write 1: addr={ \addrA 2'01 }, data=\diA [7:4]
Memory write 2: addr={ \addrA 2'10 }, data=\diA [11:8]
Memory write 3: addr={ \addrA 2'11 }, data=\diA [15:12]
```

## Testing
- The `asym_ram_sdp_write_wider` test now passes
- All 52 tests in the test suite pass (100% success rate)
- Removed `asym_ram_sdp_write_wider` from `failing_tests.txt`
- Updated README to reflect the fix and current test status

## Files Changed
- `src/frontends/uhdm/process.cpp`: Core implementation of loop unrolling and memory write restructuring
- `src/frontends/uhdm/uhdm2rtlil.h`: Added ProcessMemoryWrite structure and helper declarations
- `test/failing_tests.txt`: Removed asym_ram_sdp_write_wider (no tests failing now)
- `README.md`: Updated test count and added description of the fix

## Impact
This fix enables proper handling of complex SystemVerilog memory write patterns commonly used in:
- Asymmetric RAM implementations
- FIFO buffers with different read/write widths
- Memory controllers with burst operations
- Any design using loop-based memory initialization or updates