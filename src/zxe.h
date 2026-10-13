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

/* The vendored xsum. tools/vendor/verify checks these against
   tools/vendor/manifest.tsv. */
#define ZXE_XSUM_VERSION "stable-version-3"
#define ZXE_XSUM_COMMIT "b766b3e104cdbd6769c8df033fb430700fce32dd"

SEXP zxe_selftest(SEXP x);
SEXP zxe_sum(SEXP args, SEXP narm);
SEXP zxe_info(void);
SEXP zxe_mean(SEXP args, SEXP narm);
SEXP zxe_dot(SEXP x, SEXP y);
SEXP zxe_cumsum(SEXP x);
SEXP zxe_acc_new(void);
SEXP zxe_acc_add(SEXP acc, SEXP x, SEXP narm);
SEXP zxe_acc_merge(SEXP acc, SEXP other);
SEXP zxe_acc_negate(SEXP acc);
SEXP zxe_acc_value(SEXP acc, SEXP n);
SEXP zxe_colsums(SEXP x, SEXP nrow, SEXP ncol, SEXP narm);
SEXP zxe_rowsums(SEXP x, SEXP nrow, SEXP ncol, SEXP narm);
SEXP zxe_by(SEXP x, SEXP nrow, SEXP ncol, SEXP code, SEXP ng, SEXP narm);
void zxe_register_api(void);

#endif
