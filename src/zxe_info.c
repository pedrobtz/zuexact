#include "zxe.h"
#include <math.h>

/* What this build of zuexact is: the vendored xsum, the accumulator
   threshold, the SIMD paths xsum was compiled with, and whether fma() is a
   hardware instruction here (design §9). */
SEXP zxe_info(void) {
  const char *names[] = {"xsum", "xsum_commit", "large_threshold", "simd",
                         "fma_hardware", ""};
  SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
  SET_VECTOR_ELT(out, 0, Rf_mkString(ZXE_XSUM_VERSION));
  SET_VECTOR_ELT(out, 1, Rf_mkString(ZXE_XSUM_COMMIT));
  SET_VECTOR_ELT(out, 2, Rf_ScalarInteger(ZXE_LARGE_MIN));
#if defined(__AVX__)
  SET_VECTOR_ELT(out, 3, Rf_mkString("avx"));
#elif defined(__SSE2__)
  SET_VECTOR_ELT(out, 3, Rf_mkString("sse2"));
#else
  SET_VECTOR_ELT(out, 3, Rf_mkString("none"));
#endif
#if defined(FP_FAST_FMA) && !defined(ZXE_NO_FMA)
  SET_VECTOR_ELT(out, 4, Rf_ScalarLogical(TRUE));
#else
  SET_VECTOR_ELT(out, 4, Rf_ScalarLogical(FALSE));
#endif
  UNPROTECT(1);
  return out;
}
