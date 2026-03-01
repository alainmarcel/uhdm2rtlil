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
UHDM_RTLIL="${TEST_DIR}/${BASE_NAME}_from_uhdm_nohier.il"
VERILOG_RTLIL="${TEST_DIR}/${BASE_NAME}_from_verilog_nohier.il"

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
    # Only fail if UHDM has X values that Verilog doesn't have  
    if grep -E "^  connect.*'x" "$UHDM_RTLIL" | grep -v "cell \$mux" > /dev/null 2>&1; then
        # Get X connections from both files
        UHDM_X_CONNECTS=$(grep -E "^  connect.*'x" "$UHDM_RTLIL" | grep -v "cell \$mux" | sed 's/^  connect \\//' | sed 's/ .*//' | sort -u)
        VERILOG_X_CONNECTS=$(grep -E "^  connect.*'x" "$VERILOG_RTLIL" 2>/dev/null | grep -v "cell \$mux" | sed 's/^  connect \\//' | sed 's/ .*//' | sort -u || true)
        
        # Check if UHDM has unique X connections not in Verilog
        HAS_UNIQUE_X=0
        for wire in $UHDM_X_CONNECTS; do
            if ! echo "$VERILOG_X_CONNECTS" | grep -q "^$wire$"; then
                if [ $HAS_UNIQUE_X -eq 0 ]; then
                    echo "❌ CRITICAL ERROR: UHDM netlist contains X assignments not present in Verilog!"
                    echo "   UHDM has X assignment to wire: $wire"
                    HAS_UNIQUE_X=1
                fi
                grep "connect \\\\$wire .*'x" "$UHDM_RTLIL" | head -1
            fi
        done
        
        if [ $HAS_UNIQUE_X -eq 1 ]; then
            echo "   This indicates a serious bug in UHDM import"
            exit 1
        fi
    fi
fi

# Check for X assignments in synthesized netlists (.v files)
# Only fail if UHDM has X assignments that Verilog doesn't have for the same signal
if grep -E "assign.*=.*[0-9]+'\w*x|assign.*=.*'x" "$UHDM_SYNTH" > /dev/null 2>&1; then
    # UHDM has X assignments - check if Verilog has them too
    # Extract signal names more carefully, handling escaped identifiers and spaces
    # Also normalize function-generated signal names by replacing $<integer> with @
    UHDM_X_ASSIGNS=$(grep -E "assign.*=.*[0-9]+'\w*x|assign.*=.*'x" "$UHDM_SYNTH" | sed 's/^[[:space:]]*assign[[:space:]]*//; s/[[:space:]]*=.*//' | sed 's/\$[0-9]\+\./\$@./g' | sort -u)
    VERILOG_X_ASSIGNS=$(grep -E "assign.*=.*[0-9]+'\w*x|assign.*=.*'x" "$VERILOG_SYNTH" 2>/dev/null | sed 's/^[[:space:]]*assign[[:space:]]*//; s/[[:space:]]*=.*//' | sed 's/\$[0-9]\+\./\$@./g' | sort -u || true)
    
    # Check each X assignment in UHDM
    HAS_UNIQUE_X=0
    # Get all signal names declared in Verilog synth output (normalized)
    VERILOG_ALL_SIGNALS=$(grep -E "^\s*(wire|assign)" "$VERILOG_SYNTH" 2>/dev/null | sed 's/\$[0-9]\+\./\$@./g' | grep -oP '\\[^ ;=]+' | sort -u || true)
    while IFS= read -r signal; do
        # Skip empty lines
        [ -z "$signal" ] && continue

        # Check if this exact signal exists in Verilog X assignments
        if ! echo "$VERILOG_X_ASSIGNS" | grep -Fx "$signal" > /dev/null 2>&1; then
            # Skip internal task/function wires that don't exist in Verilog output at all
            # These are implementation details (nosync wires) that differ between frontends
            NORM_SIGNAL=$(echo "$signal" | sed 's/^[[:space:]]*//')
            if ! echo "$VERILOG_ALL_SIGNALS" | grep -Fx "\\$NORM_SIGNAL" > /dev/null 2>&1; then
                echo "ℹ️  Skipping X check for internal wire not in Verilog output: $signal"
                continue
            fi
            if [ $HAS_UNIQUE_X -eq 0 ]; then
                echo "❌ CRITICAL ERROR for $TEST_NAME: UHDM synthesized netlist contains X assignments not present in Verilog!"
                echo "   UHDM has X assignment to signal: $signal"
                HAS_UNIQUE_X=1
            fi
            # Show the actual assignment line
            grep -F "assign $signal " "$UHDM_SYNTH" | head -1
        fi
    done <<< "$UHDM_X_ASSIGNS"
    
    if [ $HAS_UNIQUE_X -eq 1 ]; then
        echo "   This indicates a serious bug in $TEST_NAME - the design is non-functional"
        exit 1
    else
        echo "ℹ️  Both UHDM and Verilog have X assignments to the same signals - this is acceptable"
    fi
fi

# Check if there are any gates to compare
GATE_COUNT=$(grep -c -E '\$_' "$VERILOG_SYNTH" || true)
if [ "$GATE_COUNT" -eq 0 ]; then
    # Constant-only circuit: no logic gates, only assign statements.
    # The equiv_make flow creates no $equiv cells for portless modules so it passes
    # vacuously.  Instead, compare constant values for every signal that appears
    # in BOTH synthesized netlists.
    echo "ℹ️  No logic gates - comparing constant wire values for $TEST_NAME"

    # Module-aware comparison using awk.
    # A naive grep across the whole file incorrectly matches same-named signals
    # (e.g. `assign out = ...`) from different modules.  Track the enclosing
    # module name and key the gate lookup table as "module:signal".
    AWK_RESULT=$(awk '
    FNR == NR {
        # First file: gate (UHDM synth) — build lookup keyed by module:signal
        if (match($0, /^[[:space:]]*module[[:space:]]+([^[:space:](;]+)/, m))
            cur_mod = m[1]
        if (match($0, /^[[:space:]]*assign[[:space:]]+([^[:space:]=]+)[[:space:]]*=[[:space:]]*(.*);[[:space:]]*$/, a)) {
            val = a[2]; gsub(/ /, "", val); gsub(/\?/, "x", val)
            gate[cur_mod ":" a[1]] = val
        }
        next
    }
    {
        # Second file: gold (Verilog synth)
        if (match($0, /^[[:space:]]*module[[:space:]]+([^[:space:](;]+)/, m))
            cur_mod = m[1]
        if (match($0, /^[[:space:]]*assign[[:space:]]+([^[:space:]=]+)[[:space:]]*=[[:space:]]*(.*);[[:space:]]*$/, a)) {
            gold_val = a[2]; gsub(/ /, "", gold_val); gsub(/\?/, "x", gold_val)
            if (gold_val ~ /[xXzZ]/) next   # undefined in gold — skip
            key = cur_mod ":" a[1]
            if (!(key in gate)) next         # absent in gate — skip
            gate_val = gate[key]
            checked++
            if (gold_val != gate_val)
                print "FAIL:" cur_mod "." a[1] ":gold=" gold_val ":gate=" gate_val
        }
    }
    END { print "CHECKED=" checked+0 }
    ' "$UHDM_SYNTH" "$VERILOG_SYNTH")

    CONST_CHECKED=$(echo "$AWK_RESULT" | grep '^CHECKED=' | sed 's/CHECKED=//')
    CONST_FAILED=0
    while IFS= read -r fail_line; do
        [[ "$fail_line" == FAIL:* ]] || continue
        mod_sig=$(echo "$fail_line" | sed 's/FAIL:\(.*\):gold=.*/\1/')
        gold_val=$(echo "$fail_line" | sed 's/.*:gold=\(.*\):gate=.*/\1/')
        gate_val=$(echo "$fail_line" | sed 's/.*:gate=\(.*\)/\1/')
        echo "❌ Signal '$mod_sig': gold=$gold_val  gate=$gate_val"
        CONST_FAILED=1
    done <<< "$AWK_RESULT"

    if [ "${CONST_CHECKED:-0}" -eq 0 ]; then
        # Nothing to compare (e.g. no assign statements at all) — skip
        echo "ℹ️  No common assign statements to compare — skipping"
        echo "# No gates or assigns to check equivalence" > "${TEST_DIR}/test_equiv.ys"
        exit 0
    fi

    if [ "$CONST_FAILED" -eq 0 ]; then
        echo "✅ All $CONST_CHECKED common constant assignments match"
        echo "# Constant-only circuit equivalence verified by value comparison" > "${TEST_DIR}/test_equiv.ys"
        exit 0
    else
        echo "❌ Constant value mismatch — circuits are NOT equivalent for $TEST_NAME"
        exit 1
    fi
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
async2sync  # Convert async reset to sync for equivalence checking
design -stash gold

# Read and process UHDM version (gate)
design -reset
read_verilog -lib +/simcells.v
read_verilog -sv UHDM_SYNTH_FILE
hierarchy -auto-top
proc
flatten
async2sync  # Convert async reset to sync for equivalence checking
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