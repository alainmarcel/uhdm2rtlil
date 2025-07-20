# Install script for directory: /home/alain/uhdm2rtlil/third_party/Surelog

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/usr/local")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Install shared libraries without execute permission?
if(NOT DEFINED CMAKE_INSTALL_SO_NO_EXE)
  set(CMAKE_INSTALL_SO_NO_EXE "1")
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

# Set default install directory permissions.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/usr/bin/objdump")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("/home/alain/uhdm2rtlil/build/third_party/Surelog/third_party/antlr4/runtime/Cpp/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("/home/alain/uhdm2rtlil/build/third_party/Surelog/third_party/UHDM/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("/home/alain/uhdm2rtlil/build/third_party/Surelog/third_party/json/cmake_install.cmake")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/surelog" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/surelog")
    file(RPATH_CHECK
         FILE "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/surelog"
         RPATH "")
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE EXECUTABLE FILES "/home/alain/uhdm2rtlil/build/third_party/Surelog/bin/surelog")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/surelog" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/surelog")
    file(RPATH_CHANGE
         FILE "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/surelog"
         OLD_RPATH "/usr/local/lib:"
         NEW_RPATH "")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/usr/bin/strip" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/surelog")
    endif()
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/roundtrip" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/roundtrip")
    file(RPATH_CHECK
         FILE "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/roundtrip"
         RPATH "")
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE EXECUTABLE FILES "/home/alain/uhdm2rtlil/build/third_party/Surelog/bin/roundtrip")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/roundtrip" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/roundtrip")
    file(RPATH_CHANGE
         FILE "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/roundtrip"
         OLD_RPATH "/usr/local/lib:"
         NEW_RPATH "")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/usr/bin/strip" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/roundtrip")
    endif()
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/home/alain/uhdm2rtlil/build/third_party/Surelog/lib/libsurelog.a")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/Surelog" TYPE FILE FILES "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/surelog.h")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/home/alain/uhdm2rtlil/build/third_party/Surelog/third_party/antlr4/runtime/Cpp/runtime/libantlr4-runtime.a")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/home/alain/uhdm2rtlil/build/third_party/Surelog/third_party/UHDM/third_party/capnproto/c++/src/capnp/libcapnp.a")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/home/alain/uhdm2rtlil/build/third_party/Surelog/third_party/UHDM/third_party/capnproto/c++/src/kj/libkj.a")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/home/alain/uhdm2rtlil/build/third_party/Surelog/third_party/UHDM/lib/libuhdm.a")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/uhdm" TYPE FILE FILES "/home/alain/uhdm2rtlil/build/third_party/Surelog/third_party/UHDM/generated/uhdm/uhdm.h")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/share/surelog" TYPE DIRECTORY FILES "/home/alain/uhdm2rtlil/build/third_party/Surelog/bin/pkg")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/Surelog" TYPE FILE FILES
    "/home/alain/uhdm2rtlil/build/third_party/Surelog/generated/include/Surelog/config.h"
    "/home/alain/uhdm2rtlil/build/third_party/Surelog/generated/include/Surelog/surelog-version.h"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/Surelog/CommandLine" TYPE FILE FILES "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/CommandLine/CommandLineParser.h")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/Surelog/SourceCompile" TYPE FILE FILES
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/SourceCompile/SymbolTable.h"
    "/home/alain/uhdm2rtlil/build/third_party/Surelog/generated/include/Surelog/SourceCompile/ParseTreeListener.h"
    "/home/alain/uhdm2rtlil/build/third_party/Surelog/generated/include/Surelog/SourceCompile/ParseTreeTraceListener.h"
    "/home/alain/uhdm2rtlil/build/third_party/Surelog/generated/include/Surelog/SourceCompile/VObjectTypes.h"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/Surelog/ErrorReporting" TYPE FILE FILES
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/ErrorReporting/Location.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/ErrorReporting/Error.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/ErrorReporting/ErrorDefinition.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/ErrorReporting/ErrorContainer.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/ErrorReporting/LogListener.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/ErrorReporting/Report.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/ErrorReporting/Waiver.h"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/Surelog/API" TYPE FILE FILES
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/API/PythonAPI.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/API/SLAPI.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/API/Surelog.h"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/Surelog/Common" TYPE FILE FILES
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Common/ClockingBlockHolder.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Common/Containers.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Common/FileSystem.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Common/NodeId.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Common/PathId.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Common/PlatformFileSystem.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Common/PortNetHolder.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Common/RTTI.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Common/SymbolId.h"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/Surelog/DesignCompile" TYPE FILE FILES "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/DesignCompile/CompileHelper.h")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/Surelog/Design" TYPE FILE FILES
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/ClockingBlock.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/Design.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/BindStmt.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/Instance.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/Signal.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/ValuedComponentI.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/DataType.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/Enum.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/Struct.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/ModuleDefinition.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/Statement.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/VObject.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/DefParam.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/FileCNodeId.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/ModuleInstance.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/Task.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/LetStmt.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/DesignComponent.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/FileContent.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/Parameter.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/ParamAssign.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/TfPortItem.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/DesignElement.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/Netlist.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/Function.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/Scope.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/TimeInfo.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/ModPort.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/Union.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/SimpleType.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Design/DummyType.h"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/Surelog/Testbench" TYPE FILE FILES
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Testbench/ClassDefinition.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Testbench/CoverGroupDefinition.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Testbench/Property.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Testbench/Variable.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Testbench/ClassObject.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Testbench/FunctionMethod.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Testbench/TaskMethod.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Testbench/Constraint.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Testbench/Program.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Testbench/TypeDef.h"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/Surelog/Package" TYPE FILE FILES "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Package/Package.h")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/Surelog/Library" TYPE FILE FILES
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Library/Library.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Library/LibrarySet.h"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/Surelog/Config" TYPE FILE FILES
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Config/Config.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Config/ConfigSet.h"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/Surelog/Expression" TYPE FILE FILES
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Expression/ExprBuilder.h"
    "/home/alain/uhdm2rtlil/third_party/Surelog/include/Surelog/Expression/Value.h"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/Surelog/SurelogTargets.cmake")
    file(DIFFERENT EXPORT_FILE_CHANGED FILES
         "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/Surelog/SurelogTargets.cmake"
         "/home/alain/uhdm2rtlil/build/third_party/Surelog/CMakeFiles/Export/lib/cmake/Surelog/SurelogTargets.cmake")
    if(EXPORT_FILE_CHANGED)
      file(GLOB OLD_CONFIG_FILES "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/Surelog/SurelogTargets-*.cmake")
      if(OLD_CONFIG_FILES)
        message(STATUS "Old export file \"$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/Surelog/SurelogTargets.cmake\" will be replaced.  Removing files [${OLD_CONFIG_FILES}].")
        file(REMOVE ${OLD_CONFIG_FILES})
      endif()
    endif()
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/Surelog" TYPE FILE FILES "/home/alain/uhdm2rtlil/build/third_party/Surelog/CMakeFiles/Export/lib/cmake/Surelog/SurelogTargets.cmake")
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/Surelog" TYPE FILE FILES "/home/alain/uhdm2rtlil/build/third_party/Surelog/CMakeFiles/Export/lib/cmake/Surelog/SurelogTargets-release.cmake")
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/Surelog" TYPE FILE FILES
    "/home/alain/uhdm2rtlil/build/third_party/Surelog/SurelogConfig.cmake"
    "/home/alain/uhdm2rtlil/build/third_party/Surelog/SurelogConfigVersion.cmake"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/pkgconfig" TYPE FILE FILES "/home/alain/uhdm2rtlil/build/third_party/Surelog/Surelog.pc")
endif()

