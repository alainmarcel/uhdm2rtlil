cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

project(uhdm2rtlil VERSION 1.86)

# Set C++ standard.  Keep the TREE at C++17: third_party/Surelog (and its
# bundled antlr4) is added below via add_subdirectory and does NOT build under
# C++20 here — antlr4's toolchain rejects `-std=c++20`.  Yosys v0.66 itself
# requires C++20, but only OUR plugin includes Yosys headers, so C++20 is
# scoped to the `uhdm2rtlil` target (see set_target_properties below); the
# extract_clocks_resets plugin is built via `yosys-config --build`, which
# supplies Yosys's own C++20 flags.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(INSTALL_DIR ${PROJECT_SOURCE_DIR}/out/current)

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

if(UHDM2RTLIL_USE_HOST_YOSYS)
  message("Using HOST YOSYS")
  find_package(yosys)
  get_target_property(YOSYS_INCLUDE_DIR yosys::yosys
                      INTERFACE_INCLUDE_DIRECTORIES)
else()
  if(DEFINED YOSYS_CONFIG AND NOT YOSYS_CONFIG STREQUAL "")
    # Use the Yosys custom location given
    set(YOSYS_INCLUDE_DIR ${YOSYS_PATH})
    message("Using YOSYS from ${YOSYS_PATH}")
  else()
    message("Using Vendored YOSYS")
    set(VENDORED_YOSYS 1)
    set(Yosys_BuildTests
        OFF
        CACHE INTERNAL "")
    set(YOSYS_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/third_party/yosys)
    # yosys-config is installed into the prefix by the CMake build/install.
    set(YOSYS_CONFIG ${INSTALL_DIR}/bin/yosys-config)
    set(YOSYS_SRC_DIR ${PROJECT_SOURCE_DIR}/third_party/yosys)
    set(YOSYS_BUILD_DIR ${YOSYS_SRC_DIR}/build)
    include(ProcessorCount)
    ProcessorCount(YOSYS_NPROC)
    if(YOSYS_NPROC EQUAL 0)
      set(YOSYS_NPROC 4)
    endif()
    # Build Vendored Yosys if not provided by upper cmake.
    #
    # Yosys v0.67 is CMake-only — the old top-level Makefile we used to invoke
    # (`make CONFIG=gcc PREFIX=… install`) was removed.  v0.67 also vendors the
    # sv-elab SystemVerilog frontend under frontends/slang; building it in
    # (YOSYS_ENABLE_SLANG=ON) makes `read_slang` part of the yosys binary so the
    # 4-frontend matrix's slang column uses the integrated frontend instead of a
    # standalone povik/yosys-slang plugin.  Slang compiles the bundled
    # MikePopoloski/slang library, which needs CMake >= 3.28 and gcc >= 11 — turn
    # it OFF (-DUHDM2RTLIL_ENABLE_SLANG=OFF) on hosts with an older toolchain.
    option(UHDM2RTLIL_ENABLE_SLANG
           "Build the sv-elab (read_slang) frontend into the vendored Yosys" ON)
    add_custom_target(yosys DEPENDS ${INSTALL_DIR}/bin/yosys)
    add_custom_command(
      OUTPUT ${INSTALL_DIR}/bin/yosys
      COMMAND ${CMAKE_COMMAND} -E echo "Compiling Yosys v0.67 via CMake, slang=${UHDM2RTLIL_ENABLE_SLANG}"
      COMMAND ${CMAKE_COMMAND} -B ${YOSYS_BUILD_DIR} -S ${YOSYS_SRC_DIR}
              -DCMAKE_BUILD_TYPE=Release
              -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}
              -DYOSYS_ENABLE_SLANG=${UHDM2RTLIL_ENABLE_SLANG}
      COMMAND ${CMAKE_COMMAND} --build ${YOSYS_BUILD_DIR} --parallel ${YOSYS_NPROC}
      COMMAND ${CMAKE_COMMAND} --install ${YOSYS_BUILD_DIR}
      WORKING_DIRECTORY "${YOSYS_SRC_DIR}"
      DEPENDS ${YOSYS_SRC_DIR}/kernel/yosys.cc)
  endif()
endif()


# Build our main frontend
set(UHDM_FRONTEND_SOURCES
    src/frontends/uhdm/uhdm2rtlil.cpp
    src/frontends/uhdm/module.cpp
    src/frontends/uhdm/expression.cpp
    src/frontends/uhdm/functions.cpp
    src/frontends/uhdm/process.cpp
    src/frontends/uhdm/process_helper.cpp
    src/frontends/uhdm/clocking.cpp
    src/frontends/uhdm/memory.cpp
    src/frontends/uhdm/memory_analysis.cpp
    src/frontends/uhdm/ref_module.cpp
    src/frontends/uhdm/primitives.cpp
    src/frontends/uhdm/package.cpp
    src/frontends/uhdm/interface.cpp
    src/frontends/uhdm/interpreter.cpp
)

# Build as a shared library (Yosys plugin)
add_library(uhdm2rtlil SHARED ${UHDM_FRONTEND_SOURCES})

# Add dependency on both components
add_dependencies(uhdm2rtlil surelog yosys)

# Link against Surelog library only
target_link_libraries(uhdm2rtlil surelog)

# Include directories.
#
# Use the INSTALLED Yosys headers (out/current/share/yosys/include), not the
# source tree: v0.67's CMake build generates kernel/yosys_config.h (included by
# kernel/yosys_common.h) into its build dir, and `cmake --install` lays the full
# header set — generated + static — under share/yosys/include with the usual
# kernel/ … prefixes.  The source tree alone is missing yosys_config.h.  The
# `yosys` target (an add_dependencies below) installs these before this compiles.
target_include_directories(uhdm2rtlil PRIVATE
    src/frontends/uhdm
    third_party/Surelog/include
    ${INSTALL_DIR}/share/yosys/include
)

# Add compiler warning flags - treat all warnings as errors
target_compile_options(uhdm2rtlil PRIVATE
    -Wall
    -Werror               # Treat all warnings as errors
    -Wno-unused-parameter # Yosys headers have many unused parameters
    -Wno-sign-compare     # Common in Yosys code
    -Wno-array-bounds     # False positive in Yosys io.h header
    # GCC 15 (Ubuntu 25.10) emits false-positive -Wmaybe-uninitialized inside
    # the inlined std::vector move-constructor of RTLIL::SigChunk/SigSpec (e.g.
    # `RTLIL::SigSig(RTLIL::SigSpec(), RTLIL::SigSpec())` in functions.cpp); the
    # code is correct, the warning is a known compiler analysis artefact, so
    # don't let -Werror reject it.  (issue #335)
    -Wno-maybe-uninitialized
)

# Add required Yosys defines.
#
# Only `_YOSYS_` here.  v0.67's generated kernel/yosys_config.h (pulled in via
# kernel/yosys.h) now defines the YOSYS_ENABLE_* feature macros itself — valueless
# `#define YOSYS_ENABLE_PLUGINS` etc. reflecting how the yosys binary was actually
# built — so defining them again here as `=1` triggers -Werror macro-redefinition.
# Matches what `yosys-config --cxxflags` passes for an external plugin.
target_compile_definitions(uhdm2rtlil PRIVATE
    _YOSYS_
)

# Set plugin properties
set_target_properties(uhdm2rtlil PROPERTIES
    PREFIX ""
    SUFFIX ".so"
    # Yosys v0.66 headers hard-require C++20; scope it to this target only so
    # the C++17 Surelog/antlr4 subtree keeps building.
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED ON
)

# Link additional system libraries needed for the plugin
target_link_libraries(uhdm2rtlil dl pthread)

# Installation
install(TARGETS uhdm2rtlil DESTINATION ${INSTALL_DIR}/share/yosys/plugins)

# Auxiliary Yosys plugin: extract_clocks_resets.  Used by
# test/test_sim_equivalence.py to drive a Verilator co-simulation
# testbench against the synthesized netlist.  Built via `yosys-config
# --build` so we don't have to replicate the Yosys include / link
# flags here.
set(EXTRACT_CR_SRC
    ${CMAKE_CURRENT_SOURCE_DIR}/src/plugins/extract_clocks_resets/extract_clocks_resets.cc)
set(EXTRACT_CR_SO ${CMAKE_CURRENT_BINARY_DIR}/extract_clocks_resets.so)
# yosys-config lives in the in-tree Yosys checkout (it's a shell script
# that knows where its own include/lib live) — use that directly.
set(YOSYS_CONFIG ${CMAKE_CURRENT_SOURCE_DIR}/third_party/yosys/yosys-config)
add_custom_command(
    OUTPUT ${EXTRACT_CR_SO}
    COMMAND ${YOSYS_CONFIG} --build ${EXTRACT_CR_SO} ${EXTRACT_CR_SRC}
    DEPENDS ${EXTRACT_CR_SRC} yosys
    COMMENT "Building extract_clocks_resets Yosys plugin"
)
add_custom_target(extract_clocks_resets ALL DEPENDS ${EXTRACT_CR_SO})

# Add test target
add_custom_target(test
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/test/run_all_tests.sh
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/test
    COMMENT "Running all UHDM frontend tests"
    DEPENDS uhdm2rtlil
)
