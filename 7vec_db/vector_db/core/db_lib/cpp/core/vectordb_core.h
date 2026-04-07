#pragma once

#include <vector>
#include <queue>
#include <utility>
#include <algorithm>
#include <limits>
#include <immintrin.h>
#include <cstdlib>
#include <cstring>
#include <stdexcept>

namespace vectordb {

namespace distance {

inline float compute_l2_distance(const float* query, const float* vec, size_t dim) {
    float dist = 0.0f;

#ifdef __AVX2__
    if (dim >= 8) {
        size_t i = 0;
        __m256 sum = _mm256_setzero_ps();

        size_t end = dim - 7;
        while (i < end) {
            __m256 q = _mm256_loadu_ps(query + i);
            __m256 v = _mm256_loadu_ps(vec + i);
            __m256 diff = _mm256_sub_ps(q, v);
            sum = _mm256_fmadd_ps(diff, diff, sum);
            i += 8;
        }

        __m256 shuffled = _mm256_permute2f128_ps(sum, sum, 0x21);
        __m256 summed = _mm256_add_ps(sum, shuffled);
        summed = _mm256_hadd_ps(summed, summed);
        summed = _mm256_hadd_ps(summed, summed);
        dist = _mm256_cvtss_f32(summed);

        for (; i < dim; ++i) {
            float diff = query[i] - vec[i];
            dist += diff * diff;
        }
    } else {
        for (size_t i = 0; i < dim; ++i) {
            float diff = query[i] - vec[i];
            dist += diff * diff;
        }
    }
#else
    for (size_t i = 0; i < dim; ++i) {
        float diff = query[i] - vec[i];
        dist += diff * diff;
    }
#endif

    return dist;
}

inline float compute_ip_distance(const float* query, const float* vec, size_t dim) {
    float dist = 0.0f;

#ifdef __AVX2__
    if (dim >= 8) {
        size_t i = 0;
        __m256 sum = _mm256_setzero_ps();

        size_t end = dim - 7;
        while (i < end) {
            __m256 q = _mm256_loadu_ps(query + i);
            __m256 v = _mm256_loadu_ps(vec + i);
            sum = _mm256_fmadd_ps(q, v, sum);
            i += 8;
        }

        __m256 shuffled = _mm256_permute2f128_ps(sum, sum, 0x21);
        __m256 summed = _mm256_add_ps(sum, shuffled);
        summed = _mm256_hadd_ps(summed, summed);
        summed = _mm256_hadd_ps(summed, summed);
        dist = _mm256_cvtss_f32(summed);

        for (; i < dim; ++i) {
            dist += query[i] * vec[i];
        }
    } else {
        for (size_t i = 0; i < dim; ++i) {
            dist += query[i] * vec[i];
        }
    }
#else
    for (size_t i = 0; i < dim; ++i) {
        dist += query[i] * vec[i];
    }
#endif

    return -dist;
}

}

class VectorStorage {
protected:
    std::vector<float> xb;
    std::vector<float> xb_transposed;
    size_t d;
    size_t ntotal;
    bool transposed;

public:
    VectorStorage(size_t dimension) 
        : d(dimension), ntotal(0), transposed(false) {
        size_t reserve_size = 1000000 * dimension;
        xb.reserve(reserve_size);
        xb_transposed.reserve(reserve_size);
    }

    virtual ~VectorStorage() = default;

    virtual void add(size_t n, const float* x) {
        if (d == 0) {
            throw std::invalid_argument("Dimension not set");
        }
        
        size_t old_size = xb.size();
        xb.resize(old_size + n * d);
        std::memcpy(xb.data() + old_size, x, n * d * sizeof(float));
        ntotal += n;
    }

    const float* data() const { return xb.data(); }
    size_t get_ntotal() const { return ntotal; }
    size_t get_dimension() const { return d; }
};

}
