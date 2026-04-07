#include &lt;pybind11/pybind11.h&gt;
#include &lt;pybind11/numpy.h&gt;
#include "flat_ip.h"

namespace py = pybind11;
using namespace vectordb::algorithms;

PYBIND11_MODULE(vectordb_flat_ip, m) {
    m.doc() = "VectorDB FLAT-IP Index Module";

    py::class_&lt;IndexFlatIP&gt;(m, "IndexFlatIP")
        .def(py::init&lt;size_t&gt;())
        .def("add", [](IndexFlatIP &amp;self, py::array_t&lt;float&gt; x) {
            py::buffer_info buf = x.request();
            if (buf.ndim != 2) {
                throw std::invalid_argument("Input must be 2D array");
            }
            size_t n = buf.shape[0];
            size_t d = buf.shape[1];
            self.add(n, static_cast&lt;float*&gt;(buf.ptr));
        })
        .def("search", [](IndexFlatIP &amp;self, py::array_t&lt;float&gt; x, size_t k) {
            py::buffer_info buf = x.request();
            if (buf.ndim != 2) {
                throw std::invalid_argument("Input must be 2D array");
            }
            size_t n = buf.shape[0];
            py::array_t&lt;float&gt; distances({n, k});
            py::array_t&lt;size_t&gt; labels({n, k});
            py::buffer_info dist_buf = distances.request();
            py::buffer_info label_buf = labels.request();
            self.search(n, static_cast&lt;float*&gt;(buf.ptr), k, 
                       static_cast&lt;float*&gt;(dist_buf.ptr), 
                       static_cast&lt;size_t*&gt;(label_buf.ptr));
            return std::make_tuple(distances, labels);
        })
        .def_property_readonly("ntotal", &amp;IndexFlatIP::get_ntotal)
        .def_property_readonly("dimension", &amp;IndexFlatIP::get_dimension);
}
