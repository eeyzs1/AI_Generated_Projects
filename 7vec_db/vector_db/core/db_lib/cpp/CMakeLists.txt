# 模块化编译的 CMake 配置

cmake_minimum_required(VERSION 3.18)
project(vectordb)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -march=native -ffast-math")
endif()

find_package(Python3 COMPONENTS Interpreter Development)
find_package(pybind11 REQUIRED)

add_library(vectordb_core INTERFACE)
target_include_directories(vectordb_core INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}/core
    ${pybind11_INCLUDE_DIRS}
    ${Python3_INCLUDE_DIRS}
)

pybind11_add_module(_ivf
    algorithms/ivf/ivf.cpp
    algorithms/ivf/bindings.cpp
)
target_link_libraries(_ivf PRIVATE
    vectordb_core
)
target_include_directories(_ivf PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/core
    ${CMAKE_CURRENT_SOURCE_DIR}/algorithms/ivf
)

pybind11_add_module(_hnsw
    algorithms/hnsw/hnsw.cpp
    algorithms/hnsw/bindings.cpp
)
target_link_libraries(_hnsw PRIVATE
    vectordb_core
)
target_include_directories(_hnsw PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/core
    ${CMAKE_CURRENT_SOURCE_DIR}/algorithms/hnsw
)

pybind11_add_module(_pq
    algorithms/pq/pq.cpp
    algorithms/pq/bindings.cpp
)
target_link_libraries(_pq PRIVATE
    vectordb_core
)
target_include_directories(_pq PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/core
    ${CMAKE_CURRENT_SOURCE_DIR}/algorithms/pq
)

pybind11_add_module(_lsh
    algorithms/lsh/lsh.cpp
    algorithms/lsh/bindings.cpp
)
target_link_libraries(_lsh PRIVATE
    vectordb_core
)
target_include_directories(_lsh PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/core
    ${CMAKE_CURRENT_SOURCE_DIR}/algorithms/lsh
)

pybind11_add_module(_kdtree
    algorithms/kdtree/kdtree.cpp
    algorithms/kdtree/bindings.cpp
)
target_link_libraries(_kdtree PRIVATE
    vectordb_core
)
target_include_directories(_kdtree PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/core
    ${CMAKE_CURRENT_SOURCE_DIR}/algorithms/kdtree
)

pybind11_add_module(_balltree
    algorithms/balltree/balltree.cpp
    algorithms/balltree/bindings.cpp
)
target_link_libraries(_balltree PRIVATE
    vectordb_core
)
target_include_directories(_balltree PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/core
    ${CMAKE_CURRENT_SOURCE_DIR}/algorithms/balltree
)

pybind11_add_module(_annoy
    algorithms/annoy/annoy.cpp
    algorithms/annoy/bindings.cpp
)
target_link_libraries(_annoy PRIVATE
    vectordb_core
)
target_include_directories(_annoy PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/core
    ${CMAKE_CURRENT_SOURCE_DIR}/algorithms/annoy
)

set_target_properties(_ivf PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../python/vectordb/cpp
)

set_target_properties(_hnsw PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../python/vectordb/cpp
)

set_target_properties(_pq PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../python/vectordb/cpp
)

set_target_properties(_lsh PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../python/vectordb/cpp
)

set_target_properties(_kdtree PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../python/vectordb/cpp
)

set_target_properties(_balltree PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../python/vectordb/cpp
)

set_target_properties(_annoy PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../python/vectordb/cpp
)
