# Simple Package Test

This test case demonstrates SystemVerilog package features including:
- Package declaration with parameters
- Package struct type definitions  
- Package functions
- Import statements in modules
- Using package types and parameters

## Test Description

The test includes:
1. **Package Definition** (`my_pkg`):
   - Parameters: `DATA_WIDTH`, `ADDR_WIDTH`
   - Struct type: `bus_transaction_t` with packed fields
   - Function: `increment_data`

2. **Main Module** (`simple_package`):
   - Imports the package with `import my_pkg::*`
   - Uses package struct type for ports and signals
   - Uses package function in logic
   - Instantiates sub-module passing struct signals

3. **Sub Module** (`sub_module`):
   - Also imports the package
   - Uses package parameters and types
   - Demonstrates package scope across module hierarchy

## Current Status

**Status: FAILING** - The UHDM frontend lacks support for SystemVerilog packages.

### Missing Features

1. **Package Import Handling**:
   - Need to process `import` statements
   - Resolve package-qualified identifiers
   - Make package items visible in module scope

2. **Package Parameter Support**:
   - Import parameters from packages into modules
   - Handle parameter references with package scope
   - Support `vpiImported` attribute

3. **Struct Type Support**:
   - Parse struct type definitions from packages
   - Calculate correct bit widths for packed structs
   - Handle struct member access
   - Support struct types in port declarations

4. **Package Function Support**:
   - Import package functions
   - Handle function calls from modules

## Implementation Requirements

To support packages, the UHDM frontend needs:

1. **Package Processing**:
   ```cpp
   void import_package(const UHDM::package* pkg);
   void process_package_imports(const UHDM::module_inst* mod);
   ```

2. **Type Resolution**:
   ```cpp
   RTLIL::Wire* resolve_struct_type(const UHDM::struct_typespec* struct_type);
   int calculate_struct_width(const UHDM::struct_typespec* struct_type);
   ```

3. **Scope Management**:
   - Package symbol tables
   - Hierarchical name resolution
   - Import visibility rules

## Test Verification

When implemented correctly:
- Both modules should import package items successfully
- Struct signals should have correct width (50 bits for bus_transaction_t)
- Package parameters should be usable in port declarations
- Sub-module instantiation should work with struct types

## Related UHDM Structures

Key UHDM objects for package support:
- `uhdmpackage` - Package definition
- `uhdmimport_typespec` - Import statements  
- `uhdmstruct_typespec` - Struct type definitions
- `uhdmtypespec_member` - Struct members
- `vpiImported` - Attribute marking imported items