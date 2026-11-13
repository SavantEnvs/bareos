# Loaded by build.sh through -DCMAKE_PROJECT_INCLUDE (once per project() call): adds the fuzz
# harnesses to upstream's own CMake build after all of upstream's targets exist, so no upstream
# file has to change.
get_property(mh_done GLOBAL PROPERTY MH_HARNESSES_DEFERRED)
if(NOT mh_done AND CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  set_property(GLOBAL PROPERTY MH_HARNESSES_DEFERRED TRUE)
  cmake_language(EVAL CODE "
    cmake_language(DEFER DIRECTORY \"\${CMAKE_SOURCE_DIR}\" CALL include
                   \"${CMAKE_CURRENT_LIST_DIR}/harnesses.cmake\")
  ")
endif()
