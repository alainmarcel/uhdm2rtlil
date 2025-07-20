# CI/CD Setup Documentation

This directory contains GitHub Actions workflows for continuous integration.

## Workflows

### CI Workflow (`.github/workflows/ci.yml`)

Runs on Ubuntu 24.04 with latest development environment for every push and pull request to `main` and `develop` branches.

**Steps:**
1. **Checkout**: Fetches code with submodules
2. **Install Dependencies**: Installs required system packages including ccache
3. **Setup ccache**: Configures compiler caching for faster rebuilds
4. **Cache Build Dependencies**: Caches build artifacts and dependencies between runs
5. **Install Python Dependencies**: Installs required Python packages
6. **Setup ccache Environment**: Configures ccache compiler wrappers
7. **Build**: Compiles the entire project using `make -j4` with ccache acceleration
8. **Print ccache Statistics**: Shows cache hit/miss statistics
9. **Test**: Runs all tests using `test/run_all_tests.sh`
10. **Upload Artifacts**: Saves test results and build artifacts

**Dependencies installed:**
- Build tools: `build-essential`, `cmake`, `git`, `ccache` (latest versions from Ubuntu 24.04)
- Languages: `python3`, `python3-pip`
- Libraries: `libssl-dev`, `zlib1g-dev`, `libtcmalloc-minimal4`, `uuid-dev`
- Tools: `tcl-dev`, `libffi-dev`, `libreadline-dev`, `bison`, `flex`
- Performance: `libunwind-dev`, `libgoogle-perftools-dev`
- Python packages: `orderedmultidict`

## Test Management

### Failing Tests

Tests that are known to fail can be marked in `test/failing_tests.txt`. These tests will be:
- Skipped during CI runs
- Listed in the test summary
- Not cause CI failure

**Format of `failing_tests.txt`:**
```
# Comments start with #
test_directory_name
another_failing_test
```

### Test Results

After each CI run, the following artifacts are uploaded:
- **test-results**: Contains `rtlil_diff.txt` and generated `.il` files
- **build-artifacts**: Contains compiled binaries

**Retention:** 7 days

## Local Testing

To run the same tests locally:
```bash
cd test
bash run_all_tests.sh
```

To see which tests are marked as failing:
```bash
cat test/failing_tests.txt
```

## Build Optimization

### Caching Strategy

The CI uses multiple caching layers to speed up builds:

1. **ccache**: Compiler cache that reuses previously compiled object files
   - 2GB cache size with compression enabled
   - Automatic cache management across CI runs
   - Statistics printed after each build

2. **GitHub Actions Cache**: Caches build artifacts and dependencies
   - Build directories: `build/`, `third_party/Surelog/build/`, `third_party/yosys/`
   - Python packages: `~/.cache/pip`
   - Cache key based on CMakeLists.txt, Makefile, and requirements.txt changes

### Performance Improvements

- **First run**: ~45-60 minutes (full compilation)
- **Subsequent runs**: ~5-15 minutes (with cache hits)
- **Parallel jobs**: Limited to 4 to prevent resource exhaustion

## Troubleshooting

### Common Issues

1. **Missing libunwind-dev**: The `libgoogle-perftools-dev` package requires `libunwind-dev`
2. **Submodule issues**: Make sure to clone with `--recursive` flag
3. **Build failures**: Check that all dependencies are installed
4. **Cache corruption**: Clear GitHub Actions cache if builds fail unexpectedly

### Debug CI Locally

You can run the same commands locally:
```bash
# Install dependencies (Ubuntu 24.04 or similar)
sudo apt-get update && sudo apt-get install -y \
  build-essential cmake git python3 python3-pip pkg-config \
  libssl-dev zlib1g-dev libtcmalloc-minimal4 uuid-dev \
  tcl-dev libffi-dev libreadline-dev bison flex \
  libunwind-dev libgoogle-perftools-dev ccache

# Install Python dependencies
pip3 install orderedmultidict

# Setup ccache (optional, for faster rebuilds)
export CC="ccache gcc"
export CXX="ccache g++"
ccache --set-config=max_size=2G
ccache --set-config=compression=true

# Build
make -j4

# Show ccache stats (optional)
ccache --show-stats

# Test
cd test && bash run_all_tests.sh
```