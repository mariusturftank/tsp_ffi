# The Flutter tooling requires that developers have CMake 3.10 or later
# However OR-Tools requires 3.20, so we use that
cmake_minimum_required(VERSION 3.20)

project(tsp_ffi_library VERSION 0.0.1 LANGUAGES CXX C)

# Set C++ standard to match OR-Tools
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Configure OR-Tools build options - we only need the C++ library, no samples/examples
set(BUILD_CXX ON CACHE BOOL "Build C++ library" FORCE)
set(BUILD_SAMPLES OFF CACHE BOOL "Build samples" FORCE)
set(BUILD_EXAMPLES OFF CACHE BOOL "Build examples" FORCE)
set(BUILD_PYTHON OFF CACHE BOOL "Build Python" FORCE)
set(BUILD_JAVA OFF CACHE BOOL "Build Java" FORCE)
set(BUILD_DOTNET OFF CACHE BOOL "Build .NET" FORCE)
set(BUILD_FLATZINC OFF CACHE BOOL "Build Flatzinc" FORCE)
set(BUILD_MATH_OPT OFF CACHE BOOL "Build MathOpt" FORCE)

# Disable optional third-party solvers
set(USE_COINOR OFF CACHE BOOL "Use COIN-OR" FORCE)
set(USE_GLPK OFF CACHE BOOL "Use GLPK" FORCE)
set(USE_HIGHS OFF CACHE BOOL "Use HiGHS" FORCE)
set(USE_PDLP OFF CACHE BOOL "Use PDLP" FORCE)
set(USE_SCIP OFF CACHE BOOL "Use SCIP" FORCE)
set(USE_CPLEX OFF CACHE BOOL "Use CPLEX" FORCE)
set(USE_XPRESS OFF CACHE BOOL "Use XPRESS" FORCE)
set(USE_GUROBI OFF CACHE BOOL "Use GUROBI" FORCE)

# Build dependencies from source for consistent versions
set(BUILD_DEPS ON CACHE BOOL "Build dependencies" FORCE)

# Build OR-Tools and all dependencies as static libraries so everything
# gets linked into the single libtsp_ffi.so — avoids needing to ship
# libortools.so, libbz2.so, etc. separately (Android can't find them).
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build static libraries" FORCE)

# bzip2 uses its own flags instead of BUILD_SHARED_LIBS
set(ENABLE_SHARED_LIB OFF CACHE BOOL "No shared bzip2" FORCE)
set(ENABLE_STATIC_LIB ON  CACHE BOOL "Static bzip2" FORCE)
set(ENABLE_LIB_ONLY   ON  CACHE BOOL "Lib only bzip2" FORCE)
set(ENABLE_APP         OFF CACHE BOOL "No bzip2 apps" FORCE)
set(ENABLE_EXAMPLES    OFF CACHE BOOL "No bzip2 examples" FORCE)

# protobuf: force static
set(protobuf_BUILD_SHARED_LIBS OFF CACHE BOOL "Static protobuf" FORCE)

set(ORTOOLS_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/or-tools")
if(NOT EXISTS "${ORTOOLS_SOURCE_DIR}/CMakeLists.txt")
  message(FATAL_ERROR
    "Vendored OR-Tools source not found at ${ORTOOLS_SOURCE_DIR}. "
    "Populate src/third_party/or-tools with a pinned source snapshot."
  )
endif()

# When cross-compiling (e.g. for Android), protoc must run on the host.
# OR-Tools' built-in host_tools mechanism uses add_custom_command which
# Ninja cannot track as a file-level dependency.  Work around this by
# building host protoc at *configure* time and passing it in.
if(CMAKE_CROSSCOMPILING AND NOT OR_TOOLS_PROTOC_EXECUTABLE)
  set(_HOST_PROTOC_DIR "${CMAKE_CURRENT_BINARY_DIR}/_host_protoc")
  set(_HOST_PROTOC     "${_HOST_PROTOC_DIR}/bin/protoc")

  if(NOT EXISTS "${_HOST_PROTOC}")
    message(STATUS "Building host protoc for cross-compilation...")

    file(RELATIVE_PATH _PATCHES_REL
      "${_HOST_PROTOC_DIR}"
      "${ORTOOLS_SOURCE_DIR}/patches")

    set(PATCHES_PATH "${_PATCHES_REL}")
    configure_file(
      "${ORTOOLS_SOURCE_DIR}/cmake/host.CMakeLists.txt"
      "${_HOST_PROTOC_DIR}/CMakeLists.txt"
      @ONLY)

    execute_process(
      COMMAND ${CMAKE_COMMAND}
        -S . -B build
        -DCMAKE_BUILD_TYPE=Release
        "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY:PATH=${_HOST_PROTOC_DIR}/bin"
      WORKING_DIRECTORY "${_HOST_PROTOC_DIR}"
      RESULT_VARIABLE _host_cfg_result)
    if(_host_cfg_result)
      message(FATAL_ERROR "Host protoc configure step failed (${_host_cfg_result})")
    endif()

    execute_process(
      COMMAND ${CMAKE_COMMAND} --build build --config Release
      WORKING_DIRECTORY "${_HOST_PROTOC_DIR}"
      RESULT_VARIABLE _host_build_result)
    if(_host_build_result)
      message(FATAL_ERROR "Host protoc build step failed (${_host_build_result})")
    endif()
  endif()

  set(OR_TOOLS_PROTOC_EXECUTABLE "${_HOST_PROTOC}" CACHE STRING
    "Path to host protoc for cross-compilation" FORCE)
  message(STATUS "Using host protoc: ${OR_TOOLS_PROTOC_EXECUTABLE}")
endif()

# Add OR-Tools as a subdirectory
add_subdirectory(${ORTOOLS_SOURCE_DIR} ${CMAKE_CURRENT_BINARY_DIR}/or-tools EXCLUDE_FROM_ALL)

# Gurobi stubs must be linked into ortools itself (not just tsp_ffi),
# because gurobi_interface.cc and gurobi_proto_solver.cc reference these
# symbols when building libortools.so.
target_sources(ortools PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/gurobi_stubs.cc
)

# Now build our FFI wrapper library
add_library(tsp_ffi SHARED
  tsp_ffi.cc
  tsp_ffi.h
)

set_target_properties(tsp_ffi PROPERTIES
  PUBLIC_HEADER "tsp_ffi.h"
  OUTPUT_NAME "tsp_ffi"
  CXX_STANDARD 17
  CXX_STANDARD_REQUIRED ON
  POSITION_INDEPENDENT_CODE ON
)

# Link against OR-Tools constraint solver
target_link_libraries(tsp_ffi PRIVATE
  ortools::ortools
)

target_include_directories(tsp_ffi PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}
)

target_compile_definitions(tsp_ffi PUBLIC 
  DART_SHARED_LIB
)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(tsp_ffi PRIVATE "-Wl,-z,max-page-size=16384")
endif()
