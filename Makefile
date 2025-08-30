# Top-level Makefile for uhdm2rtlil
.PHONY: all debug test test-all test-yosys clean plugin install help

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

# Test target - runs our internal tests only
test: all
	@echo "Running tests..."
	@cd build && make test

# Test all target - runs internal tests + all Yosys tests
test-all: all
	@echo "Running all tests (internal + Yosys)..."
	@cd test && ./run_all_tests.sh --all

# Test Yosys target - runs only Yosys tests
test-yosys: all preprocess-yosys-tests
	@echo "Running Yosys tests..."
	@cd test && ./run_all_tests.sh --yosys

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

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf build build-debug

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
	@echo "  test       - Run internal tests only"
	@echo "  test-all   - Run all tests (internal + Yosys)"
	@echo "  test-yosys - Run Yosys tests only"
	@echo "  clean      - Clean build artifacts"
	@echo "  install    - Install the plugin"
	@echo "  help       - Show this help message"
