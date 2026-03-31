#pragma once

#include <vector>
#include <queue>
#include <utility>
#include <algorithm>
#include <span>
#include <limits>
#include <immintrin.h>
#include <cstdlib>

class IndexFlatL2 {
private:
    std::vector<float> xb;  // 一维连续存储所有向量
    size_t d = 0;           // 维度
    size_t ntotal = 0;      // 向量数量

    // 优化的L2距离计算，使用SIMD指令
    inline float compute_l2_distance(const float* query, const float* vec, size_t dim) const;
    
    // 单个查询向量的搜索函数
    void search_single(const float* query, size_t k, float* distances, size_t* labels) const;
    
    // 批量处理向量的搜索函数，使用SIMD加速
    void search_batch(const float* query, size_t k, float* distances, size_t* labels) const;

public:
    IndexFlatL2(size_t dimension);
    
    void add(size_t n, const float* x);
    
    void search(size_t n, const float* x, size_t k, float* distances, size_t* labels) const;
    
    size_t size() const;
    size_t get_dimension() const;
};