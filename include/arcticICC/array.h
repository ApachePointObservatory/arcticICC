#pragma once
// minimal version of std::array, for SWIG

#include <new>
#include <iterator>
#include <algorithm>
#include <cstddef>
#include <bits/functexcept.h>
#include <ext/type_traits.h>

// namespace std::
namespace std {

  template<typename _Tp, std::size_t _Nm>
    struct array
    {
      typedef _Tp 	    			      value_type;
      typedef value_type&                   	      reference;
      typedef const value_type&             	      const_reference;
      typedef value_type*          		      iterator;
      typedef const value_type*			      const_iterator;
      typedef std::size_t                    	      size_type;
      typedef std::ptrdiff_t                   	      difference_type;
      typedef std::reverse_iterator<iterator>	      reverse_iterator;
      typedef std::reverse_iterator<const_iterator>   const_reverse_iterator;

      bool empty() const;
      size_type size() const;

      reference at(size_type __n);
    };

}
