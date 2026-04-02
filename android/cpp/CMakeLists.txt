cmake_minimum_required(VERSION 3.19)

project(LlamaWrapper C CXX)

# ============================================================
# C++ Standard
# ============================================================

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# ============================================================
# Include llama.cpp
# ============================================================

# llama.cpp must be in android/cpp/llama.cpp/
# If you don't have it yet:
#   cd android/cpp/
#   git clone https://github.com/ggerganov/llama.cpp.git

if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp/CMakeLists.txt")
  message(FATAL_ERROR
    "───────────────────────────────────────────────────────────\n"
    "llama.cpp not found!\n"
    "Please clone llama.cpp into android/cpp/:\n"
    "  cd android/cpp\n"
    "  git clone https://github.com/ggerganov/llama.cpp.git\n"
    "───────────────────────────────────────────────────────────\n"
  )
endif()

# Disable LLAMAFILE kernels to keep Android ABI builds portable.
set(GGML_LLAMAFILE OFF CACHE BOOL "Disable LLAMAFILE kernels for Android" FORCE)

# Disable OpenMP to avoid runtime dependency on libomp.so in Android APK.
set(GGML_OPENMP OFF CACHE BOOL "Disable OpenMP for Android runtime portability" FORCE)

# Add llama.cpp as subdirectory (it has its own CMakeLists.txt)
# This provides the 'llama' target we link against
add_subdirectory(llama.cpp)

# ============================================================
# Build Native Library
# ============================================================

# Create shared library: libllama_wrapper.so
# This is what Dart FFI will load with DynamicLibrary.open()
add_library(llama_wrapper SHARED
    llama_wrapper.cpp
)

# ============================================================
# Link Dependencies
# ============================================================

target_link_libraries(llama_wrapper PRIVATE
    llama              # Main llama.cpp library
    log                # Android logging
)

# ============================================================
# Include Paths
# ============================================================

target_include_directories(llama_wrapper PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp/include
)

# ============================================================
# Compilation Flags for Android
# ============================================================

# Enable optimizations for release builds
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    target_compile_options(llama_wrapper PRIVATE
        -O3
        -ffast-math
        -march=armv8-a+neon  # ARMv8 with NEON support for ARM64
    )
endif()

# Export C API symbols for Dart FFI lookups.
set_target_properties(llama_wrapper PROPERTIES
    C_VISIBILITY_PRESET default
    CXX_VISIBILITY_PRESET default
    VISIBILITY_INLINES_HIDDEN OFF
)

# ============================================================
# Output Configuration
# ============================================================

# Set output directory for .so file
set_target_properties(llama_wrapper PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}"
)

# ============================================================
# Debug Info
# ============================================================

message(STATUS "LlamaWrapper Build Configuration:")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "  Android ABI: ${ANDROID_ABI}")
message(STATUS "  Android Platform: ${ANDROID_PLATFORM}")
message(STATUS "  CMake version: ${CMAKE_VERSION}")
