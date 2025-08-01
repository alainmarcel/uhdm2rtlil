#!/bin/bash

YOSYS=/home/alain/uhdm2rtlil/third_party/yosys/yosys

echo "=== Running hierarchy directly after Verilog load ==="
cat > direct.ys << 'EOF'
# Load the design with Verilog frontend
read_verilog -sv dut.sv

# List modules and their types
ls

# Check module types
select \data_bus_if
show -format dot

# Run hierarchy pass
hierarchy -check -top simple_interface

# List modules after hierarchy
ls
EOF

$YOSYS direct.ys > direct.log 2>&1

echo "=== Checking module types ==="
grep -A20 "data_bus_if" direct.log | head -40