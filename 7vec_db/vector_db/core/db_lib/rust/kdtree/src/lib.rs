use pyo3::prelude::*;
use core::distance;
use core::VectorStorage;
use std::collections::BinaryHeap;
use std::cmp::Reverse;
use ordered_float::NotNan;

#[pyclass]
struct KDNode {
    index: usize,
    split_axis: usize,
    left: Option<Box<KDNode>>,
    right: Option<Box<KDNode>>,
}

impl KDNode {
    fn new(index: usize, split_axis: usize) -> Self {
        Self {
            index,
            split_axis,
            left: None,
            right: None,
        }
    }
}

#[pyclass]
struct IndexKDTree {
    storage: VectorStorage,
    leaf_size: usize,
    root: Option<Box<KDNode>>,
}

#[pymethods]
impl IndexKDTree {
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

        let mut indices: Vec<usize> = (old_total..self.storage.size).collect();
        self.root = self.build_tree(&mut indices, 0);

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

impl IndexKDTree {
    fn build_tree(&self, indices: &mut [usize], depth: usize) -> Option<Box<KDNode>> {
        if indices.is_empty() {
            return None;
        }

        let dim = self.storage.dimension;
        let axis = depth % dim;

        indices.sort_by(|&a, &b| {
            let va = &self.storage.vectors[a * dim..(a + 1) * dim];
            let vb = &self.storage.vectors[b * dim..(b + 1) * dim];
            va[axis].partial_cmp(&vb[axis]).unwrap()
        });

        let median = indices.len() / 2;
        let mut node = Box::new(KDNode::new(indices[median], axis));

        let (left_part, right_part) = indices.split_at_mut(median);
        let right_part = &mut right_part[1..];

        node.left = self.build_tree(left_part, depth + 1);
        node.right = self.build_tree(right_part, depth + 1);

        Some(node)
    }

    fn search_k_nearest(&self, query: &[f32], node: &KDNode, k: usize, heap: &mut BinaryHeap<Reverse<(NotNan<f32>, usize)>>) {
        let dim = self.storage.dimension;
        let vec = &self.storage.vectors[node.index * dim..(node.index + 1) * dim];
        let dist = distance::compute_l2_distance(query, vec);

        if heap.len() < k {
            heap.push(Reverse((NotNan::new(dist).unwrap(), node.index)));
        } else if dist < heap.peek().unwrap().0.0.into_inner() {
            heap.pop();
            heap.push(Reverse((NotNan::new(dist).unwrap(), node.index)));
        }

        let diff = query[node.split_axis] - vec[node.split_axis];
        let near_child = if diff < 0.0 { &node.left } else { &node.right };
        let far_child = if diff < 0.0 { &node.right } else { &node.left };

        if let Some(child) = near_child {
            self.search_k_nearest(query, child, k, heap);
        }

        if heap.len() < k || diff * diff < heap.peek().unwrap().0.0.into_inner() {
            if let Some(child) = far_child {
                self.search_k_nearest(query, child, k, heap);
            }
        }
    }
}

#[pymodule]
fn vectordb_kdtree(_py: Python, m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_class::<IndexKDTree>()?;
    Ok(())
}
