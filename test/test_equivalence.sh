#!/bin/bash

# Formal equivalence checking script for UHDM vs Verilog netlists
# This script is called by run_all_tests.sh to verify logical equivalence
# of gate-level netlists when both frontends produce output with same gate count

set -e

# Usage: test_equivalence.sh <test_name>
if [ $# -ne 1 ]; then
    echo "Usage: $0 <test_name>"
    exit 1
fi

TEST_NAME="$1"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Handle both absolute and relative paths
if [[ "$TEST_NAME" = /* ]]; then
    # Absolute path
    TEST_DIR="$TEST_NAME"
else
    # Relative path - prepend current directory
    TEST_DIR="$(pwd)/$TEST_NAME"
fi

# Extract just the base name for the files (last component of the path)
BASE_NAME=$(basename "$TEST_NAME")

# Check if required files exist
VERILOG_SYNTH="${TEST_DIR}/${BASE_NAME}_from_verilog_synth.v"
UHDM_SYNTH="${TEST_DIR}/${BASE_NAME}_from_uhdm_synth.v"
UHDM_RTLIL="${TEST_DIR}/${BASE_NAME}_from_uhdm.il"

if [ ! -f "$VERILOG_SYNTH" ] || [ ! -f "$UHDM_SYNTH" ]; then
    echo "❌ Missing synthesized netlists for $TEST_NAME"
    exit 1
fi

# Check for X assignments in UHDM RTLIL output
# Note: X values in mux defaults (connect \A) are normal for if/else chains
# Only flag X values in direct wire connections or problematic contexts
if [ -f "$UHDM_RTLIL" ]; then
    # Look for problematic X assignments (excluding mux A port defaults and memrd clocks)
    # Note: memrd cells use X for clock when CLK_ENABLE=0 (asynchronous reads)
    # Only check for X in actual clock inputs to sequential elements
    if grep -E "connect \\\\(clk|clock) .*'x" "$UHDM_RTLIL" | grep -v "cell .*memrd" > /dev/null 2>&1; then
        echo "❌ CRITICAL ERROR: UHDM netlist contains X assignments in clock signals!"
        echo "   Found X values in clock connections:"
        grep -E "connect \\\\(clk|clock) .*'x" "$UHDM_RTLIL" | grep -v "cell .*memrd" | head -5
        echo "   This indicates a serious bug in UHDM import - the design is non-functional"
        exit 1
    fi
    # Check for X values in top-level wire connections (not in cells)
    if grep -E "^  connect.*'x" "$UHDM_RTLIL" | grep -v "cell \$mux" > /dev/null 2>&1; then
        echo "❌ CRITICAL ERROR: UHDM netlist contains X assignments in wire connections!"
        echo "   Found X values in wire connections:"
        grep -E "^  connect.*'x" "$UHDM_RTLIL" | grep -v "cell \$mux" | head -5
        echo "   This indicates a serious bug in UHDM import"
        exit 1
    fi
fi

# Also check synthesized netlist for X assignments
if grep -E "assign.*=.*[0-9]+'\w*x|assign.*=.*'x" "$UHDM_SYNTH" > /dev/null 2>&1; then
    echo "❌ CRITICAL ERROR: UHDM synthesized netlist contains X assignments!"
    echo "   Found X values in assignments:"
    grep -E "assign.*=.*[0-9]+'\w*x|assign.*=.*'x" "$UHDM_SYNTH" | head -5
    echo "   This indicates a serious bug - the design is non-functional"
    exit 1
fi

# Check if there are any gates to compare
GATE_COUNT=$(grep -c -E '\$_' "$VERILOG_SYNTH" || true)
if [ "$GATE_COUNT" -eq 0 ]; then
    echo "ℹ️  No gates in synthesized netlist - skipping equivalence check for $TEST_NAME"
    # Still create the test_equiv.ys file for reference
    echo "# No gates to check equivalence" > "${TEST_DIR}/test_equiv.ys"
    exit 0
fi

# We'll let Yosys auto-detect the top module

# Create equivalence check script
EQUIV_SCRIPT="${TEST_DIR}/test_equiv.ys"
cat > "$EQUIV_SCRIPT" << 'EOF'
# Formal equivalence check for gate-level netlists
# This properly detects sequential vs combinational differences

# Load cell library
read_verilog -lib +/simcells.v

# Read and process Verilog version (gold)
read_verilog -sv VERILOG_SYNTH_FILE
hierarchy -auto-top
proc
flatten
design -stash gold

# Read and process UHDM version (gate)
design -reset
read_verilog -lib +/simcells.v
read_verilog -sv UHDM_SYNTH_FILE
hierarchy -auto-top
proc
flatten
design -stash gate

# Print statistics for both designs to detect sequential vs combinational
log
log === GOLD DESIGN STATISTICS ===
design -load gold
stat -width
log
log === GATE DESIGN STATISTICS ===
design -load gate
stat -width

# Count sequential elements in both designs
design -load gold
select */t:$_DFF_* */t:$_DFFE_* */t:$_SDFF* */t:$_DLATCH* */t:$_SR_* %ci
log
log Sequential cells in gold:
stat
select -clear

design -load gate
select */t:$_DFF_* */t:$_DFFE_* */t:$_SDFF* */t:$_DLATCH* */t:$_SR_* %ci
log
log Sequential cells in gate:
stat
select -clear

# Skip the SAT-based approach and use only the equiv flow
# which is specifically designed for gate-level netlists
design -reset
read_verilog -lib +/simcells.v
read_verilog -sv VERILOG_SYNTH_FILE
hierarchy -auto-top
proc
flatten
design -stash gold_flat

design -reset
read_verilog -lib +/simcells.v
read_verilog -sv UHDM_SYNTH_FILE
hierarchy -auto-top
proc
flatten
design -stash gate_flat

design -copy-from gold_flat -as gold *
design -copy-from gate_flat -as gate *

equiv_make gold gate equiv
equiv_simple
equiv_induct
equiv_status -assert
EOF

# Replace placeholders in the script
sed -i "s|VERILOG_SYNTH_FILE|$VERILOG_SYNTH|g" "$EQUIV_SCRIPT"
sed -i "s|UHDM_SYNTH_FILE|$UHDM_SYNTH|g" "$EQUIV_SCRIPT"

# Get path to yosys using the same approach as run_yosys_tests.sh
YOSYS_BIN="$PROJECT_ROOT/out/current/bin/yosys"

# Check if Yosys exists and is executable
if [ ! -f "$YOSYS_BIN" ]; then
    echo "WARNING: Yosys not found at $YOSYS_BIN"
    # Try alternative paths
    if [ -f "$PROJECT_ROOT/third_party/yosys/yosys" ]; then
        YOSYS_BIN="$PROJECT_ROOT/third_party/yosys/yosys"
        echo "Found Yosys at alternative path: $YOSYS_BIN"
    elif [ -f "$PROJECT_ROOT/build/third_party/yosys/yosys" ]; then
        YOSYS_BIN="$PROJECT_ROOT/build/third_party/yosys/yosys"
        echo "Found Yosys at build path: $YOSYS_BIN"
    elif command -v yosys >/dev/null 2>&1; then
        YOSYS_BIN="yosys"
        echo "Using system Yosys"
    else
        echo "ERROR: Could not find Yosys executable"
        echo "Searched paths:"
        echo "  - $PROJECT_ROOT/out/current/bin/yosys"
        echo "  - $PROJECT_ROOT/third_party/yosys/yosys"
        echo "  - $PROJECT_ROOT/build/third_party/yosys/yosys"
        echo "  - System PATH"
        exit 1
    fi
fi

# Make sure it's executable
if [ ! -x "$YOSYS_BIN" ]; then
    echo "ERROR: Yosys binary is not executable: $YOSYS_BIN"
    ls -la "$YOSYS_BIN" || echo "File does not exist"
    exit 1
fi

# Run equivalence check
EQUIV_LOG="${TEST_DIR}/equiv_check.log"
echo "Running formal equivalence check for $TEST_NAME..."

if $YOSYS_BIN -s "$EQUIV_SCRIPT" > "$EQUIV_LOG" 2>&1; then
    echo "✅ Formal equivalence check PASSED for $TEST_NAME"
    # Keep the test_equiv.ys file for reference
    exit 0
else
    echo "❌ Formal equivalence check FAILED for $TEST_NAME"
    echo "See $EQUIV_LOG for details"
    
    # Show last few lines of log for debugging
    echo "--- Last 20 lines of equivalence check log ---"
    tail -20 "$EQUIV_LOG"
    echo "----------------------------------------------"
    
    # Keep the test_equiv.ys file for debugging
    exit 1
fi