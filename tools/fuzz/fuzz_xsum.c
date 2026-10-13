/* libFuzzer harness for the vendored, patched xsum as zuexact uses it
   (design §11). The input is read as doubles; every invariant zuexact
   relies on is checked, and any violation aborts (a fuzzer finding):

     1. the small and the large accumulator round to the same bits;
     2. any split of the input into two parts, summed separately and merged,
        rounds like the whole (zuexact's xsum_merge and the C table);
     3. a large accumulator converted to a small one keeps its value
        (zuexact's long-vector path in xsum_add and the C table's addv);
     4. adding the negation of an accumulator to itself gives zero, for
        finite inputs (xsum_negate);
     5. dividing by one rounds like rounding (xsum_mean's division);
     6. rounding does not change the value (round is called repeatedly).

   Built without R by r-actions' fuzz.yml, with ASan and UBSan. */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "xsum.h"

static int same(double a, double b) {
  if (isnan(a) || isnan(b)) return isnan(a) && isnan(b);
  return memcmp(&a, &b, sizeof a) == 0;
}

static xsum_large_accumulator lacc;   /* 42 KB: static, not on the stack */

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size < 1) return 0;
  size_t n = (size - 1) / sizeof(double);
  size_t split = n ? data[0] % (n + 1) : 0;
  double *x = (double *) malloc((n ? n : 1) * sizeof(double));
  if (!x) return 0;
  memcpy(x, data + 1, n * sizeof(double));
  int finite = 1;
  for (size_t i = 0; i < n; i++) if (!isfinite(x[i])) finite = 0;

  xsum_small_accumulator s, a, b, c;
  memset(&s, 0, sizeof s);
  xsum_small_init(&s);
  xsum_small_addv(&s, x, (xsum_length) n);
  double rs = xsum_small_round(&s);
  if (!same(rs, xsum_small_round(&s))) abort();                  /* 6 */

  memset(&lacc, 0, sizeof lacc);
  xsum_large_init(&lacc);
  xsum_large_addv(&lacc, x, (xsum_length) n);
  double rl = xsum_large_round(&lacc);
  if (!same(rs, rl)) abort();                                    /* 1 */

  memset(&c, 0, sizeof c);
  xsum_large_to_small_accumulator(&c, &lacc);
  if (!same(rs, xsum_small_round(&c))) abort();                  /* 3 */

  memset(&a, 0, sizeof a);
  memset(&b, 0, sizeof b);
  xsum_small_init(&a);
  xsum_small_init(&b);
  xsum_small_addv(&a, x, (xsum_length) split);
  xsum_small_addv(&b, x + split, (xsum_length) (n - split));
  xsum_small_add_accumulator(&b, &a);
  if (!same(rs, xsum_small_round(&b))) abort();                  /* 2 */

  if (!same(rs, xsum_small_div_unsigned(&s, 1))) abort();        /* 5 */

  if (finite) {
    xsum_small_accumulator neg = s;
    xsum_small_negate(&neg);
    xsum_small_add_accumulator(&neg, &s);
    double z = xsum_small_round(&neg);
    if (!(z == 0.0)) abort();                                    /* 4 */
  }

  free(x);
  return 0;
}
