#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <zuexact.h>
#include <string.h>

/* Accumulators live in double arrays: aligned, and as many as needed. */
#define ACC_DOUBLES 128   /* 1 KB, comfortably more than acc_size */

static const zuexact_api *zx;

static const zuexact_api *api(void) {
  if (zx == NULL) zx = zuexact_api_get();
  if (zx->acc_size > sizeof(double) * ACC_DOUBLES) {
    Rf_error("accumulator larger than the fixture's buffer");
  }
  return zx;
}

static SEXP ct_info_c(void) {
  const zuexact_api *z = api();
  SEXP out = PROTECT(Rf_allocVector(REALSXP, 2));
  REAL(out)[0] = (double) z->struct_size;
  REAL(out)[1] = (double) z->acc_size;
  UNPROTECT(1);
  return out;
}

static SEXP ct_sum_c(SEXP x) {
  const zuexact_api *z = api();
  double acc[ACC_DOUBLES];
  z->init(acc);
  z->addv(acc, REAL(x), XLENGTH(x));
  return Rf_ScalarReal(z->round(acc));
}

static SEXP ct_dot_c(SEXP x, SEXP y) {
  const zuexact_api *z = api();
  double acc[ACC_DOUBLES];
  z->init(acc);
  z->add_dot(acc, REAL(x), REAL(y), XLENGTH(x));
  return Rf_ScalarReal(z->round(acc));
}

/* sum(x) - sum(y), via two accumulators, negate and merge. */
static SEXP ct_diff_c(SEXP x, SEXP y) {
  const zuexact_api *z = api();
  double a[ACC_DOUBLES], b[ACC_DOUBLES];
  z->init(a);
  z->init(b);
  for (R_xlen_t i = 0; i < XLENGTH(x); i++) z->add1(a, REAL(x)[i]);
  z->addv(b, REAL(y), XLENGTH(y));
  z->negate(b);
  z->merge(a, b);
  return Rf_ScalarReal(z->round(a));
}

static SEXP ct_mean_c(SEXP x) {
  const zuexact_api *z = api();
  double acc[ACC_DOUBLES];
  z->init(acc);
  z->addv(acc, REAL(x), XLENGTH(x));
  return Rf_ScalarReal(z->div(acc, (unsigned) XLENGTH(x)));
}

/* The bytes after an xsum_acc's 8-byte header are a table accumulator. */
static SEXP ct_round_acc_c(SEXP acc) {
  const zuexact_api *z = api();
  if (TYPEOF(acc) != RAWSXP || (size_t) XLENGTH(acc) != 8 + z->acc_size) {
    Rf_error("not an xsum_acc of this build");
  }
  double copy[ACC_DOUBLES];
  memcpy(copy, RAW(acc) + 8, z->acc_size);
  return Rf_ScalarReal(z->round(copy));
}

/* Sum x in `parts` interleaved slices, one accumulator each, then merge:
   the order-independence a parallel consumer relies on. */
static SEXP ct_sum_parts_c(SEXP x, SEXP parts_) {
  const zuexact_api *z = api();
  int parts = Rf_asInteger(parts_);
  if (parts < 1 || parts > 64) Rf_error("parts must be in 1..64");
  double accs[64][ACC_DOUBLES];
  for (int p = 0; p < parts; p++) z->init(accs[p]);
  for (R_xlen_t i = 0; i < XLENGTH(x); i++) z->add1(accs[i % parts], REAL(x)[i]);
  for (int p = parts - 1; p > 0; p--) z->merge(accs[0], accs[p]);
  return Rf_ScalarReal(z->round(accs[0]));
}

static const R_CallMethodDef methods[] = {
  {"ct_info_c", (DL_FUNC) &ct_info_c, 0},
  {"ct_sum_c", (DL_FUNC) &ct_sum_c, 1},
  {"ct_dot_c", (DL_FUNC) &ct_dot_c, 2},
  {"ct_diff_c", (DL_FUNC) &ct_diff_c, 2},
  {"ct_mean_c", (DL_FUNC) &ct_mean_c, 1},
  {"ct_round_acc_c", (DL_FUNC) &ct_round_acc_c, 1},
  {"ct_sum_parts_c", (DL_FUNC) &ct_sum_parts_c, 2},
  {NULL, NULL, 0}
};

void R_init_zuexacttest(DllInfo *dll) {
  R_registerRoutines(dll, NULL, methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
