use pyo3::prelude::*;
use rayon::prelude::*;
use core::distance::compute_ip_distance;
use core::VectorStorage;

#[pyclass]
struct FlatIPIndex {
    storage: VectorStorage,
}

#[pymethods]
impl FlatIPIndex {
    #[new]
    fn new(dimension: usize) -> Self {
        Self {
            storage: VectorStorage::new(dimension),
        }
    }

    fn add(&mut self, vectors: Vec<Vec<f32>>) -> PyResult<()> {
        if vectors.is_empty() {
            return Ok(());
        }

        let first_dim = vectors[0].len();
        if self.storage.dimension == 0 {
            return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                "Dimension not set, use new(dimension) instead",
            ));
        } else if self.storage.dimension != first_dim {
            return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                "All vectors must have the same dimension",
            ));
        }

        let num_vectors = vectors.len();
        let mut flat_data = Vec::with_capacity(num_vectors * self.storage.dimension);
        for vec in vectors {
            if vec.len() != self.storage.dimension {
                return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                    "All vectors must have the same dimension",
                ));
            }
            flat_data.extend(vec);
        }

        self.storage.add(num_vectors, &flat_data);

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
        let dim = shape[1];

        if num_vectors == 0 {
            return Ok(());
        }

        if self.storage.dimension == 0 {
            return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                "Dimension not set, use new(dimension) instead",
            ));
        } else if self.storage.dimension != dim {
            return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                "Dimension mismatch",
            ));
        }

        let buffer_ptr = buffer.buf_ptr() as *const f32;
        let slice = unsafe { std::slice::from_raw_parts(buffer_ptr, num_vectors * dim) };
        self.storage.add(num_vectors, slice);

        Ok(())
    }

    fn search(&self, query: Vec<f32>, k: usize) -> PyResult<(Vec<i64>, Vec<f32>)> {
        if self.storage.size == 0 {
            return Ok((Vec::new(), Vec::new()));
        }

        if query.len() != self.storage.dimension {
            return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                "Query vector dimension mismatch",
            ));
        }

        self.search_single(&query, k)
    }

    fn search_buf(&self, buffer: &Bound<'_, PyAny>, k: usize) -> PyResult<(Vec<i64>, Vec<f32>)> {
        use pyo3::buffer::PyBuffer;

        if self.storage.size == 0 {
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

        if dim != self.storage.dimension {
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

        self.search_single(&query_vec, k)
    }

    fn search_batch_buf(&self, buffer: &Bound<'_, PyAny>, k: usize) -> PyResult<(Vec<Vec<i64>>, Vec<Vec<f32>>)> {
        use pyo3::buffer::PyBuffer;

        if self.storage.size == 0 {
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

        if dim != self.storage.dimension {
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

        if num_threads > 1 && num_queries > 10 {
            let results: Vec<(Vec<i64>, Vec<f32>)> = queries
                .par_iter()
                .map(|query| self.search_single(query, k).unwrap())
                .collect();

            for (labels, distances) in results {
                all_labels.push(labels);
                all_distances.push(distances);
            }
        } else {
            for query in queries {
                let (labels, distances) = self.search_single(&query, k)?;
                all_labels.push(labels);
                all_distances.push(distances);
            }
        }

        Ok((all_labels, all_distances))
    }

    fn size(&self) -> usize {
        self.storage.size
    }

    fn dimension(&self) -> usize {
        self.storage.dimension
    }
}

impl FlatIPIndex {
    #[inline]
    fn insert_top_k(
        &self,
        distances: &mut [f32],
        labels: &mut [i64],
        k: usize,
        dist: f32,
        idx: i64,
    ) {
        if dist <= distances[k - 1] {
            return;
        }

        let mut left = 0;
        let mut right = k;
        while left < right {
            let mid = (left + right) / 2;
            if dist > distances[mid] {
                right = mid;
            } else {
                left = mid + 1;
            }
        }

        if left < k {
            unsafe {
                let move_count = k - left - 1;
                if move_count > 0 {
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
    fn calculate_optimal_search_threads(&self) -> usize {
        let num_threads = num_cpus::get();

        let num_threads = if self.storage.size > 500000 {
            std::cmp::min(num_threads, 10)
        } else if self.storage.size > 100000 {
            std::cmp::min(num_threads, 6)
        } else if self.storage.size > 10000 {
            std::cmp::min(num_threads, 4)
        } else {
            1
        };

        if self.storage.dimension > 256 {
            std::cmp::max(1, num_threads / 2)
        } else {
            num_threads
        }
    }

    fn search_single(&self, query: &[f32], k: usize) -> PyResult<(Vec<i64>, Vec<f32>)> {
        let mut top_distances = vec![f32::MIN; k];
        let mut top_labels = vec![0i64; k];

        if k == 0 || self.storage.size == 0 {
            return Ok((Vec::new(), Vec::new()));
        }

        let mut vec_ptr = self.storage.vectors.as_ptr();
        let dim = self.storage.dimension;

        let mut i = 0;
        while i < self.storage.size {
            let dist = compute_ip_distance(
                query,
                unsafe { std::slice::from_raw_parts(vec_ptr, dim) },
            );

            self.insert_top_k(&mut top_distances, &mut top_labels, k, dist, i as i64);
            vec_ptr = unsafe { vec_ptr.add(dim) };
            i += 1;
        }

        Ok((top_labels, top_distances))
    }
}

#[pymodule]
fn _flat_ip(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_class::<FlatIPIndex>()?;
    m.add("__version__", "1.0.0")?;
    Ok(())
}
