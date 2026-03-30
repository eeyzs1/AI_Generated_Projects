#include <pybind11/pybind11.h>
#include <pybind11/stl.h>
#include <pybind11/numpy.h>
#include "vector_db.h"

namespace py = pybind11;

PYBIND11_MODULE(vector_db_cpp, m) {
    m.doc() = "Vector database with L2 distance search, compatible with FAISS IndexFlatL2";
    
    py::class_<IndexFlatL2>(m, "IndexFlatL2")
        .def(py::init<size_t>(), py::arg("dimension"), "Create an IndexFlatL2 with given dimension")
        .def("add", [](IndexFlatL2& self, py::array_t<double> x) {
            py::buffer_info buf = x.request();
            if (buf.ndim != 2) {
                throw std::runtime_error("Input must be 2D array");
            }
            size_t n = buf.shape[0];
            size_t d = buf.shape[1];
            if (d != self.get_dimension()) {
                throw std::runtime_error("Dimension mismatch");
            }
            self.add(n, static_cast<double*>(buf.ptr));
        }, py::arg("x"), "Add vectors to the index")
        .def("search", [](IndexFlatL2& self, py::array_t<double> x, size_t k) {
            py::buffer_info buf = x.request();
            if (buf.ndim != 2) {
                throw std::runtime_error("Input must be 2D array");
            }
            size_t n = buf.shape[0];
            size_t d = buf.shape[1];
            if (d != self.get_dimension()) {
                throw std::runtime_error("Dimension mismatch");
            }
            
            // 准备输出数组
            py::array_t<double> distances({n, k});
            py::array_t<size_t> labels({n, k});
            
            py::buffer_info distances_buf = distances.request();
            py::buffer_info labels_buf = labels.request();
            
            self.search(n, static_cast<double*>(buf.ptr), k, 
                       static_cast<double*>(distances_buf.ptr), 
                       static_cast<size_t*>(labels_buf.ptr));
            
            return std::make_tuple(distances, labels);
        }, py::arg("x"), py::arg("k"), "Search for nearest neighbors")
        .def("size", &IndexFlatL2::size, "Get the number of vectors in the index")
        .def("get_dimension", &IndexFlatL2::get_dimension, "Get the dimension of the vectors");
}