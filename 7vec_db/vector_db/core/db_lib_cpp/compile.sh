#!/bin/bash

# 获取Python include目录
PYTHON_INCLUDE=$(python3 -c "import sysconfig; print(sysconfig.get_path('include'))")

# 编译向量数据库库
g++ -std=c++23 -shared -fPIC -O3 \
    -I$PYTHON_INCLUDE \
    -I$(python3 -m pybind11 --includes) \
    vector_db.cpp bindings.cpp \
    -o vector_db_cpp.so

# 检查编译是否成功
if [ $? -eq 0 ]; then
    echo "编译成功: vector_db_cpp.so"
else
    echo "编译失败"
    exit 1
fi