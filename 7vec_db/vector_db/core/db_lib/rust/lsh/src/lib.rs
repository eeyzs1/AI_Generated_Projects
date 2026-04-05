use pyo3::prelude::*;
use core::distance;
use core::VectorStorage;
use rand::Rng;
use std::collections::{HashMap, HashSet};

#[pyclass]
struct IndexLSH {
    storage: VectorStorage,
    num_hash_tables: usize,
    num_hash_functions: usize,
    r: f32,
    hash_functions: Vec<Vec<Vec<f32>>>,
    hash_tables: Vec<HashMap<usize, Vec<usize>>>,
}

#[pymethods]
impl IndexLSH {
    #[new]
    fn new(dimension: usize, num_hash_tables: Option<usize>, num_hash_functions: Option<usize>, r: Option<f32>) -> Self {
        let num_hash_tables = num_hash_tables.unwrap_or(8);
        let num_hash_functions = num_hash_functions.unwrap_or(4);
        let r = r.unwrap_or(1.0);
        let mut obj = Self {
            storage: VectorStorage::new(dimension),
            num_hash_tables,
            num_hash_functions,
            r,
            hash_functions: Vec::new(),
            hash_tables: vec![HashMap::new(); num_hash_tables],
        };
        obj.generate_hash_functions();
        obj
    }

    fn add(&mut self, x: Vec<Vec<f32>>) -> PyResult<()> {
        let n = x.len();
        if n == 0 {
            return Ok(());
        }

        let dim = self.storage.dimension;
        let old_total = self.storage.size;
        let mut flat_data = Vec::with_capacity(n * dim);
        for vec in x {
            flat_data.extend(vec);
        }
        self.storage.add(n, &flat_data);

        for i in 0..n {
            let idx = old_total + i;
            let vec = &flat_data[i * dim..(i + 1) * dim];
            for t in 0..self.num_hash_tables {
                let hash = self.hash_vector(vec, t);
                self.hash_tables[t].entry(hash).or_insert_with(Vec::new).push(idx);
            }
        }

        Ok(())
    }

    fn search(&self, x: Vec<Vec<f32>>, k: usize) -> PyResult<(Vec<Vec<i64>>, Vec<Vec<f32>>)> {
        let dim = self.storage.dimension;
        let mut all_labels = Vec::with_capacity(x.len());
        let mut all_distances = Vec::with_capacity(x.len());

        for query in x {
            let mut candidates = HashSet::new();
            for t in 0..self.num_hash_tables {
                let hash = self.hash_vector(&query, t);
                if let Some(indices) = self.hash_tables[t].get(&hash) {
                    for &idx in indices {
                        candidates.insert(idx);
                    }
                }
            }

            let mut results = Vec::with_capacity(candidates.len());
            for idx in candidates {
                let vec = &self.storage.vectors[idx * dim..(idx + 1) * dim];
                let dist = distance::compute_l2_distance(&query, vec);
                results.push((dist, idx as i64));
            }
            results.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

            let take = std::cmp::min(k, results.len());
            let mut labels = Vec::with_capacity(k);
            let mut distances = Vec::with_capacity(k);
            for (dist, idx) in results.iter().take(take) {
                labels.push(*idx);
                distances.push(*dist);
            }
            for _ in take..k {
                labels.push(0);
                distances.push(0.0);
            }

            all_labels.push(labels);
            all_distances.push(distances);
        }

        Ok((all_labels, all_distances))
    }

    #[getter]
    fn ntotal(&self) -> usize {
        self.storage.size
    }

    #[getter]
    fn dimension(&self) -> usize {
        self.storage.dimension
    }

    #[getter]
    fn num_hash_tables(&self) -> usize {
        self.num_hash_tables
    }

    #[getter]
    fn num_hash_functions(&self) -> usize {
        self.num_hash_functions
    }
}

impl IndexLSH {
    fn generate_hash_functions(&mut self) {
        let dim = self.storage.dimension;
        self.hash_functions = Vec::with_capacity(self.num_hash_tables);
        let mut rng = rand::thread_rng();

        for _ in 0..self.num_hash_tables {
            let mut table = Vec::with_capacity(self.num_hash_functions);
            for _ in 0..self.num_hash_functions {
                let mut func = Vec::with_capacity(dim + 1);
                for _ in 0..dim {
                    func.push(rng.sample(rand_distr::StandardNormal));
                }
                func.push(rng.gen_range(0.0..self.r));
                table.push(func);
            }
            self.hash_functions.push(table);
        }
    }

    fn hash_vector(&self, vec: &[f32], table_idx: usize) -> usize {
        let dim = self.storage.dimension;
        let mut hash = 0;
        for h in 0..self.num_hash_functions {
            let mut dot = 0.0f32;
            for i in 0..dim {
                dot += vec[i] * self.hash_functions[table_idx][h][i];
            }
            dot += self.hash_functions[table_idx][h][dim];
            let bit = ((dot / self.r).floor() as i32) & 1;
            hash = (hash << 1) | (bit as usize);
        }
        hash
    }
}

#[pymodule]
fn vectordb_lsh(_py: Python, m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_class::<IndexLSH>()?;
    Ok(())
}
