#!/bin/bash

# Test runner script for UHDM frontend
# Runs test_uhdm_workflow.sh for every test directory and stops on first error

set -e  # Exit on any error

echo "=== UHDM Frontend Test Runner ==="
echo "Running all test cases..."
echo

# Change to test directory
cd "$(dirname "$0")"

# Initialize counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
FAILED_TEST_NAMES=()
SKIPPED_TEST_NAMES=()

# Load failing tests list
FAILING_TESTS=()
if [ -f "failing_tests.txt" ]; then
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
            FAILING_TESTS+=("$line")
        fi
    done < "failing_tests.txt"
fi

echo "Known failing tests (will be skipped): ${FAILING_TESTS[*]}"
echo

# Find all test directories (directories containing dut.sv)
TEST_DIRS=()
for dir in */; do
    if [ -d "$dir" ] && [ -f "$dir/dut.sv" ]; then
        # Remove trailing slash from directory name
        TEST_NAME="${dir%/}"
        TEST_DIRS+=("$TEST_NAME")
    fi
done

if [ ${#TEST_DIRS[@]} -eq 0 ]; then
    echo "No test directories found (looking for directories containing dut.sv)"
    exit 1
fi

echo "Found ${#TEST_DIRS[@]} test(s): ${TEST_DIRS[*]}"
echo

# Helper function to check if test is in failing list
is_failing_test() {
    local test_name="$1"
    for failing_test in "${FAILING_TESTS[@]}"; do
        if [ "$test_name" = "$failing_test" ]; then
            return 0
        fi
    done
    return 1
}

# Run tests
for test_dir in "${TEST_DIRS[@]}"; do
    echo "=========================================="
    echo "Running test: $test_dir"
    echo "=========================================="
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Check if this test is marked as failing
    if is_failing_test "$test_dir"; then
        echo "⚠️  Test $test_dir is marked as failing, skipping..."
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        SKIPPED_TEST_NAMES+=("$test_dir")
        echo
        continue
    fi
    
    # Run the test
    if ./test_uhdm_workflow.sh "$test_dir"; then
        echo
        echo "✓ Test $test_dir PASSED"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo
        echo "✗ Test $test_dir FAILED"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$test_dir")
        
        # Stop on first failure
        echo
        echo "=== FAILURE SUMMARY ==="
        echo "Test failed: $test_dir"
        echo "Stopping test run due to failure."
        break
    fi
    
    echo
done

# Final summary
echo "=========================================="
echo "=== FINAL TEST SUMMARY ==="
echo "=========================================="
echo "Total tests found: $TOTAL_TESTS"
echo "Passed: $PASSED_TESTS"
echo "Failed: $FAILED_TESTS"
echo "Skipped: $SKIPPED_TESTS"

if [ $SKIPPED_TESTS -gt 0 ]; then
    echo
    echo "📋 SKIPPED TESTS (marked as failing):"
    for skipped_test in "${SKIPPED_TEST_NAMES[@]}"; do
        echo "  - $skipped_test"
    done
fi

if [ $FAILED_TESTS -eq 0 ]; then
    echo
    if [ $SKIPPED_TESTS -eq 0 ]; then
        echo "🎉 ALL TESTS PASSED! 🎉"
        echo "UHDM frontend is working correctly across all test cases."
    else
        echo "✅ ALL ENABLED TESTS PASSED! ✅"
        echo "UHDM frontend is working correctly for all non-failing test cases."
        echo "Note: $SKIPPED_TESTS test(s) were skipped (marked as failing)."
    fi
    exit 0
else
    echo
    echo "❌ TESTS FAILED:"
    for failed_test in "${FAILED_TEST_NAMES[@]}"; do
        echo "  - $failed_test"
    done
    echo
    echo "Please fix the failing test(s) before proceeding."
    exit 1
fi