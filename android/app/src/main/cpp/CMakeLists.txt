cmake_minimum_required(VERSION 3.22.1)
project("wabot_bot_engine")

# Node.js Mobile headers — extracted by Gradle download task
set(NODE_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/node_include")

add_library(nodejs-mobile-native-lib SHARED
    native-lib.cpp
    rn-bridge.cpp
)

target_include_directories(nodejs-mobile-native-lib PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${NODE_INCLUDE_DIR}
)

# Import the pre-built libnode.so
add_library(libnode SHARED IMPORTED)
set_target_properties(libnode PROPERTIES
    IMPORTED_LOCATION
    "${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libnode.so"
)

find_library(log-lib log)

target_link_libraries(nodejs-mobile-native-lib
    libnode
    ${log-lib}
)
