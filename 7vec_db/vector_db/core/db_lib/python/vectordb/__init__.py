"""
7VecDB - A high-performance vector database library with modular algorithms.

This library provides both C++ and Rust implementations of various vector
indexing algorithms, all accessible through a unified Python interface.
"""

__version__ = "1.0.0"
__author__ = "7VecDB Team"

from .index import VectorIndex, IndexType

__all__ = ["VectorIndex", "IndexType"]
