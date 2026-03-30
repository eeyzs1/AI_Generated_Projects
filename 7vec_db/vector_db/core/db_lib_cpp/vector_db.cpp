#include "vector_db.h"
#include <stdexcept>

IndexFlatL2::IndexFlatL2(size_t dimension) : d(dimension), ntotal(0) {
    xb.reserve(dimension);
}

void IndexFlatL2::add(size_t n, const double* x) {
    if (d == 0) {
        throw std::invalid_argument("Dimension not set");
    }
    
    // 批量添加n个向量，每个向量维度为d
    xb.insert(xb.end(), x, x + n * d);
    ntotal += n;
}

void IndexFlatL2::search(size_t n, const double* x, size_t k, double* distances, size_t* labels) const {
    if (d == 0) {
        throw std::invalid_argument("Dimension not set");
    }
    
    if (ntotal == 0) {
        // 空数据库，返回默认值
        for (size_t i = 0; i < n * k; ++i) {
            distances[i] = 0.0;
            labels[i] = 0;
        }
        return;
    }
    
    // 对于每个查询向量
    for (size_t i = 0; i < n; ++i) {
        // 优先队列（大顶堆），存储(距离, 索引)
        std::priority_queue<std::pair<double, size_t>> pq;
        
        // 使用C++23的span来表示查询向量
        std::span<const double> query_span(x + i * d, d);
        
        // 遍历所有向量计算距离
        for (size_t j = 0; j < ntotal; ++j) {
            // 使用C++23的span来表示数据库中的向量
            std::span<const double> vec_span(xb.data() + j * d, d);
            double dist = 0.0;
            
            // 计算L2平方距离
            for (size_t l = 0; l < d; ++l) {
                double diff = query_span[l] - vec_span[l];
                dist += diff * diff;
            }
            
            // 维护大小为k的优先队列
            if (pq.size() < k) {
                pq.emplace(dist, j);
            } else if (dist < pq.top().first) {
                pq.pop();
                pq.emplace(dist, j);
            }
        }
        
        // 填充结果（大顶堆，按距离从大到小存储，需要反转）
        std::vector<std::pair<double, size_t>> result;
        result.reserve(k);
        while (!pq.empty()) {
            result.emplace_back(pq.top());
            pq.pop();
        }
        // 反转结果，使距离从小到大排序
        std::reverse(result.begin(), result.end());
        // 填充到输出数组
        for (size_t j = 0; j < result.size(); ++j) {
            distances[i * k + j] = result[j].first;
            labels[i * k + j] = result[j].second;
        }
        // 填充剩余位置（如果不足k个）
        for (size_t j = result.size(); j < k; ++j) {
            distances[i * k + j] = 0.0;
            labels[i * k + j] = 0;
        }
    }
}

size_t IndexFlatL2::size() const {
    return ntotal;
}

size_t IndexFlatL2::get_dimension() const {
    return d;
}