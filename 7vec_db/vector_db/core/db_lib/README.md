# 7VecDB - Modular Vector Database Library

高性能模块化向量数据库库，支持 C++ 和 Rust 实现，提供多种索引算法。

## 架构设计

本项目采用模块化设计，核心思想是：**改一个算法，只重编那个算法，Python 壳和核心都不用全编译。**

### 目录结构

```
db_lib/
├── cpp/                    # C++ 实现
│   ├── core/               # 公共核心库 (vectordb_core)
│   ├── algorithms/         # 独立算法模块
│   │   ├── flat/          # Flat L2 索引
│   │   ├── hnsw/          # HNSW (预留)
│   │   ├── ivf/           # IVF (预留)
│   │   └── ...
│   └── CMakeLists.txt
├── rust/                   # Rust 实现
│   ├── vectordb-core/     # 公共核心库
│   ├── vectordb-flat/     # Flat 索引模块
│   ├── vectordb-hnsw/     # HNSW (预留)
│   └── Cargo.toml
├── python/                 # Python 包装层
│   └── vectordb/
│       ├── __init__.py
│       ├── index.py        # 统一入口
│       ├── cpp/            # C++ 编译的扩展
│       └── rust/           # Rust 编译的扩展
├── build_cpp.sh            # C++ 编译脚本
├── build_rust.sh           # Rust 编译脚本
└── build_all.sh            # 全部编译脚本
```

## 编译

### 编译 C++ 模块

```bash
./build_cpp.sh
```

### 编译 Rust 模块

```bash
./build_rust.sh
```

### 编译所有模块

```bash
./build_all.sh
```

## 使用方法

```python
import numpy as np
from vectordb import VectorIndex, IndexType, Implementation

# 创建 Flat L2 索引 (C++ 实现)
index = VectorIndex(
    index_type=IndexType.FLAT_L2,
    dimension=128,
    implementation=Implementation.CPP
)

# 或者使用便捷函数
from vectordb import create_index
index = create_index("flat_l2", 128, "cpp")

# 添加向量
vectors = np.random.rand(10000, 128).astype(np.float32)
index.add(vectors)

# 搜索
queries = np.random.rand(10, 128).astype(np.float32)
distances, labels = index.search(queries, k=5)

print(f"Index size: {index.size()}")
print(f"Distances shape: {distances.shape}")
print(f"Labels shape: {labels.shape}")
```

## 支持的索引类型

- ✅ **FLAT_L2**: 暴力搜索 L2 距离
- ⏳ **FLAT_IP**: 暴力搜索内积 (待实现)
- ⏳ **HNSW**: Hierarchical Navigable Small Worlds (待实现)
- ⏳ **IVF**: Inverted File (待实现)
- ⏳ **PQ**: Product Quantization (待实现)
- ⏳ **LSH**: Locality-Sensitive Hashing (待实现)
- ⏳ **KD_TREE**: K-Dimensional Tree (待实现)
- ⏳ **BALL_TREE**: Ball Tree (待实现)
- ⏳ **ANNOY**: Approximate Nearest Neighbors Oh Yeah (待实现)

## 模块化优势

1. **增量编译**: 只重新编译修改过的算法模块
2. **快速开发**: 核心库稳定后，算法模块可独立开发测试
3. **灵活替换**: 可以轻松替换不同实现的同一算法
4. **统一接口**: 所有算法通过同一个 Python 接口访问

## 开发新算法

### C++ 算法

1. 在 `cpp/algorithms/` 下创建新目录
2. 实现算法，链接 `vectordb_core`
3. 在 `CMakeLists.txt` 中添加新模块
4. 运行 `./build_cpp.sh` 编译

### Rust 算法

1. 在 `rust/` 下创建新 crate
2. 依赖 `vectordb-core`
3. 在工作区 `Cargo.toml` 中添加新成员
4. 运行 `./build_rust.sh` 编译

## 性能优化

- 核心库包含 SIMD 优化的距离计算
- 多线程支持
- 内存布局优化
