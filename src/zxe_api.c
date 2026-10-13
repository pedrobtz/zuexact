/* Design §7: the registered C table. Operates on bare xsum small
   accumulators, which are also the bytes after an xsum_acc header. */
#pragma STDC FP_CONTRACT OFF

#include "zxe.h"
#include "../inst/include/zuexact.h"
#include "zxe_twoprod.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

#define ZXE_API_BLOCK 1024

static void api_init(void *acc) {
  memset(acc, 0, sizeof(xsum_small_accumulator));
  xsum_small_init((xsum_small_accumulator *) acc);
}

static void api_add1(void *acc, double x) {
  xsum_small_add1((xsum_small_accumulator *) acc, x);
}

static void api_addv(void *acc, const double *x, ptrdiff_t n) {
  xsum_small_accumulator *s = (xsum_small_accumulator *) acc;
  if (n <= 0) return;
  if (n >= ZXE_LARGE_MIN) {
    xsum_large_accumulator *l = (xsum_large_accumulator *) malloc(sizeof *l);
    if (l != NULL) {
      xsum_small_accumulator part;
      memset(l, 0, sizeof *l);
      xsum_large_init(l);
      xsum_large_addv(l, x, (xsum_length) n);
      memset(&part, 0, sizeof part);
      xsum_large_to_small_accumulator(&part, l);
      free(l);
      xsum_small_add_accumulator(s, &part);
      return;
    }
  }
  xsum_small_addv(s, x, (xsum_length) n);
}

/* TwoProduct, as in zxe_dot.c (zxe_twoprod.h). */
static void api_add_dot(void *acc, const double *x, const double *y,
                        ptrdiff_t n) {
  double p[ZXE_API_BLOCK], e[ZXE_API_BLOCK];
  for (ptrdiff_t i = 0; i < n; i += ZXE_API_BLOCK) {
    ptrdiff_t m = n - i < ZXE_API_BLOCK ? n - i : ZXE_API_BLOCK;
    for (ptrdiff_t j = 0; j < m; j++) {
      zxe_two_prod(x[i + j], y[i + j], &p[j], &e[j]);
    }
    api_addv(acc, p, m);
    api_addv(acc, e, m);
  }
}

static void api_merge(void *acc, const void *other) {
  xsum_small_accumulator copy;
  memcpy(&copy, other, sizeof copy);
  xsum_small_add_accumulator((xsum_small_accumulator *) acc, &copy);
}

static void api_negate(void *acc) {
  xsum_small_negate((xsum_small_accumulator *) acc);
}

/* Rounding may propagate carries, so it works on a copy: the caller's
   accumulator is untouched and may be shared between reading threads. */
static double api_round(const void *acc) {
  xsum_small_accumulator copy;
  memcpy(&copy, acc, sizeof copy);
  return xsum_small_round(&copy);
}

static double api_div(const void *acc, unsigned n) {
  xsum_small_accumulator copy;
  memcpy(&copy, acc, sizeof copy);
  return xsum_small_div_unsigned(&copy, n);
}

static const zuexact_api api_v1 = {
  sizeof(zuexact_api),
  sizeof(xsum_small_accumulator),
  api_init,
  api_add1,
  api_addv,
  api_add_dot,
  api_merge,
  api_negate,
  api_round,
  api_div
};

static const zuexact_api *zuexact_api_v1(void) {
  return &api_v1;
}

void zxe_register_api(void) {
  R_RegisterCCallable("zuexact", "zuexact_api_v1", (DL_FUNC) zuexact_api_v1);
}
