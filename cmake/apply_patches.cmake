# Apply every *.patch in PATCH_DIR to the git tree TARGET_DIR, idempotently:
# a patch that already reverse-applies is skipped, one that applies is applied,
# anything else is a hard error (the patched tree moved: refresh or drop it).
# Invoked with: cmake -DPATCH_DIR=... -DTARGET_DIR=... -P apply_patches.cmake
file(GLOB _patches "${PATCH_DIR}/*.patch")
list(SORT _patches)
foreach(p ${_patches})
  execute_process(COMMAND git apply --reverse --check "${p}"
                  WORKING_DIRECTORY "${TARGET_DIR}" RESULT_VARIABLE rev
                  OUTPUT_QUIET ERROR_QUIET)
  if(rev EQUAL 0)
    message(STATUS "patch already applied: ${p}")
    continue()
  endif()
  execute_process(COMMAND git apply "${p}"
                  WORKING_DIRECTORY "${TARGET_DIR}" RESULT_VARIABLE fwd)
  if(NOT fwd EQUAL 0)
    message(FATAL_ERROR "patch does not apply to ${TARGET_DIR}: ${p}")
  endif()
  message(STATUS "patch applied: ${p}")
endforeach()
