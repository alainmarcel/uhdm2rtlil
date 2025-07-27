#!/bin/bash

# Test script for simple_always_ifelse test case
set -e

MODULE_NAME="simple_always_ifelse"
TEST_DIR="$(dirname "$0")"
BUILD_DIR="../../build"
SURELOG="${BUILD_DIR}/bin/surelog"
YOSYS="${BUILD_DIR}/bin/yosys"

# Clean previous runs
rm -rf slpp_all obj_dir *.il *.v *.log *.txt

# Run Surelog to generate UHDM
echo "Running Surelog..."
${SURELOG} -parse -sverilog -nopython -nobuiltin -nonote -noinfo -timescale 1ns/1ns -elabuhdm dut.sv -d uhdmstats > surelog_build.log 2>&1

# Create Yosys script for UHDM read
cat > test_uhdm_read.ys << EOF
# Test script to read UHDM file in Yosys
plugin -i ${BUILD_DIR}/uhdm2rtlil.so
read_uhdm slpp_all/surelog.uhdm
# Write RTLIL immediately after reading, before hierarchy
write_rtlil ${MODULE_NAME}_from_uhdm_nohier.il
hierarchy -check -top ${MODULE_NAME}
stat
proc
opt
stat
write_rtlil ${MODULE_NAME}_from_uhdm.il
# Synthesize to gate-level netlist
synth -top ${MODULE_NAME}
write_verilog -noexpr ${MODULE_NAME}_from_uhdm_synth.v
EOF

# Create Yosys script for Verilog read
cat > test_verilog_read.ys << EOF
# Test script to read Verilog file in Yosys
read_verilog -sv dut.sv
# Write RTLIL immediately after reading, before hierarchy
write_rtlil ${MODULE_NAME}_from_verilog_nohier.il
hierarchy -check -top ${MODULE_NAME}
stat
proc
opt
stat
write_rtlil ${MODULE_NAME}_from_verilog.il
# Synthesize to gate-level netlist
synth -top ${MODULE_NAME}
write_verilog -noexpr ${MODULE_NAME}_from_verilog_synth.v
EOF

# Run Yosys with UHDM
echo "Running Yosys with UHDM..."
${YOSYS} -s test_uhdm_read.ys > uhdm_path.log 2>&1

# Run Yosys with Verilog
echo "Running Yosys with Verilog..."
${YOSYS} -s test_verilog_read.ys > verilog_path.log 2>&1

# Compare RTLIL files
echo "Comparing RTLIL files..."
diff ${MODULE_NAME}_from_verilog.il ${MODULE_NAME}_from_uhdm.il > rtlil_diff.txt || true

# Compare nohier RTLIL files
echo "Comparing nohier RTLIL files..."
diff ${MODULE_NAME}_from_verilog_nohier.il ${MODULE_NAME}_from_uhdm_nohier.il > rtlil_nohier_diff.txt || true

# Compare synthesized netlists
echo "Comparing synthesized netlists..."
diff ${MODULE_NAME}_from_verilog_synth.v ${MODULE_NAME}_from_uhdm_synth.v > netlist_diff.txt || true

# Check for differences
if [ -s rtlil_diff.txt ] || [ -s rtlil_nohier_diff.txt ]; then
    echo "ERROR: RTLIL files differ!"
    echo "RTLIL differences:"
    head -20 rtlil_diff.txt
    echo ""
    echo "RTLIL nohier differences:"
    head -20 rtlil_nohier_diff.txt
    exit 1
else
    echo "SUCCESS: RTLIL files match!"
fi