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

# Add OR-Tools as a subdirectory
add_subdirectory(or-tools EXCLUDE_FROM_ALL)

# Now build our FFI wrapper library
add_library(tsp_ffi SHARED
  tsp_ffi.cc
  tsp_ffi.h
  gurobi_stubs.cc
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
