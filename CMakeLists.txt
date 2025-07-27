cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

project(uhdm2rtlil VERSION 1.0)

# Set C++ standard
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
    set(YOSYS_CONFIG ${PROJECT_SOURCE_DIR}/third_party/yosys/yosys-config)
    # Build Vendored Yosys if not provided by upper cmake
    add_custom_target(yosys DEPENDS ${INSTALL_DIR}/bin/yosys)
    add_custom_command(
      OUTPUT ${INSTALL_DIR}/bin/yosys
      COMMAND echo "       Compiling Yosys"
      COMMAND make CONFIG=gcc PREFIX=${INSTALL_DIR} ENABLE_DEBUG=1 install -j4
      WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}/third_party/yosys"
      DEPENDS ${PROJECT_SOURCE_DIR}/third_party/yosys/kernel/yosys.cc)
  endif()
endif()


# Build our main frontend
set(UHDM_FRONTEND_SOURCES
    src/frontends/uhdm/uhdm2rtlil.cpp
    src/frontends/uhdm/module.cpp
    src/frontends/uhdm/expression.cpp
    src/frontends/uhdm/process.cpp
    src/frontends/uhdm/clocking.cpp
    src/frontends/uhdm/memory.cpp
    src/frontends/uhdm/memory_analysis.cpp
    src/frontends/uhdm/ref_module.cpp
    src/frontends/uhdm/primitives.cpp
    src/frontends/uhdm/package.cpp
)

# Build as a shared library (Yosys plugin)
add_library(uhdm2rtlil SHARED ${UHDM_FRONTEND_SOURCES})

# Add dependency on both components
add_dependencies(uhdm2rtlil surelog yosys)

# Link against Surelog library only
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

# Add required Yosys defines
target_compile_definitions(uhdm2rtlil PRIVATE
    _YOSYS_
    YOSYS_ENABLE_TCL=1
    YOSYS_ENABLE_ABC=1
    YOSYS_ENABLE_GLOB=1
    YOSYS_ENABLE_PLUGINS=1
    YOSYS_ENABLE_READLINE=1
    YOSYS_ENABLE_COVER=1
    YOSYS_ENABLE_ZLIB=1
)

# Set plugin properties
set_target_properties(uhdm2rtlil PROPERTIES
    PREFIX ""
    SUFFIX ".so"
)

# Link additional system libraries needed for the plugin
target_link_libraries(uhdm2rtlil dl pthread)

# Installation
install(TARGETS uhdm2rtlil DESTINATION ${INSTALL_DIR}/share/yosys/plugins)
