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

if [ ! -f "$VERILOG_SYNTH" ] || [ ! -f "$UHDM_SYNTH" ]; then
    echo "❌ Missing synthesized netlists for $TEST_NAME"
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
# Formal equivalence check using design stash approach
# to avoid module name conflicts between gold and gate designs

# Load cell library
read_verilog -lib +/simcells.v

# Read and process Verilog version (gold)
read_verilog -sv VERILOG_SYNTH_FILE
hierarchy -auto-top
proc
design -stash gold

# Read and process UHDM version (gate)
design -reset
read_verilog -lib +/simcells.v
read_verilog -sv UHDM_SYNTH_FILE
hierarchy -auto-top
proc
design -stash gate

# Copy both designs with different names
# Flatten to handle parameterized modules with different names
design -load gold
hierarchy -auto-top
flatten
design -stash gold_flat

design -load gate
hierarchy -auto-top  
flatten
design -stash gate_flat

# Now copy the flattened designs
design -copy-from gold_flat -as gold *
design -copy-from gate_flat -as gate *

# Perform equivalence check
equiv_make gold gate equiv
equiv_simple
equiv_induct
equiv_status -assert
EOF

# Replace placeholders in the script
sed -i "s|VERILOG_SYNTH_FILE|$VERILOG_SYNTH|g" "$EQUIV_SCRIPT"
sed -i "s|UHDM_SYNTH_FILE|$UHDM_SYNTH|g" "$EQUIV_SCRIPT"

# Get path to yosys
YOSYS_BIN="../../out/current/bin/yosys"
if [ ! -x "$YOSYS_BIN" ]; then
    YOSYS_BIN="../../third_party/yosys/yosys"
fi
if [ ! -x "$YOSYS_BIN" ]; then
    YOSYS_BIN="yosys"
fi

# Run equivalence check
EQUIV_LOG="${TEST_DIR}/equiv_check.log"
echo "Running formal equivalence check for $TEST_NAME..."

if $YOSYS_BIN -q -s "$EQUIV_SCRIPT" > "$EQUIV_LOG" 2>&1; then
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