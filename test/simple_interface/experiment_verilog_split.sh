#!/bin/bash

YOSYS=/home/alain/uhdm2rtlil/third_party/yosys/yosys

echo "=== Part 1: Load with Verilog frontend and save RTLIL ==="
cat > part1.ys << 'EOF'
# Load the design with Verilog frontend
read_verilog -sv dut.sv

# Save RTLIL before hierarchy pass
write_rtlil verilog_before_hier.il

# Also dump module info
ls
EOF

$YOSYS part1.ys > part1.log 2>&1
echo "Part 1 complete. Check verilog_before_hier.il and part1.log"

echo ""
echo "=== Part 2: Load RTLIL and run hierarchy pass ==="
cat > part2.ys << 'EOF'
# Load the RTLIL file
read_rtlil verilog_before_hier.il

# Run hierarchy pass
hierarchy -check -top simple_interface

# Run other optimization passes
stat
proc
opt
stat

# Save the result
write_rtlil verilog_after_hier_from_rtlil.il
write_verilog -noexpr verilog_synth_from_rtlil.v
EOF

$YOSYS part2.ys > part2.log 2>&1
echo "Part 2 complete. Check part2.log for any errors"

echo ""
echo "=== Checking if hierarchy pass succeeded ==="
if grep -q "ERROR" part2.log; then
    echo "ERROR found in part2.log:"
    grep -A5 -B5 "ERROR" part2.log
else
    echo "No errors found. Hierarchy pass succeeded!"
fi

echo ""
echo "=== Comparing module counts ==="
echo "Modules in verilog_before_hier.il:"
grep "^module" verilog_before_hier.il | wc -l
echo "Modules in verilog_after_hier_from_rtlil.il:"
grep "^module" verilog_after_hier_from_rtlil.il | wc -l

echo ""
echo "=== Checking for AST information ==="
echo "Checking if RTLIL file contains AST references:"
grep -i "ast" verilog_before_hier.il || echo "No AST references found in RTLIL"