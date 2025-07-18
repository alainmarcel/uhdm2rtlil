cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

project(uhdm2rtlil VERSION 1.0)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Detect build type, fallback to release
if(NOT CMAKE_BUILD_TYPE)
  message(WARNING "Build type not set, falling back to Release mode.
 To specify build type use:
 -DCMAKE_BUILD_TYPE=<mode> where <mode> is Debug or Release.")
  set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Choose the type of build, options are: Debug Release." FORCE)
endif()

# Build Surelog using CMake
add_subdirectory(third_party/Surelog)

# Custom target to build Yosys using its Makefile
add_custom_target(yosys_build ALL
    COMMAND $(MAKE) -C ${CMAKE_CURRENT_SOURCE_DIR}/third_party/yosys config-gcc
    COMMAND $(MAKE) -C ${CMAKE_CURRENT_SOURCE_DIR}/third_party/yosys
    COMMENT "Building Yosys using Makefile"
    VERBATIM
)

# Build our main frontend
set(UHDM_FRONTEND_SOURCES
    src/frontends/uhdm/uhdm2rtlil.cpp
    src/frontends/uhdm/module.cpp
    src/frontends/uhdm/expression.cpp
    src/frontends/uhdm/process.cpp
    src/frontends/uhdm/clocking.cpp
    src/frontends/uhdm/memory.cpp
)

add_executable(uhdm2rtlil ${UHDM_FRONTEND_SOURCES})

# Add dependency on both components
add_dependencies(uhdm2rtlil surelog yosys_build)

# Link against Surelog library
target_link_libraries(uhdm2rtlil surelog)

# Include directories
target_include_directories(uhdm2rtlil PRIVATE 
    src/frontends/uhdm
    third_party/Surelog/include
    third_party/yosys/kernel
    third_party/yosys/frontends
    third_party/yosys/backends
    third_party/yosys
)

# Installation
install(TARGETS uhdm2rtlil DESTINATION bin)