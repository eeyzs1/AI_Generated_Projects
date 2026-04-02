#include "vector_db.h"
#include <stdexcept>
#include <thread>
#include <vector>
#include <algorithm>
#include <execution>
#include <numeric>
#include <memory>

IndexFlatL2::IndexFlatL2(size_t dimension) : d(dimension), ntotal(0), transposed(false) {
    // 预分配更大的空间，可容纳100万个向量
    size_t reserve_size = 1000000 * dimension;
    xb.reserve(reserve_size);
    xb_transposed.reserve(reserve_size);
}

void IndexFlatL2::add(size_t n, const float* x) {
    if (d == 0) {
        throw std::invalid_argument("Dimension not set");
    }
    
    // 批量添加n个向量，每个向量维度为d
    // 使用memcpy优化内存复制
    size_t old_size = xb.size();
    xb.resize(old_size + n * d);
    std::memcpy(xb.data() + old_size, x, n * d * sizeof(float));
    ntotal += n;
    
    // 转置数据以优化内存布局
    transpose_data();
}

// 转置数据以优化内存布局
void IndexFlatL2::transpose_data() {
    // 大数据集时不转置（stride 太大会破坏缓存）
    if (ntotal > 100000) {
        transposed = false;
        xb_transposed.clear();
        xb_transposed.shrink_to_fit();
        return;
    }

    if (ntotal == 0) {
        return;
    }

    // 分配转置数据的空间
    xb_transposed.resize(ntotal * d);

    // 执行转置操作：将行优先转换为列优先
    for (size_t i = 0; i < ntotal; ++i) {
        for (size_t j = 0; j < d; ++j) {
            xb_transposed[j * ntotal + i] = xb[i * d + j];
        }
    }

    transposed = true;
}

// 优化的L2距离计算，使用SIMD指令（内联函数）
inline float IndexFlatL2::compute_l2_distance(const float* query, const float* vec, size_t dim) const {
    float dist = 0.0f;

    #ifdef __AVX2__
    if (dim >= 64) {
        size_t i = 0;
        __m256 sum0 = _mm256_setzero_ps();
        __m256 sum1 = _mm256_setzero_ps();
        __m256 sum2 = _mm256_setzero_ps();
        __m256 sum3 = _mm256_setzero_ps();
        __m256 sum4 = _mm256_setzero_ps();
        __m256 sum5 = _mm256_setzero_ps();
        __m256 sum6 = _mm256_setzero_ps();
        __m256 sum7 = _mm256_setzero_ps();

        size_t end = dim - 63;
        while (i < end) {
            __builtin_prefetch(vec + i + 128, 0, 3);

            __m256 q0 = _mm256_loadu_ps(query + i);
            __m256 v0 = _mm256_loadu_ps(vec + i);
            __m256 diff0 = _mm256_sub_ps(q0, v0);
            sum0 = _mm256_fmadd_ps(diff0, diff0, sum0);

            __m256 q1 = _mm256_loadu_ps(query + i + 8);
            __m256 v1 = _mm256_loadu_ps(vec + i + 8);
            __m256 diff1 = _mm256_sub_ps(q1, v1);
            sum1 = _mm256_fmadd_ps(diff1, diff1, sum1);

            __m256 q2 = _mm256_loadu_ps(query + i + 16);
            __m256 v2 = _mm256_loadu_ps(vec + i + 16);
            __m256 diff2 = _mm256_sub_ps(q2, v2);
            sum2 = _mm256_fmadd_ps(diff2, diff2, sum2);

            __m256 q3 = _mm256_loadu_ps(query + i + 24);
            __m256 v3 = _mm256_loadu_ps(vec + i + 24);
            __m256 diff3 = _mm256_sub_ps(q3, v3);
            sum3 = _mm256_fmadd_ps(diff3, diff3, sum3);

            __m256 q4 = _mm256_loadu_ps(query + i + 32);
            __m256 v4 = _mm256_loadu_ps(vec + i + 32);
            __m256 diff4 = _mm256_sub_ps(q4, v4);
            sum4 = _mm256_fmadd_ps(diff4, diff4, sum4);

            __m256 q5 = _mm256_loadu_ps(query + i + 40);
            __m256 v5 = _mm256_loadu_ps(vec + i + 40);
            __m256 diff5 = _mm256_sub_ps(q5, v5);
            sum5 = _mm256_fmadd_ps(diff5, diff5, sum5);

            __m256 q6 = _mm256_loadu_ps(query + i + 48);
            __m256 v6 = _mm256_loadu_ps(vec + i + 48);
            __m256 diff6 = _mm256_sub_ps(q6, v6);
            sum6 = _mm256_fmadd_ps(diff6, diff6, sum6);

            __m256 q7 = _mm256_loadu_ps(query + i + 56);
            __m256 v7 = _mm256_loadu_ps(vec + i + 56);
            __m256 diff7 = _mm256_sub_ps(q7, v7);
            sum7 = _mm256_fmadd_ps(diff7, diff7, sum7);

            i += 64;
        }

        __m256 sum = _mm256_add_ps(_mm256_add_ps(sum0, sum1), _mm256_add_ps(sum2, sum3));
        sum = _mm256_add_ps(sum, _mm256_add_ps(_mm256_add_ps(sum4, sum5), _mm256_add_ps(sum6, sum7)));

        __m256 shuffled = _mm256_permute2f128_ps(sum, sum, 0x21);
        __m256 summed = _mm256_add_ps(sum, shuffled);
        summed = _mm256_hadd_ps(summed, summed);
        summed = _mm256_hadd_ps(summed, summed);
        dist = _mm256_cvtss_f32(summed);

        for (; i < dim; ++i) {
            float diff = query[i] - vec[i];
            dist += diff * diff;
        }
    } else if (dim >= 8) {
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

// 批量计算多个向量的距离（使用转置数据）
inline void IndexFlatL2::compute_batch_distances_transposed(const float* query, size_t start_idx, size_t batch_size, float* distances) const {
    #ifdef __AVX2__
    // 对每个维度，一次性处理8个向量
    for (size_t vec_offset = 0; vec_offset < batch_size; vec_offset += 8) {
        __m256 dist_vec = _mm256_setzero_ps();
        const float* base_ptr = xb_transposed.data() + start_idx + vec_offset;

        // 循环展开：每次处理8个维度
        size_t dim_idx = 0;
        for (; dim_idx + 7 < d; dim_idx += 8) {
            // 预取未来的数据
            __builtin_prefetch(base_ptr + (dim_idx + 8) * ntotal, 0, 3);
            __builtin_prefetch(base_ptr + (dim_idx + 16) * ntotal, 0, 3);

            __m256 q0 = _mm256_set1_ps(query[dim_idx]);
            __m256 v0 = _mm256_loadu_ps(base_ptr + dim_idx * ntotal);
            __m256 diff0 = _mm256_sub_ps(q0, v0);
            dist_vec = _mm256_fmadd_ps(diff0, diff0, dist_vec);

            __m256 q1 = _mm256_set1_ps(query[dim_idx + 1]);
            __m256 v1 = _mm256_loadu_ps(base_ptr + (dim_idx + 1) * ntotal);
            __m256 diff1 = _mm256_sub_ps(q1, v1);
            dist_vec = _mm256_fmadd_ps(diff1, diff1, dist_vec);

            __m256 q2 = _mm256_set1_ps(query[dim_idx + 2]);
            __m256 v2 = _mm256_loadu_ps(base_ptr + (dim_idx + 2) * ntotal);
            __m256 diff2 = _mm256_sub_ps(q2, v2);
            dist_vec = _mm256_fmadd_ps(diff2, diff2, dist_vec);

            __m256 q3 = _mm256_set1_ps(query[dim_idx + 3]);
            __m256 v3 = _mm256_loadu_ps(base_ptr + (dim_idx + 3) * ntotal);
            __m256 diff3 = _mm256_sub_ps(q3, v3);
            dist_vec = _mm256_fmadd_ps(diff3, diff3, dist_vec);

            __m256 q4 = _mm256_set1_ps(query[dim_idx + 4]);
            __m256 v4 = _mm256_loadu_ps(base_ptr + (dim_idx + 4) * ntotal);
            __m256 diff4 = _mm256_sub_ps(q4, v4);
            dist_vec = _mm256_fmadd_ps(diff4, diff4, dist_vec);

            __m256 q5 = _mm256_set1_ps(query[dim_idx + 5]);
            __m256 v5 = _mm256_loadu_ps(base_ptr + (dim_idx + 5) * ntotal);
            __m256 diff5 = _mm256_sub_ps(q5, v5);
            dist_vec = _mm256_fmadd_ps(diff5, diff5, dist_vec);

            __m256 q6 = _mm256_set1_ps(query[dim_idx + 6]);
            __m256 v6 = _mm256_loadu_ps(base_ptr + (dim_idx + 6) * ntotal);
            __m256 diff6 = _mm256_sub_ps(q6, v6);
            dist_vec = _mm256_fmadd_ps(diff6, diff6, dist_vec);

            __m256 q7 = _mm256_set1_ps(query[dim_idx + 7]);
            __m256 v7 = _mm256_loadu_ps(base_ptr + (dim_idx + 7) * ntotal);
            __m256 diff7 = _mm256_sub_ps(q7, v7);
            dist_vec = _mm256_fmadd_ps(diff7, diff7, dist_vec);
        }

        // 处理剩余维度
        for (; dim_idx < d; ++dim_idx) {
            __m256 q_broadcast = _mm256_set1_ps(query[dim_idx]);
            __m256 v_vals = _mm256_loadu_ps(base_ptr + dim_idx * ntotal);
            __m256 diff = _mm256_sub_ps(q_broadcast, v_vals);
            dist_vec = _mm256_fmadd_ps(diff, diff, dist_vec);
        }

        _mm256_storeu_ps(distances + vec_offset, dist_vec);
    }
    #else
    for (size_t i = 0; i < batch_size; ++i) {
        float dist = 0.0f;
        for (size_t dim_idx = 0; dim_idx < d; ++dim_idx) {
            float diff = query[dim_idx] - xb_transposed[dim_idx * ntotal + start_idx + i];
            dist += diff * diff;
        }
        distances[i] = dist;
    }
    #endif
}

// 批量计算多个向量的距离，使用SIMD加速
inline void IndexFlatL2::compute_batch_distances(const float* query, const float* vecs, size_t batch_size, size_t dim, float* distances) const {
    for (size_t i = 0; i < batch_size; ++i) {
        distances[i] = compute_l2_distance(query, vecs + i * dim, dim);
    }
}

// 单个查询向量的搜索函数
void IndexFlatL2::search_single(const float* query, size_t k, float* distances, size_t* labels) const {
    // 使用固定大小的数组来维护top-k结果，避免优先队列的开销
    float top_distances[k];
    size_t top_labels[k];

    // 初始化
    for (size_t i = 0; i < k; ++i) {
        top_distances[i] = std::numeric_limits<float>::max();
        top_labels[i] = 0;
    }

    // 检查是否使用转置数据
    if (transposed) {
        // 动态分块：小数据集用大块，大数据集用小块
        size_t block_size = ntotal < 200000 ? std::min(size_t(16384), ntotal) : std::min(size_t(4096), ntotal);
        float batch_dists[16384];

        // 分块处理
        for (size_t block_start = 0; block_start < ntotal; block_start += block_size) {
            size_t block_end = std::min(block_start + block_size, ntotal);
            size_t block_len = block_end - block_start;

            // 批量计算当前块的所有距离
            for (size_t i = 0; i < block_len; i += 8) {
                size_t batch = std::min(size_t(8), block_len - i);
                compute_batch_distances_transposed(query, block_start + i, batch, batch_dists + i);
            }

            // 更新top-k：使用更高效的插入策略
            for (size_t i = 0; i < block_len; ++i) {
                float dist = batch_dists[i];
                if (dist < top_distances[k-1]) {
                    // 二分查找插入位置
                    size_t left = 0, right = k;
                    while (left < right) {
                        size_t mid = (left + right) / 2;
                        if (dist < top_distances[mid]) {
                            right = mid;
                        } else {
                            left = mid + 1;
                        }
                    }

                    if (left < k) {
                        // 使用 memmove 批量移动
                        std::memmove(&top_distances[left + 1], &top_distances[left], (k - left - 1) * sizeof(float));
                        std::memmove(&top_labels[left + 1], &top_labels[left], (k - left - 1) * sizeof(size_t));
                        top_distances[left] = dist;
                        top_labels[left] = block_start + i;
                    }
                }
            }
        }
    } else {
        // 使用原始数据进行搜索
        // 针对大数据集优化：使用更高效的内存访问模式
        const size_t batch_size = 32; // 批量处理大小，适合SIMD优化
        const size_t cache_line_size = 64;
        const size_t vectors_per_cache_line = cache_line_size / sizeof(float) / d;
        
        const float* vec = xb.data();
        
        // 批量处理向量，使用连续内存访问
        size_t i = 0;
        // 展开8次循环，进一步减少分支开销
        while (i + 7 < ntotal) {
            // 软件预取，减少内存访问延迟
            __builtin_prefetch(vec + d * 8, 0, 3);
            __builtin_prefetch(vec + d * 16, 0, 3);
            
            // 计算8个向量的距离
            float dist0 = compute_l2_distance(query, vec, d);
            float dist1 = compute_l2_distance(query, vec + d, d);
            float dist2 = compute_l2_distance(query, vec + 2 * d, d);
            float dist3 = compute_l2_distance(query, vec + 3 * d, d);
            float dist4 = compute_l2_distance(query, vec + 4 * d, d);
            float dist5 = compute_l2_distance(query, vec + 5 * d, d);
            float dist6 = compute_l2_distance(query, vec + 6 * d, d);
            float dist7 = compute_l2_distance(query, vec + 7 * d, d);
            
            // 处理第一个向量
            if (dist0 < top_distances[k-1]) {
                size_t left = 0, right = k;
                while (left < right) {
                    size_t mid = (left + right) / 2;
                    if (dist0 < top_distances[mid]) {
                        right = mid;
                    } else {
                        left = mid + 1;
                    }
                }
                if (left < k) {
                    std::memmove(&top_distances[left + 1], &top_distances[left], (k - left - 1) * sizeof(float));
                    std::memmove(&top_labels[left + 1], &top_labels[left], (k - left - 1) * sizeof(size_t));
                    top_distances[left] = dist0;
                    top_labels[left] = i;
                }
            }

            // 处理第二个向量
            if (dist1 < top_distances[k-1]) {
                size_t left = 0, right = k;
                while (left < right) {
                    size_t mid = (left + right) / 2;
                    if (dist1 < top_distances[mid]) {
                        right = mid;
                    } else {
                        left = mid + 1;
                    }
                }
                if (left < k) {
                    std::memmove(&top_distances[left + 1], &top_distances[left], (k - left - 1) * sizeof(float));
                    std::memmove(&top_labels[left + 1], &top_labels[left], (k - left - 1) * sizeof(size_t));
                    top_distances[left] = dist1;
                    top_labels[left] = i + 1;
                }
            }
            
            // 处理第三到第八个向量
            if (dist2 < top_distances[k-1]) {
                size_t left = 0, right = k;
                while (left < right) {
                    size_t mid = (left + right) / 2;
                    dist2 < top_distances[mid] ? right = mid : left = mid + 1;
                }
                if (left < k) {
                    std::memmove(&top_distances[left + 1], &top_distances[left], (k - left - 1) * sizeof(float));
                    std::memmove(&top_labels[left + 1], &top_labels[left], (k - left - 1) * sizeof(size_t));
                    top_distances[left] = dist2;
                    top_labels[left] = i + 2;
                }
            }

            if (dist3 < top_distances[k-1]) {
                size_t left = 0, right = k;
                while (left < right) {
                    size_t mid = (left + right) / 2;
                    dist3 < top_distances[mid] ? right = mid : left = mid + 1;
                }
                if (left < k) {
                    std::memmove(&top_distances[left + 1], &top_distances[left], (k - left - 1) * sizeof(float));
                    std::memmove(&top_labels[left + 1], &top_labels[left], (k - left - 1) * sizeof(size_t));
                    top_distances[left] = dist3;
                    top_labels[left] = i + 3;
                }
            }

            if (dist4 < top_distances[k-1]) {
                size_t left = 0, right = k;
                while (left < right) {
                    size_t mid = (left + right) / 2;
                    dist4 < top_distances[mid] ? right = mid : left = mid + 1;
                }
                if (left < k) {
                    std::memmove(&top_distances[left + 1], &top_distances[left], (k - left - 1) * sizeof(float));
                    std::memmove(&top_labels[left + 1], &top_labels[left], (k - left - 1) * sizeof(size_t));
                    top_distances[left] = dist4;
                    top_labels[left] = i + 4;
                }
            }

            if (dist5 < top_distances[k-1]) {
                size_t left = 0, right = k;
                while (left < right) {
                    size_t mid = (left + right) / 2;
                    dist5 < top_distances[mid] ? right = mid : left = mid + 1;
                }
                if (left < k) {
                    std::memmove(&top_distances[left + 1], &top_distances[left], (k - left - 1) * sizeof(float));
                    std::memmove(&top_labels[left + 1], &top_labels[left], (k - left - 1) * sizeof(size_t));
                    top_distances[left] = dist5;
                    top_labels[left] = i + 5;
                }
            }

            if (dist6 < top_distances[k-1]) {
                size_t left = 0, right = k;
                while (left < right) {
                    size_t mid = (left + right) / 2;
                    dist6 < top_distances[mid] ? right = mid : left = mid + 1;
                }
                if (left < k) {
                    std::memmove(&top_distances[left + 1], &top_distances[left], (k - left - 1) * sizeof(float));
                    std::memmove(&top_labels[left + 1], &top_labels[left], (k - left - 1) * sizeof(size_t));
                    top_distances[left] = dist6;
                    top_labels[left] = i + 6;
                }
            }

            if (dist7 < top_distances[k-1]) {
                size_t left = 0, right = k;
                while (left < right) {
                    size_t mid = (left + right) / 2;
                    dist7 < top_distances[mid] ? right = mid : left = mid + 1;
                }
                if (left < k) {
                    std::memmove(&top_distances[left + 1], &top_distances[left], (k - left - 1) * sizeof(float));
                    std::memmove(&top_labels[left + 1], &top_labels[left], (k - left - 1) * sizeof(size_t));
                    top_distances[left] = dist7;
                    top_labels[left] = i + 7;
                }
            }
            
            vec += 8 * d;
            i += 8;
        }
        
        // 处理剩余的向量
        for (; i < ntotal; ++i) {
            float dist = compute_l2_distance(query, vec, d);

            if (dist < top_distances[k-1]) {
                size_t left = 0, right = k;
                while (left < right) {
                    size_t mid = (left + right) / 2;
                    dist < top_distances[mid] ? right = mid : left = mid + 1;
                }

                if (left < k) {
                    std::memmove(&top_distances[left + 1], &top_distances[left], (k - left - 1) * sizeof(float));
                    std::memmove(&top_labels[left + 1], &top_labels[left], (k - left - 1) * sizeof(size_t));
                    top_distances[left] = dist;
                    top_labels[left] = i;
                }
            }
            vec += d;
        }
    }
    
    // 填充到输出数组
    for (size_t j = 0; j < k; ++j) {
        distances[j] = top_distances[j];
        labels[j] = top_labels[j];
    }
}

// 并行处理的搜索函数，按向量分块
void IndexFlatL2::search_parallel(const float* query, size_t k, float* distances, size_t* labels) const {
    // 初始化结果
    for (size_t i = 0; i < k; ++i) {
        distances[i] = std::numeric_limits<float>::max();
        labels[i] = 0;
    }
    
    // 计算最优线程数
    size_t num_threads = std::thread::hardware_concurrency();
    
    // 基于向量数量和维度动态调整线程数
    if (ntotal > 500000) {
        num_threads = std::min(num_threads, size_t(64)); // 超大数据集使用更多线程
    } else if (ntotal > 100000) {
        num_threads = std::min(num_threads, size_t(32)); // 大数据集使用32线程
    } else if (ntotal > 10000) {
        num_threads = std::min(num_threads, size_t(16)); // 中等数据集使用16线程
    } else {
        num_threads = std::min(num_threads, size_t(4)); // 小数据集使用更少线程
    }
    
    // 对于高维向量，减少线程数以避免寄存器竞争
    if (d > 256) {
        num_threads = std::max(size_t(1), num_threads / 4);
    } else if (d > 128) {
        num_threads = std::max(size_t(1), num_threads / 2);
    }
    
    // 确保至少有一个线程
    num_threads = std::max(size_t(1), num_threads);
    
    // 计算每个线程处理的向量数量，确保每个线程至少处理1000个向量
    size_t min_vectors_per_thread = 1000;
    size_t max_threads = std::min(num_threads, ntotal / min_vectors_per_thread + 1);
    max_threads = std::max(size_t(1), max_threads);
    
    size_t vectors_per_thread = ntotal / max_threads;
    size_t remainder = ntotal % max_threads;
    
    // 使用线程局部存储来减少线程间竞争
    std::vector<std::vector<float>> thread_distances(max_threads, std::vector<float>(k, std::numeric_limits<float>::max()));
    std::vector<std::vector<size_t>> thread_labels(max_threads, std::vector<size_t>(k, 0));
    
    std::vector<std::thread> threads;
    threads.reserve(max_threads);
    
    size_t current_start = 0;
    for (size_t t = 0; t < max_threads; ++t) {
        size_t thread_vectors = vectors_per_thread + (t < remainder ? 1 : 0);
        size_t start = current_start;
        size_t end = current_start + thread_vectors;
        current_start = end;
        
        threads.emplace_back([this, query, start, end, k, &thread_distances, &thread_labels, t]() {
            // 预取查询向量到缓存
            __builtin_prefetch(query, 0, 0);
            __builtin_prefetch(query + 64, 0, 0);
            __builtin_prefetch(query + 128, 0, 0);
            __builtin_prefetch(query + 192, 0, 0);
            
            // 计算每个批量的大小，根据维度调整
            size_t batch_size = 128;
            if (this->d > 256) {
                batch_size = 32; // 高维向量减少批量大小
            } else if (this->d > 128) {
                batch_size = 64; // 中高维向量适当减少批量大小
            } else if (this->d > 64) {
                batch_size = 96; // 中维向量使用适中批量大小
            }
            
            if (this->transposed) {
                // 使用转置数据进行搜索，一次性计算多个向量
                size_t i = start;
                float batch_dists[128];

                // 批量处理
                while (i + batch_size - 1 < end) {
                    this->compute_batch_distances_transposed(query, i, batch_size, batch_dists);

                    for (size_t j = 0; j < batch_size; ++j) {
                        float dist = batch_dists[j];
                        if (dist < thread_distances[t][k-1]) {
                            size_t idx = 0;
                            while (idx < k && dist >= thread_distances[t][idx]) idx++;
                            if (idx < k) {
                                for (size_t l = k - 1; l > idx; --l) {
                                    thread_distances[t][l] = thread_distances[t][l - 1];
                                    thread_labels[t][l] = thread_labels[t][l - 1];
                                }
                                thread_distances[t][idx] = dist;
                                thread_labels[t][idx] = i + j;
                            }
                        }
                    }
                    i += batch_size;
                }

                // 处理剩余的向量
                if (i < end) {
                    size_t remaining = end - i;
                    this->compute_batch_distances_transposed(query, i, remaining, batch_dists);

                    for (size_t j = 0; j < remaining; ++j) {
                        float dist = batch_dists[j];
                        if (dist < thread_distances[t][k-1]) {
                            size_t idx = 0;
                            while (idx < k && dist >= thread_distances[t][idx]) idx++;
                            if (idx < k) {
                                for (size_t l = k - 1; l > idx; --l) {
                                    thread_distances[t][l] = thread_distances[t][l - 1];
                                    thread_labels[t][l] = thread_labels[t][l - 1];
                                }
                                thread_distances[t][idx] = dist;
                                thread_labels[t][idx] = i + j;
                            }
                        }
                    }
                }
            } else {
                // 使用原始数据进行搜索
                const float* vec = this->xb.data() + start * this->d;
                size_t i = start;
                
                // 批量处理
                while (i + batch_size - 1 < end) {
                    // 软件预取，减少内存访问延迟
                    size_t prefetch_distance = batch_size;
                    __builtin_prefetch(vec + this->d * batch_size, 0, 3);
                    __builtin_prefetch(vec + this->d * (batch_size + prefetch_distance), 0, 3);
                    __builtin_prefetch(vec + this->d * (batch_size + 2 * prefetch_distance), 0, 3);
                    
                    // 计算批量内所有向量的距离
                    for (size_t j = 0; j < batch_size; ++j) {
                        float dist = this->compute_l2_distance(query, vec + j * this->d, this->d);
                        
                        if (dist < thread_distances[t][k-1]) {
                            size_t idx = 0;
                            while (idx < k && dist >= thread_distances[t][idx]) idx++;
                            if (idx < k) {
                                // 优化插入操作，减少内存移动
                                for (size_t l = k - 1; l > idx; --l) {
                                    thread_distances[t][l] = thread_distances[t][l - 1];
                                    thread_labels[t][l] = thread_labels[t][l - 1];
                                }
                                thread_distances[t][idx] = dist;
                                thread_labels[t][idx] = i + j;
                            }
                        }
                    }
                    
                    vec += batch_size * this->d;
                    i += batch_size;
                }
                
                // 处理剩余的向量
                for (; i < end; ++i) {
                    float dist = this->compute_l2_distance(query, vec, this->d);
                    
                    if (dist < thread_distances[t][k-1]) {
                        size_t idx = 0;
                        while (idx < k && dist >= thread_distances[t][idx]) idx++;
                        
                        if (idx < k) {
                            for (size_t l = k - 1; l > idx; --l) {
                                thread_distances[t][l] = thread_distances[t][l - 1];
                                thread_labels[t][l] = thread_labels[t][l - 1];
                            }
                            thread_distances[t][idx] = dist;
                            thread_labels[t][idx] = i;
                        }
                    }
                    vec += this->d;
                }
            }
        });
    }
    
    // 等待所有线程完成
    for (auto& thread : threads) {
        thread.join();
    }
    
    // 合并所有线程的结果
    for (size_t t = 0; t < max_threads; ++t) {
        for (size_t i = 0; i < k; ++i) {
            float dist = thread_distances[t][i];
            size_t label = thread_labels[t][i];
            
            if (dist < distances[k-1]) {
                size_t idx = 0;
                while (idx < k && dist >= distances[idx]) idx++;
                
                if (idx < k) {
                    for (size_t l = k - 1; l > idx; --l) {
                        distances[l] = distances[l - 1];
                        labels[l] = labels[l - 1];
                    }
                    distances[idx] = dist;
                    labels[idx] = label;
                }
            }
        }
    }
}

// 并行处理的搜索函数
void IndexFlatL2::search(size_t n, const float* x, size_t k, float* distances, size_t* labels) const {
    if (d == 0) {
        throw std::invalid_argument("Dimension not set");
    }
    
    if (ntotal == 0) {
        // 空数据库，返回默认值
        for (size_t i = 0; i < n * k; ++i) {
            distances[i] = 0.0f;
            labels[i] = 0;
        }
        return;
    }
    
    // 计算最优线程数
    size_t num_threads = std::thread::hardware_concurrency();

    // 基于数据集大小和查询数量动态调整
    if (ntotal > 500000 && n >= 10) {
        num_threads = std::min(num_threads, size_t(32));
    } else if (ntotal > 100000 && n >= 10) {
        num_threads = std::min(num_threads, size_t(16));
    } else if (n < 4) {
        num_threads = std::min(num_threads, size_t(8));
    }

    // 高维向量减少线程数
    if (d > 256) {
        num_threads = std::max(size_t(1), num_threads / 2);
    }

    num_threads = std::max(size_t(1), num_threads);
    
    // 对于单个查询，使用向量级并行而不是查询级并行
    if (num_threads > 1) {
        if (n == 1) {
            // 单个查询时，使用向量分块并行处理
            const float* query = x;
            float* dist_ptr = distances;
            size_t* label_ptr = labels;
            search_parallel(query, k, dist_ptr, label_ptr);
        } else {
            // 多个查询时，使用查询级并行
            std::vector<std::thread> threads;
            threads.reserve(num_threads);
            
            size_t queries_per_thread = n / num_threads;
            size_t remainder = n % num_threads;
            
            size_t current_start = 0;
            for (size_t t = 0; t < num_threads; ++t) {
                size_t thread_queries = queries_per_thread + (t < remainder ? 1 : 0);
                size_t start = current_start;
                size_t end = current_start + thread_queries;
                current_start = end;
                
                threads.emplace_back([this, start, end, x, k, distances, labels]() {
                    // 为每个线程分配独立的工作空间，减少内存竞争
                    // 预取查询向量到缓存
                    for (size_t i = start; i < end; ++i) {
                        const float* query = x + i * this->d;
                        // 预取查询向量
                        __builtin_prefetch(query, 0, 0);
                        __builtin_prefetch(query + 64, 0, 0);
                        __builtin_prefetch(query + 128, 0, 0);
                        __builtin_prefetch(query + 192, 0, 0);
                    }
                    
                    // 处理查询
                    for (size_t i = start; i < end; ++i) {
                        const float* query = x + i * this->d;
                        float* dist_ptr = distances + i * k;
                        size_t* label_ptr = labels + i * k;
                        this->search_single(query, k, dist_ptr, label_ptr);
                    }
                });
            }
            
            // 等待所有线程完成
            for (auto& thread : threads) {
                thread.join();
            }
        }
    } else {
        // 单线程处理
        // 预取查询向量到缓存
        for (size_t i = 0; i < n; ++i) {
            const float* query = x + i * d;
            // 预取查询向量
            __builtin_prefetch(query, 0, 0);
            __builtin_prefetch(query + 64, 0, 0);
            __builtin_prefetch(query + 128, 0, 0);
            __builtin_prefetch(query + 192, 0, 0);
        }
        
        // 处理查询
        for (size_t i = 0; i < n; ++i) {
            const float* query = x + i * d;
            float* dist_ptr = distances + i * k;
            size_t* label_ptr = labels + i * k;
            search_single(query, k, dist_ptr, label_ptr);
        }
    }
}

size_t IndexFlatL2::size() const {
    return ntotal;
}

size_t IndexFlatL2::get_dimension() const {
    return d;
}