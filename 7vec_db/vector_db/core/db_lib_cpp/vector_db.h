#pragma once

#include <vector>
#include <queue>
#include <utility>
#include <algorithm>
#include <span>

class IndexFlatL2 {
private:
    std::vector<double> xb;  // 一维连续存储所有向量
    size_t d = 0;           // 维度
    size_t ntotal = 0;      // 向量数量

public:
    IndexFlatL2(size_t dimension);
    
    void add(size_t n, const double* x);
    
    void search(size_t n, const double* x, size_t k, double* distances, size_t* labels) const;
    
    size_t size() const;
    size_t get_dimension() const;
};