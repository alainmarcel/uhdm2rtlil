#!/bin/bash

# Script to preprocess Yosys test files to fix SystemVerilog constructs
# that are incompatible with the UHDM frontend

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
YOSYS_TESTS_DIR="$PROJECT_ROOT/third_party/yosys/tests"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Preprocessing Yosys test files...${NC}"

# Counter for modified files
MODIFIED_COUNT=0

# Find all Verilog/SystemVerilog files in the tests directory
find "$YOSYS_TESTS_DIR" -type f \( -name "*.v" -o -name "*.sv" \) | while read -r file; do
    # Check if file contains module declarations with ...
    if grep -q 'module\s\+[a-zA-Z_][a-zA-Z0-9_]*\s*(\s*\.\.\.\s*)' "$file" 2>/dev/null; then
        # Create backup if it doesn't exist
        if [ ! -f "${file}.orig" ]; then
            cp "$file" "${file}.orig"
        fi
        
        # Fix module declarations with ... (replace with empty parentheses)
        # This handles cases like: module top(...);
        sed -i 's/module\s\+\([a-zA-Z_][a-zA-Z0-9_]*\)\s*(\s*\.\.\.\s*)/module \1()/g' "$file"
        
        # Also handle cases with whitespace variations (. . .)
        sed -i 's/module\s\+\([a-zA-Z_][a-zA-Z0-9_]*\)\s*(\s*\.\s*\.\s*\.\s*)/module \1()/g' "$file"
        
        echo -e "${GREEN}✓${NC} Preprocessed: ${file#$YOSYS_TESTS_DIR/}"
        MODIFIED_COUNT=$((MODIFIED_COUNT + 1))
    fi
done

echo -e "${GREEN}Preprocessed $MODIFIED_COUNT test files${NC}"