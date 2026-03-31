#include "vector_db.h"
#include <stdexcept>
#include <thread>
#include <vector>
#include <algorithm>
#include <execution>
#include <numeric>

IndexFlatL2::IndexFlatL2(size_t dimension) : d(dimension), ntotal(0) {
    // 预分配更大的空间，可容纳100万个向量
    size_t reserve_size = 1000000 * dimension;
    xb.reserve(reserve_size);
}

void IndexFlatL2::add(size_t n, const float* x) {
    if (d == 0) {
        throw std::invalid_argument("Dimension not set");
    }
    
    // 批量添加n个向量，每个向量维度为d
    xb.insert(xb.end(), x, x + n * d);
    ntotal += n;
}

// 优化的L2距离计算，使用SIMD指令（内联函数）
inline float IndexFlatL2::compute_l2_distance(const float* query, const float* vec, size_t dim) const {
    // 针对大数据集优化：使用更高效的SIMD处理和内存访问模式
    float dist = 0.0f;
    
    // 对于大维度向量，使用更高效的SIMD处理
    if (dim >= 32) {
        // 展开循环，减少分支预测开销
        size_t i = 0;
        __m256 sum = _mm256_setzero_ps();
        
        // 处理每32个元素，使用连续内存访问
        size_t end = dim - 31;
        while (i < end) {
            // 软件预取，减少内存访问延迟
            __builtin_prefetch(vec + i + 128, 0, 3);
            __builtin_prefetch(vec + i + 256, 0, 3);
            __builtin_prefetch(vec + i + 384, 0, 3);
            __builtin_prefetch(vec + i + 512, 0, 3);
            
            // 一次处理32个元素，使用4个AVX2寄存器
            __m256 q0 = _mm256_loadu_ps(query + i);
            __m256 v0 = _mm256_loadu_ps(vec + i);
            __m256 q1 = _mm256_loadu_ps(query + i + 8);
            __m256 v1 = _mm256_loadu_ps(vec + i + 8);
            __m256 q2 = _mm256_loadu_ps(query + i + 16);
            __m256 v2 = _mm256_loadu_ps(vec + i + 16);
            __m256 q3 = _mm256_loadu_ps(query + i + 24);
            __m256 v3 = _mm256_loadu_ps(vec + i + 24);
            
            // 使用融合乘加指令，减少寄存器压力
            sum = _mm256_fmadd_ps(_mm256_sub_ps(q0, v0), _mm256_sub_ps(q0, v0), sum);
            sum = _mm256_fmadd_ps(_mm256_sub_ps(q1, v1), _mm256_sub_ps(q1, v1), sum);
            sum = _mm256_fmadd_ps(_mm256_sub_ps(q2, v2), _mm256_sub_ps(q2, v2), sum);
            sum = _mm256_fmadd_ps(_mm256_sub_ps(q3, v3), _mm256_sub_ps(q3, v3), sum);
            
            i += 32;
        }
        
        // 水平求和，使用更高效的指令
        __m256 shuffled = _mm256_permute2f128_ps(sum, sum, 0x21);
        __m256 summed = _mm256_add_ps(sum, shuffled);
        summed = _mm256_hadd_ps(summed, summed);
        summed = _mm256_hadd_ps(summed, summed);
        dist = _mm256_cvtss_f32(summed);
        
        // 处理剩余元素
        for (; i < dim; ++i) {
            float diff = query[i] - vec[i];
            dist += diff * diff;
        }
    } else if (dim >= 16) {
        size_t i = 0;
        __m256 sum = _mm256_setzero_ps();
        
        // 处理每16个元素
        size_t end = dim - 15;
        while (i < end) {
            // 软件预取，减少内存访问延迟
            __builtin_prefetch(vec + i + 64, 0, 3);
            __builtin_prefetch(vec + i + 128, 0, 3);
            
            __m256 q0 = _mm256_loadu_ps(query + i);
            __m256 v0 = _mm256_loadu_ps(vec + i);
            __m256 q1 = _mm256_loadu_ps(query + i + 8);
            __m256 v1 = _mm256_loadu_ps(vec + i + 8);
            
            // 使用融合乘加指令，减少寄存器压力
            sum = _mm256_fmadd_ps(_mm256_sub_ps(q0, v0), _mm256_sub_ps(q0, v0), sum);
            sum = _mm256_fmadd_ps(_mm256_sub_ps(q1, v1), _mm256_sub_ps(q1, v1), sum);
            
            i += 16;
        }
        
        // 水平求和
        __m256 shuffled = _mm256_permute2f128_ps(sum, sum, 0x21);
        __m256 summed = _mm256_add_ps(sum, shuffled);
        summed = _mm256_hadd_ps(summed, summed);
        summed = _mm256_hadd_ps(summed, summed);
        dist = _mm256_cvtss_f32(summed);
        
        // 处理剩余元素
        for (; i < dim; ++i) {
            float diff = query[i] - vec[i];
            dist += diff * diff;
        }
    } else if (dim >= 8) {
        size_t i = 0;
        __m256 sum = _mm256_setzero_ps();
        
        // 处理每8个元素
        size_t end = dim - 7;
        while (i < end) {
            // 软件预取，减少内存访问延迟
            __builtin_prefetch(vec + i + 32, 0, 3);
            __builtin_prefetch(vec + i + 64, 0, 3);
            
            __m256 q = _mm256_loadu_ps(query + i);
            __m256 v = _mm256_loadu_ps(vec + i);
            
            // 使用融合乘加指令
            sum = _mm256_fmadd_ps(_mm256_sub_ps(q, v), _mm256_sub_ps(q, v), sum);
            
            i += 8;
        }
        
        // 水平求和
        __m256 shuffled = _mm256_permute2f128_ps(sum, sum, 0x21);
        __m256 summed = _mm256_add_ps(sum, shuffled);
        summed = _mm256_hadd_ps(summed, summed);
        summed = _mm256_hadd_ps(summed, summed);
        dist = _mm256_cvtss_f32(summed);
        
        // 处理剩余元素
        for (; i < dim; ++i) {
            float diff = query[i] - vec[i];
            dist += diff * diff;
        }
    } else if (dim >= 4) {
        // 对于中等维度，使用SSE指令
        size_t i = 0;
        __m128 sum = _mm_setzero_ps();
        
        // 处理每4个元素
        size_t end = dim - 3;
        while (i < end) {
            // 软件预取，减少内存访问延迟
            __builtin_prefetch(vec + i + 16, 0, 3);
            __builtin_prefetch(vec + i + 32, 0, 3);
            
            __m128 q = _mm_loadu_ps(query + i);
            __m128 v = _mm_loadu_ps(vec + i);
            
            // 使用融合乘加指令
            sum = _mm_fmadd_ps(_mm_sub_ps(q, v), _mm_sub_ps(q, v), sum);
            
            i += 4;
        }
        
        // 水平求和
        __m128 summed = _mm_hadd_ps(sum, sum);
        summed = _mm_hadd_ps(summed, summed);
        dist = _mm_cvtss_f32(summed);
        
        // 处理剩余元素
        for (; i < dim; ++i) {
            float diff = query[i] - vec[i];
            dist += diff * diff;
        }
    } else {
        // 对于小维度，直接计算
        for (size_t i = 0; i < dim; ++i) {
            float diff = query[i] - vec[i];
            dist += diff * diff;
        }
    }
    
    return dist;
}

// 批量处理向量的搜索函数，使用SIMD加速
void IndexFlatL2::search_batch(const float* query, size_t k, float* distances, size_t* labels) const {
    // 使用固定大小的数组来维护top-k结果，避免优先队列的开销
    float top_distances[k];
    size_t top_labels[k];
    
    // 初始化
    for (size_t i = 0; i < k; ++i) {
        top_distances[i] = std::numeric_limits<float>::max();
        top_labels[i] = 0;
    }
    
    // 针对大数据集优化：使用SIMD批量处理
    const size_t batch_size = 8; // 一次处理8个向量
    const float* vec = xb.data();
    
    // 批量处理向量
    size_t total_batches = (ntotal + batch_size - 1) / batch_size;
    for (size_t batch_idx = 0; batch_idx < total_batches; ++batch_idx) {
        size_t start = batch_idx * batch_size;
        size_t end = std::min(start + batch_size, ntotal);
        
        // 处理一批向量
        for (size_t b = start; b < end; ++b) {
            float dist = compute_l2_distance(query, vec, d);
            
            // 优化top-k维护：使用线性扫描但提前终止
            if (dist < top_distances[k-1]) {
                // 线性扫描找到插入位置，对于小k来说更快
                size_t idx = 0;
                while (idx < k && dist >= top_distances[idx]) {
                    idx++;
                }
                
                if (idx < k) {
                    // 移动元素
                    for (size_t l = k - 1; l > idx; --l) {
                        top_distances[l] = top_distances[l - 1];
                        top_labels[l] = top_labels[l - 1];
                    }
                    top_distances[idx] = dist;
                    top_labels[idx] = b;
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
    
    // 针对大数据集优化：使用更高效的内存访问模式
    const size_t batch_size = (d > 128) ? 8192 : 16384; // 根据维度调整批处理大小
    const float* vec = xb.data();
    
    // 批量处理向量，使用连续内存访问
    size_t total_batches = (ntotal + batch_size - 1) / batch_size;
    for (size_t batch_idx = 0; batch_idx < total_batches; ++batch_idx) {
        size_t start = batch_idx * batch_size;
        size_t end = std::min(start + batch_size, ntotal);
        
        // 软件预取整个批次的数据，使用更激进的预取策略
        __builtin_prefetch(vec, 0, 3);
        __builtin_prefetch(vec + d * batch_size, 0, 3);
        __builtin_prefetch(vec + d * batch_size * 2, 0, 3);
        __builtin_prefetch(vec + d * batch_size * 3, 0, 3);
        __builtin_prefetch(vec + d * batch_size * 4, 0, 3);
        
        // 处理一批向量，使用循环展开提高性能
        size_t b = start;
        // 展开4次循环，减少分支开销和寄存器压力
        while (b + 3 < end) {
            // 计算四个向量的距离
            float dist0 = compute_l2_distance(query, vec, d);
            float dist1 = compute_l2_distance(query, vec + d, d);
            float dist2 = compute_l2_distance(query, vec + 2 * d, d);
            float dist3 = compute_l2_distance(query, vec + 3 * d, d);
            
            // 处理第一个向量
            if (dist0 < top_distances[k-1]) {
                size_t idx = 0;
                while (idx < k && dist0 >= top_distances[idx]) {
                    idx++;
                }
                if (idx < k) {
                    for (size_t l = k - 1; l > idx; --l) {
                        top_distances[l] = top_distances[l - 1];
                        top_labels[l] = top_labels[l - 1];
                    }
                    top_distances[idx] = dist0;
                    top_labels[idx] = b;
                }
            }
            
            // 处理第二个向量
            if (dist1 < top_distances[k-1]) {
                size_t idx = 0;
                while (idx < k && dist1 >= top_distances[idx]) {
                    idx++;
                }
                if (idx < k) {
                    for (size_t l = k - 1; l > idx; --l) {
                        top_distances[l] = top_distances[l - 1];
                        top_labels[l] = top_labels[l - 1];
                    }
                    top_distances[idx] = dist1;
                    top_labels[idx] = b + 1;
                }
            }
            
            // 处理第三个向量
            if (dist2 < top_distances[k-1]) {
                size_t idx = 0;
                while (idx < k && dist2 >= top_distances[idx]) {
                    idx++;
                }
                if (idx < k) {
                    for (size_t l = k - 1; l > idx; --l) {
                        top_distances[l] = top_distances[l - 1];
                        top_labels[l] = top_labels[l - 1];
                    }
                    top_distances[idx] = dist2;
                    top_labels[idx] = b + 2;
                }
            }
            
            // 处理第四个向量
            if (dist3 < top_distances[k-1]) {
                size_t idx = 0;
                while (idx < k && dist3 >= top_distances[idx]) {
                    idx++;
                }
                if (idx < k) {
                    for (size_t l = k - 1; l > idx; --l) {
                        top_distances[l] = top_distances[l - 1];
                        top_labels[l] = top_labels[l - 1];
                    }
                    top_distances[idx] = dist3;
                    top_labels[idx] = b + 3;
                }
            }
            
            vec += 4 * d;
            b += 4;
        }
        
        // 处理剩余的向量
        for (; b < end; ++b) {
            float dist = compute_l2_distance(query, vec, d);
            
            // 优化top-k维护：使用线性扫描但提前终止
            if (dist < top_distances[k-1]) {
                // 线性扫描找到插入位置，对于小k来说更快
                size_t idx = 0;
                while (idx < k && dist >= top_distances[idx]) {
                    idx++;
                }
                
                if (idx < k) {
                    // 移动元素
                    for (size_t l = k - 1; l > idx; --l) {
                        top_distances[l] = top_distances[l - 1];
                        top_labels[l] = top_labels[l - 1];
                    }
                    top_distances[idx] = dist;
                    top_labels[idx] = b;
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
    
    // 针对大数据集优化：使用更高效的并行策略
    size_t num_threads = std::thread::hardware_concurrency();
    
    // 动态调整线程数，根据数据集大小和维度
    if (ntotal > 100000) {
        num_threads = std::min(num_threads, size_t(32)); // 最多使用32线程
    } else if (ntotal > 10000) {
        num_threads = std::min(num_threads, size_t(16)); // 中等数据集使用16线程
    } else {
        num_threads = std::min(num_threads, std::max(size_t(1), n / 2)); // 小数据集每个线程至少处理2个查询
    }
    
    // 对于高维向量，减少线程数以避免寄存器竞争
    if (d > 128) {
        num_threads = std::max(size_t(1), num_threads / 2);
    }
    
    // 对于单个查询，使用向量级并行而不是查询级并行
    if (num_threads > 1) {
        if (n == 1) {
            // 单个查询时，将向量数据集分成多个块并行处理
            const float* query = x;
            float* dist_ptr = distances;
            size_t* label_ptr = labels;
            
            // 初始化结果
            for (size_t i = 0; i < k; ++i) {
                dist_ptr[i] = std::numeric_limits<float>::max();
                label_ptr[i] = 0;
            }
            
            // 计算每个线程处理的向量数量
            size_t vectors_per_thread = ntotal / num_threads;
            size_t remainder = ntotal % num_threads;
            
            // 使用线程局部存储来减少线程间竞争
            std::vector<std::vector<float>> thread_distances(num_threads, std::vector<float>(k, std::numeric_limits<float>::max()));
            std::vector<std::vector<size_t>> thread_labels(num_threads, std::vector<size_t>(k, 0));
            
            std::vector<std::thread> threads;
            threads.reserve(num_threads);
            
            size_t current_start = 0;
            for (size_t t = 0; t < num_threads; ++t) {
                size_t thread_vectors = vectors_per_thread + (t < remainder ? 1 : 0);
                size_t start = current_start;
                size_t end = current_start + thread_vectors;
                current_start = end;
                
                threads.emplace_back([this, query, start, end, k, &thread_distances, &thread_labels, t]() {
                    const float* vec = xb.data() + start * this->d;
                    
                    // 根据维度调整批处理大小
                    const size_t batch_size = (this->d > 128) ? 8192 : 16384;
                    size_t batch_start = start;
                    while (batch_start < end) {
                        size_t batch_end = std::min(batch_start + batch_size, end);
                        
                        // 软件预取
                        __builtin_prefetch(vec, 0, 3);
                        __builtin_prefetch(vec + this->d * batch_size, 0, 3);
                        __builtin_prefetch(vec + this->d * batch_size * 2, 0, 3);
                        __builtin_prefetch(vec + this->d * batch_size * 3, 0, 3);
                        __builtin_prefetch(vec + this->d * batch_size * 4, 0, 3);
                        
                        // 处理一批向量，使用循环展开提高性能
                        size_t b = batch_start;
                        // 展开4次循环，减少分支开销和寄存器压力
                        while (b + 3 < batch_end) {
                            // 计算四个向量的距离
                            float dist0 = compute_l2_distance(query, vec, this->d);
                            float dist1 = compute_l2_distance(query, vec + this->d, this->d);
                            float dist2 = compute_l2_distance(query, vec + 2 * this->d, this->d);
                            float dist3 = compute_l2_distance(query, vec + 3 * this->d, this->d);
                            
                            // 处理第一个向量
                            if (dist0 < thread_distances[t][k-1]) {
                                size_t idx = 0;
                                while (idx < k && dist0 >= thread_distances[t][idx]) {
                                    idx++;
                                }
                                if (idx < k) {
                                    for (size_t l = k - 1; l > idx; --l) {
                                        thread_distances[t][l] = thread_distances[t][l - 1];
                                        thread_labels[t][l] = thread_labels[t][l - 1];
                                    }
                                    thread_distances[t][idx] = dist0;
                                    thread_labels[t][idx] = b;
                                }
                            }
                            
                            // 处理第二个向量
                            if (dist1 < thread_distances[t][k-1]) {
                                size_t idx = 0;
                                while (idx < k && dist1 >= thread_distances[t][idx]) {
                                    idx++;
                                }
                                if (idx < k) {
                                    for (size_t l = k - 1; l > idx; --l) {
                                        thread_distances[t][l] = thread_distances[t][l - 1];
                                        thread_labels[t][l] = thread_labels[t][l - 1];
                                    }
                                    thread_distances[t][idx] = dist1;
                                    thread_labels[t][idx] = b + 1;
                                }
                            }
                            
                            // 处理第三个向量
                            if (dist2 < thread_distances[t][k-1]) {
                                size_t idx = 0;
                                while (idx < k && dist2 >= thread_distances[t][idx]) {
                                    idx++;
                                }
                                if (idx < k) {
                                    for (size_t l = k - 1; l > idx; --l) {
                                        thread_distances[t][l] = thread_distances[t][l - 1];
                                        thread_labels[t][l] = thread_labels[t][l - 1];
                                    }
                                    thread_distances[t][idx] = dist2;
                                    thread_labels[t][idx] = b + 2;
                                }
                            }
                            
                            // 处理第四个向量
                            if (dist3 < thread_distances[t][k-1]) {
                                size_t idx = 0;
                                while (idx < k && dist3 >= thread_distances[t][idx]) {
                                    idx++;
                                }
                                if (idx < k) {
                                    for (size_t l = k - 1; l > idx; --l) {
                                        thread_distances[t][l] = thread_distances[t][l - 1];
                                        thread_labels[t][l] = thread_labels[t][l - 1];
                                    }
                                    thread_distances[t][idx] = dist3;
                                    thread_labels[t][idx] = b + 3;
                                }
                            }
                            
                            vec += 4 * this->d;
                            b += 4;
                        }
                        
                        // 处理剩余的向量
                        for (; b < batch_end; ++b) {
                            float dist = compute_l2_distance(query, vec, this->d);
                            
                            if (dist < thread_distances[t][k-1]) {
                                size_t idx = 0;
                                while (idx < k && dist >= thread_distances[t][idx]) {
                                    idx++;
                                }
                                
                                if (idx < k) {
                                    for (size_t l = k - 1; l > idx; --l) {
                                        thread_distances[t][l] = thread_distances[t][l - 1];
                                        thread_labels[t][l] = thread_labels[t][l - 1];
                                    }
                                    thread_distances[t][idx] = dist;
                                    thread_labels[t][idx] = b;
                                }
                            }
                            vec += this->d;
                        }
                        
                        batch_start = batch_end;
                    }
                });
            }
            
            // 等待所有线程完成
            for (auto& thread : threads) {
                thread.join();
            }
            
            // 合并所有线程的结果
            for (size_t t = 0; t < num_threads; ++t) {
                for (size_t i = 0; i < k; ++i) {
                    float dist = thread_distances[t][i];
                    size_t label = thread_labels[t][i];
                    
                    if (dist < dist_ptr[k-1]) {
                        size_t idx = 0;
                        while (idx < k && dist >= dist_ptr[idx]) {
                            idx++;
                        }
                        
                        if (idx < k) {
                            for (size_t l = k - 1; l > idx; --l) {
                                dist_ptr[l] = dist_ptr[l - 1];
                                label_ptr[l] = label_ptr[l - 1];
                            }
                            dist_ptr[idx] = dist;
                            label_ptr[idx] = label;
                        }
                    }
                }
            }
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