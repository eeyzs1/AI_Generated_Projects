#pragma once

#include <vector>
#include <queue>
#include <utility>
#include <algorithm>
#include <span>
#include <limits>
#include <immintrin.h>
#include <cstdlib>
#include <cstring>
#include <atomic>

class IndexFlatL2 {
private:
    std::vector<float> xb;  // 一维连续存储所有向量（行优先）
    std::vector<float> xb_transposed;  // 转置存储的向量（列优先，用于SIMD优化）
    size_t d = 0;           // 维度
    size_t ntotal = 0;      // 向量数量
    bool transposed = false; // 是否已经转置

    // 优化的L2距离计算，使用SIMD指令
    inline float compute_l2_distance(const float* query, const float* vec, size_t dim) const;
    
    // 批量计算多个向量的距离（使用转置数据）
    inline void compute_batch_distances_transposed(const float* query, size_t start_idx, size_t batch_size, float* distances) const;

    // 批量计算多个向量的距离，使用SIMD加速
    inline void compute_batch_distances(const float* query, const float* vecs, size_t batch_size, size_t dim, float* distances) const;
    
    // 单个查询向量的搜索函数
    void search_single(const float* query, size_t k, float* distances, size_t* labels) const;
    
    // 并行处理的搜索函数，按向量分块
    void search_parallel(const float* query, size_t k, float* distances, size_t* labels) const;
    
    // 转置数据以优化内存布局
    void transpose_data();

public:
    IndexFlatL2(size_t dimension);
    
    void add(size_t n, const float* x);
    
    void search(size_t n, const float* x, size_t k, float* distances, size_t* labels) const;
    
    size_t size() const;
    size_t get_dimension() const;
};