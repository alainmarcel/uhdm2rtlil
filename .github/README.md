# CI/CD Setup

This directory contains GitHub Actions workflows for continuous integration.

## Workflows

### CI Workflow (`.github/workflows/ci.yml`)

Runs on every push and pull request to `main` and `develop` branches.

**Steps:**
1. **Checkout**: Fetches code with submodules
2. **Install Dependencies**: Installs required system packages
3. **Build**: Compiles the entire project using `make`
4. **Test**: Runs all tests using `test/run_all_tests.sh`
5. **Upload Artifacts**: Saves test results and build artifacts

**Dependencies installed:**
- Build tools: `build-essential`, `cmake`, `git`
- Languages: `python3`, `python3-pip`
- Libraries: `libssl-dev`, `zlib1g-dev`, `libtcmalloc-minimal4`, `uuid-dev`
- Tools: `tcl-dev`, `libffi-dev`, `libreadline-dev`, `bison`, `flex`
- Performance: `libgoogle-perftools-dev`

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