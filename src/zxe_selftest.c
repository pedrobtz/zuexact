#include "zxe.h"

/* Sum a double vector through both xsum accumulators and return
   c(small, large). Internal: lets the test suite exercise the vendored code
   directly, before and independently of the R functions built on it. */
SEXP zxe_selftest(SEXP x) {
  if (TYPEOF(x) != REALSXP) {
    Rf_error("zxe_selftest() needs a double vector");
  }
  const double *px = REAL_RO(x);
  xsum_length n = (xsum_length) XLENGTH(x);

  xsum_small_accumulator sacc;
  xsum_small_init(&sacc);
  xsum_small_addv(&sacc, px, n);

  xsum_large_accumulator *lacc =
    (xsum_large_accumulator *) R_alloc(1, sizeof(xsum_large_accumulator));
  xsum_large_init(lacc);
  xsum_large_addv(lacc, px, n);

  SEXP out = PROTECT(Rf_allocVector(REALSXP, 2));
  REAL(out)[0] = xsum_small_round(&sacc);
  REAL(out)[1] = xsum_large_round(lacc);
  UNPROTECT(1);
  return out;
}
