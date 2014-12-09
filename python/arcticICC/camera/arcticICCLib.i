%define ModuleDocStr
"Python interface to arcticICC C++ code, including arctic::Camera."
%enddef

%feature("autodoc", "1");
%module(package="arcticICC", docstring=ModuleDocStr) arcticICCLib

%{
#include <sstream>
#include <stdexcept>
#include "arcticICC/basics.h"
#include "arcticICC/camera.h"
%}

%inline %{
namespace arcticICC {}
using namespace arcticICC;
%}

%init %{
%}

%include "std_except.i"
%include "std_string.i"

// Specifies the default C++ to python exception handling interface
%exception {
    try {
        $action
    } catch (std::domain_error & e) {
        PyErr_SetString(PyExc_ArithmeticError, e.what());
        SWIG_fail;
    } catch (std::invalid_argument & e) {
        PyErr_SetString(PyExc_ValueError, e.what());
        SWIG_fail;
    } catch (std::length_error & e) {
        PyErr_SetString(PyExc_IndexError, e.what());
        SWIG_fail;
    } catch (std::out_of_range & e) {
        PyErr_SetString(PyExc_ValueError, e.what());
        SWIG_fail;
    } catch (std::logic_error & e) {
        PyErr_SetString(PyExc_RuntimeError, e.what());
        SWIG_fail;
    } catch (std::range_error & e) {
        PyErr_SetString(PyExc_ValueError, e.what());
        SWIG_fail;
    } catch (std::underflow_error & e) {
        PyErr_SetString(PyExc_ArithmeticError, e.what());
        SWIG_fail;
    } catch (std::overflow_error & e) {
        PyErr_SetString(PyExc_OverflowError, e.what());
        SWIG_fail;
    } catch (std::runtime_error & e) {
        PyErr_SetString(PyExc_RuntimeError, e.what());
        SWIG_fail;
    } catch (std::exception & e) {
        PyErr_SetString(PyExc_StandardError, e.what());
        SWIG_fail;
    } catch (...) {
        SWIG_fail;
    }
}

%import "arcticICC/basics.h"
%import "arcticICC/camera.h"

// put this after any structs that contain std::tr1::array
%include "array.i"
