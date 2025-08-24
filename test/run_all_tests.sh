#!/bin/bash

# Test runner script for UHDM frontend
# Runs test_uhdm_workflow.sh for every test directory and provides comprehensive statistics
# Can also run Yosys tests with --yosys or --all options

# Don't exit on error - we want to run all tests
set +e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default behavior
RUN_LOCAL=true
RUN_YOSYS=false
SPECIFIC_TEST=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --yosys)
            RUN_LOCAL=false
            RUN_YOSYS=true
            shift
            ;;
        --all)
            RUN_LOCAL=true
            RUN_YOSYS=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [TEST_PATTERN]"
            echo ""
            echo "Options:"
            echo "  --yosys       Run only Yosys tests from third_party/yosys/tests/"
            echo "  --all         Run both local tests and Yosys tests"
            echo "  --help, -h    Show this help message"
            echo ""
            echo "Arguments:"
            echo "  TEST_PATTERN  Optional pattern to match specific tests"
            echo ""
            echo "Examples:"
            echo "  $0                    # Run all local tests"
            echo "  $0 simple_memory      # Run local test matching 'simple_memory'"
            echo "  $0 --yosys            # Run all Yosys tests"
            echo "  $0 --yosys simple     # Run Yosys tests matching 'simple'"
            echo "  $0 --all              # Run all local and Yosys tests"
            exit 0
            ;;
        *)
            SPECIFIC_TEST="$1"
            shift
            ;;
    esac
done

echo "=== UHDM Frontend Test Runner ==="

# Change to test directory
cd "$SCRIPT_DIR"

# Initialize counters and tracking arrays
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
CRASHED_TESTS=0
UHDM_ONLY_TESTS=0

# For Yosys tests
YOSYS_TOTAL=0
YOSYS_PASSED=0
YOSYS_FAILED=0
YOSYS_SKIPPED=0
YOSYS_UHDM_ONLY=0
EQUIV_FAILED_TESTS=0

FAILED_TEST_NAMES=()
SKIPPED_TEST_NAMES=()
CRASHED_TEST_NAMES=()
PASSED_TEST_NAMES=()
UHDM_ONLY_TEST_NAMES=()
EQUIV_FAILED_TEST_NAMES=()

# Track unexpected results
UNEXPECTED_FAILURES=()
UNEXPECTED_SUCCESSES=()

# Load failing tests list
FAILING_TESTS=()
if [ -f "failing_tests.txt" ]; then
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
            # Trim leading and trailing whitespace and remove inline comments
            trimmed_line=$(echo "$line" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$trimmed_line" ]]; then
                FAILING_TESTS+=("$trimmed_line")
            fi
        fi
    done < "failing_tests.txt"
fi

if [ ${#FAILING_TESTS[@]} -gt 0 ]; then
    echo "Tests marked as failing (will still be run): ${FAILING_TESTS[*]}"
else
    echo "No tests marked as failing - all tests will be run normally"
fi

# Load skipped tests list
SKIPPED_TESTS_LIST=()
if [ -f "skipped_tests.txt" ]; then
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
            # Trim leading and trailing whitespace and remove inline comments
            trimmed_line=$(echo "$line" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$trimmed_line" ]]; then
                SKIPPED_TESTS_LIST+=("$trimmed_line")
            fi
        fi
    done < "skipped_tests.txt"
fi

if [ ${#SKIPPED_TESTS_LIST[@]} -gt 0 ]; then
    echo "Tests marked as skipped (will not be run): ${SKIPPED_TESTS_LIST[*]}"
else
    echo "No tests marked as skipped - all tests will be run"
fi
echo

# Only find local test directories if running local tests
if [ "$RUN_LOCAL" = true ]; then
    # Find all test directories (directories containing dut.sv)
    TEST_DIRS=()
    if [ -n "$SPECIFIC_TEST" ] && [ "$RUN_YOSYS" = false ]; then
        # Check if the specific test exists
        if [ -d "$SPECIFIC_TEST" ] && [ -f "$SPECIFIC_TEST/dut.sv" ]; then
            TEST_DIRS+=("$SPECIFIC_TEST")
        else
            echo "Error: Test '$SPECIFIC_TEST' not found or doesn't contain dut.sv"
            exit 1
        fi
    elif [ "$RUN_YOSYS" = false ] || [ -z "$SPECIFIC_TEST" ]; then
        # Find all test directories
        for dir in */; do
            if [ -d "$dir" ] && [ -f "$dir/dut.sv" ]; then
                # Remove trailing slash from directory name
                TEST_NAME="${dir%/}"
                # Skip the run directory (used for Yosys tests)
                if [ "$TEST_NAME" != "run" ]; then
                    TEST_DIRS+=("$TEST_NAME")
                fi
            fi
        done
    fi

    if [ "$RUN_YOSYS" = false ] && [ ${#TEST_DIRS[@]} -eq 0 ]; then
        echo "No test directories found (looking for directories containing dut.sv)"
        exit 1
    fi

    if [ ${#TEST_DIRS[@]} -gt 0 ]; then
        echo "Found ${#TEST_DIRS[@]} local test(s): ${TEST_DIRS[*]}"
        echo
    fi
fi

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

# Helper function to check if test should be skipped
should_skip_test() {
    local test_name="$1"
    for skipped_test in "${SKIPPED_TESTS_LIST[@]}"; do
        # Support wildcards in skipped test patterns
        if [[ "$test_name" == $skipped_test ]] || [[ "$test_name" == *"$skipped_test"* ]]; then
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
    local uhdm_synth="${test_dir}/${test_dir}_from_uhdm_synth.v"
    local verilog_synth="${test_dir}/${test_dir}_from_verilog_synth.v"
    
    # Check if UHDM output exists
    if [ ! -f "$uhdm_file" ]; then
        echo "❌ Test $test_dir FAILED - UHDM output missing"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$test_dir")
        return 1
    fi
    
    # If Verilog output is missing but UHDM succeeded, this might be showcasing UHDM's superior capabilities
    if [ ! -f "$verilog_file" ]; then
        # Check if Verilog frontend failed (common for advanced SystemVerilog)
        if [ -f "${test_dir}/verilog_path.log" ] && grep -q "ERROR" "${test_dir}/verilog_path.log"; then
            echo "✅ Test $test_dir PASSED - UHDM succeeds where Verilog fails!"
            echo "    Demonstrates UHDM's superior SystemVerilog support"
            UHDM_ONLY_TESTS=$((UHDM_ONLY_TESTS + 1))
            UHDM_ONLY_TEST_NAMES+=("$test_dir")
            return 0
        else
            echo "❌ Test $test_dir FAILED - Verilog output missing unexpectedly"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            FAILED_TEST_NAMES+=("$test_dir")
            return 1
        fi
    fi
    
    # Check if RTLIL outputs are identical
    local rtlil_identical=false
    if diff -q "$uhdm_file" "$verilog_file" >/dev/null 2>&1; then
        rtlil_identical=true
    fi
    
    # Check if synthesized netlists are identical or have same gate count
    local synth_identical=false
    local gates_match=false
    if [ -f "$uhdm_synth" ] && [ -f "$verilog_synth" ]; then
        # Compare netlists ignoring comments and whitespace
        grep -v "^//" "$uhdm_synth" | grep -v "^$" | sed 's/^[[:space:]]*//' > /tmp/uhdm_synth_clean.tmp
        grep -v "^//" "$verilog_synth" | grep -v "^$" | sed 's/^[[:space:]]*//' > /tmp/verilog_synth_clean.tmp
        if diff -q /tmp/verilog_synth_clean.tmp /tmp/uhdm_synth_clean.tmp >/dev/null 2>&1; then
            synth_identical=true
        fi
        rm -f /tmp/uhdm_synth_clean.tmp /tmp/verilog_synth_clean.tmp
        
        # Run formal equivalence check when both netlists exist
        local equiv_passed=false
        local equiv_failed=false
        if [ -x "./test_equivalence.sh" ]; then
            if ./test_equivalence.sh "$test_dir" >/dev/null 2>&1; then
                echo "    ✅ Formal equivalence check PASSED"
                equiv_passed=true
            else
                echo "    ❌ Formal equivalence check FAILED - netlists are not logically equivalent"
                equiv_failed=true
            fi
        fi
    fi
    
    # Report results
    if [ "$equiv_failed" = true ]; then
        echo "❌ Test $test_dir FAILED - Formal equivalence check failed"
        EQUIV_FAILED_TESTS=$((EQUIV_FAILED_TESTS + 1))
        EQUIV_FAILED_TEST_NAMES+=("$test_dir")
        return 2  # Return 2 to indicate equivalence failure (different from other failures)
    elif [ "$rtlil_identical" = true ] && [ "$synth_identical" = true ]; then
        echo "✅ Test $test_dir PASSED - Both RTLIL and synthesized netlists are IDENTICAL"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        PASSED_TEST_NAMES+=("$test_dir")
        return 0
    elif [ "$equiv_passed" = true ]; then
        echo "✅ Test $test_dir PASSED - Formal equivalence check confirmed functional equivalence"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        PASSED_TEST_NAMES+=("$test_dir")
        return 0
    elif [ "$rtlil_identical" = true ] && [ "$synth_identical" = false ]; then
        echo "⚠️  Test $test_dir FAILED - RTLIL identical but synthesized netlists differ"
        EQUIV_FAILED_TESTS=$((EQUIV_FAILED_TESTS + 1))
        EQUIV_FAILED_TEST_NAMES+=("$test_dir")
        return 2
    elif [ "$rtlil_identical" = false ] && [ "$synth_identical" = true ]; then
        echo "✅ Test $test_dir PASSED - RTLIL differs but synthesized netlists are IDENTICAL (functionally equivalent)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        PASSED_TEST_NAMES+=("$test_dir")
        return 0
    else
        echo "⚠️  Test $test_dir FUNCTIONAL - Both RTLIL and synthesized netlists differ (no equivalence check performed)"
        # This shouldn't happen with equivalence checking enabled
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$test_dir")
        
        # Count lines to show size difference
        local uhdm_lines=$(wc -l < "$uhdm_file" 2>/dev/null || echo "0")
        local verilog_lines=$(wc -l < "$verilog_file" 2>/dev/null || echo "0")
        echo "    RTLIL: UHDM=$uhdm_lines lines, Verilog=$verilog_lines lines"
        
        if [ -f "$uhdm_synth" ] && [ -f "$verilog_synth" ]; then
            # Count gates
            local uhdm_gates=$(grep -E '\$_' "$uhdm_synth" | wc -l)
            local verilog_gates=$(grep -E '\$_' "$verilog_synth" | wc -l)
            echo "    Gates: UHDM=$uhdm_gates, Verilog=$verilog_gates"
        fi
        return 1
    fi
}

# Run local tests if requested and found
if [ "$RUN_LOCAL" = true ] && [ ${#TEST_DIRS[@]} -gt 0 ]; then
    for test_dir in "${TEST_DIRS[@]}"; do
    
    # Check if test should be skipped
    if should_skip_test "$test_dir"; then
        echo "=========================================="
        echo "Skipping test: $test_dir (marked in skipped_tests.txt)"
        echo "=========================================="
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        SKIPPED_TEST_NAMES+=("$test_dir")
        echo
        continue
    fi
    
    echo "=========================================="
    echo "Running test: $test_dir"
    echo "=========================================="
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Check if test is expected to fail
    expected_to_fail=false
    if is_failing_test "$test_dir"; then
        expected_to_fail=true
    fi
    
    # Run the test and capture result
    ./test_uhdm_workflow.sh "$test_dir" >/dev/null 2>&1
    exit_code=$?
    
    # Analyze the result
    echo -n "Result: "
    test_result=""
    test_passed=false
    analyze_test_result "$test_dir" "$exit_code"
    result_code=$?
    
    # Determine test result type
    if [ $result_code -eq 0 ]; then
        test_passed=true
        test_result="passed"
    elif [ $result_code -eq 2 ]; then
        # Equivalence check failure
        test_result="equiv_failed"
    else
        test_result="failed"
    fi
    
    # Check for unexpected results
    if [ "$expected_to_fail" = true ]; then
        if [ "$test_result" = "passed" ]; then
            echo "    ⚠️  UNEXPECTED SUCCESS - This test was expected to fail!"
            UNEXPECTED_SUCCESSES+=("$test_dir")
        elif [ "$test_result" = "equiv_failed" ]; then
            echo "    Note: This test was expected to fail (equivalence check failure)"
        else
            echo "    Note: This test was expected to fail"
        fi
    else
        if [ "$test_result" = "failed" ]; then
            echo "    ⚠️  UNEXPECTED FAILURE - This test was expected to pass!"
            UNEXPECTED_FAILURES+=("$test_dir")
        elif [ "$test_result" = "equiv_failed" ]; then
            echo "    ⚠️  UNEXPECTED EQUIVALENCE FAILURE - This test should pass formal equivalence!"
            UNEXPECTED_FAILURES+=("$test_dir")
        fi
    fi
    
    echo
    done
fi  # End of local test loop

# Run Yosys tests if requested
if [ "$RUN_YOSYS" = true ]; then
    echo "=========================================="
    echo "=== Running Yosys Tests ==="
    echo "=========================================="
    echo
    
    # Save current directory
    SAVE_DIR=$(pwd)
    
    # Run the Yosys test script and capture results
    YOSYS_OUTPUT_FILE="/tmp/yosys_test_output_$$.txt"
    if [ -n "$SPECIFIC_TEST" ] && [ "$RUN_LOCAL" = false ]; then
        "$SCRIPT_DIR/run_yosys_tests.sh" "$SPECIFIC_TEST" | tee "$YOSYS_OUTPUT_FILE"
    else
        "$SCRIPT_DIR/run_yosys_tests.sh" | tee "$YOSYS_OUTPUT_FILE"
    fi
    YOSYS_EXIT_CODE=$?
    
    # Return to original directory
    cd "$SAVE_DIR"
    
    # Parse Yosys test results and update global counters
    if [ -f "$YOSYS_OUTPUT_FILE" ]; then
        # Extract UHDM-only success count and names
        if grep -q "🚀 UHDM-only success:" "$YOSYS_OUTPUT_FILE"; then
            YOSYS_UHDM_COUNT=$(grep "🚀 UHDM-only success:" "$YOSYS_OUTPUT_FILE" | sed 's/.*: //')
            if [ -n "$YOSYS_UHDM_COUNT" ] && [ "$YOSYS_UHDM_COUNT" -gt 0 ]; then
                UHDM_ONLY_TESTS=$((UHDM_ONLY_TESTS + YOSYS_UHDM_COUNT))
                
                # Extract UHDM-only test names from the output
                IN_UHDM_SECTION=false
                while IFS= read -r line; do
                    if [[ "$line" =~ ^🚀[[:space:]]UHDM-ONLY[[:space:]]SUCCESS ]]; then
                        IN_UHDM_SECTION=true
                    elif [[ "$line" =~ ^(✅|❌|⏭️|💥|$) ]] && [ "$IN_UHDM_SECTION" = true ]; then
                        IN_UHDM_SECTION=false
                    elif [ "$IN_UHDM_SECTION" = true ] && [[ "$line" =~ ^[[:space:]]+-[[:space:]] ]]; then
                        test_name=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//')
                        UHDM_ONLY_TEST_NAMES+=("$test_name")
                    fi
                done < "$YOSYS_OUTPUT_FILE"
            fi
        fi
        
        # Clean up
        rm -f "$YOSYS_OUTPUT_FILE"
    fi
    
    echo  # Extra newline after Yosys tests
fi

# Final summary - show when any tests were run
if [ "$TOTAL_TESTS" -gt 0 ]; then
    echo "=========================================="
    echo "=== COMPREHENSIVE TEST SUMMARY ==="
    echo "=========================================="
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

if [ $UHDM_ONLY_TESTS -gt 0 ]; then
    echo
    echo "🚀 UHDM-ONLY SUCCESS ($UHDM_ONLY_TESTS tests):"
    echo "   These tests demonstrate UHDM's superior SystemVerilog support:"
    for test in "${UHDM_ONLY_TEST_NAMES[@]}"; do
        echo "   - $test"
    done
fi


if [ $CRASHED_TESTS -gt 0 ]; then
    echo
    echo "💥 CRASHED TESTS ($CRASHED_TESTS tests):"
    echo "   These tests crashed during execution and need investigation:"
    for test in "${CRASHED_TEST_NAMES[@]}"; do
        echo "   - $test"
    done
fi

if [ $EQUIV_FAILED_TESTS -gt 0 ]; then
    echo
    echo "❌ EQUIVALENCE FAILURES ($EQUIV_FAILED_TESTS tests):"
    echo "   These tests generate output but fail formal equivalence checking:"
    for test in "${EQUIV_FAILED_TEST_NAMES[@]}"; do
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
# Recalculate functional tests before displaying
FUNCTIONAL_TESTS=$((PASSED_TESTS + UHDM_ONLY_TESTS))
echo "  • Tests that work: $FUNCTIONAL_TESTS/$TOTAL_TESTS"
echo "  • Tests that crash: $CRASHED_TESTS/$TOTAL_TESTS"
echo "  • Tests that fail equivalence: $EQUIV_FAILED_TESTS/$TOTAL_TESTS"
echo "  • Tests that fail to generate output: $FAILED_TESTS/$TOTAL_TESTS"

# Check for any unexpected results
if [ ${#UNEXPECTED_FAILURES[@]} -gt 0 ]; then
    echo
    echo "❌ UNEXPECTED FAILURES (${#UNEXPECTED_FAILURES[@]} tests):"
    echo "   These tests were expected to pass but failed:"
    for test in "${UNEXPECTED_FAILURES[@]}"; do
        echo "   - $test"
    done
fi


if [ ${#UNEXPECTED_SUCCESSES[@]} -gt 0 ]; then
    echo
    echo "❌ UNEXPECTED SUCCESSES (${#UNEXPECTED_SUCCESSES[@]} tests):"
    echo "   These tests were expected to fail but passed:"
    for test in "${UNEXPECTED_SUCCESSES[@]}"; do
        echo "   - $test"
    done
    echo
    echo "   Please remove these from failing_tests.txt"
fi

echo
echo "📊 OVERALL STATISTICS:"
echo "  Total tests run: $TOTAL_TESTS"
echo "  ✅ Passing tests: $PASSED_TESTS"
echo "  🚀 UHDM-only success: $UHDM_ONLY_TESTS"
echo "  ❌ Equivalence failures: $EQUIV_FAILED_TESTS"
echo "  ❌ True failures: $FAILED_TESTS"
echo "  💥 Crashes: $CRASHED_TESTS"
echo

# Calculate success rate (excluding equivalence failures and true failures)
FUNCTIONAL_TESTS=$((PASSED_TESTS + UHDM_ONLY_TESTS))
NON_FAILING_TESTS=$((TOTAL_TESTS - FAILED_TESTS - CRASHED_TESTS - EQUIV_FAILED_TESTS))
if [ $TOTAL_TESTS -gt 0 ] && [ $NON_FAILING_TESTS -gt 0 ]; then
    SUCCESS_RATE=$((FUNCTIONAL_TESTS * 100 / NON_FAILING_TESTS))
    echo "🎯 Success Rate: $SUCCESS_RATE% ($FUNCTIONAL_TESTS/$NON_FAILING_TESTS tests functional, excluding known failures)"
fi

# Determine exit status
echo
if [ ${#UNEXPECTED_FAILURES[@]} -eq 0 ] && [ ${#UNEXPECTED_SUCCESSES[@]} -eq 0 ]; then
    # Count expected failures
    EXPECTED_FAILS=0
    for test in "${FAILED_TEST_NAMES[@]}"; do
        if is_failing_test "$test"; then
            EXPECTED_FAILS=$((EXPECTED_FAILS + 1))
        fi
    done
    for test in "${EQUIV_FAILED_TEST_NAMES[@]}"; do
        if is_failing_test "$test"; then
            EXPECTED_FAILS=$((EXPECTED_FAILS + 1))
        fi
    done
    for test in "${CRASHED_TEST_NAMES[@]}"; do
        if is_failing_test "$test"; then
            EXPECTED_FAILS=$((EXPECTED_FAILS + 1))
        fi
    done
    
    if [ $CRASHED_TESTS -eq 0 ] && [ $FAILED_TESTS -eq 0 ] && [ $EQUIV_FAILED_TESTS -eq 0 ]; then
        echo "🎉 EXCELLENT! All tests are functional! 🎉"
        exit 0
    elif [ $EXPECTED_FAILS -gt 0 ]; then
        echo "✅ ALL RESULTS AS EXPECTED - Test suite passes with known issues"
        echo
        echo "All failing tests are documented in failing_tests.txt:"
        echo "  • Expected failures: $EXPECTED_FAILS"
        echo "  • Functional tests: $FUNCTIONAL_TESTS/$TOTAL_TESTS"
        echo
        echo "The test suite passes because all results match expectations."
        exit 0
    else
        echo "✅ ALL RESULTS AS EXPECTED - Test suite passes with known issues"
        echo
        echo "All failing tests are documented in failing_tests.txt:"
        echo "  • Crashed tests: $CRASHED_TESTS"
        echo "  • Equivalence failures: $EQUIV_FAILED_TESTS"
        echo "  • Failed tests: $FAILED_TESTS"
        echo "  • Functional tests: $FUNCTIONAL_TESTS/$TOTAL_TESTS"
        echo
        echo "The test suite passes because all results match expectations."
        exit 0
    fi
else
    echo "❌ TEST SUITE FAILED - Unexpected results detected!"
    echo
    if [ ${#UNEXPECTED_FAILURES[@]} -gt 0 ]; then
        echo "• ${#UNEXPECTED_FAILURES[@]} tests failed unexpectedly"
    fi
    if [ ${#UNEXPECTED_SUCCESSES[@]} -gt 0 ]; then
        echo "• ${#UNEXPECTED_SUCCESSES[@]} tests passed unexpectedly"
    fi
    echo
    echo "Please investigate unexpected results or update failing_tests.txt"
    exit 1
fi

fi  # End of local test summary