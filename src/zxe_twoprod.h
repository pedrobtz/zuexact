#ifndef ZXE_TWOPROD_H
#define ZXE_TWOPROD_H

/* TwoProduct (design §9): p = fl(a*b) and e with a*b == p + e exactly,
   whenever p is finite and |a*b| is above about 2^-970.

   With a hardware fused multiply-add (FP_FAST_FMA), e = fma(a, b, -p).
   Without one, fma() is a library routine, and not every C library gets it
   right: the mingw-w64 runtime used by Rtools on Windows returned wrong
   error terms for ill-conditioned dot products (test-oracle.R, 2026-10-13).
   So without hardware FMA, Dekker's algorithm with Veltkamp's splitting is
   used instead; it needs only correctly rounded multiplication and
   addition. Each half of a split has at most 26 significant bits, so every
   partial product below is exact.

   Contraction must not fuse the splitting arithmetic. Files including this
   header carry #pragma STDC FP_CONTRACT OFF (clang); GCC ignores that
   pragma but contracts only for targets with FMA instructions, which is
   exactly when the fma() branch is compiled instead. */

#include <math.h>

#define ZXE_SPLITTER 134217729.0          /* 2^27 + 1 */
#define ZXE_SPLIT_MAX 0x1p995             /* above this, C*a may overflow */

static inline void zxe_split(double a, double *hi, double *lo) {
  double t = ZXE_SPLITTER * a;
  double h = t - (t - a);
  *hi = h;
  *lo = a - h;
}

static inline void zxe_two_prod(double a, double b, double *p, double *e) {
  double pp = a * b;
  *p = pp;
  if (!isfinite(pp)) {
    *e = 0.0;   /* a non-finite product contributes only itself */
    return;
  }
#if defined(FP_FAST_FMA) && !defined(ZXE_NO_FMA)
  *e = fma(a, b, -pp);
#else
  /* Scale a large operand down by 2^53 so the split cannot overflow. The
     scaled product rounds exactly as the true one, scaled, unless it falls
     below 2^-1022: that is beyond the documented underflow limit. */
  double scale = 1.0;
  if (fabs(a) > ZXE_SPLIT_MAX) {
    a *= 0x1p-53;
    scale = 0x1p53;
  } else if (fabs(b) > ZXE_SPLIT_MAX) {
    b *= 0x1p-53;
    scale = 0x1p53;
  }
  double q = a * b;   /* == pp / scale */
  double ah, al, bh, bl;
  zxe_split(a, &ah, &al);
  zxe_split(b, &bh, &bl);
  double err = ((ah * bh - q) + ah * bl + al * bh) + al * bl;
  *e = err * scale;
#endif
}

#endif
