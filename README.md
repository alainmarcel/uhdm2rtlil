# UHDM to RTLIL Frontend

![CI](https://github.com/username/uhdm2rtlil/workflows/CI/badge.svg)

A Yosys frontend that reads UHDM (Universal Hardware Data Model) files and converts them to RTLIL.

## Quick Start

### Build
```bash
make
```

### Test
```bash
cd test
bash run_all_tests.sh
```

## Project Structure

- `src/frontends/uhdm/` - UHDM frontend implementation
- `test/` - Test cases and test runner
- `third_party/` - External dependencies (Surelog, Yosys)

## Testing

### Running Tests
The project includes automated tests that compare UHDM and Verilog frontend outputs:

```bash
cd test
bash test_uhdm_workflow.sh <test_directory>
```

### Test Management
Known failing tests are listed in `test/failing_tests.txt` and are automatically skipped during CI runs.

### Continuous Integration
GitHub Actions automatically builds the project and runs tests on every push and pull request. See `.github/workflows/ci.yml` for details.

## Development

The UHDM frontend handles SystemVerilog constructs including:
- Module definitions and instantiations
- Always blocks (`always_ff`, `always_comb`, `always`)
- Expressions and operations
- Memory inference
- Signal declarations

## License

See `LICENSE` file for details.