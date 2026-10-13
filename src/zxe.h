#ifndef ZXE_H
#define ZXE_H

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include "xsum.h"

/* Vectors of at least this many elements are summed with xsum's large
   accumulator, shorter ones with the small one. Measured by
   tools/run-benchmarks on the CI platforms (design §8). */
#define ZXE_LARGE_MIN 384

SEXP zxe_selftest(SEXP x);

#endif
