use pyo3::prelude::*;
use rayon::prelude::*;

#[pyclass]
struct FlatIndex {
    vectors: Vec<f32>,
    dimension: usize,
    size: usize,
}

#[pymethods]
impl FlatIndex {
    #[new]
    fn new() -> Self {
        // 预分配合理的内存空间，初始容量为100000个向量
        let initial_capacity = 100000 * 256; // 支持100000个256维向量
        FlatIndex {
            vectors: Vec::with_capacity(initial_capacity),
            dimension: 0,
            size: 0,
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

        // 并行计算所有向量的距离
        let distances: Vec<(f32, i64)> = (0..self.size).into_par_iter().map(|i| {
            let start = i * self.dimension;
            let end = start + self.dimension;
            let vec = &self.vectors[start..end];
            let distance = self.l2_squared_distance(&query, vec);
            (distance, i as i64)
        }).collect();

        // 排序并选择top-k
        let mut sorted_distances = distances;
        sorted_distances.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());
        
        // 取前k个结果
        let top_k = sorted_distances.into_iter().take(k).collect::<Vec<_>>();

        // 过滤掉MAX值的结果
        let valid_results: Vec<(f32, i64)> = top_k.into_iter()
            .filter(|&(dist, _)| dist < f32::MAX)
            .collect();

        let (distances, labels): (Vec<f32>, Vec<i64>) = valid_results.into_iter().unzip();

        Ok((labels, distances))
    }

    fn size(&self) -> usize {
        self.size
    }

    fn dimension(&self) -> usize {
        self.dimension
    }
}

impl FlatIndex {
    // 优化的L2距离计算，使用SIMD指令
    fn l2_squared_distance(&self, a: &[f32], b: &[f32]) -> f32 {
        let len = a.len();
        
        // 检查是否支持AVX2指令集
        #[cfg(target_arch = "x86_64")]
        if is_x86_feature_detected!("avx2") && len >= 8 {
            let mut i = 0;
            let mut sum = unsafe {
                std::arch::x86_64::_mm256_setzero_ps()
            };
            
            // 处理每8个元素
            while i + 7 < len {
                // 加载8个单精度浮点数
                let a_chunk = unsafe {
                    std::arch::x86_64::_mm256_loadu_ps(&a[i])
                };
                let b_chunk = unsafe {
                    std::arch::x86_64::_mm256_loadu_ps(&b[i])
                };
                
                // 计算差值
                let diff = unsafe {
                    std::arch::x86_64::_mm256_sub_ps(a_chunk, b_chunk)
                };
                
                // 计算平方
                let diff_sq = unsafe {
                    std::arch::x86_64::_mm256_mul_ps(diff, diff)
                };
                
                // 累加结果
                sum = unsafe {
                    std::arch::x86_64::_mm256_add_ps(sum, diff_sq)
                };
                
                i += 8;
            }
            
            // 水平相加所有结果
            let sum = unsafe {
                // 第一次水平相加
                let sum = std::arch::x86_64::_mm256_hadd_ps(sum, sum);
                // 第二次水平相加
                let sum = std::arch::x86_64::_mm256_hadd_ps(sum, sum);
                sum
            };
            
            // 提取结果
            let mut sum_buf = [0.0f32; 8];
            unsafe {
                std::arch::x86_64::_mm256_storeu_ps(sum_buf.as_mut_ptr(), sum);
            }
            let mut total = sum_buf[0] + sum_buf[1] + sum_buf[2] + sum_buf[3];
            
            // 处理剩余元素
            for j in i..len {
                let diff = a[j] - b[j];
                total += diff * diff;
            }
            
            return total;
        } else if len >= 4 {
            // 对于中等维度，使用SSE指令
            let mut i = 0;
            let mut sum = unsafe {
                std::arch::x86_64::_mm_setzero_ps()
            };
            
            // 处理每4个元素
            while i + 3 < len {
                // 加载4个单精度浮点数
                let a_chunk = unsafe {
                    std::arch::x86_64::_mm_loadu_ps(&a[i])
                };
                let b_chunk = unsafe {
                    std::arch::x86_64::_mm_loadu_ps(&b[i])
                };
                
                // 计算差值
                let diff = unsafe {
                    std::arch::x86_64::_mm_sub_ps(a_chunk, b_chunk)
                };
                
                // 计算平方
                let diff_sq = unsafe {
                    std::arch::x86_64::_mm_mul_ps(diff, diff)
                };
                
                // 累加结果
                sum = unsafe {
                    std::arch::x86_64::_mm_add_ps(sum, diff_sq)
                };
                
                i += 4;
            }
            
            // 水平相加所有结果
            let sum = unsafe {
                // 第一次水平相加
                let sum = std::arch::x86_64::_mm_hadd_ps(sum, sum);
                // 第二次水平相加
                let sum = std::arch::x86_64::_mm_hadd_ps(sum, sum);
                sum
            };
            
            // 提取结果
            let mut sum_buf = [0.0f32; 4];
            unsafe {
                std::arch::x86_64::_mm_storeu_ps(sum_buf.as_mut_ptr(), sum);
            }
            let mut total = sum_buf[0] + sum_buf[1];
            
            // 处理剩余元素
            for j in i..len {
                let diff = a[j] - b[j];
                total += diff * diff;
            }
            
            return total;
        } else {
            // 对于小维度，直接计算
            let mut total = 0.0f32;
            for j in 0..len {
                let diff = a[j] - b[j];
                total += diff * diff;
            }
            return total;
        }
    }
}

#[pymodule]
fn vector_db_rust(_py: Python, m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_class::<FlatIndex>()?;
    m.add("__version__", "1.0.0")?;
    Ok(())
}