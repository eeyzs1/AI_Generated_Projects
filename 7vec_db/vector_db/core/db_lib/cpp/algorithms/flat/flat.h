#pragma once

#include "../../core/vectordb_core.h"
#include &lt;queue&gt;
#include &lt;utility&gt;
#include &lt;algorithm&gt;
#include &lt;span&gt;
#include &lt;thread&gt;
#include &lt;atomic&gt;

namespace vectordb {
namespace algorithms {

class IndexFlatL2 : public VectorStorage {
private:
    inline void compute_batch_distances_transposed(const float* query, size_t start_idx, size_t batch_size, float* distances) const;
    inline void compute_batch_distances(const float* query, const float* vecs, size_t batch_size, size_t dim, float* distances) const;
    void search_single(const float* query, size_t k, float* distances, size_t* labels) const;
    void search_parallel(const float* query, size_t k, float* distances, size_t* labels) const;

public:
    IndexFlatL2(size_t dimension);
    void add(size_t n, const float* x);
    void search(size_t n, const float* x, size_t k, float* distances, size_t* labels) const;
};

} // namespace algorithms
} // namespace vectordb
