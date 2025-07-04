# setup required values for toolchain files if not done already
if(NOT DEFINED ANDROID_NDK AND EXISTS $ENV{ANDROID_NDK_ROOT})
    set(ANDROID_NDK $ENV{ANDROID_NDK_ROOT})
endif()

set(ANDROID_ABI "arm64-v8a" CACHE STRING "Android ABI version" FORCE)  # "arm64-v8a" is the only one supported
set(ANDROID_NATIVE_API_LEVEL 24) # 7.0
set(ANDROID_TARGET_API_LEVEL 34) # Android 14
set(ANDROID_TOOLCHAIN clang)
set(ANDROID_STL c++_shared)

if(LD_ANDROID_BUILD)
    # setup Android toolchain
    set(CMAKE_TOOLCHAIN_FILE ${ANDROID_NDK}/build/cmake/android.toolchain.cmake)
    message(STATUS "CMAKE_TOOLCHAIN_FILE: ${CMAKE_TOOLCHAIN_FILE}")
endif()
message(STATUS "CMAKE_SHARED_LINKER_FLAGS: ${CMAKE_SHARED_LINKER_FLAGS}")
