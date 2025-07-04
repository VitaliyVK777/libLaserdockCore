cmake_minimum_required(VERSION 3.11)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# library
if(IOS)
    add_library(liblzr)
else()
    add_library(liblzr SHARED)
endif()

set_property(TARGET liblzr PROPERTY AUTOMOC OFF)
set_property(TARGET liblzr PROPERTY AUTORCC OFF)
set_property(TARGET liblzr PROPERTY AUTOUIC OFF)

target_include_directories(liblzr PUBLIC .)

target_sources(liblzr PRIVATE
    #    engine.hpp
        liblzr.hpp
    #    src/engine_serialization.cpp
    #    src/engine.cpp
        src/frame.cpp
        src/ilda.cpp
        src/ilda.hpp
        src/ilda_palette.cpp
        src/ilda_read.cpp
        src/ilda_write.cpp
        src/interpolator.cpp
        src/interpolator.hpp
        src/mask.cpp
        src/optimizer.cpp
        src/optimizer.hpp
        src/optimizer_compile_paths.cpp
        src/optimizer_find_paths.cpp
        src/optimizer_path.cpp
        src/optimizer_reorder_paths.cpp
        src/point.cpp
        src/reduce.cpp
        src/transforms.cpp
        src/include/portable_endian.h
    )

# win library
if(WIN32)
    find_library (WS2_32_LIB NAMES Ws2_32)
    target_link_libraries(liblzr ${WS2_32_LIB})
    mark_as_advanced(WS2_32_LIB)

    # disable various conversion warnings
    target_compile_options(liblzr PRIVATE /wd4146)
    target_compile_options(liblzr PRIVATE /wd4244) # conversion from double to int
    target_compile_options(liblzr PRIVATE /wd4251) # conversion from double to int
    target_compile_options(liblzr PRIVATE /wd4267)
    target_compile_options(liblzr PRIVATE /wd4273)
    target_compile_options(liblzr PRIVATE /wd4305) # conversion from double to float
    target_compile_options(liblzr PRIVATE /wd4996)
endif()

if(ANDROID)
    target_compile_definitions(liblzr PRIVATE __STDC_LIMIT_MACROS)
endif()

if(NOT CMAKE_SOURCE_DIR STREQUAL PROJECT_SOURCE_DIR)
    add_library(${PROJECT_NAME}::liblzr ALIAS liblzr)
endif()
