#pragma once

#include "../../core/vectordb_core.h"
#include <vector>
#include <random>
#include <cmath>
#include <algorithm>
#include <unordered_map>
#include <unordered_set>

namespace vectordb {
namespace algorithms {

class IndexLSH : public VectorStorage {
private:
    size_t num_hash_tables_;
    size_t num_hash_functions_;
    float r_;
    std::vector<std::vector<std::vector<float>>> hash_functions_;
    std::vector<std::unordered_map<size_t, std::vector<size_t>>> hash_tables_;
    std::mt19937 rng_;

    void generate_hash_functions();
    size_t hash_vector(const float* vec, size_t table_idx) const;

public:
    IndexLSH(size_t dimension, size_t num_hash_tables = 8, 
             size_t num_hash_functions = 4, float r = 1.0);

    void add(size_t n, const float* x);

    void search(size_t n, const float* x, size_t k, float* distances, size_t* labels) const;

    size_t get_num_hash_tables() const { return num_hash_tables_; }
    size_t get_num_hash_functions() const { return num_hash_functions_; }
};

}
}
