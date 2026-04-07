#include &lt;pybind11/pybind11.h&gt;
#include &lt;pybind11/stl.h&gt;
#include &lt;pybind11/numpy.h&gt;
#include "flat.h"

namespace py = pybind11;
using namespace vectordb::algorithms;

PYBIND11_MODULE(_flat, m) {
    m.doc() = "Flat L2 index algorithm for vector database";
    m.attr("__version__") = "1.0.0";

    py::class_&lt;IndexFlatL2&gt;(m, "IndexFlatL2")
        .def(py::init&lt;size_t&gt;(), py::arg("dimension"), "Create an IndexFlatL2 with given dimension")
        .def("add", [](IndexFlatL2&amp; self, py::array_t&lt;float&gt; x) {
            py::buffer_info buf = x.request();
            if (buf.ndim != 2) {
                throw std::runtime_error("Input must be 2D array");
            }
            size_t n = buf.shape[0];
            size_t d = buf.shape[1];
            if (d != self.get_dimension()) {
                throw std::runtime_error("Dimension mismatch");
            }
            self.add(n, static_cast&lt;float*&gt;(buf.ptr));
        }, py::arg("x"), "Add vectors to the index")
        .def("search", [](IndexFlatL2&amp; self, py::array_t&lt;float&gt; x, size_t k) {
            py::buffer_info buf = x.request();
            if (buf.ndim != 2) {
                throw std::runtime_error("Input must be 2D array");
            }
            size_t n = buf.shape[0];
            size_t d = buf.shape[1];
            if (d != self.get_dimension()) {
                throw std::runtime_error("Dimension mismatch");
            }

            py::array_t&lt;float&gt; distances({n, k});
            py::array_t&lt;size_t&gt; labels({n, k});

            py::buffer_info distances_buf = distances.request();
            py::buffer_info labels_buf = labels.request();

            self.search(n, static_cast&lt;float*&gt;(buf.ptr), k,
                       static_cast&lt;float*&gt;(distances_buf.ptr),
                       static_cast&lt;size_t*&gt;(labels_buf.ptr));

            return std::make_tuple(distances, labels);
        }, py::arg("x"), py::arg("k"), "Search for nearest neighbors")
        .def("size", &amp;IndexFlatL2::size, "Get the number of vectors in the index")
        .def("get_dimension", &amp;IndexFlatL2::get_dimension, "Get the dimension of the vectors");
}
