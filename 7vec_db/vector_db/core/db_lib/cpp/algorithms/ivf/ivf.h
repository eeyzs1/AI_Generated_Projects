#pragma once

#include "../../core/vectordb_core.h"
#include <vector>
#include <memory>
#include <cmath>
#include <random>
#include <algorithm>
#include <thread>
#include <mutex>
#include <queue>
#include <utility>

namespace vectordb {
namespace algorithms {

class IndexIVF : public VectorStorage {
private:
    size_t nlist_;
    size_t nprobe_;
    std::vector<float> centroids_;
    std::vector<std::vector<size_t>> inverted_lists_;
    
    void kmeans_clustering(size_t n, const float* x, size_t max_iter = 25);
    size_t assign_to_cluster(const float* vec) const;
    void search_in_clusters(const float* query, size_t k, 
                           const std::vector<size_t>& clusters,
                           float* distances, size_t* labels) const;

public:
    IndexIVF(size_t dimension, size_t nlist = 100);
    
    void train(size_t n, const float* x);
    
    void add(size_t n, const float* x);
    
    void set_nprobe(size_t nprobe) { nprobe_ = nprobe; }
    
    void search(size_t n, const float* x, size_t k, float* distances, size_t* labels) const;
    
    size_t get_nlist() const { return nlist_; }
    size_t get_nprobe() const { return nprobe_; }
};

}
}
