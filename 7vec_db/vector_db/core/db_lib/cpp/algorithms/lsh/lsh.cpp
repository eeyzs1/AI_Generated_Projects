#include "lsh.h"
#include <stdexcept>
#include <limits>

namespace vectordb {
namespace algorithms {

IndexLSH::IndexLSH(size_t dimension, size_t num_hash_tables, 
                   size_t num_hash_functions, float r)
    : VectorStorage(dimension), num_hash_tables_(num_hash_tables), 
      num_hash_functions_(num_hash_functions), r_(r), rng_(std::random_device{}()) {
    hash_tables_.resize(num_hash_tables_);
    generate_hash_functions();
}

void IndexLSH::generate_hash_functions() {
    hash_functions_.resize(num_hash_tables_);
    std::normal_distribution<float> normal_dist(0.0, 1.0);
    std::uniform_real_distribution<float> uniform_dist(0.0, r_);

    for (size_t t = 0; t < num_hash_tables_; ++t) {
        hash_functions_[t].resize(num_hash_functions_);
        for (size_t h = 0; h < num_hash_functions_; ++h) {
            hash_functions_[t][h].resize(d + 1);
            for (size_t i = 0; i < d; ++i) {
                hash_functions_[t][h][i] = normal_dist(rng_);
            }
            hash_functions_[t][h][d] = uniform_dist(rng_);
        }
    }
}

size_t IndexLSH::hash_vector(const float* vec, size_t table_idx) const {
    size_t hash = 0;
    for (size_t h = 0; h < num_hash_functions_; ++h) {
        float dot = 0.0f;
        for (size_t i = 0; i < d; ++i) {
            dot += vec[i] * hash_functions_[table_idx][h][i];
        }
        dot += hash_functions_[table_idx][h][d];
        int bit = static_cast<int>(std::floor(dot / r_));
        hash = (hash << 1) | (bit & 1);
    }
    return hash;
}

void IndexLSH::add(size_t n, const float* x) {
    size_t old_total = ntotal;
    VectorStorage::add(n, x);

    for (size_t i = 0; i < n; ++i) {
        size_t idx = old_total + i;
        const float* vec = data() + idx * d;

        for (size_t t = 0; t < num_hash_tables_; ++t) {
            size_t hash = hash_vector(vec, t);
            hash_tables_[t][hash].push_back(idx);
        }
    }
}

void IndexLSH::search(size_t n, const float* x, size_t k, float* distances, size_t* labels) const {
    for (size_t q = 0; q < n; ++q) {
        const float* query = x + q * d;

        std::unordered_set<size_t> candidates;
        for (size_t t = 0; t < num_hash_tables_; ++t) {
            size_t hash = hash_vector(query, t);
            auto it = hash_tables_[t].find(hash);
            if (it != hash_tables_[t].end()) {
                for (size_t idx : it->second) {
                    candidates.insert(idx);
                }
            }
        }

        std::vector<std::pair<float, size_t>> results;
        for (size_t idx : candidates) {
            const float* vec = data() + idx * d;
            float dist = distance::compute_l2_distance(query, vec, d);
            results.push_back({dist, idx});
        }

        std::sort(results.begin(), results.end());

        size_t take = std::min(k, results.size());
        for (size_t i = 0; i < take; ++i) {
            distances[q * k + i] = results[i].first;
            labels[q * k + i] = results[i].second;
        }

        for (size_t i = take; i < k; ++i) {
            distances[q * k + i] = 0.0f;
            labels[q * k + i] = 0;
        }
    }
}

}
}
