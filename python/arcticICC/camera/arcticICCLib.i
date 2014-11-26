%define ModuleDocStr
"Python interface to arcticICC C++ code, including arctic::Camera."
%enddef

%feature("autodoc", "1");
%module(package="arcticICC", docstring=ModuleDocStr) tccLib

%{
#include <sstream>
#include <stdexcept>
#include "arcticICC/camera.h"
%}

%inline %{
namespace arctic {}
using namespace arctic;
%}

%init %{
%}

%import "arcticICC/camera.h"
