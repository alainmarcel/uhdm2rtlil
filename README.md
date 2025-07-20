# UHDM to RTLIL Frontend

![CI](https://github.com/username/uhdm2rtlil/workflows/CI/badge.svg)

A Yosys frontend that enables SystemVerilog synthesis through UHDM (Universal Hardware Data Model) by converting UHDM representations to Yosys RTLIL (Register Transfer Level Intermediate Language).

## Overview

This project bridges the gap between SystemVerilog source code and Yosys synthesis by leveraging two key components:

1. **Surelog** - Parses SystemVerilog and generates UHDM
2. **UHDM Frontend** - Converts UHDM to Yosys RTLIL

This enables full SystemVerilog synthesis capability in Yosys, including advanced features not available in Yosys's built-in Verilog frontend.

## Architecture & Workflow

```
SystemVerilog (.sv) → [Surelog] → UHDM (.uhdm) → [UHDM Frontend] → RTLIL → [Yosys] → Netlist
```

### Components

#### 1. **Surelog** (`third_party/Surelog/`)
- Industry-grade SystemVerilog parser and elaborator
- Handles full IEEE 1800-2017 SystemVerilog standard
- Outputs Universal Hardware Data Model (UHDM)
- Provides semantic analysis and type checking

#### 2. **UHDM Frontend** (`src/frontends/uhdm/`)
- **Core Module** (`uhdm2rtlil.cpp`) - Main frontend entry point and design import
- **Module Handler** (`module.cpp`) - Module definitions, ports, instances, and wire declarations
- **Process Handler** (`process.cpp`) - Always blocks, procedural statements, and control flow
- **Expression Handler** (`expression.cpp`) - Operations, constants, references, and complex expressions
- **Memory Handler** (`memory.cpp`) - Memory inference and array handling
- **Clocking Handler** (`clocking.cpp`) - Clock domain analysis and flip-flop generation

#### 3. **Yosys** (`third_party/yosys/`)
- Open-source synthesis framework
- Processes RTLIL for optimization and technology mapping
- Provides extensive backend support for various FPGA and ASIC flows

### Supported SystemVerilog Features

- **Module System**: Module definitions, hierarchical instantiation, parameter passing
- **Data Types**: Logic, bit vectors, arrays, packed/unpacked structures
- **Procedural Blocks**: 
  - `always_ff` - Sequential logic with proper clock/reset inference
  - `always_comb` - Combinational logic
  - `always` - Mixed sequential/combinational logic
- **Expressions**: Arithmetic, logical, bitwise, comparison, ternary operators
- **Control Flow**: If-else statements, case statements, loops
- **Memory**: Array inference, memory initialization
- **Advanced Features**: Generate blocks, interfaces, assertions

## Quick Start

### Prerequisites
- GCC/Clang compiler with C++17 support
- CMake 3.16+
- Python 3.6+
- Standard development tools (make, bison, flex)

### Build
```bash
# Clone with submodules
git clone --recursive https://github.com/username/uhdm2rtlil.git
cd uhdm2rtlil

# Build everything (Surelog, Yosys, UHDM Frontend)
make
```

### Basic Usage
```bash
# Method 1: Using the test workflow
cd test
bash test_uhdm_workflow.sh simple_counter

# Method 2: Manual workflow
# Step 1: Generate UHDM from SystemVerilog
./build/third_party/Surelog/bin/surelog -parse design.sv

# Step 2: Use Yosys with UHDM frontend
./out/current/bin/yosys -p "read_uhdm slpp_all/surelog.uhdm; synth -top top_module"
```

## Testing Framework

### Test Structure
Each test case is a directory containing:
- `dut.sv` - SystemVerilog design under test
- Automatically generated comparison files:
  - `*_from_uhdm.il` - RTLIL generated via UHDM path
  - `*_from_verilog.il` - RTLIL generated via Verilog path
  - `rtlil_diff.txt` - Detailed comparison results

### Running Tests
```bash
# Run all tests
cd test
bash run_all_tests.sh

# Run specific test
bash test_uhdm_workflow.sh simple_counter

# Test output explanation:
# ✓ PASSED - UHDM and Verilog frontends produce functionally equivalent RTLIL
# ⚠ DIFFERENT - Minor differences (usually acceptable, like source locations)
# ✗ FAILED - Significant functional differences requiring investigation
```

### Current Test Cases
- **simple_counter** - 8-bit counter with async reset (tests increment logic, reset handling)
- **flipflop** - D flip-flop (tests basic sequential logic)
- **counter** - More complex counter design

### Test Management
```bash
# View known failing tests
cat test/failing_tests.txt

# Tests in this file are automatically skipped in CI
# Format: one test name per line, # for comments
```

## Project Structure

```
uhdm2rtlil/
├── src/frontends/uhdm/          # UHDM Frontend implementation
│   ├── uhdm2rtlil.cpp          # Main frontend and design import
│   ├── module.cpp              # Module/port/instance handling  
│   ├── process.cpp             # Always blocks and statements
│   ├── expression.cpp          # Expression evaluation
│   ├── memory.cpp              # Memory and array support
│   ├── clocking.cpp            # Clock domain analysis
│   └── uhdm2rtlil.h           # Header with class definitions
├── test/                        # Test framework
│   ├── run_all_tests.sh        # Test runner script
│   ├── test_uhdm_workflow.sh   # Individual test workflow
│   ├── failing_tests.txt       # Known failing tests list
│   └── */                      # Individual test cases
├── third_party/                # External dependencies
│   ├── Surelog/               # SystemVerilog parser
│   └── yosys/                 # Synthesis framework
├── .github/workflows/         # CI/CD configuration
└── build/                     # Build artifacts
```

## Development Workflow

### Adding SystemVerilog Support
1. **Identify UHDM Objects**: Determine which UHDM object types represent the feature
2. **Implement Import**: Add handling in appropriate `src/frontends/uhdm/*.cpp` file
3. **Map to RTLIL**: Convert UHDM objects to equivalent RTLIL constructs
4. **Add Tests**: Create test cases comparing UHDM vs Verilog frontend outputs
5. **Validate**: Ensure generated RTLIL produces correct synthesis results

### Debugging
```bash
# Enable debug output
export YOSYS_ENABLE_UHDM_DEBUG=1

# Run with verbose logging
./out/current/bin/yosys -p "read_uhdm -debug design.uhdm; write_rtlil output.il"
```

### Key Design Principles
- **Correctness**: Generated RTLIL must be functionally equivalent to Verilog frontend
- **Completeness**: Support full SystemVerilog feature set over time
- **Performance**: Efficient UHDM traversal and RTLIL generation
- **Maintainability**: Clear separation of concerns between different handlers

## Continuous Integration

GitHub Actions automatically:
- Builds all components (Surelog, Yosys, UHDM Frontend)
- Runs comprehensive test suite
- Uploads test results and build artifacts
- Provides clear pass/fail status

See `.github/workflows/ci.yml` for configuration details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add appropriate test cases
4. Ensure all tests pass (or update `failing_tests.txt` if needed)
5. Submit a pull request

## License

See `LICENSE` file for details.

## Related Projects

- [Yosys](https://github.com/YosysHQ/yosys) - Open source synthesis suite
- [Surelog](https://github.com/chipsalliance/Surelog) - SystemVerilog parser
- [UHDM](https://github.com/chipsalliance/UHDM) - Universal Hardware Data Model