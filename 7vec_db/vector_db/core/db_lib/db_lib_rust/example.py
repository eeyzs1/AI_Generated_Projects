#!/usr/bin/env python3
"""
Vector DB Example
"""

import numpy as np
from vector_db_rust import FlatIndex

# Create index
index = FlatIndex()

# Add vectors (3-dimensional)
vectors = [
    [1.0, 2.0, 3.0],
    [4.0, 5.0, 6.0],
    [7.0, 8.0, 9.0],
    [10.0, 11.0, 12.0]
]
index.add(vectors)

print(f"Index size: {index.size()}")
print(f"Index dimension: {index.dimension()}")

# Search
query = [2.0, 3.0, 4.0]
k = 2

labels, distances = index.search(query, k)

print(f"Query: {query}")
print(f"Top {k} results:")
for i, (label, dist) in enumerate(zip(labels, distances)):
    print(f"Rank {i+1}: Vector {label} with L2 squared distance {dist:.6f}")

# Test with numpy arrays (same dimension)
np_vectors = np.random.rand(10, 3).tolist()
index.add(np_vectors)

print(f"\nAfter adding numpy vectors:")
print(f"Index size: {index.size()}")
print(f"Index dimension: {index.dimension()}")

# Search with numpy array
np_query = np.random.rand(3).tolist()
labels, distances = index.search(np_query, 3)

print(f"\nQuery (numpy): {np_query[:3]}...")
print(f"Top 3 results:")
for i, (label, dist) in enumerate(zip(labels, distances)):
    print(f"Rank {i+1}: Vector {label} with L2 squared distance {dist:.6f}")