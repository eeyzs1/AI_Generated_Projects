use pyo3::prelude::*;
use core::distance;
use core::VectorStorage;
use std::collections::BinaryHeap;
use std::cmp::Reverse;
use ordered_float::NotNan;

#[pyclass]
struct BallNode {
    points: Vec<usize>,
    center: Vec<f32>,
    radius: f32,
    left: Option<Box<BallNode>>,
    right: Option<Box<BallNode>>,
}

impl BallNode {
    fn new() -> Self {
        Self {
            points: Vec::new(),
            center: Vec::new(),
            radius: 0.0,
            left: None,
            right: None,
        }
    }
}

#[pyclass]
struct IndexBallTree {
    storage: VectorStorage,
    leaf_size: usize,
    root: Option<Box<BallNode>>,
}

#[pymethods]
impl IndexBallTree {
    #[new]
    fn new(dimension: usize, leaf_size: Option<usize>) -> Self {
        let leaf_size = leaf_size.unwrap_or(40);
        Self {
            storage: VectorStorage::new(dimension),
            leaf_size,
            root: None,
        }
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

        let indices: Vec<usize> = (old_total..self.storage.size).collect();
        self.root = self.build_tree(&indices);

        Ok(())
    }

    fn search(&self, x: Vec<Vec<f32>>, k: usize) -> PyResult<(Vec<Vec<i64>>, Vec<Vec<f32>>)> {
        let _dim = self.storage.dimension;
        let mut all_labels = Vec::with_capacity(x.len());
        let mut all_distances = Vec::with_capacity(x.len());

        for query in x {
            let mut heap = BinaryHeap::new();
            if let Some(root) = &self.root {
                self.search_k_nearest(&query, root, k, &mut heap);
            }

            let mut results = Vec::with_capacity(heap.len());
            while let Some(Reverse((dist, idx))) = heap.pop() {
                results.push((dist.into_inner(), idx as i64));
            }
            results.reverse();

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
    fn leaf_size(&self) -> usize {
        self.leaf_size
    }
}

impl IndexBallTree {
    fn build_tree(&self, indices: &[usize]) -> Option<Box<BallNode>> {
        let dim = self.storage.dimension;
        let mut node = Box::new(BallNode::new());
        node.points = indices.to_vec();

        if indices.len() <= self.leaf_size {
            node.center = vec![0.0f32; dim];
            for &idx in indices {
                let vec = &self.storage.vectors[idx * dim..(idx + 1) * dim];
                for j in 0..dim {
                    node.center[j] += vec[j];
                }
            }
            let inv_size = 1.0 / indices.len() as f32;
            for j in 0..dim {
                node.center[j] *= inv_size;
            }

            node.radius = 0.0;
            for &idx in indices {
                let vec = &self.storage.vectors[idx * dim..(idx + 1) * dim];
                let dist = distance::compute_l2_distance(vec, &node.center);
                node.radius = node.radius.max(dist);
            }

            return Some(node);
        }

        let mut mean = vec![0.0f32; dim];
        for &idx in indices {
            let vec = &self.storage.vectors[idx * dim..(idx + 1) * dim];
            for j in 0..dim {
                mean[j] += vec[j];
            }
        }
        let inv_n = 1.0 / indices.len() as f32;
        for j in 0..dim {
            mean[j] *= inv_n;
        }

        let mut split_dim = 0;
        let mut max_var = 0.0;
        for j in 0..dim {
            let mut var = 0.0;
            for &idx in indices {
                let vec = &self.storage.vectors[idx * dim..(idx + 1) * dim];
                let diff = vec[j] - mean[j];
                var += diff * diff;
            }
            if var > max_var {
                max_var = var;
                split_dim = j;
            }
        }

        let mut sorted_indices = indices.to_vec();
        sorted_indices.sort_by(|&a, &b| {
            let va = &self.storage.vectors[a * dim..(a + 1) * dim];
            let vb = &self.storage.vectors[b * dim..(b + 1) * dim];
            va[split_dim].partial_cmp(&vb[split_dim]).unwrap()
        });

        let median = sorted_indices.len() / 2;
        let left_indices = &sorted_indices[..median];
        let right_indices = &sorted_indices[median..];

        node.left = self.build_tree(left_indices);
        node.right = self.build_tree(right_indices);

        if let (Some(left), Some(right)) = (&node.left, &node.right) {
            node.center = vec![0.0f32; dim];
            for j in 0..dim {
                node.center[j] = (left.center[j] + right.center[j]) / 2.0;
            }
            let d1 = distance::compute_l2_distance(&left.center, &node.center) + left.radius;
            let d2 = distance::compute_l2_distance(&right.center, &node.center) + right.radius;
            node.radius = d1.max(d2);
        }

        Some(node)
    }

    fn search_k_nearest(&self, query: &[f32], node: &BallNode, k: usize, heap: &mut BinaryHeap<Reverse<(NotNan<f32>, usize)>>) {
        let dim = self.storage.dimension;

        if node.points.len() <= self.leaf_size {
            for &idx in &node.points {
                let vec = &self.storage.vectors[idx * dim..(idx + 1) * dim];
                let dist = distance::compute_l2_distance(query, vec);
                if heap.len() < k {
                    heap.push(Reverse((NotNan::new(dist).unwrap(), idx)));
                } else if dist < heap.peek().unwrap().0.0.into_inner() {
                    heap.pop();
                    heap.push(Reverse((NotNan::new(dist).unwrap(), idx)));
                }
            }
            return;
        }

        let (near_child, far_child, dist_to_far) = if let (Some(left), Some(right)) = (&node.left, &node.right) {
            let dist_left = distance::compute_l2_distance(query, &left.center);
            let dist_right = distance::compute_l2_distance(query, &right.center);
            if dist_left < dist_right {
                (left, right, dist_right)
            } else {
                (right, left, dist_left)
            }
        } else {
            return;
        };

        self.search_k_nearest(query, near_child, k, heap);

        if heap.len() < k || dist_to_far - near_child.radius < heap.peek().unwrap().0.0.into_inner() {
            self.search_k_nearest(query, far_child, k, heap);
        }
    }
}

#[pymodule]
fn vectordb_balltree(_py: Python, m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_class::<IndexBallTree>()?;
    Ok(())
}
