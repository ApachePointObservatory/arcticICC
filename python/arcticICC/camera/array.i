%{
#include <array>
%}

%import "std_except.i"
%include "arcticICC/array.h"

%extend std::array {
    inline size_t __len__() const { return $self->size(); }

    inline const value_type& _get(size_t i) const throw(std::out_of_range) {
        return $self->at(i);
    }

    inline void _set(size_t i, const value_type& v) throw(std::out_of_range) {
        $self->at(i) = v;
    }

    %pythoncode {
        def __getitem__(self, key):
            if isinstance(key, slice):
                return tuple(self._get(i) for i in range(*key.indices(len(self))))

            if key < 0:
                key += len(self)
            return self._get(key)
        
        def __setitem__(self, key, v):
            if isinstance(key, slice):
                for i in range(*key.indices(len(self))):
                    self._set(i, v[i])
            else:
                if key < 0:
                    key += len(self)
                self._set(key, v)

        def __repr__(self):
            return "%s(%s)" % (self.__class__.__name__, ", ".join(str(v) for v in self[:]))

        def __eq__(self, rhs):
            """Return True if all elements are equal, else False"""
            if len(self) != len(rhs):
                return False
            return all(self[i] == rhs[i] for i in range(len(self)))

        def __ne__(self, rhs):
            """Return True if any elements are not equal, else False"""
            return not self.__eq__(rhs)
    }
}

%template (ArrayI2) std::array<int, 2>;
%template (ArrayI4) std::array<int, 4>;
