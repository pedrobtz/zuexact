#include "zxe_acc.h"
#include <math.h>
#include <limits.h>

/* Design §4 and §6. One pass through the data in the common case: the
   values go straight into xsum, which applies IEEE rules to Inf and NaN.
   Only when the rounded result is not finite are the inputs scanned again,
   to apply R's rules (NA beats NaN beats Inf - Inf). */

#define ZXE_BLOCK 4096

enum { ZXE_RE = 0, ZXE_IM = 1 };

typedef struct {
  zxe_acc acc[2];
  int int_na;          /* an integer or logical NA was seen (na.rm = FALSE) */
  int narm;
  R_xlen_t count;      /* terms added (after na.rm), for means */
} zxe_sum_state;

/* Doubles, in blocks. Non-ALTREP vectors are summed in place; ALTREP
   vectors are read through REAL_GET_REGION and never materialised. */
static void add_real(zxe_sum_state *st, SEXP x) {
  R_xlen_t n = XLENGTH(x);
  zxe_acc *a = &st->acc[ZXE_RE];
  if (!ALTREP(x) && !st->narm) {
    zxe_acc_addv(a, REAL_RO(x), n);
    st->count += n;
    return;
  }
  double buf[ZXE_BLOCK];
  for (R_xlen_t i = 0; i < n; i += ZXE_BLOCK) {
    R_xlen_t m = n - i < ZXE_BLOCK ? n - i : ZXE_BLOCK;
    const double *p;
    if (ALTREP(x)) {
      m = REAL_GET_REGION(x, i, m, buf);
      p = buf;
    } else {
      p = REAL_RO(x) + i;
    }
    if (!st->narm) {
      zxe_acc_addv(a, p, m);
      st->count += m;
      continue;
    }
    R_xlen_t j = 0;
    while (j < m && !ISNAN(p[j])) j++;
    if (j == m) {
      zxe_acc_addv(a, p, m);
      st->count += m;
    } else {
      zxe_acc_addv(a, p, j);
      st->count += j;
      for (; j < m; j++) {
        if (!ISNAN(p[j])) {
          zxe_acc_add1(a, p[j]);
          st->count++;
        }
      }
    }
  }
}

/* Integers and logicals: converted to double exactly, a block at a time. */
static void add_int(zxe_sum_state *st, SEXP x) {
  R_xlen_t n = XLENGTH(x);
  zxe_acc *a = &st->acc[ZXE_RE];
  int ibuf[ZXE_BLOCK];
  double dbuf[ZXE_BLOCK];
  int is_lgl = TYPEOF(x) == LGLSXP;
  for (R_xlen_t i = 0; i < n; i += ZXE_BLOCK) {
    R_xlen_t m = n - i < ZXE_BLOCK ? n - i : ZXE_BLOCK;
    const int *p;
    if (ALTREP(x)) {
      m = is_lgl ? LOGICAL_GET_REGION(x, i, m, ibuf)
                 : INTEGER_GET_REGION(x, i, m, ibuf);
      p = ibuf;
    } else {
      p = (is_lgl ? LOGICAL_RO(x) : INTEGER_RO(x)) + i;
    }
    R_xlen_t k = 0;
    for (R_xlen_t j = 0; j < m; j++) {
      if (p[j] == NA_INTEGER) {
        if (!st->narm) st->int_na = 1;
        continue;
      }
      dbuf[k++] = (double) p[j];
    }
    zxe_acc_addv(a, dbuf, k);
    st->count += k;
  }
}

/* Complex: real and imaginary parts are two independent sums. With
   na.rm = TRUE an element is dropped when either part is NaN, as base
   sum() does. */
static void add_complex(zxe_sum_state *st, SEXP x) {
  R_xlen_t n = XLENGTH(x);
  const Rcomplex *z = COMPLEX_RO(x);
  double re[ZXE_BLOCK], im[ZXE_BLOCK];
  for (R_xlen_t i = 0; i < n; i += ZXE_BLOCK) {
    R_xlen_t m = n - i < ZXE_BLOCK ? n - i : ZXE_BLOCK;
    R_xlen_t k = 0;
    for (R_xlen_t j = 0; j < m; j++) {
      Rcomplex v = z[i + j];
      if (st->narm && (ISNAN(v.r) || ISNAN(v.i))) continue;
      re[k] = v.r;
      im[k] = v.i;
      k++;
    }
    zxe_acc_addv(&st->acc[ZXE_RE], re, k);
    zxe_acc_addv(&st->acc[ZXE_IM], im, k);
    st->count += k;
  }
}

typedef struct {
  int na, nan, pinf, ninf;
} zxe_flags;

static void flag_value(zxe_flags *f, double v) {
  if (ISNAN(v)) {
    if (R_IsNA(v)) f->na = 1; else f->nan = 1;
  } else if (v == R_PosInf) {
    f->pinf = 1;
  } else if (v == R_NegInf) {
    f->ninf = 1;
  }
}

/* Rescan the double inputs of one component (real or imaginary part),
   skipping what na.rm = TRUE removed. */
static void rescan(SEXP args, int part, int narm, zxe_flags *f) {
  R_xlen_t nargs = XLENGTH(args);
  for (R_xlen_t k = 0; k < nargs; k++) {
    SEXP x = VECTOR_ELT(args, k);
    R_xlen_t n = Rf_xlength(x);
    if (TYPEOF(x) == REALSXP && part == ZXE_RE) {
      double buf[ZXE_BLOCK];
      for (R_xlen_t i = 0; i < n; i += ZXE_BLOCK) {
        R_xlen_t m = n - i < ZXE_BLOCK ? n - i : ZXE_BLOCK;
        const double *p;
        if (ALTREP(x)) {
          m = REAL_GET_REGION(x, i, m, buf);
          p = buf;
        } else {
          p = REAL_RO(x) + i;
        }
        for (R_xlen_t j = 0; j < m; j++) {
          if (!(narm && ISNAN(p[j]))) flag_value(f, p[j]);
        }
      }
    } else if (TYPEOF(x) == CPLXSXP) {
      const Rcomplex *z = COMPLEX_RO(x);
      for (R_xlen_t i = 0; i < n; i++) {
        if (narm && (ISNAN(z[i].r) || ISNAN(z[i].i))) continue;
        flag_value(f, part == ZXE_RE ? z[i].r : z[i].i);
      }
    }
  }
}

/* Apply design §6 to one component. Returns the value; sets *internal when
   xsum produced a NaN that no input explains (accumulator overflow). */
static double finish(zxe_sum_state *st, SEXP args, int part, int mean,
                     int *internal) {
  double r = mean ? zxe_acc_div(&st->acc[part], (unsigned) st->count)
                  : zxe_acc_round(&st->acc[part]);
  if (st->int_na) return NA_REAL;   /* NA_integer_ coerces to NA in either part */
  if (R_FINITE(r)) return r;
  zxe_flags f = {0, 0, 0, 0};
  rescan(args, part, st->narm, &f);
  if (f.na) return NA_REAL;
  if (f.nan) return R_NaN;
  if (f.pinf && f.ninf) return R_NaN;
  if (ISNAN(r)) {
    *internal = 1;
    return R_NaN;
  }
  return r;   /* +Inf or -Inf: an infinite input, or a finite overflow */
}

/* Sum (mean = 0) or mean (mean = 1) of a list of NULL, double, integer,
   logical or complex vectors (checked in R). Returns a double, or a complex
   if any argument is complex. An attribute "zxe_status" carries a condition
   for the R side to signal: "overflow" (internal) or "count" (a mean over
   more terms than xsum's 32-bit division covers). */
static SEXP sum_or_mean(SEXP args, SEXP narm, int mean) {
  zxe_sum_state st;
  R_xlen_t nargs = XLENGTH(args), total = 0;
  int any_complex = 0;
  for (R_xlen_t k = 0; k < nargs; k++) {
    SEXP x = VECTOR_ELT(args, k);
    total += Rf_xlength(x);
    if (TYPEOF(x) == CPLXSXP) any_complex = 1;
  }
  st.narm = Rf_asLogical(narm) == TRUE;
  st.int_na = 0;
  st.count = 0;
  const char *status = NULL;

  /* Without na.rm the count is known now: refuse before reading the data. */
  if (mean && !st.narm && (double) total > (double) UINT_MAX) {
    status = "count";
  } else {
    zxe_acc_init(&st.acc[ZXE_RE], total);
    zxe_acc_init(&st.acc[ZXE_IM], any_complex ? total : 0);
    for (R_xlen_t k = 0; k < nargs; k++) {
      SEXP x = VECTOR_ELT(args, k);
      switch (TYPEOF(x)) {
      case REALSXP: add_real(&st, x); break;
      case INTSXP:
      case LGLSXP: add_int(&st, x); break;
      case CPLXSXP: add_complex(&st, x); break;
      default: break;   /* NULL */
      }
    }
    if (mean && (double) st.count > (double) UINT_MAX) status = "count";
  }

  int internal = 0;
  SEXP out;
  if (status != NULL) {
    out = PROTECT(Rf_ScalarReal(NA_REAL));
  } else if (mean && st.count == 0) {
    /* mean of nothing: NaN, as base mean() gives (design §6) */
    if (any_complex) {
      out = PROTECT(Rf_allocVector(CPLXSXP, 1));
      COMPLEX(out)[0].r = R_NaN;
      COMPLEX(out)[0].i = R_NaN;
    } else {
      out = PROTECT(Rf_ScalarReal(st.int_na ? NA_REAL : R_NaN));
    }
  } else if (any_complex) {
    out = PROTECT(Rf_allocVector(CPLXSXP, 1));
    COMPLEX(out)[0].r = finish(&st, args, ZXE_RE, mean, &internal);
    COMPLEX(out)[0].i = finish(&st, args, ZXE_IM, mean, &internal);
  } else {
    out = PROTECT(Rf_allocVector(REALSXP, 1));
    REAL(out)[0] = finish(&st, args, ZXE_RE, mean, &internal);
  }
  if (internal) status = "overflow";
  if (status != NULL) {
    Rf_setAttrib(out, Rf_install("zxe_status"), Rf_mkString(status));
  }
  UNPROTECT(1);
  return out;
}

SEXP zxe_sum(SEXP args, SEXP narm) {
  return sum_or_mean(args, narm, 0);
}

SEXP zxe_mean(SEXP args, SEXP narm) {
  return sum_or_mean(args, narm, 1);
}
