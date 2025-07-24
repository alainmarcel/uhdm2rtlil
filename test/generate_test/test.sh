#!/bin/bash

# Exit on error
set -e

echo "=== Running generate_test ==="

# Clean previous outputs
rm -f generate_test_from_verilog.il generate_test_from_uhdm.il rtlil_diff.txt

# Parse SystemVerilog to UHDM
echo "1. Parsing SystemVerilog to UHDM..."
../../third_party/Surelog/build/bin/surelog -parse -sverilog dut.sv

# Read Verilog directly with Yosys
echo "2. Reading Verilog with Yosys..."
../../third_party/yosys/yosys -q -s test_verilog_read.ys

# Read UHDM with our plugin
echo "3. Reading UHDM with our plugin..."
../../third_party/yosys/yosys -q -s test_uhdm_read.ys

# Compare outputs
echo "4. Comparing outputs..."
if diff -u generate_test_from_uhdm.il generate_test_from_verilog.il > rtlil_diff.txt; then
    echo "✓ Test PASSED: Outputs match!"
    exit 0
else
    echo "✗ Test FAILED: Outputs differ"
    echo "Diff saved to rtlil_diff.txt"
    head -20 rtlil_diff.txt
    exit 1
fi