#include "ivf.h"
#include <stdexcept>
#include <limits>
#include <unordered_set>

namespace vectordb {
namespace algorithms {

IndexIVF::IndexIVF(size_t dimension, size_t nlist) 
    : VectorStorage(dimension), nlist_(nlist), nprobe_(10) {
    inverted_lists_.resize(nlist_);
}

void IndexIVF::kmeans_clustering(size_t n, const float* x, size_t max_iter) {
    centroids_.resize(nlist_ * d);

    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<size_t> dist(0, n - 1);

    std::unordered_set<size_t> selected_indices;
    for (size_t i = 0; i < nlist_; ++i) {
        size_t idx;
        do {
            idx = dist(gen);
        } while (selected_indices.count(idx));
        selected_indices.insert(idx);
        
        const float* src = x + idx * d;
        float* dst = centroids_.data() + i * d;
        std::copy(src, src + d, dst);
    }

    std::vector<float> new_centroids(nlist_ * d, 0.0f);
    std::vector<size_t> counts(nlist_, 0);
    
    for (size_t iter = 0; iter < max_iter; ++iter) {
        std::fill(new_centroids.begin(), new_centroids.end(), 0.0f);
        std::fill(counts.begin(), counts.end(), 0);
        
        for (size_t i = 0; i < n; ++i) {
            const float* vec = x + i * d;
            size_t cluster = assign_to_cluster(vec);
            float* sum = new_centroids.data() + cluster * d;
            
            for (size_t j = 0; j < d; ++j) {
                sum[j] += vec[j];
            }
            counts[cluster]++;
        }

        bool converged = true;
        float max_shift = 0.0f;
        
        for (size_t i = 0; i < nlist_; ++i) {
            if (counts[i] > 0) {
                float* old_c = centroids_.data() + i * d;
                float* new_c = new_centroids.data() + i * d;
                float inv_count = 1.0f / counts[i];
                
                for (size_t j = 0; j < d; ++j) {
                    new_c[j] *= inv_count;
                    float diff = new_c[j] - old_c[j];
                    max_shift = std::max(max_shift, std::abs(diff));
                }
                
                std::copy(new_c, new_c + d, old_c);
            }
        }
        
        if (max_shift < 1e-4) {
            break;
        }
    }
}

size_t IndexIVF::assign_to_cluster(const float* vec) const {
    size_t best_cluster = 0;
    float best_dist = std::numeric_limits<float>::max();
    
    for (size_t i = 0; i < nlist_; ++i) {
        const float* centroid = centroids_.data() + i * d;
        float dist = distance::compute_l2_distance(vec, centroid, d);
        if (dist < best_dist) {
            best_dist = dist;
            best_cluster = i;
        }
    }
    
    return best_cluster;
}

void IndexIVF::train(size_t n, const float* x) {
    if (n < nlist_) {
        throw std::invalid_argument("Training data is too small for nlist clusters");
    }
    kmeans_clustering(n, x);
}

void IndexIVF::add(size_t n, const float* x) {
    VectorStorage::add(n, x);
    
    for (size_t i = 0; i < n; ++i) {
        size_t idx = ntotal - n + i;
        const float* vec = data() + idx * d;
        size_t cluster = assign_to_cluster(vec);
        inverted_lists_[cluster].push_back(idx);
    }
}

void IndexIVF::search_in_clusters(const float* query, size_t k, 
                                  const std::vector<size_t>& clusters,
                                  float* distances, size_t* labels) const {
    std::vector<std::pair<float, size_t>> candidates;
    
    for (size_t cluster : clusters) {
        for (size_t idx : inverted_lists_[cluster]) {
            const float* vec = data() + idx * d;
            float dist = distance::compute_l2_distance(query, vec, d);
            candidates.push_back({dist, idx});
        }
    }
    
    std::sort(candidates.begin(), candidates.end());
    
    size_t count = std::min(k, candidates.size());
    for (size_t i = 0; i < count; ++i) {
        distances[i] = candidates[i].first;
        labels[i] = candidates[i].second;
    }
    
    for (size_t i = count; i < k; ++i) {
        distances[i] = 0.0f;
        labels[i] = 0;
    }
}

void IndexIVF::search(size_t n, const float* x, size_t k, float* distances, size_t* labels) const {
    if (centroids_.empty()) {
        throw std::runtime_error("Index not trained");
    }
    
    for (size_t q = 0; q < n; ++q) {
        const float* query = x + q * d;
        
        std::vector<std::pair<float, size_t>> cluster_distances;
        for (size_t i = 0; i < nlist_; ++i) {
            const float* centroid = centroids_.data() + i * d;
            float dist = distance::compute_l2_distance(query, centroid, d);
            cluster_distances.push_back({dist, i});
        }
        
        std::sort(cluster_distances.begin(), cluster_distances.end());
        
        std::vector<size_t> clusters_to_search;
        size_t nprobe = std::min(nprobe_, nlist_);
        for (size_t i = 0; i < nprobe; ++i) {
            clusters_to_search.push_back(cluster_distances[i].second);
        }
        
        search_in_clusters(query, k, clusters_to_search, 
                          distances + q * k, labels + q * k);
    }
}

}
}
