# Top-level Makefile for uhdm2rtlil
.PHONY: all debug test clean

# Default target
all:
	@echo "Building uhdm2rtlil in Release mode..."
	@mkdir -p build
	@cd build && cmake -DCMAKE_BUILD_TYPE=Release .. && make -j$(nproc)

# Debug build target
debug:
	@echo "Building uhdm2rtlil in Debug mode..."
	@mkdir -p build-debug
	@cd build-debug && cmake -DCMAKE_BUILD_TYPE=Debug .. && make -j$(nproc)

# Test target
test: all
	@echo "Running tests..."
	@cd build && make test

# Create release build directory and configure
build:
	@echo "Configuring Release build..."
	@mkdir -p build
	@cd build && cmake -DCMAKE_BUILD_TYPE=Release ..

# Create debug build directory and configure
build-debug:
	@echo "Configuring Debug build..."
	@mkdir -p build-debug
	@cd build-debug && cmake -DCMAKE_BUILD_TYPE=Debug ..

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf build build-debug

# Install target
install: all
	@echo "Installing uhdm2rtlil..."
	cd build && make install

# Help target
help:
	@echo "Available targets:"
	@echo "  all      - Build in Release mode (default)"
	@echo "  debug    - Build in Debug mode"
	@echo "  test     - Run tests"
	@echo "  clean    - Clean build artifacts"
	@echo "  install  - Install the built binary"
	@echo "  help     - Show this help message"