/* Design §9: exact dot products by TwoProduct (zxe_twoprod.h). Each
   product x*y is split into its rounded value p and its exact error e, and
   both go into the accumulator, so the result is the correctly rounded
   exact dot product (upstream's add_dot sums only the rounded products).
   R CMD check reports -ffp-contract as a non-portable flag, so the pragma
   and the canary and oracle tests are the guard. */
#pragma STDC FP_CONTRACT OFF

#include "zxe_acc.h"
#include "zxe_twoprod.h"
#include <math.h>

#define ZXE_BLOCK 2048

typedef struct {
  int na, nan, pinf, ninf;
} dot_flags;

/* Add x[i]*y[i] for i in [0, n) exactly. A non-finite product contributes
   only itself (its fma "error" would be NaN); the special-value pass in
   zxe_dot() decides what such products mean. */
static void add_products(zxe_acc *a, const double *x, const double *y,
                         R_xlen_t n) {
  double p[ZXE_BLOCK], e[ZXE_BLOCK];
  for (R_xlen_t i = 0; i < n; i += ZXE_BLOCK) {
    R_xlen_t m = n - i < ZXE_BLOCK ? n - i : ZXE_BLOCK;
    for (R_xlen_t j = 0; j < m; j++) {
      zxe_two_prod(x[i + j], y[i + j], &p[j], &e[j]);
    }
    zxe_acc_addv(a, p, m);
    zxe_acc_addv(a, e, m);
  }
}

/* Coerce to double without copying when already double. */
static const double *as_doubles(SEXP x, R_xlen_t n) {
  if (TYPEOF(x) == REALSXP) return REAL_RO(x);
  double *d = (double *) R_alloc(n, sizeof(double));
  const int *p = TYPEOF(x) == LGLSXP ? LOGICAL_RO(x) : INTEGER_RO(x);
  for (R_xlen_t i = 0; i < n; i++) {
    d[i] = p[i] == NA_INTEGER ? NA_REAL : (double) p[i];
  }
  return d;
}

static void flag(dot_flags *f, double v) {
  if (ISNAN(v)) {
    if (R_IsNA(v)) f->na = 1; else f->nan = 1;
  } else if (v == R_PosInf) {
    f->pinf = 1;
  } else if (v == R_NegInf) {
    f->ninf = 1;
  }
}

/* .Call entry: the exactly rounded sum of x[i]*y[i] (y == x for the squared
   norm). x and y are double, integer or logical of equal length (checked in
   R). Special values follow design §6, applied to the products: any NA in x
   or y gives NA; otherwise a NaN product (NaN input, or 0 * Inf) gives NaN;
   products of both infinite signs give NaN; one infinite sign gives it. */
SEXP zxe_dot(SEXP x, SEXP y) {
  R_xlen_t n = XLENGTH(x);
  const double *px = as_doubles(x, n);
  const double *py = y == x ? px : as_doubles(y, n);
  zxe_acc acc;
  zxe_acc_init(&acc, 2 * n);
  add_products(&acc, px, py, n);
  double r = zxe_acc_round(&acc);
  if (!isfinite(r)) {
    dot_flags f = {0, 0, 0, 0};
    for (R_xlen_t i = 0; i < n; i++) {
      if (R_IsNA(px[i]) || R_IsNA(py[i])) {
        f.na = 1;
        break;
      }
      flag(&f, px[i] * py[i]);
    }
    if (f.na) r = NA_REAL;
    else if (f.nan) r = R_NaN;
    else if (f.pinf && f.ninf) r = R_NaN;
    else if (ISNAN(r)) r = R_NaN;   /* cannot happen without an input NaN */
  }
  return Rf_ScalarReal(r);
}

/* .Call entry: every prefix sum of x exactly rounded, with the rules of
   design §6 applied to each prefix. x is double, integer or logical. */
SEXP zxe_cumsum(SEXP x) {
  R_xlen_t n = XLENGTH(x);
  const double *px = as_doubles(x, n);
  SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
  double *po = REAL(out);
  xsum_small_accumulator sacc;
  xsum_small_init(&sacc);
  dot_flags f = {0, 0, 0, 0};
  for (R_xlen_t i = 0; i < n; i++) {
    double v = px[i];
    flag(&f, v);
    if (f.na) {
      po[i] = NA_REAL;
    } else if (f.nan || (f.pinf && f.ninf)) {
      po[i] = R_NaN;
    } else {
      xsum_small_add1(&sacc, v);
      po[i] = xsum_small_round(&sacc);
    }
  }
  UNPROTECT(1);
  return out;
}
