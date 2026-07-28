# SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT

cmake_minimum_required(VERSION 3.18)

project(taglib_bridge_wasm LANGUAGES C CXX)

add_subdirectory(
  ${CMAKE_CURRENT_SOURCE_DIR}/../native/taglib_bridge
  ${CMAKE_CURRENT_BINARY_DIR}/native/taglib_bridge
)

if(EMSCRIPTEN)
  add_executable(taglib_bridge_module "${CMAKE_CURRENT_SOURCE_DIR}/empty.c")
  target_link_libraries(taglib_bridge_module PRIVATE taglib_bridge)

  set(EXPORTS_FILE "${CMAKE_CURRENT_SOURCE_DIR}/exports.json")
  target_link_options(taglib_bridge_module PRIVATE
    "--no-entry"
    "-sEXPORTED_FUNCTIONS=@${EXPORTS_FILE}"
    "-sEXPORTED_RUNTIME_METHODS=['cwrap','ccall','UTF8ToString','stringToUTF8','lengthBytesUTF8','getValue','setValue']"
    "-sALLOW_MEMORY_GROWTH=1"
    "-sMODULARIZE=1"
    "-sEXPORT_NAME=TaglibBridgeModule"
    "-sENVIRONMENT=web,worker"
    "-sFILESYSTEM=0"
  )

  set_target_properties(taglib_bridge_module PROPERTIES
    OUTPUT_NAME "taglib_bridge"
    SUFFIX ".js"
  )
endif()
