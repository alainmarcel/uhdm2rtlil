# Simple Instance Array Test

This test case validates the UHDM frontend's support for Verilog primitive gate arrays.

## Test Description

The test implements various primitive gate arrays with vector connections:
- AND gate array: `and and_gates[3:0] (and_out, a, b);`
- OR gate array: `or or_gates[3:0] (or_out, a, b);`
- XOR gate array: `xor xor_gates[3:0] (xor_out, a, b);`
- NAND gate array: `nand nand_gates[0:3] (nand_out, a, b);`
- NOT gate array: `not not_gates[3:0] (not_out, a);`

## Key Features Tested

1. **Primitive Gate Arrays**: Arrays of primitive gates with proper bit-slicing
2. **Vector Connections**: Automatic bit-slicing of vector signals to individual gates
3. **Array Range Syntax**: Both ascending [0:3] and descending [3:0] ranges
4. **Gate Mapping**: Correct mapping to Yosys internal gate cells ($_AND_, $_OR_, etc.)

## UHDM Frontend Advantages

The UHDM frontend successfully imports primitive gate arrays that cause the standard Verilog frontend to fail with:
```
ERROR: Assert `new_cell->children.at(0)->type == AST_CELLTYPE' failed in frontends/ast/simplify.cc:2755.
```

This demonstrates that the UHDM frontend provides enhanced SystemVerilog support beyond the capabilities of Yosys's built-in Verilog parser.

## Implementation Details

The UHDM frontend:
1. Parses gate_array objects from UHDM
2. Extracts array bounds from Ranges() 
3. Creates individual gate instances with proper bit-slicing
4. Maps UHDM primitive types (vpiAndPrim, vpiOrPrim, etc.) to Yosys cells
5. Correctly handles both ascending and descending array ranges

## Test Results

- UHDM Path: ✓ Successfully imports all 20 gates (4 of each type)
- Verilog Path: ✗ Fails with assertion error in AST simplification
- Functional verification shows correct gate operations