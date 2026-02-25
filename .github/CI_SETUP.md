# CI/CD Setup Documentation

This directory contains GitHub Actions workflows for continuous integration.

## Workflows

### CI Workflow (`.github/workflows/ci.yml`)

Runs on Ubuntu 24.04 for every push and pull request to `main` and `develop` branches. The workflow has three jobs: a shared **build** job followed by two parallel **test** jobs.

#### Job: `build`

Compiles the entire project and uploads build artifacts for the test jobs.

**Steps:**
1. **Checkout**: Fetches code with submodules
2. **Install Dependencies**: Installs required system packages including ccache
3. **Setup GCC-9**: Installs and configures gcc-9
4. **Setup ccache**: Configures compiler caching for faster rebuilds
5. **Install Python Dependencies**: Installs required Python packages
6. **Setup ccache Environment**: Configures ccache compiler wrappers
7. **Build**: Compiles the entire project using `make -j4` with ccache acceleration
8. **Print ccache Statistics**: Shows cache hit/miss statistics
9. **Package Build Artifacts**: Creates a tarball of binaries needed for testing (yosys, uhdm2rtlil.so, surelog, uhdm-dump)
10. **Upload Build Output**: Uploads the tarball as an artifact for downstream jobs

#### Job: `test` (runs in parallel with `test-all`)

Runs internal tests only (`run_all_tests.sh`). Depends on the `build` job.

**Steps:**
1. **Checkout**: Fetches code with submodules (for test scripts and test cases)
2. **Install Runtime Dependencies**: Installs only the runtime libraries needed to execute binaries
3. **Download/Extract Build Output**: Retrieves and unpacks build artifacts from the `build` job
4. **Run Internal Tests**: Executes `test/run_all_tests.sh`
5. **Upload Test Results**: Saves test output files

#### Job: `test-all` (runs in parallel with `test`)

Runs all tests including Yosys test suite (`run_all_tests.sh --all`). Depends on the `build` job.

**Steps:**
1. **Checkout**: Fetches code with submodules (for test scripts, test cases, and Yosys tests)
2. **Install Runtime Dependencies**: Installs only the runtime libraries needed to execute binaries
3. **Download/Extract Build Output**: Retrieves and unpacks build artifacts from the `build` job
4. **Run All Tests**: Executes `test/run_all_tests.sh --all` (internal + Yosys tests)
5. **Upload Test Results**: Saves test output files including `test/run/` directory

**Dependencies installed (build job):**
- Build tools: `build-essential`, `cmake`, `git`, `ccache` (latest versions from Ubuntu 24.04)
- Languages: `python3`, `python3-pip`
- Libraries: `libssl-dev`, `zlib1g-dev`, `libtcmalloc-minimal4`, `uuid-dev`
- Tools: `tcl-dev`, `libffi-dev`, `libreadline-dev`, `bison`, `flex`
- Performance: `libunwind-dev`, `libgoogle-perftools-dev`
- Python packages: `orderedmultidict`

**Dependencies installed (test jobs):**
- Runtime only: `libtcmalloc-minimal4`, `tcl`, `libffi8`, `libreadline8`, `python3`

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
- **test-results**: Contains `rtlil_diff.txt` and generated `.il` files from internal tests
- **test-all-results**: Contains test output from all tests (internal + Yosys), including `test/run/` directory
- **build-output**: Contains compiled binaries (retained 1 day, used internally between jobs)

**Retention:** 7 days (test results), 1 day (build output)

## Local Testing

To run the same tests locally:
```bash
cd test
bash run_all_tests.sh

# Run all tests (internal + Yosys)
bash run_all_tests.sh --all
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

### Performance Improvements

- **First run**: ~45-60 minutes (full compilation)
- **Subsequent runs**: ~5-15 minutes (with cache hits)
- **Parallel jobs**: Build limited to 4 cores; test and test-all run in parallel after build completes

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

# Run internal tests
cd test && bash run_all_tests.sh

# Run all tests (internal + Yosys)
cd test && bash run_all_tests.sh --all
```
