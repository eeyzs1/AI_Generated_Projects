use pyo3::prelude::*;
use rayon::prelude::*;
use std::arch::x86_64::*;
use num_cpus;

#[pyclass]
struct FlatIndex {
    vectors: Vec<f32>,
    vectors_transposed: Vec<f32>,
    dimension: usize,
    size: usize,
    transposed: bool,
}

#[pymethods]
impl FlatIndex {
    #[new]
    fn new() -> Self {
        Self {
            vectors: Vec::new(),
            vectors_transposed: Vec::new(),
            dimension: 0,
            size: 0,
            transposed: false,
        }
    }

    fn add(&mut self, vectors: Vec<Vec<f32>>) -> PyResult<()> {
        if vectors.is_empty() {
            return Ok(());
        }

        let first_dim = vectors[0].len();
        if self.dimension == 0 {
            self.dimension = first_dim;
        } else if self.dimension != first_dim {
            return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                "All vectors must have the same dimension",
            ));
        }

        // 批量扩展，减少内存分配次数
        let num_vectors = vectors.len();
        let total_elements = num_vectors * self.dimension;
        
        // 一次性分配所有内存
        let current_len = self.vectors.len();
        self.vectors.reserve_exact(current_len + total_elements);
        
        // 直接扩展容量，避免多次分配
        self.vectors.resize(current_len + total_elements, 0.0f32);
        
        // 顺序处理向量数据，使用更高效的内存操作
        let mut offset = current_len;
        for vec in vectors {
            if vec.len() != self.dimension {
                return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                    "All vectors must have the same dimension",
                ));
            }
            // 直接拷贝数据到预分配的空间
            self.vectors[offset..offset + self.dimension].copy_from_slice(&vec);
            offset += self.dimension;
        }

        self.size += num_vectors;

        // 转置数据以优化内存布局
        self.transpose_data();

        Ok(())
    }

    fn add_buf(&mut self, buffer: &Bound<'_, PyAny>) -> PyResult<()> {
        use pyo3::buffer::PyBuffer;
        
        // 尝试将输入转换为缓冲区
        let buffer = PyBuffer::<f32>::get(buffer)?;
        let dimensions = buffer.dimensions();
        
        if dimensions != 2 {
            return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                "Input must be a 2D array",
            ));
        }
        
        let shape = buffer.shape();
        let num_vectors = shape[0];
        let first_dim = shape[1];
        
        if num_vectors == 0 {
            return Ok(());
        }
        
        if self.dimension == 0 {
            self.dimension = first_dim;
        } else if self.dimension != first_dim {
            return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                "All vectors must have the same dimension",
            ));
        }
        
        // 批量扩展，减少内存分配次数
        let total_elements = num_vectors * self.dimension;
        
        // 一次性分配所有内存
        let current_len = self.vectors.len();
        self.vectors.reserve_exact(current_len + total_elements);
        
        // 直接扩展容量，避免多次分配
        self.vectors.resize(current_len + total_elements, 0.0f32);
        
        // 直接拷贝数据到预分配的空间
        let buffer_ptr = buffer.buf_ptr() as *const f32;
        unsafe {
            std::ptr::copy_nonoverlapping(
                buffer_ptr,
                self.vectors.as_mut_ptr().add(current_len),
                total_elements
            );
        }

        self.size += num_vectors;

        // 转置数据以优化内存布局
        self.transpose_data();
        
        Ok(())
    }

    fn search(&self, query: Vec<f32>, k: usize) -> PyResult<(Vec<i64>, Vec<f32>)> {
        if self.size == 0 {
            return Ok((Vec::new(), Vec::new()));
        }

        if query.len() != self.dimension {
            return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                "Query vector dimension mismatch",
            ));
        }

        // 对于小数据集，直接使用优化的单线程搜索以避免多线程开销
        if self.size <= 10000 {
            return self.search_single(&query, k);
        }

        // 计算最优线程数
        let num_threads = self.calculate_optimal_threads();

        if num_threads > 1 {
            // 并行搜索
            self.search_parallel(&query, k)
        } else {
            // 单线程搜索
            self.search_single(&query, k)
        }
    }

    fn search_buf(&self, buffer: &Bound<'_, PyAny>, k: usize) -> PyResult<(Vec<i64>, Vec<f32>)> {
        use pyo3::buffer::PyBuffer;
        
        if self.size == 0 {
            return Ok((Vec::new(), Vec::new()));
        }
        
        // 尝试将输入转换为缓冲区
        let buffer = PyBuffer::<f32>::get(buffer)?;
        let dimensions = buffer.dimensions();
        
        if dimensions != 2 {
            return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                "Input must be a 2D array",
            ));
        }
        
        let shape = buffer.shape();
        let rows = shape[0];
        let cols = shape[1];
        
        if rows != 1 {
            return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                "Input must be a 2D array with shape (1, dimension)",
            ));
        }
        
        let dim = cols;
        
        if dim != self.dimension {
            return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                "Query vector dimension mismatch",
            ));
        }
        
        // 直接获取缓冲区数据
        let mut query_vec = Vec::with_capacity(dim);
        let buffer_ptr = buffer.buf_ptr() as *const f32;
        unsafe {
            for j in 0..dim {
                let value = *buffer_ptr.offset(j as isize);
                query_vec.push(value);
            }
        }
        
        // 计算最优线程数
        // 对于小数据集，直接使用优化的单线程搜索以避免多线程开销
        if self.size <= 10000 {
            return self.search_single(&query_vec, k);
        }

        let num_threads = self.calculate_optimal_threads();

        if num_threads > 1 {
            // 并行搜索
            self.search_parallel(&query_vec, k)
        } else {
            // 单线程搜索
            self.search_single(&query_vec, k)
        }
    }

    fn size(&self) -> usize {
        self.size
    }

    fn dimension(&self) -> usize {
        self.dimension
    }
}

impl FlatIndex {
    // 计算最优线程数
    fn calculate_optimal_threads(&self) -> usize {
        let num_threads = num_cpus::get();
        
        // 根据数据集大小和维度调整线程数
        let mut num_threads = if self.size > 1000000 {
            std::cmp::min(num_threads, 16)  // 大数据集可以用更多线程
        } else if self.size > 100000 {
            std::cmp::min(num_threads, 8)   // 中等数据集
        } else if self.size > 10000 {
            std::cmp::min(num_threads, 4)   // 小数据集用较少线程
        } else {
            1  // 极小数据集用单线程避免开销
        };

        // 对于高维向量，减少线程数以避免内存带宽瓶颈
        if self.dimension > 512 {
            num_threads = std::cmp::max(1, num_threads / 4);
        } else if self.dimension > 256 {
            num_threads = std::cmp::max(1, num_threads / 2);
        }

        num_threads
    }

    // 转置数据以优化内存布局
    fn transpose_data(&mut self) {
        // 大数据集时不转置（stride 太大会破坏缓存）
        if self.size > 100000 {
            self.transposed = false;
            self.vectors_transposed.clear();
            self.vectors_transposed.shrink_to_fit();
            return;
        }

        if self.size == 0 || self.dimension == 0 {
            return;
        }

        // 分配转置后的数据空间
        self.vectors_transposed.resize(self.size * self.dimension, 0.0f32);

        // 执行转置操作：将行优先转换为列优先
        for i in 0..self.size {
            for j in 0..self.dimension {
                self.vectors_transposed[j * self.size + i] = self.vectors[i * self.dimension + j];
            }
        }

        self.transposed = true;
    }

    // 计算L2距离（使用SIMD优化）
    #[inline]
    fn compute_l2_distance(&self, query: &[f32], vec: &[f32]) -> f32 {
        let dim = self.dimension;

        #[cfg(target_arch = "x86_64")]
        unsafe {
            if dim >= 32 {
                // 使用更多的寄存器重用和循环展开来最大化吞吐量
                let mut i = 0;
                let mut sum0 = _mm256_setzero_ps();
                let mut sum1 = _mm256_setzero_ps();
                let mut sum2 = _mm256_setzero_ps();
                let mut sum3 = _mm256_setzero_ps();

                // 预取整个向量，减少内存延迟
                std::arch::x86_64::_mm_prefetch(
                    vec.as_ptr() as *const i8,
                    std::arch::x86_64::_MM_HINT_T0
                );
                std::arch::x86_64::_mm_prefetch(
                    query.as_ptr() as *const i8,
                    std::arch::x86_64::_MM_HINT_T0
                );

                let end = dim - 31;
                while i < end {
                    // 预取未来数据
                    if i + 64 < dim {
                        std::arch::x86_64::_mm_prefetch(
                            vec.as_ptr().add(i + 64) as *const i8,
                            std::arch::x86_64::_MM_HINT_T0
                        );
                        std::arch::x86_64::_mm_prefetch(
                            query.as_ptr().add(i + 64) as *const i8,
                            std::arch::x86_64::_MM_HINT_T0
                        );
                    }

                    // 加载数据并计算距离 - 每次处理32个元素
                    let q0 = _mm256_loadu_ps(query.as_ptr().add(i));
                    let v0 = _mm256_loadu_ps(vec.as_ptr().add(i));
                    let diff0 = _mm256_sub_ps(q0, v0);
                    sum0 = _mm256_fmadd_ps(diff0, diff0, sum0);

                    let q1 = _mm256_loadu_ps(query.as_ptr().add(i + 8));
                    let v1 = _mm256_loadu_ps(vec.as_ptr().add(i + 8));
                    let diff1 = _mm256_sub_ps(q1, v1);
                    sum1 = _mm256_fmadd_ps(diff1, diff1, sum1);

                    let q2 = _mm256_loadu_ps(query.as_ptr().add(i + 16));
                    let v2 = _mm256_loadu_ps(vec.as_ptr().add(i + 16));
                    let diff2 = _mm256_sub_ps(q2, v2);
                    sum2 = _mm256_fmadd_ps(diff2, diff2, sum2);

                    let q3 = _mm256_loadu_ps(query.as_ptr().add(i + 24));
                    let v3 = _mm256_loadu_ps(vec.as_ptr().add(i + 24));
                    let diff3 = _mm256_sub_ps(q3, v3);
                    sum3 = _mm256_fmadd_ps(diff3, diff3, sum3);

                    i += 32;
                }

                // 合并部分和
                let sum_lo = _mm256_add_ps(sum0, sum1);
                let sum_hi = _mm256_add_ps(sum2, sum3);
                let sum = _mm256_add_ps(sum_lo, sum_hi);

                // 水平求和
                let hi128 = _mm256_extractf128_ps(sum, 1);
                let lo128 = _mm256_castps256_ps128(sum);
                let sum128 = _mm_add_ps(lo128, hi128);
                let sum64 = _mm_hadd_ps(sum128, sum128);
                let sum32 = _mm_hadd_ps(sum64, sum64);
                let mut dist = _mm_cvtss_f32(sum32);

                // 处理剩余维度
                while i < dim {
                    let diff = query[i] - vec[i];
                    dist += diff * diff;
                    i += 1;
                }
                dist
            } else if dim >= 8 {
                let mut i = 0;
                let mut sum = _mm256_setzero_ps();

                // 预取整个向量
                std::arch::x86_64::_mm_prefetch(
                    vec.as_ptr() as *const i8,
                    std::arch::x86_64::_MM_HINT_T0
                );
                std::arch::x86_64::_mm_prefetch(
                    query.as_ptr() as *const i8,
                    std::arch::x86_64::_MM_HINT_T0
                );

                let end = dim - 7;
                while i < end {
                    // 预取未来数据
                    if i + 16 < dim {
                        std::arch::x86_64::_mm_prefetch(
                            vec.as_ptr().add(i + 16) as *const i8,
                            std::arch::x86_64::_MM_HINT_T0
                        );
                        std::arch::x86_64::_mm_prefetch(
                            query.as_ptr().add(i + 16) as *const i8,
                            std::arch::x86_64::_MM_HINT_T0
                        );
                    }

                    let q = _mm256_loadu_ps(query.as_ptr().add(i));
                    let v = _mm256_loadu_ps(vec.as_ptr().add(i));
                    let diff = _mm256_sub_ps(q, v);
                    sum = _mm256_fmadd_ps(diff, diff, sum);
                    i += 8;
                }

                // 水平求和
                let hi128 = _mm256_extractf128_ps(sum, 1);
                let lo128 = _mm256_castps256_ps128(sum);
                let sum128 = _mm_add_ps(lo128, hi128);
                let sum64 = _mm_hadd_ps(sum128, sum128);
                let sum32 = _mm_hadd_ps(sum64, sum64);
                let mut dist = _mm_cvtss_f32(sum32);

                // 处理剩余维度
                while i < dim {
                    let diff = query[i] - vec[i];
                    dist += diff * diff;
                    i += 1;
                }
                dist
            } else {
                let mut dist = 0.0f32;
                for i in 0..dim {
                    let diff = query[i] - vec[i];
                    dist += diff * diff;
                }
                dist
            }
        }

        #[cfg(not(target_arch = "x86_64"))]
        {
            let mut dist = 0.0f32;
            for i in 0..dim {
                let diff = query[i] - vec[i];
                dist += diff * diff;
            }
            dist
        }
    }

    // 批量计算距离（使用转置数据）
    #[inline]
    fn compute_batch_distances_transposed(&self, query: &[f32], start_idx: usize, batch_size: usize, distances: &mut [f32]) {
        #[cfg(target_arch = "x86_64")]
        unsafe {
            // 对每个维度，一次性处理8个向量
            for vec_offset in (0..batch_size).step_by(8) {
                let mut dist_vec = _mm256_setzero_ps();
                
                // 计算实际要处理的向量数（处理不足8个的情况）
                let actual_batch_size = std::cmp::min(8, batch_size - vec_offset);
                
                let base_ptr = self.vectors_transposed.as_ptr().add(start_idx + vec_offset);

                // 预取整个数据块
                std::arch::x86_64::_mm_prefetch(
                    base_ptr as *const i8,
                    std::arch::x86_64::_MM_HINT_T0
                );

                // 循环展开：每次处理16个维度，提高SIMD利用率
                let mut dim_idx = 0;
                while dim_idx + 15 < self.dimension {
                    // 预取未来的数据
                    if dim_idx + 32 < self.dimension {
                        std::arch::x86_64::_mm_prefetch(
                            base_ptr.add((dim_idx + 32) * self.size) as *const i8,
                            std::arch::x86_64::_MM_HINT_T0
                        );
                    }

                    // 处理16个维度，每次1个
                    let q0 = _mm256_set1_ps(query[dim_idx]);
                    let v0 = _mm256_loadu_ps(base_ptr.add(dim_idx * self.size));
                    let diff0 = _mm256_sub_ps(q0, v0);
                    dist_vec = _mm256_fmadd_ps(diff0, diff0, dist_vec);

                    let q1 = _mm256_set1_ps(query[dim_idx + 1]);
                    let v1 = _mm256_loadu_ps(base_ptr.add((dim_idx + 1) * self.size));
                    let diff1 = _mm256_sub_ps(q1, v1);
                    dist_vec = _mm256_fmadd_ps(diff1, diff1, dist_vec);

                    let q2 = _mm256_set1_ps(query[dim_idx + 2]);
                    let v2 = _mm256_loadu_ps(base_ptr.add((dim_idx + 2) * self.size));
                    let diff2 = _mm256_sub_ps(q2, v2);
                    dist_vec = _mm256_fmadd_ps(diff2, diff2, dist_vec);

                    let q3 = _mm256_set1_ps(query[dim_idx + 3]);
                    let v3 = _mm256_loadu_ps(base_ptr.add((dim_idx + 3) * self.size));
                    let diff3 = _mm256_sub_ps(q3, v3);
                    dist_vec = _mm256_fmadd_ps(diff3, diff3, dist_vec);

                    let q4 = _mm256_set1_ps(query[dim_idx + 4]);
                    let v4 = _mm256_loadu_ps(base_ptr.add((dim_idx + 4) * self.size));
                    let diff4 = _mm256_sub_ps(q4, v4);
                    dist_vec = _mm256_fmadd_ps(diff4, diff4, dist_vec);

                    let q5 = _mm256_set1_ps(query[dim_idx + 5]);
                    let v5 = _mm256_loadu_ps(base_ptr.add((dim_idx + 5) * self.size));
                    let diff5 = _mm256_sub_ps(q5, v5);
                    dist_vec = _mm256_fmadd_ps(diff5, diff5, dist_vec);

                    let q6 = _mm256_set1_ps(query[dim_idx + 6]);
                    let v6 = _mm256_loadu_ps(base_ptr.add((dim_idx + 6) * self.size));
                    let diff6 = _mm256_sub_ps(q6, v6);
                    dist_vec = _mm256_fmadd_ps(diff6, diff6, dist_vec);

                    let q7 = _mm256_set1_ps(query[dim_idx + 7]);
                    let v7 = _mm256_loadu_ps(base_ptr.add((dim_idx + 7) * self.size));
                    let diff7 = _mm256_sub_ps(q7, v7);
                    dist_vec = _mm256_fmadd_ps(diff7, diff7, dist_vec);

                    let q8 = _mm256_set1_ps(query[dim_idx + 8]);
                    let v8 = _mm256_loadu_ps(base_ptr.add((dim_idx + 8) * self.size));
                    let diff8 = _mm256_sub_ps(q8, v8);
                    dist_vec = _mm256_fmadd_ps(diff8, diff8, dist_vec);

                    let q9 = _mm256_set1_ps(query[dim_idx + 9]);
                    let v9 = _mm256_loadu_ps(base_ptr.add((dim_idx + 9) * self.size));
                    let diff9 = _mm256_sub_ps(q9, v9);
                    dist_vec = _mm256_fmadd_ps(diff9, diff9, dist_vec);

                    let q10 = _mm256_set1_ps(query[dim_idx + 10]);
                    let v10 = _mm256_loadu_ps(base_ptr.add((dim_idx + 10) * self.size));
                    let diff10 = _mm256_sub_ps(q10, v10);
                    dist_vec = _mm256_fmadd_ps(diff10, diff10, dist_vec);

                    let q11 = _mm256_set1_ps(query[dim_idx + 11]);
                    let v11 = _mm256_loadu_ps(base_ptr.add((dim_idx + 11) * self.size));
                    let diff11 = _mm256_sub_ps(q11, v11);
                    dist_vec = _mm256_fmadd_ps(diff11, diff11, dist_vec);

                    let q12 = _mm256_set1_ps(query[dim_idx + 12]);
                    let v12 = _mm256_loadu_ps(base_ptr.add((dim_idx + 12) * self.size));
                    let diff12 = _mm256_sub_ps(q12, v12);
                    dist_vec = _mm256_fmadd_ps(diff12, diff12, dist_vec);

                    let q13 = _mm256_set1_ps(query[dim_idx + 13]);
                    let v13 = _mm256_loadu_ps(base_ptr.add((dim_idx + 13) * self.size));
                    let diff13 = _mm256_sub_ps(q13, v13);
                    dist_vec = _mm256_fmadd_ps(diff13, diff13, dist_vec);

                    let q14 = _mm256_set1_ps(query[dim_idx + 14]);
                    let v14 = _mm256_loadu_ps(base_ptr.add((dim_idx + 14) * self.size));
                    let diff14 = _mm256_sub_ps(q14, v14);
                    dist_vec = _mm256_fmadd_ps(diff14, diff14, dist_vec);

                    let q15 = _mm256_set1_ps(query[dim_idx + 15]);
                    let v15 = _mm256_loadu_ps(base_ptr.add((dim_idx + 15) * self.size));
                    let diff15 = _mm256_sub_ps(q15, v15);
                    dist_vec = _mm256_fmadd_ps(diff15, diff15, dist_vec);

                    dim_idx += 16;
                }

                // 处理剩余维度
                while dim_idx < self.dimension {
                    let q_broadcast = _mm256_set1_ps(query[dim_idx]);
                    let v_vals = _mm256_loadu_ps(base_ptr.add(dim_idx * self.size));
                    let diff = _mm256_sub_ps(q_broadcast, v_vals);
                    dist_vec = _mm256_fmadd_ps(diff, diff, dist_vec);
                    dim_idx += 1;
                }

                // 只存储实际需要的数量
                match actual_batch_size {
                    8 => _mm256_storeu_ps(distances.as_mut_ptr().add(vec_offset), dist_vec),
                    n => {
                        // 对于小于8的情况，只存储前n个值
                        let mut temp_array = [0.0f32; 8];
                        _mm256_storeu_ps(temp_array.as_mut_ptr(), dist_vec);
                        for i in 0..n {
                            distances[vec_offset + i] = temp_array[i];
                        }
                    }
                }
            }
        }

        #[cfg(not(target_arch = "x86_64"))]
        {
            for i in 0..batch_size {
                let mut dist = 0.0f32;
                for dim_idx in 0..self.dimension {
                    let q = query[dim_idx];
                    let v = self.vectors_transposed[dim_idx * self.size + start_idx + i];
                    let diff = q - v;
                    dist += diff * diff;
                }
                distances[i] = dist;
            }
        }
    }

    // 单线程搜索
    fn search_single(&self, query: &[f32], k: usize) -> PyResult<(Vec<i64>, Vec<f32>)> {
        // 使用固定大小的数组来维护top-k结果
        let mut top_distances = vec![f32::MAX; k];
        let mut top_labels = vec![0i64; k];

        // 如果k为0或没有向量，则返回空结果
        if k == 0 || self.size == 0 {
            return Ok((Vec::new(), Vec::new()));
        }

        if self.transposed {
            // 动态分块：小数据集用大块，大数据集用小块
            let block_size = if self.size < 200000 {
                std::cmp::min(16384, self.size)
            } else {
                std::cmp::min(4096, self.size)
            };

            // 使用栈上分配的数组，减少内存分配开销
            let mut batch_dists = [0.0f32; 16384];

            // 分块处理
            for block_start in (0..self.size).step_by(block_size) {
                let block_end = std::cmp::min(block_start + block_size, self.size);
                let block_len = block_end - block_start;

                // 批量计算当前块的所有距离
                for i in (0..block_len).step_by(8) {
                    let batch = std::cmp::min(8, block_len - i);
                    self.compute_batch_distances_transposed(query, block_start + i, batch, &mut batch_dists[i..i+batch]);
                }

                // 更新top-k：优化top-k更新逻辑
                for i in 0..block_len {
                    let dist = batch_dists[i];
                    
                    // 快速路径：如果距离大于等于当前最大距离，跳过
                    if dist >= top_distances[k-1] {
                        continue;
                    }
                    
                    // 查找插入位置
                    let mut pos = k - 1;
                    while pos > 0 && dist < top_distances[pos - 1] {
                        pos -= 1;
                    }

                    // 如果找到了有效位置，插入新值并移动其他元素
                    if pos < k {
                        // 移动元素，从后往前避免覆盖
                        for j in (pos + 1..k).rev() {
                            top_distances[j] = top_distances[j - 1];
                            top_labels[j] = top_labels[j - 1];
                        }
                        
                        // 插入新值
                        top_distances[pos] = dist;
                        top_labels[pos] = (block_start + i) as i64;
                    }
                }
            }
        } else {
            // 使用原始数据进行搜索
            // 针对大数据集优化：使用更高效的内存访问模式
            let mut vec_ptr = self.vectors.as_ptr();
            let dim = self.dimension;

            // 循环展开：每次处理8个向量，减少分支开销
            let mut i = 0;
            while i + 7 < self.size {
                // 软件预取，减少内存访问延迟
                unsafe {
                    std::arch::x86_64::_mm_prefetch(
                        vec_ptr.add(dim * 8) as *const i8,
                        std::arch::x86_64::_MM_HINT_T0
                    );
                    std::arch::x86_64::_mm_prefetch(
                        vec_ptr.add(dim * 16) as *const i8,
                        std::arch::x86_64::_MM_HINT_T0
                    );
                }

                // 计算8个向量的距离
                let dist0 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr, dim) });
                let dist1 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(dim), dim) });
                let dist2 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(2 * dim), dim) });
                let dist3 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(3 * dim), dim) });
                let dist4 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(4 * dim), dim) });
                let dist5 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(5 * dim), dim) });
                let dist6 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(6 * dim), dim) });
                let dist7 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(7 * dim), dim) });

                // 处理第一个向量
                if dist0 < top_distances[k-1] {
                    let mut pos = k - 1;
                    while pos > 0 && dist0 < top_distances[pos - 1] {
                        pos -= 1;
                    }
                    if pos < k {
                        for j in (pos + 1..k).rev() {
                            top_distances[j] = top_distances[j - 1];
                            top_labels[j] = top_labels[j - 1];
                        }
                        top_distances[pos] = dist0;
                        top_labels[pos] = i as i64;
                    }
                }

                // 处理第二个向量
                if dist1 < top_distances[k-1] {
                    let mut pos = k - 1;
                    while pos > 0 && dist1 < top_distances[pos - 1] {
                        pos -= 1;
                    }
                    if pos < k {
                        for j in (pos + 1..k).rev() {
                            top_distances[j] = top_distances[j - 1];
                            top_labels[j] = top_labels[j - 1];
                        }
                        top_distances[pos] = dist1;
                        top_labels[pos] = (i + 1) as i64;
                    }
                }

                // 处理第三个向量
                if dist2 < top_distances[k-1] {
                    let mut pos = k - 1;
                    while pos > 0 && dist2 < top_distances[pos - 1] {
                        pos -= 1;
                    }
                    if pos < k {
                        for j in (pos + 1..k).rev() {
                            top_distances[j] = top_distances[j - 1];
                            top_labels[j] = top_labels[j - 1];
                        }
                        top_distances[pos] = dist2;
                        top_labels[pos] = (i + 2) as i64;
                    }
                }

                // 处理第四个向量
                if dist3 < top_distances[k-1] {
                    let mut pos = k - 1;
                    while pos > 0 && dist3 < top_distances[pos - 1] {
                        pos -= 1;
                    }
                    if pos < k {
                        for j in (pos + 1..k).rev() {
                            top_distances[j] = top_distances[j - 1];
                            top_labels[j] = top_labels[j - 1];
                        }
                        top_distances[pos] = dist3;
                        top_labels[pos] = (i + 3) as i64;
                    }
                }

                // 处理第五个向量
                if dist4 < top_distances[k-1] {
                    let mut pos = k - 1;
                    while pos > 0 && dist4 < top_distances[pos - 1] {
                        pos -= 1;
                    }
                    if pos < k {
                        for j in (pos + 1..k).rev() {
                            top_distances[j] = top_distances[j - 1];
                            top_labels[j] = top_labels[j - 1];
                        }
                        top_distances[pos] = dist4;
                        top_labels[pos] = (i + 4) as i64;
                    }
                }

                // 处理第六个向量
                if dist5 < top_distances[k-1] {
                    let mut pos = k - 1;
                    while pos > 0 && dist5 < top_distances[pos - 1] {
                        pos -= 1;
                    }
                    if pos < k {
                        for j in (pos + 1..k).rev() {
                            top_distances[j] = top_distances[j - 1];
                            top_labels[j] = top_labels[j - 1];
                        }
                        top_distances[pos] = dist5;
                        top_labels[pos] = (i + 5) as i64;
                    }
                }

                // 处理第七个向量
                if dist6 < top_distances[k-1] {
                    let mut pos = k - 1;
                    while pos > 0 && dist6 < top_distances[pos - 1] {
                        pos -= 1;
                    }
                    if pos < k {
                        for j in (pos + 1..k).rev() {
                            top_distances[j] = top_distances[j - 1];
                            top_labels[j] = top_labels[j - 1];
                        }
                        top_distances[pos] = dist6;
                        top_labels[pos] = (i + 6) as i64;
                    }
                }

                // 处理第八个向量
                if dist7 < top_distances[k-1] {
                    let mut pos = k - 1;
                    while pos > 0 && dist7 < top_distances[pos - 1] {
                        pos -= 1;
                    }
                    if pos < k {
                        for j in (pos + 1..k).rev() {
                            top_distances[j] = top_distances[j - 1];
                            top_labels[j] = top_labels[j - 1];
                        }
                        top_distances[pos] = dist7;
                        top_labels[pos] = (i + 7) as i64;
                    }
                }

                vec_ptr = unsafe { vec_ptr.add(8 * dim) };
                i += 8;
            }

            // 处理剩余的向量
            for j in i..self.size {
                let vec = unsafe { std::slice::from_raw_parts(vec_ptr, dim) };
                let dist = self.compute_l2_distance(query, vec);

                if dist < top_distances[k-1] {
                    // 查找插入位置
                    let mut pos = k - 1;
                    while pos > 0 && dist < top_distances[pos - 1] {
                        pos -= 1;
                    }

                    // 如果找到了有效位置，插入新值并移动其他元素
                    if pos < k {
                        // 移动元素，从后往前避免覆盖
                        for m in (pos + 1..k).rev() {
                            top_distances[m] = top_distances[m - 1];
                            top_labels[m] = top_labels[m - 1];
                        }
                        
                        // 插入新值
                        top_distances[pos] = dist;
                        top_labels[pos] = j as i64;
                    }
                }
                vec_ptr = unsafe { vec_ptr.add(dim) };
            }
        }

        Ok((top_labels, top_distances))
    }

    // 并行搜索
    fn search_parallel(&self, query: &[f32], k: usize) -> PyResult<(Vec<i64>, Vec<f32>)> {
        // 对于小数据集，使用单线程搜索
        if self.size <= 10000 {
            return self.search_single(query, k);
        }

        let num_threads = self.calculate_optimal_threads();

        // 计算每个线程处理的向量数量，确保每个线程至少处理1000个向量
        let min_vectors_per_thread = 1000;
        let max_threads = std::cmp::min(num_threads, self.size / min_vectors_per_thread + 1);
        let max_threads = std::cmp::max(1, max_threads);

        let vectors_per_thread = self.size / max_threads;
        let remainder = self.size % max_threads;

        // 使用线程局部存储来减少线程间竞争
        let mut thread_results = vec![(vec![f32::MAX; k], vec![0i64; k]); max_threads];

        // 并行处理
        thread_results.par_iter_mut().enumerate().for_each(|(t, (thread_distances, thread_labels))| {
            let start = t * vectors_per_thread + std::cmp::min(t, remainder);
            let end = start + vectors_per_thread + if t < remainder { 1 } else { 0 };

            // 初始化线程局部结果
            for i in 0..k {
                thread_distances[i] = f32::MAX;
                thread_labels[i] = 0;
            }

            if self.transposed {
                // 使用转置数据进行搜索，一次性计算多个向量
                let batch_size = 16384;
                let mut batch_dists = [0.0f32; 16384];

                // 批量处理
                let mut i = start;
                while i < end {
                    let current_batch_size = std::cmp::min(batch_size, end - i);

                    // 批量计算当前块的所有距离
                    for j in (0..current_batch_size).step_by(8) {
                        let sub_batch_size = std::cmp::min(8, current_batch_size - j);
                        self.compute_batch_distances_transposed(query, i + j, sub_batch_size, &mut batch_dists[j..j+sub_batch_size]);
                    }

                    // 更新top-k
                    for j in 0..current_batch_size {
                        let dist = batch_dists[j];
                        if dist < thread_distances[k-1] {
                            // 使用二分查找来找到插入位置，时间复杂度为 O(log k)
                            let mut left = 0;
                            let mut right = k;
                            while left < right {
                                let mid = (left + right) / 2;
                                if dist < thread_distances[mid] {
                                    right = mid;
                                } else {
                                    left = mid + 1;
                                }
                            }

                            if left < k {
                                // 批量移动数据
                                thread_distances.copy_within(left..k-1, left+1);
                                thread_labels.copy_within(left..k-1, left+1);
                                thread_distances[left] = dist;
                                thread_labels[left] = (i + j) as i64;
                            }
                        }
                    }

                    i += current_batch_size;
                }
            } else {
                // 使用原始数据进行搜索
                let dim = self.dimension;
                let mut vec_ptr = unsafe { self.vectors.as_ptr().add(start * dim) };
                let mut i = start;

                // 循环展开：每次处理8个向量，减少分支开销
                while i + 7 < end {
                    // 软件预取，减少内存访问延迟
                    unsafe {
                        std::arch::x86_64::_mm_prefetch(
                            vec_ptr.add(dim * 8) as *const i8,
                            std::arch::x86_64::_MM_HINT_T0
                        );
                        std::arch::x86_64::_mm_prefetch(
                            vec_ptr.add(dim * 16) as *const i8,
                            std::arch::x86_64::_MM_HINT_T0
                        );
                    }

                    // 计算8个向量的距离
                    let dist0 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr, dim) });
                    let dist1 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(dim), dim) });
                    let dist2 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(2 * dim), dim) });
                    let dist3 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(3 * dim), dim) });
                    let dist4 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(4 * dim), dim) });
                    let dist5 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(5 * dim), dim) });
                    let dist6 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(6 * dim), dim) });
                    let dist7 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(7 * dim), dim) });

                    // 处理第一个向量
                    if dist0 < thread_distances[k-1] {
                        let mut left = 0;
                        let mut right = k;
                        while left < right {
                            let mid = (left + right) / 2;
                            if dist0 < thread_distances[mid] {
                                right = mid;
                            } else {
                                left = mid + 1;
                            }
                        }
                        if left < k {
                            thread_distances.copy_within(left..k-1, left+1);
                            thread_labels.copy_within(left..k-1, left+1);
                            thread_distances[left] = dist0;
                            thread_labels[left] = i as i64;
                        }
                    }

                    // 处理第二个向量
                    if dist1 < thread_distances[k-1] {
                        let mut left = 0;
                        let mut right = k;
                        while left < right {
                            let mid = (left + right) / 2;
                            if dist1 < thread_distances[mid] {
                                right = mid;
                            } else {
                                left = mid + 1;
                            }
                        }
                        if left < k {
                            thread_distances.copy_within(left..k-1, left+1);
                            thread_labels.copy_within(left..k-1, left+1);
                            thread_distances[left] = dist1;
                            thread_labels[left] = (i + 1) as i64;
                        }
                    }

                    // 处理第三个向量
                    if dist2 < thread_distances[k-1] {
                        let mut left = 0;
                        let mut right = k;
                        while left < right {
                            let mid = (left + right) / 2;
                            if dist2 < thread_distances[mid] {
                                right = mid;
                            } else {
                                left = mid + 1;
                            }
                        }
                        if left < k {
                            thread_distances.copy_within(left..k-1, left+1);
                            thread_labels.copy_within(left..k-1, left+1);
                            thread_distances[left] = dist2;
                            thread_labels[left] = (i + 2) as i64;
                        }
                    }

                    // 处理第四个向量
                    if dist3 < thread_distances[k-1] {
                        let mut left = 0;
                        let mut right = k;
                        while left < right {
                            let mid = (left + right) / 2;
                            if dist3 < thread_distances[mid] {
                                right = mid;
                            } else {
                                left = mid + 1;
                            }
                        }
                        if left < k {
                            thread_distances.copy_within(left..k-1, left+1);
                            thread_labels.copy_within(left..k-1, left+1);
                            thread_distances[left] = dist3;
                            thread_labels[left] = (i + 3) as i64;
                        }
                    }

                    // 处理第五个向量
                    if dist4 < thread_distances[k-1] {
                        let mut left = 0;
                        let mut right = k;
                        while left < right {
                            let mid = (left + right) / 2;
                            if dist4 < thread_distances[mid] {
                                right = mid;
                            } else {
                                left = mid + 1;
                            }
                        }
                        if left < k {
                            thread_distances.copy_within(left..k-1, left+1);
                            thread_labels.copy_within(left..k-1, left+1);
                            thread_distances[left] = dist4;
                            thread_labels[left] = (i + 4) as i64;
                        }
                    }

                    // 处理第六个向量
                    if dist5 < thread_distances[k-1] {
                        let mut left = 0;
                        let mut right = k;
                        while left < right {
                            let mid = (left + right) / 2;
                            if dist5 < thread_distances[mid] {
                                right = mid;
                            } else {
                                left = mid + 1;
                            }
                        }
                        if left < k {
                            thread_distances.copy_within(left..k-1, left+1);
                            thread_labels.copy_within(left..k-1, left+1);
                            thread_distances[left] = dist5;
                            thread_labels[left] = (i + 5) as i64;
                        }
                    }

                    // 处理第七个向量
                    if dist6 < thread_distances[k-1] {
                        let mut left = 0;
                        let mut right = k;
                        while left < right {
                            let mid = (left + right) / 2;
                            if dist6 < thread_distances[mid] {
                                right = mid;
                            } else {
                                left = mid + 1;
                            }
                        }
                        if left < k {
                            thread_distances.copy_within(left..k-1, left+1);
                            thread_labels.copy_within(left..k-1, left+1);
                            thread_distances[left] = dist6;
                            thread_labels[left] = (i + 6) as i64;
                        }
                    }

                    // 处理第八个向量
                    if dist7 < thread_distances[k-1] {
                        let mut left = 0;
                        let mut right = k;
                        while left < right {
                            let mid = (left + right) / 2;
                            if dist7 < thread_distances[mid] {
                                right = mid;
                            } else {
                                left = mid + 1;
                            }
                        }
                        if left < k {
                            thread_distances.copy_within(left..k-1, left+1);
                            thread_labels.copy_within(left..k-1, left+1);
                            thread_distances[left] = dist7;
                            thread_labels[left] = (i + 7) as i64;
                        }
                    }

                    vec_ptr = unsafe { vec_ptr.add(8 * dim) };
                    i += 8;
                }

                // 处理剩余的向量
                for j in i..end {
                    let vec = unsafe { std::slice::from_raw_parts(vec_ptr, dim) };
                    let dist = self.compute_l2_distance(query, vec);

                    if dist < thread_distances[k-1] {
                        // 使用二分查找来找到插入位置，时间复杂度为 O(log k)
                        let mut left = 0;
                        let mut right = k;
                        while left < right {
                            let mid = (left + right) / 2;
                            if dist < thread_distances[mid] {
                                right = mid;
                            } else {
                                left = mid + 1;
                            }
                        }

                        if left < k {
                            // 批量移动数据
                            thread_distances.copy_within(left..k-1, left+1);
                            thread_labels.copy_within(left..k-1, left+1);
                            thread_distances[left] = dist;
                            thread_labels[left] = j as i64;
                        }
                    }
                    vec_ptr = unsafe { vec_ptr.add(dim) };
                }
            }
        });

        // 合并所有线程的结果
        let mut final_distances = vec![f32::MAX; k];
        let mut final_labels = vec![0i64; k];

        for (thread_distances, thread_labels) in thread_results {
            for i in 0..k {
                let dist = thread_distances[i];
                let label = thread_labels[i];

                if dist < final_distances[k-1] {
                    // 使用二分查找来找到插入位置，时间复杂度为 O(log k)
                    let mut left = 0;
                    let mut right = k;
                    while left < right {
                        let mid = (left + right) / 2;
                        if dist < final_distances[mid] {
                            right = mid;
                        } else {
                            left = mid + 1;
                        }
                    }

                    if left < k {
                        // 批量移动数据
                        final_distances.copy_within(left..k-1, left+1);
                        final_labels.copy_within(left..k-1, left+1);
                        final_distances[left] = dist;
                        final_labels[left] = label;
                    }
                }
            }
        }

        Ok((final_labels, final_distances))
    }
}

#[pymodule]
fn vector_db_rust(_py: Python, m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_class::<FlatIndex>()?;
    m.add("__version__", "1.0.0")?;
    Ok(())
}