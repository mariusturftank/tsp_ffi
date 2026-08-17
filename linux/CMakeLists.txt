# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "tsp_ffi")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "tsp_ffi_plugin")

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "tsp_ffi_plugin.cc"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

# Collect all OR-Tools libraries to bundle
file(GLOB ABSL_LIBS "${CMAKE_CURRENT_SOURCE_DIR}/../src/build/lib/libabsl_*.so.*")
file(GLOB PROTOBUF_LIBS "${CMAKE_CURRENT_SOURCE_DIR}/../src/build/lib/libprotobuf.so.*")
file(GLOB RE2_LIBS "${CMAKE_CURRENT_SOURCE_DIR}/../src/build/lib/libre2.so.*")
file(GLOB Z_LIBS "${CMAKE_CURRENT_SOURCE_DIR}/../src/build/lib/libz.so.*")
file(GLOB BZ2_LIBS "${CMAKE_CURRENT_SOURCE_DIR}/../src/build/lib/libbz2.so.*")

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(tsp_ffi_bundled_libraries
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/build/libtsp_ffi.so"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/build/lib/libortools.so.9"
  ${ABSL_LIBS}
  ${PROTOBUF_LIBS}
  ${RE2_LIBS}
  ${Z_LIBS}
  ${BZ2_LIBS}
  PARENT_SCOPE
)
