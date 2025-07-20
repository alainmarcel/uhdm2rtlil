#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "surelog::surelog-bin" for configuration "Release"
set_property(TARGET surelog::surelog-bin APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(surelog::surelog-bin PROPERTIES
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/bin/surelog"
  )

list(APPEND _IMPORT_CHECK_TARGETS surelog::surelog-bin )
list(APPEND _IMPORT_CHECK_FILES_FOR_surelog::surelog-bin "${_IMPORT_PREFIX}/bin/surelog" )

# Import target "surelog::roundtrip" for configuration "Release"
set_property(TARGET surelog::roundtrip APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(surelog::roundtrip PROPERTIES
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/bin/roundtrip"
  )

list(APPEND _IMPORT_CHECK_TARGETS surelog::roundtrip )
list(APPEND _IMPORT_CHECK_FILES_FOR_surelog::roundtrip "${_IMPORT_PREFIX}/bin/roundtrip" )

# Import target "surelog::surelog" for configuration "Release"
set_property(TARGET surelog::surelog APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(surelog::surelog PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libsurelog.a"
  )

list(APPEND _IMPORT_CHECK_TARGETS surelog::surelog )
list(APPEND _IMPORT_CHECK_FILES_FOR_surelog::surelog "${_IMPORT_PREFIX}/lib/libsurelog.a" )

# Import target "surelog::antlr4_static" for configuration "Release"
set_property(TARGET surelog::antlr4_static APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(surelog::antlr4_static PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libantlr4-runtime.a"
  )

list(APPEND _IMPORT_CHECK_TARGETS surelog::antlr4_static )
list(APPEND _IMPORT_CHECK_FILES_FOR_surelog::antlr4_static "${_IMPORT_PREFIX}/lib/libantlr4-runtime.a" )

# Import target "surelog::capnp" for configuration "Release"
set_property(TARGET surelog::capnp APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(surelog::capnp PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libcapnp.a"
  )

list(APPEND _IMPORT_CHECK_TARGETS surelog::capnp )
list(APPEND _IMPORT_CHECK_FILES_FOR_surelog::capnp "${_IMPORT_PREFIX}/lib/libcapnp.a" )

# Import target "surelog::kj" for configuration "Release"
set_property(TARGET surelog::kj APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(surelog::kj PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libkj.a"
  )

list(APPEND _IMPORT_CHECK_TARGETS surelog::kj )
list(APPEND _IMPORT_CHECK_FILES_FOR_surelog::kj "${_IMPORT_PREFIX}/lib/libkj.a" )

# Import target "surelog::uhdm" for configuration "Release"
set_property(TARGET surelog::uhdm APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(surelog::uhdm PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libuhdm.a"
  )

list(APPEND _IMPORT_CHECK_TARGETS surelog::uhdm )
list(APPEND _IMPORT_CHECK_FILES_FOR_surelog::uhdm "${_IMPORT_PREFIX}/lib/libuhdm.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
