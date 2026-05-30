#!/bin/bash

# Script to run Yosys tests with UHDM frontend
# This script treats third_party/yosys/tests/ as read-only
# and creates test directories under test/run/

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Directories
YOSYS_TESTS_DIR="$PROJECT_ROOT/third_party/yosys/tests"
RUN_DIR="$SCRIPT_DIR/run"
YOSYS_BIN="$PROJECT_ROOT/out/current/bin/yosys"
SURELOG_BIN="$PROJECT_ROOT/build/third_party/Surelog/bin/surelog"
UHDM_PLUGIN="$PROJECT_ROOT/build/uhdm2rtlil.so"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
UHDM_ONLY_SUCCESS=0

# Arrays to store test results
declare -a PASSED_TEST_NAMES
declare -a FAILED_TEST_NAMES
declare -a SKIPPED_TEST_NAMES
declare -a UHDM_ONLY_TEST_NAMES

# Arrays to track test execution times
declare -A TEST_TIMES
declare -A TEST_START_TIMES

# Create run directory if it doesn't exist
mkdir -p "$RUN_DIR"

# Load skipped tests list
SKIPPED_TESTS_LIST=()
if [ -f "$SCRIPT_DIR/skipped_tests.txt" ]; then
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
            # Trim leading and trailing whitespace and remove inline comments
            trimmed_line=$(echo "$line" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$trimmed_line" ]]; then
                SKIPPED_TESTS_LIST+=("$trimmed_line")
            fi
        fi
    done < "$SCRIPT_DIR/skipped_tests.txt"
fi

# Load failing-tests list — entries are paths relative to
# third_party/yosys/tests/ (e.g. `svinterfaces/load_and_derive.sv`).
# Tests in this list are still RUN; if they fail they're reported as
# EXPECTED FAILED, if they pass they're reported as UNEXPECTED SUCCESS.
FAILING_TESTS_LIST=()
if [ -f "$SCRIPT_DIR/failing_tests.txt" ]; then
    while IFS= read -r line; do
        if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
            trimmed_line=$(echo "$line" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$trimmed_line" ]]; then
                FAILING_TESTS_LIST+=("$trimmed_line")
            fi
        fi
    done < "$SCRIPT_DIR/failing_tests.txt"
fi

EXPECTED_FAILURES=0
UNEXPECTED_SUCCESSES=0
declare -a EXPECTED_FAILURE_NAMES
declare -a UNEXPECTED_SUCCESS_NAMES

# Helper function to check if test should be skipped
should_skip_test() {
    local test_path="$1"
    for skipped_test in "${SKIPPED_TESTS_LIST[@]}"; do
        # Support exact matches and wildcards
        if [[ "$test_path" == "$skipped_test" ]] || [[ "$test_path" == *"$skipped_test"* ]]; then
            return 0
        fi
    done
    return 1
}

# Helper function to check if a test is marked expected-to-fail.  Match
# is exact (no wildcards) — the upstream path lives in failing_tests.txt
# as-is to keep the doc auditable.
is_failing_test() {
    local test_path="$1"
    for failing_test in "${FAILING_TESTS_LIST[@]}"; do
        if [[ "$test_path" == "$failing_test" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to check if a file is a self-contained Verilog/SystemVerilog test
is_verilog_test() {
    local file="$1"
    
    # Check file extension
    if [[ ! "$file" =~ \.(v|sv|vh)$ ]]; then
        return 1
    fi
    
    # Skip include files and headers
    if [[ "$file" =~ \.vh$ ]] || [[ "$file" =~ _inc\.v$ ]] || [[ "$file" =~ _include\.v$ ]]; then
        return 1
    fi
    
    # Skip files that are clearly not self-contained (check for module declaration)
    if ! grep -q "^\s*module\s" "$file" 2>/dev/null; then
        return 1
    fi
    
    # Skip files with includes (they're not self-contained)
    if grep -q "^\s*\`include" "$file" 2>/dev/null; then
        return 1
    fi
    
    return 0
}

# Function to preprocess test files
# Fixes module declarations with ... to make them compatible with UHDM frontend
preprocess_test_file() {
    local file="$1"
    
    # Fix module declarations with ... (replace with empty parentheses)
    # This handles cases like: module top(...);
    sed -i 's/module\s\+\([a-zA-Z_][a-zA-Z0-9_]*\)\s*(\s*\.\.\.\s*)/module \1()/g' "$file"
    
    # Also handle cases with whitespace variations
    sed -i 's/module\s\+\([a-zA-Z_][a-zA-Z0-9_]*\)\s*(\s*\.\s*\.\s*\.\s*)/module \1()/g' "$file"
    
    # Fix trailing commas in port lists (replace ,) with ))
    # This handles cases like: output [15:0] res,);
    # Use [ \t]* for whitespace since \s doesn't work in basic sed
    sed -i 's/,[ \t]*)/)/g' "$file"
    # Also handle cases where comma is at end of line and ) is on next line
    sed -i ':a;N;$!ba;s/,\n[ \t]*)/\n  )/g' "$file"
}

# Function to run a single test
run_test() {
    local test_file="$1"
    local relative_path="${test_file#$YOSYS_TESTS_DIR/}"
    local dir_name=$(dirname "$relative_path")
    local test_name=$(basename "$test_file" .v)
    test_name=$(basename "$test_name" .sv)
    
    # Check if test should be skipped
    if should_skip_test "$relative_path"; then
        echo -e "${YELLOW}Skipping test: $relative_path (marked in skipped_tests.txt)${NC}"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        SKIPPED_TEST_NAMES+=("$relative_path")
        # Don't track time for skipped tests
        return
    fi
    
    # Create test directory maintaining the original structure
    local test_dir="$RUN_DIR/${dir_name}/${test_name}"
    local relative_test_dir="${dir_name}/${test_name}"
    mkdir -p "$test_dir"
    
    echo -e "${BLUE}Running test: $relative_path${NC}"
    
    # Record test start time
    local test_start_time=$(date +%s.%N)
    
    # Preserve the source extension so Surelog picks the right language
    # mode — `.v` enters Verilog-2001 mode (where `ref` etc. are not
    # reserved); `.sv` enters SystemVerilog mode.  Without this,
    # upstream Verilog-2001 tests (e.g. yosys/tests/various/
    # port_sign_extend.v with `module ref(...)`) failed Surelog parse.
    # Yosys's verilog frontend stays in `-sv` for both — it's lenient
    # enough to accept either, and many `.v` files in the yosys tree
    # do rely on a few `-sv` parser conveniences.
    local src_ext="${test_file##*.}"
    local dut_ext="sv"
    if [ "$src_ext" = "v" ]; then
        dut_ext="v"
    fi
    cp "$test_file" "$test_dir/dut.${dut_ext}"

    # Preprocess the test file to fix SystemVerilog constructs
    preprocess_test_file "$test_dir/dut.${dut_ext}"

    # Create Yosys scripts
    cat > "$test_dir/test_verilog_read.ys" << EOF
# Test script to read Verilog file directly in Yosys
read_verilog -sv dut.${dut_ext}
write_rtlil ${test_name}_from_verilog_nohier.il
hierarchy -auto-top
stat
proc
opt
stat
write_rtlil ${test_name}_from_verilog.il
# Synthesize to gate-level netlist
synth -auto-top
write_verilog -noexpr ${test_name}_from_verilog_synth.v
EOF

    cat > "$test_dir/test_uhdm_read.ys" << EOF
# Test script to read UHDM file in Yosys
plugin -i $UHDM_PLUGIN
read_uhdm slpp_all/surelog.uhdm
write_rtlil ${test_name}_from_uhdm_nohier.il
hierarchy -auto-top
stat
proc
opt
stat
write_rtlil ${test_name}_from_uhdm.il
# Synthesize to gate-level netlist
synth -auto-top
write_verilog -noexpr ${test_name}_from_uhdm_synth.v
EOF

    # Change to test directory
    cd "$test_dir"
    
    # Run Verilog frontend
    verilog_success=false
    if $YOSYS_BIN -s test_verilog_read.ys > verilog_path.log 2>&1; then
        verilog_success=true
    fi
    
    # Run Surelog to generate UHDM.  Surelog picks SV vs Verilog-2001
    # from the file extension — see the `dut_ext` choice above.
    # Note: Surelog may return non-zero for elaboration warnings/errors (e.g. $error
    # assertions) but still produce a valid UHDM file, so check for the file instead
    $SURELOG_BIN -parse -nobuiltin -nocache -d uhdm dut.${dut_ext} > surelog.log 2>&1 || true

    # Run UHDM frontend
    uhdm_success=false
    if [ -f "slpp_all/surelog.uhdm" ]; then
        if $YOSYS_BIN -s test_uhdm_read.ys > uhdm_path.log 2>&1; then
            uhdm_success=true
        fi
    fi
    
    # Analyze results
    local test_result="failed"
    
    if [ "$verilog_success" = false ] && [ "$uhdm_success" = true ]; then
        # UHDM-only success
        echo -e "${GREEN}✅ UHDM-only success - UHDM handles advanced SystemVerilog${NC}"
        UHDM_ONLY_SUCCESS=$((UHDM_ONLY_SUCCESS + 1))
        UHDM_ONLY_TEST_NAMES+=("$relative_path")
        test_result="uhdm_only"
    elif [ "$verilog_success" = true ] && [ "$uhdm_success" = true ]; then
        # Both succeeded - check equivalence
        if [ -f "${test_name}_from_verilog.il" ] && [ -f "${test_name}_from_uhdm.il" ]; then
            # First check if RTLIL files are identical
            if diff -q "${test_name}_from_verilog.il" "${test_name}_from_uhdm.il" >/dev/null 2>&1; then
                echo -e "${GREEN}✅ RTLIL outputs are identical${NC}"
                PASSED_TESTS=$((PASSED_TESTS + 1))
                PASSED_TEST_NAMES+=("$relative_path")
                test_result="passed"
            else
                # Try formal equivalence check using existing test_equivalence.sh
                # Need to change to parent directory since test_equivalence.sh expects relative paths
                
                # Call test_equivalence.sh from the run directory
                if (cd "$RUN_DIR" && bash "$SCRIPT_DIR/test_equivalence.sh" "$relative_test_dir"); then
                    if is_failing_test "$relative_path"; then
                        echo -e "${YELLOW}⚠️  UNEXPECTED SUCCESS — remove from failing_tests.txt${NC}"
                        UNEXPECTED_SUCCESSES=$((UNEXPECTED_SUCCESSES + 1))
                        UNEXPECTED_SUCCESS_NAMES+=("$relative_path")
                    fi
                    echo -e "${GREEN}✅ Formal equivalence check passed${NC}"
                    PASSED_TESTS=$((PASSED_TESTS + 1))
                    PASSED_TEST_NAMES+=("$relative_path")
                    test_result="passed"
                else
                    if is_failing_test "$relative_path"; then
                        echo -e "${YELLOW}⚠️  Expected failure (in failing_tests.txt)${NC}"
                        EXPECTED_FAILURES=$((EXPECTED_FAILURES + 1))
                        EXPECTED_FAILURE_NAMES+=("$relative_path")
                    else
                        echo -e "${RED}❌ Equivalence check failed${NC}"
                        FAILED_TESTS=$((FAILED_TESTS + 1))
                        FAILED_TEST_NAMES+=("$relative_path")
                    fi
                fi
            fi
        else
            if is_failing_test "$relative_path"; then
                echo -e "${YELLOW}⚠️  Expected failure (in failing_tests.txt) — missing outputs${NC}"
                EXPECTED_FAILURES=$((EXPECTED_FAILURES + 1))
                EXPECTED_FAILURE_NAMES+=("$relative_path")
            else
                echo -e "${RED}❌ Missing output files${NC}"
                FAILED_TESTS=$((FAILED_TESTS + 1))
                FAILED_TEST_NAMES+=("$relative_path")
            fi
        fi
    elif [ "$verilog_success" = true ] && [ "$uhdm_success" = false ]; then
        if is_failing_test "$relative_path"; then
            echo -e "${YELLOW}⚠️  Expected failure (in failing_tests.txt) — UHDM frontend failed${NC}"
            EXPECTED_FAILURES=$((EXPECTED_FAILURES + 1))
            EXPECTED_FAILURE_NAMES+=("$relative_path")
        else
            echo -e "${RED}❌ UHDM frontend failed${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            FAILED_TEST_NAMES+=("$relative_path")
        fi
    else
        # Both failed
        echo -e "${YELLOW}⚠️  Skipped - both frontends failed${NC}"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        SKIPPED_TEST_NAMES+=("$relative_path")
        test_result="skipped"
    fi
    
    # Return to script directory
    cd "$SCRIPT_DIR"
    
    # Record test end time and calculate duration
    local test_end_time=$(date +%s.%N)
    local test_duration=$(echo "$test_end_time - $test_start_time" | bc)
    TEST_TIMES["$relative_path"]=$test_duration
    printf "Test execution time: %.2f seconds\n" $test_duration
    
    echo ""
    return 0
}

# Function to find and run all tests
find_and_run_tests() {
    local search_dir="$1"
    
    # Find all potential Verilog/SystemVerilog files
    while IFS= read -r -d '' file; do
        if is_verilog_test "$file"; then
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            run_test "$file"
        fi
    done < <(find "$search_dir" -type f \( -name "*.v" -o -name "*.sv" \) -print0 | sort -z)
}

# Main execution
echo "=== Yosys Tests with UHDM Frontend ==="
echo "Test directory: $YOSYS_TESTS_DIR"
echo "Output directory: $RUN_DIR"
echo ""

# Check if specific test pattern is provided
if [ $# -gt 0 ]; then
    # Run specific tests matching pattern
    pattern="$1"
    
    # Handle case where user provides full path
    if [[ "$pattern" == *"$YOSYS_TESTS_DIR"* ]]; then
        # Extract just the relative path within the tests directory
        pattern="${pattern#*$YOSYS_TESTS_DIR/}"
    elif [[ "$pattern" == "../third_party/yosys/tests/"* ]]; then
        # Handle relative path from test directory
        pattern="${pattern#../third_party/yosys/tests/}"
    fi
    
    echo "Running tests matching pattern: $pattern"
    echo ""
    
    while IFS= read -r -d '' file; do
        if is_verilog_test "$file"; then
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            run_test "$file"
        fi
    done < <(find "$YOSYS_TESTS_DIR" -type f \( -name "*.v" -o -name "*.sv" \) -path "*${pattern}*" -print0 | sort -z)
else
    # Run all tests
    find_and_run_tests "$YOSYS_TESTS_DIR"
fi

# Summary
echo "=========================================="
echo "=== TEST SUMMARY ==="
echo "=========================================="
echo ""
echo "📊 OVERALL STATISTICS:"
echo "  Total tests run: $TOTAL_TESTS"
echo "  ✅ Passing tests: $PASSED_TESTS"
echo "  🚀 UHDM-only success: $UHDM_ONLY_SUCCESS"
echo "  ❌ Failed tests: $FAILED_TESTS"
echo "  ⚠️  Expected failures (in failing_tests.txt): $EXPECTED_FAILURES"
echo "  ⚠️  Unexpected successes (remove from failing_tests.txt): $UNEXPECTED_SUCCESSES"
echo "  ⚠️  Skipped tests: $SKIPPED_TESTS"
echo ""

# Success rate calculation
if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$(( (PASSED_TESTS + UHDM_ONLY_SUCCESS) * 100 / TOTAL_TESTS ))
    echo "🎯 Success Rate: ${SUCCESS_RATE}% ($(( PASSED_TESTS + UHDM_ONLY_SUCCESS ))/$TOTAL_TESTS tests functional)"
    echo ""
fi

# Detailed breakdown
if [ ${#PASSED_TEST_NAMES[@]} -gt 0 ]; then
    echo "✅ PASSED TESTS (${#PASSED_TEST_NAMES[@]}):"
    for test in "${PASSED_TEST_NAMES[@]}"; do
        echo "   - $test"
    done
    echo ""
fi

if [ ${#UHDM_ONLY_TEST_NAMES[@]} -gt 0 ]; then
    echo "🚀 UHDM-ONLY SUCCESS (${#UHDM_ONLY_TEST_NAMES[@]}):"
    for test in "${UHDM_ONLY_TEST_NAMES[@]}"; do
        echo "   - $test"
    done
    echo ""
fi

if [ ${#FAILED_TEST_NAMES[@]} -gt 0 ]; then
    echo "❌ FAILED TESTS (${#FAILED_TEST_NAMES[@]}):"
    for test in "${FAILED_TEST_NAMES[@]}"; do
        echo "   - $test"
    done
    echo ""
fi

if [ ${#EXPECTED_FAILURE_NAMES[@]} -gt 0 ]; then
    echo "⚠️  EXPECTED FAILURES (${#EXPECTED_FAILURE_NAMES[@]}) — listed in failing_tests.txt:"
    for test in "${EXPECTED_FAILURE_NAMES[@]}"; do
        echo "   - $test"
    done
    echo ""
fi

if [ ${#UNEXPECTED_SUCCESS_NAMES[@]} -gt 0 ]; then
    echo "🎉 UNEXPECTED SUCCESSES (${#UNEXPECTED_SUCCESS_NAMES[@]}) — please remove from failing_tests.txt:"
    for test in "${UNEXPECTED_SUCCESS_NAMES[@]}"; do
        echo "   - $test"
    done
    echo ""
fi

if [ ${#SKIPPED_TEST_NAMES[@]} -gt 0 ]; then
    echo "⚠️  SKIPPED TESTS (${#SKIPPED_TEST_NAMES[@]}):"
    for test in "${SKIPPED_TEST_NAMES[@]}"; do
        echo "   - $test"
    done
    echo ""
fi

# Export timing data for parent script
if [ ${#TEST_TIMES[@]} -gt 0 ]; then
    # Create temporary file with timing data (use fixed name for IPC)
    TIMING_FILE="/tmp/yosys_test_times_latest.txt"
    > "$TIMING_FILE"  # Clear any existing file
    for test_name in "${!TEST_TIMES[@]}"; do
        echo "$test_name|${TEST_TIMES[$test_name]}" >> "$TIMING_FILE"
    done
    
    # Display top 5 longest running tests
    echo ""
    echo "Top 5 Longest Running Yosys Tests:"
    echo "-----------------------------------"
    sort -t'|' -k2 -rn "$TIMING_FILE" | head -5 | while IFS='|' read test_name duration; do
        printf "  %-50s %.2f seconds\n" "$test_name" "$duration"
    done
fi

# Exit with appropriate code.  Expected failures (in failing_tests.txt)
# don't fail the suite — they're tracked but not blocking.  Unexpected
# successes also don't fail (a passing test is a good thing); the
# warning surfaces in the summary so the txt can be cleaned up.
if [ $FAILED_TESTS -gt 0 ]; then
    exit 1
else
    exit 0
fi