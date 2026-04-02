import vector_db_cpp
import numpy as np

# 创建索引实例（指定维度）
dimension = 128
index = vector_db_cpp.IndexFlatL2(dimension)

# 生成一些示例向量
num_vectors = 1000
vectors = np.random.rand(num_vectors, dimension).astype(np.float32)

# 批量添加向量
print("Adding vectors...")
index.add(vectors)

print(f"Added {index.size()} vectors of dimension {index.get_dimension()}")

# 生成查询向量（支持批量查询）
num_queries = 1
queries = np.random.rand(num_queries, dimension).astype(np.float32)

# 搜索Top-5
k = 5
distances, labels = index.search(queries, k)

print(f"\nSearch results (Top-{k}):")
for i in range(num_queries):
    print(f"Query {i+1}:")
    for j in range(k):
        print(f"  Rank {j+1}: ID={labels[i, j]}, Distance={distances[i, j]:.6f}")

# 验证搜索结果
print("\nVerifying results...")
# 计算查询向量与第一个结果的距离
query = queries[0]
first_idx = labels[0, 0]
first_vec = vectors[first_idx]
computed_dist = np.linalg.norm(query - first_vec)
print(f"Computed L2 distance: {computed_dist**2:.6f}")
print(f"Index returned distance: {distances[0, 0]:.6f}")
print(f"Match: {abs(computed_dist**2 - distances[0, 0]) < 1e-10}")