/* Design §4, D9: an accumulator as an R value. A raw vector holds an 8-byte
   header and one xsum small accumulator:

     bytes 0-3  magic "ZXAC"
     byte  4    layout version (1)
     byte  5    byte order: 1 little-endian, 2 big-endian
     byte  6    flags: bit 0 NA, bit 1 NaN, bit 2 +Inf, bit 3 -Inf seen
     byte  7    reserved, 0
     bytes 8-   xsum_small_accumulator (sizeof is 560 on every platform R
                supports: 67 int64 chunks, two int64 and an int, padded)

   R keeps NA and NaN apart and xsum does not (it keeps one NaN, by payload),
   so the special values seen are recorded in the header flags and decide
   the value with the rules of design §6; xsum's own Inf/NaN fields are only
   used to notice that a scan for them is needed.

   Every operation copies the accumulator out of the raw vector into a
   zeroed local (alignment, and no uninitialised padding ever reaches R),
   works on it, and writes a new raw vector: copy-on-modify, like R. */

#include "zxe_acc.h"
#include <string.h>
#include <limits.h>

#define ZXE_ACC_HEADER 8
#define ZXE_ACC_VERSION 1
#define ZXE_ACC_BYTES (ZXE_ACC_HEADER + (R_xlen_t) sizeof(xsum_small_accumulator))

enum { F_NA = 1, F_NAN = 2, F_PINF = 4, F_NINF = 8 };

static unsigned char host_order(void) {
  const unsigned int one = 1;
  return *(const unsigned char *) &one == 1 ? 1 : 2;
}

typedef struct {
  unsigned char flags;
  xsum_small_accumulator sacc;
} acc_value;

/* Returns NULL if acc is valid, else a reason (signalled by the R side as
   zuexact_accumulator_error). */
static const char *read_acc(SEXP acc, acc_value *v) {
  if (TYPEOF(acc) != RAWSXP || XLENGTH(acc) != ZXE_ACC_BYTES) {
    return "not an accumulator of this build's size";
  }
  const unsigned char *b = RAW_RO(acc);
  if (memcmp(b, "ZXAC", 4) != 0) return "bad magic";
  if (b[4] != ZXE_ACC_VERSION) return "unknown layout version";
  if (b[5] != host_order()) return "made on a machine of the other byte order";
  memset(v, 0, sizeof *v);
  v->flags = b[6];
  memcpy(&v->sacc, b + ZXE_ACC_HEADER, sizeof v->sacc);
  return NULL;
}

static SEXP write_acc(const acc_value *v) {
  SEXP out = PROTECT(Rf_allocVector(RAWSXP, ZXE_ACC_BYTES));
  unsigned char *b = RAW(out);
  memcpy(b, "ZXAC", 4);
  b[4] = ZXE_ACC_VERSION;
  b[5] = host_order();
  b[6] = v->flags;
  b[7] = 0;
  memcpy(b + ZXE_ACC_HEADER, &v->sacc, sizeof v->sacc);
  UNPROTECT(1);
  return out;
}

static SEXP invalid(const char *why) {
  SEXP out = PROTECT(Rf_allocVector(RAWSXP, 0));
  Rf_setAttrib(out, Rf_install("zxe_status"), Rf_mkString(why));
  UNPROTECT(1);
  return out;
}

static unsigned char flags_of(double d) {
  if (ISNAN(d)) return R_IsNA(d) ? F_NA : F_NAN;
  if (d == R_PosInf) return F_PINF;
  if (d == R_NegInf) return F_NINF;
  return 0;
}

/* Add vector x (double, integer or logical, checked in R) to v. x is summed
   into its own accumulator first, then merged; only if that accumulator saw
   an Inf or NaN is x scanned for R's flags. */
static void add_vector(acc_value *v, SEXP x, int narm) {
  R_xlen_t n = XLENGTH(x);
  xsum_small_accumulator part;
  memset(&part, 0, sizeof part);
  xsum_small_init(&part);

  if (TYPEOF(x) == REALSXP) {
    double buf[4096];
    xsum_large_accumulator *lacc = NULL;
    if (n >= ZXE_LARGE_MIN) {
      lacc = (xsum_large_accumulator *) R_alloc(1, sizeof *lacc);
      memset(lacc, 0, sizeof *lacc);
      xsum_large_init(lacc);
    }
    for (R_xlen_t i = 0; i < n; i += 4096) {
      R_xlen_t m = n - i < 4096 ? n - i : 4096;
      const double *p;
      if (ALTREP(x)) {
        m = REAL_GET_REGION(x, i, m, buf);
        p = buf;
      } else {
        p = REAL_RO(x) + i;
      }
      R_xlen_t k = m;
      if (narm) {
        k = 0;
        for (R_xlen_t j = 0; j < m; j++) if (!ISNAN(p[j])) buf[k++] = p[j];
        p = buf;
      }
      if (lacc) xsum_large_addv(lacc, p, k);
      else xsum_small_addv(&part, p, k);
    }
    if (lacc) xsum_large_to_small_accumulator(&part, lacc);
    if (part.Inf != 0 || part.NaN != 0) {
      for (R_xlen_t i = 0; i < n; i++) {
        double d = ALTREP(x) ? REAL_ELT(x, i) : REAL_RO(x)[i];
        if (!(narm && ISNAN(d))) v->flags |= flags_of(d);
      }
    }
  } else {
    int is_lgl = TYPEOF(x) == LGLSXP;
    int ibuf[4096];
    double dbuf[4096];
    for (R_xlen_t i = 0; i < n; i += 4096) {
      R_xlen_t m = n - i < 4096 ? n - i : 4096;
      m = is_lgl ? LOGICAL_GET_REGION(x, i, m, ibuf)
                 : INTEGER_GET_REGION(x, i, m, ibuf);
      R_xlen_t k = 0;
      for (R_xlen_t j = 0; j < m; j++) {
        if (ibuf[j] == NA_INTEGER) {
          if (!narm) v->flags |= F_NA;
        } else {
          dbuf[k++] = (double) ibuf[j];
        }
      }
      xsum_small_addv(&part, dbuf, k);
    }
  }
  xsum_small_add_accumulator(&v->sacc, &part);
}

/* Design §6 on the flags, then round or divide. *internal is set when xsum
   holds a NaN that no flag explains: accumulator overflow. */
static double value_of(acc_value *v, double n, int *internal) {
  unsigned char f = v->flags;
  if (f & F_NA) return NA_REAL;
  if (f & F_NAN) return R_NaN;
  if ((f & F_PINF) && (f & F_NINF)) return R_NaN;
  double r = n < 0 ? xsum_small_round(&v->sacc)
                   : xsum_small_div_unsigned(&v->sacc, (unsigned) n);
  if (ISNAN(r)) {
    *internal = 1;
    return R_NaN;
  }
  return r;
}

SEXP zxe_acc_new(void) {
  acc_value v;
  memset(&v, 0, sizeof v);
  xsum_small_init(&v.sacc);
  return write_acc(&v);
}

SEXP zxe_acc_add(SEXP acc, SEXP x, SEXP narm) {
  acc_value v;
  const char *why = read_acc(acc, &v);
  if (why) return invalid(why);
  add_vector(&v, x, Rf_asLogical(narm) == TRUE);
  return write_acc(&v);
}

SEXP zxe_acc_merge(SEXP acc, SEXP other) {
  acc_value v, w;
  const char *why = read_acc(acc, &v);
  if (!why) why = read_acc(other, &w);
  if (why) return invalid(why);
  v.flags |= w.flags;
  xsum_small_add_accumulator(&v.sacc, &w.sacc);
  return write_acc(&v);
}

SEXP zxe_acc_negate(SEXP acc) {
  acc_value v;
  const char *why = read_acc(acc, &v);
  if (why) return invalid(why);
  xsum_small_negate(&v.sacc);
  unsigned char f = v.flags & (F_NA | F_NAN);
  if (v.flags & F_PINF) f |= F_NINF;
  if (v.flags & F_NINF) f |= F_PINF;
  v.flags = f;
  return write_acc(&v);
}

/* n < 0: the rounded sum; n >= 1: the exactly rounded mean over n terms
   (n == 0 and n > UINT_MAX are handled in R). */
SEXP zxe_acc_value(SEXP acc, SEXP n) {
  acc_value v;
  const char *why = read_acc(acc, &v);
  if (why) return invalid(why);
  int internal = 0;
  SEXP out = PROTECT(Rf_ScalarReal(value_of(&v, Rf_asReal(n), &internal)));
  if (internal) Rf_setAttrib(out, Rf_install("zxe_status"), Rf_mkString("overflow"));
  UNPROTECT(1);
  return out;
}
