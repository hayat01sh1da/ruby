#ifndef INTERNAL_ATOMIC_H
#define INTERNAL_ATOMIC_H

#include "ruby/atomic.h"

/* shim macros only */
#define ATOMIC_ADD(var, val) RUBY_ATOMIC_ADD(var, val)
#define ATOMIC_CAS(var, oldval, newval) RUBY_ATOMIC_CAS(var, oldval, newval)
#define ATOMIC_DEC(var) RUBY_ATOMIC_DEC(var)
#define ATOMIC_EXCHANGE(var, val) RUBY_ATOMIC_EXCHANGE(var, val)
#define ATOMIC_FETCH_ADD(var, val) RUBY_ATOMIC_FETCH_ADD(var, val)
#define ATOMIC_FETCH_SUB(var, val) RUBY_ATOMIC_FETCH_SUB(var, val)
#define ATOMIC_INC(var) RUBY_ATOMIC_INC(var)
#define ATOMIC_OR(var, val) RUBY_ATOMIC_OR(var, val)
#define ATOMIC_PTR_CAS(var, oldval, newval) RUBY_ATOMIC_PTR_CAS(var, oldval, newval)
#define ATOMIC_PTR_EXCHANGE(var, val) RUBY_ATOMIC_PTR_EXCHANGE(var, val)
#define ATOMIC_SET(var, val) RUBY_ATOMIC_SET(var, val)
#define ATOMIC_SIZE_ADD(var, val) RUBY_ATOMIC_SIZE_ADD(var, val)
#define ATOMIC_SIZE_CAS(var, oldval, newval) RUBY_ATOMIC_SIZE_CAS(var, oldval, newval)
#define ATOMIC_SIZE_DEC(var) RUBY_ATOMIC_SIZE_DEC(var)
#define ATOMIC_SIZE_EXCHANGE(var, val) RUBY_ATOMIC_SIZE_EXCHANGE(var, val)
#define ATOMIC_SIZE_INC(var) RUBY_ATOMIC_SIZE_INC(var)
#define ATOMIC_SIZE_SUB(var, val) RUBY_ATOMIC_SIZE_SUB(var, val)
#define ATOMIC_SUB(var, val) RUBY_ATOMIC_SUB(var, val)
#define ATOMIC_VALUE_CAS(var, oldval, val) RUBY_ATOMIC_VALUE_CAS(var, oldval, val)
#define ATOMIC_VALUE_EXCHANGE(var, val) RUBY_ATOMIC_VALUE_EXCHANGE(var, val)

static inline rb_atomic_t
rbimpl_atomic_load_relaxed(rb_atomic_t *ptr)
{
#if defined(HAVE_GCC_ATOMIC_BUILTINS)
    return __atomic_load_n(ptr, __ATOMIC_RELAXED);
#else
    return *ptr;
#endif
}
#define ATOMIC_LOAD_RELAXED(var) rbimpl_atomic_load_relaxed(&(var))

#endif
