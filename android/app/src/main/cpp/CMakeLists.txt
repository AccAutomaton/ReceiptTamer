cmake_minimum_required(VERSION 3.18.1)
project("mnn_jni")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ============================================================================
# MNN Configuration
# ============================================================================

# MNN prebuilt libraries location
set(MNN_LIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI})

message(STATUS "Building for ABI: ${ANDROID_ABI}")
message(STATUS "MNN lib dir: ${MNN_LIB_DIR}")

# Check if MNN libraries exist for this ABI
if(NOT EXISTS "${MNN_LIB_DIR}/libMNN.so")
    message(FATAL_ERROR "MNN libraries not found in: ${MNN_LIB_DIR}. Only arm64-v8a is supported.")
endif()

# ============================================================================
# Create JNI shared library
# ============================================================================

add_library(mnn_jni SHARED
    mnn-jni.cpp
)

# Include directories for MNN headers
target_include_directories(mnn_jni PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Link against MNN libraries
target_link_libraries(mnn_jni PRIVATE
    ${MNN_LIB_DIR}/libMNN.so
    ${MNN_LIB_DIR}/libMNN_Express.so
    ${MNN_LIB_DIR}/libllm.so
    ${MNN_LIB_DIR}/libc++_shared.so
    android
    log
)

# Define that we're using MNN
target_compile_definitions(mnn_jni PRIVATE
    MNN_ENABLED=1
)