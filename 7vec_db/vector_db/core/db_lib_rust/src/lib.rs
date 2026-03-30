use pyo3::prelude::*;

#[pyclass]
struct FlatIndex {
    vectors: Vec<f64>,
    dimension: usize,
    size: usize,
}

#[pymethods]
impl FlatIndex {
    #[new]
    fn new() -> Self {
        FlatIndex {
            vectors: Vec::new(),
            dimension: 0,
            size: 0,
        }
    }

    fn add(&mut self, vectors: Vec<Vec<f64>>) -> PyResult<()> {
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

        for vec in vectors {
            if vec.len() != self.dimension {
                return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                    "All vectors must have the same dimension",
                ));
            }
            self.vectors.extend(vec);
            self.size += 1;
        }

        Ok(())
    }

    fn search(&self, query: Vec<f64>, k: usize) -> PyResult<(Vec<i64>, Vec<f64>)> {
        if self.size == 0 {
            return Ok((Vec::new(), Vec::new()));
        }

        if query.len() != self.dimension {
            return Err(PyErr::new::<pyo3::exceptions::PyValueError, _>(
                "Query vector dimension mismatch",
            ));
        }

        let mut results: Vec<(f64, i64)> = Vec::with_capacity(self.size);

        for i in 0..self.size {
            let start = i * self.dimension;
            let end = start + self.dimension;
            let vec = &self.vectors[start..end];
            let distance = self.l2_squared_distance(&query, vec);
            results.push((distance, i as i64));
        }

        results.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

        let k = k.min(self.size);
        let (distances, labels): (Vec<f64>, Vec<i64>) = results.into_iter().take(k).unzip();

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
    fn l2_squared_distance(&self, a: &[f64], b: &[f64]) -> f64 {
        a.iter().zip(b.iter())
            .map(|(x, y)| (x - y).powi(2))
            .sum::<f64>()
    }
}

#[pymodule]
fn vector_db_rust(_py: Python, m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_class::<FlatIndex>()?;
    Ok(())
}