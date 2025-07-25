#!/bin/bash

# Generate UHDM file if not already present
if [ ! -f slpp_all/surelog.uhdm ]; then
    echo "Generating UHDM..."
    surelog -parse dut.sv
fi

# Run yosys with UHDM frontend
cat > test_uhdm_read.ys <<'EOF'
plugin -i /home/alain/uhdm2rtlil/build/uhdm2rtlil.so
read_uhdm slpp_all/surelog.uhdm
hierarchy -top simple_instance_array
stat
write_rtlil rtlil_uhdm.txt
EOF

echo "Running yosys with UHDM frontend..."
/home/alain/uhdm2rtlil/out/current/bin/yosys -s test_uhdm_read.ys > uhdm_path.log 2>&1

# Check for errors
if grep -q "ERROR" uhdm_path.log; then
    echo "Error found in UHDM import:"
    grep "ERROR" uhdm_path.log
    exit 1
else
    echo "UHDM import successful!"
    
    # Show statistics
    echo -e "\nModule statistics:"
    grep -A 10 "Statistics" uhdm_path.log || true
    
    # Check if gates were created
    echo -e "\nChecking for primitive gates:"
    grep -E "Number of cells:|\\$_AND_|\\$_OR_|\\$_XOR_|\\$_NAND_|\\$_NOT_" uhdm_path.log || true
fi