#!/bin/bash

# 编译Rust库
echo "编译Rust库..."
export PYO3_USE_ABI3_FORWARD_COMPATIBILITY=1
cargo build --release

# 检查编译是否成功
if [ $? -ne 0 ]; then
    echo "编译失败"
    exit 1
fi

# 获取编译输出的动态库文件名（不同系统可能不同）
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    LIB_FILE="libvector_db_rust.dylib"
else
    # Linux
    LIB_FILE="libvector_db_rust.so"
fi

echo "编译成功: $LIB_FILE"

# 获取Python site-packages目录
PYTHON_SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])")

# 复制到site-packages目录
echo "正在安装 vector_db_rust 到 $PYTHON_SITE_PACKAGES"
sudo cp "target/release/$LIB_FILE" "$PYTHON_SITE_PACKAGES/vector_db_rust.so"

# 检查安装是否成功
if [ $? -ne 0 ]; then
    echo "安装失败"
    exit 1
fi

echo "安装成功!"
echo "现在可以在Python中使用 'import vector_db_rust' 导入"

# 验证安装
echo "\n验证安装..."
python3 -c "import vector_db_rust; print('vector_db_rust 导入成功'); index = vector_db_rust.FlatIndex(); print('创建索引成功'); index.add([[1.0, 2.0, 3.0]]); print('添加向量成功'); print('Rust库安装验证完成')"