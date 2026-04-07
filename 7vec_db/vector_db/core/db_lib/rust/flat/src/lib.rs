use pyo3::prelude::*;
use rayon::prelude::*;
use core::distance::compute_l2_distance;
use core::VectorStorage;

#[pyclass]
struct FlatIndex {
    storage: VectorStorage,
}

#[pymethods]
impl FlatIndex {
    #[new]
    fn new(dimension: usize) -&gt; Self {
        Self {
            storage: VectorStorage::new(dimension),
        }
    }

    fn add(&amp;mut self, vectors: Vec&lt;Vec&lt;f32&gt;&gt;) -&gt; PyResult&lt;()&gt; {
        if vectors.is_empty() {
            return Ok(());
        }

        let first_dim = vectors[0].len();
        if self.storage.dimension == 0 {
            return Err(PyErr::new::&lt;pyo3::exceptions::PyValueError, _&gt;(
                "Dimension not set, use new(dimension) instead",
            ));
        } else if self.storage.dimension != first_dim {
            return Err(PyErr::new::&lt;pyo3::exceptions::PyValueError, _&gt;(
                "All vectors must have the same dimension",
            ));
        }

        let num_vectors = vectors.len();
        let mut flat_data = Vec::with_capacity(num_vectors * self.storage.dimension);
        for vec in vectors {
            if vec.len() != self.storage.dimension {
                return Err(PyErr::new::&lt;pyo3::exceptions::PyValueError, _&gt;(
                    "All vectors must have the same dimension",
                ));
            }
            flat_data.extend(vec);
        }

        self.storage.add(num_vectors, &amp;flat_data);

        Ok(())
    }

    fn add_buf(&amp;mut self, buffer: &amp;Bound&lt;'_, PyAny&gt;) -&gt; PyResult&lt;()&gt; {
        use pyo3::buffer::PyBuffer;

        let buffer = PyBuffer::&lt;f32&gt;::get(buffer)?;
        let dimensions = buffer.dimensions();

        if dimensions != 2 {
            return Err(PyErr::new::&lt;pyo3::exceptions::PyValueError, _&gt;(
                "Input must be a 2D array",
            ));
        }

        let shape = buffer.shape();
        let num_vectors = shape[0];
        let dim = shape[1];

        if num_vectors == 0 {
            return Ok(());
        }

        if self.storage.dimension == 0 {
            return Err(PyErr::new::&lt;pyo3::exceptions::PyValueError, _&gt;(
                "Dimension not set, use new(dimension) instead",
            ));
        } else if self.storage.dimension != dim {
            return Err(PyErr::new::&lt;pyo3::exceptions::PyValueError, _&gt;(
                "Dimension mismatch",
            ));
        }

        let buffer_ptr = buffer.buf_ptr() as *const f32;
        let slice = unsafe { std::slice::from_raw_parts(buffer_ptr, num_vectors * dim) };
        self.storage.add(num_vectors, slice);

        Ok(())
    }

    fn search(&amp;self, query: Vec&lt;f32&gt;, k: usize) -&gt; PyResult&lt;(Vec&lt;i64&gt;, Vec&lt;f32&gt;)&gt; {
        if self.storage.size == 0 {
            return Ok((Vec::new(), Vec::new()));
        }

        if query.len() != self.storage.dimension {
            return Err(PyErr::new::&lt;pyo3::exceptions::PyValueError, _&gt;(
                "Query vector dimension mismatch",
            ));
        }

        self.search_single(&amp;query, k)
    }

    fn search_buf(&amp;self, buffer: &amp;Bound&lt;'_, PyAny&gt;, k: usize) -&gt; PyResult&lt;(Vec&lt;i64&gt;, Vec&lt;f32&gt;)&gt; {
        use pyo3::buffer::PyBuffer;

        if self.storage.size == 0 {
            return Ok((Vec::new(), Vec::new()));
        }

        let buffer = PyBuffer::&lt;f32&gt;::get(buffer)?;
        let dimensions = buffer.dimensions();

        if dimensions != 2 {
            return Err(PyErr::new::&lt;pyo3::exceptions::PyValueError, _&gt;(
                "Input must be a 2D array",
            ));
        }

        let shape = buffer.shape();
        let rows = shape[0];
        let cols = shape[1];

        if rows != 1 {
            return Err(PyErr::new::&lt;pyo3::exceptions::PyValueError, _&gt;(
                "Input must be a 2D array with shape (1, dimension)",
            ));
        }

        let dim = cols;

        if dim != self.storage.dimension {
            return Err(PyErr::new::&lt;pyo3::exceptions::PyValueError, _&gt;(
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

        self.search_single(&amp;query_vec, k)
    }

    fn search_batch_buf(&amp;self, buffer: &amp;Bound&lt;'_, PyAny&gt;, k: usize) -&gt; PyResult&lt;(Vec&lt;Vec&lt;i64&gt;&gt;, Vec&lt;Vec&lt;f32&gt;&gt;)&gt; {
        use pyo3::buffer::PyBuffer;

        if self.storage.size == 0 {
            return Ok((Vec::new(), Vec::new()));
        }

        let buffer = PyBuffer::&lt;f32&gt;::get(buffer)?;
        let dimensions = buffer.dimensions();

        if dimensions != 2 {
            return Err(PyErr::new::&lt;pyo3::exceptions::PyValueError, _&gt;(
                "Input must be a 2D array",
            ));
        }

        let shape = buffer.shape();
        let num_queries = shape[0];
        let dim = shape[1];

        if dim != self.storage.dimension {
            return Err(PyErr::new::&lt;pyo3::exceptions::PyValueError, _&gt;(
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

        if num_threads &gt; 1 &amp;&amp; num_queries &gt; 10 {
            let results: Vec&lt;(Vec&lt;i64&gt;, Vec&lt;f32&gt;)&gt; = queries
                .par_iter()
                .map(|query| self.search_single(query, k).unwrap())
                .collect();

            for (labels, distances) in results {
                all_labels.push(labels);
                all_distances.push(distances);
            }
        } else {
            for query in queries {
                let (labels, distances) = self.search_single(&amp;query, k)?;
                all_labels.push(labels);
                all_distances.push(distances);
            }
        }

        Ok((all_labels, all_distances))
    }

    fn size(&amp;self) -&gt; usize {
        self.storage.size
    }

    fn dimension(&amp;self) -&gt; usize {
        self.storage.dimension
    }
}

impl FlatIndex {
    #[inline]
    fn insert_top_k(
        &amp;self,
        distances: &amp;mut [f32],
        labels: &amp;mut [i64],
        k: usize,
        dist: f32,
        idx: i64,
    ) {
        if dist &gt;= distances[k - 1] {
            return;
        }

        let mut left = 0;
        let mut right = k;
        while left &lt; right {
            let mid = (left + right) / 2;
            if dist &lt; distances[mid] {
                right = mid;
            } else {
                left = mid + 1;
            }
        }

        if left &lt; k {
            unsafe {
                let move_count = k - left - 1;
                if move_count &gt; 0 {
                    std::ptr::copy(
                        distances.as_ptr().add(left),
                        distances.as_mut_ptr().add(left + 1),
                        move_count,
                    );
                    std::ptr::copy(
                        labels.as_ptr().add(left),
                        labels.as_mut_ptr().add(left + 1),
                        move_count,
                    );
                }
                distances[left] = dist;
                labels[left] = idx;
            }
        }
    }

    #[inline]
    fn calculate_optimal_search_threads(&amp;self) -&gt; usize {
        let num_threads = num_cpus::get();

        let num_threads = if self.storage.size &gt; 500000 {
            std::cmp::min(num_threads, 10)
        } else if self.storage.size &gt; 100000 {
            std::cmp::min(num_threads, 6)
        } else if self.storage.size &gt; 10000 {
            std::cmp::min(num_threads, 4)
        } else {
            1
        };

        if self.storage.dimension &gt; 256 {
            std::cmp::max(1, num_threads / 2)
        } else {
            num_threads
        }
    }

    fn search_single(&amp;self, query: &amp;[f32], k: usize) -&gt; PyResult&lt;(Vec&lt;i64&gt;, Vec&lt;f32&gt;)&gt; {
        let mut top_distances = vec![f32::MAX; k];
        let mut top_labels = vec![0i64; k];

        if k == 0 || self.storage.size == 0 {
            return Ok((Vec::new(), Vec::new()));
        }

        let mut vec_ptr = self.storage.vectors.as_ptr();
        let dim = self.storage.dimension;

        let mut i = 0;
        while i + 7 &lt; self.storage.size {
            #[cfg(target_arch = "x86_64")]
            unsafe {
                std::arch::x86_64::_mm_prefetch(
                    vec_ptr.add(8 * dim) as *const i8,
                    std::arch::x86_64::_MM_HINT_T0,
                );
                std::arch::x86_64::_mm_prefetch(
                    vec_ptr.add(16 * dim) as *const i8,
                    std::arch::x86_64::_MM_HINT_T0,
                );
            }

            let dist0 = compute_l2_distance(
                query,
                unsafe { std::slice::from_raw_parts(vec_ptr, dim) },
                dim,
            );
            let dist1 = compute_l2_distance(
                query,
                unsafe { std::slice::from_raw_parts(vec_ptr.add(dim), dim) },
                dim,
            );
            let dist2 = compute_l2_distance(
                query,
                unsafe { std::slice::from_raw_parts(vec_ptr.add(2 * dim), dim) },
                dim,
            );
            let dist3 = compute_l2_distance(
                query,
                unsafe { std::slice::from_raw_parts(vec_ptr.add(3 * dim), dim) },
                dim,
            );
            let dist4 = compute_l2_distance(
                query,
                unsafe { std::slice::from_raw_parts(vec_ptr.add(4 * dim), dim) },
                dim,
            );
            let dist5 = compute_l2_distance(
                query,
                unsafe { std::slice::from_raw_parts(vec_ptr.add(5 * dim), dim) },
                dim,
            );
            let dist6 = compute_l2_distance(
                query,
                unsafe { std::slice::from_raw_parts(vec_ptr.add(6 * dim), dim) },
                dim,
            );
            let dist7 = compute_l2_distance(
                query,
                unsafe { std::slice::from_raw_parts(vec_ptr.add(7 * dim), dim) },
                dim,
            );

            self.insert_top_k(&amp;mut top_distances, &amp;mut top_labels, k, dist0, i as i64);
            self.insert_top_k(
                &amp;mut top_distances,
                &amp;mut top_labels,
                k,
                dist1,
                (i + 1) as i64,
            );
            self.insert_top_k(
                &amp;mut top_distances,
                &amp;mut top_labels,
                k,
                dist2,
                (i + 2) as i64,
            );
            self.insert_top_k(
                &amp;mut top_distances,
                &amp;mut top_labels,
                k,
                dist3,
                (i + 3) as i64,
            );
            self.insert_top_k(
                &amp;mut top_distances,
                &amp;mut top_labels,
                k,
                dist4,
                (i + 4) as i64,
            );
            self.insert_top_k(
                &amp;mut top_distances,
                &amp;mut top_labels,
                k,
                dist5,
                (i + 5) as i64,
            );
            self.insert_top_k(
                &amp;mut top_distances,
                &amp;mut top_labels,
                k,
                dist6,
                (i + 6) as i64,
            );
            self.insert_top_k(
                &amp;mut top_distances,
                &amp;mut top_labels,
                k,
                dist7,
                (i + 7) as i64,
            );

            vec_ptr = unsafe { vec_ptr.add(8 * dim) };
            i += 8;
        }

        for (; i &lt; self.storage.size; ++i) {
            let dist = compute_l2_distance(
                query,
                unsafe { std::slice::from_raw_parts(vec_ptr, dim) },
                dim,
            );

            self.insert_top_k(&amp;mut top_distances, &amp;mut top_labels, k, dist, i as i64);
            vec_ptr = unsafe { vec_ptr.add(dim) };
        }

        Ok((top_labels, top_distances))
    }
}

#[pymodule]
fn _flat(m: &amp;Bound&lt;'_, PyModule&gt;) -&gt; PyResult&lt;()&gt; {
    m.add_class::&lt;FlatIndex&gt;()?;
    m.add("__version__", "1.0.0")?;
    Ok(())
}
