/* zuexact: exactly rounded sums from C (design §7).

   In DESCRIPTION:   LinkingTo: zuexact
                     Imports: zuexact   (so the namespace is loaded first)
   In C:             #include <zuexact.h>
                     const zuexact_api *zx = zuexact_api_get();

   An accumulator is opaque memory of zx->acc_size bytes, aligned as a
   double (a double array, malloc() or R_alloc() memory is). Place it on the
   stack, in your own structs or arrays; zuexact never allocates on your
   behalf except a temporary inside addv() and add_dot() for long vectors,
   with malloc(), falling back to a slower path if that fails.

   Every function works only on the memory it is given: it is safe to call
   from any thread, including OpenMP workers, each with its own accumulator.
   round() and div() do not modify the accumulator, so several threads may
   read one that none is writing.

   Special values follow IEEE rules, not R's: adding NaN gives NaN, Inf and
   -Inf together give NaN, and R's NA is not told apart from other NaNs. A
   finite sum out of range rounds to an infinity. The R functions apply
   R's rules on top (design §6); a consumer that needs them must track NA
   itself.

   Versioning: members are only ever appended to zuexact_api, and
   struct_size says how many the provider has. Any other change gets a new
   name (zuexact_api_v2). */
#ifndef ZUEXACT_H
#define ZUEXACT_H

#include <stddef.h>
#include <R_ext/Rdynload.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct zuexact_api {
  size_t struct_size;   /* sizeof(zuexact_api) in the provider */
  size_t acc_size;      /* bytes of one accumulator */
  void (*init)(void *acc);
  void (*add1)(void *acc, double x);
  void (*addv)(void *acc, const double *x, ptrdiff_t n);
  /* Exact dot product: each x[i]*y[i] and its fma() rounding error. */
  void (*add_dot)(void *acc, const double *x, const double *y, ptrdiff_t n);
  void (*merge)(void *acc, const void *other);   /* acc += other */
  void (*negate)(void *acc);
  double (*round)(const void *acc);              /* correctly rounded sum */
  double (*div)(const void *acc, unsigned n);    /* correctly rounded sum / n */
} zuexact_api;

/* The provider's table. R_GetCCallable() loads the zuexact namespace if
   needed and signals an R error if it cannot. */
static inline const zuexact_api *zuexact_api_get(void) {
  typedef const zuexact_api *(*getter)(void);
  getter get = (getter) R_GetCCallable("zuexact", "zuexact_api_v1");
  return get ? get() : NULL;
}

#ifdef __cplusplus
}
#endif

#endif
