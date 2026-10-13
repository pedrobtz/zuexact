#ifndef ZXE_H
#define ZXE_H

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include "xsum.h"

/* Vectors of at least this many elements are summed with xsum's large
   accumulator, shorter ones with the small one. The choice changes speed,
   never the result. Measured by tools/run-benchmarks on the CI platforms
   (design §8): the crossover is 384 on ARM64 and 96 to 192 on x86-64. */
#if defined(__aarch64__) || defined(_M_ARM64)
# define ZXE_LARGE_MIN 384
#else
# define ZXE_LARGE_MIN 128
#endif

SEXP zxe_selftest(SEXP x);

#endif
