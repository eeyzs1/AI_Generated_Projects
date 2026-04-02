#!/bin/bash

# 获取Python include目录
PYTHON_INCLUDE=$(python3 -c "import sysconfig; print(sysconfig.get_path('include'))")

# 编译向量数据库库
echo "编译向量数据库库..."
g++ -std=c++23 -shared -fPIC -O3 -march=native -mtune=native -flto -mavx -mavx2 -mfma \
    -I$PYTHON_INCLUDE \
    -I$(python3 -m pybind11 --includes) \
    vector_db.cpp bindings.cpp \
    -o vector_db_cpp.so

# 检查编译是否成功
if [ $? -ne 0 ]; then
    echo "编译失败"
    exit 1
fi

echo "编译成功: vector_db_cpp.so"

# 获取Python site-packages目录
PYTHON_SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])")

# 复制到site-packages目录
echo "正在安装 vector_db_cpp 到 $PYTHON_SITE_PACKAGES"
sudo cp vector_db_cpp.so "$PYTHON_SITE_PACKAGES/"

# 检查安装是否成功
if [ $? -ne 0 ]; then
    echo "安装失败"
    exit 1
fi

echo "安装成功!"
echo "现在可以在Python中使用 'import vector_db_cpp' 导入"

# 验证安装
echo "\n验证安装..."
python3 -c "import vector_db_cpp; print('vector_db_cpp 导入成功'); index = vector_db_cpp.IndexFlatL2(128); print('创建索引成功'); index.add([[1.0]*128]); print('添加向量成功'); print('C++库安装验证完成')"