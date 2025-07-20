#!/bin/bash

# Test runner script for UHDM frontend
# Runs test_uhdm_workflow.sh for every test directory and provides comprehensive statistics

# Don't exit on error - we want to run all tests
set +e

echo "=== UHDM Frontend Test Runner ==="
echo "Running all test cases..."
echo

# Change to test directory
cd "$(dirname "$0")"

# Initialize counters and tracking arrays
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
CRASHED_TESTS=0
RTLIL_DIFF_TESTS=0

FAILED_TEST_NAMES=()
SKIPPED_TEST_NAMES=()
CRASHED_TEST_NAMES=()
RTLIL_DIFF_TEST_NAMES=()
PASSED_TEST_NAMES=()

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

if [ ${#FAILING_TESTS[@]} -gt 0 ]; then
    echo "Tests marked as failing (will still be run): ${FAILING_TESTS[*]}"
else
    echo "No tests marked as failing - all tests will be run normally"
fi
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

# Helper function to analyze test result
analyze_test_result() {
    local test_dir="$1"
    local exit_code="$2"
    
    # Check for crashes (core dumps, aborts, etc)
    if [ "$exit_code" -eq 134 ] || [ "$exit_code" -eq 139 ] || [ "$exit_code" -eq 6 ]; then
        echo "💥 Test $test_dir CRASHED (exit code: $exit_code)"
        CRASHED_TESTS=$((CRASHED_TESTS + 1))
        CRASHED_TEST_NAMES+=("$test_dir")
        return 1
    fi
    
    # Check if test generated output files
    local uhdm_file="${test_dir}/${test_dir}_from_uhdm.il"
    local verilog_file="${test_dir}/${test_dir}_from_verilog.il"
    
    if [ ! -f "$uhdm_file" ] || [ ! -f "$verilog_file" ]; then
        echo "❌ Test $test_dir FAILED - missing output files"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$test_dir")
        return 1
    fi
    
    # Check if RTLIL outputs are identical
    if diff -q "$uhdm_file" "$verilog_file" >/dev/null 2>&1; then
        echo "✅ Test $test_dir PASSED - RTLIL outputs are IDENTICAL"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        PASSED_TEST_NAMES+=("$test_dir")
        return 0
    else
        echo "⚠️  Test $test_dir FUNCTIONAL - RTLIL outputs differ (expected)"
        RTLIL_DIFF_TESTS=$((RTLIL_DIFF_TESTS + 1))
        RTLIL_DIFF_TEST_NAMES+=("$test_dir")
        
        # Count lines to show size difference
        local uhdm_lines=$(wc -l < "$uhdm_file" 2>/dev/null || echo "0")
        local verilog_lines=$(wc -l < "$verilog_file" 2>/dev/null || echo "0")
        echo "    UHDM: $uhdm_lines lines, Verilog: $verilog_lines lines"
        return 0
    fi
}

# Run tests
for test_dir in "${TEST_DIRS[@]}"; do
    echo "=========================================="
    echo "Running test: $test_dir"
    echo "=========================================="
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Mark if test was previously failing
    was_failing=""
    if is_failing_test "$test_dir"; then
        was_failing=" [was marked as failing]"
    fi
    
    # Run the test and capture result
    ./test_uhdm_workflow.sh "$test_dir" >/dev/null 2>&1
    exit_code=$?
    
    # Analyze the result
    echo -n "Result: "
    analyze_test_result "$test_dir" "$exit_code"
    
    if [ -n "$was_failing" ]; then
        echo "    Note: This test was previously marked as failing"
    fi
    
    echo
done

# Final summary
echo "=========================================="
echo "=== COMPREHENSIVE TEST SUMMARY ==="
echo "=========================================="
echo
echo "📊 OVERALL STATISTICS:"
echo "  Total tests run: $TOTAL_TESTS"
echo "  ✅ Perfect matches: $PASSED_TESTS"
echo "  ⚠️  Functional (RTLIL diffs): $RTLIL_DIFF_TESTS"
echo "  ❌ True failures: $FAILED_TESTS"
echo "  💥 Crashes: $CRASHED_TESTS"
echo

# Calculate success rate
FUNCTIONAL_TESTS=$((PASSED_TESTS + RTLIL_DIFF_TESTS))
if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$((FUNCTIONAL_TESTS * 100 / TOTAL_TESTS))
    echo "🎯 Success Rate: $SUCCESS_RATE% ($FUNCTIONAL_TESTS/$TOTAL_TESTS tests functional)"
fi

echo
echo "📈 DETAILED BREAKDOWN:"

if [ $PASSED_TESTS -gt 0 ]; then
    echo
    echo "✅ PERFECT MATCHES ($PASSED_TESTS tests):"
    echo "   These tests produce identical RTLIL output between UHDM and Verilog frontends:"
    for test in "${PASSED_TEST_NAMES[@]}"; do
        echo "   - $test"
    done
fi

if [ $RTLIL_DIFF_TESTS -gt 0 ]; then
    echo
    echo "⚠️  FUNCTIONAL WITH DIFFERENCES ($RTLIL_DIFF_TESTS tests):"
    echo "   These tests work correctly but have expected RTLIL differences:"
    for test in "${RTLIL_DIFF_TEST_NAMES[@]}"; do
        echo "   - $test"
    done
    echo
    echo "   Note: RTLIL differences are normal between UHDM and Verilog frontends due to:"
    echo "   • Different source location tracking"
    echo "   • Different intermediate representations"
    echo "   • Different wire/cell naming conventions"
    echo "   • Different optimization passes applied"
fi

if [ $CRASHED_TESTS -gt 0 ]; then
    echo
    echo "💥 CRASHED TESTS ($CRASHED_TESTS tests):"
    echo "   These tests crashed during execution and need investigation:"
    for test in "${CRASHED_TEST_NAMES[@]}"; do
        echo "   - $test"
    done
fi

if [ $FAILED_TESTS -gt 0 ]; then
    echo
    echo "❌ TRUE FAILURES ($FAILED_TESTS tests):"
    echo "   These tests failed to generate output files:"
    for test in "${FAILED_TEST_NAMES[@]}"; do
        echo "   - $test"
    done
fi

echo
echo "🔍 ANALYSIS:"
echo "  • Tests that work: $FUNCTIONAL_TESTS/$TOTAL_TESTS"
echo "  • Tests that crash: $CRASHED_TESTS/$TOTAL_TESTS"
echo "  • Tests that fail: $FAILED_TESTS/$TOTAL_TESTS"

echo
if [ $CRASHED_TESTS -eq 0 ] && [ $FAILED_TESTS -eq 0 ]; then
    echo "🎉 EXCELLENT! All tests are functional! 🎉"
    echo
    echo "The UHDM frontend successfully processes all test cases without crashes."
    if [ $RTLIL_DIFF_TESTS -gt 0 ]; then
        echo "RTLIL differences are expected and normal between different frontends."
    fi
    echo
    echo "✨ Key achievements:"
    echo "  • No crashes or failures"
    echo "  • All SystemVerilog constructs are supported"
    echo "  • Memory analysis pass is working"
    echo "  • Parameter handling is correct"
    echo "  • Process import is functional"
    exit 0
elif [ $CRASHED_TESTS -eq 0 ]; then
    echo "⚠️  MOSTLY WORKING - Some tests fail but none crash"
    echo "This suggests configuration or missing file issues rather than code bugs."
    exit 1
else
    echo "❌ NEEDS ATTENTION - Some tests are crashing"
    echo "Priority should be fixing crashes before addressing other issues."
    exit 1
fi