# Architecture and supported SystemVerilog

Back to the [README](../README.md).

## Workflow

```
SystemVerilog (.sv) → [Surelog] → UHDM (.uhdm) → [UHDM Frontend] → RTLIL → [Yosys] → Netlist
```

## Components

#### 1. **Surelog** (`third_party/Surelog/`)
- Industry-grade SystemVerilog parser and elaborator
- Handles full IEEE 1800-2017 SystemVerilog standard
- Outputs Universal Hardware Data Model (UHDM)
- Provides semantic analysis and type checking

#### 2. **UHDM Frontend** (`src/frontends/uhdm/`)
- **Core Module** (`uhdm2rtlil.cpp`) - Main frontend entry point, design import, and UHDM elaboration
- **Module Handler** (`module.cpp`) - Module definitions, ports, instances, and wire declarations
- **Process Handler** (`process.cpp`) - Always blocks, procedural statements, and control flow
- **Expression Handler** (`expression.cpp`) - Operations, constants, references, and complex expressions
- **Functions Handler** (`functions.cpp`) - Compile-time constant function evaluation
- **Interpreter** (`interpreter.cpp`) - Statement interpreter for initial block execution
- **Memory Handler** (`memory.cpp`) - Memory inference and array handling
- **Memory Analysis** (`memory_analysis.cpp`) - Advanced memory pattern detection and optimization
- **Clocking Handler** (`clocking.cpp`) - Clock domain analysis and flip-flop generation
- **Package Support** (`package.cpp`) - SystemVerilog package imports, parameters, and type definitions
- **Primitives Support** (`primitives.cpp`) - Verilog primitive gates and gate arrays
- **Reference Module** (`ref_module.cpp`) - Module instance reference resolution and parameter passing
- **Interface Support** (`interface.cpp`) - SystemVerilog interface handling with automatic expansion

#### 3. **Yosys** (`third_party/yosys/`)
- Open-source synthesis framework
- Processes RTLIL for optimization and technology mapping
- Provides extensive backend support for various FPGA and ASIC flows

## Supported SystemVerilog features

- **Module System**: Module definitions, hierarchical instantiation, parameter passing
- **Data Types**:
  - Logic, bit vectors, arrays
  - Packed multidimensional arrays with dynamic element access (e.g., `logic [0:3][7:0]`, typedef variants)
  - Packed structures with member access via bit slicing
  - Packed unions with member access (all members overlay at bit offset 0, width = widest member)
  - Structs containing unions and unions containing structs (nested access)
  - Struct arrays with complex indexing
  - Package types and imports
- **Procedural Blocks**: 
  - `always_ff` - Sequential logic with proper clock/reset inference
  - `always_comb` - Combinational logic
  - `always` - Mixed sequential/combinational logic
- **Expressions**:
  - Arithmetic, logical, bitwise, comparison, ternary operators
  - Compound assignment operators (`+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`, `<<<=`, `>>>=`)
  - Increment/decrement operators (`x++`, `--x`) as statements and in expressions
  - Assignment expressions (`x = (y = expr) + 1`) with proper side-effect ordering
  - System function calls ($signed, $unsigned, $floor, $ceil)
  - User-defined function calls with good support (simple functions, arithmetic, boolean logic, case statements, nested if-else)
  - Struct member access (e.g., `bus.field`)
  - Hierarchical signal references
  - Parameter references with HEX/BIN/DEC formats
  - Loop variable substitution in generate blocks
- **Control Flow**: If-else statements, case statements (including constant evaluation in initial blocks), for loops with compile-time unrolling and variable substitution, repeat loops with compile-time unrolling, while loops in compile-time function evaluation, named and unnamed begin blocks with local variable scoping
- **Memory**: Array inference, memory initialization, for-loop memory initialization patterns, asymmetric port RAM with different read/write widths
- **Shift Registers**: Automatic detection and optimization of shift register patterns (e.g., `M[i+1] <= M[i]`)
- **Generate Blocks**: 
  - For loops with proper scope handling
  - If-else generate conditions
  - Hierarchical naming (e.g., `gen_loop[0].signal`)
  - Net and variable imports from generate scopes
- **Packages**: Import statements, package parameters (including localparam/parameter from enum constants), package-scoped typedefs and enum types, struct types, functions
- **Net Types**: `wand` and `wor` (wire-AND and wire-OR) with proper multi-driver resolution
- **Primitives**: Gate arrays (and, or, xor, nand, nor, xnor, not, buf)
- **Types & Casts**: enums (incl. ranged members and enum arrays), typedef chains, unpacked
  arrays and unpacked-array ports, unions, type parameters, size / type casts, `$bits`,
  `$clog2`, assignment patterns (`'{a: .., default: ..}`) on structs and packed arrays
- **Statements**: `unique` / `priority` case, `case inside`, tasks and void functions,
  `break` / `return` in unrolled loops, cross-module (XMR) reads and writes
- **Advanced Features**: 
  - Interfaces with modports, interface arrays and interface-typed ports
    (flattened to individual signals)
  - Interface port connections and signal mapping
  - Assertions (`assert property` lowered to `$check` cells)
