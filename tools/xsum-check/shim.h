/* Declarations upstream's xsum-check.c expects from xsum.h, which zuexact's
   patch 0001 removes. tools/xsum-check/run includes this right after the
   checker's own #include "xsum.h" (xsum.h has no include guard). */
extern int xsum_debug;
void xsum_small_display (xsum_small_accumulator *restrict);
void xsum_large_display (xsum_large_accumulator *restrict);
