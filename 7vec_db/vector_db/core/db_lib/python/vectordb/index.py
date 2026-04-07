"""
Vector Index - Unified interface for all vector indexing algorithms.
"""

from enum import Enum
from typing import Any, Tuple, Optional

import numpy as np


class IndexType(Enum):
    """Supported index types."""
    FLAT_L2 = "flat_l2"
    FLAT_IP = "flat_ip"
    HNSW = "hnsw"
    IVF = "ivf"
    PQ = "pq"
    LSH = "lsh"
    KD_TREE = "kd_tree"
    BALL_TREE = "ball_tree"
    ANNOY = "annoy"


class Implementation(Enum):
    """Supported implementations."""
    CPP = "cpp"
    RUST = "rust"


class VectorIndex:
    """
    Unified vector index interface.
    
    This class provides a single interface to all supported vector indexing
    algorithms, implemented in either C++ or Rust.
    """
    
    def __init__(
        self,
        index_type: IndexType,
        dimension: int,
        implementation: Implementation = Implementation.CPP,
        **kwargs: Any
    ):
        """
        Create a new vector index.
        
        Args:
            index_type: Type of index to create
            dimension: Dimension of the vectors
            implementation: Implementation to use (C++ or Rust)
            **kwargs: Additional algorithm-specific parameters
        """
        self.index_type = index_type
        self.dimension = dimension
        self.implementation = implementation
        self._index = None
        self._initialize_index(**kwargs)
    
    def _initialize_index(self, **kwargs: Any):
        """Initialize the underlying index implementation."""
        if self.implementation == Implementation.CPP:
            self._init_cpp_index(**kwargs)
        elif self.implementation == Implementation.RUST:
            self._init_rust_index(**kwargs)
        else:
            raise ValueError(f"Unknown implementation: {self.implementation}")
    
    def _init_cpp_index(self, **kwargs: Any):
        """Initialize C++ implementation."""
        try:
            if self.index_type == IndexType.FLAT_L2:
                from .cpp._flat import IndexFlatL2
                self._index = IndexFlatL2(self.dimension)
            elif self.index_type == IndexType.FLAT_IP:
                from .cpp._flat_ip import IndexFlatIP
                self._index = IndexFlatIP(self.dimension)
            elif self.index_type == IndexType.IVF:
                from .cpp._ivf import IndexIVF
                nlist = kwargs.get('nlist', 100)
                self._index = IndexIVF(self.dimension, nlist)
            elif self.index_type == IndexType.HNSW:
                from .cpp._hnsw import IndexHNSW
                M = kwargs.get('M', 16)
                ef_construction = kwargs.get('ef_construction', 200)
                self._index = IndexHNSW(self.dimension, M, ef_construction)
            elif self.index_type == IndexType.PQ:
                from .cpp._pq import IndexPQ
                M = kwargs.get('M', 8)
                nbits = kwargs.get('nbits', 8)
                self._index = IndexPQ(self.dimension, M, nbits)
            elif self.index_type == IndexType.LSH:
                from .cpp._lsh import IndexLSH
                num_hash_tables = kwargs.get('num_hash_tables', 8)
                num_hash_functions = kwargs.get('num_hash_functions', 4)
                r = kwargs.get('r', 1.0)
                self._index = IndexLSH(self.dimension, num_hash_tables, num_hash_functions, r)
            elif self.index_type == IndexType.KD_TREE:
                from .cpp._kdtree import IndexKDTree
                self._index = IndexKDTree(self.dimension)
            elif self.index_type == IndexType.BALL_TREE:
                from .cpp._balltree import IndexBallTree
                leaf_size = kwargs.get('leaf_size', 40)
                self._index = IndexBallTree(self.dimension, leaf_size)
            elif self.index_type == IndexType.ANNOY:
                from .cpp._annoy import IndexAnnoy
                n_trees = kwargs.get('n_trees', 10)
                search_k = kwargs.get('search_k', 0)
                leaf_size = kwargs.get('leaf_size', 40)
                self._index = IndexAnnoy(self.dimension, n_trees, search_k, leaf_size)
            else:
                raise NotImplementedError(
                    f"Index type {self.index_type} not yet implemented in C++"
                )
        except ImportError as e:
            raise ImportError(
                f"Failed to import C++ implementation: {e}. "
                "Make sure the C++ extensions are compiled."
            )
    
    def _init_rust_index(self, **kwargs: Any):
        """Initialize Rust implementation."""
        try:
            if self.index_type == IndexType.FLAT_L2:
                from .rust._flat import FlatIndex
                self._index = FlatIndex(self.dimension)
            elif self.index_type == IndexType.FLAT_IP:
                from .rust._flat_ip import FlatIPIndex
                self._index = FlatIPIndex(self.dimension)
            else:
                raise NotImplementedError(
                    f"Index type {self.index_type} not yet implemented in Rust"
                )
        except ImportError as e:
            raise ImportError(
                f"Failed to import Rust implementation: {e}. "
                "Make sure the Rust extensions are compiled."
            )
    
    def train(self, vectors: np.ndarray) -&gt; None:
        """
        Train the index (for algorithms that require training, like IVF).
        
        Args:
            vectors: 2D array of training vectors
        """
        if vectors.ndim != 2:
            raise ValueError("Vectors must be a 2D array")
        if vectors.shape[1] != self.dimension:
            raise ValueError(
                f"Vector dimension mismatch: expected {self.dimension}, "
                f"got {vectors.shape[1]}"
            )
        
        if hasattr(self._index, 'train'):
            self._index.train(vectors)
    
    def add(self, vectors: np.ndarray) -&gt; None:
        """
        Add vectors to the index.
        
        Args:
            vectors: 2D array of vectors with shape (n_vectors, dimension)
        """
        if vectors.ndim != 2:
            raise ValueError("Vectors must be a 2D array")
        if vectors.shape[1] != self.dimension:
            raise ValueError(
                f"Vector dimension mismatch: expected {self.dimension}, "
                f"got {vectors.shape[1]}"
            )
        
        if hasattr(self._index, 'add_buf'):
            self._index.add_buf(vectors)
        else:
            self._index.add(vectors)
    
    def set_nprobe(self, nprobe: int) -&gt; None:
        """
        Set the number of clusters to probe during search (for IVF only).
        
        Args:
            nprobe: Number of clusters to probe
        """
        if hasattr(self._index, 'set_nprobe'):
            self._index.set_nprobe(nprobe)
    
    def set_ef_search(self, ef: int) -&gt; None:
        """
        Set the size of the dynamic candidate list during search (for HNSW only).
        
        Args:
            ef: Size of the candidate list
        """
        if hasattr(self._index, 'set_ef_search'):
            self._index.set_ef_search(ef)
    
    def set_search_k(self, search_k: int) -&gt; None:
        """
        Set the number of nodes to inspect during search (for Annoy only).
        
        Args:
            search_k: Number of nodes to inspect
        """
        if hasattr(self._index, 'set_search_k'):
            self._index.set_search_k(search_k)
    
    def search(
        self,
        queries: np.ndarray,
        k: int
    ) -&gt; Tuple[np.ndarray, np.ndarray]:
        """
        Search for nearest neighbors.
        
        Args:
            queries: 2D array of query vectors with shape (n_queries, dimension)
            k: Number of neighbors to return
        
        Returns:
            Tuple of (distances, labels) with shapes (n_queries, k)
        """
        if queries.ndim != 2:
            raise ValueError("Queries must be a 2D array")
        if queries.shape[1] != self.dimension:
            raise ValueError(
                f"Query dimension mismatch: expected {self.dimension}, "
                f"got {queries.shape[1]}"
            )
        
        # 先检查 C++ 绑定的现代接口 (搜索一批查询)
        if hasattr(self._index, 'search') and (
            self.index_type == IndexType.FLAT_L2 or 
            self.index_type == IndexType.FLAT_IP
        ):
            distances, labels = self._index.search(queries, k)
            return np.array(distances), np.array(labels)
        
        # 检查 Rust 绑定接口
        if hasattr(self._index, 'search_batch_buf'):
            labels, distances = self._index.search_batch_buf(queries, k)
            return np.array(distances), np.array(labels)
        elif hasattr(self._index, 'search'):
            if queries.shape[0] == 1:
                distances, labels = self._index.search(queries[0], k)
                return np.array([distances]), np.array([labels])
            else:
                all_distances = []
                all_labels = []
                for query in queries:
                    dist, lbl = self._index.search(query, k)
                    all_distances.append(dist)
                    all_labels.append(lbl)
                return np.array(all_distances), np.array(all_labels)
        else:
            raise NotImplementedError("Search not implemented for this index")
    
    def size(self) -&gt; int:
        """Get the number of vectors in the index."""
        if hasattr(self._index, 'ntotal'):
            return self._index.ntotal
        elif hasattr(self._index, 'size'):
            return self._index.size()
        else:
            raise NotImplementedError("Size not available for this index")
    
    def get_dimension(self) -&gt; int:
        """Get the dimension of the vectors."""
        return self.dimension


def create_index(
    index_type: str,
    dimension: int,
    implementation: str = "cpp",
    **kwargs: Any
) -&gt; VectorIndex:
    """
    Convenience function to create a vector index.
    
    Args:
        index_type: Type of index as string
        dimension: Dimension of the vectors
        implementation: Implementation as string ("cpp" or "rust")
        **kwargs: Additional algorithm-specific parameters
    
    Returns:
        VectorIndex instance
    """
    idx_type = IndexType(index_type.lower())
    impl = Implementation(implementation.lower())
    return VectorIndex(idx_type, dimension, impl, **kwargs)
