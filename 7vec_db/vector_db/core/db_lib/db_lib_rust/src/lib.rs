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

        let num_vectors = vectors.len();
        let total_elements = num_vectors * self.dimension;
        
        let current_len = self.vectors.len();
        self.vectors.reserve_exact(current_len + total_elements);
        self.vectors.resize(current_len + total_elements, 0.0f32);
        
        let mut offset = current_len;
        for vec in vectors {
            if vec.len() != self.dimension {
                return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                    "All vectors must have the same dimension",
                ));
            }
            self.vectors[offset..offset + self.dimension].copy_from_slice(&vec);
            offset += self.dimension;
        }

        self.size += num_vectors;
        self.transpose_data();

        Ok(())
    }

    fn add_buf(&mut self, buffer: &Bound<'_, PyAny>) -> PyResult<()> {
        use pyo3::buffer::PyBuffer;
        
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
        
        let total_elements = num_vectors * self.dimension;
        
        let current_len = self.vectors.len();
        self.vectors.reserve_exact(current_len + total_elements);
        self.vectors.resize(current_len + total_elements, 0.0f32);
        
        let buffer_ptr = buffer.buf_ptr() as *const f32;
        unsafe {
            std::ptr::copy_nonoverlapping(
                buffer_ptr,
                self.vectors.as_mut_ptr().add(current_len),
                total_elements
            );
        }

        self.size += num_vectors;
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

        if self.size <= 10000 {
            return self.search_single(&query, k);
        }

        let num_threads = self.calculate_optimal_search_threads();

        if num_threads > 1 {
            self.search_parallel(&query, k)
        } else {
            self.search_single(&query, k)
        }
    }

    fn search_buf(&self, buffer: &Bound<'_, PyAny>, k: usize) -> PyResult<(Vec<i64>, Vec<f32>)> {
        use pyo3::buffer::PyBuffer;
        
        if self.size == 0 {
            return Ok((Vec::new(), Vec::new()));
        }
        
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
        
        let mut query_vec = Vec::with_capacity(dim);
        let buffer_ptr = buffer.buf_ptr() as *const f32;
        unsafe {
            for j in 0..dim {
                let value = *buffer_ptr.offset(j as isize);
                query_vec.push(value);
            }
        }
        
        if self.size <= 10000 {
            return self.search_single(&query_vec, k);
        }

        let num_threads = self.calculate_optimal_search_threads();

        if num_threads > 1 {
            self.search_parallel(&query_vec, k)
        } else {
            self.search_single(&query_vec, k)
        }
    }

    fn search_batch_buf(&self, buffer: &Bound<'_, PyAny>, k: usize) -> PyResult<(Vec<Vec<i64>>, Vec<Vec<f32>>)> {
        use pyo3::buffer::PyBuffer;
        
        if self.size == 0 {
            return Ok((Vec::new(), Vec::new()));
        }
        
        let buffer = PyBuffer::<f32>::get(buffer)?;
        let dimensions = buffer.dimensions();
        
        if dimensions != 2 {
            return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                "Input must be a 2D array",
            ));
        }
        
        let shape = buffer.shape();
        let num_queries = shape[0];
        let dim = shape[1];
        
        if dim != self.dimension {
            return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                "Query vector dimension mismatch",
            ));
        }
        
        let mut queries = Vec::with_capacity(num_queries);
        let buffer_ptr = buffer.buf_ptr() as *const f32;
        
        unsafe {
            for i in 0..num_queries {
                let mut query = Vec::with_capacity(dim);
                for j in 0..dim {
                    let value = *buffer_ptr.offset((i * dim + j) as isize);
                    query.push(value);
                }
                queries.push(query);
            }
        }
        
        let mut all_labels = Vec::with_capacity(num_queries);
        let mut all_distances = Vec::with_capacity(num_queries);
        
        let num_threads = self.calculate_optimal_search_threads();
        
        // 如果查询很多，用查询级并行；否则用向量级并行
        if num_threads > 1 && num_queries > 10 {
            let results: Vec<(Vec<i64>, Vec<f32>)> = queries.par_iter()
                .map(|query| {
                    self.search_single(query, k).unwrap()
                })
                .collect();
            
            for (labels, distances) in results {
                all_labels.push(labels);
                all_distances.push(distances);
            }
        } else {
            for query in queries {
                let (labels, distances) = if self.size <= 10000 {
                    self.search_single(&query, k)?
                } else {
                    self.search_parallel(&query, k)?
                };
                all_labels.push(labels);
                all_distances.push(distances);
            }
        }
        
        Ok((all_labels, all_distances))
    }

    fn size(&self) -> usize {
        self.size
    }

    fn dimension(&self) -> usize {
        self.dimension
    }
}

impl FlatIndex {
    #[inline]
    fn insert_top_k(&self, distances: &mut [f32], labels: &mut [i64], k: usize, dist: f32, idx: i64) {
        if dist >= distances[k-1] {
            return;
        }
        
        // 二分查找定位插入位置
        let mut left = 0;
        let mut right = k;
        while left < right {
            let mid = (left + right) / 2;
            if dist < distances[mid] {
                right = mid;
            } else {
                left = mid + 1;
            }
        }

        if left < k {
            // 使用 ptr::copy 进行高效的批量移动
            unsafe {
                let move_count = k - left - 1;
                if move_count > 0 {
                    std::ptr::copy(
                        distances.as_ptr().add(left),
                        distances.as_mut_ptr().add(left + 1),
                        move_count
                    );
                    std::ptr::copy(
                        labels.as_ptr().add(left),
                        labels.as_mut_ptr().add(left + 1),
                        move_count
                    );
                }
                distances[left] = dist;
                labels[left] = idx;
            }
        }
    }

    #[inline]
    fn calculate_optimal_search_threads(&self) -> usize {
        let num_threads = num_cpus::get();
        
        let num_threads = if self.size > 500000 {
            std::cmp::min(num_threads, 10)
        } else if self.size > 100000 {
            std::cmp::min(num_threads, 6)
        } else if self.size > 10000 {
            std::cmp::min(num_threads, 4)
        } else {
            1
        };

        if self.dimension > 256 {
            std::cmp::max(1, num_threads / 2)
        } else if self.dimension > 128 {
            std::cmp::max(1, num_threads)
        } else {
            num_threads
        }
    }

    #[inline]
    fn calculate_optimal_threads(&self) -> usize {
        let num_threads = num_cpus::get();
        
        let num_threads = if self.size > 1000000 {
            std::cmp::min(num_threads, 16)
        } else if self.size > 200000 {
            std::cmp::min(num_threads, 10)
        } else if self.size > 100000 {
            std::cmp::min(num_threads, 6)
        } else if self.size > 10000 {
            std::cmp::min(num_threads, 4)
        } else {
            1
        };

        if self.dimension > 512 {
            std::cmp::max(1, num_threads / 2)
        } else if self.dimension > 256 {
            std::cmp::max(1, num_threads)
        } else {
            num_threads
        }
    }

    fn transpose_data(&mut self) {
        // 对于128D和256D，转置开销太大，直接不转置！
        if self.dimension == 128 || self.dimension == 256 {
            self.transposed = false;
            self.vectors_transposed.clear();
            self.vectors_transposed.shrink_to_fit();
            return;
        }
        
        if self.size > 200000 {
            self.transposed = false;
            self.vectors_transposed.clear();
            self.vectors_transposed.shrink_to_fit();
            return;
        }

        if self.size == 0 || self.dimension == 0 {
            return;
        }

        self.vectors_transposed.resize(self.size * self.dimension, 0.0f32);

        for i in 0..self.size {
            for j in 0..self.dimension {
                self.vectors_transposed[j * self.size + i] = self.vectors[i * self.dimension + j];
            }
        }

        self.transposed = true;
    }

    #[inline]
    fn compute_l2_distance(&self, query: &[f32], vec: &[f32]) -> f32 {
        let dim = self.dimension;

        #[cfg(target_arch = "x86_64")]
        unsafe {
            if dim == 128 {
                let mut sum0 = _mm256_setzero_ps();
                let mut sum1 = _mm256_setzero_ps();
                let mut sum2 = _mm256_setzero_ps();
                let mut sum3 = _mm256_setzero_ps();

                // 预取未来的数据
                std::arch::x86_64::_mm_prefetch(
                    vec.as_ptr().add(128) as *const i8,
                    std::arch::x86_64::_MM_HINT_T0
                );

                let q0 = _mm256_loadu_ps(query.as_ptr());
                let v0 = _mm256_loadu_ps(vec.as_ptr());
                let diff0 = _mm256_sub_ps(q0, v0);
                sum0 = _mm256_fmadd_ps(diff0, diff0, sum0);

                let q1 = _mm256_loadu_ps(query.as_ptr().add(8));
                let v1 = _mm256_loadu_ps(vec.as_ptr().add(8));
                let diff1 = _mm256_sub_ps(q1, v1);
                sum1 = _mm256_fmadd_ps(diff1, diff1, sum1);

                let q2 = _mm256_loadu_ps(query.as_ptr().add(16));
                let v2 = _mm256_loadu_ps(vec.as_ptr().add(16));
                let diff2 = _mm256_sub_ps(q2, v2);
                sum2 = _mm256_fmadd_ps(diff2, diff2, sum2);

                let q3 = _mm256_loadu_ps(query.as_ptr().add(24));
                let v3 = _mm256_loadu_ps(vec.as_ptr().add(24));
                let diff3 = _mm256_sub_ps(q3, v3);
                sum3 = _mm256_fmadd_ps(diff3, diff3, sum3);

                let q4 = _mm256_loadu_ps(query.as_ptr().add(32));
                let v4 = _mm256_loadu_ps(vec.as_ptr().add(32));
                let diff4 = _mm256_sub_ps(q4, v4);
                sum0 = _mm256_fmadd_ps(diff4, diff4, sum0);

                let q5 = _mm256_loadu_ps(query.as_ptr().add(40));
                let v5 = _mm256_loadu_ps(vec.as_ptr().add(40));
                let diff5 = _mm256_sub_ps(q5, v5);
                sum1 = _mm256_fmadd_ps(diff5, diff5, sum1);

                let q6 = _mm256_loadu_ps(query.as_ptr().add(48));
                let v6 = _mm256_loadu_ps(vec.as_ptr().add(48));
                let diff6 = _mm256_sub_ps(q6, v6);
                sum2 = _mm256_fmadd_ps(diff6, diff6, sum2);

                let q7 = _mm256_loadu_ps(query.as_ptr().add(56));
                let v7 = _mm256_loadu_ps(vec.as_ptr().add(56));
                let diff7 = _mm256_sub_ps(q7, v7);
                sum3 = _mm256_fmadd_ps(diff7, diff7, sum3);

                let q8 = _mm256_loadu_ps(query.as_ptr().add(64));
                let v8 = _mm256_loadu_ps(vec.as_ptr().add(64));
                let diff8 = _mm256_sub_ps(q8, v8);
                sum0 = _mm256_fmadd_ps(diff8, diff8, sum0);

                let q9 = _mm256_loadu_ps(query.as_ptr().add(72));
                let v9 = _mm256_loadu_ps(vec.as_ptr().add(72));
                let diff9 = _mm256_sub_ps(q9, v9);
                sum1 = _mm256_fmadd_ps(diff9, diff9, sum1);

                let q10 = _mm256_loadu_ps(query.as_ptr().add(80));
                let v10 = _mm256_loadu_ps(vec.as_ptr().add(80));
                let diff10 = _mm256_sub_ps(q10, v10);
                sum2 = _mm256_fmadd_ps(diff10, diff10, sum2);

                let q11 = _mm256_loadu_ps(query.as_ptr().add(88));
                let v11 = _mm256_loadu_ps(vec.as_ptr().add(88));
                let diff11 = _mm256_sub_ps(q11, v11);
                sum3 = _mm256_fmadd_ps(diff11, diff11, sum3);

                let q12 = _mm256_loadu_ps(query.as_ptr().add(96));
                let v12 = _mm256_loadu_ps(vec.as_ptr().add(96));
                let diff12 = _mm256_sub_ps(q12, v12);
                sum0 = _mm256_fmadd_ps(diff12, diff12, sum0);

                let q13 = _mm256_loadu_ps(query.as_ptr().add(104));
                let v13 = _mm256_loadu_ps(vec.as_ptr().add(104));
                let diff13 = _mm256_sub_ps(q13, v13);
                sum1 = _mm256_fmadd_ps(diff13, diff13, sum1);

                let q14 = _mm256_loadu_ps(query.as_ptr().add(112));
                let v14 = _mm256_loadu_ps(vec.as_ptr().add(112));
                let diff14 = _mm256_sub_ps(q14, v14);
                sum2 = _mm256_fmadd_ps(diff14, diff14, sum2);

                let q15 = _mm256_loadu_ps(query.as_ptr().add(120));
                let v15 = _mm256_loadu_ps(vec.as_ptr().add(120));
                let diff15 = _mm256_sub_ps(q15, v15);
                sum3 = _mm256_fmadd_ps(diff15, diff15, sum3);

                let sum_a = _mm256_add_ps(sum0, sum1);
                let sum_b = _mm256_add_ps(sum2, sum3);
                let sum = _mm256_add_ps(sum_a, sum_b);

                // 使用更好的水平求和方法，参考C++实现
                let shuffled = _mm256_permute2f128_ps(sum, sum, 0x21);
                let summed = _mm256_add_ps(sum, shuffled);
                let summed = _mm256_hadd_ps(summed, summed);
                let summed = _mm256_hadd_ps(summed, summed);
                _mm256_cvtss_f32(summed)
            } else if dim == 256 {
                let mut sum0 = _mm256_setzero_ps();
                let mut sum1 = _mm256_setzero_ps();
                let mut sum2 = _mm256_setzero_ps();
                let mut sum3 = _mm256_setzero_ps();
                let mut sum4 = _mm256_setzero_ps();
                let mut sum5 = _mm256_setzero_ps();
                let mut sum6 = _mm256_setzero_ps();
                let mut sum7 = _mm256_setzero_ps();

                // 预取未来的数据
                std::arch::x86_64::_mm_prefetch(
                    vec.as_ptr().add(128) as *const i8,
                    std::arch::x86_64::_MM_HINT_T0
                );

                // 完全展开，去除循环，像128D那样
                let q0 = _mm256_loadu_ps(query.as_ptr());
                let v0 = _mm256_loadu_ps(vec.as_ptr());
                let diff0 = _mm256_sub_ps(q0, v0);
                sum0 = _mm256_fmadd_ps(diff0, diff0, sum0);

                let q1 = _mm256_loadu_ps(query.as_ptr().add(8));
                let v1 = _mm256_loadu_ps(vec.as_ptr().add(8));
                let diff1 = _mm256_sub_ps(q1, v1);
                sum1 = _mm256_fmadd_ps(diff1, diff1, sum1);

                let q2 = _mm256_loadu_ps(query.as_ptr().add(16));
                let v2 = _mm256_loadu_ps(vec.as_ptr().add(16));
                let diff2 = _mm256_sub_ps(q2, v2);
                sum2 = _mm256_fmadd_ps(diff2, diff2, sum2);

                let q3 = _mm256_loadu_ps(query.as_ptr().add(24));
                let v3 = _mm256_loadu_ps(vec.as_ptr().add(24));
                let diff3 = _mm256_sub_ps(q3, v3);
                sum3 = _mm256_fmadd_ps(diff3, diff3, sum3);

                let q4 = _mm256_loadu_ps(query.as_ptr().add(32));
                let v4 = _mm256_loadu_ps(vec.as_ptr().add(32));
                let diff4 = _mm256_sub_ps(q4, v4);
                sum4 = _mm256_fmadd_ps(diff4, diff4, sum4);

                let q5 = _mm256_loadu_ps(query.as_ptr().add(40));
                let v5 = _mm256_loadu_ps(vec.as_ptr().add(40));
                let diff5 = _mm256_sub_ps(q5, v5);
                sum5 = _mm256_fmadd_ps(diff5, diff5, sum5);

                let q6 = _mm256_loadu_ps(query.as_ptr().add(48));
                let v6 = _mm256_loadu_ps(vec.as_ptr().add(48));
                let diff6 = _mm256_sub_ps(q6, v6);
                sum6 = _mm256_fmadd_ps(diff6, diff6, sum6);

                let q7 = _mm256_loadu_ps(query.as_ptr().add(56));
                let v7 = _mm256_loadu_ps(vec.as_ptr().add(56));
                let diff7 = _mm256_sub_ps(q7, v7);
                sum7 = _mm256_fmadd_ps(diff7, diff7, sum7);

                let q8 = _mm256_loadu_ps(query.as_ptr().add(64));
                let v8 = _mm256_loadu_ps(vec.as_ptr().add(64));
                let diff8 = _mm256_sub_ps(q8, v8);
                sum0 = _mm256_fmadd_ps(diff8, diff8, sum0);

                let q9 = _mm256_loadu_ps(query.as_ptr().add(72));
                let v9 = _mm256_loadu_ps(vec.as_ptr().add(72));
                let diff9 = _mm256_sub_ps(q9, v9);
                sum1 = _mm256_fmadd_ps(diff9, diff9, sum1);

                let q10 = _mm256_loadu_ps(query.as_ptr().add(80));
                let v10 = _mm256_loadu_ps(vec.as_ptr().add(80));
                let diff10 = _mm256_sub_ps(q10, v10);
                sum2 = _mm256_fmadd_ps(diff10, diff10, sum2);

                let q11 = _mm256_loadu_ps(query.as_ptr().add(88));
                let v11 = _mm256_loadu_ps(vec.as_ptr().add(88));
                let diff11 = _mm256_sub_ps(q11, v11);
                sum3 = _mm256_fmadd_ps(diff11, diff11, sum3);

                let q12 = _mm256_loadu_ps(query.as_ptr().add(96));
                let v12 = _mm256_loadu_ps(vec.as_ptr().add(96));
                let diff12 = _mm256_sub_ps(q12, v12);
                sum4 = _mm256_fmadd_ps(diff12, diff12, sum4);

                let q13 = _mm256_loadu_ps(query.as_ptr().add(104));
                let v13 = _mm256_loadu_ps(vec.as_ptr().add(104));
                let diff13 = _mm256_sub_ps(q13, v13);
                sum5 = _mm256_fmadd_ps(diff13, diff13, sum5);

                let q14 = _mm256_loadu_ps(query.as_ptr().add(112));
                let v14 = _mm256_loadu_ps(vec.as_ptr().add(112));
                let diff14 = _mm256_sub_ps(q14, v14);
                sum6 = _mm256_fmadd_ps(diff14, diff14, sum6);

                let q15 = _mm256_loadu_ps(query.as_ptr().add(120));
                let v15 = _mm256_loadu_ps(vec.as_ptr().add(120));
                let diff15 = _mm256_sub_ps(q15, v15);
                sum7 = _mm256_fmadd_ps(diff15, diff15, sum7);

                let q16 = _mm256_loadu_ps(query.as_ptr().add(128));
                let v16 = _mm256_loadu_ps(vec.as_ptr().add(128));
                let diff16 = _mm256_sub_ps(q16, v16);
                sum0 = _mm256_fmadd_ps(diff16, diff16, sum0);

                let q17 = _mm256_loadu_ps(query.as_ptr().add(136));
                let v17 = _mm256_loadu_ps(vec.as_ptr().add(136));
                let diff17 = _mm256_sub_ps(q17, v17);
                sum1 = _mm256_fmadd_ps(diff17, diff17, sum1);

                let q18 = _mm256_loadu_ps(query.as_ptr().add(144));
                let v18 = _mm256_loadu_ps(vec.as_ptr().add(144));
                let diff18 = _mm256_sub_ps(q18, v18);
                sum2 = _mm256_fmadd_ps(diff18, diff18, sum2);

                let q19 = _mm256_loadu_ps(query.as_ptr().add(152));
                let v19 = _mm256_loadu_ps(vec.as_ptr().add(152));
                let diff19 = _mm256_sub_ps(q19, v19);
                sum3 = _mm256_fmadd_ps(diff19, diff19, sum3);

                let q20 = _mm256_loadu_ps(query.as_ptr().add(160));
                let v20 = _mm256_loadu_ps(vec.as_ptr().add(160));
                let diff20 = _mm256_sub_ps(q20, v20);
                sum4 = _mm256_fmadd_ps(diff20, diff20, sum4);

                let q21 = _mm256_loadu_ps(query.as_ptr().add(168));
                let v21 = _mm256_loadu_ps(vec.as_ptr().add(168));
                let diff21 = _mm256_sub_ps(q21, v21);
                sum5 = _mm256_fmadd_ps(diff21, diff21, sum5);

                let q22 = _mm256_loadu_ps(query.as_ptr().add(176));
                let v22 = _mm256_loadu_ps(vec.as_ptr().add(176));
                let diff22 = _mm256_sub_ps(q22, v22);
                sum6 = _mm256_fmadd_ps(diff22, diff22, sum6);

                let q23 = _mm256_loadu_ps(query.as_ptr().add(184));
                let v23 = _mm256_loadu_ps(vec.as_ptr().add(184));
                let diff23 = _mm256_sub_ps(q23, v23);
                sum7 = _mm256_fmadd_ps(diff23, diff23, sum7);

                let q24 = _mm256_loadu_ps(query.as_ptr().add(192));
                let v24 = _mm256_loadu_ps(vec.as_ptr().add(192));
                let diff24 = _mm256_sub_ps(q24, v24);
                sum0 = _mm256_fmadd_ps(diff24, diff24, sum0);

                let q25 = _mm256_loadu_ps(query.as_ptr().add(200));
                let v25 = _mm256_loadu_ps(vec.as_ptr().add(200));
                let diff25 = _mm256_sub_ps(q25, v25);
                sum1 = _mm256_fmadd_ps(diff25, diff25, sum1);

                let q26 = _mm256_loadu_ps(query.as_ptr().add(208));
                let v26 = _mm256_loadu_ps(vec.as_ptr().add(208));
                let diff26 = _mm256_sub_ps(q26, v26);
                sum2 = _mm256_fmadd_ps(diff26, diff26, sum2);

                let q27 = _mm256_loadu_ps(query.as_ptr().add(216));
                let v27 = _mm256_loadu_ps(vec.as_ptr().add(216));
                let diff27 = _mm256_sub_ps(q27, v27);
                sum3 = _mm256_fmadd_ps(diff27, diff27, sum3);

                let q28 = _mm256_loadu_ps(query.as_ptr().add(224));
                let v28 = _mm256_loadu_ps(vec.as_ptr().add(224));
                let diff28 = _mm256_sub_ps(q28, v28);
                sum4 = _mm256_fmadd_ps(diff28, diff28, sum4);

                let q29 = _mm256_loadu_ps(query.as_ptr().add(232));
                let v29 = _mm256_loadu_ps(vec.as_ptr().add(232));
                let diff29 = _mm256_sub_ps(q29, v29);
                sum5 = _mm256_fmadd_ps(diff29, diff29, sum5);

                let q30 = _mm256_loadu_ps(query.as_ptr().add(240));
                let v30 = _mm256_loadu_ps(vec.as_ptr().add(240));
                let diff30 = _mm256_sub_ps(q30, v30);
                sum6 = _mm256_fmadd_ps(diff30, diff30, sum6);

                let q31 = _mm256_loadu_ps(query.as_ptr().add(248));
                let v31 = _mm256_loadu_ps(vec.as_ptr().add(248));
                let diff31 = _mm256_sub_ps(q31, v31);
                sum7 = _mm256_fmadd_ps(diff31, diff31, sum7);

                let sum_a = _mm256_add_ps(sum0, sum1);
                let sum_b = _mm256_add_ps(sum2, sum3);
                let sum_c = _mm256_add_ps(sum4, sum5);
                let sum_d = _mm256_add_ps(sum6, sum7);
                let sum_ab = _mm256_add_ps(sum_a, sum_b);
                let sum_cd = _mm256_add_ps(sum_c, sum_d);
                let sum = _mm256_add_ps(sum_ab, sum_cd);

                // 使用更好的水平求和方法，参考C++实现
                let shuffled = _mm256_permute2f128_ps(sum, sum, 0x21);
                let summed = _mm256_add_ps(sum, shuffled);
                let summed = _mm256_hadd_ps(summed, summed);
                let summed = _mm256_hadd_ps(summed, summed);
                _mm256_cvtss_f32(summed)
            } else if dim >= 64 {
                let mut i = 0;
                let mut sum0 = _mm256_setzero_ps();
                let mut sum1 = _mm256_setzero_ps();
                let mut sum2 = _mm256_setzero_ps();
                let mut sum3 = _mm256_setzero_ps();

                let end = dim - 63;
                while i < end {
                    // 预取未来的数据，参考C++实现
                    std::arch::x86_64::_mm_prefetch(
                        vec.as_ptr().add(i + 128) as *const i8,
                        std::arch::x86_64::_MM_HINT_T0
                    );
                    
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

                    let q4 = _mm256_loadu_ps(query.as_ptr().add(i + 32));
                    let v4 = _mm256_loadu_ps(vec.as_ptr().add(i + 32));
                    let diff4 = _mm256_sub_ps(q4, v4);
                    sum0 = _mm256_fmadd_ps(diff4, diff4, sum0);

                    let q5 = _mm256_loadu_ps(query.as_ptr().add(i + 40));
                    let v5 = _mm256_loadu_ps(vec.as_ptr().add(i + 40));
                    let diff5 = _mm256_sub_ps(q5, v5);
                    sum1 = _mm256_fmadd_ps(diff5, diff5, sum1);

                    let q6 = _mm256_loadu_ps(query.as_ptr().add(i + 48));
                    let v6 = _mm256_loadu_ps(vec.as_ptr().add(i + 48));
                    let diff6 = _mm256_sub_ps(q6, v6);
                    sum2 = _mm256_fmadd_ps(diff6, diff6, sum2);

                    let q7 = _mm256_loadu_ps(query.as_ptr().add(i + 56));
                    let v7 = _mm256_loadu_ps(vec.as_ptr().add(i + 56));
                    let diff7 = _mm256_sub_ps(q7, v7);
                    sum3 = _mm256_fmadd_ps(diff7, diff7, sum3);

                    i += 64;
                }

                let sum_a = _mm256_add_ps(sum0, sum1);
                let sum_b = _mm256_add_ps(sum2, sum3);
                let sum = _mm256_add_ps(sum_a, sum_b);

                let shuffled = _mm256_permute2f128_ps(sum, sum, 0x21);
                let summed = _mm256_add_ps(sum, shuffled);
                let summed = _mm256_hadd_ps(summed, summed);
                let summed = _mm256_hadd_ps(summed, summed);
                let mut dist = _mm256_cvtss_f32(summed);

                while i < dim {
                    let diff = query[i] - vec[i];
                    dist += diff * diff;
                    i += 1;
                }
                dist
            } else if dim >= 32 {
                let mut i = 0;
                let mut sum0 = _mm256_setzero_ps();
                let mut sum1 = _mm256_setzero_ps();

                let end = dim - 31;
                while i < end {
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
                    sum0 = _mm256_fmadd_ps(diff2, diff2, sum0);

                    let q3 = _mm256_loadu_ps(query.as_ptr().add(i + 24));
                    let v3 = _mm256_loadu_ps(vec.as_ptr().add(i + 24));
                    let diff3 = _mm256_sub_ps(q3, v3);
                    sum1 = _mm256_fmadd_ps(diff3, diff3, sum1);

                    i += 32;
                }

                let sum = _mm256_add_ps(sum0, sum1);

                let shuffled = _mm256_permute2f128_ps(sum, sum, 0x21);
                let summed = _mm256_add_ps(sum, shuffled);
                let summed = _mm256_hadd_ps(summed, summed);
                let summed = _mm256_hadd_ps(summed, summed);
                let mut dist = _mm256_cvtss_f32(summed);

                while i < dim {
                    let diff = query[i] - vec[i];
                    dist += diff * diff;
                    i += 1;
                }
                dist
            } else if dim >= 8 {
                let mut i = 0;
                let mut sum = _mm256_setzero_ps();

                let end = dim - 7;
                while i < end {
                    let q = _mm256_loadu_ps(query.as_ptr().add(i));
                    let v = _mm256_loadu_ps(vec.as_ptr().add(i));
                    let diff = _mm256_sub_ps(q, v);
                    sum = _mm256_fmadd_ps(diff, diff, sum);
                    i += 8;
                }

                let shuffled = _mm256_permute2f128_ps(sum, sum, 0x21);
                let summed = _mm256_add_ps(sum, shuffled);
                let summed = _mm256_hadd_ps(summed, summed);
                let summed = _mm256_hadd_ps(summed, summed);
                let mut dist = _mm256_cvtss_f32(summed);

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

    #[inline]
    fn compute_batch_distances_transposed(&self, query: &[f32], start_idx: usize, batch_size: usize, distances: &mut [f32]) {
        #[cfg(target_arch = "x86_64")]
        unsafe {
            for vec_offset in (0..batch_size).step_by(8) {
                let mut dist_vec = _mm256_setzero_ps();
                let actual_batch_size = std::cmp::min(8, batch_size - vec_offset);
                let base_ptr = self.vectors_transposed.as_ptr().add(start_idx + vec_offset);

                let mut dim_idx = 0;
                while dim_idx + 31 < self.dimension {
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

                    let q16 = _mm256_set1_ps(query[dim_idx + 16]);
                    let v16 = _mm256_loadu_ps(base_ptr.add((dim_idx + 16) * self.size));
                    let diff16 = _mm256_sub_ps(q16, v16);
                    dist_vec = _mm256_fmadd_ps(diff16, diff16, dist_vec);

                    let q17 = _mm256_set1_ps(query[dim_idx + 17]);
                    let v17 = _mm256_loadu_ps(base_ptr.add((dim_idx + 17) * self.size));
                    let diff17 = _mm256_sub_ps(q17, v17);
                    dist_vec = _mm256_fmadd_ps(diff17, diff17, dist_vec);

                    let q18 = _mm256_set1_ps(query[dim_idx + 18]);
                    let v18 = _mm256_loadu_ps(base_ptr.add((dim_idx + 18) * self.size));
                    let diff18 = _mm256_sub_ps(q18, v18);
                    dist_vec = _mm256_fmadd_ps(diff18, diff18, dist_vec);

                    let q19 = _mm256_set1_ps(query[dim_idx + 19]);
                    let v19 = _mm256_loadu_ps(base_ptr.add((dim_idx + 19) * self.size));
                    let diff19 = _mm256_sub_ps(q19, v19);
                    dist_vec = _mm256_fmadd_ps(diff19, diff19, dist_vec);

                    let q20 = _mm256_set1_ps(query[dim_idx + 20]);
                    let v20 = _mm256_loadu_ps(base_ptr.add((dim_idx + 20) * self.size));
                    let diff20 = _mm256_sub_ps(q20, v20);
                    dist_vec = _mm256_fmadd_ps(diff20, diff20, dist_vec);

                    let q21 = _mm256_set1_ps(query[dim_idx + 21]);
                    let v21 = _mm256_loadu_ps(base_ptr.add((dim_idx + 21) * self.size));
                    let diff21 = _mm256_sub_ps(q21, v21);
                    dist_vec = _mm256_fmadd_ps(diff21, diff21, dist_vec);

                    let q22 = _mm256_set1_ps(query[dim_idx + 22]);
                    let v22 = _mm256_loadu_ps(base_ptr.add((dim_idx + 22) * self.size));
                    let diff22 = _mm256_sub_ps(q22, v22);
                    dist_vec = _mm256_fmadd_ps(diff22, diff22, dist_vec);

                    let q23 = _mm256_set1_ps(query[dim_idx + 23]);
                    let v23 = _mm256_loadu_ps(base_ptr.add((dim_idx + 23) * self.size));
                    let diff23 = _mm256_sub_ps(q23, v23);
                    dist_vec = _mm256_fmadd_ps(diff23, diff23, dist_vec);

                    let q24 = _mm256_set1_ps(query[dim_idx + 24]);
                    let v24 = _mm256_loadu_ps(base_ptr.add((dim_idx + 24) * self.size));
                    let diff24 = _mm256_sub_ps(q24, v24);
                    dist_vec = _mm256_fmadd_ps(diff24, diff24, dist_vec);

                    let q25 = _mm256_set1_ps(query[dim_idx + 25]);
                    let v25 = _mm256_loadu_ps(base_ptr.add((dim_idx + 25) * self.size));
                    let diff25 = _mm256_sub_ps(q25, v25);
                    dist_vec = _mm256_fmadd_ps(diff25, diff25, dist_vec);

                    let q26 = _mm256_set1_ps(query[dim_idx + 26]);
                    let v26 = _mm256_loadu_ps(base_ptr.add((dim_idx + 26) * self.size));
                    let diff26 = _mm256_sub_ps(q26, v26);
                    dist_vec = _mm256_fmadd_ps(diff26, diff26, dist_vec);

                    let q27 = _mm256_set1_ps(query[dim_idx + 27]);
                    let v27 = _mm256_loadu_ps(base_ptr.add((dim_idx + 27) * self.size));
                    let diff27 = _mm256_sub_ps(q27, v27);
                    dist_vec = _mm256_fmadd_ps(diff27, diff27, dist_vec);

                    let q28 = _mm256_set1_ps(query[dim_idx + 28]);
                    let v28 = _mm256_loadu_ps(base_ptr.add((dim_idx + 28) * self.size));
                    let diff28 = _mm256_sub_ps(q28, v28);
                    dist_vec = _mm256_fmadd_ps(diff28, diff28, dist_vec);

                    let q29 = _mm256_set1_ps(query[dim_idx + 29]);
                    let v29 = _mm256_loadu_ps(base_ptr.add((dim_idx + 29) * self.size));
                    let diff29 = _mm256_sub_ps(q29, v29);
                    dist_vec = _mm256_fmadd_ps(diff29, diff29, dist_vec);

                    let q30 = _mm256_set1_ps(query[dim_idx + 30]);
                    let v30 = _mm256_loadu_ps(base_ptr.add((dim_idx + 30) * self.size));
                    let diff30 = _mm256_sub_ps(q30, v30);
                    dist_vec = _mm256_fmadd_ps(diff30, diff30, dist_vec);

                    let q31 = _mm256_set1_ps(query[dim_idx + 31]);
                    let v31 = _mm256_loadu_ps(base_ptr.add((dim_idx + 31) * self.size));
                    let diff31 = _mm256_sub_ps(q31, v31);
                    dist_vec = _mm256_fmadd_ps(diff31, diff31, dist_vec);

                    dim_idx += 32;
                }

                while dim_idx < self.dimension {
                    let q_broadcast = _mm256_set1_ps(query[dim_idx]);
                    let v_vals = _mm256_loadu_ps(base_ptr.add(dim_idx * self.size));
                    let diff = _mm256_sub_ps(q_broadcast, v_vals);
                    dist_vec = _mm256_fmadd_ps(diff, diff, dist_vec);
                    dim_idx += 1;
                }

                match actual_batch_size {
                    8 => _mm256_storeu_ps(distances.as_mut_ptr().add(vec_offset), dist_vec),
                    n => {
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

    fn search_single(&self, query: &[f32], k: usize) -> PyResult<(Vec<i64>, Vec<f32>)> {
        let mut top_distances = vec![f32::MAX; k];
        let mut top_labels = vec![0i64; k];

        if k == 0 || self.size == 0 {
            return Ok((Vec::new(), Vec::new()));
        }

        #[cfg(target_arch = "x86_64")]
        unsafe {
            // 预取查询向量到缓存，参考C++实现
            std::arch::x86_64::_mm_prefetch(
                query.as_ptr() as *const i8,
                std::arch::x86_64::_MM_HINT_T0
            );
            if query.len() > 64 {
                std::arch::x86_64::_mm_prefetch(
                    query.as_ptr().add(64) as *const i8,
                    std::arch::x86_64::_MM_HINT_T0
                );
            }
            if query.len() > 128 {
                std::arch::x86_64::_mm_prefetch(
                    query.as_ptr().add(128) as *const i8,
                    std::arch::x86_64::_MM_HINT_T0
                );
            }
            if query.len() > 192 {
                std::arch::x86_64::_mm_prefetch(
                    query.as_ptr().add(192) as *const i8,
                    std::arch::x86_64::_MM_HINT_T0
                );
            }
        }

        if self.transposed {
            let block_size = std::cmp::min(4096, self.size);

            let mut batch_dists = [0.0f32; 16384];

            for block_start in (0..self.size).step_by(block_size) {
                let block_end = std::cmp::min(block_start + block_size, self.size);
                let block_len = block_end - block_start;

                for i in (0..block_len).step_by(8) {
                    let batch = std::cmp::min(8, block_len - i);
                    self.compute_batch_distances_transposed(query, block_start + i, batch, &mut batch_dists[i..i+batch]);
                }

                for i in 0..block_len {
                    let dist = batch_dists[i];
                    self.insert_top_k(&mut top_distances, &mut top_labels, k, dist, (block_start + i) as i64);
                }
            }
        } else {
            let mut vec_ptr = self.vectors.as_ptr();
            let dim = self.dimension;

            let mut i = 0;
            if dim == 128 || dim == 256 {
                // 对128D和256D专门优化，每次处理8个向量，参考C++实现
                while i + 7 < self.size {
                    // 软件预取，减少内存访问延迟
                    #[cfg(target_arch = "x86_64")]
                    unsafe {
                        std::arch::x86_64::_mm_prefetch(
                            vec_ptr.add(8 * dim) as *const i8,
                            std::arch::x86_64::_MM_HINT_T0
                        );
                        std::arch::x86_64::_mm_prefetch(
                            vec_ptr.add(16 * dim) as *const i8,
                            std::arch::x86_64::_MM_HINT_T0
                        );
                    }

                    let dist0 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr, dim) });
                    let dist1 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(dim), dim) });
                    let dist2 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(2 * dim), dim) });
                    let dist3 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(3 * dim), dim) });
                    let dist4 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(4 * dim), dim) });
                    let dist5 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(5 * dim), dim) });
                    let dist6 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(6 * dim), dim) });
                    let dist7 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(7 * dim), dim) });

                    self.insert_top_k(&mut top_distances, &mut top_labels, k, dist0, i as i64);
                    self.insert_top_k(&mut top_distances, &mut top_labels, k, dist1, (i + 1) as i64);
                    self.insert_top_k(&mut top_distances, &mut top_labels, k, dist2, (i + 2) as i64);
                    self.insert_top_k(&mut top_distances, &mut top_labels, k, dist3, (i + 3) as i64);
                    self.insert_top_k(&mut top_distances, &mut top_labels, k, dist4, (i + 4) as i64);
                    self.insert_top_k(&mut top_distances, &mut top_labels, k, dist5, (i + 5) as i64);
                    self.insert_top_k(&mut top_distances, &mut top_labels, k, dist6, (i + 6) as i64);
                    self.insert_top_k(&mut top_distances, &mut top_labels, k, dist7, (i + 7) as i64);

                    vec_ptr = unsafe { vec_ptr.add(8 * dim) };
                    i += 8;
                }
            } else {
                    // 对其他维度，每次处理8个向量
                    while i + 7 < self.size {
                        // 软件预取，减少内存访问延迟
                        #[cfg(target_arch = "x86_64")]
                        unsafe {
                            std::arch::x86_64::_mm_prefetch(
                                vec_ptr.add(8 * dim) as *const i8,
                                std::arch::x86_64::_MM_HINT_T0
                            );
                            std::arch::x86_64::_mm_prefetch(
                                vec_ptr.add(16 * dim) as *const i8,
                                std::arch::x86_64::_MM_HINT_T0
                            );
                        }

                        let dist0 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr, dim) });
                        let dist1 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(dim), dim) });
                        let dist2 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(2 * dim), dim) });
                        let dist3 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(3 * dim), dim) });
                        let dist4 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(4 * dim), dim) });
                        let dist5 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(5 * dim), dim) });
                        let dist6 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(6 * dim), dim) });
                        let dist7 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(7 * dim), dim) });

                        self.insert_top_k(&mut top_distances, &mut top_labels, k, dist0, i as i64);
                        self.insert_top_k(&mut top_distances, &mut top_labels, k, dist1, (i + 1) as i64);
                        self.insert_top_k(&mut top_distances, &mut top_labels, k, dist2, (i + 2) as i64);
                        self.insert_top_k(&mut top_distances, &mut top_labels, k, dist3, (i + 3) as i64);
                        self.insert_top_k(&mut top_distances, &mut top_labels, k, dist4, (i + 4) as i64);
                        self.insert_top_k(&mut top_distances, &mut top_labels, k, dist5, (i + 5) as i64);
                        self.insert_top_k(&mut top_distances, &mut top_labels, k, dist6, (i + 6) as i64);
                        self.insert_top_k(&mut top_distances, &mut top_labels, k, dist7, (i + 7) as i64);

                        vec_ptr = unsafe { vec_ptr.add(8 * dim) };
                        i += 8;
                    }
                }

            for j in i..self.size {
                let vec = unsafe { std::slice::from_raw_parts(vec_ptr, dim) };
                let dist = self.compute_l2_distance(query, vec);

                self.insert_top_k(&mut top_distances, &mut top_labels, k, dist, j as i64);
                
                vec_ptr = unsafe { vec_ptr.add(dim) };
            }
        }

        Ok((top_labels, top_distances))
    }

    fn search_parallel(&self, query: &[f32], k: usize) -> PyResult<(Vec<i64>, Vec<f32>)> {
        if self.size <= 10000 {
            return self.search_single(query, k);
        }

        let num_threads = self.calculate_optimal_search_threads();

        let min_vectors_per_thread = 1000;
        let max_threads = std::cmp::min(num_threads, self.size / min_vectors_per_thread + 1);
        let max_threads = std::cmp::max(1, max_threads);

        let vectors_per_thread = self.size / max_threads;
        let remainder = self.size % max_threads;

        let mut thread_results = vec![(vec![f32::MAX; k], vec![0i64; k]); max_threads];

        thread_results.par_iter_mut().enumerate().for_each(|(t, (thread_distances, thread_labels))| {
            let start = t * vectors_per_thread + std::cmp::min(t, remainder);
            let end = start + vectors_per_thread + if t < remainder { 1 } else { 0 };

            for i in 0..k {
                thread_distances[i] = f32::MAX;
                thread_labels[i] = 0;
            }

            #[cfg(target_arch = "x86_64")]
            unsafe {
                // 预取查询向量到缓存，参考C++实现
                std::arch::x86_64::_mm_prefetch(
                    query.as_ptr() as *const i8,
                    std::arch::x86_64::_MM_HINT_T0
                );
                if query.len() > 64 {
                    std::arch::x86_64::_mm_prefetch(
                        query.as_ptr().add(64) as *const i8,
                        std::arch::x86_64::_MM_HINT_T0
                    );
                }
                if query.len() > 128 {
                    std::arch::x86_64::_mm_prefetch(
                        query.as_ptr().add(128) as *const i8,
                        std::arch::x86_64::_MM_HINT_T0
                    );
                }
                if query.len() > 192 {
                    std::arch::x86_64::_mm_prefetch(
                        query.as_ptr().add(192) as *const i8,
                        std::arch::x86_64::_MM_HINT_T0
                    );
                }
            }

            if self.transposed {
                let batch_size = 4096;
                let mut batch_dists = [0.0f32; 16384];

                let mut i = start;
                while i < end {
                    let current_batch_size = std::cmp::min(batch_size, end - i);

                    for j in (0..current_batch_size).step_by(8) {
                        let sub_batch_size = std::cmp::min(8, current_batch_size - j);
                        self.compute_batch_distances_transposed(query, i + j, sub_batch_size, &mut batch_dists[j..j+sub_batch_size]);
                    }

                    for j in 0..current_batch_size {
                        let dist = batch_dists[j];
                        self.insert_top_k(thread_distances, thread_labels, k, dist, (i + j) as i64);
                    }

                    i += current_batch_size;
                }
            } else {
                let dim = self.dimension;
                let mut vec_ptr = unsafe { self.vectors.as_ptr().add(start * dim) };
                let mut i = start;

                if dim == 128 || dim == 256 {
                    // 对128D和256D专门优化，每次处理8个向量，参考C++实现
                    while i + 7 < end {
                        // 软件预取，减少内存访问延迟
                        #[cfg(target_arch = "x86_64")]
                        unsafe {
                            std::arch::x86_64::_mm_prefetch(
                                vec_ptr.add(8 * dim) as *const i8,
                                std::arch::x86_64::_MM_HINT_T0
                            );
                            std::arch::x86_64::_mm_prefetch(
                                vec_ptr.add(16 * dim) as *const i8,
                                std::arch::x86_64::_MM_HINT_T0
                            );
                        }

                        let dist0 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr, dim) });
                        let dist1 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(dim), dim) });
                        let dist2 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(2 * dim), dim) });
                        let dist3 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(3 * dim), dim) });
                        let dist4 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(4 * dim), dim) });
                        let dist5 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(5 * dim), dim) });
                        let dist6 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(6 * dim), dim) });
                        let dist7 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(7 * dim), dim) });

                        self.insert_top_k(thread_distances, thread_labels, k, dist0, i as i64);
                        self.insert_top_k(thread_distances, thread_labels, k, dist1, (i + 1) as i64);
                        self.insert_top_k(thread_distances, thread_labels, k, dist2, (i + 2) as i64);
                        self.insert_top_k(thread_distances, thread_labels, k, dist3, (i + 3) as i64);
                        self.insert_top_k(thread_distances, thread_labels, k, dist4, (i + 4) as i64);
                        self.insert_top_k(thread_distances, thread_labels, k, dist5, (i + 5) as i64);
                        self.insert_top_k(thread_distances, thread_labels, k, dist6, (i + 6) as i64);
                        self.insert_top_k(thread_distances, thread_labels, k, dist7, (i + 7) as i64);

                        vec_ptr = unsafe { vec_ptr.add(8 * dim) };
                        i += 8;
                    }
                } else {
                    // 对其他维度，每次处理8个向量
                    while i + 7 < end {
                        // 软件预取，减少内存访问延迟
                        #[cfg(target_arch = "x86_64")]
                        unsafe {
                            std::arch::x86_64::_mm_prefetch(
                                vec_ptr.add(8 * dim) as *const i8,
                                std::arch::x86_64::_MM_HINT_T0
                            );
                            std::arch::x86_64::_mm_prefetch(
                                vec_ptr.add(16 * dim) as *const i8,
                                std::arch::x86_64::_MM_HINT_T0
                            );
                        }

                        let dist0 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr, dim) });
                        let dist1 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(dim), dim) });
                        let dist2 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(2 * dim), dim) });
                        let dist3 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(3 * dim), dim) });
                        let dist4 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(4 * dim), dim) });
                        let dist5 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(5 * dim), dim) });
                        let dist6 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(6 * dim), dim) });
                        let dist7 = self.compute_l2_distance(query, unsafe { std::slice::from_raw_parts(vec_ptr.add(7 * dim), dim) });

                        self.insert_top_k(thread_distances, thread_labels, k, dist0, i as i64);
                        self.insert_top_k(thread_distances, thread_labels, k, dist1, (i + 1) as i64);
                        self.insert_top_k(thread_distances, thread_labels, k, dist2, (i + 2) as i64);
                        self.insert_top_k(thread_distances, thread_labels, k, dist3, (i + 3) as i64);
                        self.insert_top_k(thread_distances, thread_labels, k, dist4, (i + 4) as i64);
                        self.insert_top_k(thread_distances, thread_labels, k, dist5, (i + 5) as i64);
                        self.insert_top_k(thread_distances, thread_labels, k, dist6, (i + 6) as i64);
                        self.insert_top_k(thread_distances, thread_labels, k, dist7, (i + 7) as i64);

                        vec_ptr = unsafe { vec_ptr.add(8 * dim) };
                        i += 8;
                    }
                }

                for j in i..end {
                    let vec = unsafe { std::slice::from_raw_parts(vec_ptr, dim) };
                    let dist = self.compute_l2_distance(query, vec);

                    self.insert_top_k(thread_distances, thread_labels, k, dist, j as i64);
                    vec_ptr = unsafe { vec_ptr.add(dim) };
                }
            }
        });

        let mut final_distances = vec![f32::MAX; k];
        let mut final_labels = vec![0i64; k];

        for (thread_distances, thread_labels) in thread_results {
            for i in 0..k {
                let dist = thread_distances[i];
                let label = thread_labels[i];
                self.insert_top_k(&mut final_distances, &mut final_labels, k, dist, label);
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
