cmake_minimum_required(VERSION 3.24)

cmake_policy(SET CMP0091 NEW)

project(
    WinPebblePNGToJPG
    VERSION 2.0.1
    LANGUAGES CXX RC
)

set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
option(WINPEBBLE_STORE_CANDIDATE "Build unreleased Store candidate metadata" OFF)

add_executable(
    WinPebble.PNGToJPG
    WIN32
    native/WinPebble.PNGToJPG.cpp
    resources/version.rc
)

target_compile_features(WinPebble.PNGToJPG PRIVATE cxx_std_20)
target_include_directories(WinPebble.PNGToJPG PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")

target_compile_definitions(
    WinPebble.PNGToJPG
    PRIVATE
        UNICODE
        _UNICODE
        WIN32_LEAN_AND_MEAN
        NOMINMAX
)

if(MSVC)
    # The reviewed manifest is embedded by version.rc as resource #1.
    target_link_options(WinPebble.PNGToJPG PRIVATE /MANIFEST:NO)
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

add_library(WinPebble.PNGToJPG.Shell SHARED shell/ExplorerCommand.cpp shell/ExplorerCommand.def shell/version.rc)
target_compile_features(WinPebble.PNGToJPG.Shell PRIVATE cxx_std_20)
target_compile_definitions(WinPebble.PNGToJPG.Shell PRIVATE UNICODE _UNICODE)
target_link_libraries(WinPebble.PNGToJPG.Shell PRIVATE shell32 shlwapi ole32 user32)
if(WINPEBBLE_STORE_CANDIDATE)
    target_compile_definitions(WinPebble.PNGToJPG PRIVATE WINPEBBLE_STORE_CANDIDATE)
    target_compile_definitions(WinPebble.PNGToJPG.Shell PRIVATE WINPEBBLE_STORE_CANDIDATE)
endif()
add_executable(Shell-Probe tests/Shell-Probe.cpp)
target_compile_features(Shell-Probe PRIVATE cxx_std_20)
target_compile_definitions(Shell-Probe PRIVATE UNICODE _UNICODE)
target_link_libraries(Shell-Probe PRIVATE shell32 shlwapi ole32)
if(MSVC)
    foreach(target WinPebble.PNGToJPG.Shell Shell-Probe)
        target_compile_options(${target} PRIVATE /W4 /WX /permissive- /EHsc /utf-8)
    endforeach()
endif()


