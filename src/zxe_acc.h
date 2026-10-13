#ifndef ZXE_ACC_H
#define ZXE_ACC_H

#include "zxe.h"

/* One exact sum in progress: a small accumulator, plus a large one that is
   used instead when the caller expects at least ZXE_LARGE_MIN terms. */
typedef struct {
  int large;
  xsum_small_accumulator sacc;
  xsum_large_accumulator *lacc;   /* R_alloc'd when large */
} zxe_acc;

static inline void zxe_acc_init(zxe_acc *a, R_xlen_t expected) {
  a->large = expected >= ZXE_LARGE_MIN;
  if (a->large) {
    a->lacc = (xsum_large_accumulator *)
      R_alloc(1, sizeof(xsum_large_accumulator));
    xsum_large_init(a->lacc);
  } else {
    a->lacc = NULL;
    xsum_small_init(&a->sacc);
  }
}

static inline void zxe_acc_addv(zxe_acc *a, const double *x, R_xlen_t n) {
  if (n <= 0) return;
  if (a->large) xsum_large_addv(a->lacc, x, (xsum_length) n);
  else xsum_small_addv(&a->sacc, x, (xsum_length) n);
}

static inline void zxe_acc_add1(zxe_acc *a, double x) {
  if (a->large) xsum_large_add1(a->lacc, x);
  else xsum_small_add1(&a->sacc, x);
}

static inline double zxe_acc_round(zxe_acc *a) {
  return a->large ? xsum_large_round(a->lacc) : xsum_small_round(&a->sacc);
}

/* The exactly rounded quotient of the exact sum by n (n >= 1). */
static inline double zxe_acc_div(zxe_acc *a, unsigned n) {
  return a->large ? xsum_large_div_unsigned(a->lacc, n)
                  : xsum_small_div_unsigned(&a->sacc, n);
}


/* Special values seen, and the rules of design §6 applied to them. */
enum { ZXE_F_NA = 1, ZXE_F_NAN = 2, ZXE_F_PINF = 4, ZXE_F_NINF = 8 };

static inline unsigned char zxe_flag_of(double d) {
  if (ISNAN(d)) return R_IsNA(d) ? ZXE_F_NA : ZXE_F_NAN;
  if (d == R_PosInf) return ZXE_F_PINF;
  if (d == R_NegInf) return ZXE_F_NINF;
  return 0;
}

/* r is xsum's rounded value; *internal is set if xsum holds a NaN that no
   flag explains (accumulator overflow). */
static inline double zxe_apply_flags(unsigned char f, double r, int *internal) {
  if (f & ZXE_F_NA) return NA_REAL;
  if (f & ZXE_F_NAN) return R_NaN;
  if ((f & ZXE_F_PINF) && (f & ZXE_F_NINF)) return R_NaN;
  if (ISNAN(r)) {
    *internal = 1;
    return R_NaN;
  }
  return r;
}

#endif
