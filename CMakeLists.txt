cmake_minimum_required(VERSION 3.24)

cmake_policy(SET CMP0091 NEW)

project(
    WinPebblePNGToJPG
    VERSION 2.0.0
    LANGUAGES CXX RC
)

set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

add_executable(
    WinPebble.PNGToJPG
    WIN32
    native/WinPebble.PNGToJPG.cpp
    resources/version.rc
)

target_compile_features(WinPebble.PNGToJPG PRIVATE cxx_std_20)

target_compile_definitions(
    WinPebble.PNGToJPG
    PRIVATE
        UNICODE
        _UNICODE
        WIN32_LEAN_AND_MEAN
        NOMINMAX
)

if(MSVC)
    target_compile_options(
        WinPebble.PNGToJPG
        PRIVATE
            /W4
            /WX
            /permissive-
            /EHsc
            /utf-8
    )
endif()

target_link_libraries(
    WinPebble.PNGToJPG
    PRIVATE
        windowscodecs
        ole32
        shell32
        oleaut32
        shlwapi
)

set_target_properties(
    WinPebble.PNGToJPG
    PROPERTIES
        OUTPUT_NAME "WinPebble.PNGToJPG"
)


