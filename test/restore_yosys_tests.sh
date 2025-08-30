#!/bin/bash

# Script to restore original Yosys test files from backups

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
YOSYS_TESTS_DIR="$PROJECT_ROOT/third_party/yosys/tests"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Restoring original Yosys test files...${NC}"

# Counter for restored files
RESTORED_COUNT=0

# Find all backup files
find "$YOSYS_TESTS_DIR" -type f -name "*.orig" | while read -r backup_file; do
    original_file="${backup_file%.orig}"
    
    if [ -f "$original_file" ]; then
        # Restore from backup
        cp "$backup_file" "$original_file"
        # Remove backup
        rm "$backup_file"
        
        echo -e "${GREEN}✓${NC} Restored: ${original_file#$YOSYS_TESTS_DIR/}"
        RESTORED_COUNT=$((RESTORED_COUNT + 1))
    else
        echo -e "${RED}✗${NC} Original file missing for backup: ${backup_file#$YOSYS_TESTS_DIR/}"
    fi
done

echo -e "${GREEN}Restored $RESTORED_COUNT test files${NC}"