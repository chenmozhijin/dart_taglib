# SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT

cmake_minimum_required(VERSION 3.18)

project(taglib_bridge LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(BUILD_BINDINGS OFF CACHE BOOL "" FORCE)
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

if(NOT TARGET tag)
  add_subdirectory(
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib
    ${CMAKE_CURRENT_BINARY_DIR}/third_party/taglib
  )
endif()

if(EMSCRIPTEN)
  # The final WebAssembly module links this target. A static library keeps the
  # bridge symbols in the final link instead of treating it as a separate module.
  set(TAGLIB_BRIDGE_LIBRARY_TYPE STATIC)
else()
  set(TAGLIB_BRIDGE_LIBRARY_TYPE SHARED)
endif()

add_library(taglib_bridge ${TAGLIB_BRIDGE_LIBRARY_TYPE}
  src/bridge_common.cpp
  src/bridge_capabilities.cpp
  src/bridge_tags.cpp
  src/bridge_sylt.cpp
  src/bridge_encoding.cpp
  src/bridge_save.cpp
)

target_include_directories(taglib_bridge
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/toolkit
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/mpeg
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/mpeg/id3v1
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/mpeg/id3v2
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/mpeg/id3v2/frames
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/asf
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/ape
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/dsdiff
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/dsf
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/flac
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/matroska
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/mp4
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/mpc
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/ogg
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/ogg/flac
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/ogg/opus
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/ogg/speex
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/ogg/vorbis
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/riff
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/riff/aiff
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/riff/wav
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/shorten
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/trueaudio
    ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/taglib/taglib/wavpack
    ${CMAKE_CURRENT_BINARY_DIR}/third_party/taglib
)

target_compile_definitions(taglib_bridge
  PRIVATE
    TAGLIB_BRIDGE_BUILDING
    TAGLIB_STATIC
)

target_link_libraries(taglib_bridge
  PRIVATE
    tag
)

set_target_properties(taglib_bridge PROPERTIES
  OUTPUT_NAME taglib_bridge
)
