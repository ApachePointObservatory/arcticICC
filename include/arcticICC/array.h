#pragma once
// minimal version of tr1::array, for SWIG

#include <new>
#include <iterator>
#include <algorithm>
#include <cstddef>
#include <bits/functexcept.h>
#include <ext/type_traits.h>

//namespace std::tr1
namespace std {
namespace tr1 {

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

      void assign(const value_type& __u);

      size_type size() const;

      reference at(size_type __n);
    };

}}
