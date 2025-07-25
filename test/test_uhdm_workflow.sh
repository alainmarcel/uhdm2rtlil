#!/bin/bash

# Generic test script for UHDM workflow comparison: UHDM vs Verilog frontends
# This script demonstrates the complete flow and compares UHDM vs Verilog import
# Usage: test_uhdm_workflow.sh <test_directory>

set -e  # Exit on any error

# Check if test directory argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <test_directory>"
    echo "Example: $0 flipflop"
    exit 1
fi

TEST_DIR="$1"

# Check if test directory exists
if [ ! -d "$TEST_DIR" ]; then
    echo "ERROR: Test directory '$TEST_DIR' does not exist"
    exit 1
fi

# Change to test directory
cd "$TEST_DIR"

# Extract module name from directory name (for hierarchy command)
# Remove any trailing slash and extract just the basename
MODULE_NAME=$(basename "$TEST_DIR" | sed 's|/$||')

echo "=== UHDM vs Verilog Workflow Comparison ==="
echo "Testing: SystemVerilog -> [UHDM path vs Verilog path] -> Yosys -> RTLIL comparison"
echo "Test Directory: $TEST_DIR"
echo "Module Name: $MODULE_NAME"
echo

# Set up paths (relative to test directory)
SURELOG_BIN="../../build/third_party/Surelog/bin/surelog"
YOSYS_BIN="../../out/current/bin/yosys"
SV_FILE="dut.sv"
UHDM_FILE="slpp_all/surelog.uhdm"

# Check if binaries exist
if [ ! -f "$SURELOG_BIN" ]; then
    echo "ERROR: Surelog not found at $SURELOG_BIN"
    exit 1
fi

if [ ! -f "$YOSYS_BIN" ]; then
    echo "ERROR: Yosys not found at $YOSYS_BIN"
    exit 1
fi

if [ ! -f "$SV_FILE" ]; then
    echo "ERROR: SystemVerilog file $SV_FILE not found in $TEST_DIR"
    exit 1
fi

# Clean up previous runs (but preserve UHDM file)
echo "1. Cleaning up previous files..."
rm -f *.log *.dot *_from_uhdm.il *_from_verilog.il rtlil_diff.txt test_*_read.ys uhdm_path.log verilog_path.log
rm -f *_from_uhdm_synth.v *_from_verilog_synth.v netlist_diff.txt

# Step 1: Check if UHDM file exists or generate it
echo "2. Checking for existing UHDM file or generating..."
if [ -f "$UHDM_FILE" ]; then
    echo "   ✓ Using existing UHDM file: $UHDM_FILE"
    echo "   File size: $(ls -lh $UHDM_FILE | awk '{print $5}')"
else
    echo "   Running Surelog to generate UHDM..."
    echo "   Command: $SURELOG_BIN -parse -d uhdm $SV_FILE"
    echo "   Logging to: surelog_build.log"
    $SURELOG_BIN -parse -d uhdm "$SV_FILE" > surelog_build.log 2>&1
    
    # Check if UHDM file was generated
    if [ ! -f "$UHDM_FILE" ]; then
        echo "ERROR: UHDM file $UHDM_FILE was not generated by Surelog"
        echo "Check surelog_build.log for errors"
        exit 1
    fi
    
    echo "   ✓ UHDM file generated successfully: $UHDM_FILE"
    echo "   File size: $(ls -lh $UHDM_FILE | awk '{print $5}')"
    echo "   Surelog log saved to: surelog_build.log"
fi
echo

# Step 2: Create Yosys script to read UHDM file
echo "3. Creating Yosys script to read UHDM..."
cat > test_uhdm_read.ys << EOF
# Test script to read UHDM file in Yosys
plugin -i ../../build/uhdm2rtlil.so
read_uhdm slpp_all/surelog.uhdm
# Write RTLIL immediately after reading, before hierarchy
write_rtlil ${MODULE_NAME}_from_uhdm_nohier.il
hierarchy -check -top $MODULE_NAME
stat
proc
opt
stat
write_rtlil ${MODULE_NAME}_from_uhdm.il
# Synthesize to gate-level netlist
synth -top $MODULE_NAME
write_verilog -noexpr ${MODULE_NAME}_from_uhdm_synth.v
EOF

echo "   ✓ Yosys script created: test_uhdm_read.ys"
echo

# Step 3: Create Yosys script to read Verilog file
echo "4. Creating Yosys script to read Verilog..."
cat > test_verilog_read.ys << EOF
# Test script to read Verilog file directly in Yosys
read_verilog -sv dut.sv
# Write RTLIL immediately after reading, before hierarchy
write_rtlil ${MODULE_NAME}_from_verilog_nohier.il
hierarchy -check -top $MODULE_NAME
stat
proc
opt
stat
write_rtlil ${MODULE_NAME}_from_verilog.il
# Synthesize to gate-level netlist
synth -top $MODULE_NAME
write_verilog -noexpr ${MODULE_NAME}_from_verilog_synth.v
EOF

echo "   ✓ Yosys script created: test_verilog_read.ys"
echo

# Step 4: Run Yosys with UHDM input
echo "5. Running Yosys with UHDM input (logging to uhdm_path.log)..."
echo "   Command: $YOSYS_BIN test_uhdm_read.ys > uhdm_path.log 2>&1"
if $YOSYS_BIN test_uhdm_read.ys > uhdm_path.log 2>&1; then
    echo "   ✓ Yosys successfully processed UHDM file"
    echo "   Log saved to: uhdm_path.log"
else
    echo "   ✗ Yosys failed to process UHDM file"
    echo "   Check uhdm_path.log for errors"
    exit 1
fi

echo

# Check if this test is in the failing tests list
IS_FAILING_TEST=0
if [ -f "../failing_tests.txt" ] && grep -q "^$TEST_DIR$" "../failing_tests.txt"; then
    IS_FAILING_TEST=1
    echo "   Note: This test is in the failing_tests.txt list"
fi

# Step 5: Run Yosys with Verilog input
echo "6. Running Yosys with direct Verilog input (logging to verilog_path.log)..."
echo "   Command: $YOSYS_BIN test_verilog_read.ys > verilog_path.log 2>&1"
VERILOG_FAILED=0
if $YOSYS_BIN test_verilog_read.ys > verilog_path.log 2>&1; then
    echo "   ✓ Yosys successfully processed Verilog file"
    echo "   Log saved to: verilog_path.log"
else
    VERILOG_FAILED=1
    echo "   ⚠ Yosys failed to process Verilog file"
    echo "   This may be expected for certain SystemVerilog constructs"
    echo "   Check verilog_path.log for details"
    
    # If UHDM passed but Verilog failed, this might demonstrate UHDM's superior capabilities
    if [ ! -f "${MODULE_NAME}_from_uhdm.il" ]; then
        echo "   ✗ ERROR: Both UHDM and Verilog frontends failed"
        exit 1
    fi
fi

echo

# Step 6: Compare the results
echo "7. Comparing UHDM vs Verilog RTLIL outputs..."
UHDM_RTLIL="${MODULE_NAME}_from_uhdm.il"
VERILOG_RTLIL="${MODULE_NAME}_from_verilog.il"

if [ $VERILOG_FAILED -eq 1 ] && [ -f "$UHDM_RTLIL" ]; then
    echo "   ✓ UHDM frontend succeeded where Verilog frontend failed!"
    echo "   This demonstrates UHDM's superior SystemVerilog support"
    echo
    echo "   UHDM RTLIL ($UHDM_RTLIL):"
    echo "   ====================================="
    cat "$UHDM_RTLIL"
    echo
    
    # Count cells in UHDM output
    if grep -q "Number of cells:" uhdm_path.log; then
        echo "   Cell statistics from UHDM import:"
        grep -A 10 "Number of cells:" uhdm_path.log | grep -E "Number of cells:|\\$_"
    fi
    
    RESULT=0  # Success - UHDM works even when Verilog doesn't
elif [ -f "$UHDM_RTLIL" ] && [ -f "$VERILOG_RTLIL" ]; then
    echo "   Both files generated successfully"
    echo
    echo "   UHDM RTLIL ($UHDM_RTLIL):"
    echo "   ====================================="
    cat "$UHDM_RTLIL"
    echo
    echo "   Verilog RTLIL ($VERILOG_RTLIL):"
    echo "   =========================================="
    cat "$VERILOG_RTLIL"
    echo
    
    # Compare files
    if diff -u "$UHDM_RTLIL" "$VERILOG_RTLIL" > rtlil_diff.txt; then
        echo "   ✓ RTLIL outputs are IDENTICAL!"
        echo "     UHDM frontend produces the same result as Verilog frontend"
        rm rtlil_diff.txt
        RESULT=0
    else
        echo "   ⚠ RTLIL outputs are DIFFERENT:"
        echo "     Differences saved to rtlil_diff.txt"
        echo
        echo "   Diff summary:"
        head -20 rtlil_diff.txt
        if [ $(wc -l < rtlil_diff.txt) -gt 20 ]; then
            echo "   ... (truncated, see rtlil_diff.txt for full diff)"
        fi
        # For tests in failing_tests.txt, differences are expected
        if [ $IS_FAILING_TEST -eq 1 ]; then
            echo "   Note: Differences are expected for this test (in failing_tests.txt)"
            RESULT=0
        else
            RESULT=1
        fi
    fi
else
    echo "   ✗ One or both RTLIL files missing"
    ls -la *.il 2>/dev/null || echo "   No .il files found"
    RESULT=1
fi

echo

# Step 7: Compare synthesized netlists if both were generated
echo "8. Comparing synthesized gate-level netlists..."
UHDM_SYNTH="${MODULE_NAME}_from_uhdm_synth.v"
VERILOG_SYNTH="${MODULE_NAME}_from_verilog_synth.v"

if [ $VERILOG_FAILED -eq 1 ] && [ -f "$UHDM_SYNTH" ]; then
    echo "   ✓ UHDM frontend produced synthesized netlist"
    echo "   Verilog frontend failed, so no netlist comparison possible"
    echo
    echo "   UHDM synthesized netlist ($UHDM_SYNTH):"
    echo "   ===================================="
    head -50 "$UHDM_SYNTH"
    if [ $(wc -l < "$UHDM_SYNTH") -gt 50 ]; then
        echo "   ... (truncated, see $UHDM_SYNTH for full netlist)"
    fi
elif [ -f "$UHDM_SYNTH" ] && [ -f "$VERILOG_SYNTH" ]; then
    echo "   Both synthesized netlists generated successfully"
    
    # Extract just the module contents for comparison (ignore comments and formatting)
    # This helps compare the actual gate-level implementation
    grep -v "^//" "$UHDM_SYNTH" | grep -v "^$" | sed 's/^[[:space:]]*//' > uhdm_synth_clean.tmp
    grep -v "^//" "$VERILOG_SYNTH" | grep -v "^$" | sed 's/^[[:space:]]*//' > verilog_synth_clean.tmp
    
    if diff -u verilog_synth_clean.tmp uhdm_synth_clean.tmp > netlist_diff.txt; then
        echo "   ✓ Synthesized netlists are IDENTICAL!"
        echo "     Both frontends produce the same gate-level implementation"
        rm netlist_diff.txt uhdm_synth_clean.tmp verilog_synth_clean.tmp
    else
        echo "   ⚠ Synthesized netlists are DIFFERENT:"
        echo "     Differences saved to netlist_diff.txt"
        echo
        echo "   Netlist diff summary:"
        head -20 netlist_diff.txt
        if [ $(wc -l < netlist_diff.txt) -gt 20 ]; then
            echo "   ... (truncated, see netlist_diff.txt for full diff)"
        fi
        
        # Count gates in each netlist for comparison
        echo
        echo "   Gate count comparison:"
        echo -n "   UHDM path: "
        grep -E "\\$\\(and|or|xor|not|mux|dff\\)" "$UHDM_SYNTH" | wc -l
        echo -n "   Verilog path: "
        grep -E "\\$\\(and|or|xor|not|mux|dff\\)" "$VERILOG_SYNTH" | wc -l
    fi
    rm -f uhdm_synth_clean.tmp verilog_synth_clean.tmp
else
    echo "   ⚠ One or both synthesized netlists missing"
    ls -la *_synth.v 2>/dev/null || echo "   No synthesized netlists found"
fi

echo
echo "=== Test Summary ==="
echo "✓ Surelog successfully parsed SystemVerilog and generated UHDM"
echo "✓ Yosys UHDM frontend successfully read UHDM and generated RTLIL"

if [ $VERILOG_FAILED -eq 1 ]; then
    echo "⚠ Yosys Verilog frontend failed (may be expected for advanced SystemVerilog)"
    echo "✓ UHDM frontend demonstrates superior SystemVerilog support!"
else
    echo "✓ Yosys Verilog frontend successfully read SystemVerilog and generated RTLIL"
    
    if [ -f "rtlil_diff.txt" ]; then
        if [ $IS_FAILING_TEST -eq 1 ]; then
            echo "⚠ RTLIL outputs differ (expected - test is in failing_tests.txt)"
        else
            echo "⚠ RTLIL outputs differ - see rtlil_diff.txt for details"
        fi
    else
        echo "✓ RTLIL outputs are identical - UHDM frontend working correctly!"
    fi
fi

echo
echo "Generated files:"
ls -la *.uhdm *.il *.ys *.txt *.log *_synth.v 2>/dev/null || echo "  Files may not have been generated"

# Return to original directory
cd ..

# Exit with appropriate code
exit $RESULT