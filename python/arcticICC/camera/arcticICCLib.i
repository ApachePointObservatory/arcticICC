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

%init %{
%}

// %include "lsst/p_lsstSwig.i"

%import "arcticICC/camera.h"
