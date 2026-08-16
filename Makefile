# Top-level Makefile for uhdm2rtlil
.PHONY: all debug test test-read-sv test-all test-cores test-cva6 test-yosys frontends test-matrix clean plugin install help

# Use bash as the default shell
SHELL := /usr/bin/env bash

ifeq ($(CPU_CORES),)
	CPU_CORES := $(shell nproc)
	ifeq ($(CPU_CORES),)
		CPU_CORES := $(shell sysctl -n hw.physicalcpu)
	endif
	ifeq ($(CPU_CORES),)
		CPU_CORES := 2  # Good minimum assumption
	endif
endif

# Default target
all: build
	@echo "Building uhdm2rtlil in Release mode..."
	@cd build && make -j$(CPU_CORES)

# Debug build target
debug: build-debug
	@echo "Building uhdm2rtlil in Debug mode..."
	@cd build-debug && make -j$(CPU_CORES)

# Smoke test for the `read_sv` command (in-process Surelog compile, no .uhdm).
# Fast; run first in CI so a broken plugin entry point fails early.
test-read-sv: all
	@echo "Testing read_sv command..."
	@cd test && ./test_read_sv.sh

# Test target - runs our internal tests only
test: all test-read-sv
	@echo "Running tests..."
	@cd build && make test

# Test all target - runs internal tests + all Yosys tests + CVA6 equivalence.
# The CVA6 stage runs LAST because it is by far the slowest (146 modules, each
# its own Surelog elaboration plus a SAT miter).
test-all: all
	@echo "Running all tests (internal + Yosys + CVA6 equivalence)..."
	@echo "  note: the CVA6 stage runs last and is the slowest; --no-cva6 skips it"
	@cd test && ./run_all_tests.sh --all

# CVA6 per-module formal equivalence (read_uhdm vs the built-in read_slang).
# The CVA6 RTL is vendored under test/cva6_equiv/rtl (refresh it with
# test/cva6_equiv/vendor_cva6.sh <cva6-checkout>), so this needs no external
# checkout.  It is also run as part of `make test-all`.
test-cva6: all
	@echo "Running CVA6 per-module equivalence tests..."
	@cd test && ./run_all_tests.sh --cva6

# Test cores target - runs only the rp32 and Ibex core IP tests
test-cores: all
	@echo "Running core IP tests (rp32 + Ibex)..."
	@cd test && ./run_all_tests.sh --cores --no-cva6

# Test Yosys target - runs only Yosys tests
test-yosys: all preprocess-yosys-tests
	@echo "Running Yosys tests..."
	@cd test && ./run_all_tests.sh --yosys

# Build the external frontend(s) for the 4-frontend matrix.  Only sv2v is
# external now — slang (read_slang / sv-elab) is built into the yosys binary
# via YOSYS_ENABLE_SLANG=ON.  Requires Haskell Stack on PATH for sv2v.
frontends: all
	@echo "Building external frontends (sv2v)..."
	@cd test && ./build_frontends.sh

# Run the 4-frontend regression matrix over the internal tests.
test-matrix: all frontends
	@echo "Running 4-frontend regression matrix..."
	@cd test && python3 run_frontend_matrix.py

# Preprocess Yosys test files to fix incompatible constructs
preprocess-yosys-tests:
	@echo "Preprocessing Yosys test files..."
	@cd test && ./preprocess_yosys_tests.sh

# Create release build directory and configure
build: | build/Makefile

build/Makefile:
	@echo "Configuring Release build..."
	@mkdir -p build
	@if [[ "$(CC)" == *"ccache"* ]]; then \
		cd build && cmake -DCMAKE_BUILD_TYPE=Release -DCPU_CORES=$(CPU_CORES) -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER=g++ ..; \
	else \
		cd build && cmake -DCMAKE_BUILD_TYPE=Release -DCPU_CORES=$(CPU_CORES) -DCMAKE_C_COMPILER="$(CC)" -DCMAKE_CXX_COMPILER="$(CXX)" ..; \
	fi

# Create debug build directory and configure
build-debug: | build-debug/Makefile

build-debug/Makefile:
	@echo "Configuring Debug build..."
	@mkdir -p build-debug
	@if [[ "$(CC)" == *"ccache"* ]]; then \
		cd build-debug && cmake -DCMAKE_BUILD_TYPE=Debug -DCPU_CORES=$(CPU_CORES) -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER=g++ ..; \
	else \
		cd build-debug && cmake -DCMAKE_BUILD_TYPE=Debug -DCPU_CORES=$(CPU_CORES) -DCMAKE_C_COMPILER="$(CC)" -DCMAKE_CXX_COMPILER="$(CXX)" ..; \
	fi

# Clean build artifacts.
#
# IMPORTANT: Yosys v0.67 builds out-of-tree under third_party/yosys/build/ (its
# own CMake build dir) and installs into out/.  Both survive `rm -rf build`, so
# a proper clean must remove the Yosys CMake build dir too — otherwise a stale
# build links against objects from a previous submodule pin and crashes at
# runtime (ABI mismatch, e.g. `std::out_of_range: Cell::getParam()`).
clean:
	@echo "Cleaning build artifacts (build dirs, out/, Yosys CMake build)..."
	rm -rf build build-debug out
	rm -rf third_party/yosys/build
	@echo "Clean complete. (Re-running 'make' will rebuild Yosys from scratch.)"

# Install target
install: all
	@echo "Installing uhdm2rtlil plugin..."
	cd build && make install

# Plugin target - build and show plugin location
plugin: all
	@echo "Plugin built at: $(shell pwd)/build/uhdm2rtlil.so"
	@echo "To use with Yosys: yosys -m $(shell pwd)/build/uhdm2rtlil.so"

# Help target
help:
	@echo "Available targets:"
	@echo "  all        - Build in Release mode (default)"
	@echo "  debug      - Build in Debug mode"
	@echo "  plugin     - Build and show plugin location"
	@echo "  test-read-sv - Smoke-test the read_sv command (in-process Surelog)"
	@echo "  test       - Run internal tests only (includes test-read-sv)"
	@echo "  test-all   - Run all tests (internal + Yosys + CVA6 equivalence)"
	@echo "  test-cva6  - Run the CVA6 per-module equivalence suite (vendored CVA6 RTL)"
	@echo "  test-yosys - Run Yosys tests only"
	@echo "  frontends  - Build sv2v for the 4-frontend matrix (slang is built into yosys)"
	@echo "  test-matrix - Run the 4-frontend regression matrix (internal tests)"
	@echo "  clean      - Remove ALL build artifacts (build dirs, out/, in-tree Yosys/abc objects)"
	@echo "  install    - Install the plugin"
	@echo "  help       - Show this help message"
