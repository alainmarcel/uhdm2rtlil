#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "uhdm::capnp" for configuration "Release"
set_property(TARGET uhdm::capnp APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(uhdm::capnp PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libcapnp.a"
  )

list(APPEND _IMPORT_CHECK_TARGETS uhdm::capnp )
list(APPEND _IMPORT_CHECK_FILES_FOR_uhdm::capnp "${_IMPORT_PREFIX}/lib/libcapnp.a" )

# Import target "uhdm::kj" for configuration "Release"
set_property(TARGET uhdm::kj APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(uhdm::kj PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libkj.a"
  )

list(APPEND _IMPORT_CHECK_TARGETS uhdm::kj )
list(APPEND _IMPORT_CHECK_FILES_FOR_uhdm::kj "${_IMPORT_PREFIX}/lib/libkj.a" )

# Import target "uhdm::uhdm" for configuration "Release"
set_property(TARGET uhdm::uhdm APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(uhdm::uhdm PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libuhdm.a"
  )

list(APPEND _IMPORT_CHECK_TARGETS uhdm::uhdm )
list(APPEND _IMPORT_CHECK_FILES_FOR_uhdm::uhdm "${_IMPORT_PREFIX}/lib/libuhdm.a" )

# Import target "uhdm::uhdm-cmp" for configuration "Release"
set_property(TARGET uhdm::uhdm-cmp APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(uhdm::uhdm-cmp PROPERTIES
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/bin/uhdm-cmp"
  )

list(APPEND _IMPORT_CHECK_TARGETS uhdm::uhdm-cmp )
list(APPEND _IMPORT_CHECK_FILES_FOR_uhdm::uhdm-cmp "${_IMPORT_PREFIX}/bin/uhdm-cmp" )

# Import target "uhdm::uhdm-dump" for configuration "Release"
set_property(TARGET uhdm::uhdm-dump APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(uhdm::uhdm-dump PROPERTIES
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/bin/uhdm-dump"
  )

list(APPEND _IMPORT_CHECK_TARGETS uhdm::uhdm-dump )
list(APPEND _IMPORT_CHECK_FILES_FOR_uhdm::uhdm-dump "${_IMPORT_PREFIX}/bin/uhdm-dump" )

# Import target "uhdm::uhdm-hier" for configuration "Release"
set_property(TARGET uhdm::uhdm-hier APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(uhdm::uhdm-hier PROPERTIES
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/bin/uhdm-hier"
  )

list(APPEND _IMPORT_CHECK_TARGETS uhdm::uhdm-hier )
list(APPEND _IMPORT_CHECK_FILES_FOR_uhdm::uhdm-hier "${_IMPORT_PREFIX}/bin/uhdm-hier" )

# Import target "uhdm::uhdm-lint" for configuration "Release"
set_property(TARGET uhdm::uhdm-lint APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(uhdm::uhdm-lint PROPERTIES
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/bin/uhdm-lint"
  )

list(APPEND _IMPORT_CHECK_TARGETS uhdm::uhdm-lint )
list(APPEND _IMPORT_CHECK_FILES_FOR_uhdm::uhdm-lint "${_IMPORT_PREFIX}/bin/uhdm-lint" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
